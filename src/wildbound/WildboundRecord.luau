-- Saved-progress record, schema 2 (W10, M6.1; Nest Heist Phase 3 NS1/NS2). Pure: no service, no yield, no clock. It defines the one value
-- stored per player, turns a State profile into that value and back, validates every load and runs the migration
-- ladder. Design: docs/mechanics/wildbound-persistence.md sections 3 and 7. Only the store adapter
-- (WildboundStoreRoblox) may name the data store service; this module and WildboundPersistence never do.
-- Schema 2 (NS1, NS2): the incubator list (server timestamps) and the training levels are saved; what is out in the
-- world (the bag, the pouch, a dropped or carried item, the trip) is never saved, so a death or a leave still loses it.
-- Schema 3 (NS7): the gloves with their rolled stats and the worn one.
local Record = {}

Record.SCHEMA = 3
Record.LEDGER_CAP = 64
Record.MAX_CHARS = 4194304

local ITEM_KINDS = table.freeze({ Creature = true, Egg = true, Nightbloom = true })
local TIERS = table.freeze({ Safe = true, Fog = true, Territory = true })
local WARDS = table.freeze({ Seal = true, Totem = true })
local KNOWN = table.freeze({
	schema = true, revision = true, lastCommitId = true, lastWriteId = true, nextUid = true, nextTrip = true,
	nextOp = true, firstSealGranted = true, collection = true, equippedUid = true, banked = true, ember = true,
	consumables = true, upgrades = true, skills = true, bondXp = true, settings = true, stats = true, atRisk = true,
	ledger = true, incubating = true, training = true, gloves = true,
})
local STATS = table.freeze({ "tripsOpened", "extractions", "defeats", "firstPlayedDay" })
-- NS7: a glove's stats and their hard caps in percent. Must equal WildboundGear.HARD_CAPS (the Save suite checks).
Record.GLOVE_CAPS = table.freeze({ move = 3, steal = 25, burst = 30, drain = 40, calm = 40 })
Record.GLOVE_RARITIES = table.freeze({ Comun = true, Rara = true, Epica = true, Legendaria = true })
Record.GLOVE_LIMIT = 12

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
Record.copy = copy

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isCount(value)
	return finite(value) and value >= 0 and value % 1 == 0 and value < 2 ^ 53
end
Record.isCount = isCount

-- Durable item IDs are u1, u2, ... with no leading zero. Session IDs (wb:N) never match.
local function uidNumber(value)
	if type(value) ~= "string" then return nil end
	local digits = string.match(value, "^u([1-9]%d*)$")
	if not digits or #digits > 15 then return nil end
	return tonumber(digits)
end
Record.uidNumber = uidNumber

function Record.blank()
	local stats = {}
	for _, name in ipairs(STATS) do stats[name] = 0 end
	return {
		schema = Record.SCHEMA, revision = 0, nextUid = 1, nextTrip = 1, nextOp = 1, firstSealGranted = false,
		collection = { registered = {}, bankedEggs = {} },
		banked = {}, ember = 0, consumables = {}, upgrades = {}, skills = {}, bondXp = {}, settings = {},
		stats = stats, ledger = {}, incubating = {}, training = {}, gloves = { owned = {} },
	}
end

function Record.allocateUid(record)
	local uid = "u" .. record.nextUid
	record.nextUid += 1
	return uid
end

function Record.findLedger(record, id)
	for _, entry in ipairs(record.ledger) do
		if entry.id == id then return entry end
	end
	return nil
end

-- Keeps the newest LEDGER_CAP entries, by count (section 5).
function Record.appendLedger(record, entry)
	table.insert(record.ledger, { id = entry.id, kind = entry.kind, digest = entry.digest })
	while #record.ledger > Record.LEDGER_CAP do table.remove(record.ledger, 1) end
end

-- A stable text for a payload of plain values: keys sorted, so table order never changes the digest.
local function canonical(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for k in pairs(value) do table.insert(keys, k) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local parts = {}
		for _, k in ipairs(keys) do table.insert(parts, tostring(k) .. "=" .. canonical(value[k])) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

function Record.digest(kind, payload)
	return tostring(kind) .. ":" .. canonical(payload)
end

local function item(entry)
	return { uid = entry.uid, kind = entry.kind, species = entry.species, riskTier = entry.riskTier,
		quantity = entry.quantity, wardSource = entry.wardSource }
end

local function anyPositive(amounts)
	for _, quantity in pairs(amounts) do
		if type(quantity) == "number" and quantity > 0 then return true end
	end
	return false
end

-- Only the lists that are saved: the bag, the drops and the carry slot are never written (NS2).
local function everyUid(profile)
	local list = {}
	for _, name in ipairs({ "registered", "bankedEggs", "incubating" }) do
		for _, entry in ipairs(profile[name] or {}) do table.insert(list, entry.uid) end
	end
	for _, glove in ipairs(profile.gloves and profile.gloves.list or {}) do table.insert(list, glove.uid) end
	return list
end

-- Profile -> record. `base` is the record loaded at claim: its counters, ledger, stats, settings and any
-- unknown field are kept. `meta` carries what the State profile does not hold: nowUnix, sessionNow (the
-- server clock the expedition used), leftAtUnix, marks, kUsed, position and droppedExpiry (uid -> unix time).
-- Returns nil and "SessionId" when an item still carries a session ID, so B17 IDs can never be saved.
function Record.fromProfile(profile, base, meta, economy, config)
	meta = meta or {}
	for _, uid in ipairs(everyUid(profile)) do
		if not uidNumber(uid) then return nil, "SessionId" end
	end
	if profile.equippedUid ~= nil and not uidNumber(profile.equippedUid) then return nil, "SessionId" end
	local record = {}
	for k, v in pairs(base or {}) do
		if not KNOWN[k] then record[k] = copy(v) end
	end
	local source = base or Record.blank()
	record.schema = Record.SCHEMA
	record.revision = source.revision or 0
	record.lastCommitId = source.lastCommitId
	record.lastWriteId = source.lastWriteId
	record.nextUid = source.nextUid or 1
	record.nextTrip = source.nextTrip or 1
	record.nextOp = source.nextOp or 1
	record.settings = copy(source.settings or {})
	record.stats = copy(source.stats or Record.blank().stats)
	record.ledger = copy(source.ledger or {})
	record.firstSealGranted = profile.earnedSeal == true
	record.collection = { registered = {}, bankedEggs = {} }
	for _, entry in ipairs(profile.registered) do
		table.insert(record.collection.registered, { uid = entry.uid, species = entry.species })
	end
	for _, entry in ipairs(profile.bankedEggs) do
		table.insert(record.collection.bankedEggs, { uid = entry.uid, species = entry.species })
	end
	record.equippedUid = profile.equippedUid
	record.banked = copy(profile.banked)
	record.ember = profile.ember
	record.consumables = copy(profile.consumables)
	record.upgrades = copy(profile.upgrades)
	record.skills = copy(profile.skills)
	record.bondXp = {}
	for uid, entry in pairs(profile.bond) do record.bondXp[uid] = entry.xp end
	record.incubating = {}
	for _, entry in ipairs(profile.incubating or {}) do
		table.insert(record.incubating, { uid = entry.uid, species = entry.species, startedAtUnix = entry.startedAt,
			readyAtUnix = entry.readyAt })
	end
	record.training = copy(profile.training or {})
	-- NS7: every glove and the worn one.
	record.gloves = { owned = {} }
	for _, glove in ipairs(profile.gloves and profile.gloves.list or {}) do
		table.insert(record.gloves.owned, { uid = glove.uid, rarity = glove.rarity, stats = copy(glove.stats) })
	end
	record.gloves.equippedUid = profile.gloves and profile.gloves.equipped or nil
	if profile.gloves and profile.gloves.equipped ~= nil and not uidNumber(profile.gloves.equipped) then
		return nil, "SessionId"
	end

	-- NS2: nothing at risk is saved. Schema 1's atRisk writer is kept behind meta.saveAtRisk, which no caller sets, so
	-- the legacy shape stays readable by the validator; toProfile never restores it.
	local expedition = profile.expedition
	local atRisk = meta.saveAtRisk == true and (#profile.pending > 0 or #profile.dropped > 0
		or anyPositive(profile.carried) or profile.sealArmed or profile.totemActive or expedition ~= nil)
	if atRisk then
		local risk = {
			pending = {}, carried = copy(profile.carried), dropped = {},
			sealArmed = profile.sealArmed == true, totemActive = profile.totemActive == true,
			marks = meta.marks or 0, kUsed = meta.kUsed or 0,
			position = meta.position and { x = meta.position.x, y = meta.position.y, z = meta.position.z } or nil,
			checkpointAtUnix = meta.nowUnix or 0, leftAtUnix = meta.leftAtUnix,
		}
		for _, entry in ipairs(profile.pending) do table.insert(risk.pending, item(entry)) end
		local expiry = meta.droppedExpiry or {}
		for _, entry in ipairs(profile.dropped) do
			-- No known expiry: it lapses at the checkpoint, so a missing timer can never extend a drop.
			table.insert(risk.dropped, { entry = item(entry), expiresAtUnix = expiry[entry.uid] or meta.nowUnix or 0 })
		end
		if expedition then
			local elapsed = finite(meta.sessionNow) and finite(expedition.startedAt)
				and math.max(0, meta.sessionNow - expedition.startedAt) or 0
			risk.expedition = {
				elapsedSeconds = elapsed, maxDistanceFromCamp = expedition.maxDistanceFromCamp,
				paidSlots = copy(expedition.paidSlots), newUnits = expedition.newUnits, newItems = expedition.newItems,
				bondXp = expedition.bondXp, bondEvents = copy(expedition.bondEvents),
				pendingBond = copy(expedition.pendingBond),
			}
		end
		record.atRisk = risk
	end
	return record
end

local function zeroed(names, value)
	local out = {}
	for _, name in ipairs(names) do out[name] = value end
	return out
end

-- Record -> a profile with exactly the shape State:addPlayer makes. Session-only tables start empty.
-- Bond level is computed from tuning; `sessionNow` rebuilds the expedition start on this server's clock.
function Record.toProfile(record, economy, config, sessionNow)
	local consumables = {}
	for name in pairs(config.capacity.consumableCaps) do consumables[name] = record.consumables[name] or 0 end
	local upgrades = {}
	for name in pairs(config.upgrades) do upgrades[name] = record.upgrades[name] == true end
	local banked = zeroed(economy.materials(config), 0)
	for name, quantity in pairs(record.banked) do banked[name] = quantity end
	local carried = zeroed(economy.pouchMaterials(config), 0)
	local profile = {
		pending = {}, bankedEggs = {}, registered = {}, earnedSeal = record.firstSealGranted == true,
		defeats = {}, defeatOrder = {}, dropped = {}, strikeDrops = {}, strikeOrder = {},
		carried = carried, banked = banked, ember = record.ember, consumables = consumables, upgrades = upgrades,
		sealArmed = false, totemActive = false, expedition = nil, skills = copy(record.skills), bond = {},
		-- Delivery B: the carry slot is not saved (a carried creature is at risk, like the old bag creature, and
		-- schema 1 has no field for it); collection entries follow from the registered species.
		carrying = nil, discovered = {},
	}
	profile.equippedUid = record.equippedUid
	for _, entry in ipairs(record.collection.registered) do
		table.insert(profile.registered, { uid = entry.uid, species = entry.species })
		profile.discovered[entry.species] = true
	end
	for _, entry in ipairs(record.collection.bankedEggs) do
		table.insert(profile.bankedEggs, { uid = entry.uid, kind = "Egg", species = entry.species })
	end
	for uid, xp in pairs(record.bondXp) do
		profile.bond[uid] = { xp = xp, level = economy.bondLevel(config, xp) }
	end
	-- NS2: the incubator and the training levels, made only when there is something (the blank profile must equal
	-- State:addPlayer's, RT-2). Incubation times are server Unix seconds, so an egg keeps hatching while offline.
	if type(record.incubating) == "table" and #record.incubating > 0 then
		profile.incubating = {}
		for _, entry in ipairs(record.incubating) do
			table.insert(profile.incubating, { uid = entry.uid, species = entry.species, startedAt = entry.startedAtUnix,
				readyAt = entry.readyAtUnix })
		end
	end
	if type(record.training) == "table" and next(record.training) ~= nil then profile.training = copy(record.training) end
	-- NS7: the gloves, made only when there is one.
	local gloves = record.gloves
	if type(gloves) == "table" and type(gloves.owned) == "table" and #gloves.owned > 0 then
		profile.gloves = { list = {}, equipped = gloves.equippedUid }
		for _, glove in ipairs(gloves.owned) do
			table.insert(profile.gloves.list, { uid = glove.uid, rarity = glove.rarity, stats = copy(glove.stats) })
		end
	end
	-- NS2: a legacy atRisk section is never restored, so carried things never come back after a leave.
	return profile
end

-- Validation on every load and before every write. Any problem means quarantine on load and no write on save.
function Record.validate(record, economy, config)
	local problems = {}
	local function fail(text) table.insert(problems, text) end
	if type(record) ~= "table" then return false, { "record is not a table" } end
	local function count(value, label) if not isCount(value) then fail(label .. " is not a count") end end
	local function flag(value, label) if type(value) ~= "boolean" then fail(label .. " is not a boolean") end end
	local function map(value, label)
		if type(value) ~= "table" then fail(label .. " is not a table"); return false end
		return true
	end
	local function optionalString(value, label)
		if value ~= nil and (type(value) ~= "string" or #value == 0 or #value > 128) then fail(label .. " is not an ID") end
	end

	if record.schema ~= Record.SCHEMA then fail("schema is not " .. Record.SCHEMA) end
	count(record.revision, "revision"); count(record.nextUid, "nextUid")
	count(record.nextTrip, "nextTrip"); count(record.nextOp, "nextOp")
	flag(record.firstSealGranted, "firstSealGranted")
	optionalString(record.lastCommitId, "lastCommitId"); optionalString(record.lastWriteId, "lastWriteId")
	count(record.ember, "ember")

	local seen, highest, companions = {}, 0, 0
	local registeredSet = {}
	local function claimUid(uid, label)
		local number = uidNumber(uid)
		if not number then fail(label .. " has a malformed ID " .. tostring(uid)); return end
		if seen[uid] then fail("ID " .. uid .. " is used twice") end
		seen[uid] = true
		if number > highest then highest = number end
	end
	local function species(entry, label)
		if type(entry.species) ~= "string" or #entry.species == 0 then fail(label .. " has no species") end
	end
	local function bagItem(entry, label)
		if type(entry) ~= "table" then fail(label .. " is not a table"); return end
		claimUid(entry.uid, label)
		if not ITEM_KINDS[entry.kind] then fail(label .. " has an unknown kind") return end
		if entry.kind == "Nightbloom" then
			if not isCount(entry.quantity) or entry.quantity < 1 then fail(label .. " has no quantity") end
		else
			species(entry, label)
			companions += 1
		end
		if entry.riskTier ~= nil and not TIERS[entry.riskTier] then fail(label .. " has an unknown tier") end
		if entry.wardSource ~= nil and not WARDS[entry.wardSource] then fail(label .. " has an unknown ward") end
	end

	local collection = record.collection
	if map(collection, "collection") then
		for _, name in ipairs({ "registered", "bankedEggs" }) do
			local list = collection[name]
			if map(list, name) then
				for index, entry in ipairs(list) do
					local label = name .. "[" .. index .. "]"
					if type(entry) ~= "table" then fail(label .. " is not a table") else
						claimUid(entry.uid, label)
						species(entry, label)
						companions += 1
						if name == "registered" then registeredSet[entry.uid] = true end
					end
				end
			end
		end
	end

	if map(record.incubating, "incubating") then
		for index, entry in ipairs(record.incubating) do
			local label = "incubating[" .. index .. "]"
			if type(entry) ~= "table" then fail(label .. " is not a table") else
				claimUid(entry.uid, label)
				species(entry, label)
				companions += 1
				if not finite(entry.startedAtUnix) or not finite(entry.readyAtUnix) then fail(label .. " has no times") end
			end
		end
	end
	if map(record.training, "training") then
		for name, level in pairs(record.training) do
			if type(name) ~= "string" or #name == 0 or #name > 32 then fail("training has a malformed key") end
			count(level, "training." .. tostring(name))
		end
	end

	local gloves = record.gloves
	if map(gloves, "gloves") and map(gloves.owned, "gloves.owned") then
		local owned = {}
		if #gloves.owned > Record.GLOVE_LIMIT then fail("gloves are over their limit") end
		for index, glove in ipairs(gloves.owned) do
			local label = "gloves[" .. index .. "]"
			if type(glove) ~= "table" then fail(label .. " is not a table") else
				claimUid(glove.uid, label)
				owned[glove.uid] = true
				if not Record.GLOVE_RARITIES[glove.rarity] then fail(label .. " has an unknown rarity") end
				local statCount = 0
				if type(glove.stats) ~= "table" then fail(label .. " has no stats") else
					for stat, value in pairs(glove.stats) do
						local cap = Record.GLOVE_CAPS[stat]
						if not cap then fail(label .. " has an unknown stat " .. tostring(stat))
						elseif not finite(value) or value <= 0 or value > cap then fail(label .. "." .. stat .. " is out of range") end
						statCount += 1
					end
				end
				if statCount < 1 or statCount > 5 then fail(label .. " has no valid stat count") end
			end
		end
		if gloves.equippedUid ~= nil and not owned[gloves.equippedUid] then fail("the worn glove is not owned") end
	end

	if record.equippedUid ~= nil and not registeredSet[record.equippedUid] then fail("equippedUid is not registered") end
	if map(record.bondXp, "bondXp") then
		for uid, xp in pairs(record.bondXp) do
			if not registeredSet[uid] then fail("bond for " .. tostring(uid) .. " is not a registered companion") end
			count(xp, "bondXp")
		end
	end

	local materials = {}
	for _, name in ipairs(economy.materials(config)) do materials[name] = true end
	local pouch = {}
	for _, name in ipairs(economy.pouchMaterials(config)) do pouch[name] = true end
	local function amounts(value, known, label)
		if not map(value, label) then return end
		for name, quantity in pairs(value) do
			if not known[name] then fail(label .. " has an unknown key " .. tostring(name)) end
			count(quantity, label .. "." .. tostring(name))
		end
	end
	amounts(record.banked, materials, "banked")
	amounts(record.consumables, config.capacity.consumableCaps, "consumables")
	if map(record.upgrades, "upgrades") then
		for name, owned in pairs(record.upgrades) do
			if not config.upgrades[name] then fail("upgrades has an unknown key " .. tostring(name)) end
			flag(owned, "upgrades." .. tostring(name))
		end
	end
	if map(record.skills, "skills") then
		for id, owned in pairs(record.skills) do
			if type(id) ~= "string" or owned ~= true then fail("skills holds a malformed entry") end
		end
	end
	map(record.settings, "settings")
	if map(record.stats, "stats") then
		for name, value in pairs(record.stats) do count(value, "stats." .. tostring(name)) end
	end
	if map(record.ledger, "ledger") then
		if #record.ledger > Record.LEDGER_CAP then fail("ledger is over its cap") end
		for index, entry in ipairs(record.ledger) do
			if type(entry) ~= "table" or type(entry.id) ~= "string" or type(entry.kind) ~= "string"
				or type(entry.digest) ~= "string" then
				fail("ledger[" .. index .. "] is malformed")
			end
		end
	end

	local risk = record.atRisk
	if risk ~= nil and map(risk, "atRisk") then
		if map(risk.pending, "atRisk.pending") then
			for index, entry in ipairs(risk.pending) do bagItem(entry, "pending[" .. index .. "]") end
		end
		if map(risk.dropped, "atRisk.dropped") then
			for index, drop in ipairs(risk.dropped) do
				if type(drop) ~= "table" then fail("dropped[" .. index .. "] is not a table") else
					bagItem(drop.entry, "dropped[" .. index .. "]")
					if not finite(drop.expiresAtUnix) then fail("dropped[" .. index .. "] has no expiry") end
				end
			end
		end
		amounts(risk.carried, pouch, "atRisk.carried")
		flag(risk.sealArmed, "atRisk.sealArmed"); flag(risk.totemActive, "atRisk.totemActive")
		count(risk.marks, "atRisk.marks"); count(risk.kUsed, "atRisk.kUsed")
		if risk.position ~= nil then
			local p = risk.position
			if type(p) ~= "table" or not finite(p.x) or not finite(p.y) or not finite(p.z) then
				fail("atRisk.position is malformed")
			end
		end
		if not finite(risk.checkpointAtUnix) then fail("atRisk.checkpointAtUnix is malformed") end
		if risk.leftAtUnix ~= nil and not finite(risk.leftAtUnix) then fail("atRisk.leftAtUnix is malformed") end
		local expedition = risk.expedition
		if expedition ~= nil and map(expedition, "atRisk.expedition") then
			for _, name in ipairs({ "elapsedSeconds", "maxDistanceFromCamp" }) do
				if not finite(expedition[name]) or expedition[name] < 0 then fail("expedition." .. name .. " is malformed") end
			end
			count(expedition.newUnits, "expedition.newUnits"); count(expedition.newItems, "expedition.newItems")
			count(expedition.bondXp, "expedition.bondXp")
			map(expedition.paidSlots, "expedition.paidSlots"); map(expedition.bondEvents, "expedition.bondEvents")
			map(expedition.pendingBond, "expedition.pendingBond")
		end
	end

	if companions > config.capacity.collectionLimit then fail("collection is over its limit") end
	if isCount(record.nextUid) and record.nextUid <= highest then fail("nextUid is at or below a used ID") end
	return #problems == 0, problems
end

-- The ladder: MIGRATIONS[n] turns version n into n + 1. Version 0 is the unversioned shape: a table with no
-- schema field. No store ever held one (nothing was saved before W10), so this step exists to prove the ladder
-- and to read hand-made exports; it only fills missing fields and never invents items.
Record.MIGRATIONS = table.freeze({
	[0] = function(data)
		local blank = Record.blank()
		for k, v in pairs(blank) do
			if data[k] == nil then data[k] = v end
		end
		local highest = 0
		for _, name in ipairs({ "registered", "bankedEggs" }) do
			for _, entry in ipairs(type(data.collection) == "table" and data.collection[name] or {}) do
				local number = type(entry) == "table" and uidNumber(entry.uid)
				if number and number > highest then highest = number end
			end
		end
		if type(data.nextUid) == "number" and data.nextUid <= highest then data.nextUid = highest + 1 end
		return data
	end,
	-- NS1/NS2: schema 2 saves the incubator and the training levels, and nothing at risk. A schema 1 atRisk section
	-- (the bag, the pouch, drops, the trip) is dropped: carried things are lost on leaving, as in play.
	[1] = function(data)
		data.atRisk = nil
		if type(data.incubating) ~= "table" then data.incubating = {} end
		if type(data.training) ~= "table" then data.training = {} end
		return data
	end,
	-- NS7: schema 3 adds the gloves. The IT1 equipment was session only and never saved, but a hand-made or legacy
	-- `gear` map ({ [id] = true }) migrates safely: the Guantes de captura and the Botas become a Común glove with the
	-- stat they used to give (calm, drain), and the Chaleco and the Amuleto, whose effects are gone, refund their
	-- Esencia (45 and 40, their IT1 price). Nothing else is invented.
	[2] = function(data)
		local gloves = type(data.gloves) == "table" and data.gloves or {}
		if type(gloves.owned) ~= "table" then gloves.owned = {} end
		local legacy = type(data.gear) == "table" and data.gear or {}
		local nextUid = type(data.nextUid) == "number" and data.nextUid or 1
		for _, item in ipairs({ { "guantes", "calm" }, { "botas", "drain" } }) do
			if legacy[item[1]] == true and #gloves.owned < Record.GLOVE_LIMIT then
				local uid = "u" .. nextUid
				nextUid += 1
				table.insert(gloves.owned, { uid = uid, rarity = "Comun", stats = { [item[2]] = 9 } })
				if gloves.equippedUid == nil then gloves.equippedUid = uid end
			end
		end
		local refund = (legacy.chaleco == true and 45 or 0) + (legacy.amuleto == true and 40 or 0)
		if refund > 0 and type(data.ember) == "number" then data.ember += refund end
		data.nextUid = nextUid
		data.gear = nil
		data.gloves = gloves
		return data
	end,
})

-- Returns "Current" or "Migrated" with a new table, or "TooNew" or "Quarantined" with nil. Never changes `raw`.
function Record.migrate(raw, migrations)
	migrations = migrations or Record.MIGRATIONS
	if type(raw) ~= "table" then return "Quarantined", nil, "NotATable" end
	local version = raw.schema
	if version == nil then version = 0 end
	if type(version) ~= "number" or version % 1 ~= 0 or version < 0 then return "Quarantined", nil, "BadSchema" end
	if version > Record.SCHEMA then return "TooNew", nil end
	local data = copy(raw)
	if version == Record.SCHEMA then return "Current", data end
	while version < Record.SCHEMA do
		local step = migrations[version]
		if type(step) ~= "function" then return "Quarantined", nil, "MissingStep" end
		local ok, nextData = pcall(step, data)
		if not ok or type(nextData) ~= "table" then return "Quarantined", nil, "StepFailed" end
		version += 1
		nextData.schema = version
		data = nextData
	end
	return "Migrated", data
end

return Record
