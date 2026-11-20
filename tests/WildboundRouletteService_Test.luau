-- Invoke with require(freshTestClone)(require(freshServiceClone), require(freshRouletteClone), require(freshStateClone),
-- require(freshEconomyClone), require(freshConfigClone), require(freshTextClone), { server = WildboundServer.Source,
-- service = freshServiceClone.Source, client = WildboundRouletteClient.Source }, require(freshOffersClone)).
-- PF5 (user decision 2026-11-14, odd/tasks/wildbound-playtest-fixes.md): the hub roulette. One station in the hub plaza
-- that everyone may use; the server alone validates (rate limit, alive, distance from the server-side root), rolls,
-- spends Esencia atomically through State:spinRoulette and grants. The client only asks to "spin" (or, RW-4, for a
-- spin pack by its catalog id) and the odds are one tap away before spinning. Fakes only: fake players and roots, a
-- scripted rng and clock, and a parentless folder.
-- RW-4 / RW-5 (owner request 2026-11-20): spin packs from WildboundOffers, free on the server while the development
-- switch is on (the suite injects it: unlockAll), "Próximamente" when it is off; the extra spins live in the service
-- for the session only and cost no Esencia.
return function(Service, Roulette, State, Economy, Config, Text, sources, Offers)
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
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	sources = type(sources) == "table" and sources or {}

	local STATION = Vector3.new(265, 0.5, 14)
	-- A world: one State with one player, a fake root near the station, a scripted rng and clock, captured messages.
	-- RW-4: the offers catalog and the development switch are injected (options.locked turns it off); the HUD notice's
	-- wait runs at once unless options.holdNotice keeps it in w.deferred.
	local function world(options)
		options = options or {}
		assert(type(Offers) == "table", "the suite needs WildboundOffers (8th argument)")
		local state = State.new(Economy, Config)
		local player = { UserId = 501, Name = "Tester" }
		state:addPlayer(player.UserId)
		local w = { state = state, player = player, t = 100, rolls = {}, rolled = 0, fired = {}, notified = {},
			deferred = {}, alive = true, root = { Position = STATION + Vector3.new(3, 2, 0) } }
		w.service = Service.new({
			state = state,
			Roulette = Roulette,
			Text = Text,
			Offers = Offers,
			unlockAll = options.locked ~= true,
			alive = function() return w.alive end,
			rootOf = function() return w.root end,
			random = function()
				w.rolled += 1
				return table.remove(w.rolls, 1) or 0
			end,
			now = function() return w.t end,
			fire = function(target, kind, payload) table.insert(w.fired, { player = target, kind = kind, payload = payload }) end,
			notify = function(target, ok, text) table.insert(w.notified, { player = target, ok = ok, text = text }) end,
			after = function(seconds, run)
				if options.holdNotice then
					table.insert(w.deferred, { seconds = seconds, run = run })
				else
					run()
				end
			end,
			position = STATION,
		})
		w.offerLater = function() w.t += Service.OFFER_SECONDS + 0.01 end
		w.last = function() return w.fired[#w.fired] end
		w.profile = function() return state.players["n:" .. player.UserId] end
		w.snap = function() return state:snapshot(player.UserId) end
		w.later = function() w.t += Service.SPIN_SECONDS + 0.01 end
		return w
	end

	case("RS-1: the view lists every prize's odds in Spanish, the price or the free spin and the pity counter", function()
		local w = world()
		local view = w.service:view(w.player)
		equal(view.free, true, "one free spin per account")
		equal(view.price, 45); equal(view.price, Roulette.LIVE.spinCost)
		equal(view.pityEvery, 10); equal(view.pityLeft, 10); equal(view.pityRarity, Text.RARITY.Rara)
		equal(view.canSpin, true, "the free spin needs no Esencia")
		equal(#view.odds, #Roulette.LIVE.prizes, "one row per prize")
		local sum = 0
		for index, row in ipairs(view.odds) do
			local prize = Roulette.LIVE.prizes[index]
			equal(row.id, prize.id, "row " .. index)
			equal(row.label, Text.ROULETTE.prizes[prize.id], row.id .. " label from WildboundText")
			equal(row.rarity, Text.RARITY[prize.rarity], row.id .. " rarity word")
			equal(row.rarityKey, prize.rarity)
			assert(math.abs(row.percent - prize.weight / 100) < 1e-9, row.id .. " percent")
			sum += row.percent
		end
		assert(math.abs(sum - 100) < 1e-9, "the odds sum to 100")
		equal(w.service:open(w.player), true, "open")
		local message = w.last()
		equal(message.kind, "open"); equal(message.player, w.player)
		equal(#message.payload.odds, #Roulette.LIVE.prizes, "the odds are sent before any spin")
		equal(w.rolled, 0, "opening never rolls"); equal(w.snap().ember, 0, "opening never spends")
	end)

	case("RS-2: the free spin grants on the server; then a paid spin without 45 Esencia is refused and changes nothing", function()
		local w = world()
		w.rolls = { 0 }
		local ok = w.service:spin(w.player)
		equal(ok, true, "the free spin")
		local message = w.last()
		equal(message.kind, "result"); equal(message.payload.prizeId, "esencia10"); equal(message.payload.free, true)
		equal(message.payload.cost, 0)
		equal(message.payload.text, Text.ROULETTE.wonFree:format(Text.ROULETTE.prizes.esencia10))
		equal(message.payload.index, 1, "the row the client's spin lands on")
		equal(message.payload.view.free, false, "the free spin is used")
		equal(w.snap().ember, 10); equal(w.snap().roulette.freeSpinUsed, true)
		equal(#w.notified, 1, "the HUD is refreshed once"); equal(w.notified[1].text, message.payload.text)
		w.later()
		w.rolls = { 0.98 }
		local paid, reason = w.service:spin(w.player)
		equal(paid, false); equal(reason, "CannotAfford")
		equal(w.last().kind, "refused")
		equal(w.last().payload.text, Text.ROULETTE.cannotAfford:format(35), "it says how much is missing")
		equal(w.snap().ember, 10, "nothing paid"); equal(w.snap().banked.fogbark, 0, "nothing granted")
		equal(w.snap().roulette.paidSpins, 0, "not counted")
		equal(#w.notified, 1, "a refusal grants nothing to show")
	end)

	case("RS-3: a paid spin takes 45 Esencia and grants the server's prize (materials to the bank)", function()
		local w = world()
		w.rolls = { 0 }
		w.service:spin(w.player)
		w.profile().ember = 100
		w.later()
		w.rolls = { 0.98 }
		local ok = w.service:spin(w.player)
		equal(ok, true)
		local payload = w.last().payload
		equal(payload.prizeId, "forestChest"); equal(payload.cost, 45); equal(payload.free, false)
		equal(payload.rarity, Text.RARITY.Legendaria)
		equal(payload.text, Text.ROULETTE.won:format(Text.ROULETTE.prizes.forestChest))
		local snap = w.snap()
		equal(snap.ember, 55, "100 - 45")
		equal(snap.banked.fogbark, 40); equal(snap.banked.glowmoss, 20); equal(snap.banked.nightbloom, 5)
		equal(snap.roulette.paidSpins, 1); equal(snap.roulette.pityCount, 0, "a Legendaria resets the pity")
		equal(payload.view.price, 45); equal(payload.view.free, false); equal(payload.view.ember, 55)
	end)

	case("RS-4: one spin at a time: a second spin inside SPIN_SECONDS is refused before rolling", function()
		local w = world()
		w.profile().ember = 500
		w.rolls = { 0, 0 }
		equal((w.service:spin(w.player)), true)
		local ok, reason = w.service:spin(w.player)
		equal(ok, false); equal(reason, "Busy")
		equal(w.last().payload.text, Text.ROULETTE.busy)
		equal(w.rolled, 1, "the refused spin never rolled"); equal(w.snap().ember, 510, "only the free spin's prize")
		w.later()
		equal((w.service:spin(w.player)), true, "after the spin finishes")
		equal(w.snap().ember, 510 - 45 + 10)
	end)

	case("RS-5: a dead, rootless or far player is refused before rolling; nothing changes", function()
		local w = world()
		w.profile().ember = 500
		w.alive = false
		equal(select(2, w.service:spin(w.player)), "InvalidContext")
		equal(w.last().payload.text, Text.ROULETTE.unavailable)
		w.alive, w.root = true, nil
		w.later()
		equal(select(2, w.service:spin(w.player)), "InvalidContext")
		w.root = { Position = STATION + Vector3.new(Service.RANGE + 1, 0, 0) }
		w.later()
		equal(select(2, w.service:spin(w.player)), "TooFar")
		equal(w.last().payload.text, Text.ROULETTE.tooFar)
		equal((w.service:open(w.player)), false, "the odds panel opens only near the station")
		equal(w.rolled, 0, "never rolled"); equal(w.snap().ember, 500)
		equal(w.snap().roulette.freeSpinUsed, false, "the free spin is still there")
		local stranger = { UserId = 777, Name = "NoProfile" }
		w.root = { Position = STATION }
		w.later()
		equal(select(2, w.service:spin(stranger)), "InvalidPlayer", "a player without a profile")
	end)

	case("RS-6: the remote handler reads only the action word; prize, price or rng from the client are ignored", function()
		local w = world()
		w.profile().ember = 500
		w.rolls = { 0 }
		equal((w.service:handle(w.player, "spin", "forestChest", 0, 0.98)), true)
		equal(w.last().payload.prizeId, "esencia10", "the server's roll, not the client's")
		equal(w.snap().ember, 510)
		w.later()
		for _, bad in ipairs({ "grant", "SPIN", 5, { "spin" } }) do
			equal((w.service:handle(w.player, bad)), false, "ignored: " .. tostring(bad))
		end
		equal((w.service:handle(w.player)), false, "ignored: no action")
		equal(w.rolled, 1, "nothing else rolled"); equal(w.snap().ember, 510)
		equal((w.service:handle(w.player, "open")), true, "open")
		equal(w.last().kind, "open")
	end)

	case("RS-7: the pity counter counts down and the 10th paid spin without Rara+ gives Rara or better", function()
		local w = world()
		w.profile().ember = 2000
		w.rolls = { 0 }
		w.service:spin(w.player)
		for spin = 1, 9 do
			w.later()
			w.rolls = { 0 }
			w.service:spin(w.player)
			equal(w.last().payload.prizeId, "esencia10", "miss " .. spin)
			equal(w.last().payload.view.pityLeft, 10 - spin, "counter after miss " .. spin)
		end
		w.later()
		w.rolls = { 0 }
		w.service:spin(w.player)
		local payload = w.last().payload
		equal(payload.prizeId, "esencia45", "the Rara+ pool"); equal(payload.pity, true)
		equal(payload.text, Text.ROULETTE.pityWon:format(Text.ROULETTE.prizes.esencia45))
		equal(payload.view.pityLeft, 10, "reset")
	end)

	case("RS-8: the station is built at runtime with one prompt everyone may use (no owner gating)", function()
		local w = world()
		local folder = Instance.new("Folder")
		local model = w.service:build(folder, CFrame.new(240, 0.5, 30))
		equal(model.Parent, folder); equal(model.Name, "WildboundRouletteStation")
		equal(model:GetAttribute("OwnerUserId"), nil, "no owner")
		local prompts = {}
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("ProximityPrompt") then table.insert(prompts, item) end
		end
		equal(#prompts, 1, "one prompt")
		local prompt = prompts[1]
		equal(prompt.ActionText, Text.ROULETTE.prompt); equal(prompt.ObjectText, Text.ROULETTE.object)
		equal(prompt.HoldDuration, 0); equal(prompt.RequiresLineOfSight, false)
		equal(prompt:GetAttribute("WildboundHubStation"), nil, "not a base station")
		assert(prompt.MaxActivationDistance <= Service.RANGE, "the prompt reaches no farther than a spin")
		equal(w.service.position, Vector3.new(240, 0.5, 30), "spins measure from the built station")
		local anchored = true
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") and not item.Anchored then anchored = false end
		end
		equal(anchored, true, "every part is anchored")
		folder:Destroy()
	end)

	-- Deliberately changed (RW-4, owner request 2026-11-20): the remote handler also reads one offer id (for "offer"
	-- only) and the client may send "offer" with a catalog id besides "spin".
	case("RS-9: wiring: the server starts the service in a do block with a server rng; the client sends only spin/offer", function()
		local server = sources.server or ""
		has(server, 'require(script.Parent:WaitForChild("WildboundRouletteService"))')
		has(server, "Heist.roulette = RouletteService.new({")
		has(server, "Random.new()", "a server-side rng")
		has(server, "Rules.HUB_X", "the station stands in the hub plaza")
		local at = server:find('require(script.Parent:WaitForChild("WildboundRouletteService"))', 1, true)
		assert(at, "service required")
		local lineStart = server:sub(1, at):match(".*()\n") or 1
		local line = server:sub(lineStart, at)
		hasNot(line, "\nlocal RouletteService", "the server adds no top-level local (NH-W13)")
		local service = sources.service or ""
		has(service, "OnServerEvent:Connect(function(player, action, offerId)", "the handler reads one word and one offer id")
		has(service, "self:handle(player, action, offerId)", "nothing else reaches the handler")
		hasNot(service, "math.random", "the roll comes from the injected server rng")
		local client = sources.client or ""
		assert(#client > 0, "client source")
		local calls, seen = 0, {}
		for args in client:gmatch("FireServer%(([^)]*)%)") do
			calls += 1
			seen[args] = true
			assert(args == '"open"' or args == '"spin"' or args == '"offer", pack.offer.id',
				"the client sends only spin or offer with a catalog id: " .. args)
		end
		assert(calls >= 2, "the client asks the server to spin and for packs")
		assert(seen['"spin"'] and seen['"offer", pack.offer.id'], "spin and offer")
		has(client, "Text.ROULETTE", "the client words come from WildboundText")
	end)

	-- Deliberately changed (P0.1, owner request 2026-11-20): the roulette window leaves the dark Style.panel for the
	-- store kit in WildboundUiStyle (docs/design/refs/store-ui-reference.png).
	-- Deliberately changed again (RW-1..RW-6, owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente
	-- igual a la de la foto que te envie y que lo de la ruleta sea asi", docs/design/refs/roulette-wheel-reference.webp):
	-- the blue window, the cyan price card and its rays and the X give way to the wheel of the reference over a dimmed
	-- screen: "Tiradas: N", the wheel (WildboundRouletteWheel), the green "Girar" and red "Cerrar", the round "i" that
	-- opens the odds window (the store-kit window with the old odds words and its own X), and the three spin packs with
	-- the Robux sign (kit glyph) and "modo desarrollo: gratis". Every box comes from Wheel.layout (phones either way);
	-- "Efectos suaves" picks the short spin. Still no purchase call. After review: Girar stays off for the server's
	-- spinSeconds after a tap, a second "open" during a spin is ignored, and the odds window says extra spins skip the pity.
	case("RS-10: the roulette window is the wheel of the reference, keeps its words and opens the odds from the i", function()
		local client = sources.client or ""
		assert(#client > 0, "client source")
		hasNot(client, "Style.panel(panel)", "the old dark panel")
		for _, gone in ipairs({ "Style.kitCard(", "Style.setSpin(", "CARD_HEIGHT" }) do
			hasNot(client, gone, "client")
		end
		for _, needle in ipairs({ "require(ReplicatedStorage:WaitForChild(\"WildboundRouletteWheel\"))",
			"require(ReplicatedStorage:WaitForChild(\"WildboundOffers\"))", "WHEEL_WORDS.spinsLeft:format(view.spinsLeft or 0)",
			"Style.kitTitle(panel, WHEEL_WORDS.spinsLeft", "Style.kitButton(panel, WORDS.spin, \"green\", \"Spin\")",
			"Style.kitButton(panel, WORDS.close, \"red\", \"Close\")", "Style.kitButton(panel, WHEEL_WORDS.oddsButton",
			"Style.kitWindow(gui, \"OddsPanel\"", "Style.kitTitle(oddsPanel, WORDS.oddsHeader", "Style.kitClose(oddsPanel)",
			"WORDS.oddsNote", "WORDS.oddsRow", "WORDS.spinning", "WORDS.pityNext",
			"Wheel.buildWheel(panel, faces, Style)", "Wheel.face(PRIZES[row.id])",
			"Wheel.buildPack(panel, offer, Style.priceText(\"robux\", offer.robux), Style)",
			"Offers.WORDS.devFree", "Offers.WORDS.comingSoon", "view.unlocked",
			"Wheel.layout(size.X, size.Y)", "Wheel.fitPack(", "Wheel.motion(Style.reduced(playerGui))",
			"Wheel.targetRotation(index, wheelCount, motion.turns,", "Enum.EasingStyle.Quint",
			"oddsButton.Activated:Connect(", "oddsClose.Activated:Connect(", "closeButton.Activated:Connect(hidePanel)",
			"Style.setLabel(spinButton, WORDS.spin)", "kind == \"granted\"",
			"tonumber(view.spinSeconds)", "if os.clock() - spinAskedAt < spinGate() then return end",
			"if spinning then return end", "WHEEL_WORDS.extraNoPity" }) do
			has(client, needle, "client")
		end
		hasNot(client, "spinButton.Text =", "the kit button's words live on its Label")
		for _, banned in ipairs({ "MarketplaceService", "PromptProductPurchase", "PromptPurchase", "PromptGamePassPurchase",
			"ProcessReceipt", "Robux", "rbxassetid", "kitNewBadge", "kitTimerChip" }) do
			hasNot(client, banned, "client")
		end
	end)

	-- RW-4 / RW-5: a pack grants its spins for free while the switch is on; an extra spin after the free first spin rolls
	-- the whole table, costs no Esencia, is counted down and leaves the pity and the paid spins alone.
	case("RS-11: a spin pack grants free extra spins; an extra spin costs no Esencia and keeps the pity", function()
		local w = world()
		equal(w.service.unlocked, true, "the injected switch")
		w.rolls = { 0 }
		equal((w.service:spin(w.player)), true, "the free first spin")
		equal(w.snap().ember, 10)
		equal(w.service:view(w.player).spinsLeft, 0, "no spins left")
		equal(w.service:view(w.player).canSpin, false, "10 Esencia cannot pay 45")
		equal((w.service:handle(w.player, "offer", "rouletteSpins3")), true, "the pack")
		local message = w.last()
		equal(message.kind, "granted"); equal(message.player, w.player)
		equal(message.payload.offerId, "rouletteSpins3"); equal(message.payload.spins, 3); equal(message.payload.extraSpins, 3)
		equal(message.payload.text, Offers.WORDS.granted:format("+3 Tiradas", 3))
		equal(message.payload.view.spinsLeft, 3); equal(message.payload.view.extraSpins, 3)
		equal(message.payload.view.canSpin, true, "an extra spin needs no Esencia")
		equal(message.payload.view.unlocked, true)
		equal(w.snap().ember, 10, "a pack costs nothing")
		equal(w.rolled, 1, "a pack never rolls")
		w.later()
		w.rolls = { 0.98 }
		equal((w.service:spin(w.player)), true, "an extra spin with only 10 Esencia")
		local payload = w.last().payload
		equal(payload.prizeId, "forestChest"); equal(payload.cost, 0); equal(payload.free, true); equal(payload.extra, true)
		equal(payload.pity, false)
		equal(payload.text, Text.ROULETTE.wonFree:format(Text.ROULETTE.prizes.forestChest))
		equal(payload.index, #Roulette.LIVE.prizes, "the wedge the wheel stops on")
		local snap = w.snap()
		equal(snap.ember, 10, "no Esencia spent"); equal(snap.banked.fogbark, 40, "the prize is granted")
		equal(snap.roulette.paidSpins, 0, "not a paid spin"); equal(snap.roulette.pityCount, 0, "the pity waits")
		equal(snap.roulette.freeSpinUsed, true)
		equal(payload.view.extraSpins, 2, "counted down"); equal(payload.view.spinsLeft, 2)
		w.later()
		w.rolls = { 0 }
		w.service:spin(w.player)
		w.later()
		w.rolls = { 0 }
		w.service:spin(w.player)
		equal(w.service:view(w.player).extraSpins, 0, "all used")
		equal(w.snap().ember, 30, "two more free Esencia prizes, nothing paid")
		w.later()
		local paid, reason = w.service:spin(w.player)
		equal(paid, false); equal(reason, "CannotAfford", "then Esencia again")
	end)

	-- RW-4: with DESBLOQUEAR_TODO off the server answers "Próximamente" and grants nothing.
	case("RS-12: with the switch off a pack is refused with Próximamente and nothing changes", function()
		local w = world({ locked = true })
		equal(w.service.unlocked, false)
		local ok, reason = w.service:offer(w.player, "rouletteSpins10")
		equal(ok, false); equal(reason, "Locked")
		local message = w.last()
		equal(message.kind, "refused"); equal(message.payload.text, Offers.WORDS.comingSoon)
		equal(message.payload.view.unlocked, false, "the client says Próximamente")
		equal(message.payload.view.extraSpins, 0); equal(message.payload.view.spinsLeft, 1, "only the free first spin")
		equal(w.rolled, 0); equal(w.snap().ember, 0)
	end)

	-- RW-4: only a catalog id is accepted; the rate, alive and range are checked on the server; at most 99 extra spins
	-- are held, and a pack that would pass that is refused whole (nothing lost).
	case("RS-13: packs are validated: catalog ids only, the rate, alive and in range, and the 99 cap", function()
		local w = world()
		for _, bad in ipairs({ "rouletteSpins2", "ROULETTESPINS1", "", 5, { "rouletteSpins1" }, true }) do
			w.offerLater()
			local ok, reason = w.service:offer(w.player, bad)
			equal(ok, false, "refused: " .. tostring(bad)); equal(reason, "UnknownOffer", tostring(bad))
		end
		w.offerLater()
		equal(select(2, w.service:offer(w.player, nil)), "UnknownOffer", "no id")
		equal(w.last().payload.text, Offers.WORDS.unknown)
		w.offerLater()
		equal((w.service:handle(w.player, "offer")), false, "no id through the remote")
		equal(w.last().payload.reason, "UnknownOffer")
		equal(w.service:view(w.player).extraSpins, 0, "nothing granted")
		w.offerLater()
		equal((w.service:offer(w.player, "rouletteSpins1")), true)
		local again, busy = w.service:offer(w.player, "rouletteSpins1")
		equal(again, false); equal(busy, "OfferBusy", "one pack at a time"); equal(w.last().payload.text, Offers.WORDS.wait)
		equal(w.service:view(w.player).extraSpins, 1)
		w.offerLater()
		w.root = { Position = STATION + Vector3.new(Service.RANGE + 1, 0, 0) }
		equal(select(2, w.service:offer(w.player, "rouletteSpins1")), "TooFar")
		w.offerLater()
		w.root = { Position = STATION }
		w.alive = false
		equal(select(2, w.service:offer(w.player, "rouletteSpins1")), "InvalidContext")
		w.alive = true
		w.offerLater()
		equal(select(2, w.service:offer({ UserId = 777, Name = "NoProfile" }, "rouletteSpins1")), "InvalidPlayer")
		equal(w.service:view(w.player).extraSpins, 1, "nothing granted while refused")
		for _ = 1, 9 do
			w.offerLater()
			equal((w.service:offer(w.player, "rouletteSpins10")), true)
		end
		equal(w.service:view(w.player).extraSpins, 91)
		w.offerLater()
		local full, why = w.service:offer(w.player, "rouletteSpins10")
		equal(full, false); equal(why, "Full"); equal(w.last().payload.text, Offers.WORDS.full)
		equal(w.service:view(w.player).extraSpins, 91, "refused whole")
		w.offerLater()
		equal((w.service:offer(w.player, "rouletteSpins3")), true, "a smaller pack still fits")
		equal(w.service:view(w.player).extraSpins, Offers.MAX_EXTRA_SPINS - 5)
		equal(w.rolled, 0, "packs never roll"); equal(w.snap().ember, 0, "packs never pay or charge Esencia")
	end)

	-- RW-5: the account's free first spin is used before any extra spin.
	case("RS-14: the free first spin comes before the extra spins", function()
		local w = world()
		equal((w.service:offer(w.player, "rouletteSpins1")), true)
		local view = w.service:view(w.player)
		equal(view.spinsLeft, 2, "the free first spin and one extra"); equal(view.free, true)
		w.rolls = { 0 }
		w.service:spin(w.player)
		local payload = w.last().payload
		equal(payload.free, true); equal(payload.extra, false, "the free first spin, not the extra one")
		equal(w.snap().roulette.freeSpinUsed, true)
		equal(payload.view.extraSpins, 1, "the extra spin is still there"); equal(payload.view.spinsLeft, 1)
	end)

	-- RW-6: the result reaches the client at once (the wheel needs it to stop), but the HUD notice of the win waits
	-- NOTIFY_DELAY, under SPIN_SECONDS, so it never tells the prize before the wheel stops.
	case("RS-15: the HUD notice of a win waits for the wheel; the next spin waits longer still", function()
		local w = world({ holdNotice = true })
		w.rolls = { 0 }
		equal((w.service:spin(w.player)), true)
		equal(w.last().kind, "result", "the wheel gets the prize at once")
		equal(#w.notified, 0, "no notice yet")
		equal(#w.deferred, 1); equal(w.deferred[1].seconds, Service.NOTIFY_DELAY)
		assert(Service.NOTIFY_DELAY > 0 and Service.NOTIFY_DELAY < Service.SPIN_SECONDS, "the notice comes before the next spin")
		equal(w.last().payload.view.spinSeconds, Service.SPIN_SECONDS, "the client keeps Girar off this long after a tap")
		w.deferred[1].run()
		equal(#w.notified, 1); equal(w.notified[1].text, w.last().payload.text); equal(w.notified[1].ok, true)
		local service = sources.service or ""
		has(service, "task.delay(Service.NOTIFY_DELAY", "the real wait")
		has(service, "player.Parent == nil", "never for a player who left")
		has(service, "self.extra[player] = nil", "a leaving player's extra spins are forgotten")
	end)

	return result
end
