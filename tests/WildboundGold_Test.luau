-- Invoke with require(freshTestClone)(require(freshGoldClone), freshGoldClone.Source, { state = require(freshStateClone),
-- economy = require(freshEconomyClone), config = require(freshConfigClone), record = require(freshRecordClone),
-- campView = require(freshCampViewClone), text = require(freshTextClone), service = WildboundGoldService.Source,
-- server = WildboundServer.Source, client = WildboundClient.Source, goldClient = WildboundGoldClient.Source }).
-- Gold (owner request 2026-11-16, odd/tasks/wildbound-gold.md): farm creatures and the treadmill pay gold; gold buys the
-- farm's extra places and treadmill levels in addition to their Esencia prices. GD-18..GD-20: the owner-approved
-- follow-up (farm places 7 and 8, treadmill x1.25, hatch/tame bonus 10, the farm paused for idle players).
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
		-- Owner feedback 3: farm income about x3.5 (was 2/3/5/8).
		equal(Gold.farmRate({ "Lumipol" }, rarityOf), 7)
		equal(Gold.farmRate({ "Cestillo" }, rarityOf), 10)
		equal(Gold.farmRate({ "Polvilla" }, rarityOf), 18)
		equal(Gold.farmRate({ "Tizoncillo" }, rarityOf), 30)
		equal(Gold.farmRate({ "Mielita" }, rarityOf), 7, "a candy critter")
		equal(Gold.farmRate({ "Lumipol", "Lumipol", "Polvilla" }, rarityOf), 32)
		equal(Gold.TAME_BONUS, 10, "tame/hatch bonus (gold follow-up: was 20, at first 5)")
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
		-- Owner feedback 3: 2 per lap (was 1), cap 10 a minute (was 6).
		equal(Gold.lapGold(0), 2); equal(Gold.lapGold(3), 2); equal(Gold.lapGold(4), 3); equal(Gold.lapGold(17), 6)
		local window, paid = nil, 0
		for lap = 1, 7 do
			local got
			got, window = Gold.capLap(window, lap * 8, Gold.lapGold(0))
			paid += got
		end
		equal(paid, 10, "7 laps in under a minute pay the cap of 10")
		local got
		got, window = Gold.capLap(window, 8 + 60, 6)
		equal(got, 6, "a new minute opens a new window")
		got = Gold.capLap(window, 70, 6)
		equal(got, 4, "the rest of the cap")
		equal(Gold.TREADMILL_CAP_PER_MINUTE, 10)
	end)

	case("GD-4: gold prices for the farm places and the treadmill levels", function()
		equal(Gold.upgradePrice("farmSlot5"), 60); equal(Gold.upgradePrice("farmSlot6"), 150)
		-- Gold follow-up (owner OK 2026-11-16): two more farm places and a steeper treadmill ladder (x1.25, was x1.15).
		equal(Gold.upgradePrice("farmSlot7"), 600); equal(Gold.upgradePrice("farmSlot8"), 1500)
		equal(Gold.upgradePrice("reinforcedPack"), nil, "only the farm places sell for gold")
		equal(Gold.TRAIN_GROWTH, 1.25)
		equal(Gold.trainPrice(0, 17), 30); equal(Gold.trainPrice(1, 17), 38); equal(Gold.trainPrice(16, 17), 1066)
		equal(Gold.trainPrice(17, 17), nil); equal(Gold.trainPrice(-1, 17), nil)
	end)

	case("GD-5: the first gold purchase takes 1 to 5 minutes of normal play (owner feedback 3: was 5 to 10)", function()
		-- Normal early play: two common creatures in the farm, one minute in five on the treadmill (lap cap), one tame
		-- every ten minutes. The cheapest gold purchase is the first treadmill level.
		local perMinute = Gold.farmRate({ "Lumipol", "Lumipol" }, rarityOf) + Gold.TREADMILL_CAP_PER_MINUTE / 5
			+ Gold.TAME_BONUS / 10
		local cheapest = math.min(Gold.trainPrice(0, 17), Gold.upgradePrice("farmSlot5"))
		local minutes = cheapest / perMinute
		assert(minutes >= 1 and minutes <= 5, ("first purchase after %.1f minutes"):format(minutes))
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

	-- Owner feedback 3: "Vender" a creature for gold, by rarity and bond level.
	case("GD-13: a creature's sale price by rarity and bond level", function()
		equal(Gold.sellPrice("Comun", 1), 25); equal(Gold.sellPrice("Rara", 1), 60)
		equal(Gold.sellPrice("Epica", 1), 150); equal(Gold.sellPrice("Legendaria", 1), 400)
		equal(Gold.sellPrice(nil, 1), 25, "an unknown rarity sells as common")
		equal(Gold.sellPrice("Comun", 3), 35, "+20% per bond level above 1")
		equal(Gold.sellPrice("Rara", 0 / 0), 60); equal(Gold.sellPrice("Rara", -4), 60); equal(Gold.sellPrice("Rara"), 60)
		equal(Gold.sellPrice("Comun", 1e9), Gold.sellPrice("Comun", Gold.SELL_MAX_LEVEL), "the level is capped")
	end)

	case("GD-14: State sells an owned creature for gold; never the companion, a farm creature or the last one", function()
		local state, profile = fresh()
		local function refused(reason, ok, why) equal(ok, false); equal(why, reason) end
		profile.registered = { { uid = "a", species = "Lumipol" }, { uid = "b", species = "Cestillo" },
			{ uid = "c", species = "Polvilla" } }
		profile.discovered = { Lumipol = true, Cestillo = true, Polvilla = true }
		profile.equippedUid = "a"
		profile.farm = { "b" }
		profile.bond = { c = { xp = 3, level = 2 } }
		refused("InvalidPlayer", state:sellCreature("Bob", "c", true, 150))
		refused("InvalidContext", state:sellCreature("Alice", "c", false, 150))
		refused("NotOwnedPet", state:sellCreature("Alice", "zz", true, 150))
		refused("IsCompanion", state:sellCreature("Alice", "a", true, 25))
		refused("InFarm", state:sellCreature("Alice", "b", true, 60))
		refused("InvalidPrice", state:sellCreature("Alice", "c", true, 0))
		refused("InvalidPrice", state:sellCreature("Alice", "c", true, 1.5))
		equal(#profile.registered, 3, "refusals change nothing"); equal(state:snapshot("Alice").gold, 0)
		local ok, result = state:sellCreature("Alice", "c", true, 180)
		equal(ok, true); equal(result.species, "Polvilla"); equal(result.gold, 180)
		equal(#profile.registered, 2); equal(profile.bond.c, nil, "its bond goes with it")
		equal(profile.discovered.Polvilla, true, "the species stays discovered")
		equal(state:snapshot("Alice").gold, 180)
		-- Down to one creature: it can never be sold, even when it is not the companion.
		profile.farm = {}
		profile.equippedUid = nil
		equal(state:sellCreature("Alice", "b", true, 60), true)
		refused("LastCreature", state:sellCreature("Alice", "a", true, 25))
		equal(state:snapshot("Alice").gold, 240)
	end)

	case("GD-15: the panel offers Vender on every creature the server would sell", function()
		local snapshot = { registered = { { uid = "a", species = "Lumipol" }, { uid = "b", species = "Cestillo" },
			{ uid = "c", species = "Polvilla" } }, equippedUid = "a", farm = { "b" } }
		local set = View.sellable(snapshot)
		equal(set.a, nil, "not the companion"); equal(set.b, nil, "not a farm creature"); equal(set.c, true)
		equal(next(View.sellable({ registered = { { uid = "x", species = "Lumipol" } } })), nil, "not the last one")
		equal(next(View.sellable(nil)), nil)
		equal(Text.GOLD.sell, "Vender"); equal(Text.GOLD.sellConfirm, "Confirmar")
		assert(Text.GOLD.sellRow:format("Lumipol", 25):find("25 de oro", 1, true))
		assert(Text.GOLD.sold:format("Lumipol", 25):find("+25 de oro", 1, true))
		for _, why in ipairs({ "IsCompanion", "InFarm", "LastCreature" }) do
			assert(type(Text.GOLD.sellRefused[why]) == "string", "refusal words for " .. why)
		end
	end)

	case("GD-16: the base screens hide gloves, chest, incubator, crafts and skills; farm, treadmill and gold stay", function()
		local hidden = View.HIDDEN
		equal(hidden.eggsTab, true, "the Huevos (cofre/incubadora) tab is hidden")
		equal(hidden.stations.chest, true); equal(hidden.stations.incubator, true); equal(hidden.stations.glove, true)
		equal(hidden.stations.train, nil, "the treadmill prompt stays")
		local rows = View.campRows(Config, Economy, { ember = 0, gold = 0, banked = {}, consumables = { seal = 1, totem = 1 },
			upgrades = {}, skills = {}, bond = {}, gloves = {}, luckTotems = 0 }, { atCamp = true, goldPrices = prices })
		local shown, ids = View.visibleRows(rows), {}
		for _, item in ipairs(shown) do
			ids[item.id] = true
			assert(item.section ~= "Craft" and item.section ~= "Gear" and item.section ~= "Skills", "hidden row " .. item.id)
		end
		for _, id in ipairs({ "upgrade:incubatorSlot2", "upgrade:incubatorSlot3", "upgrade:fastIncubator", "gear:guantes",
			"gear:totemSuerte", "craft:seal" }) do
			equal(ids[id], nil, id .. " is hidden")
		end
		for _, id in ipairs({ "upgrade:farmSlot5", "gold:farmSlot5", "gold:train", "banked" }) do
			equal(ids[id], true, id .. " stays")
		end
		assert(#shown < #rows, "something is hidden")
		equal(#View.campRows(Config, Economy, {}, { atCamp = true }) > 0, true, "campRows itself still lists everything")
	end)

	case("GD-17: wiring: Vender reaches the gold service; the client hides what View.HIDDEN names", function()
		local server, service, client = sources.server, sources.service, sources.client
		assert(server:find("SellCreature = true", 1, true), "the server accepts SellCreature")
		assert(server:find("Heist.gold:sell(player, argument)", 1, true), "SellCreature reaches the gold service")
		assert(service:find("state:sellCreature", 1, true) and service:find("Gold.sellPrice", 1, true), "the service sells")
		assert(client:find("SellCreature", 1, true) and client:find("Camp.sellable", 1, true), "the panel's Vender rows")
		assert(client:find("Camp.visibleRows", 1, true), "the camp tab drops hidden rows")
		assert(client:find("Camp.HIDDEN", 1, true), "the eggs tab and station prompts follow the flag")
		assert(client:find("Camp.HIDDEN.sections.Craft", 1, true), "the Bag tab's seal buttons hide with the crafts")
		assert(service:find('op == "creature"', 1, true), "the Studio-only probe gives a test creature for the sale check")
	end)

	-- Gold follow-up (owner OK 2026-11-16 to the O7 proposals, docs/balance/wildbound-2-0-economy-sim.md).
	case("GD-18: the farm pauses for a player who has not moved for IDLE_SECONDS", function()
		equal(Gold.IDLE_SECONDS, 300)
		assert(Gold.IDLE_MOVE_STUDS > 0, "a move threshold")
		local track = Gold.watch(nil, 0, 0, 100)
		equal(Gold.idle(track, 100), false, "a new track is active")
		track = Gold.watch(track, 1, 1, 200) -- a small shuffle is not a move
		equal(Gold.idle(track, 100 + Gold.IDLE_SECONDS - 1), false)
		equal(Gold.idle(track, 100 + Gold.IDLE_SECONDS), true, "still for IDLE_SECONDS: idle")
		track = Gold.watch(track, Gold.IDLE_MOVE_STUDS + 1, 0, 500)
		equal(Gold.idle(track, 500), false, "a real move wakes the farm")
		equal(Gold.idle(track, 500 + Gold.IDLE_SECONDS - 1), false)
		local same = Gold.watch(track, nil, nil, 9999)
		equal(same, track, "no position (no character) changes nothing")
		equal(Gold.idle(nil, 1e9), false, "no track yet: not idle")
		equal(Gold.idle(Gold.watch(nil, 0 / 0, 0, 5), 1e9), false, "a bad position starts no track")
		-- Jumping in place moves up, not across: still idle.
		track = Gold.watch(nil, 10, 10, 0)
		track = Gold.watch(track, 10, 10, 150)
		equal(Gold.idle(track, Gold.IDLE_SECONDS), true)
	end)

	case("GD-19: farm places 7 and 8: Esencia or gold, each needs the one before; old saves load", function()
		local up = Config.upgrades
		equal(up.farmSlot7.effects.farmSlots, 7); equal(up.farmSlot7.requires, "farmSlot6")
		equal(up.farmSlot8.effects.farmSlots, 8); equal(up.farmSlot8.requires, "farmSlot7")
		equal(up.farmSlot7.cost.ember, 2000); equal(up.farmSlot8.cost.ember, 4500)
		local state, profile = fresh()
		profile.ember = 10000
		local function refused(reason, ok, why) equal(ok, false); equal(why, reason) end
		state:addGold("Alice", 5000)
		refused("NeedsPrerequisite", state:upgradeWithGold("Alice", "farmSlot7", true, 0, 600))
		equal(state:upgradeWithGold("Alice", "farmSlot5", true, 0, 60), true)
		equal(state:upgradeWithGold("Alice", "farmSlot6", true, 0, 150), true)
		refused("NeedsPrerequisite", state:upgradeWithGold("Alice", "farmSlot8", true, 0, 1500))
		equal(state:upgradeWithGold("Alice", "farmSlot7", true, 0, 600), true)
		equal(state:snapshot("Alice").farmSlots, 7)
		equal(state:upgrade("Alice", "farmSlot8", true, 0), true, "the eighth with Esencia")
		equal(state:snapshot("Alice").farmSlots, 8); equal(profile.ember, 5500)
		equal(state:snapshot("Alice").gold, 5000 - 60 - 150 - 600)
		-- A save made before these places existed has no farmSlot7/farmSlot8 key: it loads with both unbought.
		local record = Record.fromProfile(profile, nil, nil, Economy, Config)
		record.upgrades.farmSlot7, record.upgrades.farmSlot8 = nil, nil
		equal(Record.validate(record, Economy, Config), true, "an older save is still valid")
		local back = Record.toProfile(record, Economy, Config, 0)
		equal(back.upgrades.farmSlot7, false); equal(back.upgrades.farmSlot8, false)
		equal(back.upgrades.farmSlot6, true)
		local other = State.new(Economy, Config)
		other:loadPlayer("Alice", back)
		equal(other:snapshot("Alice").farmSlots, 6)
		-- The camp screen lists them with both prices, the seventh waiting for the sixth.
		local rows = rowsOf({ gold = 999, upgrades = { farmSlot5 = true } }, { atCamp = true,
			goldPrices = { farmSlot5 = 60, farmSlot6 = 150, farmSlot7 = 600, farmSlot8 = 1500 } })
		assert(rows["upgrade:farmSlot7"].text:find("2000 de Esencia o 600 de oro", 1, true), rows["upgrade:farmSlot7"].text)
		assert(rows["upgrade:farmSlot7"].text:find("Séptimo lugar de granja", 1, true), rows["upgrade:farmSlot7"].text)
		equal(rows["gold:farmSlot7"].enabled, false)
		assert(rows["gold:farmSlot7"].why:find("Sexto lugar de granja", 1, true), rows["gold:farmSlot7"].why)
		assert(rows["upgrade:farmSlot8"].text:find("Octavo lugar de granja", 1, true), rows["upgrade:farmSlot8"].text)
	end)

	case("GD-20: wiring: the service watches each player's position on the server and skips the farm when idle", function()
		local service = sources.service
		assert(service:find("Gold.watch(", 1, true) and service:find("Gold.idle(", 1, true), "the service uses the idle rule")
		assert(service:find("HumanoidRootPart", 1, true), "the position comes from the server's character")
		assert(service:find("WildboundFarmPaused", 1, true), "the pause shows on a player attribute")
		local _, remotes = service:gsub("Instance%.new%(\"RemoteEvent\"%)", "")
		equal(remotes, 1, "no new remote: the client never reports idleness (only GoldPopup)")
		equal(Text.GOLD.farmPaused ~= nil and type(Text.GOLD.farmPaused), "string", "the pause notice words")
	end)

	return result
end
