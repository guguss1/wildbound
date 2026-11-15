-- Invoke with require(freshTestClone)(require(freshClipsClone), ServerStorage.WildboundAssets.Tortidragon).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2): Tortidragon's eleven clips against its sheet (pack
-- 03_PERSONAJES/03_TORTIDRAGON.md). The clips are data: per key, an offset and a rotation per bone in model axes (X to
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
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local BONES = { "Root", "Pelvis", "Spine", "Neck_01", "Neck_02", "Head", "Jaw", "CreamCrest", "Strawberry_L", "Strawberry_R",
		"Cheek_L", "Cheek_R", "Strawberry_Back", "FrontLeg_L_Upper", "FrontLeg_L_Lower", "FrontLeg_R_Upper", "FrontLeg_R_Lower",
		"BackLeg_L_Upper", "BackLeg_L_Lower", "BackLeg_R_Upper", "BackLeg_R_Lower", "Tail_01", "Tail_02", "Tail_03" }
	local KNOWN = {}
	for _, bone in ipairs(BONES) do KNOWN[bone] = true end
	local function value(pose, bone, i) return (pose[bone] or {})[i] or 0 end
	local function samePose(a, b, label)
		for _, bone in ipairs(BONES) do
			for i = 1, 6 do near(value(a, bone, i), value(b, bone, i), 1e-6, label .. " " .. bone .. "[" .. i .. "]") end
		end
	end
	local function keys(name) return Clips.CLIPS[name].keys end
	local SHEET = { Idle = { 3, true }, Walk_Quadruped = { 0.9, true }, Run_Quadruped = { 0.6, true }, Turn = { 0.5, false },
		Alert = { 0.75, false }, Attack_Telegraph = { 1, false }, Attack_Release = { 0.65, false }, Attack_Recover = { 0.85, false },
		HitReact = { 0.5, false }, FarmIdle = { 4, true }, HatchReact = { 2, false } }

	case("the eleven clips of the sheet, with its lengths and loops, on the rig's bones only", function()
		local count = 0
		for _ in pairs(Clips.CLIPS) do count += 1 end
		equal(count, 11, "clips"); equal(#Clips.ORDER, 11, "order")
		for name, rule in pairs(SHEET) do
			local clip = Clips.CLIPS[name]
			assert(clip, "missing clip " .. name)
			near(clip.length, rule[1], 1e-6, name .. " length"); equal(clip.loop, rule[2], name .. " loop")
			near(clip.keys[1][1], 0, 1e-9, name .. " first key time"); near(clip.keys[#clip.keys][1], clip.length, 1e-9, name .. " last key time")
			for i = 2, #clip.keys do assert(clip.keys[i][1] > clip.keys[i - 1][1], name .. " keys out of order") end
			for i, key in ipairs(clip.keys) do
				for bone in pairs(key[2]) do assert(KNOWN[bone], name .. " key " .. i .. " poses an unknown bone " .. tostring(bone)) end
			end
		end
	end)

	case("every clip is published: an Animation asset id per clip, none shared", function()
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

	case("looping clips close cleanly and one-shots end at rest (Alert holds its look)", function()
		for name, clip in pairs(Clips.CLIPS) do
			if clip.loop then
				samePose(clip.keys[1][2], clip.keys[#clip.keys][2], name .. " loop seam")
			elseif name ~= "Attack_Telegraph" and name ~= "Attack_Release" and name ~= "Alert" then
				samePose(clip.keys[#clip.keys][2], {}, name .. " end")
			end
		end
	end)

	case("the three attack segments chain without a jump", function()
		local telegraph, release, recover = keys("Attack_Telegraph"), keys("Attack_Release"), keys("Attack_Recover")
		samePose(telegraph[1][2], {}, "telegraph starts at rest")
		samePose(telegraph[#telegraph][2], release[1][2], "telegraph into release")
		samePose(release[#release][2], recover[1][2], "release into recover")
		samePose(recover[#recover][2], {}, "recover ends at rest")
	end)

	case("markers for the server-timed attack: start, commit at the 0.60 s lock, the shots, recover, end", function()
		local function marker(name, label)
			for _, m in ipairs(Clips.CLIPS[name].markers or {}) do if m[2] == label then return m[1] end end
			error(name .. " has no marker " .. label, 0)
		end
		near(marker("Attack_Telegraph", "TelegraphStart"), 0, 1e-9, "TelegraphStart"); near(marker("Attack_Telegraph", "AttackCommit"), 0.6, 1e-9, "AttackCommit")
		near(marker("Attack_Release", "HitFrame"), 0, 1e-9, "HitFrame")
		near(marker("Attack_Recover", "RecoverStart"), 0, 1e-9, "RecoverStart"); near(marker("Attack_Recover", "AttackEnd"), 0.85, 1e-9, "AttackEnd")
		for name, clip in pairs(Clips.CLIPS) do
			for _, m in ipairs(clip.markers or {}) do
				local onKey = false
				for _, key in ipairs(clip.keys) do if math.abs(key[1] - m[1]) < 1e-9 then onKey = true end end
				assert(onKey, name .. " marker " .. m[2] .. " is not on a keyframe")
				assert(string.sub(name, 1, 7) == "Attack_", name .. " carries the attack marker " .. m[2])
			end
		end
	end)

	case("in place: the root never moves and, standing, the legs take the body's bob back (no foot sliding)", function()
		for name, clip in pairs(Clips.CLIPS) do
			for i, key in ipairs(clip.keys) do
				local pose = key[2]
				for axis = 1, 6 do near(value(pose, "Root", axis), 0, 1e-9, name .. " key " .. i .. " moves the root") end
				if name ~= "FarmIdle" then
					local bob = value(pose, "Pelvis", 2)
					for _, leg in ipairs({ "FrontLeg_L_Upper", "FrontLeg_R_Upper", "BackLeg_L_Upper", "BackLeg_R_Upper" }) do
						near(value(pose, leg, 2), -bob, 1e-9, name .. " key " .. i .. " " .. leg .. " lets the feet follow the body")
					end
				end
			end
		end
	end)

	case("four-legged gaits: the trot swings diagonal pairs, the gallop the front pair then the back pair", function()
		for _, key in ipairs(keys("Walk_Quadruped")) do
			local p = key[2]
			near(value(p, "FrontLeg_L_Upper", 4), value(p, "BackLeg_R_Upper", 4), 1e-9, "trot pair FL-BR")
			near(value(p, "FrontLeg_R_Upper", 4), value(p, "BackLeg_L_Upper", 4), 1e-9, "trot pair FR-BL")
		end
		local swing = 0
		for _, key in ipairs(keys("Walk_Quadruped")) do swing = math.max(swing, math.abs(value(key[2], "FrontLeg_L_Upper", 4))) end
		assert(swing >= 12, "the trot barely moves the legs: " .. swing)
		local first = keys("Run_Quadruped")[1][2]
		assert(value(first, "FrontLeg_L_Upper", 4) * value(first, "FrontLeg_R_Upper", 4) > 0, "the gallop's front legs are not together")
		assert(value(first, "FrontLeg_L_Upper", 4) * value(first, "BackLeg_L_Upper", 4) < 0, "the gallop's back pair is not opposite the front")
		local lift = 0
		for _, key in ipairs(keys("Run_Quadruped")) do lift = math.max(lift, value(key[2], "Tail_01", 4)) end
		assert(lift > 0, "the tail does not lift for balance in the gallop")
	end)

	case("the attack reads: cheeks puff in the tell (only ever more), the jaw opens in the release; the farm pet never strikes", function()
		local telegraph = keys("Attack_Telegraph")
		for i = 2, #telegraph do
			assert(-value(telegraph[i][2], "Cheek_L", 1) >= -value(telegraph[i - 1][2], "Cheek_L", 1) - 1e-9, "the cheeks deflate in the tell")
		end
		assert(-value(telegraph[#telegraph][2], "Cheek_L", 1) >= 0.3, "the cheeks do not puff out (left is -X)")
		assert(value(telegraph[#telegraph][2], "Cheek_R", 1) >= 0.3, "the right cheek does not puff out")
		local open = 0
		for _, key in ipairs(keys("Attack_Release")) do open = math.min(open, value(key[2], "Jaw", 4)) end
		assert(open <= -20, "the mouth does not open to spit: " .. open)
		for _, key in ipairs(keys("FarmIdle")) do
			assert(value(key[2], "Cheek_L", 1) == 0 and value(key[2], "Cheek_R", 1) == 0, "FarmIdle puffs like an attack")
			assert(value(key[2], "Pelvis", 2) < -1, "the farm pet does not lie down")
		end
		equal(#(Clips.CLIPS.FarmIdle.markers or {}), 0, "FarmIdle markers")
	end)

	case("Clips.build makes a KeyframeSequence the prefab's bones can play", function()
		local sequence = Clips.build(prefab, "Attack_Telegraph")
		assert(sequence:IsA("KeyframeSequence"), "not a KeyframeSequence")
		equal(sequence.Loop, false, "Loop"); equal(sequence.Name, "Attack_Telegraph", "Name")
		local frames = sequence:GetKeyframes()
		equal(#frames, #keys("Attack_Telegraph"), "keyframes")
		local last, poses, commit = nil, 0, nil
		for _, frame in ipairs(frames) do
			if not last or frame.Time > last.Time then last = frame end
			for _, d in ipairs(frame:GetDescendants()) do
				if d:IsA("KeyframeMarker") and d.Name == "AttackCommit" then commit = frame.Time end
			end
		end
		near(last.Time, 1, 1e-6, "length"); near(commit, 0.6, 1e-6, "AttackCommit marker time")
		for _, d in ipairs(last:GetDescendants()) do if d:IsA("Pose") then poses += 1 end end
		equal(poses, 25, "poses per key: the root part and 24 bones")
		local root = last:FindFirstChild("RootPart")
		local pelvis = root and root:FindFirstChild("Root") and root.Root:FindFirstChild("Pelvis")
		local cheek = pelvis and pelvis:FindFirstChild("Spine") and pelvis.Spine:FindFirstChild("Neck_01") and pelvis.Spine.Neck_01:FindFirstChild("Neck_02")
			and pelvis.Spine.Neck_01.Neck_02:FindFirstChild("Head") and pelvis.Spine.Neck_01.Neck_02.Head:FindFirstChild("Cheek_L")
		assert(cheek, "pose tree does not follow the bone tree")
		local rest
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("Bone") and d.Name == "Cheek_L" then rest = prefab:GetPivot():ToObjectSpace(d.WorldCFrame).Rotation end
		end
		local inModel = rest * cheek.CFrame * rest:Inverse()
		near(inModel.Position.X, value(keys("Attack_Telegraph")[#keys("Attack_Telegraph")][2], "Cheek_L", 1), 1e-4, "cheek offset")
		sequence:Destroy()
		assert(not pcall(Clips.build, prefab, "NoSuchClip"), "an unknown clip was accepted")
	end)

	return result
end
