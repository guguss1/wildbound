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

-- Don Glaseon walk (odd/tasks/wildbound-caramelo-playfix.md): the walking clips are a sampled gait, 16 Linear keys per
-- step cycle. p in [0, 1) is the cycle: 0 = the left heel lands (left thigh fully forward), 0.5 = the right heel lands.
-- The planted leg stays straight and its foot flat while the thigh sweeps back; the swinging leg bends its knee (the
-- foot lifts) and its toes come up; the body drops on each landing (so the stretched leg still reaches the ground) and
-- rocks over the planted leg, the hips and shoulders twist against each other, the arms swing against the legs and the
-- licorice, the crown and the head follow a little late. Cadence: a planted foot travels 2 * HIP * sin(swing) per half
-- cycle, so a cycle covers 4 * HIP * sin(swing) studs; the cycle length is that over his move speed (no sliding).
local HIP = 7 -- the thigh joints over the soles, in studs (the prefab's Thigh_L/Thigh_R)
local KEYS_PER_CYCLE = 16
-- His move speeds (WildboundBeastConfig.BEASTS.DonGlaseon.tuning; the test checks they still match).
Clips.WALK_SPEED, Clips.RUN_SPEED = 9, 21
local TAU = 2 * math.pi
local function cycleLength(speed, swing) return 4 * HIP * math.sin(math.rad(swing)) / speed end
local WALK = { swing = 22, knee = 50, give = 0, toe = 10, drop = 1, bounce = 0, lean = -4, shift = 0.15, twist = 5, sway = 3,
	arm = 14, spread = 4, elbow = 10, curl = 4, look = 0, nod = 1.5, jaw = 3, flap = 0, jiggle = 0.06, crown = 2, lash = 6 }
local RUN = { swing = 32, knee = 80, give = 8, toe = 15, drop = 0.6, bounce = 0.25, lean = -16, shift = 0.2, twist = 8, sway = 4,
	arm = 30, spread = 8, elbow = 25, curl = 15, look = 10, nod = 3, jaw = 12, flap = 4, jiggle = 0.12, crown = 4, lash = 10 }
local function gait(p, g)
	local c, s = math.cos(TAU * p), math.sin(TAU * p)
	local thigh = g.swing * c
	-- left: planted for p in [0, 0.5] (s >= 0), swinging after; the right leg half a cycle later
	local kneeL = g.knee * math.max(0, -s) + g.give * math.max(0, s)
	local kneeR = g.knee * math.max(0, s) + g.give * math.max(0, -s)
	local dy = -HIP * (1 - math.cos(math.rad(g.swing * math.abs(c)))) * g.drop + g.bounce * math.abs(s)
	local ca = math.cos(TAU * (p - 0.05)) -- the arms trail the legs a little
	local function lag(d) return math.cos(TAU * (p - d)) end
	return {
		Pelvis = { 0, dy, 0 },
		Spine_Lower = { -g.shift * s, 0, 0, g.lean, -g.twist * c, g.sway * s },
		Spine_Upper = { 0, 0, 0, g.nod * 0.5 * math.cos(2 * TAU * p), g.twist * 1.6 * c, -g.sway * 0.5 * s },
		Neck = { 0, 0, 0, g.look * 0.4, -g.twist * 0.6 * c, 0 },
		Head = { 0, 0, 0, g.look * 0.6 + g.nod * math.cos(2 * TAU * (p - 0.06)), 0, -g.sway * 0.3 * s },
		Jaw = { 0, 0, 0, -(g.jaw + g.flap * math.abs(s)) },
		CandyCrown = { 0, g.jiggle * math.cos(2 * TAU * (p - 0.1)), 0, 0, 0, g.crown * math.sin(TAU * (p - 0.12)) },
		Thigh_L = { 0, 0, 0, thigh }, Thigh_R = { 0, 0, 0, -thigh },
		Shin_L = { 0, 0, 0, -kneeL }, Shin_R = { 0, 0, 0, -kneeR },
		-- the sole stays level (it cancels the thigh and the knee), the toes rise while the leg swings
		Foot_L = { 0, 0, 0, kneeL - thigh + g.toe * math.max(0, -s) }, Foot_R = { 0, 0, 0, kneeR + thigh + g.toe * math.max(0, s) },
		UpperArm_L = { 0, 0, 0, -g.arm * ca, 0, -g.spread }, UpperArm_R = { 0, 0, 0, g.arm * ca, 0, g.spread },
		Forearm_L = { 0, 0, 0, g.elbow * (1 + 0.5 * math.max(0, -ca)) }, Forearm_R = { 0, 0, 0, g.elbow * (1 + 0.5 * math.max(0, ca)) },
		Finger_L1 = { 0, 0, 0, -g.curl }, Finger_L2 = { 0, 0, 0, -g.curl }, Finger_R1 = { 0, 0, 0, -g.curl }, Finger_R2 = { 0, 0, 0, -g.curl },
		Licorice_01 = { 0, 0, 0, 0.4 * g.arm * lag(0.12), 0, g.lash * math.sin(TAU * (p - 0.15)) },
		Licorice_02 = { 0, 0, 0, 0.3 * g.arm * lag(0.2), 0, g.lash * math.sin(TAU * (p - 0.23)) },
		Licorice_03 = { 0, 0, 0, 0.2 * g.arm * lag(0.28), 0, g.lash * math.sin(TAU * (p - 0.31)) },
	}
end
-- A looping clip of `cycles` step cycles at `speed`; extra(q) (q in [0, 1) over the whole clip) adds to each key.
local function walking(g, speed, cycles, extra)
	local length = cycleLength(speed, g.swing) * cycles
	local total = KEYS_PER_CYCLE * cycles
	local keys = {}
	for i = 0, total do
		local q = (i % total) / total -- the last key is the first again: the loop closes exactly
		local pose = gait((q * cycles) % 1, g)
		table.insert(keys, { length * i / total, extra and merge(pose, extra(q)) or pose })
	end
	return { length = length, loop = true, priority = Enum.AnimationPriority.Movement, easing = "Linear", cycles = cycles, keys = keys }
end

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
	-- heavy steps (Patrol, Return): the body drops on each landing and rocks over the planted leg; the arms swing a little
	Patrol_Walk = walking(WALK, Clips.WALK_SPEED, 1),
	-- violent steps (Chase), the torso bent forward, the knees high, the arms pumping, the jaw open
	Chase_Run = walking(RUN, Clips.RUN_SPEED, 1),
	-- it lifts its head and opens its eyes: the head snaps up and holds
	Notice = { length = 0.8, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.2, merge(head(18), jaw(10), breath(1), candies(5, 0.15)) }, { 0.5, merge(head(14, 6), jaw(6), candies(-3)) },
		{ 0.8, merge(head(12), jaw(5)) } } },
	-- walks to where it last saw the target (the brain moves it at the patrol speed), looking left and right as it goes
	Search = walking(WALK, Clips.WALK_SPEED, 2, function(q)
		local look = math.sin(TAU * q)
		return merge(head(4, 40 * look), { Spine_Upper = { 0, 0, 0, 0, 10 * look, 0 } })
	end),
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
				item.EasingStyle = clip.easing == "Linear" and Enum.PoseEasingStyle.Linear or Enum.PoseEasingStyle.Cubic
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
