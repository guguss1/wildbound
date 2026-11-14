-- Lumipol rig pass (user, 2026-11-11: "Sleep" while asleep, "Run" while it chases, "Walk" when it walks home).
-- The rigged Lumipol (assets/lumipol_rig v1: one skinned MeshPart with 22 Bones) is animated from
-- WildboundLumipolAnimData, the bone poses baked out of Blender. This module is pure math over a rig it is handed:
-- it fits the Blender armature to the imported bones (the axis turn, the scale and the offset the importer chose), turns
-- every key into Bone.Transform values for that rig, samples a clip at a time, and can write a clip as a
-- KeyframeSequence (for the place owner to publish). It reads no service and changes nothing but the bones it is given.
local Rig = {}

-- The model's skinned MeshPart and its bones by name, or nil when the model holds no bones.
function Rig.find(model)
	if typeof(model) ~= "Instance" then return nil end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("MeshPart") and item:FindFirstChildWhichIsA("Bone", true) then
			local bones = {}
			for _, bone in ipairs(item:GetDescendants()) do
				if bone:IsA("Bone") then bones[bone.Name] = bone end
			end
			return { mesh = item, bones = bones }
		end
	end
	return nil
end

-- Every bone under the mesh, parents before children.
local function ordered(mesh)
	local list = {}
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("Bone") then
				table.insert(list, child)
				walk(child)
			end
		end
	end
	walk(mesh)
	return list
end

-- Each bone's rest frame in the mesh's space (Transform ignored).
local function restFrames(order)
	local frames = {}
	for _, bone in ipairs(order) do
		local parent = bone.Parent
		frames[bone] = (parent:IsA("Bone") and frames[parent] or CFrame.identity) * bone.CFrame
	end
	return frames
end

-- The 24 axis turns (right-handed), as CFrames.
local TURNS = {}
do
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	for i = 1, 3 do
		for j = 1, 3 do
			if j ~= i then
				for _, si in ipairs({ 1, -1 }) do
					for _, sj in ipairs({ 1, -1 }) do
						local x, y = axes[i] * si, axes[j] * sj
						table.insert(TURNS, CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y)))
					end
				end
			end
		end
	end
end
Rig.TURNS = TURNS

-- Maps Blender armature space onto the mesh's space: mesh point = o + s * R(blender point). Picks the axis turn with
-- the smallest error over every bone head the data and the rig share. Returns { R, s, o, err, count } or nil.
function Rig.fit(data, rig)
	local frames = restFrames(ordered(rig.mesh))
	local pairs_ = {}
	for name, p in pairs(data.restPos) do
		local bone = rig.bones[name]
		if bone then table.insert(pairs_, { b = Vector3.new(p[1], p[2], p[3]), r = frames[bone].Position }) end
	end
	if #pairs_ < 4 then return nil end
	local cb, cr = Vector3.zero, Vector3.zero
	for _, q in ipairs(pairs_) do cb += q.b; cr += q.r end
	cb /= #pairs_; cr /= #pairs_
	local best
	for _, turn in ipairs(TURNS) do
		local num, den = 0, 0
		for _, q in ipairs(pairs_) do
			local b = turn:VectorToWorldSpace(q.b - cb)
			num += (q.r - cr):Dot(b)
			den += b:Dot(b)
		end
		local s = den > 0 and num / den or 0
		if s > 0 then
			local err = 0
			for _, q in ipairs(pairs_) do
				err += ((q.r - cr) - turn:VectorToWorldSpace(q.b - cb) * s).Magnitude ^ 2
			end
			if not best or err < best.err then
				best = { R = turn, s = s, o = cr - turn:VectorToWorldSpace(cb) * s, err = math.sqrt(err / #pairs_),
					count = #pairs_ }
			end
		end
	end
	return best
end

-- One key's delta for a bone, in the mesh's space.
local function delta(fit, v)
	local rot = CFrame.new(0, 0, 0, v[5], v[6], v[7], v[4])
	local turned = fit.R * rot * fit.R:Inverse()
	local t = fit.R:VectorToWorldSpace(Vector3.new(v[1], v[2], v[3])) * fit.s
	return CFrame.new(fit.o) * CFrame.new(t) * turned * CFrame.new(-fit.o)
end

-- Turns the data's actions into clips for this rig: clips[name] = { length, keys = { { t, pose = { [Bone] = CFrame } } } }.
function Rig.build(data, rig, fit)
	local order = ordered(rig.mesh)
	local rest = restFrames(order)
	local clips = {}
	for name, action in pairs(data.actions) do
		local keys = {}
		for _, key in ipairs(action.keys) do
			local posed, pose = {}, {}
			for _, bone in ipairs(order) do
				local parent = bone.Parent
				local base = (parent:IsA("Bone") and posed[parent] or CFrame.identity) * bone.CFrame
				local v = key.p[bone.Name]
				local target = v and delta(fit, v) * rest[bone] or base
				posed[bone] = target
				pose[bone] = base:Inverse() * target
			end
			table.insert(keys, { t = key.t, pose = pose })
		end
		clips[name] = { length = action.length, keys = keys, bones = order }
	end
	return clips
end

-- The clip's pose at `time` (looped), as { [Bone] = CFrame }, written into `out`.
function Rig.sample(clip, time, out)
	out = out or {}
	local keys = clip.keys
	local t = clip.length > 0 and time % clip.length or 0
	local i = 1
	while i < #keys and keys[i + 1].t <= t do i += 1 end
	local a, b = keys[i], keys[math.min(i + 1, #keys)]
	local alpha = (b.t > a.t) and (t - a.t) / (b.t - a.t) or 0
	for bone, cf in pairs(a.pose) do
		out[bone] = cf:Lerp(b.pose[bone], alpha)
	end
	return out
end

-- The clip as a looping KeyframeSequence (poses nested like the bones, under a pose named after the mesh).
function Rig.keyframeSequence(clip, rig, name)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name, sequence.Loop = name, true
	sequence.Priority = Enum.AnimationPriority.Core
	for _, key in ipairs(clip.keys) do
		local frame = Instance.new("Keyframe")
		frame.Time = key.t
		local top = Instance.new("Pose")
		top.Name, top.Weight = rig.mesh.Name, 0
		local made = {}
		for _, bone in ipairs(clip.bones) do
			local pose = Instance.new("Pose")
			pose.Name, pose.CFrame = bone.Name, key.pose[bone]
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.Parent = made[bone.Parent] or top
			made[bone] = pose
		end
		top.Parent = frame
		frame.Parent = sequence
	end
	return sequence
end

return Rig
