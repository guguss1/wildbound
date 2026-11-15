-- Tortidragon's clips (odd/tasks/wildbound-caramelo.md, CA2; pack 03_PERSONAJES/03_TORTIDRAGON.md). Eleven animations
-- as data, turned into KeyframeSequences for the prefab's bones by Clips.build.
-- A key is { time, pose }; a pose maps a bone to { dx, dy, dz, pitch, yaw, roll } in MODEL axes (studs and degrees;
-- X is the character's right, Y up, -Z forward), relative to its parent's motion. Missing bones rest. A positive
-- pitch lifts the nose, and swings a leg's foot forward.
-- Everything is in place: Root never moves (no physical translation from the clip), the body bobs on the Pelvis and
-- every upper leg takes the bob back, so the feet stay on the ground. It trots on four legs (diagonal pairs) and
-- gallops with the front and back pairs together; it never hops like Gomibu or wobbles like Flanfuria.
-- Markers follow the art standard; the server times the attack by itself and never trusts them.
-- Rules: WildboundCandyTortidragonClips_Test.
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
local UPPER = { "FrontLeg_L_Upper", "FrontLeg_R_Upper", "BackLeg_L_Upper", "BackLeg_R_Upper" }
-- The body up (+) or down (-) and pitched, the four upper legs taking the height back so the feet stay planted.
local function body(dy, pitch, roll)
	local pose = { Pelvis = { 0, dy, 0, pitch or 0, 0, roll or 0 } }
	for _, name in ipairs(UPPER) do pose[name] = { 0, -dy, 0 } end
	return pose
end
-- Leg swings in degrees (+ the foot forward) for front-left, front-right, back-left, back-right; the lower leg bends
-- back by `bend` on the legs moving forward (the foot lifts while it travels).
local function legs(fl, fr, bl, br, bend)
	bend = bend or 0
	local function lower(swing) return swing > 0 and -bend or 0 end
	return { FrontLeg_L_Upper = { 0, 0, 0, fl }, FrontLeg_R_Upper = { 0, 0, 0, fr }, BackLeg_L_Upper = { 0, 0, 0, bl },
		BackLeg_R_Upper = { 0, 0, 0, br }, FrontLeg_L_Lower = { 0, 0, 0, lower(fl) }, FrontLeg_R_Lower = { 0, 0, 0, lower(fr) },
		BackLeg_L_Lower = { 0, 0, 0, lower(bl) }, BackLeg_R_Lower = { 0, 0, 0, lower(br) } }
end
local function neck(pitch, yaw) return { Neck_01 = { 0, 0, 0, pitch * 0.5, yaw * 0.4, 0 }, Neck_02 = { 0, 0, 0, pitch * 0.5, yaw * 0.6, 0 } } end
local function head(pitch, yaw, roll) return { Head = { 0, 0, 0, pitch or 0, yaw or 0, roll or 0 } } end
-- The jaw open by `degrees` (it drops: a negative pitch).
local function jaw(degrees) return { Jaw = { 0, 0, 0, -degrees, 0, 0 } } end
-- The cheeks puffed out sideways: a = 1 is the full puff of the tell. Left is -X.
local function cheeks(a) return { Cheek_L = { -0.35 * a, 0, 0 }, Cheek_R = { 0.35 * a, 0, 0 } } end
-- The cream tail: sideways (yaw) and up (lift, + curls it up and over).
local function tail(yaw, lift)
	lift = lift or 0
	return { Tail_01 = { 0, 0, 0, lift * 0.4, yaw * 0.4, 0 }, Tail_02 = { 0, 0, 0, lift * 0.3, yaw * 0.35, 0 },
		Tail_03 = { 0, 0, 0, lift * 0.3, yaw * 0.25, 0 } }
end
-- The crest and the strawberries swing (roll in degrees) and bob.
local function wobble(roll, bob)
	bob = bob or 0
	return { CreamCrest = { 0, bob, 0, 0, 0, roll }, Strawberry_L = { 0, bob * 0.5, 0, 0, 0, roll * 0.7 },
		Strawberry_R = { 0, bob * 0.5, 0, 0, 0, roll * 0.7 }, Strawberry_Back = { 0, 0, 0, 0, 0, roll * 0.5 } }
end
local REST = {}
-- Lying down at the farm: body low, front legs folded forward, back legs tucked.
local LIE = merge({ Pelvis = { 0, -1.5, 0 } }, { FrontLeg_L_Upper = { 0, 0.3, 0, 75 }, FrontLeg_R_Upper = { 0, 0.3, 0, 75 },
	FrontLeg_L_Lower = { 0, 0, 0, -10 }, FrontLeg_R_Lower = { 0, 0, 0, -10 }, BackLeg_L_Upper = { 0, 0.2, 0, 60 },
	BackLeg_R_Upper = { 0, 0.2, 0, 60 }, BackLeg_L_Lower = { 0, 0, 0, -110 }, BackLeg_R_Lower = { 0, 0, 0, -110 } }, neck(-10, 0), tail(30, -10))
local AIM = merge(cheeks(1), neck(12, 0), head(8), body(-0.25, 3), legs(8, 8, -6, -6), tail(0, 18))
local SPAT = merge(cheeks(0.1), neck(-12, 0), head(-14), jaw(28), body(-0.1, -3), legs(4, 4, -4, -4), tail(0, 25))

Clips.ORDER = { "Idle", "Walk_Quadruped", "Run_Quadruped", "Turn", "Alert", "Attack_Telegraph", "Attack_Release", "Attack_Recover",
	"HitReact", "FarmIdle", "HatchReact" }
Clips.CLIPS = {
	-- breathing, the tail swinging, a look to each side
	Idle = { length = 3.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, REST }, { 0.75, merge(body(0.08, 0), tail(12, 4), head(0, 10)) }, { 1.5, merge(body(-0.04, 0), wobble(2)) },
		{ 2.25, merge(body(0.08, 0), tail(-12, 4), head(0, -10)) }, { 3.0, REST } } },
	-- a trot: diagonal pairs (front-left with back-right) swing together, the body bobs twice per cycle
	Walk_Quadruped = { length = 0.9, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, merge(legs(18, -18, -18, 18, 20), body(0, 0)) }, { 0.225, merge(legs(0, 0, 0, 0), body(0.12, 0), tail(6)) },
		{ 0.45, merge(legs(-18, 18, 18, -18, 20), body(0, 0)) }, { 0.675, merge(legs(0, 0, 0, 0), body(0.12, 0), tail(-6)) },
		{ 0.9, merge(legs(18, -18, -18, 18, 20), body(0, 0)) } } },
	-- a gallop: front pair, then back pair; the body rocks nose down and nose up, the tail lifted for balance
	Run_Quadruped = { length = 0.6, loop = true, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, merge(legs(28, 24, -26, -22, 30), body(0, -5), neck(-6, 0), tail(0, 15)) },
		{ 0.15, merge(legs(0, 4, 10, 14), body(0.35, 0), tail(0, 20), wobble(3, 0.05)) },
		{ 0.3, merge(legs(-26, -22, 28, 24, 30), body(0, 5), neck(6, 0), tail(0, 12)) },
		{ 0.45, merge(legs(4, 0, -10, -6), body(0.2, 0), tail(0, 18), wobble(-3)) },
		{ 0.6, merge(legs(28, 24, -26, -22, 30), body(0, -5), neck(-6, 0), tail(0, 15)) } } },
	-- the head leads, the body leans into the curve, the tail swings out
	Turn = { length = 0.5, loop = false, priority = Enum.AnimationPriority.Movement, keys = {
		{ 0, REST }, { 0.2, merge(neck(0, 20), head(0, 15), body(0, 0, 6), tail(-20)) }, { 0.35, merge(neck(0, 10), body(0, 0, 3), tail(-10)) },
		{ 0.5, REST } } },
	-- the neck goes up and the head looks; the crest and strawberries swing
	Alert = { length = 0.75, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.2, merge(neck(18, 0), head(10), wobble(8, 0.1), tail(0, 10)) }, { 0.45, merge(neck(16, 0), head(6, 12), wobble(-5)) },
		{ 0.75, merge(neck(14, 0), head(4)) } } },
	-- Abanico de Confites, part 1: the cheeks puff, the head pulls back, the legs brace; only ever deeper
	Attack_Telegraph = { length = 1.0, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "TelegraphStart" }, { 0.6, "AttackCommit" } }, keys = {
		{ 0, REST }, { 0.3, merge(cheeks(0.4), neck(5, 0), head(3), body(-0.1, 1), tail(0, 8)) },
		{ 0.6, merge(cheeks(0.8), neck(10, 0), head(6), body(-0.2, 2), legs(6, 6, -4, -4), tail(0, 14)) }, { 1.0, AIM } } },
	-- part 2: the head snaps forward, the mouth opens and the candies fly; the tail flicks up
	Attack_Release = { length = 0.65, loop = false, priority = Enum.AnimationPriority.Action, markers = { { 0, "HitFrame" } }, keys = {
		{ 0, AIM }, { 0.12, merge(SPAT, wobble(6)) }, { 0.35, merge(SPAT, wobble(-4), jaw(6)) }, { 0.65, SPAT } } },
	-- part 3: shakes the icing off, the tail uncurls
	Attack_Recover = { length = 0.85, loop = false, priority = Enum.AnimationPriority.Action,
		markers = { { 0, "RecoverStart" }, { 0.85, "AttackEnd" } }, keys = {
		{ 0, SPAT }, { 0.2, merge(head(0, 0, 14), wobble(10), tail(0, 15)) }, { 0.4, merge(head(0, 0, -12), wobble(-8), tail(0, 8)) },
		{ 0.6, merge(head(0, 0, 6), wobble(4), tail(0, 3)) }, { 0.85, REST } } },
	-- a head shake
	HitReact = { length = 0.5, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, REST }, { 0.1, merge(body(-0.15, -4), head(-6, 18), wobble(10)) }, { 0.25, merge(head(0, -16), wobble(-8)) },
		{ 0.4, merge(head(0, 8), wobble(4)) }, { 0.5, REST } } },
	-- the pet at the farm: lying down, the tail swaying, licking the cream; nothing that reads as a strike
	FarmIdle = { length = 4.0, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
		{ 0, LIE }, { 1.0, merge(LIE, tail(-25), { Pelvis = { 0, 0.05, 0 } }) }, { 2.0, merge(LIE, head(-15, -20), jaw(10)) },
		{ 2.5, merge(LIE, head(-12, -20), jaw(4)) }, { 3.0, merge(LIE, tail(-20)) }, { 4.0, LIE } } },
	-- out of the egg: crouched, it springs up, sneezes a (decorative) candy and looks around
	HatchReact = { length = 2.0, loop = false, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, merge(body(-0.8, 0), neck(-15, 0), cheeks(0.2)) }, { 0.35, merge(body(0.3, 4), neck(15, 0), wobble(10, 0.15)) },
		{ 0.7, merge(neck(18, 0), head(18), cheeks(0.6)) }, { 0.9, merge(neck(-10, 0), head(-22), jaw(25), wobble(-8)) },
		{ 1.3, merge(head(0, -25), tail(15)) }, { 1.7, merge(head(0, 25), tail(-15)) }, { 2.0, REST } } },
}

-- Published copies (Animation assets uploaded from assets/exports/caramelo/tortidragon-clips/*.rbxmx, made by
-- Clips.build in Studio). A clip changed here must be exported and uploaded again: the game plays these ids.
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
