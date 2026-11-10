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

	-- Nest Heist Phase 3 (NS1, NS2): schema 2 adds the incubator and the training levels and never holds atRisk.
	-- Deliberately changed pin: schema 1 -> 2.
	case("RT-1: a blank record is schema 2, valid, starts every counter at 1 and holds nothing at risk", function()
		local record = Record.blank()
		-- NS7: schema 3 adds the gloves (deliberately changed pin: 2 -> 3).
		equal(Record.SCHEMA, 3)
		equal(record.schema, 3)
		deepEqual(record.incubating, {}); deepEqual(record.training, {}); deepEqual(record.gloves, { owned = {} })
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

	-- NS2 (user rule, 2026-11-10): carried, unsecured things are never saved; a death or a leave loses them as before.
	-- Deliberately changed pin: RT-5 used to save them in atRisk.
	case("RT-5: what is out in the world is never saved and never comes back", function()
		local profile = stateProfile()
		profile.pending = {
			{ uid = "u4", kind = "Egg", species = "Lumipol", protected = true, riskTier = "Territory", wardSource = "Seal" },
			{ uid = "u6", kind = "Nightbloom", quantity = 2, protected = false },
		}
		profile.dropped = { { uid = "u5", kind = "Creature", species = "Lumipol", protected = false, riskTier = "Fog" } }
		profile.carried.fogbark = 3
		profile.totemActive = true
		profile.carrying = { uid = "wb:9", kind = "Creature", species = "Lumipol" }
		profile.expedition = { startedAt = 500, maxDistanceFromCamp = 80, paidSlots = { s1 = true }, newUnits = 3,
			newItems = 2, bondXp = 4, bondEvents = { pulseRevealInFog = 1 }, pendingBond = {} }
		local base = Record.blank(); base.nextUid = 7
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 2000, sessionNow = 590, leftAtUnix = 2000,
			marks = 1, kUsed = 1, position = { x = 1, y = 2, z = 3 }, droppedExpiry = { u5 = 2025 } }, Economy, Config))
		valid(record, "nothing at risk")
		equal(record.atRisk, nil, "no atRisk section")
		local text = HttpService:JSONEncode(record)
		for _, banned in ipairs({ "u4", "u5", "u6", "wb:9", "pending", "paidSlots" }) do
			assert(not string.find(text, banned, 1, true), "record must not hold " .. banned)
		end
		local legacy = fixture()
		local back = Record.toProfile(legacy, Economy, Config, 10000)
		equal(#back.pending, 0, "a legacy atRisk section is never restored")
		equal(#back.dropped, 0); equal(back.carried.fogbark, 0); equal(back.expedition, nil)
		equal(back.totemActive, false)
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
		r = fixture(); r.schema = Record.SCHEMA + 1; invalid(r, "a newer schema is not valid for this server")
		r = fixture(); r.ledger[1].digest = nil; invalid(r, "ledger entry without digest")
	end)

	case("RT-13: migration ladder: current, too new, absent schema, throwing and invalid steps", function()
		local status, migrated = Record.migrate(fixture())
		equal(status, "Current"); equal(migrated.schema, Record.SCHEMA)
		local newer = fixture(); newer.schema = Record.SCHEMA + 1
		status, migrated = Record.migrate(newer)
		equal(status, "TooNew"); equal(migrated, nil)
		local unversioned = { collection = { registered = { { uid = "u4", species = "Lumipol" } }, bankedEggs = {} },
			ember = 7 }
		status, migrated = Record.migrate(unversioned)
		equal(status, "Migrated")
		equal(migrated.schema, Record.SCHEMA); equal(migrated.ember, 7); equal(migrated.nextUid, 5)
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

	-- NS1: a schema 1 save migrates to schema 2 (deliberately changed pin: "Current" -> "Migrated").
	case("RT-14: the golden schema 1 fixture migrates to schema 2 and survives a JSON round trip", function()
		local golden = HttpService:JSONDecode([[{"schema":1,"revision":42,"lastCommitId":"extract:31",
			"lastWriteId":"srv:1:9","nextUid":18,"nextTrip":8,"nextOp":32,"firstSealGranted":true,
			"collection":{"registered":[{"uid":"u12","species":"Lumipol"}],"bankedEggs":[{"uid":"u9","species":"Lumipol"}]},
			"equippedUid":"u12","banked":{"fogbark":0,"glowmoss":0,"nightbloom":0},"ember":0,
			"consumables":{"seal":0,"capsule":0,"totem":0},"upgrades":{"reinforcedPack":false},"skills":{},
			"bondXp":{"u12":0},"settings":{},"stats":{"tripsOpened":0,"extractions":0,"defeats":0,"firstPlayedDay":0},
			"ledger":[{"id":"extract:31","kind":"extract","digest":"x"}]}]])
		local status, migrated = Record.migrate(golden)
		equal(status, "Migrated")
		valid(migrated, "golden v1 migrated")
		local expected = Record.copy(golden)
		expected.schema = Record.SCHEMA; expected.incubating = {}; expected.training = {}; expected.gloves = { owned = {} }
		deepEqual(HttpService:JSONDecode(HttpService:JSONEncode(migrated)), expected)
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

	-- Nest Heist Phase 3 (NS2, NS3): what the save holds besides the collection.
	case("RT-19: incubating eggs survive profile -> record -> profile with their server timestamps", function()
		local profile = stateProfile()
		profile.incubating = { { uid = "u2", species = "Lumipol", startedAt = 1700000000, readyAt = 1700000090 } }
		local base = Record.blank(); base.nextUid = 3
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 1700000010 }, Economy, Config))
		valid(record, "with an incubating egg")
		equal(#record.incubating, 1)
		equal(record.incubating[1].uid, "u2"); equal(record.incubating[1].readyAtUnix, 1700000090)
		local back = Record.toProfile(record, Economy, Config, 0)
		equal(#back.incubating, 1)
		equal(back.incubating[1].startedAt, 1700000000); equal(back.incubating[1].readyAt, 1700000090)
		equal(back.incubating[1].species, "Lumipol")
		local r = Record.copy(record); r.incubating[1].readyAtUnix = 0 / 0; invalid(r, "NaN ready time")
		r = Record.copy(record); r.incubating[1].uid = "wb:4"; invalid(r, "session id in the incubator")
		r = Record.copy(record); r.collection.bankedEggs = { { uid = "u2", species = "Lumipol" } }
		invalid(r, "the same egg banked and incubating")
	end)

	case("RT-20: training levels survive the round trip; a blank profile has none", function()
		local profile = stateProfile()
		profile.training = { speed = 3 }
		local record = assert(Record.fromProfile(profile, Record.blank(), { nowUnix = 1 }, Economy, Config))
		equal(record.training.speed, 3)
		valid(record, "with training")
		equal(Record.toProfile(record, Economy, Config, 0).training.speed, 3)
		local blank = Record.toProfile(Record.blank(), Economy, Config, 0)
		equal(blank.training, nil, "made on first use, like the incubator list")
		equal(blank.incubating, nil)
		local r = Record.copy(record); r.training.speed = -1; invalid(r, "negative level")
		r = Record.copy(record); r.training.speed = 1.5; invalid(r, "fractional level")
	end)

	case("RT-21: migration 1 -> 2 drops atRisk (carried items are never saved) and adds the new lists", function()
		local old = fixture()
		old.schema = 1
		local status, migrated = Record.migrate(old)
		equal(status, "Migrated")
		equal(migrated.atRisk, nil, "what was out in the world is not carried into schema 2")
		deepEqual(migrated.incubating, {}); deepEqual(migrated.training, {})
		valid(migrated, "migrated fixture")
		equal(old.atRisk ~= nil, true, "the input is never changed")
		local status0, from0 = Record.migrate({ ember = 3 })
		equal(status0, "Migrated"); equal(from0.schema, Record.SCHEMA); valid(from0, "v0 through every step")
	end)

	-- Nest Heist Phase 3 (NS7): gloves with rolled stats are saved with the worn one.
	case("RT-22: gloves survive the round trip with their stats and the worn one; the record checks every stat", function()
		local profile = stateProfile()
		profile.gloves = { list = { { uid = "u1", rarity = "Rara", stats = { move = 1.5, calm = 12 } },
			{ uid = "u2", rarity = "Comun", stats = { drain = 9 } } }, equipped = "u2" }
		local base = Record.blank(); base.nextUid = 3
		local record = assert(Record.fromProfile(profile, base, { nowUnix = 1 }, Economy, Config))
		valid(record, "with gloves")
		equal(#record.gloves.owned, 2); equal(record.gloves.equippedUid, "u2")
		equal(record.gloves.owned[1].stats.calm, 12)
		local back = Record.toProfile(record, Economy, Config, 0)
		equal(back.gloves.equipped, "u2"); equal(back.gloves.list[1].stats.move, 1.5); equal(back.gloves.list[2].rarity, "Comun")
		equal(Record.toProfile(Record.blank(), Economy, Config, 0).gloves, nil, "a blank profile has no glove table")
		local r = Record.copy(record); r.gloves.owned[1].stats.move = 99; invalid(r, "a stat over its cap")
		r = Record.copy(record); r.gloves.owned[1].stats.stealth = 5; invalid(r, "an unknown stat")
		r = Record.copy(record); r.gloves.owned[1].rarity = "Mitica"; invalid(r, "an unknown rarity")
		r = Record.copy(record); r.gloves.equippedUid = "u9"; invalid(r, "a worn glove that is not owned")
		r = Record.copy(record); r.gloves.owned[2].uid = "u1"; invalid(r, "a glove ID used twice")
		profile.gloves.list[1].uid = "wb:5"
		equal((Record.fromProfile(profile, base, { nowUnix = 1 }, Economy, Config)), nil, "session IDs are never saved")
	end)

	case("RT-23: migration 2 -> 3 adds the gloves and turns a legacy gear map into gloves or Esencia, safely", function()
		local old = Record.blank()
		old.schema = 2; old.gloves = nil; old.ember = 10; old.nextUid = 5
		old.gear = { guantes = true, botas = true, chaleco = true, amuleto = true }
		local status, migrated = Record.migrate(old)
		equal(status, "Migrated")
		valid(migrated, "migrated legacy gear")
		equal(#migrated.gloves.owned, 2, "the Guantes and the Botas became gloves")
		equal(migrated.gloves.owned[1].stats.calm, 9); equal(migrated.gloves.owned[2].stats.drain, 9)
		equal(migrated.gloves.owned[1].uid, "u5"); equal(migrated.nextUid, 7)
		equal(migrated.gloves.equippedUid, "u5")
		equal(migrated.ember, 10 + 45 + 40, "the Chaleco and the Amuleto refund their Esencia")
		equal(migrated.gear, nil, "the legacy map is gone")
		local plain = Record.blank(); plain.schema = 2; plain.gloves = nil
		local _, none = Record.migrate(plain)
		deepEqual(none.gloves, { owned = {} })
	end)

	return result
end
