-- Invoke with require(freshTestClone)(require(freshClipsClone), require(freshAnimPlanClone)).
-- Scuttler (odd/tasks/wildbound-scuttler.md, SC9): the seventeen clips WildboundBeastAnimPlan.PLANS.Scuttler names, as
-- data. Per key, an offset and a rotation per bone in model axes (X to the creature's right, Y up, -Z forward).
-- The build case runs on a stand-in rig made from Clips.BONES (a RootPart and the bone tree, rest rotation identity),
-- so the suite runs before the model is imported; SC10 adds the imported prefab as a third argument. Changes nothing
-- (the stand-in is never parented and is destroyed at the end).
return function(Clips, Plan)
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
	local BONES = {}
	local KNOWN = {}
	for _, bone in ipairs(Clips.BONES) do
		table.insert(BONES, bone[1])
		KNOWN[bone[1]] = true
	end
	local function value(pose, bone, i) return (pose[bone] or {})[i] or 0 end
	local function samePose(a, b, label)
		for _, bone in ipairs(BONES) do
			for i = 1, 6 do near(value(a, bone, i), value(b, bone, i), 1e-6, label .. " " .. bone .. "[" .. i .. "]") end
		end
	end
	local function keys(name) return Clips.CLIPS[name].keys end
	local function first(name) return keys(name)[1][2] end
	local function last(name) local k = keys(name); return k[#k][2] end
	local SHEET = { Idle = { 2.4, true }, Skitter = { 0.6, true }, Read = { 1.6, true }, Intercept = { 0.4, true },
		Block = { 1.2, true }, Feint = { 0.9, false }, ChargeWindup = { 1.1, false }, Charge = { 0.45, true }, Snap = { 1.2, false },
		PulseCharge = { 1.3, false }, Pulse = { 0.8, false }, Recover = { 1.0, false }, Stumble = { 0.8, false },
		Crash = { 0.7, false }, Fallen = { 1.6, true }, GetUp = { 1.0, false }, Retreat = { 1.0, false } }
	-- The clips allowed to drop the body to the ground (the feet leave it).
	local DOWN = { Stumble = true, Crash = true, Fallen = true, GetUp = true }
	local LEGS = {}
	for _, s in ipairs({ "L", "R" }) do
		for i = 1, 4 do table.insert(LEGS, { side = s, index = i, upper = "Leg_" .. s .. i .. "_Upper" }) end
	end

	case("the rig: 43 bones, parents first, Root on top, the legs on Hips, no name twice", function()
		equal(#Clips.BONES, 43, "bones")
		local seen = {}
		for i, bone in ipairs(Clips.BONES) do
			assert(not seen[bone[1]], "bone named twice: " .. bone[1])
			if i == 1 then equal(bone[1], "Root", "first bone"); equal(bone[2], nil, "Root's parent")
			else assert(seen[bone[2]], bone[1] .. " comes before its parent " .. tostring(bone[2])) end
			seen[bone[1]] = bone[2] or true
		end
		for _, leg in ipairs(LEGS) do equal(seen[leg.upper], "Hips", leg.upper .. " parent") end
	end)

	case("the seventeen clips of the plan, with their lengths and loops, on the rig's bones only", function()
		local count = 0
		for _ in pairs(Clips.CLIPS) do count += 1 end
		equal(count, 17, "clips"); equal(#Clips.ORDER, 17, "order")
		local inOrder = {}
		for _, name in ipairs(Clips.ORDER) do
			assert(not inOrder[name], "ORDER names " .. name .. " twice")
			inOrder[name] = true
		end
		for name, rule in pairs(SHEET) do
			local clip = Clips.CLIPS[name]
			assert(clip and inOrder[name], "missing clip " .. name)
			near(clip.length, rule[1], 1e-6, name .. " length"); equal(clip.loop, rule[2], name .. " loop")
			near(clip.keys[1][1], 0, 1e-9, name .. " first key time"); near(clip.keys[#clip.keys][1], clip.length, 1e-9, name .. " last key time")
			for i = 2, #clip.keys do assert(clip.keys[i][1] > clip.keys[i - 1][1], name .. " keys out of order") end
			for i, key in ipairs(clip.keys) do
				for bone in pairs(key[2]) do assert(KNOWN[bone], name .. " key " .. i .. " poses an unknown bone " .. tostring(bone)) end
			end
		end
	end)

	case("the clips are exactly the ones WildboundBeastAnimPlan.PLANS.Scuttler plays", function()
		assert(type(Plan) == "table" and type(Plan.clips) == "function", "no AnimPlan given")
		local planned = Plan.clips("Scuttler")
		local ours = table.clone(Clips.ORDER)
		table.sort(ours)
		equal(#planned, #ours, "clip count")
		for i, name in ipairs(planned) do equal(ours[i], name, "clip " .. i) end
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

	case("loops close cleanly; one-shots end at rest unless the next phase picks up their last pose", function()
		local HOLDS = { ChargeWindup = true, PulseCharge = true, Stumble = true, Crash = true, Retreat = true }
		for name, clip in pairs(Clips.CLIPS) do
			if clip.loop then
				samePose(first(name), last(name), name .. " loop seam")
			elseif not HOLDS[name] then
				samePose(last(name), {}, name .. " end")
			end
		end
		for _, name in ipairs({ "Feint", "ChargeWindup", "Snap", "PulseCharge", "Retreat" }) do
			samePose(first(name), {}, name .. " starts at rest")
		end
	end)

	case("the chains join without a jump: windup -> charge -> recover/stumble/crash -> fallen -> get up; rear -> pulse", function()
		samePose(last("ChargeWindup"), first("Charge"), "windup into charge")
		for _, name in ipairs({ "Recover", "Stumble", "Crash" }) do samePose(first("Charge"), first(name), "charge into " .. name) end
		samePose(last("Stumble"), first("Fallen"), "stumble into fallen")
		samePose(last("Crash"), first("Fallen"), "crash into fallen")
		samePose(first("Fallen"), first("GetUp"), "fallen into get up")
		samePose(last("PulseCharge"), first("Pulse"), "pulse charge into pulse")
	end)

	case("markers for the server-timed attacks only: the windup commits at 0.80 s, the Snap hits at 0.90 s; the feint has none", function()
		local function marker(name, label)
			for _, m in ipairs(Clips.CLIPS[name].markers or {}) do if m[2] == label then return m[1] end end
			error(name .. " has no marker " .. label, 0)
		end
		near(marker("ChargeWindup", "TelegraphStart"), 0, 1e-9, "windup TelegraphStart")
		near(marker("ChargeWindup", "AttackCommit"), 0.8, 1e-9, "windup AttackCommit (1.1 s tell, lockLead 0.3)")
		near(marker("Snap", "TelegraphStart"), 0, 1e-9, "Snap TelegraphStart"); near(marker("Snap", "HitFrame"), 0.9, 1e-9, "Snap HitFrame")
		near(marker("PulseCharge", "TelegraphStart"), 0, 1e-9, "PulseCharge TelegraphStart")
		near(marker("Pulse", "HitFrame"), 0, 1e-9, "Pulse HitFrame")
		equal(#(Clips.CLIPS.Feint.markers or {}), 0, "Feint markers")
		local ATTACKS = { ChargeWindup = true, Snap = true, PulseCharge = true, Pulse = true }
		for name, clip in pairs(Clips.CLIPS) do
			for _, m in ipairs(clip.markers or {}) do
				local onKey = false
				for _, key in ipairs(clip.keys) do if math.abs(key[1] - m[1]) < 1e-9 then onKey = true end end
				assert(onKey, name .. " marker " .. m[2] .. " is not on a keyframe")
				assert(ATTACKS[name], name .. " carries the attack marker " .. m[2])
			end
		end
	end)

	case("in place: the root never moves; standing, Hips never turns or slides and the legs take its bob back", function()
		for name, clip in pairs(Clips.CLIPS) do
			for i, key in ipairs(clip.keys) do
				local pose = key[2]
				for axis = 1, 6 do near(value(pose, "Root", axis), 0, 1e-9, name .. " key " .. i .. " moves the root") end
				near(value(pose, "Hips", 1), 0, 1e-9, name .. " key " .. i .. " slides Hips sideways")
				near(value(pose, "Hips", 3), 0, 1e-9, name .. " key " .. i .. " slides Hips along the lane")
				if not DOWN[name] then
					for axis = 4, 6 do near(value(pose, "Hips", axis), 0, 1e-9, name .. " key " .. i .. " turns Hips") end
					local bob = value(pose, "Hips", 2)
					for _, leg in ipairs(LEGS) do
						near(value(pose, leg.upper, 2), -bob, 1e-9, name .. " key " .. i .. " " .. leg.upper .. " lets the feet follow the body")
					end
				end
			end
		end
	end)

	case("alternating tripods: L1, R2, L3, R4 swing together and the other four the opposite way", function()
		local function forward(pose, leg)
			local yaw = value(pose, leg.upper, 5)
			return leg.side == "L" and -yaw or yaw
		end
		for _, name in ipairs({ "Skitter", "Intercept", "Charge" }) do
			local swing = 0
			for i, key in ipairs(keys(name)) do
				local lead = forward(key[2], LEGS[1]) -- L1, group A
				for _, leg in ipairs(LEGS) do
					local inA = (leg.side == "L") == (leg.index % 2 == 1)
					near(forward(key[2], leg), inA and lead or -lead, 1e-9, name .. " key " .. i .. " " .. leg.upper)
				end
				swing = math.max(swing, math.abs(lead))
			end
			assert(swing >= 12, name .. " barely moves the legs: " .. swing)
		end
		assert(Clips.CLIPS.Intercept.length < Clips.CLIPS.Skitter.length, "the intercept run is not faster than the skitter")
		assert(Clips.CLIPS.Charge.length < Clips.CLIPS.Skitter.length, "the charge is not faster than the skitter")
	end)

	case("the moves read: the windup only deepens, the pulse rears higher and screams, the Block lifts the claws, the fall lies down", function()
		local windup = keys("ChargeWindup")
		for i = 2, #windup do
			assert(value(windup[i][2], "Hips", 2) <= value(windup[i - 1][2], "Hips", 2) + 1e-9, "the windup rises at key " .. i)
		end
		assert(value(last("ChargeWindup"), "Thorax", 4) <= -8, "the windup does not lower the head end")
		local charge = keys("PulseCharge")
		for i = 2, #charge do
			assert(value(charge[i][2], "Thorax", 4) >= value(charge[i - 1][2], "Thorax", 4) - 1e-9, "the rear-up drops at key " .. i)
		end
		assert(value(last("PulseCharge"), "Thorax", 4) >= 25, "the pulse charge does not rear up")
		local scream = 0
		for _, key in ipairs(keys("Pulse")) do scream = math.min(scream, value(key[2], "Jaw", 4)) end
		assert(scream <= -30, "the jaw does not open to scream: " .. scream)
		for i, key in ipairs(keys("Block")) do
			for _, s in ipairs({ "L", "R" }) do
				assert(value(key[2], "Claw_" .. s .. "_Upper", 4) >= 25, "Block key " .. i .. " lowers the " .. s .. " claw")
			end
		end
		local tiltLeft, tiltRight = 0, 0
		for _, key in ipairs(keys("Read")) do
			tiltLeft = math.max(tiltLeft, value(key[2], "Head", 6)); tiltRight = math.min(tiltRight, value(key[2], "Head", 6))
		end
		assert(tiltLeft >= 10 and tiltRight <= -10, "the read does not tilt the head both ways")
		for i, key in ipairs(keys("Fallen")) do
			assert(value(key[2], "Hips", 2) <= -3, "Fallen key " .. i .. " is not on the ground")
		end
	end)

	case("Clips.build makes a KeyframeSequence the rig's bones can play", function()
		local rig
		do
			-- A stand-in: a RootPart carrying Clips.BONES (rest rotation identity), pivot at the origin.
			rig = Instance.new("Model")
			rig.Name = "ScuttlerStandIn"
			local part = Instance.new("Part")
			part.Name = "RootPart"
			part.Anchored = true
			part.CFrame = CFrame.new()
			part.Parent = rig
			rig.PrimaryPart = part
			local byName = {}
			for _, bone in ipairs(Clips.BONES) do
				local item = Instance.new("Bone")
				item.Name = bone[1]
				item.Parent = bone[2] and byName[bone[2]] or part
				byName[bone[1]] = item
			end
		end
		local ok, err = pcall(function()
			local sequence = Clips.build(rig, "ChargeWindup")
			assert(sequence:IsA("KeyframeSequence"), "not a KeyframeSequence")
			equal(sequence.Loop, false, "Loop"); equal(sequence.Name, "ChargeWindup", "Name")
			local frames = sequence:GetKeyframes()
			equal(#frames, #keys("ChargeWindup"), "keyframes")
			local final, commit = nil, nil
			for _, frame in ipairs(frames) do
				if not final or frame.Time > final.Time then final = frame end
				for _, d in ipairs(frame:GetDescendants()) do
					if d:IsA("KeyframeMarker") and d.Name == "AttackCommit" then commit = frame.Time end
				end
			end
			near(final.Time, 1.1, 1e-6, "length"); near(commit, 0.8, 1e-6, "AttackCommit marker time")
			local poses = 0
			for _, d in ipairs(final:GetDescendants()) do if d:IsA("Pose") then poses += 1 end end
			equal(poses, 44, "poses per key: the root part and 43 bones")
			local base = final:FindFirstChild(rig.PrimaryPart.Name)
			local hips = base and base:FindFirstChild("Root") and base.Root:FindFirstChild("Hips")
			local jawPose = hips and hips:FindFirstChild("Thorax") and hips.Thorax:FindFirstChild("Head") and hips.Thorax.Head:FindFirstChild("Jaw")
			assert(jawPose, "pose tree does not follow the bone tree")
			local rest
			for _, d in ipairs(rig:GetDescendants()) do
				if d:IsA("Bone") and d.Name == "Hips" then rest = rig:GetPivot():ToObjectSpace(d.WorldCFrame).Rotation end
			end
			local inModel = rest * hips.CFrame * rest:Inverse()
			near(inModel.Position.Y, value(last("ChargeWindup"), "Hips", 2), 1e-4, "Hips bob")
			sequence:Destroy()
			assert(not pcall(Clips.build, rig, "NoSuchClip"), "an unknown clip was accepted")
		end)
		rig:Destroy()
		assert(ok, err)
	end)

	return result
end
