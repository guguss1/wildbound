-- Invoke with require(freshTestClone)(require(freshRecordClone), require(freshEconomyClone), require(freshConfigClone),
-- require(freshStateClone), freshRecordClone.Source). Saved-progress record, schema 1 (W10, M6.1): blank record,
-- serializer to and from the State profile, validation, migration ladder, durable IDs, ledger and size.
-- F numbers refer to docs/mechanics/wildbound-persistence.md section 8. No data store is touched here.
return function(Record, Economy, Config, State, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local HttpService = game:GetService("HttpService")
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
		for k, v in pairs(b) do
			assert(a[k] ~= nil, path .. "." .. tostring(k) .. ": missing, expected " .. tostring(v))
		end
	end
	local function invalid(record, label)
		local ok, problems = Record.validate(record, Economy, Config)
		assert(ok == false, (label or "record") .. ": expected validation to fail")
		assert(type(problems) == "table" and #problems > 0, (label or "record") .. ": expected problems listed")
	end
	local function valid(record, label)
		local ok, problems = Record.validate(record, Economy, Config)
		assert(ok == true, (label or "record") .. ": " .. table.concat(problems or {}, "; "))
	end

	-- A full record that uses every section: two pets, a banked egg, a bag egg and a dropped creature.
	local function fixture()
		local record = Record.blank()
		record.nextUid = 6
		record.collection.registered = { { uid = "u1", species = "Lumipol" }, { uid = "u2", species = "Lumipol" } }
		record.collection.bankedEggs = { { uid = "u3", species = "Lumipol" } }
		record.equippedUid = "u1"
		record.bondXp = { u1 = 10 }
		record.ember = 40
		record.banked.fogbark = 5
		record.consumables.seal = 2
		record.ledger = { { id = "extract:1", kind = "extract", digest = "d1" } }
		record.nextOp = 2
		record.atRisk = {
			pending = { { uid = "u4", kind = "Egg", species = "Lumipol", riskTier = "Territory", wardSource = "Seal" } },
			carried = { fogbark = 3 },
			dropped = { { entry = { uid = "u5", kind = "Creature", species = "Lumipol", riskTier = "Fog" },
				expiresAtUnix = 1000030 } },
			sealArmed = false, totemActive = false, marks = 1, kUsed = 0,
			position = { x = 10, y = 3, z = -20 },
			expedition = { elapsedSeconds = 90, maxDistanceFromCamp = 120.5, paidSlots = { s1 = true },
				newUnits = 3, newItems = 1, bondXp = 0, bondEvents = {}, pendingBond = {} },
			checkpointAtUnix = 1000000, leftAtUnix = nil,
		}
		return record
	end

	local function stateProfile()
		local state = State.new(Economy, Config)
		state:addPlayer(1)
		return state.players["n:1"], state
	end

	case("RT-1: a blank record is schema 1, valid, starts every counter at 1 and holds nothing at risk", function()
		local record = Record.blank()
		equal(Record.SCHEMA, 1)
		equal(record.schema, 1)
		equal(record.revision, 0)
		equal(record.nextUid, 1); equal(record.nextTrip, 1); equal(record.nextOp, 1)
		equal(record.firstSealGranted, false)
		equal(record.atRisk, nil)
		equal(#record.ledger, 0)
		valid(record, "blank")
		local other = Record.blank()
		other.collection.registered[1] = { uid = "u1", species = "Lumipol" }
		equal(#record.collection.registered, 0, "two blanks never share tables")
	end)

	case("RT-2: a blank record loads into exactly the profile State:addPlayer makes", function()
		local expected = stateProfile()
		local loaded = Record.toProfile(Record.blank(), Economy, Config, 0)
		deepEqual(loaded, expected)
	end)

	case("RT-3: durable fields survive profile -> record -> profile, and bond level is recomputed", function()
		local profile = stateProfile()
		profile.registered = { { uid = "u1", species = "Lumipol" }, { uid = "u2", species = "Lumipol" } }
		profile.bankedEggs = { { uid = "u3", kind = "Egg", species = "Lumipol" } }
		profile.equippedUid = "u1"
		profile.bond = { u1 = { xp = 12, level = 99 } }
		profile.ember = 40
		profile.banked.fogbark = 5
		profile.consumables.seal = 2
		profile.upgrades.reinforcedPack = true
		profile.skills = { keenEyes = true }
		profile.earnedSeal = true
		local base = Record.blank(); base.nextUid = 4
		local record, reason = Record.fromProfile(profile, base, { nowUnix = 1000000 }, Economy, Config)
		assert(record, "serialized: " .. tostring(reason))
		valid(record, "serialized")
		equal(record.firstSealGranted, true)
		equal(record.bondXp.u1, 12)
		local back = Record.toProfile(record, Economy, Config, 0)
		deepEqual(back.registered, profile.registered)
		deepEqual(back.bankedEggs, profile.bankedEggs)
		equal(back.equippedUid, "u1"); equal(back.ember, 40); equal(back.banked.fogbark, 5)
		equal(back.consumables.seal, 2); equal(back.upgrades.reinforcedPack, true); equal(back.skills.keenEyes, true)
		equal(back.earnedSeal, true)
		equal(back.bond.u1.xp, 12)
		equal(back.bond.u1.level, Economy.bondLevel(Config, 12), "level comes from tuning, never from the save")
	end)

	case("RT-4: session values and derived values never enter the record", function()
		local profile = stateProfile()
		profile.registered = { { uid = "u1", species = "Lumipol" } }
		profile.bond = { u1 = { xp = 5, level = 1 } }
		profile.defeats = { ["life:0"] = true }; profile.defeatOrder = { "life:0" }
		profile.strikeDrops = { a1 = true }; profile.strikeOrder = { "a1" }
		local base = Record.blank(); base.nextUid = 2
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 1 }, Economy, Config))
		local text = HttpService:JSONEncode(record)
		-- stats.defeats is a designed counter, so the session tables are checked by key, not by text.
		equal(record.defeats, nil); equal(record.defeatOrder, nil)
		for _, banned in ipairs({ "strikeDrops", "strikeOrder", "\"level\"", "capacity",
			"sessionOnly", "\"bond\"", "protected", "wb:", "life:0" }) do
			assert(not string.find(text, banned, 1, true), "record must not hold " .. banned)
		end
		equal(record.atRisk, nil, "nothing out in the world")
	end)

	case("RT-5: what is out in the world is saved in atRisk and comes back with its wards and trip time", function()
		local profile = stateProfile()
		profile.pending = {
			{ uid = "u4", kind = "Egg", species = "Lumipol", protected = true, riskTier = "Territory", wardSource = "Seal" },
			{ uid = "u6", kind = "Nightbloom", quantity = 2, protected = false },
		}
		profile.dropped = { { uid = "u5", kind = "Creature", species = "Lumipol", protected = false, riskTier = "Fog" } }
		profile.carried.fogbark = 3
		profile.totemActive = true
		profile.expedition = { startedAt = 500, maxDistanceFromCamp = 80, paidSlots = { s1 = true }, newUnits = 3,
			newItems = 2, bondXp = 4, bondEvents = { pulseRevealInFog = 1 }, pendingBond = {} }
		local base = Record.blank(); base.nextUid = 7
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 2000, sessionNow = 590, leftAtUnix = 2000,
			marks = 1, kUsed = 1, position = { x = 1, y = 2, z = 3 }, droppedExpiry = { u5 = 2025 } }, Economy, Config))
		valid(record, "at risk")
		local risk = record.atRisk
		assert(risk, "atRisk written")
		equal(risk.pending[1].wardSource, "Seal"); equal(risk.pending[1].protected, nil)
		equal(risk.pending[2].quantity, 2)
		equal(risk.dropped[1].entry.uid, "u5"); equal(risk.dropped[1].expiresAtUnix, 2025)
		equal(risk.carried.fogbark, 3); equal(risk.totemActive, true)
		equal(risk.marks, 1); equal(risk.kUsed, 1); equal(risk.position.z, 3)
		equal(risk.checkpointAtUnix, 2000); equal(risk.leftAtUnix, 2000)
		equal(risk.expedition.elapsedSeconds, 90)
		equal(risk.expedition.startedAt, nil, "a server clock value is never saved")
		local back = Record.toProfile(record, Economy, Config, 10000)
		equal(back.pending[1].protected, true); equal(back.pending[1].wardSource, "Seal")
		equal(back.pending[2].protected, false)
		equal(back.dropped[1].uid, "u5")
		equal(back.carried.fogbark, 3); equal(back.totemActive, true)
		equal(back.expedition.startedAt, 10000 - 90)
		equal(back.expedition.paidSlots.s1, true); equal(back.expedition.bondEvents.pulseRevealInFog, 1)
	end)

	case("RT-6: a session ID (wb:N) is refused by the serializer, so B17 IDs can never be saved", function()
		local profile = stateProfile()
		profile.registered = { { uid = "wb:1", species = "Lumipol" } }
		local record, reason = Record.fromProfile(profile, Record.blank(), { nowUnix = 1 }, Economy, Config)
		equal(record, nil); equal(reason, "SessionId")
	end)

	case("RT-7: counters, ledger, stats, settings and unknown fields come from the loaded record", function()
		local base = fixture()
		base.futureField = { keep = "me" }
		base.settings = { reducedEffects = true }
		base.stats.extractions = 4
		local profile = Record.toProfile(base, Economy, Config, 0)
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 1000000, sessionNow = 0,
			droppedExpiry = { u5 = 1000030 } }, Economy, Config))
		equal(record.futureField.keep, "me")
		equal(record.settings.reducedEffects, true)
		equal(record.stats.extractions, 4)
		equal(record.nextUid, 6); equal(record.nextOp, 2)
		equal(record.ledger[1].id, "extract:1")
		base.ledger[1].id = "changed"
		equal(record.ledger[1].id, "extract:1", "the record is a detached copy")
	end)

	case("RT-8: validation rejects wrong types, NaN, infinity, fractions and negatives", function()
		valid(fixture(), "fixture")
		local r = fixture(); r.ember = "40"; invalid(r, "string ember")
		r = fixture(); r.ember = 0 / 0; invalid(r, "NaN ember")
		r = fixture(); r.ember = math.huge; invalid(r, "infinite ember")
		r = fixture(); r.ember = 1.5; invalid(r, "fraction ember")
		r = fixture(); r.banked.fogbark = -1; invalid(r, "negative banked")
		r = fixture(); r.consumables.seal = 0.5; invalid(r, "fraction consumable")
		r = fixture(); r.firstSealGranted = "yes"; invalid(r, "string flag")
		r = fixture(); r.collection = nil; invalid(r, "missing collection")
		r = fixture(); r.atRisk.marks = -1; invalid(r, "negative marks")
		r = fixture(); r.atRisk.position = { x = 0 / 0, y = 0, z = 0 }; invalid(r, "NaN position")
		r = fixture(); r.atRisk.pending[1].kind = "Dragon"; invalid(r, "unknown item kind")
		invalid("not a table", "string record")
	end)

	case("RT-9: F2.3 and F2.4 a UID used twice anywhere in the record is rejected", function()
		local r = fixture(); r.collection.bankedEggs[1].uid = "u1"; invalid(r, "registered and banked egg")
		r = fixture(); r.atRisk.pending[1].uid = "u2"; invalid(r, "pending and registered")
		r = fixture(); r.atRisk.dropped[1].entry.uid = "u3"; invalid(r, "dropped and banked egg")
		r = fixture(); r.collection.registered[2].uid = "u1"; invalid(r, "twice in registered")
	end)

	case("RT-10: F2.5 session IDs, malformed IDs and a counter at or below a used number are rejected", function()
		local r = fixture(); r.collection.registered[1].uid = "wb:1"; r.equippedUid = nil; r.bondXp = {}
		invalid(r, "wb:1")
		r = fixture(); r.collection.bankedEggs[1].uid = "u0"; invalid(r, "u0")
		r = fixture(); r.collection.bankedEggs[1].uid = "x3"; invalid(r, "x3")
		r = fixture(); r.collection.bankedEggs[1].uid = "u03"; invalid(r, "leading zero")
		r = fixture(); r.nextUid = 5; invalid(r, "nextUid equal to the highest used number")
		r = fixture(); r.nextUid = 6; valid(r, "nextUid one above the highest")
	end)

	case("RT-11: references must point at registered companions", function()
		local r = fixture(); r.equippedUid = "u3"; invalid(r, "equipped a banked egg")
		r = fixture(); r.bondXp = { u9 = 1 }; invalid(r, "bond for an unknown companion")
		r = fixture(); r.bondXp = { u2 = 1.5 }; invalid(r, "fractional bond")
	end)

	case("RT-12: limits: collection over the cap, ledger over 64, unknown tuning keys, wrong schema", function()
		local r = fixture()
		r.collection.registered = {}
		for n = 1, Config.capacity.collectionLimit + 1 do
			r.collection.registered[n] = { uid = "u" .. (n + 10), species = "Lumipol" }
		end
		r.nextUid = Config.capacity.collectionLimit + 20; r.equippedUid = nil; r.bondXp = {}
		invalid(r, "collection over the limit")
		r = fixture()
		for n = 1, Record.LEDGER_CAP + 1 do r.ledger[n] = { id = "craft:" .. n, kind = "craft", digest = "d" } end
		invalid(r, "ledger over its cap")
		r = fixture(); r.banked.gold = 1; invalid(r, "unknown material")
		r = fixture(); r.consumables.potion = 1; invalid(r, "unknown consumable")
		r = fixture(); r.upgrades.reinforcedPack = 1; invalid(r, "non-boolean upgrade")
		r = fixture(); r.schema = 2; invalid(r, "schema 2 is not valid for this server")
		r = fixture(); r.ledger[1].digest = nil; invalid(r, "ledger entry without digest")
	end)

	case("RT-13: migration ladder: current, too new, absent schema, throwing and invalid steps", function()
		local status, migrated = Record.migrate(fixture())
		equal(status, "Current"); equal(migrated.schema, 1)
		local newer = fixture(); newer.schema = 2
		status, migrated = Record.migrate(newer)
		equal(status, "TooNew"); equal(migrated, nil)
		local unversioned = { collection = { registered = { { uid = "u4", species = "Lumipol" } }, bankedEggs = {} },
			ember = 7 }
		status, migrated = Record.migrate(unversioned)
		equal(status, "Migrated")
		equal(migrated.schema, 1); equal(migrated.ember, 7); equal(migrated.nextUid, 5)
		equal(unversioned.schema, nil, "the input is never changed")
		valid(migrated, "migrated v0")
		status, migrated = Record.migrate(unversioned, { [0] = function() error("boom") end })
		equal(status, "Quarantined"); equal(migrated, nil)
		status = Record.migrate(unversioned, { [0] = function() return "not a table" end })
		equal(status, "Quarantined")
		status = Record.migrate(unversioned, {})
		equal(status, "Quarantined", "a missing step is a quarantine, never a guess")
		status = Record.migrate("text")
		equal(status, "Quarantined")
		local negative = fixture(); negative.schema = -1
		equal((Record.migrate(negative)), "Quarantined")
		local fraction = fixture(); fraction.schema = 1.5
		equal((Record.migrate(fraction)), "Quarantined")
	end)

	case("RT-14: the golden schema 1 fixture stays valid and survives a JSON round trip", function()
		local golden = HttpService:JSONDecode([[{"schema":1,"revision":42,"lastCommitId":"extract:31",
			"lastWriteId":"srv:1:9","nextUid":18,"nextTrip":8,"nextOp":32,"firstSealGranted":true,
			"collection":{"registered":[{"uid":"u12","species":"Lumipol"}],"bankedEggs":[{"uid":"u9","species":"Lumipol"}]},
			"equippedUid":"u12","banked":{"fogbark":0,"glowmoss":0,"nightbloom":0},"ember":0,
			"consumables":{"seal":0,"capsule":0,"totem":0},"upgrades":{"reinforcedPack":false},"skills":{},
			"bondXp":{"u12":0},"settings":{},"stats":{"tripsOpened":0,"extractions":0,"defeats":0,"firstPlayedDay":0},
			"ledger":[{"id":"extract:31","kind":"extract","digest":"x"}]}]])
		valid(golden, "golden v1")
		local status, migrated = Record.migrate(golden)
		equal(status, "Current")
		deepEqual(HttpService:JSONDecode(HttpService:JSONEncode(migrated)), golden)
	end)

	case("RT-15: F2.1 and F2.2 new IDs continue the saved counter and never collide", function()
		local record = fixture()
		equal(Record.allocateUid(record), "u6")
		equal(Record.allocateUid(record), "u7")
		equal(record.nextUid, 8)
		local copy = Record.copy(record)
		equal(Record.allocateUid(copy), "u8", "a later session continues from the saved counter")
	end)

	case("RT-16: F4.5 the ledger keeps the newest 64 entries and digests ignore key order", function()
		local record = Record.blank()
		for n = 1, 65 do Record.appendLedger(record, { id = "craft:" .. n, kind = "craft", digest = "d" .. n }) end
		equal(#record.ledger, Record.LEDGER_CAP)
		equal(record.ledger[1].id, "craft:2")
		equal(Record.findLedger(record, "craft:1"), nil)
		equal(Record.findLedger(record, "craft:65").digest, "d65")
		local a = Record.digest("hatch", { egg = "u3", pet = "u6" })
		local b = Record.digest("hatch", { pet = "u6", egg = "u3" })
		equal(a, b)
		assert(a ~= Record.digest("hatch", { egg = "u3", pet = "u7" }), "a different payload has a different digest")
		assert(a ~= Record.digest("extract", { egg = "u3", pet = "u6" }), "the kind is part of the digest")
	end)

	case("RT-17: a full collection stays far below the 4,194,304 character limit", function()
		equal(Record.MAX_CHARS, 4194304)
		local record = Record.blank()
		for n = 1, Config.capacity.collectionLimit do
			record.collection.registered[n] = { uid = "u" .. n, species = "Lumipol" }
			record.bondXp["u" .. n] = 999
		end
		record.nextUid = Config.capacity.collectionLimit + 1
		for n = 1, Record.LEDGER_CAP do Record.appendLedger(record, { id = "craft:" .. n, kind = "craft",
			digest = string.rep("f", 16) }) end
		valid(record, "full collection")
		local size = #HttpService:JSONEncode(record)
		assert(size < 20000, "expected under 20 KB, got " .. size)
	end)

	case("RT-18: source check: the record module never names the data store service", function()
		assert(type(source) == "string" and #source > 0, "source passed")
		assert(not string.find(source, "DataStoreService", 1, true), "no DataStoreService")
		assert(not string.find(source, "GetDataStore", 1, true), "no GetDataStore")
		assert(not string.find(source, "UpdateAsync", 1, true), "no UpdateAsync")
	end)

	return result
end
