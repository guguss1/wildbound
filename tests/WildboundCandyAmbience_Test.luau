-- Invoke with require(freshTestClone)(require(freshCandyAmbienceClone), require(freshAudioMixClone),
--   require(freshAudioCatalogClone), require(freshBiomeLightClone),
--   { client = <WildboundCandyAmbienceClient Source>, audio = <WildboundAudioClient Source> }).
-- Caramelo ambience (owner request 2026-11-16: "music, sparkles, lights, so it feels more alive"): client-only lights,
-- sparkles, a gentle lollipop sway and a sweeter music bed while the player is in the Caramelo plot. Pure rules (budgets,
-- nearest-N pick, palette, hysteresis, curves), the music slot through the existing mix, and source pins. Changes nothing.
return function(Ambience, Mix, Catalog, BiomeLight, sources)
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
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local client = type(sources) == "table" and sources.client or ""
	local audio = type(sources) == "table" and sources.audio or ""
	local function ids(list)
		local out = {}
		for _, item in ipairs(list) do table.insert(out, item.id) end
		return table.concat(out, ",")
	end

	case("AM1: budgets for desktop, touch and Efectos suaves", function()
		local desktop, touch, soft = Ambience.budget(false, false), Ambience.budget(true, false), Ambience.budget(false, true)
		-- Deliberately changed (V3): "more sparkle particles": desktop emitters 10 -> 16 and 60 -> 100 particles/s
		equal(desktop.lights, 12, "desktop lights"); equal(desktop.emitters, 16, "desktop emitters")
		equal(desktop.rate, 100, "desktop particles per second"); equal(desktop.sway, 8, "desktop swaying lollipops")
		assert(desktop.pulse == true and desktop.fireflies == true, "desktop pulses and has fireflies")
		assert(touch.lights <= 6 and touch.lights > 0, "touch lights at most 6")
		near(touch.rate, desktop.rate / 2, "touch: half the particles")
		assert(touch.emitters <= desktop.emitters and touch.sway <= 4, "touch: fewer emitters and swaying props")
		equal(touch.pulse, false, "touch: no pulsing")
		equal(soft.emitters, 0, "soft: no sparkles"); equal(soft.rate, 0, "soft: no particles")
		equal(soft.sway, 0, "soft: no motion"); equal(soft.pulse, false, "soft: no pulsing")
		equal(soft.fireflies, false, "soft: no fireflies")
		assert(soft.lights <= 6 and soft.lights > 0, "soft keeps a few steady lights")
		equal(Ambience.budget(true, true), soft, "Efectos suaves wins over touch")
		near(Ambience.PICK_SECONDS, 0.5, "re-picked at 2 Hz")
		for kind, spec in pairs(Ambience.KINDS) do
			if spec.light then
				assert(spec.light.range <= Ambience.MAX_RANGE and spec.light.range > 0, kind .. " light range")
				assert(spec.light.brightness > 0 and spec.light.brightness <= 2.5, kind .. " light brightness")
			end
		end
		assert(Ambience.MAX_RANGE <= 16, "modest light range")
	end)

	case("AM2: the nearest-N pick is pure, deterministic and weighted", function()
		local list = {
			{ id = "lollipop:Lollipop_1", kind = "lollipop", x = 10, y = 0, z = 0 },
			{ id = "lollipop:Lollipop_2", kind = "lollipop", x = 30, y = 0, z = 0 },
			{ id = "gumdrop:Gumdrop_1", kind = "gumdrop", x = 0, y = 0, z = 20 },
			{ id = "cotton:CottonTree_1", kind = "cotton", x = 5, y = 0, z = 0 }, -- no light: never a light pick
			{ id = "nest:Nest_A", kind = "nest", x = 45, y = 0, z = 0 }, -- 45 x 0.6 = 27: before Lollipop_2 (30)
			{ id = "lollipop:Lollipop_9", kind = "lollipop", x = 500, y = 0, z = 0 }, -- out of reach
			{ id = "gumdrop:Gumdrop_0", kind = "gumdrop", x = 0, y = 0, z = -20 }, -- ties Gumdrop_1: id order
		}
		local eye = { x = 0, y = 0, z = 0 }
		local before = ids(list)
		local picked = Ambience.pick(list, eye, 4, "light")
		equal(ids(picked), "lollipop:Lollipop_1,gumdrop:Gumdrop_0,gumdrop:Gumdrop_1,nest:Nest_A", "nearest four lights")
		equal(ids(list), before, "the input is not reordered")
		local shuffled = { list[7], list[3], list[5], list[1], list[6], list[2], list[4] }
		equal(ids(Ambience.pick(shuffled, eye, 4, "light")), ids(picked), "same answer whatever the order")
		equal(#Ambience.pick(list, eye, 100, "light"), 5, "out-of-reach and lightless kinds are left out")
		equal(ids(Ambience.pick(list, eye, 1, "sparkle")), "cotton:CottonTree_1", "the cotton tree sparkles")
		equal(#Ambience.pick(list, eye, 0, "light"), 0, "a zero budget picks nothing")
		equal(#Ambience.pick(list, { x = 0 / 0, y = 0, z = 0 }, 4, "light"), 0, "a bad eye picks nothing")
		equal(#Ambience.pick({ { id = "x", kind = "unknown", x = 1, y = 0, z = 0 } }, eye, 4, "light"), 0, "unknown kinds")
		equal(ids(Ambience.pick(list, eye, 1, "sway")), "lollipop:Lollipop_1", "only lollipops sway")
		assert(Ambience.REACH.light >= Ambience.REACH.sparkle and Ambience.REACH.sparkle >= Ambience.REACH.sway, "reaches")
	end)

	case("AM3: emitter rates fit the particle budget", function()
		local picks = { { rate = 6 }, { rate = 6 }, { rate = 8 }, { rate = 5 } }
		local full = Ambience.rates(picks, 60)
		near(full[1], 6, "under budget: unchanged"); near(full[3], 8)
		local squeezed = Ambience.rates(picks, 20)
		local sum = 0
		for _, r in ipairs(squeezed) do sum += r end
		near(sum, 20, "scaled down to the total", 1e-6)
		near(squeezed[3] / squeezed[1], 8 / 6, "kept in proportion", 1e-6)
		for _, r in ipairs(Ambience.rates(picks, 0)) do near(r, 0, "a zero budget is silent") end
		equal(#Ambience.rates({}, 60), 0)
		-- the worst desktop case: every emitter the busiest kind, plus the fireflies
		local worst, busiest = {}, Ambience.FIREFLIES.rate
		for _, spec in pairs(Ambience.KINDS) do
			if spec.sparkle then busiest = math.max(busiest, spec.sparkle.rate) end
		end
		for _ = 1, Ambience.budget(false, false).emitters do table.insert(worst, { rate = busiest }) end
		sum = 0
		for _, r in ipairs(Ambience.rates(worst, Ambience.budget(false, false).rate)) do sum += r end
		-- Deliberately changed (V3): the particle budget is 100 on desktop and 50 on touch (was 60 and 30)
		assert(sum <= 100 + 1e-6, "desktop at most 100 particles/s: " .. sum)
		sum = 0
		for _, r in ipairs(Ambience.rates(worst, Ambience.budget(true, false).rate)) do sum += r end
		assert(sum <= 50 + 1e-6, "touch at most 50 particles/s: " .. sum)
	end)

	case("AM4: the candy palette and stable colours", function()
		for _, name in ipairs({ "pink", "mint", "lemon", "sky", "warm" }) do
			local c = Ambience.PALETTE[name]
			assert(type(c) == "table" and #c == 3, name .. " missing")
			for _, v in ipairs(c) do assert(v >= 0 and v <= 255 and v % 1 == 0, name .. " channel") end
		end
		equal(#Ambience.PALETTE_ORDER, 4, "pink, mint, lemon, sky")
		equal(Ambience.colorName("nest", "nest:Nest_A"), "warm", "nests glow warm")
		equal(Ambience.colorName("eggNest", "eggNest:Nest_B"), "warm", "egg nests glow warm")
		equal(Ambience.colorName("portal", "portal:Portal"), "sky", "the portal is sky blue")
		equal(Ambience.colorName("lollipop", "lollipop:Lollipop_3"), Ambience.colorName("lollipop", "lollipop:Lollipop_3"),
			"the same prop keeps its colour")
		local seen, count = {}, 0
		for i = 1, 12 do
			local name = Ambience.colorName("lollipop", "lollipop:Lollipop_" .. i)
			assert(table.find(Ambience.PALETTE_ORDER, name), "a candy colour")
			if not seen[name] then seen[name], count = true, count + 1 end
		end
		assert(count >= 3, "twelve lollipops use at least three colours, got " .. count)
		local rgb = Ambience.color("portal", "portal:Portal")
		equal(rgb[1], Ambience.PALETTE.sky[1], "color() returns the palette row")
	end)

	case("AM5: enter and leave the plot with hysteresis", function()
		local b = Ambience.boundsFromFloor(612, -3, 400, 400)
		near(b.minX, 412); near(b.maxX, 812); near(b.minZ, -203); near(b.maxZ, 197)
		near(Ambience.distanceOutside(b, 612, -3), 0, "the centre is inside")
		near(Ambience.distanceOutside(b, 400, -3), 12, "12 studs west of the edge")
		equal(Ambience.inside(false, b, 612, -3), true, "enter in the middle")
		equal(Ambience.inside(false, b, 412 - Ambience.ENTER_MARGIN + 1, 0), true, "enter just before the edge")
		equal(Ambience.inside(false, b, 412 - 20, 0), false, "20 studs out: not yet")
		equal(Ambience.inside(true, b, 412 - 20, 0), true, "20 studs out after being in: still in (no flicker)")
		equal(Ambience.inside(true, b, 412 - Ambience.LEAVE_MARGIN - 1, 0), false, "left beyond the leave margin")
		assert(Ambience.LEAVE_MARGIN > Ambience.ENTER_MARGIN, "a real gap between enter and leave")
		equal(Ambience.inside(true, nil, 612, -3), false, "no bounds: off")
		equal(Ambience.inside(true, b, 0 / 0, 0), false, "a bad point: off")
		local fallback = Ambience.fallbackBounds(BiomeLight)
		assert(fallback, "the Caramelo square from WildboundBiomeLight")
		near(fallback.minX, 412); near(fallback.maxX, 812); near(fallback.minZ, -203); near(fallback.maxZ, 197)
		equal(Ambience.fallbackBounds(nil), nil, "no module: no bounds")
	end)

	case("AM6: pulse, sway and the cake's colour cycle", function()
		for t = 0, 12, 0.37 do
			local p = Ambience.pulse(t, 0.3)
			assert(p >= 0.75 - 1e-9 and p <= 1 + 1e-9, "pulse in 0.75..1: " .. p)
			local s = Ambience.sway(t, 0.3)
			assert(math.abs(s) <= math.rad(Ambience.SWAY_DEGREES) + 1e-9, "sway within its angle")
		end
		assert(Ambience.SWAY_DEGREES <= 8, "a gentle sway")
		near(Ambience.pulse(0 / 0, 0), 1, "bad time: steady")
		near(Ambience.sway(0 / 0, 0), 0, "bad time: at rest")
		local first = Ambience.cakeColor(0, 0)
		equal(first[1], Ambience.PALETTE.pink[1], "the cycle starts pink")
		local second = Ambience.cakeColor(Ambience.CAKE_PERIOD / 4, 0)
		equal(second[2], Ambience.PALETTE.mint[2], "a quarter later it is mint")
		local whole = Ambience.cakeColor(Ambience.CAKE_PERIOD, 0)
		equal(whole[1], first[1], "it loops")
		near(Ambience.phase("lollipop:Lollipop_1", 4), Ambience.phase("lollipop:Lollipop_1", 4), "a stable phase")
		local ph = Ambience.phase("x", 4)
		assert(ph >= 0 and ph < 4, "phase within the period")
		equal(Ambience.thinAxis(8.4, 8.4, 1.1), "Z"); equal(Ambience.thinAxis(1, 6, 6), "X"); equal(Ambience.thinAxis(5, 0.5, 5), "Y")
	end)

	case("AM7: nests twinkle where an egg sits", function()
		local eggs = { { x = 100, z = 100 }, { x = 0, z = 0 } }
		equal(Ambience.nearEgg(101, 99, eggs, Ambience.EGG_RADIUS), true, "an egg in the bowl")
		equal(Ambience.nearEgg(50, 50, eggs, Ambience.EGG_RADIUS), false, "no egg here")
		equal(Ambience.nearEgg(0, 0, {}, Ambience.EGG_RADIUS), false)
		equal(Ambience.nestKind(true, true, false), "eggNest", "an egg: twinkle")
		equal(Ambience.nestKind(false, true, true), "nest", "eggs are known and this nest has none: glow only")
		equal(Ambience.nestKind(false, false, true), "eggNest", "no egg data at all: every live nest twinkles")
		equal(Ambience.nestKind(false, false, false), "nest", "a nest that is not live still glows")
		assert(Ambience.KINDS.eggNest.sparkle and not Ambience.KINDS.nest.sparkle, "only egg nests twinkle")
		assert(Ambience.KINDS.nest.light and Ambience.KINDS.eggNest.light, "every nest glows")
		assert(Ambience.KINDS.nest.weight < 1 and Ambience.KINDS.eggNest.weight <= Ambience.KINDS.nest.weight,
			"nests win lights from farther away")
	end)

	case("AM8: the music slot: silent while unset, takes over once set, ducks under danger", function()
		local slot = Ambience.MUSIC_SLOT
		equal(slot, "carameloMusic")
		-- Outside Caramelo nothing changes.
		local plain = Mix.targets("Safe", "Day", false)
		equal(plain[slot], nil, "no new key outside")
		near(plain.safeMusic, 0.15, "the calm bed as before")
		near(Mix.musicPitch(false, false), 1, "its own pitch outside")
		-- Unset track: the existing calm bed, a little louder and sweeter, inside the plot.
		local unset = Mix.targets("Safe", "Day", false, true, false)
		equal(unset[slot], nil, "an unset slot never becomes a layer")
		near(unset.safeMusic, Mix.CANDY.safeMusic, "the calm bed in Caramelo")
		assert(Mix.CANDY.safeMusic > 0.15 and Mix.CANDY.safeMusic <= 0.35, "a bit louder, under the music cap")
		near(Mix.musicPitch(true, false), Mix.CANDY.pitch, "sweeter")
		assert(Mix.CANDY.pitch > 1 and Mix.CANDY.pitch <= 1.2, "a small pitch lift")
		-- Set track: it plays instead of the calm bed, at its own pitch.
		local set = Mix.targets("Safe", "Day", false, true, true)
		near(set[slot], Mix.CANDY.track, "the Caramelo track plays")
		near(set.safeMusic, 0, "the calm bed gives way")
		near(Mix.musicPitch(true, true), 1, "the real track keeps its pitch")
		near(Mix.targets("Safe", "Day", false, false, true)[slot], 0, "leaving fades it out")
		-- Danger ducks it, like the calm bed.
		-- Review follow-up: the calm bed gets the same lift at every hour, not a flat level.
		near(Mix.targets("Safe", "Night", false, true, false).safeMusic, 0.08 * Mix.CANDY.safeMusic / 0.15, "night: lifted, not flat")
		near(Mix.targets("Safe", "Dusk", false, true, false).safeMusic, 0.12 * Mix.CANDY.safeMusic / 0.15, "dusk: lifted")
		near(Mix.targets("Distant", "Day", false, true, false).safeMusic, 0.08 * Mix.CANDY.safeMusic / 0.15, "distant: lifted")
		near(Mix.targets("Distant", "Day", false, true, true)[slot], Mix.CANDY.track / 2, "halved when something is near")
		near(Mix.targets("Near", "Day", false, true, true)[slot], 0, "silent when close")
		near(Mix.targets("Chase", "Day", false, true, true)[slot], 0, "silent in a chase")
		near(Mix.targets("Chase", "Day", false, true, false).safeMusic, 0, "the sweet bed is silent in a chase too")
		near(Mix.targets("Chase", "Day", false, true, true).chaseMusic, 0.35, "the chase music is untouched")
		near(Mix.fadeSeconds(slot, false, false), 4, "it leaves like a bed, over 4 s")
		-- The catalog: either no slot yet, or a looping Music slot with real ids.
		local entry = Catalog.SOUNDS[slot]
		if entry then
			assert(entry.group == "Music" and entry.loop == true and #entry.ids >= 1, "a looping music slot")
			for level in pairs({ Safe = 1, Distant = 1, Near = 1, Chase = 1 }) do
				for key in pairs(Mix.targets(level, "Day", false, true, true)) do
					assert(Catalog.SOUNDS[key], key .. " is not in the catalog")
				end
			end
		end
		for key in pairs(Mix.targets("Safe", "Day", false, true, entry ~= nil)) do
			assert(Catalog.SOUNDS[key], key .. " is not in the catalog")
		end
	end)

	case("AM9: no sound id or texture id outside the catalog", function()
		assert(not string.find(client, "%d%d%d%d%d%d%d"), "an asset id is written in the client")
		hasNot(client, "rbxassetid", "no asset ids")
		hasNot(client, "rbxasset://", "the default particle texture only")
		hasNot(client, ".Texture", "the emitters keep the default texture")
		hasNot(client, "Instance.new(\"Sound\")", "the music goes through the audio controller")
		hasNot(client, "SoundId", "no sound ids")
		has(audio, "Catalog.SOUNDS.carameloMusic ~= nil", "the audio controller reads the slot from the catalog")
	end)

	case("AM10: client wiring: Heartbeat, streaming, cleanup, no server traffic", function()
		has(client, "RunService.Heartbeat:Connect", "Heartbeat drives it")
		hasNot(client, "RenderStepped", "RenderStepped did not fire in Studio Play")
		has(client, "workspace:WaitForChild(Ambience.ROOT_NAME", "waits for the built biome")
		has(client, "ChildAdded", "props that stream in late are found")
		has(client, "ChildRemoved", "props that stream out are dropped")
		has(client, "Ambience.FORBIDDEN", "never touches SistemaSonriente")
		has(client, "local function teardown()", "one cleanup")
		has(client, "if not inCandy then\n\t\tteardown()", "cleaned up on leaving")
		has(client, "holder:Destroy()", "every light, emitter and helper part goes")
		has(client, "restoreSway(", "swayed heads return to where they were")
		has(client, "script.Destroying", "cleaned up when the script goes")
		has(client, ".Shadows = false", "no shadow-casting lights")
		has(client, ".CanCollide, ", "helper parts never collide")
		has(client, ":GetAttribute(\"Reduced\")", "Efectos suaves is honoured")
		has(client, "UserInputService.TouchEnabled", "touch devices get the smaller budget")
		has(client, "Ambience.budget(", "the budget comes from the rules")
		has(client, "Ambience.pick(", "the picks come from the rules")
		has(client, "Ambience.PICK_SECONDS", "re-picked on its timer")
		has(client, "SetAttribute(Ambience.GUI_ATTRIBUTE", "the audio controller is told through the local gui")
		for _, banned in ipairs({ "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction", "WildboundNetwork",
			"player:SetAttribute", "biome:SetAttribute", "ServerStorage", "DataStore" }) do
			hasNot(client, banned, "client only")
		end
	end)

	case("AM11: the audio controller plays the Caramelo bed through the mix", function()
		has(audio, "worldGui:GetAttribute(\"CandyAmbience\") == true", "reads the local flag")
		has(audio, "Mix.targets(level, phase, reduced, candy, candyTrack)", "the mix decides the volumes")
		has(audio, "Mix.musicPitch(candy, candyTrack)", "the sweeter pitch comes from the mix")
		equal(Ambience.GUI_ATTRIBUTE, "CandyAmbience", "the same flag on both sides")
	end)

	-- Review follow-up (odd/reviews/caramelo-ambience-review.md): visible sparkles, streaming, a real sway, daylight.
	case("AM12: review follow-up: spots above the pieces, streaming, sway about the foot, brighter in day light", function()
		has(client, "math.abs(cf.UpVector.Y) * half.Y", "spots start above the piece's top, not its centre")
		has(client, "if c.piece then return nil end", "a piece not streamed in is skipped, never dropped to the foot")
		has(client, "if not biome or biome.Parent == nil then", "a lost biome is searched again")
		has(client, "Ambience.EGG_RADIUS), false,", "the partial egg tag is not taken as the full list")
		has(client, "spec.color or Ambience.colorName(", "the sparkle keeps its own colour (lemon twinkle)")
		has(client, "restoreSway(entry)\n\t\t\tsways[rec.id] = newSway(rec)", "a reloaded lollipop sways again")
		has(client, "local ok, message = pcall(animate, os.clock())", "a failing frame is reported once")
		has(client, "t - lastPulse >= Ambience.PULSE_STEP", "the breath is throttled")
		has(client, "CFrame.new(entry.foot)", "the lollipop leans about its foot")
		has(client, "\"StickA\", \"StickB\"", "the stick leans with the head")
		has(client, "emitter.Brightness = style.brightness", "the glitter is bright enough for day light")
		has(audio, "Catalog.SOUNDS.safeMusic.pitch * musicPitch", "the catalog pitch is kept")
		assert(Ambience.PULSE_STEP >= 0.05 and Ambience.PULSE_STEP <= 0.2, "about 10 Hz")
		-- Deliberately changed (V3): "a little less bright light overall": every light 20 % dimmer than the review's
		-- step (lollipop 2 -> 1.6, cake 2.4 -> 1.9), still brighter than before the review (1.5 and 1.8)
		near(Ambience.KINDS.lollipop.light.brightness, 1.6, "lollipop"); near(Ambience.KINDS.cake.light.brightness, 1.9, "cake")
		for name, style in pairs(Ambience.STYLES) do
			assert(style.brightness and style.brightness >= 1 and style.brightness <= 3, name .. " particle brightness")
		end
		local x, z = Ambience.swayAxis(0, 0, 1)
		near(x, 0); near(z, 1)
		x, z = Ambience.swayAxis(3, 1, 4)
		near(x, 0.6); near(z, 0.8)
		equal(Ambience.swayAxis(0, 1, 0), nil, "a flat disc does not sway")
		equal(Ambience.swayAxis(0 / 0, 0, 1), nil)
	end)

	-- Caramelo v3 (owner request 2026-11-17: "a little less bright light overall and more sparkle particles";
	-- docs/design/wildbound-caramelo-v3-plan.md): dimmer lights, more sparkles, the v3 pieces decorated, the waterfall
	-- flowing on the client.
	case("AM13: V3: dimmer lights, more sparkles, the v3 pieces and the waterfall's flow", function()
		local before = { lollipop = 2, gumdrop = 1.6, nest = 2.2, eggNest = 2.5, cake = 2.4, portal = 2.4 }
		for kind, was in pairs(before) do
			local now = Ambience.KINDS[kind].light.brightness
			assert(now <= was * 0.85 + 1e-9 and now >= was * 0.75 - 1e-9, kind .. " is not 15-25 % dimmer: " .. now)
		end
		assert(Ambience.budget(false, false).emitters > 10 and Ambience.budget(false, false).rate > 60, "more sparkles on desktop")
		assert(Ambience.budget(true, false).emitters > 5 and Ambience.budget(true, false).rate > 30, "more sparkles on touch")
		equal(Ambience.budget(false, true).emitters, 0, "Efectos suaves still has none")
		equal(Ambience.V3_FOLDER, "CaramelV3", "the v3 folder")
		for _, name in ipairs({ "Trees", "River", "Lake", "Waterfall", "Houses", "Licorice" }) do
			assert(table.find(Ambience.V3_FOLDERS, name), name .. " is decorated")
		end
		for _, kind in ipairs({ "river", "waterfall", "house", "licorice" }) do
			assert(Ambience.KINDS[kind] and Ambience.KINDS[kind].sparkle, kind .. " sparkles")
			assert(Ambience.STYLES[Ambience.KINDS[kind].sparkle.style], kind .. "'s style exists")
		end
		assert(Ambience.KINDS.house.light.brightness <= 1.6, "house lights are soft")
		for t = 0, 10, 0.37 do
			local d = Ambience.flowOffset(t, 12, 18, 0.4)
			assert(d >= 0 and d < 18, "flow offset within the span: " .. d)
		end
		near(Ambience.flowOffset(0, 12, 18, 0.5), 9, "the phase is a fraction of the span")
		near(Ambience.flowOffset(1, 12, 18, 0), 12, "12 studs down after a second")
		near(Ambience.flowOffset(0 / 0, 12, 18, 0), 0, "a bad time rests")
		near(Ambience.flowOffset(1, 12, 0, 0), 0, "no span rests")
		has(client, "biome:FindFirstChild(Ambience.V3_FOLDER)", "the client finds the v3 folder")
		has(client, "Ambience.flowOffset(", "the streaks flow by the rule")
		has(client, "restoreFlows()", "streaks go back when the ambience stops")
		has(client, "if budget.sway > 0 then", "no flow with Efectos suaves")
		has(client, "string.sub(childName, 1, 6) == \"Choco_\"", "the chocolate shimmers")
	end)

	return result
end
