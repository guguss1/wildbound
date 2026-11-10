-- Invoke with require(freshTestClone)(require(freshTotemRecordClone), require(freshRecordClone),
-- freshTotemRecordClone.Source).
-- Luck totem persistence (decision Q10, docs/mechanics/wildbound-new-mechanics.md section 4): the record step 3 -> 4
-- that stores the single-use totems a player owns (bought or earned), its validation, the profile seam and the pure
-- grant and consume rules. No data store is touched: everything here works on plain tables.
return function(TotemRecord, Record, source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function valid(record, label)
		local ok, problems = TotemRecord.validate(record)
		assert(ok == true, (label or "record") .. ": " .. table.concat(problems or {}, "; "))
	end
	local function invalid(record, label)
		local ok, problems = TotemRecord.validate(record)
		assert(ok == false, (label or "record") .. ": expected validation to fail")
		assert(type(problems) == "table" and #problems > 0, (label or "record") .. ": expected problems listed")
	end
	local function schema3()
		local record = Record.blank()
		record.schema = 3
		record.ember = 12
		return record
	end

	case("TR1: the step goes from schema 3 to 4 and the only totem kind is the luck totem", function()
		equal(TotemRecord.FROM, 3); equal(TotemRecord.SCHEMA, 4)
		equal(TotemRecord.FROM, Record.SCHEMA, "the step starts where the deployed record ends")
		equal(TotemRecord.KINDS.totemSuerte, true)
		equal(TotemRecord.CAP, 5)
	end)

	case("TR2: migration: a schema 3 record gains an empty totem map; nothing else changes and nothing is invented", function()
		local before = schema3()
		local after = TotemRecord.step(Record.copy(before))
		equal(type(after.totems), "table"); equal(next(after.totems), nil, "no totem is invented")
		equal(after.ember, 12, "other fields are kept")
		equal(after.schema, 3, "the ladder, not the step, writes the schema number")
		valid(after, "migrated")
		equal(before.totems, nil, "the input copy given to the ladder is the only one changed")
	end)

	case("TR3: the whole ladder from an unversioned record through the deployed steps and this one", function()
		local status, migrated = Record.migrate({ ember = 3 })
		equal(status, "Migrated"); equal(migrated.schema, 3)
		local stepped = TotemRecord.step(migrated)
		stepped.schema = TotemRecord.SCHEMA
		valid(stepped, "v0 through every step")
		local ladder = TotemRecord.ladder(Record.MIGRATIONS)
		for version = 0, TotemRecord.FROM - 1 do
			equal(ladder[version], Record.MIGRATIONS[version], "step " .. version .. " is reused as is")
		end
		equal(ladder[TotemRecord.FROM], TotemRecord.step, "the new step is appended")
		equal(table.isfrozen(ladder), true, "the ladder is frozen like Record.MIGRATIONS")
	end)

	case("TR4: never overwrite on a bad load: a malformed totem section is kept for validation to quarantine", function()
		local raw = schema3()
		raw.totems = "lots"
		local after = TotemRecord.step(raw)
		equal(after.totems, "lots", "the step only fills a missing section")
		invalid(after, "a string is not a totem map")
		local bad = schema3(); bad.totems = { totemSuerte = -1 }; invalid(bad, "a negative count")
		bad = schema3(); bad.totems = { totemSuerte = 1.5 }; invalid(bad, "a fractional count")
		bad = schema3(); bad.totems = { totemSuerte = 6 }; invalid(bad, "over the cap")
		bad = schema3(); bad.totems = { dragonEgg = 1 }; invalid(bad, "an unknown kind")
		bad = schema3(); bad.totems = { totemSuerte = 0 / 0 }; invalid(bad, "not a number")
		invalid(nil, "no record")
	end)

	case("TR5: grant adds a totem (bought or earned) up to the cap; consume uses exactly one", function()
		local record = TotemRecord.step(schema3())
		equal(TotemRecord.grant(record, "totemSuerte", 1, "bought"), true)
		equal(TotemRecord.grant(record, "totemSuerte", 1, "earned"), true)
		equal(TotemRecord.count(record, "totemSuerte"), 2)
		equal(select(2, TotemRecord.grant(record, "totemSuerte", 4, "earned")), "Full", "never past the cap")
		equal(TotemRecord.count(record, "totemSuerte"), 2, "a refused grant changes nothing")
		equal(select(2, TotemRecord.grant(record, "totemSuerte", 1, "stolen")), "BadSource")
		equal(select(2, TotemRecord.grant(record, "dragonEgg", 1, "bought")), "UnknownKind")
		equal(select(2, TotemRecord.grant(record, "totemSuerte", 0, "bought")), "BadCount")
		equal(select(2, TotemRecord.grant(record, "totemSuerte", 1.5, "bought")), "BadCount")
		equal(TotemRecord.consume(record, "totemSuerte"), true)
		equal(TotemRecord.count(record, "totemSuerte"), 1)
		equal(TotemRecord.consume(record, "totemSuerte"), true)
		equal(select(2, TotemRecord.consume(record, "totemSuerte")), "None", "single use: none left")
		equal(record.totems.totemSuerte, nil, "an empty kind leaves no zero behind")
		valid(record, "after use")
	end)

	case("TR6: the profile seam: the count crosses both ways and the blank profile stays unchanged", function()
		local record = TotemRecord.step(schema3())
		local fromEmpty = TotemRecord.fromProfile({}, record)
		equal(next(fromEmpty), nil, "no totems, an empty map")
		local saved = TotemRecord.fromProfile({ luckTotems = 2 }, record)
		equal(saved.totemSuerte, 2)
		equal(TotemRecord.fromProfile({ luckTotems = 99 }, record).totemSuerte, TotemRecord.CAP, "capped on save")
		equal(TotemRecord.fromProfile({ luckTotems = "x" }, record).totemSuerte, nil, "garbage saves nothing")
		local profile = {}
		TotemRecord.toProfile(record, profile)
		equal(profile.luckTotems, nil, "the blank profile must equal State:addPlayer's (RT-2)")
		record.totems.totemSuerte = 3
		TotemRecord.toProfile(record, profile)
		equal(profile.luckTotems, 3)
	end)

	case("TR7: the module is pure and names no data store", function()
		assert(type(source) == "string", "source")
		for _, needle in ipairs({ "GetService", "DataStore", "os.time", "math.random", "workspace" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	return result
end
