-- Invoke with require(freshTestClone)(require(freshEggLoopClone), freshEggLoopClone.Source, { text =
-- require(freshTextClone), species = require(freshSpeciesClone), state = require(freshStateClone), economy =
-- require(freshEconomyClone), config = require(freshEconomyConfigClone), server = WildboundServer.Source, client =
-- WildboundClient.Source, guide = WildboundBaseGuideClient.Source, catalog = require(freshAudioCatalogClone) }).
-- Egg loop (docs/design/wildbound-egg-loop.md): the pure rules (objective line, FIFO auto-fill, reward encoding, the
-- cradle's sign, the shelf, the hatch banner), the bank -> collection -> reward -> incubator -> hatch path through the
-- real WildboundState, and the source contracts for the server and the two clients.
return function(EggLoop, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or needle) .. " missing")
	end
	sources = type(sources) == "table" and sources or {}
	local Text = sources.text
	local looks = sources.species and sources.species.LOOKS or nil

	case("EL1: presentation numbers are PROPUESTA, frozen, and change no reward", function()
		local C = EggLoop.CONFIG
		assert(table.isfrozen(C), "frozen")
		equal(C.REWARD_TOAST_SECONDS, 3.5); equal(C.HATCH_BANNER_SECONDS, 4); equal(C.SHELF_MAX, 6)
		equal(C.SPARKLES, 40); equal(C.SPARKLES_REDUCED, 12)
		has(source, "PROPUESTA", "marked for the owner")
	end)

	case("EL2: rarity: own field, then species, then risk tier, then Comun", function()
		equal(EggLoop.rarityOf({ rarity = "Epica", species = "Lumipol" }, looks), "Epica")
		equal(EggLoop.rarityOf({ species = "Cestillo" }, { Cestillo = { rarity = "Rara" } }), "Rara")
		equal(EggLoop.rarityOf({ species = "Nope", riskTier = "Heart" }, {}), "Legendaria")
		equal(EggLoop.rarityOf({ riskTier = "FogFar" }), "Rara")
		equal(EggLoop.rarityOf({}), "Comun"); equal(EggLoop.rarityOf(nil), "Comun")
		if looks then equal(EggLoop.rarityOf({ species = "Lumipol" }, looks), "Comun") end
	end)

	case("EL3: the objective state machine: carry, incubate, again, steal", function()
		local function f(extra)
			local value = { carryingEgg = false, stored = 0, incubating = 0, registered = 0, slots = 1 }
			for key, item in pairs(extra) do value[key] = item end
			return value
		end
		equal(EggLoop.objective(f({})), "steal", "nothing yet")
		equal(EggLoop.objective(f({ carryingEgg = true, stored = 3, incubating = 0 })), "carry", "carrying wins")
		equal(EggLoop.objective(f({ stored = 1 })), "incubate", "a stored egg and a free cradle")
		equal(EggLoop.objective(f({ stored = 1, incubating = 1 })), "again", "cradle full")
		equal(EggLoop.objective(f({ stored = 1, incubating = 1, slots = 2 })), "incubate", "a second cradle")
		equal(EggLoop.objective(f({ incubating = 1 })), "again", "hatching")
		equal(EggLoop.objective(f({ registered = 2 })), "again", "a veteran with nothing at home")
		equal(EggLoop.objective(nil), "steal")
	end)

	case("EL4: facts read the snapshot: only an egg in the backpack slot counts as carrying", function()
		local facts = EggLoop.facts({ pending = { { kind = "Egg", inArms = true } }, bankedEggs = { {}, {} },
			incubating = { { readyAt = 50 }, { readyAt = 30 } }, registered = { {} } }, 1)
		equal(facts.carryingEgg, true); equal(facts.stored, 2); equal(facts.incubating, 2); equal(facts.soonest, 30)
		equal(facts.registered, 1); equal(facts.slots, 1)
		equal(EggLoop.facts({ pending = { { kind = "Egg" } } }).carryingEgg, false, "an egg in the bag only")
		local empty = EggLoop.facts(nil, 0 / 0)
		equal(empty.stored, 0); equal(empty.slots, 1); equal(empty.soonest, nil)
	end)

	case("EL5: the objective words: every line fits the HUD (42 bytes), the timer counts down", function()
		assert(type(Text) == "table" and type(Text.LOOP) == "table", "Text.LOOP")
		local L = Text.LOOP
		for _, key in ipairs({ "steal", "carry", "incubate", "again", "againReady" }) do
			assert(type(L[key]) == "string" and #L[key] <= 42, key .. " fits")
		end
		assert(#L.againTimer:format("12:59") <= 42, "the timer line fits")
		local facts = { carryingEgg = false, stored = 0, incubating = 1, soonest = 190, registered = 0, slots = 1 }
		local line, id = EggLoop.objectiveText(facts, 100, Text)
		equal(id, "again"); equal(line, L.againTimer:format("1:30"))
		equal((EggLoop.objectiveText(facts, 190, Text)), L.againReady, "time is up")
		equal((EggLoop.objectiveText({ carryingEgg = true }, 0, Text)), L.carry)
		equal(EggLoop.clock(0), "0:00"); equal(EggLoop.clock(59.2), "1:00"); equal(EggLoop.clock(0 / 0), "0:00")
	end)

	case("EL6: auto-fill takes the oldest stored egg, only into a free cradle", function()
		local eggs = { { uid = "wb:3" }, { uid = "wb:7" } }
		equal(EggLoop.nextToIncubate(eggs, 0, 1), "wb:3", "first in, first out")
		equal(EggLoop.nextToIncubate(eggs, 1, 1), nil, "cradle busy")
		equal(EggLoop.nextToIncubate(eggs, 1, 2), "wb:3", "a second cradle")
		equal(EggLoop.nextToIncubate({}, 0, 1), nil, "nothing stored")
		equal(EggLoop.nextToIncubate({ { uid = "" }, { uid = "wb:9" } }, 0, 1), "wb:9", "a malformed entry is skipped")
		equal(EggLoop.nextToIncubate(nil, 0, 1), nil)
	end)

	case("EL7: the reward round-trips through the attribute string; a new nonce is a new value", function()
		local reward = { species = "Lumipol", rarity = "Rara", ember = 10.7, stored = 2, incubating = true, nonce = 12.5 }
		local value = EggLoop.encodeReward(reward)
		local back = EggLoop.decodeReward(value)
		assert(back, "decoded")
		equal(back.species, "Lumipol"); equal(back.rarity, "Rara"); equal(back.ember, 10); equal(back.stored, 2)
		equal(back.incubating, true)
		reward.nonce = 13
		assert(EggLoop.encodeReward(reward) ~= value, "every bank changes the attribute")
		equal(EggLoop.encodeReward({ species = "a|b" }), nil, "no separator in a name")
		equal(EggLoop.decodeReward("2|Lumipol|Comun|8|0|0|1"), nil, "unknown version")
		equal(EggLoop.decodeReward("1|Lumipol|Mitica|8|0|0|1"), nil, "unknown rarity")
		equal(EggLoop.decodeReward(nil), nil)
	end)

	case("EL8: the toast, the cradle sign, the shelf and the hatch banner", function()
		local L = Text.LOOP
		local lines = EggLoop.rewardLines({ species = "Lumipol", rarity = "Comun", ember = 8, stored = 3, incubating = false },
			Text)
		equal(lines.title, "¡Huevo guardado!")
		equal(lines.line, L.bankedLine:format(Text.CARD.species.Lumipol or "Lumipol", Text.RARITY.Comun, 8))
		equal(lines.sub, L.bankedStored:format(3))
		equal(EggLoop.rewardLines({ species = "Lumipol", rarity = "Comun", ember = 8, stored = 0, incubating = true }, Text).sub,
			L.bankedIncubating)
		-- Play check 2026-11-12: a Safe-tier egg pays 0; the toast says no "+0".
		equal(EggLoop.rewardLines({ species = "Lumipol", rarity = "Comun", ember = 0, stored = 1 }, Text).line,
			L.eggRow:format(Text.CARD.species.Lumipol or "Lumipol", Text.RARITY.Comun))
		local text, mode = EggLoop.cradleLine({ species = "Lumipol", readyAt = 130 }, 100, 0, Text)
		equal(mode, "busy"); has(text, "0:30")
		equal(select(2, EggLoop.cradleLine({ species = "Lumipol", readyAt = 100 }, 100, 0, Text)), "ready")
		equal(select(2, EggLoop.cradleLine(nil, 100, 2, Text)), "freeEggs")
		equal((EggLoop.cradleLine(nil, 100, 0, Text)), L.cradleFree)
		local shelf = EggLoop.shelf({ {}, {}, {}, { riskTier = "Heart" } }, 3)
		equal(#shelf.rarities, 3); equal(shelf.extra, 1)
		local hatch = EggLoop.hatchLines({ uid = "wb:9", species = "Lumipol" }, "wb:9", Text)
		equal(hatch.title, "¡Nuevo compañero!"); has(hatch.line, "te acompaña")
		has(EggLoop.hatchLines({ uid = "wb:9", species = "Lumipol" }, "wb:1", Text).line, "Inventario", "where it went")
		has(EggLoop.eggRow({ species = "Lumipol" }, looks, Text), Text.RARITY.Comun)
	end)

	case("EL9: bank -> collection -> reward -> incubator -> hatch through the real State", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		assert(State and Economy and Config, "State, Economy and the config")
		local state = State.new(Economy, Config)
		assert(state:addPlayer(1))
		state:registerEncounter("nest-1", "Egg")
		assert(state:takeEgg(1, { uid = "wb:egg1", kind = "Egg", species = "Lumipol", riskTier = "Fog" }, true, 0))
		local before = state:snapshot(1)
		equal(EggLoop.objective(EggLoop.facts(before, 1)), "carry")
		local pendingEgg = before.pending[1]
		local ember = Economy.itemEmber(Config, pendingEgg)
		equal(ember, Config.earn.eggEmberByTier.Fog, "the egg pays its tier's Esencia")
		local ok, count, receipt = state:extract(1, true, 0, 1000)
		assert(ok and count == 1, "banked")
		assert(receipt.ember >= ember, "the receipt carries the egg's Esencia")
		local banked = state:snapshot(1)
		equal(#banked.bankedEggs, 1, "in the collection"); equal(banked.bankedEggs[1].uid, "wb:egg1")
		equal(EggLoop.objective(EggLoop.facts(banked, 1)), "incubate")
		local uid = EggLoop.nextToIncubate(banked.bankedEggs, #banked.incubating, 1)
		equal(uid, "wb:egg1")
		local filled, entry = state:incubate(1, uid, true, 0, 1000, 90, 1)
		assert(filled and entry.readyAt == 1090, "in the cradle")
		local busy = state:snapshot(1)
		equal(EggLoop.objective(EggLoop.facts(busy, 1)), "again")
		equal(EggLoop.nextToIncubate(busy.bankedEggs, #busy.incubating, 1), nil, "nothing else to fill")
		equal(#state:hatchReady(1, 1089), 0, "not yet")
		local born = state:hatchReady(1, 1090)
		equal(#born, 1); equal(born[1].species, "Lumipol"); equal(born[1].equipped, true, "the first one follows")
		local after = state:snapshot(1)
		equal(#after.registered, 1); equal(#after.incubating, 0)
		equal(EggLoop.objective(EggLoop.facts(after, 1)), "again")
	end)

	case("EL10: a second egg waits in the collection while the cradle is busy, then goes in FIFO", function()
		local State, Economy, Config = sources.state, sources.economy, sources.config
		local state = State.new(Economy, Config)
		state:addPlayer(2)
		for index = 1, 2 do
			assert(state:takeEgg(2, { uid = "wb:e" .. index, kind = "Egg", species = "Lumipol", riskTier = "Fog" }, true, 0))
			assert(state:extract(2, true, 0, 100 * index))
			local snap = state:snapshot(2)
			local uid = EggLoop.nextToIncubate(snap.bankedEggs, #snap.incubating, 1)
			if uid then assert(state:incubate(2, uid, true, 0, 100 * index, 90, 1)) end
		end
		local snap = state:snapshot(2)
		equal(#snap.incubating, 1); equal(snap.incubating[1].uid, "wb:e1", "the first egg went in")
		equal(#snap.bankedEggs, 1); equal(snap.bankedEggs[1].uid, "wb:e2", "the second waits")
		state:hatchReady(2, 1000)
		snap = state:snapshot(2)
		equal(EggLoop.nextToIncubate(snap.bankedEggs, #snap.incubating, 1), "wb:e2", "refilled after the hatch")
	end)

	case("EL11: pure: no services, clock, world or randomness", function()
		for _, needle in ipairs({ "GetService", "os.time", "os.clock", "tick()", "workspace", "Instance.new", "math.random",
			"DataStore" }) do
			assert(not source:find(needle, 1, true), "source has " .. needle)
		end
	end)

	case("EL12: the server banks first, rewards on an attribute, then auto-fills; the hatch step refills", function()
		local server = sources.server
		assert(type(server) == "string" and #server > 1000, "server source")
		has(server, 'ReplicatedStorage:WaitForChild("WildboundEggLoop")')
		local enter = server:match("function Heist%.enterBase%(player, now%)(.-)\nend\n")
		assert(enter, "enterBase body")
		local extract = enter:find("state:extract(", 1, true)
		local secure = enter:find("Heist.secure(player)", 1, true)
		local reward = enter:find('"WildboundEggReward"', 1, true)
		local fill = enter:find("Heist.autoIncubate(player", 1, true)
		assert(extract and secure and reward and fill and extract < secure and secure < fill and fill < reward,
			"bank, secure, fill the cradle, then the reward attribute")
		has(enter, "Heist.EggLoop.encodeReward(", "the encoded reward")
		has(enter, "Economy.itemEmber(EconomyConfig", "the egg's own Esencia, from the economy config")
		local auto = server:match("function Heist%.autoIncubate%((.-)\nend\n")
		assert(auto, "autoIncubate body")
		has(auto, "Heist.EggLoop.nextToIncubate("); has(auto, "state:incubate("); has(auto, "Incubator.live.SLOTS")
		local hatchStep = server:match("local function stepIncubators%(now%)(.-)\nend\n")
		assert(hatchStep, "stepIncubators body")
		has(hatchStep, "Heist.BaseZone.isInside(", "a refill only while the owner stands in the base")
		has(hatchStep, "Heist.autoIncubate(player", "the next stored egg goes in")
	end)

	case("EL13: the clients only draw: objective line, toast, cradle sign, shelf, hatch banner, catalog sounds", function()
		local client, guide, catalog = sources.client, sources.guide, sources.catalog
		has(client, "EggLoop.objectiveText(", "the HUD objective line")
		has(client, "EggLoop.eggRow(", "the stored egg rows name the rarity")
		has(guide, '"WildboundEggReward"'); has(guide, "EggLoop.decodeReward("); has(guide, "EggLoop.rewardLines(")
		has(guide, "EggLoop.cradleLine("); has(guide, "EggLoop.shelf("); has(guide, "EggLoop.hatchLines(")
		has(guide, "ParticleEmitter", "sparkles"); has(guide, "Catalog.SOUNDS", "sounds from the catalog")
		has(guide, '"WildboundIncubatorStation"', "the own base's cradle")
		for _, code in ipairs({ client, guide }) do
			assert(not code:find("rbxassetid://%d"), "no hard-coded asset id")
		end
		assert(not guide:find("FireServer", 1, true) and not guide:find("InvokeServer", 1, true), "the guide sends nothing")
		if catalog then
			assert(catalog.SOUNDS.eggBanked and not catalog.SOUNDS.eggBanked.loop, "the bank sound")
			assert(catalog.SOUNDS.eggHatched and not catalog.SOUNDS.eggHatched.loop, "the hatch sound")
		end
	end)

	return result
end
