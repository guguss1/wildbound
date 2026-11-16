-- Invoke with require(freshTestClone)(require(freshGoldClone), freshGoldClone.Source, { state = require(freshStateClone),
-- economy = require(freshEconomyClone), config = require(freshConfigClone), record = require(freshRecordClone),
-- campView = require(freshCampViewClone), text = require(freshTextClone), service = WildboundGoldService.Source,
-- server = WildboundServer.Source, client = WildboundClient.Source, goldClient = WildboundGoldClient.Source }).
-- Gold (owner request 2026-11-16, odd/tasks/wildbound-gold.md): farm creatures and the treadmill pay gold; gold buys the
-- farm's extra places and treadmill levels in addition to their Esencia prices.
return function(Gold, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
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
	local State, Economy, Config, Record, View, Text = sources.state, sources.economy, sources.config, sources.record,
		sources.campView, sources.text
	local RARITY = { Lumipol = "Comun", Cestillo = "Rara", Polvilla = "Epica", Tizoncillo = "Legendaria" }
	local function rarityOf(name) return RARITY[name] end

	case("GD-1: a farm pays per creature, more for rarer ones; unknown species count as common", function()
		equal(Gold.farmRate({ "Lumipol" }, rarityOf), 2)
		equal(Gold.farmRate({ "Cestillo" }, rarityOf), 3)
		equal(Gold.farmRate({ "Polvilla" }, rarityOf), 5)
		equal(Gold.farmRate({ "Tizoncillo" }, rarityOf), 8)
		equal(Gold.farmRate({ "Mielita" }, rarityOf), 2, "a candy critter")
		equal(Gold.farmRate({ "Lumipol", "Lumipol", "Polvilla" }, rarityOf), 9)
		equal(Gold.farmRate({}, rarityOf), 0); equal(Gold.farmRate(nil, rarityOf), 0)
	end)

	case("GD-2: farm gold accrues each second and keeps the fraction", function()
		local carry, total = nil, 0
		for _ = 1, 60 do
			local whole
			whole, carry = Gold.accrue(carry, 2, 1)
			total += whole
		end
		equal(total, 2, "2 per minute over 60 one-second steps")
		local whole, rest = Gold.accrue(0, 0, 1)
		equal(whole, 0); equal(rest, 0)
		whole = Gold.accrue(0, 6, 600)
		equal(whole, 6, "a long gap counts as one minute at most")
		whole = Gold.accrue(0 / 0, 2, 0 / 0)
		equal(whole, 0)
	end)

	case("GD-3: a treadmill lap pays more at higher levels, capped per minute (anti-AFK)", function()
		equal(Gold.lapGold(0), 1); equal(Gold.lapGold(3), 1); equal(Gold.lapGold(4), 2); equal(Gold.lapGold(17), 5)
		local window, paid = nil, 0
		for lap = 1, 7 do
			local got
			got, window = Gold.capLap(window, lap * 8, Gold.lapGold(0))
			paid += got
		end
		equal(paid, 6, "7 laps in under a minute pay the cap of 6")
		local got
		got, window = Gold.capLap(window, 8 + 60, 5)
		equal(got, 5, "a new minute opens a new window")
		got = Gold.capLap(window, 70, 5)
		equal(got, 1, "the rest of the cap")
		equal(Gold.TREADMILL_CAP_PER_MINUTE, 6)
	end)

	case("GD-4: gold prices for the farm places and the treadmill levels", function()
		equal(Gold.upgradePrice("farmSlot5"), 60); equal(Gold.upgradePrice("farmSlot6"), 150)
		equal(Gold.upgradePrice("reinforcedPack"), nil, "only the farm places sell for gold")
		equal(Gold.trainPrice(0, 17), 30); equal(Gold.trainPrice(1, 17), 35); equal(Gold.trainPrice(16, 17), 281)
		equal(Gold.trainPrice(17, 17), nil); equal(Gold.trainPrice(-1, 17), nil)
	end)

	case("GD-5: the first gold purchase takes 5 to 10 minutes of normal play", function()
		-- Normal early play: two common creatures in the farm, one minute in five on the treadmill (lap cap), one tame
		-- every ten minutes. The cheapest gold purchase is the first treadmill level.
		local perMinute = Gold.farmRate({ "Lumipol", "Lumipol" }, rarityOf) + Gold.TREADMILL_CAP_PER_MINUTE / 5
			+ Gold.TAME_BONUS / 10
		local cheapest = math.min(Gold.trainPrice(0, 17), Gold.upgradePrice("farmSlot5"))
		local minutes = cheapest / perMinute
		assert(minutes >= 5 and minutes <= 10, ("first purchase after %.1f minutes"):format(minutes))
		local fifth = Gold.upgradePrice("farmSlot5") / (Gold.farmRate({ "Lumipol", "Lumipol", "Lumipol", "Lumipol" }, rarityOf)
			+ Gold.TREADMILL_CAP_PER_MINUTE / 5)
		assert(fifth <= 10, ("a full farm buys the fifth place in %.1f minutes"):format(fifth))
	end)

	case("GD-6: earned gold shows as one batched popup", function()
		local buffer = Gold.batch(nil, 2)
		buffer = Gold.batch(buffer, 3)
		equal(Gold.flush(buffer, 10), 5, "the first popup at once")
		buffer = Gold.batch(buffer, 1)
		equal(Gold.flush(buffer, 11), nil, "not again within POPUP_SECONDS")
		buffer = Gold.batch(buffer, 1)
		equal(Gold.flush(buffer, 10 + Gold.POPUP_SECONDS), 2)
		equal(Gold.flush(buffer, 100), nil, "nothing pending")
	end)

	local function fresh()
		local state = State.new(Economy, Config)
		state:addPlayer("Alice")
		return state, state.players["s:Alice"]
	end

	case("GD-7: State keeps gold, shows it in the snapshot and saves it in the record", function()
		local state, profile = fresh()
		equal(state:snapshot("Alice").gold, 0)
		equal(profile.training, nil, "a blank profile stays blank")
		local ok, total = state:addGold("Alice", 12)
		equal(ok, true); equal(total, 12); equal(state:snapshot("Alice").gold, 12)
		equal(state:addGold("Alice", -3), false); equal(state:addGold("Alice", 1.5), false); equal(state:addGold("Alice", 0 / 0), false)
		equal(state:addGold("Bob", 3), false)
		equal(state:snapshot("Alice").gold, 12)
		local record = Record.fromProfile(profile, nil, nil, Economy, Config)
		assert(record, "the profile saves")
		local valid = Record.validate(record, Economy, Config)
		equal(valid, true, "the saved record is valid")
		local back = Record.toProfile(record, Economy, Config, 0)
		local other = State.new(Economy, Config)
		other:loadPlayer("Alice", back)
		equal(other:snapshot("Alice").gold, 12, "gold comes back after a save")
	end)

	case("GD-8: a farm place bought with gold: same rules as Esencia, refused cleanly", function()
		local state, profile = fresh()
		profile.ember = 5000
		local function refused(reason, ok, why) equal(ok, false); equal(why, reason) end
		refused("CannotAffordGold", state:upgradeWithGold("Alice", "farmSlot5", true, 0, 60))
		equal(profile.upgrades.farmSlot5, false); equal(state:snapshot("Alice").gold, 0)
		state:addGold("Alice", 100)
		refused("NotAtCamp", state:upgradeWithGold("Alice", "farmSlot5", true, 999, 60))
		refused("NeedsPrerequisite", state:upgradeWithGold("Alice", "farmSlot6", true, 0, 150))
		refused("UnknownUpgrade", state:upgradeWithGold("Alice", "nope", true, 0, 60))
		equal(state:snapshot("Alice").gold, 100, "refusals change nothing")
		local ok = state:upgradeWithGold("Alice", "farmSlot5", true, 0, 60)
		equal(ok, true); equal(state:snapshot("Alice").gold, 40); equal(profile.ember, 5000, "no Esencia spent")
		equal(state:snapshot("Alice").farmSlots, 5)
		refused("AlreadyOwned", state:upgradeWithGold("Alice", "farmSlot5", true, 0, 60))
		refused("CannotAffordGold", state:upgradeWithGold("Alice", "farmSlot6", true, 0, 150))
		equal(state:snapshot("Alice").gold, 40)
	end)

	case("GD-9: a treadmill level bought with gold", function()
		local state, profile = fresh()
		equal(state:trainWithGold("Alice", true, 0, 30, 17), false, "no gold")
		state:addGold("Alice", 70)
		local ok, level = state:trainWithGold("Alice", true, 0, 30, 17)
		equal(ok, true); equal(level, 1); equal(state:snapshot("Alice").gold, 40); equal(profile.training.walk, 1)
		equal(select(2, state:trainWithGold("Alice", true, 999, 35, 17)), "NotAtCamp")
		profile.training.walk = 17
		equal(select(2, state:trainWithGold("Alice", true, 0, 35, 17)), "AtLimit")
		equal(state:snapshot("Alice").gold, 40)
	end)

	local prices = { farmSlot5 = 60, farmSlot6 = 150, train = 30, trainEmber = 20, trainLevel = 0, trainMax = 17 }
	local function rowsOf(snapshot, ctx)
		local base = { ember = 0, gold = 0, banked = { fogbark = 0, glowmoss = 0, nightbloom = 0 },
			consumables = { seal = 0, capsule = 0, totem = 0 }, upgrades = {}, skills = {}, bond = {}, pending = {},
			riskPreview = { loseItems = 0, keep = 0, loseMaterials = {} } }
		for key, value in pairs(snapshot) do base[key] = value end
		ctx.goldPrices = ctx.goldPrices or prices
		local byId = {}
		for _, item in ipairs(View.campRows(Config, Economy, base, ctx)) do byId[item.id] = item end
		return byId
	end

	case("GD-10: the camp screen shows both prices and a gold button", function()
		local rows = rowsOf({ gold = 70 }, { atCamp = true })
		assert(rows["upgrade:farmSlot5"].text:find("400 de Esencia o 60 de oro", 1, true), rows["upgrade:farmSlot5"].text)
		equal(rows["upgrade:farmSlot5"].action, "Upgrade")
		local gold = rows["gold:farmSlot5"]
		equal(gold.action, "BuyGold"); equal(gold.argument, "farmSlot5"); equal(gold.label, "Usar oro"); equal(gold.enabled, true)
		equal(rows["gold:farmSlot6"].enabled, false, "the sixth needs the fifth")
		assert(rows["gold:farmSlot6"].why:find("Requiere", 1, true), rows["gold:farmSlot6"].why)
		local train = rows["gold:train"]
		equal(train.action, "BuyGold"); equal(train.argument, "train"); equal(train.enabled, true)
		assert(train.text:find("30 de oro", 1, true) and train.text:find("20 de Esencia", 1, true), train.text)
		local poor = rowsOf({ gold = 10 }, { atCamp = true })
		equal(poor["gold:farmSlot5"].enabled, false)
		assert(poor["gold:farmSlot5"].why:find("Faltan 50 de oro", 1, true), poor["gold:farmSlot5"].why)
		equal(rowsOf({ gold = 999 }, { atCamp = false })["gold:train"].why, "Ve al campamento")
		local owned = rowsOf({ gold = 999, upgrades = { farmSlot5 = true, farmSlot6 = true } }, { atCamp = true })
		equal(owned["gold:farmSlot5"], nil, "no gold row once owned")
		local top = rowsOf({}, { atCamp = true, goldPrices = { trainLevel = 17, trainMax = 17 } })
		equal(top["gold:train"].action, nil, "no button at the top level")
		local compact = rowsOf({ gold = 10 }, { atCamp = true, compact = true })
		for id, item in pairs(compact) do
			if id:sub(1, 5) == "gold:" then
				assert(View.rowHeight(item, 379, 13, true) <= 64, id .. " compact row too tall: " .. item.text)
			end
		end
		equal(rowsOf({}, { atCamp = true, goldPrices = {} })["gold:train"], nil, "no gold prices, no gold rows")
	end)

	case("GD-11: wiring: server, service, clients and words", function()
		local server, service, client, goldClient = sources.server, sources.service, sources.client, sources.goldClient
		assert(server:find("BuyGold = true", 1, true), "the server accepts BuyGold")
		assert(server:find("Heist.gold:buy(player, argument)", 1, true), "BuyGold reaches the gold service")
		assert(server:find("Heist.gold:bonus(player)", 1, true), "tame and hatch pay a bonus")
		assert(server:find("Heist.gold:lap(player, res.level)", 1, true), "a treadmill lap pays gold")
		assert(server:find("WildboundGoldService", 1, true), "the service is started")
		assert(service:find("state:addGold", 1, true) and service:find("Gold.farmRate", 1, true), "the service pays the farm")
		assert(service:find("RunService:IsStudio()", 1, true), "the test probe exists in Studio only")
		assert(client:find("BuyGold = true", 1, true) and client:find("goldPrices", 1, true), "the camp screen shows gold")
		assert(goldClient:find("WildboundGold", 1, true) and goldClient:find("GoldPopup", 1, true), "the HUD counter and popup")
		equal(Text.GOLD.popup:format(3), "+3 oro"); equal(Text.GOLD.counter:format(7), "Oro: 7")
	end)

	case("GD-12: the gold rules are pure and never sold for Robux", function()
		for _, word in ipairs({ "game:", "GetService", "os.", "task.", "Random", "workspace", "Instance.new",
			"MarketplaceService", "Robux", "DataStore" }) do
			equal(source:find(word, 1, true), nil, "source mentions " .. word)
		end
		equal(Config.monetization, "none")
	end)

	return result
end
