-- Invoke with require(freshTestClone)(require(freshServiceClone), require(freshRouletteClone), require(freshStateClone),
-- require(freshEconomyClone), require(freshConfigClone), require(freshTextClone), { server = WildboundServer.Source,
-- service = freshServiceClone.Source, client = WildboundRouletteClient.Source }).
-- PF5 (user decision 2026-11-14, odd/tasks/wildbound-playtest-fixes.md): the hub roulette. One station in the hub plaza
-- that everyone may use; the server alone validates (rate limit, alive, distance from the server-side root), rolls,
-- spends Esencia atomically through State:spinRoulette and grants. The client only asks to "open" or "spin" and shows
-- the odds before spinning. Fakes only: fake players and roots, a scripted rng and clock, and a parentless folder.
return function(Service, Roulette, State, Economy, Config, Text, sources)
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
	local function world()
		local state = State.new(Economy, Config)
		local player = { UserId = 501, Name = "Tester" }
		state:addPlayer(player.UserId)
		local w = { state = state, player = player, t = 100, rolls = {}, rolled = 0, fired = {}, notified = {},
			alive = true, root = { Position = STATION + Vector3.new(3, 2, 0) } }
		w.service = Service.new({
			state = state,
			Roulette = Roulette,
			Text = Text,
			alive = function() return w.alive end,
			rootOf = function() return w.root end,
			random = function()
				w.rolled += 1
				return table.remove(w.rolls, 1) or 0
			end,
			now = function() return w.t end,
			fire = function(target, kind, payload) table.insert(w.fired, { player = target, kind = kind, payload = payload }) end,
			notify = function(target, ok, text) table.insert(w.notified, { player = target, ok = ok, text = text }) end,
			position = STATION,
		})
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

	case("RS-9: wiring: the server starts the service in a do block with a server rng; the client sends only open/spin", function()
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
		has(service, "OnServerEvent:Connect(function(player, action)", "the handler reads one word")
		hasNot(service, "math.random", "the roll comes from the injected server rng")
		local client = sources.client or ""
		assert(#client > 0, "client source")
		local calls = 0
		for args in client:gmatch("FireServer%(([^)]*)%)") do
			calls += 1
			assert(args == '"open"' or args == '"spin"', "the client sends only open or spin: " .. args)
		end
		assert(calls >= 1, "the client asks the server to spin")
		has(client, "Text.ROULETTE", "the client words come from WildboundText")
	end)

	-- Deliberately changed (P0.1, owner request 2026-11-20): the roulette window leaves the dark Style.panel for the
	-- store kit in WildboundUiStyle (docs/design/refs/store-ui-reference.png). Same words, same two remote words; the
	-- price card's rays stand still with "Efectos suaves" (also when it is switched on while the window is open) and
	-- while the window is shut; on a wide window the result fills the room between the card and the buttons, so a
	-- short phone held sideways never draws it over the card; no price button, no purchase.
	case("RS-10: the roulette window wears the store kit, keeps its words and closes from the X or Cerrar", function()
		local client = sources.client or ""
		assert(#client > 0, "client source")
		hasNot(client, "Style.panel(panel)", "the old dark panel")
		for _, needle in ipairs({ "Style.kitWindow(gui, \"Panel\"", "Style.kitTitle(panel, WORDS.title", "Style.kitClose(panel)",
			"Style.kitCard(main, \"cyan\", true", "Style.kitButton(main, text, tone, name)", "button(\"Spin\", WORDS.spin, \"green\"",
			"button(\"Close\", WORDS.close, \"red\"", "WORDS.oddsHeader", "WORDS.oddsNote", "WORDS.spinning",
			"closeX.Activated:Connect(hidePanel)", "closeButton.Activated:Connect(hidePanel)",
			"Style.setSpin(card, Style.motion(Style.reduced(playerGui)).spin)", "Style.setSpin(card, false)",
			"Style.setLabel(spinButton, WORDS.spin)", "Style.isWide(inner.AbsoluteSize.X)", "Style.fitText(",
			"world:GetAttributeChangedSignal(\"Reduced\")",
			"resultLine.Position = UDim2.new(0, 0, 0, CARD_HEIGHT + 4)",
			"resultLine.Size = UDim2.new(1, 0, 1, -(CARD_HEIGHT + 8 + Style.KIT_SIZES.buttonHeight))",
			"resultLine.Position = UDim2.new(0, 0, 1, -56)" }) do
			has(client, needle, "client")
		end
		hasNot(client, "spinButton.Text =", "the kit button's words live on its Label")
		for _, banned in ipairs({ "MarketplaceService", "PromptProductPurchase", "PromptPurchase", "ProcessReceipt",
			"kitPriceButton", "kitNewBadge", "kitTimerChip" }) do
			hasNot(client, banned, "client")
		end
	end)

	return result
end
