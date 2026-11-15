-- Scuttler's clips (odd/tasks/wildbound-scuttler.md, SC9; docs/design/wildbound-scuttler-plan.md section 9). The
-- seventeen clips WildboundBeastAnimPlan.PLANS.Scuttler names, as data, turned into KeyframeSequences for the prefab's
-- bones (assets/blender/scuttler/build_scuttler.py, 43 bones) by Clips.build.
-- A key is { time, pose }; a pose maps a bone to { dx, dy, dz, pitch, yaw, roll } in MODEL axes (studs and degrees;
-- X is the creature's right, Y up, -Z forward), relative to its parent's motion. Missing bones rest. A positive pitch
-- lifts the nose (and raises a claw arm that points forward).
-- Everything is in place: Root never moves (the server moves the model). Standing, the body bobs on Hips without
-- turning and every upper leg (the legs hang from Hips) takes the bob back, so the feet stay on the ground; rearing up
-- and leaning are done on the Thorax. Only the fall clips (Stumble, Crash, Fallen, GetUp) drop the body to the ground.
-- It skitters on alternating tripods: L1, R2, L3, R4 swing together, the other four the opposite way.
-- Markers follow the art standard; the server times every attack by itself and never trusts them. The feint carries
-- no marker on purpose: it is never registered with the dodge.
-- Rules: WildboundScuttlerClips_Test.
local Clips = {}

-- The rig's bones, parents first (the Blender source's BONES list): { name, parent }.
Clips.BONES = (function()
	local list = { { "Root" }, { "Hips", "Root" }, { "Thorax", "Hips" }, { "Head", "Thorax" }, { "Jaw", "Head" } }
	for _, s in ipairs({ "L", "R" }) do
		table.insert(list, { "Antenna_" .. s .. "_01", "Head" })
		table.insert(list, { "Antenna_" .. s .. "_02", "Antenna_" .. s .. "_01" })
	end
	for _, s in ipairs({ "L", "R" }) do
		local c = "Claw_" .. s .. "_"
		table.insert(list, { c .. "Shoulder", "Thorax" })
		table.insert(list, { c .. "Upper", c .. "Shoulder" })
		table.insert(list, { c .. "Fore", c .. "Upper" })
		table.insert(list, { c .. "PincerA", c .. "Fore" })
		table.insert(list, { c .. "PincerB", c .. "Fore" })
	end
	for _, s in ipairs({ "L", "R" }) do
		for i = 1, 4 do
			local leg = "Leg_" .. s .. i .. "_"
			table.insert(list, { leg .. "Upper", "Hips" })
			table.insert(list, { leg .. "Lower", leg .. "Upper" })
			table.insert(list, { leg .. "Foot", leg .. "Lower" })
		end
	end
	return list
end)()

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

local SIDES = { "L", "R" }
-- Left is -X: a left limb swings forward with a negative yaw and lifts with a negative roll; the right one mirrors it.
local function mirror(side, value) return side == "L" and -value or value end
-- Tripod groups: true for L1, R2, L3, R4.
local function groupA(side, i) return (side == "L") == (i % 2 == 1) end

-- The body up (+) or down (-) on Hips, never turned; the eight upper legs take the height back.
local function body(dy)
	local pose = { Hips = { 0, dy, 0 } }
	for _, s in ipairs(SIDES) do
		for i = 1, 4 do pose["Leg_" .. s .. i .. "_Upper"] = { 0, -dy, 0 } end
	end
	return pose
end
-- Alternating tripods: group A swings `swing` degrees forward (B the same back); liftA/liftB raise the feet (degrees).
local function gait(swing, liftA, liftB)
	local pose = {}
	for _, s in ipairs(SIDES) do
		for i = 1, 4 do
			local a = groupA(s, i)
			local fwd = a and swing or -swing
			local lift = a and (liftA or 0) or (liftB or 0)
			pose["Leg_" .. s .. i .. "_Upper"] = { 0, 0, 0, 0, mirror(s, fwd), mirror(s, lift) }
			pose["Leg_" .. s .. i .. "_Lower"] = { 0, 0, 0, 0, 0, mirror(s, -lift * 0.5) }
		end
	end
	return pose
end
-- Every leg splayed up and out (the fall): the feet leave the ground.
local function splay(lift)
	local pose = {}
	for _, s in ipairs(SIDES) do
		for i = 1, 4 do
			pose["Leg_" .. s .. i .. "_Upper"] = { 0, 0, 0, 0, 0, mirror(s, lift) }
			pose["Leg_" .. s .. i .. "_Foot"] = { 0, 0, 0, 0, 0, mirror(s, -lift * 0.8) }
		end
	end
	return pose
end
local function thorax(pitch, yaw, roll) return { Thorax = { 0, 0, 0, pitch or 0, yaw or 0, roll or 0 } } end
local function head(pitch, yaw, roll) return { Head = { 0, 0, 0, pitch or 0, yaw or 0, roll or 0 } } end
-- The jaw open by `degrees` (it drops: a negative pitch).
local function jaw(degrees) return { Jaw = { 0, 0, 0, -degrees, 0, 0 } } end
-- Both antennas: sweep (yaw, + toward the creature's left), lift (pitch) and spread (each out to its side).
local function antennas(sweep, lift, spread)
	sweep, lift, spread = sweep or 0, lift or 0, spread or 0
	local pose = {}
	for _, s in ipairs(SIDES) do
		local yaw = sweep + (s == "L" and spread or -spread)
		pose["Antenna_" .. s .. "_01"] = { 0, 0, 0, lift * 0.6, yaw * 0.6, 0 }
		pose["Antenna_" .. s .. "_02"] = { 0, 0, 0, lift * 0.4, yaw * 0.4, 0 }
	end
	return pose
end
-- Both claw arms: raise (pitch of the upper arm), reach (the forearm forward and down, +), open (the pincer blades
-- apart) and sweep (+ inward, toward the middle; - outward).
local function claws(raise, reach, open, sweep)
	raise, reach, open, sweep = raise or 0, reach or 0, open or 0, sweep or 0
	local pose = {}
	for _, s in ipairs(SIDES) do
		local c = "Claw_" .. s .. "_"
		pose[c .. "Shoulder"] = { 0, 0, 0, 0, mirror(s, -sweep), 0 }
		pose[c .. "Upper"] = { 0, 0, 0, raise, 0, 0 }
		pose[c .. "Fore"] = { 0, 0, 0, -reach, 0, 0 }
		pose[c .. "PincerA"] = { 0, 0, 0, open * 0.5, 0, 0 }
		pose[c .. "PincerB"] = { 0, 0, 0, -open * 0.5, 0, 0 }
	end
	return pose
end

local REST = {}
-- Head down, claws forward, legs braced: the charge, and the end of its windup.
local CHARGE = merge(body(-1.0), thorax(-12), head(-10), claws(-5, 25, 10), antennas(0, -20))
local CHARGE0 = merge(CHARGE, gait(22, 0, 0))
-- On the ground after the overrun: the body down, the legs splayed, dazed.
local FALLEN = merge({ Hips = { 0, -4.2, 0, -6, 0, 6 } }, splay(30), thorax(-10, 0, 4), head(-8, 0, 10), claws(-20, 0, 10),
	antennas(0, -25, 20), jaw(10))
-- Reared up at the end of the pulse's charge.
local REAR = merge(thorax(30), head(14), claws(40, 0, 30, -40), antennas(0, 30, 30), jaw(20))
local SCREAM = merge(REAR, jaw(25), antennas(0, 0, 15))
local LOW = merge(body(-0.6), thorax(-6), head(-4), claws(-8, -15), antennas(0, -15))
local BLOCK = merge(body(0.3), thorax(10), head(6), claws(35, -20, 25), antennas(0, 15, 15))
local READ = merge(head(4), antennas(0, 10, 8))
local CROUCH = merge(body(-1.2), thorax(-10), head(-8), claws(-6, 20))
local RETREAT_END = merge(body(-1.6), thorax(-12), head(-12), claws(-20, -25), antennas(0, -30))

-- A walk cycle: group A forward, both centred with B in the air, A back, both centred with A in the air.
local function cycle(base, length, swing, lift, bob)
	return {
		{ 0, merge(base, gait(swing, 0, 0)) },
		{ length * 0.25, merge(base, gait(0, 0, lift), body(bob)) },
		{ length * 0.5, merge(base, gait(-swing, 0, 0)) },
		{ length * 0.75, merge(base, gait(0, lift, 0), body(bob)) },
		{ length, merge(base, gait(swing, 0, 0)) },
	}
end

Clips.ORDER = { "Idle", "Skitter", "Read", "Intercept", "Block", "Feint", "ChargeWindup", "Charge", "Snap", "PulseCharge",
	"Pulse", "Recover", "Stumble", "Crash", "Fallen", "GetUp", "Retreat" }
local A = Enum.AnimationPriority
Clips.CLIPS = {
	-- breathing, the antennas drifting, the jaw twitching
	Idle = { length = 2.4, loop = true, priority = A.Idle, keys = {
		{ 0, REST }, { 0.6, merge(body(0.12), antennas(10, 5), jaw(4)) }, { 1.2, merge(body(-0.05), antennas(-6), head(0, 0, 4)) },
		{ 1.8, merge(body(0.12), antennas(-12, 5), jaw(6)) }, { 2.4, REST } } },
	-- the stalk: alternating tripods, the body bobbing twice per cycle (rate by speed, ref 14 studs/s)
	Skitter = { length = 0.6, loop = true, priority = A.Movement, keys = cycle(merge(antennas(0, 5)), 0.6, 20, 14, 0.25) },
	-- it reads the route: the head tilts to each side, the antennas sweep
	Read = { length = 1.6, loop = true, priority = A.Action, keys = {
		{ 0, READ }, { 0.4, merge(READ, head(0, 12, 14), antennas(25), thorax(4, 4)) }, { 0.8, merge(READ, jaw(5)) },
		{ 1.2, merge(READ, head(0, -12, -14), antennas(-25), thorax(4, -4)) }, { 1.6, READ } } },
	-- the intercept run: low and fast, claws tucked (ref 21 studs/s)
	Intercept = { length = 0.4, loop = true, priority = A.Movement, keys = cycle(LOW, 0.4, 26, 18, 0.2) },
	-- it blocks the route: claws up and open, swaying
	Block = { length = 1.2, loop = true, priority = A.Action, keys = {
		{ 0, BLOCK }, { 0.3, merge(BLOCK, claws(0, 0, 10), thorax(0, 0, 4)) }, { 0.6, BLOCK },
		{ 0.9, merge(BLOCK, claws(0, 0, 10), thorax(0, 0, -4)) }, { 1.2, BLOCK } } },
	-- the feint: it crouches like a real windup and lunges a little with the thorax, then stops; the body never travels
	Feint = { length = 0.9, loop = false, priority = A.Action, keys = {
		{ 0, REST }, { 0.45, CROUCH }, { 0.65, merge(CROUCH, { Thorax = { 0, 0, -0.8, -4, 0, 0 } }, head(-2)) }, { 0.9, REST } } },
	-- the real charge's tell: only ever deeper, the lane locks at 0.80 s (lockLead 0.3 before the 1.1 s tell)
	ChargeWindup = { length = 1.1, loop = false, priority = A.Action,
		markers = { { 0, "TelegraphStart" }, { 0.8, "AttackCommit" } }, keys = {
		{ 0, REST }, { 0.4, merge(body(-0.5), thorax(-6), head(-5), claws(5, 10), antennas(0, -10)) },
		{ 0.8, merge(body(-0.9), thorax(-10), head(-9), claws(-3, 20, 8), antennas(0, -18), gait(11, 0, 0)) }, { 1.1, CHARGE0 } } },
	-- the charge itself: head down, fast tripods
	Charge = { length = 0.45, loop = true, priority = A.Movement, keys = cycle(CHARGE, 0.45, 22, 20, 0.3) },
	-- the Snap: claws up and out, then a sweep inward at the strike
	Snap = { length = 1.2, loop = false, priority = A.Action, markers = { { 0, "TelegraphStart" }, { 0.9, "HitFrame" } }, keys = {
		{ 0, REST }, { 0.5, merge(thorax(6), head(4), claws(40, 0, 35, -25)) }, { 0.8, merge(thorax(8), head(6), claws(45, 0, 40, -30)) },
		{ 0.9, merge(thorax(-6), head(-4), claws(-10, 25, 0, 30)) }, { 1.2, REST } } },
	-- the pulse's charge: it rears up on the thorax (only ever higher), claws spread, jaw opening
	PulseCharge = { length = 1.3, loop = false, priority = A.Action, markers = { { 0, "TelegraphStart" } }, keys = {
		{ 0, REST }, { 0.6, merge(thorax(18), head(10), claws(25, 0, 20, -30), antennas(0, 20, 20), jaw(10)) }, { 1.3, REAR } } },
	-- the scream: the jaw wide, a shake, back down
	Pulse = { length = 0.8, loop = false, priority = A.Action, markers = { { 0, "HitFrame" } }, keys = {
		{ 0, REAR }, { 0.15, SCREAM }, { 0.35, merge(SCREAM, head(0, 0, 6)) }, { 0.55, merge(REAR, head(0, 0, -6)) }, { 0.8, REST } } },
	-- after a missed charge: it shakes its head and stands
	Recover = { length = 1.0, loop = false, priority = A.Action, keys = {
		{ 0, CHARGE0 }, { 0.3, merge(body(-0.4), head(0, 0, 12), antennas(0, 0, 10)) }, { 0.6, head(0, 0, -10) }, { 1.0, REST } } },
	-- the overrun in the open: it trips forward and rolls onto its side
	Stumble = { length = 0.8, loop = false, priority = A.Action, keys = {
		{ 0, CHARGE0 }, { 0.3, merge({ Hips = { 0, -1.5, 0, -10, 0, 8 } }, thorax(-14), head(-10), splay(10), claws(-15, 30)) },
		{ 0.8, FALLEN } } },
	-- the overrun into a wall: the head slams, it bounces back and drops
	Crash = { length = 0.7, loop = false, priority = A.Action, keys = {
		{ 0, CHARGE0 }, { 0.15, merge(CHARGE, thorax(-14), head(-14), claws(-25, 10)) },
		{ 0.35, merge({ Hips = { 0, -2, 0, 8, 0, 0 } }, thorax(10), head(20), splay(15), antennas(0, -30)) }, { 0.7, FALLEN } } },
	-- dazed on the ground: the head rolls, the antennas droop and swing
	Fallen = { length = 1.6, loop = true, priority = A.Action, keys = {
		{ 0, FALLEN }, { 0.4, merge(FALLEN, head(0, 10, -8), antennas(15)) }, { 0.8, merge(FALLEN, head(4)) },
		{ 1.2, merge(FALLEN, head(0, -10, 8), antennas(-15)) }, { 1.6, FALLEN } } },
	-- back on its feet
	GetUp = { length = 1.0, loop = false, priority = A.Action, keys = {
		{ 0, FALLEN }, { 0.5, merge(body(-1.2), thorax(-6), head(6, 0, -6), antennas(0, 10)) }, { 1.0, REST } } },
	-- it leaves: crouches low, backs off a step and stays low while it fades (the last pose holds)
	Retreat = { length = 1.0, loop = false, priority = A.Action, keys = {
		{ 0, REST }, { 0.3, merge(body(-0.6), thorax(-6), head(-6), antennas(0, -15)) },
		{ 0.6, merge(body(-1.2), thorax(-10), head(-10), claws(-15, -20), antennas(0, -25), gait(-10, 0, 8)) }, { 1.0, RETREAT_END } } },
}

-- Published copies (Animation assets made by Clips.build in Studio and published to the group that owns the
-- universe). A clip changed here must be built and published again: the game plays these ids.
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
