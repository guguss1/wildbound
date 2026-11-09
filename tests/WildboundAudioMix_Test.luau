-- Invoke with require(freshTestClone)(require(freshMixClone), require(freshCatalogClone)). Both are pure and stand
-- alone; the test checks that every mix slot exists in the catalog.
-- Delivery D9: the horror mix as pure rules. Target volumes per threat level, time of day and Reduced effects, the
-- fades, the footstep interval, one-shot scheduling with an injected roll, and the jumpscare gate. No sound plays here.
return function(Mix, Catalog)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local LEVELS, TIMES = { "Safe", "Distant", "Near", "Chase" }, { "Day", "Dusk", "Night" }
	local MUSIC = { "safeMusic", "nightBed", "unsettling", "chaseMusic", "pulse" }

	case("D9: the table of section 4 for each level", function()
		local safe = Mix.targets("Safe", "Day", false)
		near(safe.wind, 0.20, "wind")
		near(safe.birds, 0.10, "birds by day")
		near(safe.safeMusic, 0.15, "safe music by day")
		near(safe.unsettling, 0, "no unsettling music when safe")
		near(Mix.targets("Safe", "Night", false).wind, 0.14, "wind at night")
		near(Mix.targets("Safe", "Night", false).nightBed, 0.08, "night under-bed")
		near(Mix.targets("Safe", "Night", false).insectsNight, 0.12)
		near(Mix.targets("Safe", "Dusk", false).insectsDusk, 0.12)
		near(Mix.targets("Safe", "Dusk", false).safeMusic, 0.12)
		local distant = Mix.targets("Distant", "Day", false)
		near(distant.safeMusic, 0.08)
		near(distant.unsettling, 0.20)
		local closeBy = Mix.targets("Near", "Day", false)
		near(closeBy.wind, 0.14, "wind x 0.7")
		near(closeBy.birds, 0)
		near(closeBy.breathing, 0.30)
		near(closeBy.steps, 0.40, "dread pass: was 0.35")
		local chase = Mix.targets("Chase", "Night", false)
		near(chase.wind, 0.14 * 0.4, "wind x 0.4")
		near(chase.chaseMusic, 0.35)
		near(chase.pulse, 0.12)
		near(chase.steps, 0.45, "dread pass: was 0.40")
		near(chase.unsettling, 0)
		-- Deliberately changed in the dread pass: a heavy, slow walk (0.85) and a run (1.2) instead of 1 and 1.15.
		near(Mix.stepPitch("Chase"), 1.2)
		near(Mix.stepPitch("Near"), 0.85)
	end)

	case("D9: invariants hold for every level, time and Reduced", function()
		for _, level in ipairs(LEVELS) do
			for _, time in ipairs(TIMES) do
				for _, reduced in ipairs({ false, true }) do
					local t = Mix.targets(level, time, reduced)
					local label = level .. " " .. time .. " " .. tostring(reduced)
					local loudestMusic = 0
					for _, slot in ipairs(MUSIC) do
						assert(t[slot] <= 0.35 + 1e-9, label .. ": " .. slot .. " above 0.35")
						loudestMusic = math.max(loudestMusic, t[slot])
					end
					if level == "Near" or level == "Chase" then
						assert(math.max(t.steps, t.breathing, t.giantSteps) >= loudestMusic, label .. ": guardian cues under the music")
					end
					for _, shot in ipairs({ "snap", "dirt", "whisper", "signature", "hit", "stinger", "crack", "groan" }) do
						assert(Mix.oneShot(shot, reduced).volume <= 0.35 + 1e-9, label .. ": " .. shot .. " above 0.35")
					end
					for slot, volume in pairs(t) do
						assert(Catalog.SOUNDS[slot], label .. ": " .. slot .. " is not in the catalog")
						assert(volume >= 0 and volume <= 1, label .. ": " .. slot)
					end
				end
			end
		end
		assert(Mix.LIMITS.sounds <= 14 and Mix.LIMITS.snaps <= 2 and Mix.LIMITS.steps <= 3, "caps")
		near(Mix.STINGER_COOLDOWN, 15)
	end)

	case("D9: reduced overrides (0.6 master, caps, whispers off)", function()
		near(Mix.master(false), 1)
		near(Mix.master(true), 0.6)
		near(Mix.targets("Chase", "Night", true).chaseMusic, 0.20, "chase music cap")
		near(Mix.targets("Near", "Night", true).breathing, 0.15, "breathing")
		near(Mix.oneShot("signature", true).volume, 0.15)
		near(Mix.oneShot("hit", true).volume, 0.30)
		near(Mix.oneShot("hit", false).volume, 0.35, "DD-9: hit at 0.35")
		near(Mix.oneShot("stinger", false).volume, 0.35)
		assert(Mix.oneShot("stinger", true).slot == "softStinger", "reduced swaps the stinger")
		near(Mix.oneShot("stinger", true).volume, 0.25)
		assert(Mix.nextDelay("whisper", "Distant", true, 0.5) == nil, "whispers off")
		near(Mix.nextDelay("snap", "Distant", true, 0), 8, "snaps kept")
		near(Mix.targets("Near", "Day", true).steps, 0.40, "steps unchanged")
		near(Mix.targets("Near", "Day", true).giantSteps, 0.30, "the giant's steps unchanged")
		near(Mix.oneShot("groan", true).volume, 0.15, "the groan softer")
		near(Mix.fadeSeconds("wind", true, true), 2, "every layer fades in over 2 s")
	end)

	case("D9: fades, schedules and positions", function()
		near(Mix.fadeSeconds("unsettling", true, false), 1.5, "rise")
		near(Mix.fadeSeconds("chaseMusic", false, false), 3, "chase out")
		near(Mix.fadeSeconds("breathing", false, false), 2, "near out")
		near(Mix.fadeSeconds("wind", false, false), 4, "safe beds")
		near(Mix.nextDelay("snap", "Distant", false, 0), 8)
		near(Mix.nextDelay("snap", "Distant", false, 1), 20)
		near(Mix.nextDelay("snap", "Near", false, 0.5), 10)
		near(Mix.nextDelay("whisper", "Distant", false, 0), 20)
		near(Mix.nextDelay("signature", "Chase", false, 1), 20)
		assert(Mix.nextDelay("snap", "Safe", false, 0.5) == nil and Mix.nextDelay("snap", "Chase", false, 0.5) == nil)
		assert(Mix.nextDelay("snap", "Distant", false, 0 / 0) == nil, "bad roll")
		local point = Mix.cuePosition(0, 0, 100, 0, 0, 0.5)
		near(point.x, 15, "nearest distance toward the guardian")
		near(point.z, 0)
		local far = Mix.cuePosition(0, 0, 100, 0, 1, 0.5)
		near(far.x, 70)
		local turned = Mix.cuePosition(0, 0, 100, 0, 0, 1)
		assert(math.abs(math.deg(math.atan2(turned.z, turned.x)) - 35) < 1e-6, "35 degrees at most")
		local lost = Mix.cuePosition(0, 0, nil, nil, 0, 0.25)
		assert(lost and math.abs(math.sqrt(lost.x ^ 2 + lost.z ^ 2) - 15) < 1e-6, "random bearing without a guardian")
	end)

	-- Deliberately changed in the dread pass: a 17-stud giant strides 9 studs, not 5.
	case("Dread pass: step interval is a giant's 9-stud stride over speed", function()
		near(Mix.stepInterval(4), 2.25)
		near(Mix.stepInterval(10), 0.9)
		assert(Mix.stepInterval(0) == nil and Mix.stepInterval(0 / 0) == nil and Mix.stepInterval(-3) == nil, "no steps when still")
	end)

	case("Dread pass: you hear its steps before you see it", function()
		-- The fog hides it from about 48 to 140 studs (docs/ui/wildbound-world.md); its steps carry to 150.
		for _, slot in ipairs({ "steps", "giantSteps", "approach" }) do
			local min, max = Mix.rollOff(slot)
			assert(min >= 10 and max >= 150, slot .. " rolls off too soon: " .. tostring(min) .. ", " .. tostring(max))
		end
		local min, max = Mix.rollOff("snap")
		near(min, 8, "other cues keep 8"); near(max, 60, "other cues keep 60")
		for _, time in ipairs(TIMES) do
			local distant = Mix.targets("Distant", time, false)
			near(distant.steps, 0.25, time .. " distant steps")
			near(distant.giantSteps, 0.18, time .. " distant giant steps")
			near(distant.approach, 0.12, time .. " approach bed")
			near(Mix.targets("Safe", time, false).giantSteps, 0, time .. " silent when safe")
		end
		near(Mix.targets("Near", "Night", false).giantSteps, 0.30)
		near(Mix.targets("Chase", "Night", false).giantSteps, 0.35)
		near(Mix.targets("Chase", "Night", false).approach, 0, "the bed gives way to the chase")
		near(Mix.targets("Near", "Night", false).creak, 0.12, "trees creak when it is near")
		assert(Mix.gait(4) < 1 and Mix.gait(10) > 1 and Mix.gait(30) <= 1.3 and Mix.gait(0) >= 0.7, "walk slow, run fast")
		assert(Mix.gait(0 / 0) == 1, "bad speed keeps the clip's own pace")
		near(Mix.oneShot("crack", false).volume, 0.25); near(Mix.oneShot("groan", false).volume, 0.30)
		near(Mix.nextDelay("crack", "Near", false, 0), 8); near(Mix.nextDelay("crack", "Near", false, 1), 16)
		near(Mix.nextDelay("groan", "Chase", false, 0), 10); near(Mix.nextDelay("groan", "Chase", false, 1), 18)
		assert(Mix.nextDelay("crack", "Safe", false, 0.5) == nil, "no cracks when safe")
		-- Ids from docs/audio/wildbound-dread-assets-shortlist.md, kept in the catalog only.
		local ids = function(slot) return table.concat(Catalog.SOUNDS[slot].ids, ",") end
		assert(ids("giantSteps") == "9125404769,9125404774" and Catalog.SOUNDS.giantSteps.loop, "giant thumps loop")
		assert(ids("approach") == "9125404796" and ids("crack") == "9126239755" and ids("creak") == "9120262025", "beds")
		assert(ids("groan") == "9114628321" and math.abs(Catalog.SOUNDS.groan.pitch - 0.7) < 1e-9, "groan pitched down")
		assert(ids("steps") == "9114080709,9114079718", "the single thump stays the stride one-shot")
	end)

	case("D9: jumpscare refuses within 15 s, twice per life, and when unloaded", function()
		local state = Mix.newJumpscare()
		local ok = Mix.jumpscareAllowed(state, 100, "life-1", true)
		assert(ok, "the first defeat plays")
		Mix.markJumpscare(state, 100, "life-1")
		assert(not Mix.jumpscareAllowed(state, 130, "life-1", true), "once per life")
		assert(not Mix.jumpscareAllowed(state, 110, "life-2", true), "15 s cooldown")
		assert(Mix.jumpscareAllowed(state, 115, "life-2", true), "after 15 s on a new life")
		assert(not Mix.jumpscareAllowed(state, 200, "life-3", false), "unloaded stinger: impact only")
		assert(not Mix.jumpscareAllowed(nil, 200, "life-3", true))
		assert(Mix.fresh(99, 100) and not Mix.fresh(97.9, 100) and not Mix.fresh(nil, 100) and not Mix.fresh(0 / 0, 100),
			"events older than 2 s are stale")
	end)

	case("D9: no id is repeated across conflicting roles without being listed", function()
		local owners = {}
		for slot, entry in pairs(Catalog.SOUNDS) do
			assert(type(entry.ids) == "table" and #entry.ids >= 1, slot .. " has no id")
			assert(table.find(Catalog.GROUPS, entry.group), slot .. " has no known group")
			for _, id in ipairs(entry.ids) do
				assert(type(id) == "number" and id > 0 and id % 1 == 0, slot .. " id")
				owners[id] = owners[id] or {}
				table.insert(owners[id], slot)
			end
		end
		for id, slots in pairs(owners) do
			if #slots > 1 then
				table.sort(slots)
				local listed = Catalog.SHARED[id]
				assert(listed and table.concat(listed, ",") == table.concat(slots, ","), tostring(id) .. " reused by "
					.. table.concat(slots, ",") .. " without being listed")
			end
		end
		assert(#Catalog.GROUPS == 5, "five groups")
	end)

	-- Chase pass (CP1): the player's own breath while sprinting and out of breath, the existing hidden breath (no new id).
	case("chase pass: breath while sprinting, hidden or out of breath", function()
		near(Mix.breath(true, "walk", false), 0.12, "hidden, as before")
		near(Mix.breath(false, "sprint", false), 0.22, "sprinting")
		near(Mix.breath(false, "exhausted", false), 0.3, "out of breath")
		near(Mix.breath(false, "walk", false), 0, "walking is quiet")
		near(Mix.breath(false, "sprint", true), 0.11, "Efectos suaves halves it")
		near(Mix.breath(true, "sprint", false), 0.12, "hiding wins")
	end)
	-- Fear pass (FA3): a heartbeat that rises with the threat, a parent's roar, and La Silueta's distant call.
	case("FA3: the heartbeat follows its intensity, quieter with Efectos suaves", function()
		local calm = Mix.heart(0, false)
		near(calm.volume, 0, "silent when calm")
		local full = Mix.heart(1, false)
		assert(full.volume > 0.3 and full.volume <= 0.6, "audible " .. tostring(full.volume))
		assert(full.speed > Mix.heart(0.3, false).speed, "it beats faster when close")
		assert(Mix.heart(1, true).volume < full.volume, "softer")
		near(Mix.heart(0 / 0, false).volume, 0, "bad input")
		assert(Catalog.SOUNDS.heartbeat and Catalog.SOUNDS.heartbeat.loop and not Catalog.SOUNDS.heartbeat.spatial,
			"a looping heartbeat in the player's head")
	end)

	case("FA3: a roar from the parents and a distant call from La Silueta", function()
		assert(Catalog.SOUNDS.roar and Catalog.SOUNDS.roar.spatial, "the roar comes from the adult")
		local roar = Mix.oneShot("roar", false)
		assert(roar.volume > 0.3, "loud")
		assert(Mix.oneShot("roar", true).volume < roar.volume, "softer")
		assert(Catalog.SOUNDS.call and Catalog.SOUNDS.call.spatial, "the call comes from the forest")
		local lo, hi = Mix.rollOff("call")
		assert(hi >= 180, "heard from far away " .. tostring(hi))
		assert(Mix.nextDelay("call", "Distant", false, 0.5) ~= nil, "it calls while it is around")
		assert(Mix.nextDelay("call", "Safe", false, 0.5) == nil, "never in camp")
		assert(Mix.nextDelay("call", "Chase", false, 0.5) == nil, "not during a chase (the roar is there)")
	end)

	return result
end
