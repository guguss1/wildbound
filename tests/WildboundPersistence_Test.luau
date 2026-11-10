-- Invoke with require(freshTestClone)(require(freshPersistenceClone), require(freshRecordClone), require(freshFakeClone),
-- require(freshEconomyClone), require(freshConfigClone), { persistence = freshPersistenceClone.Source,
-- record = freshRecordClone.Source, server = WildboundServer.Source }). Session lock, load guard, autosave, leave,
-- close and the write-first commit (W10, M6.2), all against the in-memory fake store with an injected clock.
-- F and D numbers refer to docs/mechanics/wildbound-persistence.md section 8. Green here proves logic only, never
-- Roblox behavior: no real data store is called (section 10, D8).
return function(Persistence, Record, Fake, Economy, Config, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local KEY = "Player_1"
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
	local function deepEqual(a, b, path)
		path = path or "root"
		if type(a) ~= "table" or type(b) ~= "table" then
			assert(a == b, path .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
			return
		end
		for k, v in pairs(a) do deepEqual(v, b[k], path .. "." .. tostring(k)) end
		for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. ": missing") end
	end
	local function contains(list, value)
		for _, item in ipairs(list) do if item == value then return true end end
		return false
	end

	local function setup()
		local clock = { t = 1000000, waited = 0 }
		local store = Fake.new({ clock = function() return clock.t end, wait = function(s) clock.t += s end })
		local statuses = {}
		local function server(id, extra)
			local options = {
				store = store, serverId = id, record = Record, economy = Economy, config = Config,
				clock = function() return clock.t end,
				wait = function(seconds)
					clock.waited += seconds
					clock.t += seconds
					local hook = clock.onWait
					clock.onWait = nil
					if hook then hook() end
				end,
				random = function() return 0.5 end,
				spawn = function(fn) fn() end,
				onStatus = function(key, status)
					table.insert(statuses, { server = id, key = key, status = status, writes = #store.writes })
				end,
			}
			for k, v in pairs(extra or {}) do options[k] = v end
			return Persistence.new(options)
		end
		return store, clock, server, statuses
	end
	local function seedRecord()
		local record = Record.blank()
		record.revision = 5
		record.nextUid = 3
		record.collection.registered = { { uid = "u1", species = "Lumipol" } }
		record.collection.bankedEggs = { { uid = "u2", species = "Lumipol" } }
		record.ember = 10
		return record
	end
	local function statusesFor(statuses, id)
		local list = {}
		for _, entry in ipairs(statuses) do if entry.server == id then table.insert(list, entry.status) end end
		return list
	end
	local function hatch(record, op)
		for index, egg in ipairs(record.collection.bankedEggs) do
			if egg.uid == op.payload.egg then
				table.remove(record.collection.bankedEggs, index)
				table.insert(record.collection.registered, { uid = op.payload.pet, species = egg.species })
				return record
			end
		end
		return nil
	end
	local function hatchOp(manager)
		return manager:newOp(KEY, "hatch", function(allocate) return { egg = "u2", pet = allocate() } end)
	end

	case("PS-1: F1.1 a load that throws every time gives Unavailable, no profile and no write", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local before = store:raw(KEY)
		store:failAll("Error")
		local a = server("A")
		local outcome, profile = a:load(KEY, 0)
		equal(outcome, "Unavailable"); equal(profile, nil)
		equal(store:raw(KEY), before); equal(#store.writes, 0)
		equal(store.calls, Persistence.MAX_ATTEMPTS)
		assert(clock.waited < 20, "automatic attempts fit in about 20 s, waited " .. clock.waited)
		equal(a:info(KEY).loaded, false); equal(a:info(KEY).saveStatus, "Off")
	end)

	case("PS-2: F1.2 ten minutes of unsaved play, a leave and a close write nothing", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local before = store:raw(KEY)
		store:failAll("Error")
		local a = server("A")
		equal((a:load(KEY, 0)), "Unavailable")
		store:failAll(nil)
		local unsaved = Record.toProfile(Record.blank(), Economy, Config, 0)
		local function provider() return unsaved, {} end
		for _ = 1, 20 do
			clock.t += 30
			unsaved.ember += 5
			a:markDirty(KEY)
			a:tick(provider)
		end
		equal(a:checkpoint(KEY, unsaved, {}), "NotLoaded")
		equal(a:release(KEY, unsaved, {}), "NotLoaded")
		a:closeAll(provider, 25)
		equal(#store.writes, 0); equal(store:raw(KEY), before)
	end)

	case("PS-3: F1.3 a load that times out is Unavailable, never New", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		store:failAll("Timeout")
		local outcome, profile = server("A"):load(KEY, 0)
		equal(outcome, "Unavailable"); equal(profile, nil); equal(#store.writes, 0)
	end)

	case("PS-4: F1.4 only a confirmed absent value is New, with one write that takes the lock", function()
		local store, _, server = setup()
		local a = server("A")
		local outcome, profile = a:load(KEY, 0)
		equal(outcome, "New")
		deepEqual(profile, Record.toProfile(Record.blank(), Economy, Config, 0))
		equal(#store.writes, 1)
		equal(store:metadata(KEY).LockId, "A")
		equal(a:info(KEY).loaded, true)
	end)

	case("PS-5: F1.5 malformed values are quarantined with no write and no retry", function()
		local store, _, server = setup()
		store:seedRaw(KEY, "{\"schema\":1,\"ember\":\"lots\"}")
		local before = store:raw(KEY)
		local a = server("A")
		equal((a:load(KEY, 0)), "Quarantined")
		equal(store:raw(KEY), before); equal(#store.writes, 0); equal(store.calls, 1)
		equal(a.counters.quarantined, 1)
		local duplicate = seedRecord()
		duplicate.collection.bankedEggs[1].uid = "u1"
		store:seed("Player_2", duplicate, {}, 0)
		local beforeDuplicate = store:raw("Player_2")
		equal((a:load("Player_2", 0)), "Quarantined")
		equal(store:raw("Player_2"), beforeDuplicate)
		equal(a:info("Player_2").saveStatus, "Off")
	end)

	case("PS-6: F1.6 a record from a newer schema is TooNew with no write", function()
		local store, _, server = setup()
		local newer = seedRecord(); newer.schema = Record.SCHEMA + 1
		store:seed(KEY, newer, {}, 0)
		local before = store:raw(KEY)
		equal((server("A"):load(KEY, 0)), "TooNew")
		equal(store:raw(KEY), before); equal(#store.writes, 0)
	end)

	case("PS-7: F1.7 a failed load, unsaved play, then Try again loads the real record and merges nothing", function()
		local store, clock, server = setup()
		local seed = seedRecord()
		store:seed(KEY, seed, {}, clock.t - 1000)
		store:script({ "throwBefore", "throwBefore", "throwBefore" })
		local a = server("A")
		equal((a:load(KEY, 0)), "Unavailable")
		local unsaved = Record.toProfile(Record.blank(), Economy, Config, 0)
		unsaved.ember = 999
		local outcome, profile = a:load(KEY, 0)
		equal(outcome, "Loaded")
		equal(profile.ember, 10, "the real record, not the unsaved play")
		local _, stored = store:read(KEY)
		deepEqual(stored, seed)
		equal(store:metadata(KEY).LockId, "A")
	end)

	case("PS-8: F1.8 a migration that throws quarantines and leaves the bytes alone", function()
		local store, _, server = setup()
		store:seedRaw(KEY, "{\"collection\":{\"registered\":[],\"bankedEggs\":[]},\"ember\":3}")
		local before = store:raw(KEY)
		local a = server("A", { migrations = { [0] = function() error("broken step") end } })
		equal((a:load(KEY, 0)), "Quarantined")
		equal(store:raw(KEY), before); equal(#store.writes, 0)
		local b = server("B")
		equal((b:load(KEY, 0)), "Loaded", "the shipped ladder migrates the unversioned shape")
	end)

	case("PS-9: F1.9 a failing autosave pauses without a success notice, and a later one succeeds", function()
		local store, clock, server, statuses = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		local function provider() return profile, {} end
		profile.ember = 55
		a:markDirty(KEY)
		store:failAll("Error")
		clock.t += Persistence.AUTOSAVE
		a:tick(provider)
		equal(a:info(KEY).saveStatus, "Paused")
		equal(a:info(KEY).dirty, true)
		assert(not contains(statusesFor(statuses, "A"), "Saved"), "no success while the save fails")
		store:failAll(nil)
		clock.t += Persistence.AUTOSAVE
		a:tick(provider)
		equal(a:info(KEY).saveStatus, "Saved")
		local _, stored = store:read(KEY)
		equal(stored.ember, 55)
	end)

	case("PS-10: F1.10 a commit that finds a foreign lock is LockLost, never retried, and the session is revoked", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		store:update(KEY, function(value) return value, { LockId = "B" } end)
		local calls, writes = store.calls, #store.writes
		equal(a:checkpoint(KEY, profile, {}), "LockLost")
		equal(store.calls, calls + 1, "no retry after LockLost")
		equal(a:info(KEY).revoked, true)
		equal(a.counters.lockLost, 1)
		a:markDirty(KEY)
		clock.t += 600
		a:tick(function() return profile, {} end)
		equal(a:release(KEY, profile, {}), "NotLoaded")
		equal(a:commit(KEY, hatchOp(a), hatch), "NotLoaded")
		equal(#store.writes, writes)
		equal(store:metadata(KEY).LockId, "B")
	end)

	case("PS-11: F5.1 a second server meets a fresh lock: LockedElsewhere, no write", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		equal((server("A"):load(KEY, 0)), "Loaded")
		local writes = #store.writes
		local outcome, profile = server("B"):load(KEY, 0)
		equal(outcome, "LockedElsewhere"); equal(profile, nil)
		equal(#store.writes, writes)
		equal(store:metadata(KEY).LockId, "A")
	end)

	case("PS-12: F5.8 and F5.2 a lock is refused at 299 s and taken at 300 s; the old holder is then LockLost", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profileA = a:load(KEY, 0)
		local takenAt = clock.t
		local b = server("B", { maxAttempts = 1 })
		clock.t = takenAt + Persistence.LOCK_EXPIRY - 1
		equal((b:load(KEY, 0)), "LockedElsewhere")
		clock.t = takenAt + Persistence.LOCK_EXPIRY
		equal((b:load(KEY, 0)), "Loaded")
		profileA.ember = 500
		equal(a:checkpoint(KEY, profileA, {}), "LockLost")
		local _, stored = store:read(KEY)
		equal(stored.ember, 10, "B's record stands")
		equal(store:metadata(KEY).LockId, "B")
	end)

	case("PS-13: F5.3 a delayed write that arrives after the takeover is ignored", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profileA = a:load(KEY, 0)
		clock.t += Persistence.LOCK_EXPIRY
		local b = server("B")
		store:script({ { delay = 3, before = function() b:load(KEY, 0) end } })
		profileA.ember = 777
		equal(a:checkpoint(KEY, profileA, {}), "LockLost")
		local _, stored = store:read(KEY)
		equal(stored.ember, 10)
		equal(store:metadata(KEY).LockId, "B")
	end)

	case("PS-14: F5.4 a stale snapshot is rejected by revision: no union of lists, no resurrected egg", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profileA = a:load(KEY, 0)
		store:update(KEY, function(value, info)
			value.revision += 1
			value.collection.bankedEggs = {}
			return value, info.metadata
		end)
		local writes = #store.writes
		equal(a:checkpoint(KEY, profileA, {}), "Diverged")
		equal(#store.writes, writes)
		local _, stored = store:read(KEY)
		equal(#stored.collection.bankedEggs, 0, "the egg is not brought back")
		equal(a:info(KEY).revoked, true)
	end)

	case("PS-15: F5.5 a claim during the old server's final write waits and then gets that result", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profileA = a:load(KEY, 0)
		profileA.ember = 77
		local b = server("B")
		clock.onWait = function() equal(a:release(KEY, profileA, {}), "Released") end
		local outcome, profileB = b:load(KEY, 0)
		equal(outcome, "Loaded")
		equal(profileB.ember, 77)
		equal(store:metadata(KEY).LockId, "B")
	end)

	case("PS-16: F5.7 a failed release self-heals at exactly the expiry, not before", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profileA = a:load(KEY, 0)
		local lastWrite = clock.t
		store:failAll("Error")
		equal(a:release(KEY, profileA, {}), "Failed")
		equal(a:info(KEY), nil, "the player is gone from this server either way")
		store:failAll(nil)
		local b = server("B", { maxAttempts = 1 })
		clock.t = lastWrite + Persistence.LOCK_EXPIRY - 1
		equal((b:load(KEY, 0)), "LockedElsewhere")
		clock.t = lastWrite + Persistence.LOCK_EXPIRY
		equal((b:load(KEY, 0)), "Loaded")
	end)

	case("PS-17: autosave runs on its interval with a random first offset, skips clean profiles and refreshes the lock", function()
		local store, clock, server = setup()
		local a = server("A")
		local loadedAt = clock.t
		local _, profile = a:load(KEY, 0)
		local function provider() return profile, {} end
		equal(#store.writes, 1)
		a:markDirty(KEY)
		clock.t = loadedAt + Persistence.AUTOSAVE * 0.5 - 1
		a:tick(provider)
		equal(#store.writes, 1, "not due yet")
		clock.t = loadedAt + Persistence.AUTOSAVE * 0.5
		a:tick(provider)
		equal(#store.writes, 2, "first autosave at the random offset")
		equal(a:info(KEY).dirty, false)
		clock.t += Persistence.AUTOSAVE
		a:tick(provider)
		equal(#store.writes, 2, "clean and lock still fresh: skipped")
		clock.t += Persistence.AUTOSAVE
		a:tick(provider)
		equal(#store.writes, 2, "120 s since the last write is still fresh")
		clock.t += Persistence.AUTOSAVE
		a:tick(provider)
		equal(#store.writes, 3, "refreshed before half the expiry has passed twice")
		assert(Persistence.REFRESH_AFTER * 2 <= Persistence.LOCK_EXPIRY, "refresh well inside the expiry")
		assert(Persistence.AUTOSAVE < Persistence.LOCK_EXPIRY, "autosave more often than the expiry")
	end)

	-- NS2 (user rule): a carried egg is never saved, not even at a leave. Deliberately changed pins in PS-18 and PS-19.
	case("PS-18: leaving writes a final record and releases the lock; a bag egg is not saved", function()
		local store, clock, server = setup()
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		local uid = a:allocateUid(KEY)
		equal(uid, "u1", "grants take durable IDs from the saved counter (B17)")
		profile.pending = { { uid = uid, kind = "Egg", species = "Lumipol", protected = false, riskTier = "Territory" } }
		equal(a:release(KEY, profile, { nowUnix = clock.t }), "Released")
		local _, stored = store:read(KEY)
		equal(stored.atRisk, nil, "the bag egg is lost with the leave, never saved")
		equal(store:metadata(KEY).LockId, nil)
		equal(a:info(KEY), nil)
		local writes = #store.writes
		equal(a:release(KEY, profile, {}), "NotLoaded")
		equal(#store.writes, writes)
		local _, again = a:load("Player_2", 0)
		equal(a:release("Player_2", again, {}), "Released")
		local _, calm = store:read("Player_2")
		equal(calm.atRisk, nil, "nothing at risk, nothing to expire")
	end)

	case("PS-19: D10.7 closing writes one final record per player, releases every lock and saves nothing at risk", function()
		local store, _, server = setup()
		local a = server("A")
		local profiles = {}
		for n = 1, 3 do
			local key = "Player_" .. n
			local _, profile = a:load(key, 0)
			profiles[key] = profile
		end
		profiles.Player_2.carried.fogbark = 4
		local writes = #store.writes
		local report = a:closeAll(function(key) return profiles[key], {} end, 25)
		equal(report.saved, 3); equal(#report.failed, 0)
		equal(#store.writes, writes + 3)
		for n = 1, 3 do equal(store:metadata("Player_" .. n).LockId, nil) end
		local _, two = store:read("Player_2")
		equal(two.atRisk, nil, "the pouch is never saved")
		equal(two.banked.fogbark, 0, "and never banked by a close")
	end)

	case("PS-20: closing keeps to its time budget when the store keeps failing", function()
		local store, clock, server = setup()
		local a = server("A")
		local profiles = {}
		for n = 1, 2 do
			local _, profile = a:load("Player_" .. n, 0)
			profiles["Player_" .. n] = profile
		end
		store:failAll("Error")
		local started = clock.t
		local report = a:closeAll(function(key) return profiles[key], {} end, 25)
		assert(clock.t - started <= 25, "closed within the budget, took " .. (clock.t - started))
		equal(report.saved, 0); equal(#report.failed, 2)
	end)

	case("PS-21: a record over the size budget is never sent", function()
		local store, _, server = setup()
		local a = server("A", { maxChars = 2000 })
		local _, profile = a:load(KEY, 0)
		for n = 1, 90 do profile.registered[n] = { uid = a:allocateUid(KEY), species = "Lumipol" } end
		local calls = store.calls
		equal(a:checkpoint(KEY, profile, {}), "TooLarge")
		equal(store.calls, calls)
		equal(a:info(KEY).saveStatus, "Paused")
		equal(Persistence.MAX_CHARS, 4194304)
	end)

	case("PS-22: F3.1 a hatch that fails before the write changes nothing and claims nothing", function()
		local store, clock, server, statuses = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		a:load(KEY, 0)
		local before = store:raw(KEY)
		store:script({ "throwBefore", "throwBefore", "throwBefore" })
		local outcome = a:commit(KEY, hatchOp(a), hatch)
		equal(outcome, "NotWritten")
		equal(store:raw(KEY), before)
		assert(not contains(statusesFor(statuses, "A"), "Saved"), "no success claim")
		equal(a:info(KEY).saveStatus, "Paused")
	end)

	case("PS-30: a record that fails validation on the way out is never written", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		profile.registered[2] = { uid = "u1", species = "Lumipol" }
		local calls = store.calls
		equal(a:checkpoint(KEY, profile, {}), "Invalid")
		equal(store.calls, calls)
		equal(a:info(KEY).saveStatus, "Paused")
		profile.registered[2] = nil
		profile.registered[1] = { uid = "wb:1", species = "Lumipol" }
		equal(a:checkpoint(KEY, profile, {}), "Invalid", "a session ID is refused by the serializer")
		equal(store.calls, calls)
	end)

	case("PS-23: F3.2, F2.6 and F3.9 a lost reply is retried: one egg out, one pet in, one ID, success after the write", function()
		local store, clock, server, statuses = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		a:load(KEY, 0)
		local claimWrites = #store.writes
		local op = hatchOp(a)
		equal(op.payload.pet, "u3")
		store:script({ "commitThenThrow" })
		local outcome, record = a:commit(KEY, op, hatch)
		equal(outcome, "Committed")
		equal(#store.writes, claimWrites + 1, "exactly one write landed")
		equal(#record.collection.bankedEggs, 0)
		equal(#record.collection.registered, 2)
		equal(record.collection.registered[2].uid, "u3")
		equal(#record.ledger, 1); equal(record.ledger[1].id, op.id)
		equal(record.nextUid, 4)
		local saving, saved
		for _, entry in ipairs(statuses) do
			if entry.status == "Saving" and not saving then saving = entry end
			if entry.status == "Saved" and saving and not saved then saved = entry end
		end
		assert(saving and saved, "Saving then Saved were reported")
		equal(saving.writes, claimWrites, "Saving is reported before the write")
		assert(saved.writes > claimWrites, "Saved is reported only after the store confirmed")
	end)

	case("PS-24: F3.3 a lost reply with a failed read-back is Unknown, blocks other ops, and resolves to one award", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		local op = hatchOp(a)
		store:script({ "commitThenThrow", "throwBefore", "throwBefore" })
		store:scriptReads({ "throwBefore" })
		equal((a:commit(KEY, op, hatch)), "Unknown")
		equal(a:info(KEY).saveStatus, "Unknown")
		local calls = store.calls
		local other = a:newOp(KEY, "equip", function() return { uid = "u1" } end)
		equal((a:commit(KEY, other, function(record) record.equippedUid = "u1"; return record end)), "Unknown")
		equal(a:checkpoint(KEY, profile, {}), "Unknown")
		equal(store.calls, calls, "nothing is sent while an outcome is in doubt")
		local outcome, record = a:commit(KEY, op, hatch)
		equal(outcome, "Committed")
		equal(#record.collection.registered, 2); equal(#record.collection.bankedEggs, 0)
		equal(a:info(KEY).saveStatus, "Saved")
	end)

	case("PS-25: F4.1 and F4.2 the same op delivered twice has one effect and one write", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		a:load(KEY, 0)
		local op = hatchOp(a)
		local _, first = a:commit(KEY, op, hatch)
		local writes = #store.writes
		local outcome, second, alreadyApplied = a:commit(KEY, op, hatch)
		equal(outcome, "Committed"); equal(alreadyApplied, true)
		equal(#store.writes, writes)
		equal(second.revision, first.revision)
		equal(#second.collection.registered, 2)
	end)

	case("PS-26: F4.4 the same op ID with another payload is an OperationConflict with no second award", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		a:load(KEY, 0)
		local op = hatchOp(a)
		a:commit(KEY, op, hatch)
		local forged = { id = op.id, kind = op.kind, payload = { egg = "u2", pet = "u9" } }
		forged.digest = Record.digest(forged.kind, forged.payload)
		local writes = #store.writes
		equal((a:commit(KEY, forged, hatch)), "OperationConflict")
		equal(#store.writes, writes)
		equal(a.counters.operationConflicts, 1)
	end)

	case("PS-27: one write per player at a time: an autosave or checkpoint during a commit waits", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		local _, profile = a:load(KEY, 0)
		a:markDirty(KEY)
		local during
		store:script({ { before = function()
			clock.t += Persistence.AUTOSAVE
			a:tick(function() return profile, {} end)
			during = a:checkpoint(KEY, profile, {})
		end } })
		local writes = #store.writes
		equal((a:commit(KEY, hatchOp(a), hatch)), "Committed")
		equal(during, "Busy")
		equal(#store.writes, writes + 1)
		equal(a:info(KEY).dirty, true, "the skipped autosave stays due")
	end)

	case("PS-28: F2.2 a later session on another server continues the ID counter", function()
		local store, clock, server = setup()
		store:seed(KEY, seedRecord(), {}, clock.t - 1000)
		local a = server("A")
		a:load(KEY, 0)
		local _, record = a:commit(KEY, hatchOp(a), hatch)
		equal(a:release(KEY, Record.toProfile(record, Economy, Config, 0), {}), "Released")
		local b = server("B")
		equal((b:load(KEY, 0)), "Loaded")
		local op = b:newOp(KEY, "grant", function(allocate) return { uid = allocate() } end)
		equal(op.payload.uid, "u4")
		equal(op.id, "grant:2")
	end)

	-- NS1 (user approval 2026-11-10): the live server now wires saving through WildboundSave. Deliberately changed pin:
	-- "the live server does not load persistence" became "it loads it beside WildboundSave and names no data store".
	case("PS-29: source check: no data store service here; the live server saves only through WildboundSave", function()
		for name, text in pairs({ persistence = sources.persistence, record = sources.record }) do
			assert(type(text) == "string" and #text > 0, name .. " source passed")
			assert(not string.find(text, "DataStoreService", 1, true), name .. " names DataStoreService")
			assert(not string.find(text, "GetDataStore", 1, true), name .. " names GetDataStore")
		end
		assert(type(sources.server) == "string" and #sources.server > 0, "server source passed")
		assert(string.find(sources.server, "WildboundSave", 1, true), "the live server saves through WildboundSave")
		assert(not string.find(sources.server, "DataStoreService", 1, true), "the live server names no data store")
	end)

	return result
end
