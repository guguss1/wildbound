-- Invoke with require(freshTestClone)(require(freshRankClone), require(freshStateClone), require(freshEconomyClone),
-- require(freshConfigClone), require(freshRecordClone), sources) where sources = { rank, client, gold, state } are
-- the Source texts of WildboundRank, WildboundRankClient, WildboundGoldService and WildboundState.
-- T1 (docs/design/wildbound-fun-build-plan.md; owner request 2026-11-20 "que se pueda jugar mas tiempo"): the thief
-- rank. Each egg brought home counts once (State's bankItem, saved in the training map like gold), the rank never goes
-- down, the server mirrors the count on WildboundThiefSteals and the HUD shows a sign, a bar and a rank-up card.
return function(Rank, State, Economy, Config, Record, sources)
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
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or needle) .. ": not found")
	end
	sources = type(sources) == "table" and sources or {}

	case("RK1: the ladder: Aprendiz at 0, Ladronzuelo at 3, then Ladrón, Bandido, Maestro and Leyenda, in order", function()
		local names = { "Aprendiz", "Ladronzuelo", "Ladrón", "Bandido", "Maestro", "Leyenda" }
		local ats = { 0, 3, 8, 15, 25, 40 }
		equal(#Rank.LADDER, #names, "ranks")
		for index, entry in ipairs(Rank.LADDER) do
			equal(entry.name, names[index], "name " .. index)
			equal(entry.at, ats[index], "eggs for " .. names[index])
			assert(type(entry.icon) == "string" and #entry.icon > 0, "icon " .. index)
		end
		assert(table.isfrozen(Rank.LADDER) and table.isfrozen(Rank.LADDER[1]), "the ladder cannot be changed at run time")
		equal(Rank.ATTRIBUTE, "WildboundThiefSteals"); equal(Rank.KEY, "eggsHome")
	end)

	case("RK2: a bad count is 0; the rank of a count is the highest rank it reaches", function()
		for _, bad in ipairs({ nil, -1, 0 / 0, "5", {}, true }) do equal(Rank.count(bad), 0, "count of " .. tostring(bad)) end
		equal(Rank.count(2.9), 2, "whole eggs only"); equal(Rank.count(math.huge), Rank.MAX, "capped")
		equal(Rank.index(0), 1); equal(Rank.index(2), 1); equal(Rank.index(3), 2); equal(Rank.index(7), 2)
		equal(Rank.index(8), 3); equal(Rank.index(39), 5); equal(Rank.index(40), 6); equal(Rank.index(5000), 6)
		equal(Rank.at(3).name, "Ladronzuelo")
		equal(Rank.fromTraining({ eggsHome = 4, gold = 99 }), 4); equal(Rank.fromTraining(nil), 0)
		equal(Rank.fromTraining({ eggsHome = -3 }), 0)
	end)

	case("RK3: the bar counts eggs since the current rank toward the next; the top rank shows a full bar", function()
		local start = Rank.progress(0)
		equal(start.name, "Aprendiz"); equal(start.have, 0); equal(start.need, 3); equal(start.nextName, "Ladronzuelo")
		equal(start.text, "0/3 huevos"); equal(start.top, false)
		local two = Rank.progress(2)
		equal(two.text, "2/3 huevos")
		local five = Rank.progress(5)
		equal(five.name, "Ladronzuelo"); equal(five.have, 2); equal(five.need, 5); equal(five.text, "2/5 huevos")
		local top = Rank.progress(41)
		equal(top.name, "Leyenda"); equal(top.top, true); equal(top.have, top.need, "a full bar"); equal(top.nextName, nil)
		equal(top.text, Rank.TEXT.top)
	end)

	case("RK4: a rank up is reported only when a higher rank is reached; the first read and a lower count never are", function()
		equal(Rank.reached(nil, 3), nil, "the first read only remembers")
		equal(Rank.reached(2, 3).name, "Ladronzuelo")
		equal(Rank.reached(3, 4), nil, "same rank")
		equal(Rank.reached(5, 2), nil, "never down")
		equal(Rank.reached(2, 9).name, "Ladrón", "a jump names the higher rank")
		local title, body, hint = Rank.upLines(Rank.LADDER[2])
		equal(title, "¡Ladronzuelo!"); equal(body, Rank.TEXT.upBody); equal(hint, "Próximo: Ladrón con 8 huevos")
		local _, _, last = Rank.upLines(Rank.LADDER[#Rank.LADDER])
		equal(last, Rank.TEXT.upTop)
	end)

	case("RK5: each egg brought home counts once in the saved training map; creatures and trips do not", function()
		local state = State.new(Economy, Config)
		state:addPlayer("Alice")
		equal(Rank.fromTraining(state:snapshot("Alice").training), 0, "a new player")
		for index = 1, 2 do
			assert(state:registerEncounter("egg" .. index, "Egg"))
			assert(state:pickup("Alice", "egg" .. index, true, 0))
		end
		assert(state:extract("Alice", true, 0, 10))
		equal(Rank.fromTraining(state:snapshot("Alice").training), 2, "two eggs home")
		equal(select(2, next(state.players)).training.eggsHome, 2, "kept on the profile (the only player)")
		assert(state:registerEncounter("egg3", "Egg"))
		assert(state:pickup("Alice", "egg3", true, 0))
		assert(state:extract("Alice", true, 0, 20))
		equal(Rank.fromTraining(state:snapshot("Alice").training), 3, "a second trip adds")
		equal(Rank.at(Rank.fromTraining(state:snapshot("Alice").training)).name, "Ladronzuelo", "three eggs: Ladronzuelo")
		local ok = state:extract("Alice", true, 0, 30)
		equal(ok, false, "an empty extract")
		equal(Rank.fromTraining(state:snapshot("Alice").training), 3, "an empty extract counts nothing")
		local fresh = State.new(Economy, Config)
		fresh:addPlayer("Bob")
		equal(fresh:snapshot("Bob").training.eggsHome, nil, "nothing is made before the first egg (blank profile unchanged)")
	end)

	case("RK6: the count is saved and loaded with the training map, with no record schema step", function()
		local state = State.new(Economy, Config)
		state:addPlayer(1)
		local profile = select(2, next(state.players))
		profile.training = { eggsHome = 5, gold = 12 }
		local record, reason = Record.fromProfile(profile, Record.blank(), { nowUnix = 1000000 }, Economy, Config)
		assert(record, "serialized: " .. tostring(reason))
		local ok, problems = Record.validate(record, Economy, Config)
		assert(ok, "valid: " .. table.concat(problems or {}, "; "))
		equal(record.training.eggsHome, 5, "saved")
		local back = Record.toProfile(record, Economy, Config, 0)
		equal(back.training.eggsHome, 5, "loaded")
		equal(Record.SCHEMA, 6, "no schema bump")
	end)

	case("RK7: the wiring: bankItem counts eggs, the gold service mirrors the attribute, the HUD reads it", function()
		local state, gold, client, rank = sources.state, sources.gold, sources.client, sources.rank
		has(state, "player.training.eggsHome = ", "State counts in the training map")
		local bank = state:match("local function bankItem%(.-\nend")
		assert(bank and bank:find("eggsHome", 1, true), "the count sits inside bankItem, which every egg-home path uses")
		has(gold, "\"WildboundThiefSteals\"", "the gold service mirrors the count")
		has(gold, "snapshot.training", "read from the saved training map")
		has(client, "Rank.ATTRIBUTE", "the HUD reads the attribute")
		has(client, "GetAttributeChangedSignal(Rank.ATTRIBUTE)", "and follows its changes")
		has(client, "Rank.reached(", "the card shows only on a real rank up")
		has(client, "Style.reduced(", "Efectos suaves is honoured")
		for _, text in ipairs({ client, rank }) do
			for _, banned in ipairs({ "MarketplaceService", "Robux", "R$", "PromptProductPurchase" }) do
				assert(not text:find(banned, 1, true), "no purchase words: " .. banned)
			end
		end
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "math.random", "tick()", "workspace" }) do
			assert(not rank:find(needle, 1, true), "the rank module is pure: " .. needle)
		end
	end)

	return result
end
