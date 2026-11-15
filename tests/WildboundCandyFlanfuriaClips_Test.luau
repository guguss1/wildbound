-- Invoke with require(freshTestClone)(require(freshClipsClone), ServerStorage.WildboundAssets.Flanfuria).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4, S6): Flanfuria's ten clips against its sheet (pack
-- 03_PERSONAJES/02_FLANFURIA.md). The clips are data: per key, an offset and a rotation per bone in model axes (X to
-- the character's right, Y up, -Z forward). Changes nothing.
return function(Clips, prefab)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local BONES = { "Root", "FlanBase", "FlanJiggle", "CaramelTop", "CatRoot", "CatHead", "CatEar_L", "CatEar_R", "CatPaw_L", "CatPaw_R",
		"CatTail_01", "CatTail_02", "CreamPeak", "Cherry" }
	local KNOWN = {}
	for _, bone in ipairs(BONES) do KNOWN[bone] = true end
	local function value(pose, bone, i) return (pose[bone] or {})[i] or 0 end
	local function samePose(a, b, label)
		for _, bone in ipairs(BONES) do
			for i = 1, 6 do near(value(a, bone, i), value(b, bone, i), 1e-6, label .. " " .. bone .. "[" .. i .. "]") end
		end
	end
	local function keys(name) return Clips.CLIPS[name].keys end
	-- how far the top of the flan sits above (+) or below (-) its rest height in a pose, ignoring the hop itself
	local function flanLift(pose) return value(pose, "FlanJiggle", 2) + value(pose, "CaramelTop", 2) end
	local function catLag(pose) return value(pose, "CatRoot", 2) end
	local SHEET = { Idle = { 3, true }, Hop_Move = { 1.1, true }, Turn = { 0.6, false }, Alert = { 0.8, false },
		Attack_Telegraph = { 1, false }, Attack_Release = { 0.8, false }, Attack_Recover = { 0.85, false },
		HitReact = { 0.5, false }, FarmIdle = { 4, true }, HatchReact = { 2, false } }

	case("S6: the ten clips of the sheet, with its lengths and loops, on the sheet's bones only", function()
		local count = 0
		for _ in pairs(Clips.CLIPS) do count += 1 end
		equal(count, 10, "clips")
		equal(#Clips.ORDER, 10, "order")
		for name, rule in pairs(SHEET) do
			local clip = Clips.CLIPS[name]
			assert(clip, "missing clip " .. name)
			near(clip.length, rule[1], 1e-6, name .. " length")
			equal(clip.loop, rule[2], name .. " loop")
			near(clip.keys[1][1], 0, 1e-9, name .. " first key time")
			near(clip.keys[#clip.keys][1], clip.length, 1e-9, name .. " last key time")
			for i = 2, #clip.keys do assert(clip.keys[i][1] > clip.keys[i - 1][1], name .. " keys out of order") end
			for i, key in ipairs(clip.keys) do
				for bone in pairs(key[2]) do assert(KNOWN[bone], name .. " key " .. i .. " poses an unknown bone " .. tostring(bone)) end
			end
		end
	end)

	case("S6: every clip is published: an Animation asset id per clip, none shared", function()
		local seen = {}
		for _, name in ipairs(Clips.ORDER) do
			local id = Clips.IDS and Clips.IDS[name]
			assert(type(id) == "number" and id > 1e9 and id % 1 == 0, name .. " has no asset id")
			assert(not seen[id], name .. " shares its asset id")
			seen[id] = true
			equal(Clips.animationId(name), "rbxassetid://" .. string.format("%d", id), name .. " content id")
		end
		assert(not pcall(Clips.animationId, "NoSuchClip"), "an unknown clip got a content id")
	end)

	case("S6: looping clips close cleanly and one-shots end at rest", function()
		for name, clip in pairs(Clips.CLIPS) do
			if clip.loop then
				samePose(clip.keys[1][2], clip.keys[#clip.keys][2], name .. " loop seam")
			elseif name ~= "Attack_Telegraph" and name ~= "Attack_Release" then
				samePose(clip.keys[#clip.keys][2], {}, name .. " end")
			end
		end
	end)

	case("S6: the three attack segments chain without a jump", function()
		local telegraph, release, recover = keys("Attack_Telegraph"), keys("Attack_Release"), keys("Attack_Recover")
		samePose(telegraph[1][2], {}, "telegraph starts at rest")
		samePose(telegraph[#telegraph][2], release[1][2], "telegraph into release")
		samePose(release[#release][2], recover[1][2], "release into recover")
		samePose(recover[#recover][2], {}, "recover ends at rest")
	end)

	case("S6: markers for the server-timed attack: start, commit at 1.00 s, the wave leaving, recover, end", function()
		local function marker(name, label)
			for _, m in ipairs(Clips.CLIPS[name].markers or {}) do if m[2] == label then return m[1] end end
			error(name .. " has no marker " .. label, 0)
		end
		near(marker("Attack_Telegraph", "TelegraphStart"), 0, 1e-9, "TelegraphStart")
		near(marker("Attack_Telegraph", "AttackCommit"), 1, 1e-9, "AttackCommit")
		near(marker("Attack_Release", "HitFrame"), 0, 1e-9, "HitFrame")
		near(marker("Attack_Recover", "RecoverStart"), 0, 1e-9, "RecoverStart")
		near(marker("Attack_Recover", "AttackEnd"), 0.85, 1e-9, "AttackEnd")
		for name, clip in pairs(Clips.CLIPS) do
			for _, m in ipairs(clip.markers or {}) do
				local onKey = false
				for _, key in ipairs(clip.keys) do if math.abs(key[1] - m[1]) < 1e-9 then onKey = true end end
				assert(onKey, name .. " marker " .. m[2] .. " is not on a keyframe")
				assert(string.sub(name, 1, 7) == "Attack_", name .. " carries the attack marker " .. m[2])
			end
		end
	end)

	case("S6: in place, with a flat base: the root only goes up and FlanBase never moves", function()
		for name, clip in pairs(Clips.CLIPS) do
			for i, key in ipairs(clip.keys) do
				local pose = key[2]
				near(value(pose, "Root", 1), 0, 1e-9, name .. " key " .. i .. " moves the root sideways")
				near(value(pose, "Root", 3), 0, 1e-9, name .. " key " .. i .. " moves the root forward")
				assert(value(pose, "Root", 2) >= 0, name .. " key " .. i .. " sinks into the floor")
				for axis = 1, 6 do near(value(pose, "FlanBase", axis), 0, 1e-9, name .. " key " .. i .. " moves the base") end
				assert(flanLift(pose) >= -1.6, name .. " key " .. i .. " presses the flan through its own base: " .. flanLift(pose))
			end
		end
	end)

	case("S6: it hops like heavy jelly, the kitten a beat late, and the farm pet never strikes", function()
		local low, high, apex = 0, 0, 0
		local hop = keys("Hop_Move")
		for _, key in ipairs(hop) do
			low, high = math.min(low, flanLift(key[2])), math.max(high, flanLift(key[2]))
			apex = math.max(apex, value(key[2], "Root", 2))
		end
		assert(low <= -0.6, "Hop_Move never compresses: " .. low)
		assert(high >= 0.4, "Hop_Move never stretches: " .. high)
		assert(apex >= 0.8 and apex <= 1.5, "Hop_Move is not a short low hop: " .. apex)
		-- the lag: the kitten is still up while the flan is pressed, and comes down on a later key
		local held, nodded = nil, false
		for i, key in ipairs(hop) do
			if flanLift(key[2]) < -0.5 and catLag(key[2]) > 0.1 then held = held or i end
			if held and i > held and catLag(key[2]) < -0.1 then nodded = true end
		end
		assert(held, "the kitten sinks with the flan instead of lagging")
		assert(nodded, "the kitten never nods after the flan")
		local telegraph = keys("Attack_Telegraph")
		local depth = flanLift(telegraph[#telegraph][2])
		assert(depth <= -1, "the telegraph is not a flattening: " .. depth)
		for i = 2, #telegraph do assert(flanLift(telegraph[i][2]) <= flanLift(telegraph[i - 1][2]) + 1e-9, "the telegraph lets go before the wave") end
		assert(catLag(telegraph[#telegraph][2]) < 0, "the kitten does not duck in the tell")
		local release = keys("Attack_Release")
		local burst = 0
		for _, key in ipairs(release) do burst = math.max(burst, flanLift(key[2])) end
		assert(burst >= 0.6, "the release does not spring the body out: " .. burst)
		for _, key in ipairs(release) do equal(value(key[2], "Root", 2), 0, "the release leaves the ground") end
		local swings = 0
		local recover = keys("Attack_Recover")
		for i = 2, #recover - 1 do
			if (flanLift(recover[i][2]) - flanLift(recover[i - 1][2])) * (flanLift(recover[i + 1][2]) - flanLift(recover[i][2])) < 0 then swings += 1 end
		end
		assert(swings >= 3, "the recovery does not wobble twice: " .. swings .. " turns")
		for _, key in ipairs(keys("FarmIdle")) do
			assert(flanLift(key[2]) > depth * 0.5, "FarmIdle flattens like an attack")
			equal(value(key[2], "Root", 2), 0, "FarmIdle hops")
		end
		equal(#(Clips.CLIPS.FarmIdle.markers or {}), 0, "FarmIdle markers")
	end)

	case("Clips.build makes a KeyframeSequence the prefab's bones can play", function()
		local sequence = Clips.build(prefab, "Attack_Telegraph")
		assert(sequence:IsA("KeyframeSequence"), "not a KeyframeSequence")
		equal(sequence.Loop, false, "Loop")
		equal(sequence.Name, "Attack_Telegraph", "Name")
		local frames = sequence:GetKeyframes()
		equal(#frames, #keys("Attack_Telegraph"), "keyframes")
		local last, poses, commit = nil, 0, nil
		for _, frame in ipairs(frames) do
			if not last or frame.Time > last.Time then last = frame end
			for _, d in ipairs(frame:GetDescendants()) do
				if d:IsA("KeyframeMarker") and d.Name == "AttackCommit" then commit = frame.Time end
			end
		end
		near(last.Time, 1, 1e-6, "length")
		near(commit, 1, 1e-6, "AttackCommit marker time")
		for _, d in ipairs(last:GetDescendants()) do if d:IsA("Pose") then poses += 1 end end
		equal(poses, 15, "poses per key: the root part and 14 bones")
		local root = last:FindFirstChild("RootPart")
		local jiggle = root and root:FindFirstChild("Root") and root.Root:FindFirstChild("FlanBase") and root.Root.FlanBase:FindFirstChild("FlanJiggle")
		assert(jiggle and jiggle:FindFirstChild("CaramelTop") and jiggle.CaramelTop:FindFirstChild("CatRoot")
			and jiggle.CaramelTop.CatRoot:FindFirstChild("CatHead"), "pose tree does not follow the bone tree")
		-- the FlanJiggle pose, taken back to model axes, is the offset the data asks for
		local rest
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("Bone") and d.Name == "FlanJiggle" then rest = prefab:GetPivot():ToObjectSpace(d.WorldCFrame).Rotation end
		end
		local inModel = rest * jiggle.CFrame * rest:Inverse()
		near(inModel.Position.Y, value(keys("Attack_Telegraph")[#keys("Attack_Telegraph")][2], "FlanJiggle", 2), 1e-4, "flan offset")
		sequence:Destroy()
		assert(not pcall(Clips.build, prefab, "NoSuchClip"), "an unknown clip was accepted")
	end)

	return result
end
