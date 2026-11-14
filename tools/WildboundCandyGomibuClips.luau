-- Gomibu's clips (odd/tasks/caramelo-bioma.md, T3; pack 03_PERSONAJES/01_GOMIBU.md). Ten animations as data, turned
-- into KeyframeSequences for the prefab's bones by Clips.build. Roblox animations cannot scale, so the gummy squash and
-- stretch is made by moving bones: the skin between them compresses or pulls.
-- A key is { time, pose }; a pose maps a bone to { dx, dy, dz, pitch, yaw, roll } in MODEL axes (studs and degrees;
-- X is the character's right, Y up, -Z forward), relative to its parent's motion. Missing bones rest.
-- Everything is in place: Root only goes up (the jump); on the ground the legs take back what the pelvis moves, so the
-- feet never slide. Markers follow the art standard; the server times the attack by itself and never trusts them.
-- Rules: WildboundCandyGomibuClips_Test.
local Clips = {}

local function merge(...)
	local out = {}
	for _, pose in ipairs({ ... }) do
		for bone, v in pairs(pose) do
			local sum = out[bone] or { 0, 0, 0, 0, 0, 0 }
			for i = 1, 6 do sum[i] += v[i] or 0 end
			out[bone] = sum
		end
	end
	return out
end
-- Pressed down and wider: pelvis and head sink, the legs give the height back, arms and ears spread.
local function squash(a)
	return { Pelvis = { 0, -0.45 * a, 0 }, Leg_L = { 0, 0.45 * a, 0 }, Leg_R = { 0, 0.45 * a, 0 }, SpineGel = { 0, -0.2 * a, 0 },
		Head = { 0, -0.35 * a, 0 }, Arm_L = { -0.25 * a, 0, 0 }, Arm_R = { 0.25 * a, 0, 0 },
		Ear_L = { -0.15 * a, 0, 0, 0, 0, 12 * a }, Ear_R = { 0.15 * a, 0, 0, 0, 0, -12 * a } }
end
-- Pulled tall and thin, feet still planted.
local function stretch(a)
	return { Pelvis = { 0, 0.3 * a, 0 }, Leg_L = { 0, -0.3 * a, 0 }, Leg_R = { 0, -0.3 * a, 0 }, SpineGel = { 0, 0.2 * a, 0 },
		Head = { 0, 0.3 * a, 0 }, Arm_L = { 0.12 * a, 0, 0 }, Arm_R = { -0.12 * a, 0, 0 } }
end
local function air(height) return { Root = { 0, height, 0 } } end
local function arms(degrees) return { Arm_L = { 0, 0, 0, 0, 0, -degrees }, Arm_R = { 0, 0, 0, 0, 0, degrees } } end
local function look(yaw, pitch) return { Head = { 0, 0, 0, pitch or 0, yaw, 0 } } end
local REST = {}

Clips.ORDER = { "Idle", "Bounce_Move", "Turn", "Alert", "Attack_Telegraph", "Attack_Release", "Attack_Recover", "HitReact", "FarmIdle", "HatchReact" }
Clips.CLIPS = {
	-- breathing at about 0.8 Hz, ears taking turns
	Idle = { length = 2.4, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, REST }, { 0.6, merge(squash(0.25), { Ear_L = { 0, 0, 0, 0, 0, 8 } }) }, { 1.2, REST },
		{ 1.8, merge(squash(0.25), { Ear_R = { 0, 0, 0, 0, 0, -8 } }) }, { 2.4, REST } } },
	-- one micro bounce: press, spring, fly, land, settle
	Bounce_Move = { length = 0.9, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, REST }, { 0.2, squash(0.9) }, { 0.32, merge(stretch(1.4), air(0.5)) }, { 0.52, merge(stretch(0.5), air(1.6), arms(25)) },
		{ 0.72, merge(stretch(1.0), air(0.25)) }, { 0.8, squash(0.75) }, { 0.9, REST } } },
	Turn = { length = 0.5, loop = false, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, REST }, { 0.15, merge(squash(0.4), look(-15)) }, { 0.35, merge(stretch(0.4), look(25), { SpineGel = { 0, 0, 0, 0, 15, 0 } }) }, { 0.5, REST } } },
	Alert = { length = 0.7, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.15, squash(0.5) }, { 0.3, merge(stretch(1.0), air(0.7), arms(40), { Ear_L = { 0, 0.1, 0, 0, 0, -10 }, Ear_R = { 0, 0.1, 0, 0, 0, 10 } }) },
		{ 0.5, squash(0.4) }, { 0.7, REST } } },
	-- Golpe de Goma, part 1: a long press that only goes deeper; the ears swell at the end
	Attack_Telegraph = { length = 0.9, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "TelegraphStart" }, { 0.55, "AttackCommit" } }, keys = {
		{ 0, REST }, { 0.25, squash(0.6) }, { 0.55, squash(1.1) }, { 0.9, merge(squash(1.4), { Ear_L = { 0, 0.2, 0 }, Ear_R = { 0, 0.2, 0 } }) } } },
	-- part 2: the short arc and the slam
	Attack_Release = { length = 0.45, loop = false, priority = Enum.AnimationPriority.Action, markers = { { 0.45, "HitFrame" } }, keys = {
		{ 0, merge(squash(1.4), { Ear_L = { 0, 0.2, 0 }, Ear_R = { 0, 0.2, 0 } }) }, { 0.1, merge(stretch(1.5), air(1.0)) },
		{ 0.25, merge(stretch(0.6), air(3.0), arms(70)) }, { 0.4, merge(stretch(1.2), air(0.4)) }, { 0.45, squash(1.5) } } },
	-- part 3: the jelly swings twice and settles
	Attack_Recover = { length = 0.7, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "RecoverStart" }, { 0.7, "AttackEnd" } }, keys = {
		{ 0, squash(1.5) }, { 0.15, stretch(0.9) }, { 0.3, squash(0.6) }, { 0.45, stretch(0.4) }, { 0.58, squash(0.2) }, { 0.7, REST } } },
	HitReact = { length = 0.45, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.1, merge(squash(0.3), { Head = { 0.5, 0, 0, 0, 0, -18 }, SpineGel = { 0.15, 0, 0, 0, 0, -10 } }) },
		{ 0.25, { Head = { -0.25, 0, 0, 0, 0, 9 }, SpineGel = { -0.08, 0, 0, 0, 0, 5 } } }, { 0.45, REST } } },
	-- the pet at the farm: slow soft bounces and a wave, nothing that reads as a strike
	FarmIdle = { length = 3.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, REST }, { 0.5, squash(0.3) }, { 1.0, merge(stretch(0.5), air(0.4)) }, { 1.3, squash(0.25) }, { 1.6, REST },
		{ 1.9, { Arm_R = { 0, 0, 0, 0, 0, 115 }, Head = { 0, 0, 0, 0, 0, 6 } } }, { 2.2, { Arm_R = { 0, 0, 0, 0, 0, 85 }, Head = { 0, 0, 0, 0, 0, 6 } } },
		{ 2.5, { Arm_R = { 0, 0, 0, 0, 0, 115 }, Head = { 0, 0, 0, 0, 0, 6 } } }, { 3.0, REST } } },
	-- out of the egg: curled up, one bounce, a look to each side
	HatchReact = { length = 2.0, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, merge(squash(1.2), look(0, -20)) }, { 0.4, merge(stretch(1.2), air(2.0), arms(60)) }, { 0.7, squash(0.7) }, { 0.9, REST },
		{ 1.2, look(-40) }, { 1.6, look(40) }, { 2.0, REST } } },
}

-- Published copies (Animation assets of the group, uploaded from caramelo/gomibu/clips/*.rbxmx in the local repo).
-- A clip changed here must be exported and uploaded again: the game plays these ids, not the data above.
Clips.IDS = {
	Idle = 130587958094065,
	Bounce_Move = 108794101959381,
	Turn = 85153558577544,
	Alert = 110814729835093,
	Attack_Telegraph = 89115956400925,
	Attack_Release = 104997163073400,
	Attack_Recover = 132923991579412,
	HitReact = 125091864220996,
	FarmIdle = 135673668651279,
	HatchReact = 130256310567093,
}

-- The content id an Animation instance needs to play a clip in the game.
function Clips.animationId(name)
	local id = Clips.IDS[name]
	assert(id, "no published clip named " .. tostring(name))
	return "rbxassetid://" .. string.format("%d", id)
end

-- The KeyframeSequence of one clip for the given prefab (it reads the rest rotation of each bone from it).
function Clips.build(prefab, name)
	local clip = Clips.CLIPS[name]
	assert(clip, "no clip named " .. tostring(name))
	local root = prefab.PrimaryPart
	local pivot = prefab:GetPivot()
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = clip.loop
	sequence.Priority = clip.priority
	local function addPoses(parentPose, instance, pose)
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("Bone") then
				local item = Instance.new("Pose")
				item.Name = child.Name
				item.EasingStyle = Enum.PoseEasingStyle.Cubic
				item.EasingDirection = Enum.PoseEasingDirection.InOut
				local v = pose[child.Name]
				if v then
					-- the data is in model axes; a pose is in the bone's own rest axes
					local rest = pivot:ToObjectSpace(child.WorldCFrame).Rotation
					item.CFrame = rest:Inverse() * (CFrame.new(v[1] or 0, v[2] or 0, v[3] or 0)
						* CFrame.Angles(math.rad(v[4] or 0), math.rad(v[5] or 0), math.rad(v[6] or 0))) * rest
				end
				item.Parent = parentPose
				addPoses(item, child, pose)
			end
		end
	end
	for _, key in ipairs(clip.keys) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key[1]
		local base = Instance.new("Pose")
		base.Name = root.Name
		base.Weight = 0
		base.Parent = keyframe
		addPoses(base, root, key[2])
		for _, marker in ipairs(clip.markers or {}) do
			if math.abs(marker[1] - key[1]) < 1e-9 then
				local item = Instance.new("KeyframeMarker")
				item.Name = marker[2]
				item.Parent = keyframe
			end
		end
		keyframe.Parent = sequence
	end
	return sequence
end

return Clips
