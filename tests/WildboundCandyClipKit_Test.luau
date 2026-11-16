-- Invoke with require(freshTestClone)(require(freshKitClone), ServerStorage.WildboundNewCandyImports.Canelin,
-- require(freshCanelinClipsClone), require(freshSpecClone), { [name] = require(freshClipsClone) } for the six critters,
-- StarterPlayer.StarterPlayerScripts.WildboundCandyCritterAnim.Source), where each fresh clips clone is
-- ReplicatedStorage.WildboundCandyCritterClips<Name> cloned next to a fresh WildboundCandyClipKit clone (it requires
-- script.Parent.WildboundCandyClipKit) and freshSpecClone is ReplicatedStorage.WildboundCandyCritterAnimSpec.
-- Caramelo critters (odd/tasks/wildbound-candy-critters-anim.md): the shared clip kit. define keeps the clip-module API,
-- sample interpolates keys with the clip's easing (loops wrap, one-shots clamp), transform matches the Pose maths and
-- build makes one KeyframeSequence per clip on the real rig. The spec maps every phase to a clip its data module has,
-- and the client player uses the spec, Kit.transform and the Animator for published ids. Changes nothing (built
-- sequences and probe models are destroyed).
return function(Kit, prefab, Clips, Spec, allClips, clientSource)
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
	local function cubic(a)
		if a < 0.5 then return 4 * a * a * a end
		return 1 - (-2 * a + 2) ^ 3 / 2
	end

	local DATA = {
		ORDER = { "Sway", "Hop", "Spin" },
		CLIPS = {
			Sway = { length = 2, loop = true, priority = "Idle", keys = {
				{ t = 0, pose = {} },
				{ t = 1, pose = { Body = { 0, 1, 0, 0, 20, 0 } } },
				{ t = 2, pose = {} },
			} },
			Hop = { length = 1, loop = false, priority = "Action", keys = {
				{ t = 0, pose = { Body = { 0, 0, 0, 0, 0, 0 } } },
				{ t = 0.5, pose = { Body = { 0, 2, 0, 10, 0, 0 }, Head = { 0, 0, 0, 0, 0, 30 } } },
				{ t = 1, pose = { Body = { 0, 0.5, 0, 0, 0, 0 } } },
			} },
			Spin = { length = 1, loop = true, priority = "Movement", easing = "Linear", keys = {
				{ t = 0, pose = { Body = { 0, 0, 0, 0, 0, 0 } } },
				{ t = 0.75, pose = { Body = { 0, 0, 0, 0, 270, 0 } } },
			} },
		},
	}

	case("CK1: define keeps the clip-module API and the ORDER", function()
		local clips = Kit.define(DATA)
		equal(#clips.ORDER, 3, "order")
		equal(clips.ORDER[1], "Sway")
		equal(clips.ORDER[3], "Spin")
		equal(clips.CLIPS.Hop, DATA.CLIPS.Hop, "clips table")
		equal(type(clips.IDS), "table", "IDS")
		equal(next(clips.IDS), nil, "IDS empty")
		equal(type(clips.build), "function", "build")
		assert(not pcall(clips.animationId, "Sway"), "animationId must error without an id")
		clips.IDS.Sway = 123456789012
		equal(clips.animationId("Sway"), "rbxassetid://123456789012")
		assert(not pcall(Kit.define, { ORDER = { "Nope" }, CLIPS = {} }), "a missing ORDER clip must error")
		assert(not pcall(Kit.define, { ORDER = { "X" }, CLIPS = { X = { length = 1, loop = false, priority = "Loud", keys = {} } } }),
			"an unknown priority must error")
		equal(Kit.PRIORITY.Movement, Enum.AnimationPriority.Movement)
	end)

	case("CK2: sample returns the key pose exactly at each key", function()
		local hop = DATA.CLIPS.Hop
		local at = Kit.sample(hop, 0.5)
		near(at.Body[2], 2, 1e-9, "Body y at 0.5")
		near(at.Body[4], 10, 1e-9, "Body rx at 0.5")
		near(at.Head[6], 30, 1e-9, "Head rz at 0.5")
		local start = Kit.sample(hop, 0)
		near(start.Body[2], 0, 1e-9, "Body y at 0")
		local sway = Kit.sample(DATA.CLIPS.Sway, 1)
		near(sway.Body[5], 20, 1e-9, "Sway ry at 1")
	end)

	case("CK3: between keys, cubic in-out by default and linear when asked", function()
		local hop = Kit.sample(DATA.CLIPS.Hop, 0.125) -- alpha 0.25 of 0..0.5
		near(hop.Body[2], 2 * cubic(0.25), 1e-9, "cubic Body y")
		near(hop.Head[6], 30 * cubic(0.25), 1e-9, "a bone missing in the first key eases from rest")
		local late = Kit.sample(DATA.CLIPS.Hop, 0.75) -- alpha 0.5 of 0.5..1, Head missing in the last key
		near(late.Body[2], 2 + (0.5 - 2) * cubic(0.5), 1e-9, "cubic second half")
		near(late.Head[6], 30 * (1 - cubic(0.5)), 1e-9, "a bone missing in the second key eases to rest")
		local spin = Kit.sample(DATA.CLIPS.Spin, 0.25)
		near(spin.Body[5], 90, 1e-9, "linear ry")
		near(Kit.ease(DATA.CLIPS.Spin, 0.3), 0.3, 1e-12, "linear ease")
		near(Kit.ease(DATA.CLIPS.Hop, 0.3), cubic(0.3), 1e-12, "cubic ease")
	end)

	case("CK4: loops wrap (also from a last key before the length), one-shots clamp", function()
		local a = Kit.sample(DATA.CLIPS.Sway, 0.4)
		local b = Kit.sample(DATA.CLIPS.Sway, 2.4)
		local c = Kit.sample(DATA.CLIPS.Sway, 6.4)
		near(b.Body[2], a.Body[2], 1e-9, "one period later")
		near(c.Body[5], a.Body[5], 1e-9, "three periods later")
		-- Spin's last key is at 0.75 of 1: 0.75..1 eases back to the first key (linear)
		local wrap = Kit.sample(DATA.CLIPS.Spin, 0.875)
		near(wrap.Body[5], 135, 1e-9, "wrap segment, halfway from 270 back to 0")
		near(Kit.sample(DATA.CLIPS.Spin, 1.25).Body[5], 90, 1e-9, "loop wrap on a linear clip")
		local after = Kit.sample(DATA.CLIPS.Hop, 5)
		near(after.Body[2], 0.5, 1e-9, "one-shot holds its last key")
		local before = Kit.sample(DATA.CLIPS.Hop, -1)
		near(before.Body[2], 0, 1e-9, "one-shot clamps below 0")
		near(Kit.localTime(DATA.CLIPS.Sway, -0.5), 1.5, 1e-9, "negative loop time wraps")
	end)

	case("CK5: a reused out table sends untouched bones back to rest", function()
		local out = Kit.sample(DATA.CLIPS.Hop, 0.5)
		near(out.Head[6], 30, 1e-9, "Head posed")
		Kit.sample(DATA.CLIPS.Sway, 1, out)
		near(out.Head[6], 0, 1e-9, "Head back to rest")
		near(out.Body[5], 20, 1e-9, "Body from the new clip")
	end)

	case("CK6: transform round trip: rest * T * rest:Inverse() gives back the model-axes offset", function()
		local rest = CFrame.Angles(math.rad(30), math.rad(-50), math.rad(10))
		local v = { 0.3, -0.2, 0.5, 15, -25, 40 }
		local back = rest * Kit.transform(rest, v) * rest:Inverse()
		local want = CFrame.new(v[1], v[2], v[3]) * CFrame.Angles(math.rad(v[4]), math.rad(v[5]), math.rad(v[6]))
		local px, py, pz = back:ToObjectSpace(want):ToEulerAnglesXYZ()
		near((back.Position - want.Position).Magnitude, 0, 1e-5, "position")
		near(math.abs(px) + math.abs(py) + math.abs(pz), 0, 1e-5, "rotation")
		equal(Kit.transform(rest, { 0, 0, 0, 0, 0, 0 }):FuzzyEq(CFrame.identity, 1e-6), true, "zero is identity")
		equal(Kit.transform(CFrame.identity, {}):FuzzyEq(CFrame.identity, 1e-6), true, "missing values count as 0")
	end)

	local function bonesOf(model)
		local list = {}
		for _, d in ipairs(model.PrimaryPart:GetDescendants()) do
			if d:IsA("Bone") then table.insert(list, d) end
		end
		return list
	end
	local function countPoses(keyframe)
		local n = 0
		for _, d in ipairs(keyframe:GetDescendants()) do
			if d:IsA("Pose") then n += 1 end
		end
		return n
	end

	case("CK7: build on the real rig: keys, poses = 1 + bones, priority, loop, round trip", function()
		local bones = bonesOf(prefab)
		assert(#bones > 0, "the prefab has bones")
		local pick = bones[math.min(2, #bones)]
		local data = { ORDER = { "Probe" }, CLIPS = { Probe = { length = 1, loop = true, priority = "Movement", keys = {
			{ t = 0, pose = {} },
			{ t = 0.5, pose = { [pick.Name] = { 0.2, 0.1, -0.3, 10, 20, -15 } } },
			{ t = 1, pose = {} },
		} } } }
		local seq = Kit.define(data).build(prefab, "Probe")
		local ok, problem = pcall(function()
			equal(seq.ClassName, "KeyframeSequence")
			equal(seq.Name, "Probe")
			equal(seq.Loop, true, "loop")
			equal(seq.Priority, Enum.AnimationPriority.Movement, "priority")
			local frames = seq:GetKeyframes()
			equal(#frames, 3, "keyframes")
			table.sort(frames, function(a, b) return a.Time < b.Time end)
			equal(countPoses(frames[2]), 1 + #bones, "poses")
			local pose = frames[2]:FindFirstChild(pick.Name, true)
			assert(pose, "pose for " .. pick.Name)
			equal(pose.EasingStyle, Enum.PoseEasingStyle.Cubic, "default easing")
			equal(pose.EasingDirection, Enum.PoseEasingDirection.InOut, "default direction")
			local rest = prefab:GetPivot():ToObjectSpace(pick.WorldCFrame).Rotation
			local back = rest * pose.CFrame * rest:Inverse()
			near((back.Position - Vector3.new(0.2, 0.1, -0.3)).Magnitude, 0, 1e-4, "round trip offset")
			local want = CFrame.Angles(math.rad(10), math.rad(20), math.rad(-15))
			local rx, ry, rz = back.Rotation:ToObjectSpace(want):ToEulerAnglesXYZ()
			near(math.abs(rx) + math.abs(ry) + math.abs(rz), 0, 1e-4, "round trip rotation")
			assert(not pcall(Kit.define(data).build, prefab, "Missing"), "an unknown clip errors")
		end)
		seq:Destroy()
		assert(ok, problem)
	end)

	case("CK8: the generated Clips build every clip: keyframes = keys, poses = 1 + bones, Linear where asked", function()
		assert(Clips, "pass the Canelin clips module")
		local bones = #bonesOf(prefab)
		local linearSeen = false
		for _, name in ipairs(Clips.ORDER) do
			local clip = Clips.CLIPS[name]
			local seq = Clips.build(prefab, name)
			local ok, problem = pcall(function()
				local frames = seq:GetKeyframes()
				equal(#frames, #clip.keys, name .. " keyframes")
				equal(countPoses(frames[1]), 1 + bones, name .. " poses")
				equal(seq.Loop, clip.loop, name .. " loop")
				equal(seq.Priority, Kit.PRIORITY[clip.priority], name .. " priority")
				local style = clip.easing == "Linear" and Enum.PoseEasingStyle.Linear or Enum.PoseEasingStyle.Cubic
				for _, d in ipairs(seq:GetDescendants()) do
					if d:IsA("Pose") and d.Parent:IsA("Pose") then
						equal(d.EasingStyle, style, name .. " easing of " .. d.Name)
					end
				end
				if clip.easing == "Linear" then linearSeen = true end
			end)
			seq:Destroy()
			assert(ok, problem)
		end
		equal(linearSeen, true, "Canelin has Linear clips (Spin, Charge)")
	end)

	local NAMES = { "DuquesaBurbuja", "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }

	case("CK9: the spec names only clips each data module has, and covers every brain phase", function()
		assert(Spec and allClips, "pass the spec and the six clips modules")
		local count = 0
		for _ in pairs(Spec.SPEC) do count += 1 end
		equal(count, #NAMES, "six critters in the spec")
		for _, name in ipairs(NAMES) do
			local spec, data = Spec.SPEC[name], allClips[name]
			assert(spec, "spec for " .. name)
			assert(data and data.CLIPS, "clips module for " .. name)
			assert(data.CLIPS[spec.idle], name .. ": idle clip " .. tostring(spec.idle))
			equal(data.CLIPS[spec.idle].loop, true, name .. ": idle loops")
			for _, extra in ipairs(spec.extras) do assert(data.CLIPS[extra], name .. ": extra clip " .. extra) end
			for phase, clip in pairs(spec.phase) do
				assert(data.CLIPS[clip], name .. ": phase " .. phase .. " -> missing clip " .. tostring(clip))
			end
			for _, phase in ipairs(Spec.BRAIN_PHASES) do
				assert(spec.phase[phase], name .. ": brain phase " .. phase .. " is not mapped")
				equal(Spec.clipFor(name, phase, data.CLIPS), spec.phase[phase], name .. " " .. phase)
			end
		end
	end)

	case("CK10: clipFor falls back to idle; publishedId only takes a non-empty string Clip_ attribute", function()
		assert(Spec and allClips, "pass the spec and the six clips modules")
		local clips = allClips.Mielita.CLIPS
		equal(Spec.clipFor("Mielita", "NoSuchPhase", clips), "Fly", "unknown phase")
		equal(Spec.clipFor("Mielita", nil, clips), "Fly", "no phase")
		equal(Spec.clipFor("Mielita", "Telegraph", clips), "Pollen", "mapped phase")
		equal(Spec.clipFor("Mielita", "Telegraph", { Fly = clips.Fly }), "Fly", "a mapped clip the data lacks")
		local probe = Instance.new("Model")
		local ok, problem = pcall(function()
			probe.Name = "Mochimiau"
			equal(Spec.critterName(probe), "Mochimiau", "by name")
			probe:SetAttribute("WildboundCritter", "Flanin")
			equal(Spec.critterName(probe), "Flanin", "by attribute")
			probe.Name = "Rock"
			probe:SetAttribute("WildboundCritter", nil)
			equal(Spec.critterName(probe), nil, "none of the six")
			equal(Spec.publishedId(probe, "Idle"), nil, "no attribute")
			probe:SetAttribute("Clip_Idle", "")
			equal(Spec.publishedId(probe, "Idle"), nil, "empty string")
			probe:SetAttribute("Clip_Idle", 123)
			equal(Spec.publishedId(probe, "Idle"), nil, "a number is not an id")
			probe:SetAttribute("Clip_Idle", "rbxassetid://123")
			equal(Spec.publishedId(probe, "Idle"), "rbxassetid://123", "string id")
		end)
		probe:Destroy()
		assert(ok, problem)
	end)

	case("CK11: the client player uses the spec, Kit.transform and plays published ids on the Animator", function()
		assert(type(clientSource) == "string", "pass the client source")
		local function has(text, label)
			assert(string.find(clientSource, text, 1, true), "client must contain " .. label .. " (" .. text .. ")")
		end
		has('WaitForChild("WildboundCandyCritterAnimSpec")', "the spec require")
		has("Spec.clipFor(", "the phase resolution from the spec")
		has("Kit.transform(item.rest, v, item.restInv)", "the shared transform")
		assert(not string.find(clientSource, "CFrame.Angles", 1, true), "no inline transform copy in the client")
		assert(not string.find(clientSource, "local SPEC", 1, true), "no local copy of the spec")
		has("Spec.publishedId(", "the Clip_ rule from the spec")
		has(":LoadAnimation(", "loading the published Animation")
		has("track:Play(FADE)", "playing it")
		has("stopTrack(state", "stopping it on clip change and drop")
		has("resetBones(state)", "resetting bones")
	end)

	return result
end
