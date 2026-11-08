-- Server-side analytics seam (W16, M9.5). Pure rules: it turns game moments into a fixed, versioned event
-- vocabulary and hands each event to an injected sink. Design and privacy rules: docs/testing/wildbound-analytics.md.
-- This wave has no live sink. Mode "off" builds a no-op object; mode "record" keeps events in memory for tests.
-- It never names a Roblox analytics, HTTP, data store or marketplace service, and it never reads a player's name.
--
-- Rules, all enforced here and tested:
--   * closed set of event names, each with fixed fields whose values come from short lists (no numbers, no free text)
--   * a per-session opaque id; the caller's key stays in memory and never appears in an event
--   * a per-session rate limit and cap, a sink that may throw, and one-time events logged once per session
--   * no per-frame work: every call happens on a game moment, and a call that logs nothing allocates nothing
local Analytics = {}
Analytics.__index = Analytics

Analytics.SCHEMA = 1
Analytics.MAX_EVENTS = 150 -- per session; the last slot is kept for session_end
Analytics.MAX_SESSIONS = 100
Analytics.RATE_CAPACITY = 20 -- repeatable events a session may burst
Analytics.RATE_SECONDS = 3 -- one more token per this many seconds
Analytics.STRIKE_WINDOW = 10 -- a defeat this soon after a strike on the same player counts as Silueta's
Analytics.SINK_TRIP = 25 -- consecutive sink errors before the sink is cut off for the rest of the server
Analytics.MAX_T = 86400
Analytics.MAX_FIELDS = 3

local function set(...) return table.freeze({ ... }) end
local EMPTY = table.freeze({})

local ZONES = set("outside", "fog", "territory")
local TRIPS = set("0", "1", "2", "3", "4plus")
local TRIP_NUMBERS = set("1", "2", "3", "4plus")
local YESNO = set("yes", "no")
local TRIP_BANDS = set("under3", "3to8", "over8") -- minutes, from D5's 3 to 8 minute trip
local CAPTURE_BANDS = set("under4", "4to8", "over8") -- seconds, around the 4 to 6 s hold
local SESSION_BANDS = set("under1", "1to5", "5to15", "15to30", "over30") -- minutes
-- Expedition islands (K3): seconds from the join to the first steal and the first registration.
local HOOK_BANDS = set("under30", "30to60", "60to120", "over120")
local ISLANDS = set("I1", "I2", "I3", "I4", "I5")

local function event(fields, once, client)
	return table.freeze({ fields = table.freeze(fields), once = once == true, client = client == true })
end

Analytics.EVENTS = table.freeze({
	session_join = event({}, true),
	start_play = event({}, true, true),
	tutorial_complete = event({}, true, true),
	tutorial_skip = event({}, true, true),
	trip_open = event({ n = TRIP_NUMBERS }),
	first_gain = event({ source = set("gather", "pickup", "capture") }, true),
	first_gather = event({ zone = ZONES }, true),
	first_capture = event({ zone = ZONES }, true),
	first_extract = event({}, true),
	-- Delivery B: the first carried creature registered at the camp refuge.
	first_register = event({}, true),
	-- Expedition islands (K3): the first-minute hook. The first cria taken, the first registration timed, and each
	-- island a session reaches (once per island).
	first_steal = event({ band = HOOK_BANDS }, true),
	first_register_timed = event({ band = HOOK_BANDS }, true),
	island_reached = event({ island = ISLANDS }),
	first_craft = event({ recipe = set("seal", "capsule", "totem") }, true),
	trip_end = event({ outcome = set("extracted", "defeated", "left"), band = TRIP_BANDS, gained = YESNO }),
	capture_end = event({ zone = ZONES, reason = set("Completed", "LeftRing", "TimedOut", "TooFar", "Struck",
		"Defeated", "BackpackFull", "CollectionFull", "Cancelled", "Disconnected", "Lost", "LostTrack", "Watchdog",
		"SealMissed"),
		band = CAPTURE_BANDS }),
	spent = event({ what = set("craft", "upgrade", "skill", "capsule") }),
	strike = event({}),
	death = event({ cause = set("silueta", "other") }),
	session_end = event({ band = SESSION_BANDS, trips = TRIPS, ended = set("left", "closed") }, true),
})

-- The capture rule names zones by tier; gathering uses the economy's zone names.
Analytics.ZONE_OF_TIER = table.freeze({ Safe = "outside", Fog = "fog", Territory = "territory" })

Analytics.METHODS = set("join", "leave", "closeAll", "observeCamp", "gain", "extracted", "registered", "crafted", "spent",
	"capture", "noteStrike", "death", "fromClient", "stole", "islandReached")
Analytics.COUNTERS = set("sent", "rejected", "rejectedClient", "duplicates", "droppedRate", "droppedCap",
	"droppedSink", "droppedSessions", "sinkErrors", "unknownSession")

local function member(list, value)
	for _, item in ipairs(list) do
		if item == value then return true end
	end
	return false
end

-- Whether `fields` is exactly the whitelist for `name`: every field present, none extra, each value on its list.
function Analytics.validate(name, fields)
	if type(name) ~= "string" then return false, "name" end
	local def = Analytics.EVENTS[name]
	if not def then return false, "unknownEvent" end
	if fields == nil then fields = EMPTY end
	if type(fields) ~= "table" then return false, "fields" end
	for key, value in pairs(fields) do
		local allowed = type(key) == "string" and def.fields[key] or nil
		if not allowed then return false, "unknownField" end
		if type(value) ~= "string" or not member(allowed, value) then return false, "badValue" end
	end
	for field in pairs(def.fields) do
		if fields[field] == nil then return false, "missingField" end
	end
	return true
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function band(seconds, names, first, second)
	if seconds < first then return names[1] end
	if seconds <= second then return names[2] end
	return names[3]
end

local function sessionBand(seconds)
	if seconds < 60 then return "under1" end
	if seconds < 300 then return "1to5" end
	if seconds < 900 then return "5to15" end
	if seconds < 1800 then return "15to30" end
	return "over30"
end

local function tripLabel(count)
	return count >= 4 and "4plus" or tostring(count)
end

-- A sink is any table with write(sink, event). Events are frozen, so a sink cannot change what others see.
function Analytics.recorder(cap)
	local recorder = { events = {}, cap = cap or 500, overflow = 0 }
	function recorder.write(self, value)
		if #self.events >= self.cap then
			self.overflow += 1
			return
		end
		table.insert(self.events, value)
	end
	return recorder
end

-- One line per event for an exported log. The caller supplies the encoder, so this module names no service.
function Analytics.lines(events, encode)
	local out = {}
	for index, value in ipairs(events) do out[index] = encode(value) end
	return out
end

function Analytics.new(options)
	assert(type(options) == "table", "Analytics.new needs options")
	local sink = options.sink
	assert(type(sink) == "table" and type(sink.write) == "function", "Analytics.new needs a sink with write")
	local rng = Random.new()
	local random = options.random or function() return rng:NextNumber() end
	local tag = options.tag
	if tag == nil then
		tag = ""
		for _ = 1, 12 do tag ..= string.format("%x", math.min(15, math.floor(random() * 16))) end
	end
	local counters = {}
	for _, name in ipairs(Analytics.COUNTERS) do counters[name] = 0 end
	return setmetatable({
		enabled = true, mode = options.mode or "custom", sink = sink, clock = options.clock or os.clock,
		tag = tag, serial = 0, sessions = {}, sessionCount = 0, counters = counters, consecutive = 0, tripped = false,
	}, Analytics)
end

-- "off" (or anything unknown) is a no-op object with the same methods. "record" keeps events in memory.
function Analytics.disabled()
	local counters = {}
	for _, name in ipairs(Analytics.COUNTERS) do counters[name] = 0 end
	local object = { enabled = false, mode = "off", counters = table.freeze(counters) }
	for _, name in ipairs(Analytics.METHODS) do object[name] = function() return false end end
	return table.freeze(object)
end

function Analytics.fromMode(mode, options)
	if mode ~= "record" then return Analytics.disabled(), nil end
	options = options or {}
	local recorder = Analytics.recorder(options.cap)
	local copy = table.clone(options)
	copy.sink, copy.mode = recorder, "record"
	return Analytics.new(copy), recorder
end

local function deliver(self, value)
	if self.tripped then
		self.counters.droppedSink += 1
		return
	end
	if pcall(self.sink.write, self.sink, value) then
		self.consecutive = 0
		self.counters.sent += 1
	else
		self.consecutive += 1
		self.counters.sinkErrors += 1
		if self.consecutive >= Analytics.SINK_TRIP then self.tripped = true end
	end
end

-- The one place an event is built. Rejects anything off the whitelist, then applies the limits.
local function emit(self, session, name, fields)
	local valid = Analytics.validate(name, fields)
	if not valid then
		self.counters.rejected += 1
		return false
	end
	local def = Analytics.EVENTS[name]
	if def.once and session.seen[name] then
		self.counters.duplicates += 1
		return false
	end
	local final = name == "session_end"
	if session.count >= (final and Analytics.MAX_EVENTS or Analytics.MAX_EVENTS - 1) then
		self.counters.droppedCap += 1
		return false
	end
	local now = self.clock()
	if not def.once and not final then
		session.tokens = math.min(Analytics.RATE_CAPACITY, session.tokens + (now - session.refillAt) / Analytics.RATE_SECONDS)
		session.refillAt = now
		if session.tokens < 1 then
			self.counters.droppedRate += 1
			return false
		end
		session.tokens -= 1
	end
	if def.once then session.seen[name] = true end
	session.seq += 1
	session.count += 1
	local copy = EMPTY
	if next(def.fields) ~= nil then
		copy = {}
		for key, value in pairs(fields) do copy[key] = value end
		table.freeze(copy)
	end
	deliver(self, table.freeze({
		v = Analytics.SCHEMA, name = name, sid = session.sid, seq = session.seq,
		t = math.clamp(math.floor(now - session.startedAt), 0, Analytics.MAX_T), f = copy,
	}))
	return true
end

local function hookBand(seconds)
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 30 then return "under30" end
	if seconds < 60 then return "30to60" end
	if seconds < 120 then return "60to120" end
	return "over120"
end

local function sessionOf(self, key)
	local session = key ~= nil and self.sessions[key] or nil
	if not session then self.counters.unknownSession += 1 end
	return session
end

local function closeTrip(self, session, outcome)
	if not session.tripOpen then return end
	local seconds = self.clock() - session.tripStartedAt
	session.tripOpen = false
	emit(self, session, "trip_end", { outcome = outcome, band = band(seconds, TRIP_BANDS, 180, 480),
		gained = session.tripGained and "yes" or "no" })
	session.tripGained = false
end

local function openTrip(self, session)
	if session.tripOpen then return end
	session.trips += 1
	session.tripOpen, session.tripGained, session.tripStartedAt = true, false, self.clock()
	emit(self, session, "trip_open", { n = tripLabel(session.trips) })
end

-- A player arrived. The key is anything stable for the visit; it is never written to an event.
function Analytics:join(key)
	if key == nil or self.sessions[key] then return false end
	if self.sessionCount >= Analytics.MAX_SESSIONS then
		self.counters.droppedSessions += 1
		return false
	end
	self.serial += 1
	local now = self.clock()
	local session = { sid = self.tag .. "-" .. self.serial, startedAt = now, seq = 0, count = 0,
		tokens = Analytics.RATE_CAPACITY, refillAt = now, seen = {}, tripOpen = false, tripGained = false,
		tripStartedAt = now, trips = 0, lastStrikeAt = nil }
	self.sessions[key] = session
	self.sessionCount += 1
	emit(self, session, "session_join")
	return true
end

-- The visit ended. An open trip ends as "left"; session_end is always allowed its reserved slot.
function Analytics:leave(key, ended)
	local session = sessionOf(self, key)
	if not session then return false end
	closeTrip(self, session, "left")
	emit(self, session, "session_end", { band = sessionBand(self.clock() - session.startedAt),
		trips = session.trips == 0 and "0" or tripLabel(session.trips),
		ended = ended == "closed" and "closed" or "left" })
	self.sessions[key] = nil
	self.sessionCount -= 1
	return true
end

function Analytics:closeAll()
	local keys = {}
	for key in pairs(self.sessions) do table.insert(keys, key) end
	for _, key in ipairs(keys) do self:leave(key, "closed") end
	return #keys > 0
end

-- Reported where the server already decides it: the player stands outside camp and alive. Opens a trip once.
function Analytics:observeCamp(key, outside)
	if outside ~= true then return false end
	local session = sessionOf(self, key)
	if not session or session.tripOpen then return false end
	openTrip(self, session)
	return true
end

-- Something entered the bag or pouch. source: gather | pickup | capture; zone is needed for gather and capture.
function Analytics:gain(key, source, zone)
	if not member(Analytics.EVENTS.first_gain.fields.source, source)
		or (source ~= "pickup" and not member(ZONES, zone)) then
		self.counters.rejected += 1
		return false
	end
	local session = sessionOf(self, key)
	if not session then return false end
	openTrip(self, session)
	session.tripGained = true
	emit(self, session, "first_gain", { source = source })
	if source == "gather" then emit(self, session, "first_gather", { zone = zone }) end
	if source == "capture" then emit(self, session, "first_capture", { zone = zone }) end
	return true
end

-- A full extraction was confirmed. Ends the trip and logs the first one.
function Analytics:extracted(key)
	local session = sessionOf(self, key)
	if not session then return false end
	emit(self, session, "first_extract")
	closeTrip(self, session, "extracted")
	return true
end

-- Delivery B: a carried creature was registered at the refuge. Like the chest, the refuge ends an open trip.
function Analytics:registered(key)
	local session = sessionOf(self, key)
	if not session then return false end
	emit(self, session, "first_register")
	emit(self, session, "first_register_timed", { band = hookBand(self.clock() - session.startedAt) })
	closeTrip(self, session, "extracted")
	return true
end

-- K3: the first cria taken from an island nest, timed from the join.
function Analytics:stole(key)
	local session = sessionOf(self, key)
	if not session then return false end
	emit(self, session, "first_steal", { band = hookBand(self.clock() - session.startedAt) })
	return true
end

-- K3: a session walked onto an island floor. Each island is logged once per session.
function Analytics:islandReached(key, island)
	if not member(ISLANDS, island) then
		self.counters.rejected += 1
		return false
	end
	local session = sessionOf(self, key)
	if not session then return false end
	session.islands = session.islands or {}
	if session.islands[island] then return true end
	session.islands[island] = true
	emit(self, session, "island_reached", { island = island })
	return true
end

function Analytics:crafted(key, recipe)
	if not member(Analytics.EVENTS.first_craft.fields.recipe, recipe) then
		self.counters.rejected += 1
		return false
	end
	local session = sessionOf(self, key)
	if not session then return false end
	emit(self, session, "first_craft", { recipe = recipe })
	emit(self, session, "spent", { what = "craft" })
	return true
end

function Analytics:spent(key, what)
	local session = sessionOf(self, key)
	if not session then return false end
	return emit(self, session, "spent", { what = what })
end

-- A capture screen ended. `reason` is the capture rule's reason; `zone` comes from ZONE_OF_TIER.
function Analytics:capture(key, reason, zone, seconds, granted)
	if not finite(seconds) or not member(ZONES, zone)
		or not member(Analytics.EVENTS.capture_end.fields.reason, reason) then
		self.counters.rejected += 1
		return false
	end
	local session = sessionOf(self, key)
	if not session then return false end
	emit(self, session, "capture_end", { zone = zone, reason = reason, band = band(math.max(0, seconds), CAPTURE_BANDS, 4, 8) })
	if granted == true then self:gain(key, "capture", zone) end
	return true
end

function Analytics:noteStrike(key)
	local session = sessionOf(self, key)
	if not session then return false end
	session.lastStrikeAt = self.clock()
	return emit(self, session, "strike")
end

-- A defeat. It counts as Silueta's when a strike on the same player came just before.
function Analytics:death(key)
	local session = sessionOf(self, key)
	if not session then return false end
	local struck = session.lastStrikeAt ~= nil and self.clock() - session.lastStrikeAt <= Analytics.STRIKE_WINDOW
	session.lastStrikeAt = nil
	emit(self, session, "death", { cause = struck and "silueta" or "other" })
	closeTrip(self, session, "defeated")
	return true
end

-- The only way a client's word can become an event: a name from the small client list, once per session.
-- It carries no fields, so there is nothing to forge. No remote is wired to this in W16.
function Analytics:fromClient(key, name)
	local def = type(name) == "string" and Analytics.EVENTS[name] or nil
	if not def or not def.client then
		self.counters.rejectedClient += 1
		return false
	end
	local session = sessionOf(self, key)
	if not session then return false end
	return emit(self, session, name)
end

return Analytics
