-- Don Glaseon's clips (odd/tasks/wildbound-caramelo.md, CA3; pack 03_PERSONAJES/04_DON_GLASEON_BOSS.md, "Animaciones").
-- Eleven animations as data, turned into KeyframeSequences for the prefab's bones by Clips.build.
-- A key is { time, pose }; a pose maps a bone to { dx, dy, dz, pitch, yaw, roll } in MODEL axes (studs and degrees;
-- X is the character's right, Y up, -Z forward), relative to its parent's motion. Missing bones rest. A positive
-- pitch lifts what points forward and swings what hangs down forward (a leg's foot, an arm's hand); a positive roll
-- swings what hangs down toward +X (the right arm outward, the left arm inward).
-- Everything is in place: Root never moves (no root motion), the body bobs on the Pelvis and the thighs take the bob
-- back, so the feet stay on the ground. Heavy two-legged steps; the licorice whip is the right arm (Latigo de Regaliz),
-- its long lash a client ribbon. Markers follow the art standard; the server times the attack by itself.
-- Rules: WildboundCandyDonGlaseonClips_Test.
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
-- The body up (+) or down (-), leaning (pitch: - forward) and rocking (roll); the thighs take the height back.
local function body(dy, lean, roll)
	return { Pelvis = { 0, dy, 0, 0, 0, roll or 0 }, Spine_Lower = { 0, 0, 0, lean or 0 }, Thigh_L = { 0, -dy, 0 }, Thigh_R = { 0, -dy, 0 } }
end
-- The legs: thigh swings in degrees (+ the foot forward); the shin bends back by `bend` on the leg moving forward.
local function legs(l, r, bend)
	bend = bend or 0
	return { Thigh_L = { 0, 0, 0, l }, Thigh_R = { 0, 0, 0, r }, Shin_L = { 0, 0, 0, l > 0 and -bend or 0 },
		Shin_R = { 0, 0, 0, r > 0 and -bend or 0 }, Foot_L = { 0, 0, 0, l > 0 and bend * 0.5 or 0 }, Foot_R = { 0, 0, 0, r > 0 and bend * 0.5 or 0 } }
end
-- The arms swing (pitch, + forward) and open (spread, + away from the body), the claws curl by `curl`.
local function arms(l, r, spread, curl)
	spread, curl = spread or 0, curl or 0
	return { UpperArm_L = { 0, 0, 0, l, 0, -spread }, UpperArm_R = { 0, 0, 0, r, 0, spread }, Finger_L1 = { 0, 0, 0, -curl },
		Finger_L2 = { 0, 0, 0, -curl }, Finger_R1 = { 0, 0, 0, -curl }, Finger_R2 = { 0, 0, 0, -curl } }
end
local function head(pitch, yaw, roll) return { Neck = { 0, 0, 0, (pitch or 0) * 0.4, (yaw or 0) * 0.4, 0 },
	Head = { 0, 0, 0, (pitch or 0) * 0.6, (yaw or 0) * 0.6, roll or 0 } } end
-- The jaw open by `degrees` (it drops: a negative pitch).
local function jaw(degrees) return { Jaw = { 0, 0, 0, -degrees, 0, 0 } } end
local function breath(a) return { Spine_Upper = { 0, 0.12 * a, 0, 2 * a }, Shoulder_L = { 0, 0.08 * a, 0 }, Shoulder_R = { 0, 0.08 * a, 0 } } end
local function candies(roll, bob) return { CandyCrown = { 0, bob or 0, 0, 0, 0, roll } } end
-- The licorice links: `whip` straightens them forward along the arm (0 = coiled at rest).
local function licorice(whip, sway)
	sway = sway or 0
	return { Licorice_01 = { 0, 0, 0, whip * 0.5, 0, sway }, Licorice_02 = { 0, 0, 0, whip * 0.3, 0, sway }, Licorice_03 = { 0, 0, 0, whip * 0.2, 0, sway } }
end
local REST = {}
-- Latigo de Regaliz: the right arm high and back with the whip cocked, the jaw wide, the body twisted (the tell) ...
local RAISED = merge({ Shoulder_R = { 0, 0.4, 0, 0, 0, 10 }, UpperArm_R = { 0, 0, 0, 150, 0, 15 }, Forearm_R = { 0, 0, 0, 40 },
	Spine_Upper = { 0, 0, 0, 4, -14, 0 } }, licorice(-40, 10), jaw(30), head(10, -8), body(-0.3, 0, -3), legs(10, -8), arms(-10, 0, 10, 20))
-- ... then thrown forward: the arm and the licorice straight out in front, the body leaning into it.
local LASH = merge({ Shoulder_R = { 0, -0.2, -0.4 }, UpperArm_R = { 0, 0, 0, 85, 0, -4 }, Forearm_R = { 0, 0, 0, 10 },
	Spine_Upper = { 0, 0, 0, -8, 12, 0 } }, licorice(90), jaw(18), head(-6, 6), body(-0.5, -10, 2), legs(14, -10), arms(-15, 0, 12, 10))

Clips.ORDER = { "Idle_Breath", "Patrol_Walk", "Chase_Run", "Notice", "Search", "Attack_Telegraph_Licorice",
	"Attack_Release_Licorice", "Attack_Recover_Licorice", "HitReact_ImmuneBat", "LoseTarget", "Roar_Visual" }
Clips.CLIPS = {
	-- weight and layered breathing: the chest rises, the shoulders follow, the jaw hangs open a little
	Idle_Breath = { length = 3.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, REST }, { 1.0, merge(breath(1), jaw(4), arms(2, 2, 2, 4)) }, { 1.6, merge(breath(1.1), jaw(6), candies(2)) },
		{ 2.4, merge(breath(0.3), jaw(2), candies(-1)) }, { 3.0, REST } } },
	-- heavy steps: the body drops on each landing and rocks over the planted leg; the arms swing a little
	Patrol_Walk = { length = 1.1, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, merge(legs(18, -18, 25), body(-0.35, -3, 3), arms(-8, 8)) },
		{ 0.275, merge(legs(0, 0), body(0.15, -2, 0), candies(2, 0.05)) },
		{ 0.55, merge(legs(-18, 18, 25), body(-0.35, -3, -3), arms(8, -8)) },
		{ 0.825, merge(legs(0, 0), body(0.15, -2, 0), candies(-2, 0.05)) },
		{ 1.1, merge(legs(18, -18, 25), body(-0.35, -3, 3), arms(-8, 8)) } } },
	-- violent steps, the torso bent forward, the arms pumping, the jaw open
	Chase_Run = { length = 0.75, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, merge(legs(30, -26, 40), body(-0.5, -16, 4), arms(-25, 25, 8, 15), jaw(14), head(10)) },
		{ 0.1875, merge(legs(0, 0), body(0.4, -14, 0), arms(0, 0, 8, 15), jaw(10), head(8), candies(4, 0.1)) },
		{ 0.375, merge(legs(-26, 30, 40), body(-0.5, -16, -4), arms(25, -25, 8, 15), jaw(14), head(10)) },
		{ 0.5625, merge(legs(0, 0), body(0.4, -14, 0), arms(0, 0, 8, 15), jaw(10), head(8), candies(-4, 0.1)) },
		{ 0.75, merge(legs(30, -26, 40), body(-0.5, -16, 4), arms(-25, 25, 8, 15), jaw(14), head(10)) } } },
	-- it lifts its head and opens its eyes: the head snaps up and holds
	Notice = { length = 0.8, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.2, merge(head(18), jaw(10), breath(1), candies(5, 0.15)) }, { 0.5, merge(head(14, 6), jaw(6), candies(-3)) },
		{ 0.8, merge(head(12), jaw(5)) } } },
	-- looks around without turning the whole body
	Search = { length = 1.6, loop = true, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, merge(head(4)) }, { 0.4, merge(head(4, 40), { Spine_Upper = { 0, 0, 0, 0, 10, 0 } }) },
		{ 0.8, merge(head(0)) }, { 1.2, merge(head(4, -40), { Spine_Upper = { 0, 0, 0, 0, -10, 0 } }) }, { 1.6, merge(head(4)) } } },
	-- Latigo de Regaliz, part 1: the asymmetric wind-up; only ever deeper, frozen from the lock (0.6 s)
	Attack_Telegraph_Licorice = { length = 1.1, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "TelegraphStart" }, { 0.6, "AttackCommit" } }, keys = {
		{ 0, REST }, { 0.3, merge({ UpperArm_R = { 0, 0, 0, 70, 0, 10 }, Forearm_R = { 0, 0, 0, 20 } }, jaw(14), head(6), licorice(-15)) },
		{ 0.6, merge(RAISED, jaw(-4)) }, { 1.1, RAISED } } },
	-- part 2: the lash (0.35 s)
	Attack_Release_Licorice = { length = 0.35, loop = false, priority = Enum.AnimationPriority.Action, markers = { { 0.35, "HitFrame" } }, keys = {
		{ 0, RAISED }, { 0.15, merge(LASH, { UpperArm_R = { 0, 0, 0, 20 } }) }, { 0.35, LASH } } },
	-- part 3: the whip comes back to the arm, the jaw half closes; exposed
	Attack_Recover_Licorice = { length = 1.0, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "RecoverStart" }, { 1.0, "AttackEnd" } }, keys = {
		{ 0, LASH }, { 0.35, merge({ UpperArm_R = { 0, 0, 0, 40 }, Forearm_R = { 0, 0, 0, 20 } }, licorice(30, -10), jaw(10), body(-0.2, -6), breath(1)) },
		{ 0.7, merge({ UpperArm_R = { 0, 0, 0, 12 } }, licorice(5), jaw(6), breath(1)) }, { 1.0, REST } } },
	-- the bat bounces off: a small wobble, no stun
	HitReact_ImmuneBat = { length = 0.35, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.1, merge({ Spine_Upper = { 0, 0, 0, 3, 0, 6 } }, head(0, 10), candies(6)) },
		{ 0.22, merge({ Spine_Upper = { 0, 0, 0, 0, 0, -3 } }, head(0, -4), candies(-4)) }, { 0.35, REST } } },
	-- it stops and looks toward the exit
	LoseTarget = { length = 1.0, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.3, merge(head(-4, 30), body(-0.1, 0)) }, { 0.7, merge(head(-6, 55), arms(0, 0, -4), jaw(-2)) },
		{ 1.0, merge(head(-4, 50), arms(0, 0, -4)) } } },
	-- the roar when it appears: chest up, arms wide, the jaw at its widest; no damage, no second ability
	Roar_Visual = { length = 1.5, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.3, merge(body(-0.4, -8), arms(-10, -10, 5, 10), head(-8), jaw(8)) },
		{ 0.6, merge(body(0.2, 8), breath(1.5), arms(20, 20, 45, 25), head(22), jaw(38), candies(6, 0.2)) },
		{ 0.9, merge(body(0.2, 8), breath(1.5), arms(22, 22, 48, 25), head(24, 6), jaw(40), candies(-6, 0.2)) },
		{ 1.2, merge(body(0.1, 4), breath(1), arms(10, 10, 25, 10), head(14, -6), jaw(30), candies(4)) }, { 1.5, REST } } },
}

-- Published copies (Animation assets uploaded from the KeyframeSequences Clips.build makes in Studio). A clip changed
-- here must be exported and uploaded again: the game plays these ids. Empty until the clips are published to the
-- group that owns the universe (odd/tasks/wildbound-caramelo.md, CA2/CA3 blocker).
Clips.IDS = {}

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
