-- Flanfuria's clips (odd/tasks/caramelo-bioma.md, T4; pack 03_PERSONAJES/02_FLANFURIA.md). Ten animations as data,
-- turned into KeyframeSequences for the prefab's bones by Clips.build. Roblox animations cannot scale, so the flan's
-- squash and stretch is FlanJiggle sinking towards FlanBase or rising from it: the skin between them does the rest.
-- A key is { time, pose }; a pose maps a bone to { dx, dy, dz, pitch, yaw, roll } in MODEL axes (studs and degrees;
-- X is the character's right, Y up, -Z forward), relative to its parent's motion. Missing bones rest.
-- Everything is in place: Root only goes up (the hop) and FlanBase never moves, so the wide flat base stays flat.
-- The kitten is late: CatRoot takes back part of what the flan does and gives it a key later (the lag helper), so it
-- nods after the flan lands. Markers follow the art standard; the server times the attack by itself.
-- Rules: WildboundCandyFlanfuriaClips_Test.
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
-- The flan pressed down: its upper mass sinks and the caramel cap settles into it.
local function squash(a) return { FlanJiggle = { 0, -0.9 * a, 0 }, CaramelTop = { 0, -0.15 * a, 0 } } end
-- The flan pulled tall.
local function stretch(a) return { FlanJiggle = { 0, 0.6 * a, 0 }, CaramelTop = { 0, 0.1 * a, 0 } } end
local function air(height) return { Root = { 0, height, 0 } } end
-- The kitten out of step with the flan: studs above (+) or below (-) where the flan would carry it, and a nod.
local function lag(studs, nod) return { CatRoot = { 0, studs, 0, nod or 0, 0, 0 } } end
local function look(yaw, pitch) return { CatHead = { 0, 0, 0, pitch or 0, yaw, 0 } } end
local function ears(degrees) return { CatEar_L = { 0, 0, 0, 0, 0, degrees }, CatEar_R = { 0, 0, 0, 0, 0, -degrees } } end
local function tail(yaw, lift) return { CatTail_01 = { 0, 0, 0, 0, yaw, 0 }, CatTail_02 = { 0, lift or 0, 0, 0, yaw * 0.6, 0 } } end
local function cherry(hop, tilt) return { Cherry = { 0, hop, 0, 0, 0, tilt or 0 }, CreamPeak = { 0, 0, 0, 0, 0, (tilt or 0) * 0.4 } } end
local function wobble(degrees) return { FlanJiggle = { 0, 0, 0, 0, 0, degrees }, CaramelTop = { 0, 0, 0, 0, 0, degrees * 0.5 } } end
-- The kitten flat on the caramel, paws out: a = 1 is the full crouch of the tell.
local function crouch(a)
	return { CatRoot = { 0, -0.2 * a, 0, 12 * a, 0, 0 }, CatHead = { 0, -0.15 * a, 0, -8 * a, 0, 0 },
		CatPaw_L = { 0, 0, -0.15 * a }, CatPaw_R = { 0, 0, -0.15 * a }, CatEar_L = { 0, 0, 0, 0, 0, -14 * a }, CatEar_R = { 0, 0, 0, 0, 0, 14 * a } }
end
-- Curled up asleep on the cream: head down, tail round the body.
local CURL = merge(crouch(0.6), look(25, 10), tail(-35, -0.1))
-- Holding on: both paws reach up for the cream and the ears go flat.
local GRAB = { CatPaw_L = { 0.1, 0.5, -0.1 }, CatPaw_R = { -0.1, 0.5, -0.1 }, CatEar_L = { 0, 0, 0, 0, 0, -20 }, CatEar_R = { 0, 0, 0, 0, 0, 20 } }
local REST = {}
local PRESSED = merge(squash(1.4), crouch(1))
local SPENT = merge(squash(0.5), crouch(0.3))

Clips.ORDER = { "Idle", "Hop_Move", "Turn", "Alert", "Attack_Telegraph", "Attack_Release", "Attack_Recover", "HitReact", "FarmIdle", "HatchReact" }
Clips.CLIPS = {
	-- a slow tremble; the kitten looks one way, flicks an ear, looks the other
	Idle = { length = 3.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, REST }, { 0.75, merge(squash(0.2), wobble(2), look(20), tail(10)) }, { 1.5, merge(stretch(0.1), { CatEar_L = { 0, 0, 0, 0, 0, 10 } }) },
		{ 2.25, merge(squash(0.2), wobble(-2), look(-20), tail(-10)) }, { 3.0, REST } } },
	-- one heavy hop: press, spring, a low flight, the landing, and the kitten nodding after it
	Hop_Move = { length = 1.1, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, REST }, { 0.25, merge(squash(0.9), lag(0.3)) }, { 0.4, merge(stretch(1.2), air(0.4), lag(-0.25, 6)) },
		{ 0.6, merge(stretch(0.4), air(1.2), lag(0.1), tail(0, 0.3), cherry(0.1)) }, { 0.8, merge(stretch(0.8), air(0.2)) },
		{ 0.9, merge(squash(1.0), lag(0.35), cherry(0.2)) }, { 1.0, merge(stretch(0.25), lag(-0.3, 10), cherry(-0.05)) }, { 1.1, REST } } },
	-- the body turns first, the kitten a little later
	Turn = { length = 0.6, loop = false, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, REST }, { 0.2, merge(squash(0.3), { FlanJiggle = { 0, 0, 0, 0, 20, 0 }, CatRoot = { 0, 0, 0, 0, -20, 0 } }) },
		{ 0.4, merge({ CatRoot = { 0, 0, 0, 0, 15, 0 } }, look(10), tail(-15)) }, { 0.6, REST } } },
	-- ears, cherry and the caramel drip swing
	Alert = { length = 0.8, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.2, merge(stretch(0.3), ears(15), cherry(0.15, 15), wobble(4)) }, { 0.4, merge(ears(-8), cherry(0, -12), wobble(-4)) },
		{ 0.6, merge(ears(8), cherry(0.05, 8), wobble(2)) }, { 0.8, REST } } },
	-- Onda de Caramelo, part 1: the flan flattens and shakes, only ever deeper; the kitten ducks
	Attack_Telegraph = { length = 1.0, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "TelegraphStart" }, { 1.0, "AttackCommit" } }, keys = {
		{ 0, REST }, { 0.25, merge(squash(0.5), crouch(0.4)) }, { 0.5, merge(squash(0.9), crouch(0.7), wobble(3)) },
		{ 0.75, merge(squash(1.2), crouch(1), wobble(-3)) }, { 1.0, PRESSED } } },
	-- part 2: the body springs out as the ring leaves, the kitten thrown up a beat later
	Attack_Release = { length = 0.8, loop = false, priority = Enum.AnimationPriority.Action, markers = { { 0, "HitFrame" } }, keys = {
		{ 0, PRESSED }, { 0.15, merge(stretch(1.3), lag(-0.3)) }, { 0.4, merge(stretch(0.6), lag(0.3), ears(12), cherry(0.25)) }, { 0.8, SPENT } } },
	-- part 3: the flan swings back into shape and the kitten sits up
	Attack_Recover = { length = 0.85, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "RecoverStart" }, { 0.85, "AttackEnd" } }, keys = {
		{ 0, SPENT }, { 0.2, merge(stretch(0.7), lag(-0.15)) }, { 0.4, merge(squash(0.4), lag(0.15)) }, { 0.55, stretch(0.25) },
		{ 0.7, squash(0.1) }, { 0.85, REST } } },
	-- the kitten clings to the cream while the flan rocks
	HitReact = { length = 0.5, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.12, merge(squash(0.3), wobble(-8), GRAB, lag(-0.15)) }, { 0.3, merge(wobble(4), GRAB) }, { 0.5, REST } } },
	-- the pet at the farm: the kitten asleep, the flan breathing; nothing that reads as a strike
	FarmIdle = { length = 4.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, CURL }, { 1, merge(CURL, squash(0.15)) }, { 2, merge(CURL, stretch(0.1), tail(4)) }, { 3, merge(CURL, squash(0.15)) }, { 4, CURL } } },
	-- out of the egg: one bounce, the cherry hopping softly, a look to each side
	HatchReact = { length = 2.0, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, merge(squash(1.2), crouch(0.8)) }, { 0.4, merge(stretch(1.1), air(1.5), lag(-0.2), cherry(0.2)) }, { 0.7, merge(squash(0.7), lag(0.3), cherry(0.5)) },
		{ 1.0, merge(stretch(0.2), lag(-0.2, 8), cherry(0.15)) }, { 1.3, merge(look(-30), cherry(0.3)) }, { 1.7, merge(look(30), tail(12)) }, { 2.0, REST } } },
}

-- Published copies (Animation assets of the group, uploaded from caramelo/flanfuria/clips/*.rbxmx in the local repo).
-- A clip changed here must be exported and uploaded again: the game plays these ids, not the data above.
Clips.IDS = {
	Idle = 120202747796302,
	Hop_Move = 124899981776007,
	Turn = 113950536737953,
	Alert = 121882612543550,
	Attack_Telegraph = 132333586251728,
	Attack_Release = 90469176884468,
	Attack_Recover = 115321389742570,
	HitReact = 99432353222398,
	FarmIdle = 132955540550748,
	HatchReact = 83529503438825,
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
