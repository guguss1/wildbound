-- Invoke with require(freshTestClone)(require(freshClipsClone), ServerStorage.WildboundAssets.Gomibu).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3, S6): Gomibu's ten clips against its sheet (pack
-- 03_PERSONAJES/01_GOMIBU.md, 02_DIRECCION_DE_ARTE/02_ESCALAS_Y_ANIMACION_COMUN.md). The clips are data: per key, an
-- offset and a rotation per bone in model axes (X to the character's right, Y up, -Z forward). Changes nothing.
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
	local BONES = { "Root", "Pelvis", "SpineGel", "Head", "Ear_L", "Ear_R", "Arm_L", "Arm_R", "Hand_L", "Hand_R", "Leg_L", "Leg_R", "Foot_L", "Foot_R" }
	local function value(pose, bone, i) return (pose[bone] or {})[i] or 0 end
	local function samePose(a, b, label)
		for _, bone in ipairs(BONES) do
			for i = 1, 6 do near(value(a, bone, i), value(b, bone, i), 1e-6, label .. " " .. bone .. "[" .. i .. "]") end
		end
	end
	local function keys(name) return Clips.CLIPS[name].keys end
	-- how far the head sits above (+) or below (-) its rest height in a pose, ignoring the jump itself
	local function headLift(pose) return value(pose, "Pelvis", 2) + value(pose, "SpineGel", 2) + value(pose, "Head", 2) end
	local SHEET = { Idle = { 2, 3, true }, Bounce_Move = { 0.8, 1.1, true }, Turn = { 0.5, 0.5, false }, Alert = { 0.7, 0.7, false },
		Attack_Telegraph = { 0.9, 0.9, false }, Attack_Release = { 0.45, 0.45, false }, Attack_Recover = { 0.7, 0.7, false },
		HitReact = { 0.45, 0.45, false }, FarmIdle = { 3, 3, true }, HatchReact = { 2, 2, false } }

	case("S6: the ten clips of the sheet, with its lengths and loops", function()
		local count = 0
		for _ in pairs(Clips.CLIPS) do count += 1 end
		equal(count, 10, "clips")
		equal(#Clips.ORDER, 10, "order")
		for name, rule in pairs(SHEET) do
			local clip = Clips.CLIPS[name]
			assert(clip, "missing clip " .. name)
			assert(clip.length >= rule[1] - 1e-6 and clip.length <= rule[2] + 1e-6, name .. " lasts " .. clip.length)
			equal(clip.loop, rule[3], name .. " loop")
			near(clip.keys[1][1], 0, 1e-9, name .. " first key time")
			near(clip.keys[#clip.keys][1], clip.length, 1e-9, name .. " last key time")
			for i = 2, #clip.keys do assert(clip.keys[i][1] > clip.keys[i - 1][1], name .. " keys out of order") end
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

	case("S6: markers for the server-timed attack: start, commit at 0.55 s, hit, recover, end", function()
		local function marker(name, label)
			for _, m in ipairs(Clips.CLIPS[name].markers or {}) do if m[2] == label then return m[1] end end
			error(name .. " has no marker " .. label, 0)
		end
		near(marker("Attack_Telegraph", "TelegraphStart"), 0, 1e-9, "TelegraphStart")
		near(marker("Attack_Telegraph", "AttackCommit"), 0.55, 1e-9, "AttackCommit")
		near(marker("Attack_Release", "HitFrame"), 0.45, 1e-9, "HitFrame")
		near(marker("Attack_Recover", "RecoverStart"), 0, 1e-9, "RecoverStart")
		near(marker("Attack_Recover", "AttackEnd"), 0.7, 1e-9, "AttackEnd")
		for name, clip in pairs(Clips.CLIPS) do
			for _, m in ipairs(clip.markers or {}) do
				local onKey = false
				for _, key in ipairs(clip.keys) do if math.abs(key[1] - m[1]) < 1e-9 then onKey = true end end
				assert(onKey, name .. " marker " .. m[2] .. " is not on a keyframe")
				assert(string.sub(name, 1, 7) == "Attack_", name .. " carries the attack marker " .. m[2])
			end
		end
	end)

	case("S6: in place, and no sliding feet: on the ground the feet stay where they are", function()
		for name, clip in pairs(Clips.CLIPS) do
			for i, key in ipairs(clip.keys) do
				local pose = key[2]
				near(value(pose, "Root", 1), 0, 1e-9, name .. " key " .. i .. " moves the root sideways")
				near(value(pose, "Root", 3), 0, 1e-9, name .. " key " .. i .. " moves the root forward")
				assert(value(pose, "Root", 2) >= 0, name .. " key " .. i .. " sinks into the floor")
				if value(pose, "Root", 2) == 0 then
					for _, side in ipairs({ "L", "R" }) do
						for axis = 1, 3 do
							near(value(pose, "Pelvis", axis) + value(pose, "Leg_" .. side, axis) + value(pose, "Foot_" .. side, axis), 0, 1e-6,
								name .. " key " .. i .. " slides foot " .. side)
						end
					end
				end
			end
		end
	end)

	case("S6: it moves like gelatin, and the farm pet never strikes", function()
		local low, high, apex = 0, 0, 0
		for _, key in ipairs(keys("Bounce_Move")) do
			low, high = math.min(low, headLift(key[2])), math.max(high, headLift(key[2]))
			apex = math.max(apex, value(key[2], "Root", 2))
		end
		assert(low <= -0.6, "Bounce_Move never compresses: " .. low)
		assert(high >= 0.4, "Bounce_Move never stretches: " .. high)
		assert(apex >= 1, "Bounce_Move never leaves the ground")
		local telegraph = keys("Attack_Telegraph")
		local depth = headLift(telegraph[#telegraph][2])
		assert(depth <= -0.9, "the telegraph is not a long compression: " .. depth)
		for i = 2, #telegraph do assert(headLift(telegraph[i][2]) <= headLift(telegraph[i - 1][2]) + 1e-9, "the telegraph lets go before the jump") end
		local swings = 0
		local recover = keys("Attack_Recover")
		for i = 2, #recover - 1 do
			if (headLift(recover[i][2]) - headLift(recover[i - 1][2])) * (headLift(recover[i + 1][2]) - headLift(recover[i][2])) < 0 then swings += 1 end
		end
		assert(swings >= 3, "the landing does not wobble twice: " .. swings .. " turns")
		for _, key in ipairs(keys("FarmIdle")) do
			assert(headLift(key[2]) > depth * 0.5, "FarmIdle squashes like an attack")
			assert(value(key[2], "Root", 2) <= 0.6, "FarmIdle jumps like an attack")
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
		near(last.Time, 0.9, 1e-6, "length")
		near(commit, 0.55, 1e-6, "AttackCommit marker time")
		for _, d in ipairs(last:GetDescendants()) do if d:IsA("Pose") then poses += 1 end end
		equal(poses, 15, "poses per key: the root part and 14 bones")
		local root = last:FindFirstChild("RootPart")
		assert(root and root:FindFirstChild("Root") and root.Root:FindFirstChild("Pelvis"), "pose tree does not follow the bone tree")
		-- the head pose, taken back to model axes, is the offset the data asks for
		local head = root.Root.Pelvis.SpineGel.Head
		local rest
		for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") and d.Name == "Head" then rest = prefab:GetPivot():ToObjectSpace(d.WorldCFrame).Rotation end end
		local inModel = rest * head.CFrame * rest:Inverse()
		near(inModel.Position.Y, value(keys("Attack_Telegraph")[#keys("Attack_Telegraph")][2], "Head", 2), 1e-4, "head offset")
		sequence:Destroy()
		assert(not pcall(Clips.build, prefab, "NoSuchClip"), "an unknown clip was accepted")
	end)

	return result
end
