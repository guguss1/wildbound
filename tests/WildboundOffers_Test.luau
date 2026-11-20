-- Invoke with require(freshTestClone)(require(freshOffersClone), require(freshFlagsClone), require(freshEconomyConfigClone),
-- { offers = WildboundOffers.Source, flags = WildboundFlags.Source, service = WildboundRouletteService.Source,
-- client = WildboundRouletteClient.Source, wheel = WildboundRouletteWheel.Source, style = WildboundUiStyle.Source,
-- server = WildboundServer.Source }).
-- RW-4 (P0.2 of docs/design/wildbound-fun-build-plan.md; owner request 2026-11-20: "que lo de la ruleta sea asi",
-- docs/design/refs/roulette-wheel-reference.webp): the offers catalog and the development switch. Pins the three spin
-- packs (+1 / +3 / +10 spins at the placeholder prices 9 / 29 / 89), the pure claim rule (the switch, the 99 cap, catalog
-- ids only), DESBLOQUEAR_TODO = true in WildboundFlags with monetization still "none", and that no roulette or offers
-- source (nor the server) names a purchase call. tools/test_no_purchase_calls.py checks every game script.
-- Pure: no Instance is made.
return function(Offers, Flags, EconomyConfig, sources)
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
	sources = type(sources) == "table" and sources or {}

	case("O1: three spin packs like the reference, frozen, valid, with Spanish names and placeholder prices", function()
		assert(type(Offers.LIST) == "table" and table.isfrozen(Offers.LIST), "LIST frozen")
		assert(table.isfrozen(Offers.WORDS), "WORDS frozen")
		local want = {
			{ "rouletteSpins1", 1, 9, "+1 Tirada", "Paquete chico", "green" },
			{ "rouletteSpins3", 3, 29, "+3 Tiradas", "Popular", "blue" },
			{ "rouletteSpins10", 10, 89, "+10 Tiradas", "Mejor oferta", "purple" },
		}
		equal(#Offers.list(), #want, "offers")
		for index, row in ipairs(want) do
			local offer = Offers.list()[index]
			equal(offer.id, row[1], "id " .. index)
			equal(offer.kind, "rouletteSpins", row[1] .. " kind")
			equal(offer.spins, row[2], row[1] .. " spins")
			equal(offer.robux, row[3], row[1] .. " price")
			equal(offer.name, row[4], row[1] .. " name")
			equal(offer.caption, row[5], row[1] .. " caption")
			equal(offer.tone, row[6], row[1] .. " tone")
			assert(table.isfrozen(offer), row[1] .. " frozen")
		end
		local ok, errors = Offers.validate()
		assert(ok, "the catalog validates: " .. table.concat(errors or {}, " | "))
		equal(Offers.WORDS.devFree, "modo desarrollo: gratis")
		equal(Offers.WORDS.comingSoon, "Próximamente")
		equal(Offers.WORDS.granted:format("+3 Tiradas", 3), "¡+3 Tiradas gratis! Tiradas extra: 3")
	end)

	case("O2: get() finds only a catalog id given as a string", function()
		equal(Offers.get("rouletteSpins3").spins, 3)
		for _, bad in ipairs({ "rouletteSpins2", "ROULETTESPINS1", "", 1, true, { "rouletteSpins1" } }) do
			equal(Offers.get(bad), nil, "id " .. tostring(bad))
		end
		equal(Offers.get(nil), nil, "nil")
	end)

	case("O3: the switch: only DESBLOQUEAR_TODO = true opens; the flags turn it on and stay frozen", function()
		equal(Offers.unlocked({ DESBLOQUEAR_TODO = true }), true)
		equal(Offers.unlocked({ DESBLOQUEAR_TODO = false }), false)
		equal(Offers.unlocked({ DESBLOQUEAR_TODO = "true" }), false, "only a real true")
		equal(Offers.unlocked({}), false, "missing")
		equal(Offers.unlocked(nil), false, "no flags")
		equal(Flags.DESBLOQUEAR_TODO, true, "development: everything open (owner, 2026-11-20)")
		equal(Offers.unlocked(Flags), true)
		assert(table.isfrozen(Flags), "flags frozen")
		equal(Flags.damageMode, "private", "the other flags are untouched")
		equal(Flags.persistenceMode, "datastore", "the other flags are untouched")
	end)

	case("O4: claim(): the catalog id, the switch, the 99 cap (refused whole) and a bad count read as 0", function()
		local ok, held, offer = Offers.claim("rouletteSpins3", true, 0)
		equal(ok, true); equal(held, 3); equal(offer.id, "rouletteSpins3")
		equal(select(2, Offers.claim("rouletteSpins10", true, 5)), 15, "adds")
		local locked, why = Offers.claim("rouletteSpins1", false, 0)
		equal(locked, false); equal(why, "Locked", "switch off")
		equal(select(2, Offers.claim("rouletteSpins1", nil, 0)), "Locked", "no switch")
		equal(select(2, Offers.claim("nope", true, 0)), "UnknownOffer")
		equal(select(2, Offers.claim(nil, true, 0)), "UnknownOffer")
		equal(Offers.MAX_EXTRA_SPINS, 99)
		equal(select(2, Offers.claim("rouletteSpins10", true, 89)), 99, "up to the cap")
		local full, reason = Offers.claim("rouletteSpins10", true, 90)
		equal(full, false); equal(reason, "Full", "over the cap: refused whole")
		equal(select(2, Offers.claim("rouletteSpins1", true, 98)), 99)
		for _, bad in ipairs({ -3, 2.5, 0 / 0, math.huge, "7" }) do
			equal(select(2, Offers.claim("rouletteSpins1", true, bad)), 1, "held " .. tostring(bad) .. " reads as 0")
		end
		equal(select(2, Offers.claim("rouletteSpins1", true, nil)), 1, "nil reads as 0")
	end)

	case("O5: validate() catches a broken catalog", function()
		local function broken(change, needle)
			local list = {}
			for index, offer in ipairs(Offers.LIST) do list[index] = table.clone(offer) end
			change(list)
			local ok, errors = Offers.validate(list)
			assert(ok == false, needle .. ": expected a failure")
			assert(table.concat(errors, " | "):lower():find(needle, 1, true), needle .. ": " .. table.concat(errors, " | "))
		end
		broken(function(list) list[2].id = "rouletteSpins1" end, "duplicate")
		broken(function(list) list[1].spins = 0 end, "spins")
		broken(function(list) list[1].spins = 1.5 end, "spins")
		broken(function(list) list[3].robux = -1 end, "price")
		broken(function(list) list[3].kind = "gloves" end, "kind")
		broken(function(list) list[2].name = "" end, "name")
		broken(function(list) list[2].caption = nil end, "caption")
		local ok = Offers.validate({})
		equal(ok, false, "an empty catalog")
	end)

	-- Nothing is ever charged: monetization stays "none", and no source of the roulette, the offers, the kit or the
	-- server names a purchase call. The word "Robux" stays in the catalog (and the kit's sign), never in the window.
	case("O6: monetization stays none and no source names a purchase call", function()
		equal(Offers.MONETIZATION, "none")
		equal(EconomyConfig.monetization, "none", "WildboundEconomyConfig")
		equal(Flags.monetization, nil, "the switch does not change monetization")
		local banned = { "MarketplaceService", "PromptProductPurchase", "PromptGamePassPurchase", "PromptPurchase",
			"PromptBundlePurchase", "PromptPremiumPurchase", "ProcessReceipt", "UserOwnsGamePassAsync" }
		for _, key in ipairs({ "offers", "flags", "service", "client", "wheel", "style", "server" }) do
			local text = sources[key]
			assert(type(text) == "string" and #text > 0, key .. " source")
			for _, word in ipairs(banned) do
				assert(not text:find(word, 1, true), key .. " names " .. word)
			end
		end
		assert(sources.offers:find("Robux", 1, true), "the catalog names its currency")
		for _, key in ipairs({ "client", "wheel" }) do
			assert(not sources[key]:find("Robux", 1, true), key .. ": the word stays in the catalog")
		end
		local service = sources.service
		assert(service:find("self.offers.claim(offerId, self.unlocked", 1, true), "the server decides with the switch")
		assert(service:find('script.Parent:FindFirstChild("WildboundFlags")', 1, true), "the switch is read on the server")
		assert(not sources.client:find("WildboundFlags", 1, true), "the client never reads the server's flags")
		for _, word in ipairs({ "game:", "Instance.new", "task.", "os.", "Random", "require(" }) do
			assert(not sources.offers:find(word, 1, true), "the catalog is pure: " .. word)
		end
	end)

	return result
end
