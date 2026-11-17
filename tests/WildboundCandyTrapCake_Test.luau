-- Invoke with require(freshTestClone)(require(freshCandyTrapCakeClone), require(freshCandyLayoutClone),
--   { service = <WildboundCandyTrapCakeService Source>, server = <WildboundServer Source>,
--     bossService = <WildboundCandyDonGlaseonService Source>, client = <WildboundCandyCakeClient Source>,
--     text = require(freshTextClone) }).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG7): Torta trampa. Three decoy cakes stand on the routes a thief
-- uses; each holds a slice (a short sugar rush); one of them is Don Glaseon in disguise while he sleeps. It breathes and
-- drops a crumb now and then; it springs when a player comes close or bites it, lashes everyone near away, and the
-- decoys pop until they grow back. Pure rules plus source pins of the service and the two server edits. Changes nothing.
return function(Trap, Layout, sources)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function kinds(events)
		local out = {}
		for _, event in ipairs(events) do table.insert(out, event.kind) end
		return table.concat(out, ",")
	end
	local first = function() return 1 end
	local spots = Trap.spotsWorld(Layout.CENTRE)
	local function at(index, dx, dz, id)
		return { id = id or 1, x = spots[index].x + (dx or 0), z = spots[index].z + (dz or 0), alive = true, safe = false }
	end

	case("DG7: the numbers: three decoys, spring within 5 studs, 0.8 s tell, lash 9 studs, regrow 90 s, rush x1.25 for 5 s", function()
		equal(#Trap.SPOTS, 3, "three decoy cakes")
		near(Trap.SPRING_STUDS, 5, "spring"); near(Trap.PROMPT_STUDS, 8, "prompt reach")
		near(Trap.TELL_SECONDS, 0.8, "tell"); assert(Trap.TELL_SECONDS >= 0.8, "the fair-strike floor")
		near(Trap.LASH_STUDS, 9, "lash reach"); near(Trap.PUSH_STUDS, 12, "push"); near(Trap.PUSH_SECONDS, 0.4, "push time")
		near(Trap.POP_SECONDS, 0.7, "pop after the lash"); near(Trap.REGROW_SECONDS, 90, "regrow"); near(Trap.REARM_SECONDS, 30, "re-arm")
		near(Trap.RUSH_SECONDS, 5, "rush"); near(Trap.RUSH_SCALE, 1.25, "rush scale"); near(Trap.RUSH_CAP, 26, "rush cap")
		assert(Trap.CRUMB_RATE > 0 and Trap.CRUMB_RATE <= 1, "a crumb now and then")
		assert(Trap.BREATH_SCALE > 0 and Trap.BREATH_SCALE <= 0.06, "it breathes slightly")
		assert(type(Trap.TEXT.prompt) == "string" and type(Trap.TEXT.object) == "string", "the prompt's words")
	end)

	-- Deliberately changed (PF6, odd/tasks/wildbound-caramelo-playfix.md): two of the three cakes stood inside Don
	-- Glaseon's 62-stud territory (the stair one 33.5, the path one 60.6 studs from its centre). Walking to them woke him,
	-- which unmasks the disguise, so they could never spring. Every cake now stands outside the territory, past a
	-- spring's reach: the stair cake moved to the left (riverside) route, the path cake further out along the main route.
	case("DG7/PF6: the decoys stand on the thief routes, outside Don Glaseon's territory: riverside, main path, rare nest", function()
		local keys = {}
		for _, spot in ipairs(Trap.SPOTS) do keys[spot.key] = spot end
		assert(keys.riverside and keys.path and keys.rareNest, "riverside, path and rareNest spots")
		local boss = Layout.BOSS
		for _, spot in ipairs(Trap.SPOTS) do
			local d = Layout.flat(spot.x, spot.z, boss.x, boss.z)
			assert(d > boss.territoryRadius + Trap.SPRING_STUDS, spot.key .. " stands " .. d .. " studs from the boss ground's centre")
		end
		assert(Layout.routeDistance(keys.riverside.x, keys.riverside.z, "left") <= Layout.PATH_WIDTH / 2 + 3, "the riverside decoy is by the left route")
		assert(Layout.routeDistance(keys.path.x, keys.path.z, "main") <= Layout.PATH_WIDTH / 2 + 3, "the path decoy is by the main route")
		local nest
		for _, n in ipairs(Layout.NESTS) do if n.id == keys.rareNest.nest then nest = n end end
		assert(nest and nest.rarity ~= "Comun", "beside a rare nest")
		assert(Layout.flat(nest.x, nest.z, keys.rareNest.x, keys.rareNest.z) <= 14, "next to it")
		for i, spot in ipairs(spots) do
			near(spot.x, Layout.CENTRE.x + Trap.SPOTS[i].x, "world x"); near(spot.z, Layout.CENTRE.z + Trap.SPOTS[i].z, "world z")
		end
	end)

	-- CH3 (owner request "more eggs too"): the new nests never stand on a decoy cake (only the rare-nest decoy stands by
	-- its own nest, R1, about 12 studs off).
	case("CH3: every nest, the new ones too, stays at least 10 studs from every decoy cake", function()
		for _, spot in ipairs(Trap.SPOTS) do
			for _, n in ipairs(Layout.NESTS) do
				assert(Layout.flat(n.x, n.z, spot.x, spot.z) >= 10, "nest " .. n.id .. " on the " .. spot.key .. " decoy")
			end
		end
	end)

	case("DG7: one decoy is him, only while he sleeps; waking unmasks it and it re-arms 30 s after he sleeps again", function()
		local s = Trap.new(0, function(n) equal(n, 3, "picks among three") return 2 end)
		equal(s.trapIndex, 2, "the server's pick"); equal(Trap.disguised(s, false, 0), true, "asleep: disguised")
		equal(Trap.disguised(s, true, 0), false, "awake: never in disguise")
		local events = Trap.step(s, 1, true, {}, first, spots)
		equal(kinds(events), "Unmasked"); equal(s.trapIndex, nil, "no trap while he is out")
		equal(#Trap.step(s, 5, true, {}, first, spots), 0, "still awake: nothing")
		equal(#Trap.step(s, 10, false, {}, first, spots), 0, "asleep again: waits")
		equal(Trap.disguised(s, false, 39.9), false, "not yet")
		equal(kinds(Trap.step(s, 40, false, {}, first, spots)), "Armed"); equal(s.trapIndex, 1)
		equal(Trap.disguised(s, false, 40), true)
	end)

	case("DG7: it springs on a player within 5 studs: tell 0.8 s, a lash pushes everyone within 9 studs away, then the decoys pop", function()
		local s = Trap.new(0, first)
		equal(#Trap.step(s, 1, false, { at(1, 6, 0) }, first, spots), 0, "6 studs: nothing")
		equal(#Trap.step(s, 1.1, false, { at(2, 0, 1) }, first, spots), 0, "another decoy: nothing")
		local spring = Trap.step(s, 1.2, false, { at(1, 4, 0, 7) }, first, spots)
		equal(kinds(spring), "Spring"); equal(spring[1].by, 7, "who sprang it"); equal(spring[1].index, 1)
		near(spring[1].lashAt, 2.0, "lash 0.8 s later"); equal(s.status, "Springing")
		equal(#Trap.step(s, 1.9, false, { at(1, 4, 0, 7) }, first, spots), 0, "the tell")
		local lash = Trap.step(s, 2.0, false, { at(1, 4, 0, 7), at(1, 0, -8, 8), at(1, 10, 0, 9),
			{ id = 10, x = spots[1].x, z = spots[1].z + 2, alive = true, safe = true } }, first, spots)
		equal(kinds(lash), "Lash")
		local pushed = {}
		for _, push in ipairs(lash[1].pushes) do pushed[push.id] = push end
		assert(pushed[7] and pushed[8] and not pushed[9] and not pushed[10], "within 9 studs, never a safe player")
		near(pushed[7].dx, 1, "away from the cake"); near(pushed[8].dz, -1, "away")
		near(pushed[7].studs, 12, "push"); near(pushed[7].seconds, 0.4, "push time")
		equal(kinds(Trap.step(s, 2.7, false, {}, first, spots)), "Pop"); equal(s.status, "Popped")
		equal(Trap.disguised(s, false, 3), false, "popped: no disguise")
		equal(#Trap.step(s, 92.6, false, {}, first, spots), 0, "not grown yet")
		equal(kinds(Trap.step(s, 92.7, false, {}, first, spots)), "Regrow,Armed"); equal(s.status, "Ready"); equal(s.round, 2)
	end)

	case("DG7: a slice: a sugar rush once per cake per player per round; biting the disguised one springs it", function()
		local s = Trap.new(0, function() return 3 end)
		local ok, got = Trap.take(s, 1, 5, 4, 1, true, false)
		equal(ok, true); equal(got.kind, "Rush"); near(got.untilAt, 6, "5 s of rush")
		local again, why = Trap.take(s, 1, 5, 4, 2, true, false)
		equal(again, false); equal(why, "Eaten")
		equal((Trap.take(s, 2, 5, 4, 2, true, false)), true, "another cake")
		equal(select(2, Trap.take(s, 2, 6, 9, 2, true, false)), "TooFar")
		equal(select(2, Trap.take(s, 2, 6, 4, 2, false, false)), "Invalid")
		local bite, sprung = Trap.take(s, 3, 6, 3, 2, true, false)
		equal(bite, true); equal(sprung.kind, "Spring"); equal(s.status, "Springing")
		equal(select(2, Trap.take(s, 1, 9, 3, 2.5, true, false)), "Gone", "no slice while it springs")
		-- awake, the third is only a cake
		local t = Trap.new(0, function() return 3 end)
		Trap.step(t, 1, true, {}, first, spots)
		local plain = select(2, Trap.take(t, 3, 6, 3, 2, true, true))
		equal(plain.kind, "Rush", "unmasked: an ordinary slice")
	end)

	case("DG7: the rush: x1.25 of the speed, capped at 26, never slower, nothing when over or when stopped", function()
		near(Trap.rushSpeed(16, 10, 5), 20); near(Trap.rushSpeed(24, 10, 5), 26, "cap")
		near(Trap.rushSpeed(30, 10, 5), 30, "never slower"); near(Trap.rushSpeed(16, 10, 10), 16, "over")
		near(Trap.rushSpeed(0, 10, 5), 0, "a ragdolled player stays down"); near(Trap.rushSpeed(16, nil, 5), 16)
	end)

	case("DG7 wiring: the service builds kit cakes, prompts, breath and crumbs, writes the disguise and asks the server's rush", function()
		local service = sources.service
		has(service, 'require(ServerStorage:WaitForChild("WildboundCandyTrapCake"))')
		has(service, 'Kit.place(library, "CakeTower"', "decoys from the Candy kit")
		has(service, 'Instance.new("ProximityPrompt")'); has(service, "Trap.take(")
		has(service, "Trap.step("); has(service, 'telemetry:SetAttribute("Candy_bossDisguised"', "the disguise for the sleeper")
		has(service, 'GetAttribute("Beast_bossAwake")', "only while he sleeps")
		has(service, 'SetAttribute("WildboundCandyRushUntil"', "the rush through the server's one WalkSpeed writer")
		has(service, '"WildboundBeastPush"', "the beasts' push slot, never two at once")
		has(service, 'Instance.new("ParticleEmitter")', "the crumbs"); has(service, "DonGlaseon.asleep(", "the pop-out never collides")
	end)

	-- PF6 (odd/tasks/wildbound-caramelo-playfix.md): a bite used to give only an invisible +25 % walk for 5 s, and a second
	-- bite was refused in silence, so the owner read "the cake does nothing". Now the prompt says what it is, a bite tells
	-- the player on screen (WildboundText.CANDY_CAKE.rush) with a catalogue sound and a sparkle, and a refused second bite
	-- says "Ya comiste de esta torta". The server only names what happened (player attribute WildboundCandyCakeSaid,
	-- "<what>:<serial>"); WildboundCandyCakeClient shows it.
	case("PF6 wiring: a clear prompt, and a bite or a refused bite is told to the player", function()
		local service, client, text = sources.service, sources.client, sources.text
		assert(type(client) == "string" and type(text) == "table", "pass the cake client source and WildboundText")
		local words = text.CANDY_CAKE
		assert(type(words) == "table", "WildboundText.CANDY_CAKE")
		equal(words.rush, "¡Subidón de azúcar! Corres más rápido", "the rush line")
		equal(words.eaten, "Ya comiste de esta torta", "the refusal line")
		equal(words.prompt, "Comer una porción", "the prompt"); equal(words.object, "Torta de caramelo", "the prompt's object")
		for key, line in pairs(words) do assert(#line <= 64, key .. " is longer than 64 bytes") end
		has(service, "prompt.ActionText, prompt.ObjectText = Text.CANDY_CAKE.prompt, Text.CANDY_CAKE.object", "the prompt's words")
		has(service, 'say(player, "rush")', "a bite is told"); has(service, 'say(player, "eaten")', "a refused bite is told")
		has(service, 'player:SetAttribute("WildboundCandyCakeSaid"', "the server names what happened")
		has(client, 'GetAttributeChangedSignal("WildboundCandyCakeSaid")', "the client listens")
		has(client, "Text.CANDY_CAKE[what]", "the line comes from WildboundText")
		has(client, 'Catalog.SOUNDS.eggBanked', "a catalogue sound"); has(client, 'Instance.new("ParticleEmitter")', "a sparkle")
	end)

	-- PF6 review: a second bite 2.2-2.7 s after the first used to land while the first line's 0.5 s fade was still
	-- playing, and that fade hid the new line ("Ya comiste de esta torta" never showed). A new line cancels the old fade.
	case("PF6 review: a new line cancels the previous line's fade", function()
		local client = sources.client
		assert(type(client) == "string", "pass the cake client source")
		has(client, "local fade", "the fade tween is kept")
		has(client, "if fade then fade:Cancel() end", "a new line cancels the old fade")
		has(client, "fade = TweenService:Create(line,", "the delayed fade is the kept tween")
		local cancelAt = string.find(client, "if fade then fade:Cancel() end", 1, true)
		local showAt = string.find(client, "line.TextTransparency, line.TextStrokeTransparency = 0, 0.2", 1, true)
		assert(cancelAt and showAt and cancelAt < showAt, "the old fade is cancelled before the new line is shown")
	end)

	case("DG7 wiring: applyCarry applies the rush; the server re-applies when it starts and ends; the sleeper hides in disguise", function()
		local server = sources.server
		has(server, 'local rush = player:GetAttribute("WildboundCandyRushUntil")', "applyCarry reads the rush")
		has(server, "speed = math.max(speed, math.min(speed * 1.25, 26))", "Trap.rushSpeed's rule")
		has(server, 'GetAttributeChangedSignal("WildboundCandyRushUntil")', "re-applied on a new rush")
		has(sources.bossService, 'telemetry:GetAttribute("Candy_bossDisguised") == true', "the sleeper reads the disguise")
		has(sources.bossService, 'GetAttributeChangedSignal("Candy_bossDisguised"):Connect(refresh)')
		has(sources.bossService, "sleeper.Parent = (not awake and not disguised) and workspace or nil")
	end)

	return result
end
