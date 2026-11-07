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
		near(closeBy.steps, 0.35)
		local chase = Mix.targets("Chase", "Night", false)
		near(chase.wind, 0.14 * 0.4, "wind x 0.4")
		near(chase.chaseMusic, 0.35)
		near(chase.pulse, 0.12)
		near(chase.steps, 0.40)
		near(chase.unsettling, 0)
		near(Mix.stepPitch("Chase"), 1.15)
		near(Mix.stepPitch("Near"), 1)
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
						assert(math.max(t.steps, t.breathing) >= loudestMusic, label .. ": guardian cues under the music")
					end
					for _, shot in ipairs({ "snap", "dirt", "whisper", "signature", "hit", "stinger" }) do
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
		near(Mix.targets("Near", "Day", true).steps, 0.35, "steps unchanged")
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

	case("D9: step interval is 5 / speed", function()
		near(Mix.stepInterval(4), 1.25)
		near(Mix.stepInterval(10), 0.5)
		assert(Mix.stepInterval(0) == nil and Mix.stepInterval(0 / 0) == nil and Mix.stepInterval(-3) == nil, "no steps when still")
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

	return result
end
