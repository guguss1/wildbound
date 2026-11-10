-- Saved progress, live glue (Nest Heist Phase 3, NS1 and NS2). Server only. It joins WildboundState (the session
-- profile), WildboundRecord (the saved value) and WildboundPersistence (lock, load guard, autosave, leave, close) over
-- a store port from WildboundStoreRoblox. It never names a data store: the port, the clocks and the waits are
-- injected, so every rule here runs against the in-memory fake in tests.
--
-- Rules:
-- * Only a successful claim (New or Loaded) makes a saving session. Any other outcome (Unavailable, LockedElsewhere,
--   Quarantined, TooNew) gives the player a fresh session profile that is never written: a failed or locked load can
--   never overwrite the real record.
-- * What is saved: banked eggs, registered creatures, the equipped companion, Ember (Esencia), materials banked at
--   camp, consumables, upgrades, skills, bond, the incubator (server Unix times) and the training levels. What is out
--   in the world (the bag, the pouch, a carried or dropped egg, the trip) is never saved.
-- * State makes session IDs (wb:N). Each one gets a durable ID (uN) from the saved counter the first time it is saved,
--   and keeps it for the rest of the session, so the next session loads the same IDs.
-- * Dirty tracking: a digest of the saved fields; a change marks the profile dirty and the next autosave (about every
--   60 s per player) writes it. A clean profile still writes when its lock nears expiry (Persistence.REFRESH_AFTER).
-- * Budget: autosaves wait while the store's write budget is under BUDGET_FLOOR; leave and close always try.
local Save = {}
Save.__index = Save

Save.KEY_PREFIX = "Player_"
Save.STEP_SECONDS = 5 -- how often the live loop checks for due autosaves
Save.BUDGET_FLOOR = 4 -- autosaves wait while fewer write requests than this are left
Save.CLOSE_BUDGET = 25

function Save.keyOf(userId)
	return Save.KEY_PREFIX .. tostring(userId)
end

-- options: persistence (nil = saving off), state, record, clock (Unix seconds), budget (fn -> number or nil),
-- spawn, wait, label (store label for the output), onMode(userId, mode, outcome).
function Save.new(options)
	assert(type(options) == "table" and type(options.state) == "table" and type(options.record) == "table",
		"Save.new needs the State and the Record module")
	return setmetatable({
		persistence = options.persistence, state = options.state, Record = options.record,
		clock = options.clock or os.time, budget = options.budget, spawn = options.spawn or task.spawn,
		wait = options.wait or task.wait, label = options.label or "off", onMode = options.onMode or function() end,
		players = {}, modes = {}, outcomes = {}, releasing = 0, deferred = 0,
	}, Save)
end

local function profileOf(self, userId)
	return self.state.players["n:" .. tostring(userId)]
end

-- The saved view of a profile: durable IDs only, nothing at risk. Allocates a durable ID for each session ID once.
local function durableView(self, userId)
	local profile = profileOf(self, userId)
	local entry = self.players[userId]
	if not profile or not entry then return nil end
	local Record, persistence, key = self.Record, self.persistence, Save.keyOf(userId)
	local map = entry.map
	local function durable(uid)
		if uid == nil then return nil end
		if Record.uidNumber(uid) then return uid end
		local mapped = map[uid]
		if not mapped then
			mapped = persistence:allocateUid(key)
			if not mapped then return nil end
			map[uid] = mapped
		end
		return mapped
	end
	local view = {}
	for k, v in pairs(profile) do view[k] = v end
	local function list(source, fields)
		local out = {}
		for _, item in ipairs(source or {}) do
			local copyItem = table.clone(item)
			copyItem.uid = durable(item.uid)
			if not copyItem.uid then return nil end
			if fields then for name, value in pairs(fields) do copyItem[name] = value end end
			table.insert(out, copyItem)
		end
		return out
	end
	view.registered = list(profile.registered)
	view.bankedEggs = list(profile.bankedEggs)
	view.incubating = profile.incubating and list(profile.incubating) or nil
	if not view.registered or not view.bankedEggs or (profile.incubating and not view.incubating) then return nil end
	local registered = {}
	for _, item in ipairs(view.registered) do registered[item.uid] = true end
	view.equippedUid = profile.equippedUid and durable(profile.equippedUid) or nil
	if view.equippedUid and not registered[view.equippedUid] then view.equippedUid = nil end
	view.bond = {}
	for uid, bond in pairs(profile.bond or {}) do
		local mapped = durable(uid)
		if mapped and registered[mapped] then view.bond[mapped] = bond end
	end
	-- Nothing at risk: the record writer never reads these, they are cleared here so no later change can save them.
	view.pending, view.dropped, view.carrying, view.expedition = {}, {}, nil, nil
	return view
end

-- A stable text of every saved field, so an unchanged profile is not rewritten.
local function digestOf(self, view)
	local bondXp = {}
	for uid, bond in pairs(view.bond) do bondXp[uid] = bond.xp end
	local stripped = {}
	for _, name in ipairs({ "registered", "bankedEggs", "incubating" }) do
		local list = {}
		for index, item in ipairs(view[name] or {}) do
			list[index] = { uid = item.uid, species = item.species, startedAt = item.startedAt, readyAt = item.readyAt }
		end
		stripped[name] = list
	end
	return self.Record.digest("save", {
		lists = stripped, equipped = view.equippedUid or "", banked = view.banked, ember = view.ember,
		consumables = view.consumables, upgrades = view.upgrades, skills = view.skills, bond = bondXp,
		training = view.training or {}, seal = view.earnedSeal == true,
	})
end

-- PlayerAdded: claim and load, or play unsaved. Yields while the store is called. Returns mode, outcome.
-- Modes: "Saved" (a saving session), "Unsaved" (the load failed or is locked: nothing will be written), "Off".
function Save:join(userId, sessionNow)
	local state = self.state
	if not self.persistence then
		state:addPlayer(userId)
		self.modes[userId] = "Off"
		self.onMode(userId, "Off", nil)
		return "Off", nil
	end
	local key = Save.keyOf(userId)
	local outcome, profile = self.persistence:load(key, sessionNow)
	if profile then
		state:addPlayer(userId)
		state:loadPlayer(userId, profile)
		self.players[userId] = { map = {} }
		local view = durableView(self, userId)
		self.players[userId].digest = view and digestOf(self, view) or nil
		self.modes[userId], self.outcomes[userId] = "Saved", outcome
		self.onMode(userId, "Saved", outcome)
		return "Saved", outcome
	end
	state:addPlayer(userId)
	self.modes[userId], self.outcomes[userId] = "Unsaved", outcome
	self.onMode(userId, "Unsaved", outcome)
	return "Unsaved", outcome
end

function Save:mode(userId)
	return self.modes[userId], self.outcomes[userId]
end

function Save:isSaving(userId)
	if self.modes[userId] ~= "Saved" or not self.persistence then return false end
	local info = self.persistence:info(Save.keyOf(userId))
	return info ~= nil and info.loaded == true
end

local function meta(self)
	return { nowUnix = self.clock() }
end

-- The live loop calls this every STEP_SECONDS. Marks changed profiles dirty, then lets Persistence write the due ones,
-- unless the request budget is low (non-critical writes wait). Returns the keys written.
function Save:step()
	local persistence = self.persistence
	if not persistence then return {} end
	for userId, entry in pairs(self.players) do
		local view = durableView(self, userId)
		if view then
			local digest = digestOf(self, view)
			if digest ~= entry.digest then
				entry.digest = digest
				persistence:markDirty(Save.keyOf(userId))
			end
		end
	end
	if self.budget then
		local ok, left = pcall(self.budget)
		if ok and type(left) == "number" and left < Save.BUDGET_FLOOR then
			self.deferred += 1
			return {}
		end
	end
	local byKey = {}
	for userId in pairs(self.players) do byKey[Save.keyOf(userId)] = userId end
	return persistence:tick(function(key)
		local userId = byKey[key]
		local view = userId and durableView(self, userId)
		if not view then return nil end
		return view, meta(self)
	end)
end

-- PlayerRemoving, before State:removePlayer. The saved view is taken now; the final write and lock release run on
-- their own thread, so the leave never waits for the store. Returns "Releasing", "Unsaved" or "Off".
function Save:leave(userId)
	local mode = self.modes[userId]
	self.modes[userId], self.outcomes[userId] = nil, nil
	local entry = self.players[userId]
	if not entry or not self.persistence then return mode or "Off" end
	local view = durableView(self, userId)
	self.players[userId] = nil
	local key = Save.keyOf(userId)
	-- Without a view (the session was revoked) nothing is written; the lock then expires on its own.
	if not view then return "Revoked" end
	local snapshot = self.Record.copy(view)
	self.releasing += 1
	self.spawn(function()
		local ok, result = pcall(function() return self.persistence:release(key, snapshot, meta(self)) end)
		self.releasing -= 1
		self.lastRelease = ok and result or ("Error: " .. tostring(result))
	end)
	return "Releasing"
end

-- BindToClose: waits for leaves already writing, then one final write per remaining player within the budget.
function Save:closeAll(budget)
	local persistence = self.persistence
	if not persistence then return { saved = 0, failed = {} } end
	local deadline = self.clock() + (budget or Save.CLOSE_BUDGET)
	local byKey = {}
	for userId in pairs(self.players) do byKey[Save.keyOf(userId)] = userId end
	local report = persistence:closeAll(function(key)
		local userId = byKey[key]
		local view = userId and durableView(self, userId)
		if not view then return nil end
		return self.Record.copy(view), meta(self)
	end, math.max(1, deadline - self.clock()))
	table.clear(self.players)
	while self.releasing > 0 and self.clock() < deadline do self.wait(0.1) end
	report.releasing = self.releasing
	return report
end

-- The live autosave loop: one step every STEP_SECONDS until stopped. A failing step is reported, never fatal.
function Save:run()
	self.spawn(function()
		while not self.stopped do
			self.wait(Save.STEP_SECONDS)
			if self.stopped then break end
			local ok, failure = pcall(self.step, self)
			if not ok then warn("Wildbound saves: an autosave step failed: " .. tostring(failure)) end
		end
	end)
end

-- Studio only: ServerStorage.WildboundTelemetry.SaveProbe for the Play checks. Ops: "info", "rejoin" (a leave and a
-- join in place, as stopping and starting Play would), "failLoad" (a rejoin whose load fails every attempt; returns
-- whether the stored value stayed byte-equal), "holdLock" (a rejoin while another server's fresh lock is on the key)
-- and "clearLock" (removes that lock, then rejoins). notify(userId, text) refreshes the player's screen.
function Save:probe(telemetry, notify)
	local HttpService = game:GetService("HttpService")
	local fn = Instance.new("BindableFunction")
	fn.Name = "SaveProbe"
	local function stored(key)
		local ok, value, info = self.port:read(key)
		if not ok then return nil, nil, value end
		return value ~= nil and HttpService:JSONEncode(value) or nil, info and info.metadata and info.metadata.LockId
	end
	local function rejoin(userId)
		self:leave(userId)
		for _ = 1, 400 do
			if self.releasing == 0 then break end
			self.wait(0.05)
		end
		self.state:removePlayer(userId)
		local mode, outcome = self:join(userId, workspace:GetServerTimeNow())
		if notify then notify(userId, mode .. " " .. tostring(outcome)) end
		return mode, outcome
	end
	fn.OnInvoke = function(op, userId)
		userId = tonumber(userId)
		if not userId or not self.persistence or not self.port then return nil, "NoSaving" end
		local key = Save.keyOf(userId)
		if op == "info" then
			local text, lock = stored(key)
			local mode, outcome = self:mode(userId)
			return { label = self.label, reason = self.reason, mode = mode, outcome = outcome,
				saving = self:isSaving(userId), deferred = self.deferred, lastRelease = self.lastRelease, stored = text,
				lock = lock, info = self.persistence:info(key) }
		elseif op == "rejoin" then
			return rejoin(userId)
		elseif op == "failLoad" then
			self:leave(userId)
			for _ = 1, 400 do
				if self.releasing == 0 then break end
				self.wait(0.05)
			end
			local before = stored(key)
			local real = self.persistence.store
			self.persistence.store = { update = function() return false, "Error" end, read = function() return false, "Error" end }
			local ok, mode, outcome = pcall(rejoin, userId)
			self.persistence.store = real
			local after = stored(key)
			return ok and mode or "Error", outcome, before ~= nil and before == after
		elseif op == "holdLock" then
			self:leave(userId)
			for _ = 1, 400 do
				if self.releasing == 0 then break end
				self.wait(0.05)
			end
			self.port:update(key, function(current)
				if current == nil then return nil end
				return current, { LockId = "SaveProbe:another-server" }
			end)
			local before = stored(key)
			self.state:removePlayer(userId)
			local mode, outcome = self:join(userId, workspace:GetServerTimeNow())
			if notify then notify(userId, mode .. " " .. tostring(outcome)) end
			local after, lock = stored(key)
			return mode, outcome, before == after, lock
		elseif op == "clearLock" then
			self.port:update(key, function(current)
				if current == nil then return nil end
				return current, {}
			end)
			return rejoin(userId)
		end
		return nil, "UnknownOp"
	end
	fn.Parent = telemetry
	return fn
end

-- Live start (the inventory server calls this once). env: state, record, persistence (module), store (module),
-- economy, config, mode (WildboundFlags.persistenceMode), telemetry, notify. Opens the store (memory in Studio without
-- API access, said in the output), builds the session manager, starts the autosave loop and, in Studio, the probe.
function Save.start(env)
	local isStudio = game:GetService("RunService"):IsStudio()
	local port, label, reason = env.store.open({ mode = env.mode or "datastore", isStudio = isStudio })
	if reason then
		warn("Wildbound saves: " .. label .. " - " .. reason)
	else
		print("Wildbound saves: " .. label)
	end
	local serverId = game.JobId ~= "" and game.JobId or ("studio:" .. game:GetService("HttpService"):GenerateGUID(false))
	local persistence = port and env.persistence.new({ store = port, serverId = serverId, record = env.record,
		economy = env.economy, config = env.config }) or nil
	local save = Save.new({ persistence = persistence, state = env.state, record = env.record, label = label,
		budget = port and function() return port:budget() end or nil })
	save.port, save.reason = port, reason
	if persistence then save:run() end
	if isStudio and env.telemetry and persistence then save:probe(env.telemetry, env.notify) end
	return save
end

return Save
