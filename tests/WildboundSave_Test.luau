-- Invoke with require(freshTestClone)({ Save = require(freshSaveClone), Store = require(freshStoreClone),
-- Persistence = require(freshPersistenceClone), Record = require(freshRecordClone), State = require(freshStateClone),
-- Economy = require(freshEconomyClone), Config = require(freshConfigClone), Fake = require(freshFakeClone) },
-- { save = freshSaveClone.Source, store = freshStoreClone.Source, server = WildboundServer.Source,
-- persistence = WildboundPersistence.Source, record = WildboundRecord.Source, text = WildboundText.Source,
-- startView = WildboundStartView.Source, campView = WildboundCampView.Source }).
-- Nest Heist Phase 3 (NS1, NS2): the live saved-progress glue against the in-memory fake store and a fake data store
-- service. No real data store is ever touched here. SV numbers are the feature document's NS1/NS2 contracts.
return function(m, sources)
	local Save, Store, Persistence, Record, State = m.Save, m.Store, m.Persistence, m.Record, m.State
	local Economy, Config, Fake = m.Economy, m.Config, m.Fake
	local result = { passed = 0, failed = 0, messages = {} }
	local HttpService = game:GetService("HttpService")
	local USER = 1001
	local KEY = "Player_1001"
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end

	-- One fake store shared by every "server" of a test, one clock in Unix seconds.
	local function world()
		local clock = { t = 1700000000 }
		local store = Fake.new({ clock = function() return clock.t end, wait = function(s) clock.t += s end })
		local function server(id, extra)
			extra = extra or {}
			local state = State.new(Economy, Config)
			local persistence = Persistence.new({
				store = extra.port or store, serverId = id, record = Record, economy = Economy, config = Config,
				clock = function() return clock.t end, wait = function(s) clock.t += s end,
				random = function() return 0 end, spawn = function(fn) fn() end,
			})
			local modes = {}
			local save = Save.new({
				persistence = persistence, state = state, record = Record, clock = function() return clock.t end,
				budget = extra.budget, spawn = function(fn) fn() end, wait = function(s) clock.t += s end,
				onMode = function(userId, mode, outcome) table.insert(modes, { userId = userId, mode = mode, outcome = outcome }) end,
			})
			return save, state, persistence, modes
		end
		return store, clock, server
	end
	local function stored(store)
		local raw = store:raw(KEY)
		return raw and HttpService:JSONDecode(raw) or nil
	end
	local function seed(store, clock, fill)
		local record = Record.blank()
		record.nextUid = 4
		record.collection.registered = { { uid = "u1", species = "Lumipol" } }
		record.collection.bankedEggs = { { uid = "u2", species = "Lumipol" } }
		record.equippedUid = "u1"
		record.ember = 50
		record.banked.fogbark = 7
		if fill then fill(record) end
		store:seed(KEY, record, {}, clock.t - 1000)
		return record
	end
	-- A banked egg the normal way: an encounter, a pickup, the chest.
	local function bankEgg(state, id)
		state:registerEncounter(id, "Egg")
		assert(state:pickup(USER, id, true, 5))
		assert(state:extract(USER, true, 0, 0))
	end

	case("SV-1: a new player claims a fresh record and plays a saving session", function()
		local store, _, server = world()
		local save, state, _, modes = server("A")
		local mode, outcome = save:join(USER, 0)
		equal(mode, "Saved"); equal(outcome, "New")
		equal(save:isSaving(USER), true)
		assert(state:snapshot(USER), "the profile exists")
		equal(store:metadata(KEY).LockId, "A", "the lock is taken by this server")
		equal(modes[1].mode, "Saved")
	end)

	case("SV-2: a saved record loads into State: collection, banked egg, companion, Esencia, materials", function()
		local store, clock, server = world()
		seed(store, clock, function(r) r.upgrades.reinforcedPack = true; r.training = { speed = 2 } end)
		local save, state = server("A")
		equal((save:join(USER, 0)), "Saved")
		local snapshot = state:snapshot(USER)
		equal(#snapshot.registered, 1); equal(snapshot.registered[1].uid, "u1")
		equal(#snapshot.bankedEggs, 1); equal(snapshot.bankedEggs[1].uid, "u2")
		equal(snapshot.equippedUid, "u1"); equal(snapshot.ember, 50); equal(snapshot.banked.fogbark, 7)
		equal(snapshot.upgrades.reinforcedPack, true)
		equal(state.players["n:" .. USER].training.speed, 2)
	end)

	case("SV-3: a failed load plays unsaved and never writes, even after play, autosaves and a leave", function()
		local store, clock, server = world()
		seed(store, clock)
		local before = store:raw(KEY)
		store:failAll("Error")
		local save, state, _, modes = server("A")
		local mode, outcome = save:join(USER, 0)
		equal(mode, "Unsaved"); equal(outcome, "Unavailable")
		equal(save:isSaving(USER), false)
		equal(modes[1].mode, "Unsaved")
		equal(state:snapshot(USER).ember, 0, "a fresh session profile, not the saved one")
		store:failAll(nil)
		state.players["n:" .. USER].ember = 999
		clock.t += 600
		save:step(); save:step()
		equal(save:leave(USER), "Unsaved")
		save:closeAll(5)
		equal(store:raw(KEY), before, "the real record is untouched"); equal(#store.writes, 0)
	end)

	case("SV-4: a record locked by another live server plays unsaved and is never overwritten", function()
		local store, clock, server = world()
		local record = Record.blank(); record.ember = 77
		store:seed(KEY, record, { LockId = "B" }, clock.t - 10)
		local before = store:raw(KEY)
		local save, state = server("A")
		local mode, outcome = save:join(USER, 0)
		equal(mode, "Unsaved"); equal(outcome, "LockedElsewhere")
		state.players["n:" .. USER].ember = 1
		save:step(); save:leave(USER); save:closeAll(5)
		equal(store:raw(KEY), before); equal(store:metadata(KEY).LockId, "B", "the other server keeps its lock")
	end)

	case("SV-5: a stale lock (no update for LOCK_EXPIRY) is taken over", function()
		local store, clock, server = world()
		local record = Record.blank(); record.ember = 12
		store:seed(KEY, record, { LockId = "Crashed" }, clock.t - Persistence.LOCK_EXPIRY - 1)
		local save, state = server("A")
		equal((save:join(USER, 0)), "Saved")
		equal(state:snapshot(USER).ember, 12)
		equal(store:metadata(KEY).LockId, "A")
	end)

	case("SV-6: session IDs get durable IDs once; the companion and its bond follow; a rejoin loads the same IDs", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		bankEgg(state, "egg:1")
		local egg = state:snapshot(USER).bankedEggs[2].uid
		assert(string.sub(egg, 1, 3) == "wb:", "State made a session ID: " .. egg)
		local ok, pet = state:hatch(USER, egg, true, 0)
		assert(ok, "hatched")
		assert(state:equip(USER, pet, true))
		state.players["n:" .. USER].bond[pet] = { xp = 6, level = 1 }
		clock.t += 200
		save:step()
		local first = stored(store)
		local saved = first.collection.registered[2].uid
		assert(Record.uidNumber(saved), "a durable ID was saved: " .. tostring(saved))
		equal(first.equippedUid, saved, "the companion uses the same durable ID")
		equal(first.bondXp[saved], 6)
		state.players["n:" .. USER].ember += 1
		clock.t += 200
		save:step()
		equal(stored(store).collection.registered[2].uid, saved, "the same session ID keeps its durable ID")
		save:leave(USER)
		equal(store:metadata(KEY).LockId, nil, "the leave released the lock")
		local again, state2 = server("B")
		equal((again:join(USER, 0)), "Saved")
		local snapshot = state2:snapshot(USER)
		equal(snapshot.registered[2].uid, saved); equal(snapshot.equippedUid, saved)
		equal(snapshot.bond[saved].xp, 6)
	end)

	case("SV-7: carried things are never saved: the bag egg, the pouch and the carry slot are lost on leaving", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		state:registerEncounter("egg:bag", "Egg")
		assert(state:pickup(USER, "egg:bag", true, 5), "an egg in the bag")
		local profile = state.players["n:" .. USER]
		profile.carried.fogbark = 3
		save:leave(USER)
		local saved = stored(store)
		equal(saved.atRisk, nil)
		equal(#saved.collection.bankedEggs, 1, "only the egg banked before")
		equal(saved.banked.fogbark, 7, "the pouch is not banked by a leave")
		local again, state2 = server("B")
		again:join(USER, 0)
		local snapshot = state2:snapshot(USER)
		equal(#snapshot.pending, 0); equal(snapshot.carried.fogbark, 0); equal(snapshot.carrying, nil)
	end)

	case("SV-8: autosave writes only a changed profile, about once a minute, and waits while the budget is low", function()
		local store, clock, server = world()
		seed(store, clock)
		local budget = { left = 100 }
		local save, state = server("A", { budget = function() return budget.left end })
		save:join(USER, 0)
		local writes = #store.writes
		clock.t += Persistence.AUTOSAVE + 1
		save:step()
		equal(#store.writes, writes, "clean: nothing written")
		state.players["n:" .. USER].ember = 60
		budget.left = Save.BUDGET_FLOOR - 1
		clock.t += Persistence.AUTOSAVE + 1
		save:step()
		equal(#store.writes, writes, "a low budget defers the autosave")
		equal(save.deferred, 1)
		budget.left = 100
		save:step()
		equal(#store.writes, writes + 1, "written once the budget is back")
		equal(stored(store).ember, 60)
		save:step()
		equal(#store.writes, writes + 1, "not again until the next autosave")
	end)

	case("SV-9: closing writes every saving player once and releases every lock", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		save:join(USER + 1, 0)
		state.players["n:" .. USER].ember = 61
		local report = save:closeAll(25)
		equal(report.saved, 2); equal(#report.failed, 0)
		equal(stored(store).ember, 61)
		equal(store:metadata(KEY).LockId, nil); equal(store:metadata("Player_1002").LockId, nil)
	end)

	case("SV-10: an incubating egg keeps its server times and hatches on rejoin once its time has passed", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		local egg = state:snapshot(USER).bankedEggs[1].uid
		assert(state:incubate(USER, egg, true, 0, clock.t, 90, 1))
		save:leave(USER)
		local saved = stored(store)
		equal(#saved.incubating, 1); equal(saved.incubating[1].readyAtUnix, clock.t + 90)
		equal(#saved.collection.bankedEggs, 0)
		clock.t += 300
		local again, state2 = server("B")
		again:join(USER, 0)
		local hatched = state2:hatchReady(USER, clock.t)
		equal(#hatched, 1, "hatched by the server clock while away")
		equal(#state2:snapshot(USER).registered, 2)
	end)

	case("SV-11: an unversioned (version 0) value migrates and loads", function()
		local store, clock, server = world()
		store:seed(KEY, { ember = 5, collection = { registered = { { uid = "u3", species = "Lumipol" } }, bankedEggs = {} } },
			{}, clock.t - 1000)
		local save, state = server("A")
		local mode, outcome = save:join(USER, 0)
		equal(mode, "Saved"); equal(outcome, "Loaded")
		equal(state:snapshot(USER).ember, 5); equal(state:snapshot(USER).registered[1].uid, "u3")
		equal(stored(store).schema, Record.SCHEMA, "the claim wrote the migrated value")
	end)

	case("SV-12: saving off keeps the old session-only game", function()
		local state = State.new(Economy, Config)
		local save = Save.new({ persistence = nil, state = state, record = Record })
		equal((save:join(USER, 0)), "Off")
		assert(state:snapshot(USER))
		equal(save:isSaving(USER), false)
		equal(save:leave(USER), "Off")
	end)

	case("SV-13: the memory port keeps values, metadata and times, cancels on nil, and fails on request", function()
		local now = { t = 100 }
		local port = Store.memory(function() return now.t end)
		local ok, value, info = port:read("k")
		equal(ok, true); equal(value, nil); equal(info, nil)
		ok, value = port:update("k", function(current, i)
			equal(current, nil); equal(type(i.metadata), "table")
			return { a = 1 }, { LockId = "S" }
		end)
		equal(ok, true); equal(value.a, 1)
		now.t = 130
		ok, value, info = port:read("k")
		equal(value.a, 1); equal(info.metadata.LockId, "S"); equal(info.updatedAt, 100)
		ok = port:update("k", function() return nil end)
		equal(ok, true); equal(port.writes, 1, "a cancelled update writes nothing")
		port:failNext(1)
		local failed, kind = port:update("k", function() return { a = 2 } end)
		equal(failed, false); equal(kind, "Error")
		equal(port:read("k") and select(2, port:read("k")).a, 1)
	end)

	-- A fake DataStoreService: UpdateAsync with (value, keyInfo), keyInfo.UpdatedTime in milliseconds.
	local function fakeService(options)
		options = options or {}
		local service = { calls = {}, entries = {}, budgetCalls = 0 }
		local function keyInfo(entry)
			return { UpdatedTime = entry.updated, GetMetadata = function() return table.clone(entry.metadata) end }
		end
		function service:GetDataStore(name)
			table.insert(self.calls, "GetDataStore:" .. name)
			if options.openError then error(options.openError) end
			local store = {}
			function store.UpdateAsync(_, key, transform)
				if options.updateError then error(options.updateError) end
				local entry = service.entries[key]
				local value, userIds, metadata = transform(entry and entry.value, entry and keyInfo(entry) or nil)
				if value == nil then return entry and entry.value, entry and keyInfo(entry) end
				service.entries[key] = { value = value, metadata = metadata or {}, updated = 1700000000123, userIds = userIds }
				return value, keyInfo(service.entries[key])
			end
			function store.GetAsync(_, key)
				if options.readError then error(options.readError) end
				local entry = service.entries[key]
				return entry and entry.value, entry and keyInfo(entry)
			end
			return store
		end
		function service:GetRequestBudgetForRequestType(kind)
			self.budgetCalls += 1
			self.lastKind = kind
			return 42
		end
		return service
	end

	case("SV-14: the data store port: lock metadata out and in, UpdatedTime in seconds, the player's UserId, budget", function()
		local service = fakeService()
		local port = Store.roblox(service, "Test", "UpdateAsync")
		local ok, value, info = port:update(KEY, function(current, i)
			equal(current, nil); equal(i.updatedAt, nil)
			return { ember = 3 }, { LockId = "S" }
		end)
		equal(ok, true); equal(value.ember, 3)
		equal(info.updatedAt, 1700000000.123, "milliseconds become seconds")
		equal(service.entries[KEY].userIds[1], USER, "the save is tagged with its player")
		equal(service.entries[KEY].metadata.LockId, "S")
		local seen
		port:update(KEY, function(current, i) seen = i; equal(current.ember, 3); return nil end)
		equal(seen.metadata.LockId, "S"); equal(seen.updatedAt, 1700000000.123)
		local readOk, readValue, readInfo = port:read(KEY)
		equal(readOk, true); equal(readValue.ember, 3); equal(readInfo.metadata.LockId, "S")
		equal(port:budget(), 42); equal(service.lastKind, "UpdateAsync")
	end)

	case("SV-15: data store errors become failures Persistence retries; an access error is NoAccess", function()
		local port = Store.roblox(fakeService({ updateError = "502: API Services rejected request" }), "T", "U")
		local ok, kind = port:update(KEY, function() return {} end)
		equal(ok, false); equal(kind, "NoAccess")
		port = Store.roblox(fakeService({ readError = "Request was throttled" }), "T", "U")
		ok, kind = port:read(KEY)
		equal(ok, false); equal(kind, "Throttled")
		equal(Store.errorKind("something else"), "Error")
	end)

	case("SV-16: Store.open: off, memory, Studio without access falls back to memory, live keeps the data store", function()
		equal((Store.open({ mode = "off" })), nil)
		local port, label = Store.open({ mode = "memory" })
		equal(label, "memory"); assert(port and port.update, "a memory port")
		local studioPort, studioLabel, reason = Store.open({ mode = "datastore", isStudio = true,
			service = fakeService({ readError = "Studio access to API services is not enabled" }), requestType = "U" })
		equal(studioLabel, "memory"); assert(studioPort.failNext, "the memory port"); assert(reason and #reason > 0)
		local live, liveLabel = Store.open({ mode = "datastore", isStudio = false,
			service = fakeService({ readError = "Studio access to API services is not enabled" }), requestType = "U" })
		equal(liveLabel, "datastore"); assert(live and not live.failNext, "live servers keep the real port")
		local ok, okLabel = Store.open({ mode = "datastore", isStudio = true, service = fakeService(), requestType = "U" })
		equal(okLabel, "datastore"); assert(ok)
	end)

	case("SV-17: a leave right after a join releases the lock (a player who left while loading)", function()
		local store, _, server = world()
		local save = server("A")
		save:join(USER, 0)
		equal(save:leave(USER), "Releasing")
		equal(store:metadata(KEY).LockId, nil)
		equal(save:mode(USER), nil)
	end)

	case("SV-18: source checks: only the store adapter names the data store service; the server wires WildboundSave", function()
		for _, name in ipairs({ "save", "persistence", "record", "server" }) do
			local text = sources[name]
			assert(type(text) == "string" and #text > 0, name .. " source passed")
			assert(not string.find(text, "DataStoreService", 1, true), name .. " names DataStoreService")
			assert(not string.find(text, "UpdateAsync", 1, true), name .. " calls UpdateAsync")
		end
		assert(string.find(sources.store, "DataStoreService", 1, true), "the adapter names the service")
		assert(string.find(sources.server, "WildboundSave", 1, true), "the server requires WildboundSave")
		assert(string.find(sources.server, "WildboundStoreRoblox", 1, true), "the server opens the store")
		assert(string.find(sources.server, ":closeAll(", 1, true), "BindToClose flushes the saves")
		assert(string.find(sources.server, ":leave(player.UserId)", 1, true), "PlayerRemoving saves and releases")
		assert(not string.find(sources.save, "SetAsync", 1, true), "never SetAsync")
		assert(not string.find(sources.store, "SetAsync", 1, true), "never SetAsync in the adapter")
	end)

	case("SV-21: gloves are saved with durable IDs and the worn one, and load back the same", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		local profile = state.players["n:" .. USER]
		profile.banked.fogbark, profile.banked.glowmoss = 99, 99
		local ok, glove = state:craftGear(USER, "guantes", true, 0, { rarity = "Epica", stats = { move = 2, burst = 14, calm = 20 } })
		assert(ok, "crafted: " .. tostring(glove))
		save:leave(USER)
		local saved = stored(store)
		equal(#saved.gloves.owned, 1)
		local uid = saved.gloves.owned[1].uid
		assert(Record.uidNumber(uid), "a durable glove ID: " .. tostring(uid))
		equal(saved.gloves.equippedUid, uid); equal(saved.gloves.owned[1].stats.burst, 14)
		local again, state2 = server("B")
		again:join(USER, 0)
		local snapshot = state2:snapshot(USER)
		equal(snapshot.equippedGlove, uid); equal(snapshot.glove.stats.calm, 20); equal(snapshot.glove.rarity, "Epica")
	end)

	case("SV-19: the autosave loop steps every STEP_SECONDS until stopped", function()
		local store, clock, server = world()
		seed(store, clock)
		local save, state = server("A")
		save:join(USER, 0)
		state.players["n:" .. USER].ember = 80
		clock.t += Persistence.AUTOSAVE + 1
		local waits = {}
		save.wait = function(seconds)
			table.insert(waits, seconds)
			if #waits >= 2 then save.stopped = true end
		end
		save:run()
		equal(waits[1], Save.STEP_SECONDS)
		equal(stored(store).ember, 80, "the first step wrote the change")
		equal(#waits, 2, "and the loop stopped")
	end)

	case("SV-20: the player words say the collection is saved and what is carried is not", function()
		for _, name in ipairs({ "text", "startView", "campView" }) do
			local text = sources[name]
			assert(type(text) == "string" and #text > 0, name .. " source passed")
			assert(not string.find(text, "se pierde al salir del servidor", 1, true), name .. " still says all is lost")
			assert(not string.find(text, "El progreso no se guarda", 1, true), name .. " still says nothing is saved")
		end
		assert(string.find(sources.startView, "se guarda", 1, true), "the start screen says what is saved")
	end)

	return result
end
