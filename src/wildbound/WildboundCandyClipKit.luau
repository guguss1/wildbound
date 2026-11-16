-- Shared clip kit for the six Caramelo critters (odd/tasks/wildbound-candy-critters.md). Pure apart from Instance.new.
-- Clip data (generated from the Blender JSON by tools/generate_candy_critter_clips.py) is, per clip:
--   { length, loop, priority = "Idle"|"Movement"|"Action", easing = "Linear"?, keys = { { t, pose = { Bone = {6} } } } }
-- where a bone value is { dx, dy, dz, rx, ry, rz }: studs and degrees in model axes (X right, Y up, -Z forward),
-- relative to rest. A bone missing from a key is at rest in that key.
-- Kit.define(data) returns a table with the existing clip-module API (ORDER, CLIPS, IDS, animationId, build), so
-- WildboundCandyClipPublish.build/pending/idsSource work on it unchanged. Kit.sample and Kit.transform let a client
-- play the same data live through Bone.Transform (WildboundCandyCritterAnim), with no published Animation asset.
-- Rules: tests/WildboundCandyClipKit_Test.luau.
local Kit = {}

Kit.PRIORITY = {
	Idle = Enum.AnimationPriority.Idle,
	Movement = Enum.AnimationPriority.Movement,
	Action = Enum.AnimationPriority.Action,
}

local ZERO = { 0, 0, 0, 0, 0, 0 }
Kit.ZERO = ZERO

-- A bone's Transform (or Pose.CFrame) for a model-axes value v, given the bone's rest rotation relative to the model
-- pivot (pivot:ToObjectSpace(bone.WorldCFrame).Rotation, read while every Transform is identity). restInv (optional)
-- is rest:Inverse(), passed by callers that cache it (the client player, every frame).
function Kit.transform(rest, v, restInv)
	return (restInv or rest:Inverse()) * (CFrame.new(v[1] or 0, v[2] or 0, v[3] or 0)
		* CFrame.Angles(math.rad(v[4] or 0), math.rad(v[5] or 0), math.rad(v[6] or 0))) * rest
end

-- Easing of a clip between two keys: Linear, or Cubic InOut (Roblox's default for these clips).
function Kit.ease(clip, alpha)
	if clip.easing == "Linear" then return alpha end
	if alpha < 0.5 then return 4 * alpha * alpha * alpha end
	local f = -2 * alpha + 2
	return 1 - f * f * f / 2
end

-- The clip's local time for an elapsed time t: loops wrap, one-shots clamp to [0, length].
function Kit.localTime(clip, t)
	local length = clip.length
	if length <= 0 then return 0 end
	if clip.loop then
		t = t % length
		if t < 0 then t += length end
		return t
	end
	return math.clamp(t, 0, length)
end

local function blend(out, a, b, w)
	for bone, va in pairs(a) do
		local vb = b[bone] or ZERO
		local o = out[bone] or table.create(6, 0)
		for i = 1, 6 do
			local x = va[i] or 0
			o[i] = x + ((vb[i] or 0) - x) * w
		end
		out[bone] = o
	end
	for bone, vb in pairs(b) do
		if a[bone] == nil then
			local o = out[bone] or table.create(6, 0)
			for i = 1, 6 do o[i] = (vb[i] or 0) * w end
			out[bone] = o
		end
	end
	return out
end

-- { Bone = {6 numbers} } at elapsed time t, interpolated between the surrounding keys with the clip's easing. A looping
-- clip whose last key is before its length eases from the last key back to the first. `out` (optional) is reused: its
-- bones that this sample does not touch are set back to rest (zeros).
function Kit.sample(clip, t, out)
	if out then
		for _, v in pairs(out) do
			for i = 1, 6 do v[i] = 0 end
		end
	else
		out = {}
	end
	local keys = clip.keys
	local count = #keys
	if count == 0 then return out end
	t = Kit.localTime(clip, t)
	local first, last = keys[1], keys[count]
	if count == 1 or t <= first.t and not (clip.loop and first.t > 0) then
		return blend(out, first.pose, first.pose, 0)
	end
	if t >= last.t then
		if clip.loop and clip.length > last.t then
			local span = clip.length - last.t + first.t
			return blend(out, last.pose, first.pose, Kit.ease(clip, (t - last.t) / span))
		end
		return blend(out, last.pose, last.pose, 0)
	end
	if t < first.t then -- loop whose first key is after 0: still between the last key and the first
		local span = clip.length - last.t + first.t
		return blend(out, last.pose, first.pose, Kit.ease(clip, (t + clip.length - last.t) / span))
	end
	for index = 1, count - 1 do
		local a, b = keys[index], keys[index + 1]
		if t <= b.t then
			local span = b.t - a.t
			local alpha = span > 0 and (t - a.t) / span or 1
			return blend(out, a.pose, b.pose, Kit.ease(clip, alpha))
		end
	end
	return blend(out, last.pose, last.pose, 0)
end

-- A clip module with the existing API from generated data { ORDER, CLIPS, IDS? }.
function Kit.define(data)
	assert(type(data.ORDER) == "table" and type(data.CLIPS) == "table", "clip data needs ORDER and CLIPS")
	for _, name in ipairs(data.ORDER) do
		local clip = data.CLIPS[name]
		assert(clip, "ORDER names a missing clip " .. tostring(name))
		assert(Kit.PRIORITY[clip.priority], name .. ": unknown priority " .. tostring(clip.priority))
		local previous = -math.huge
		for _, key in ipairs(clip.keys) do
			assert(key.t >= previous, name .. ": key times must not decrease")
			previous = key.t
		end
	end
	local Clips = { ORDER = data.ORDER, CLIPS = data.CLIPS, IDS = data.IDS or {} }

	function Clips.animationId(name)
		local id = Clips.IDS[name]
		assert(id, "no published clip named " .. tostring(name))
		return "rbxassetid://" .. string.format("%d", id)
	end

	-- The KeyframeSequence of one clip for the given prefab, which must be at rest (every Bone.Transform identity).
	function Clips.build(prefab, name)
		local clip = Clips.CLIPS[name]
		assert(clip, "no clip named " .. tostring(name))
		local root = prefab.PrimaryPart
		local pivot = prefab:GetPivot()
		local linear = clip.easing == "Linear"
		local sequence = Instance.new("KeyframeSequence")
		sequence.Name = name
		sequence.Loop = clip.loop
		sequence.Priority = Kit.PRIORITY[clip.priority]
		local function addPoses(parentPose, instance, pose)
			for _, child in ipairs(instance:GetChildren()) do
				if child:IsA("Bone") then
					local item = Instance.new("Pose")
					item.Name = child.Name
					if linear then
						item.EasingStyle = Enum.PoseEasingStyle.Linear
					else
						item.EasingStyle = Enum.PoseEasingStyle.Cubic
						item.EasingDirection = Enum.PoseEasingDirection.InOut
					end
					local v = pose[child.Name]
					if v then
						item.CFrame = Kit.transform(pivot:ToObjectSpace(child.WorldCFrame).Rotation, v)
					end
					item.Parent = parentPose
					addPoses(item, child, pose)
				end
			end
		end
		for _, key in ipairs(clip.keys) do
			local keyframe = Instance.new("Keyframe")
			keyframe.Time = key.t
			local base = Instance.new("Pose")
			base.Name = root.Name
			base.Weight = 0
			base.Parent = keyframe
			addPoses(base, root, key.pose)
			keyframe.Parent = sequence
		end
		return sequence
	end

	return Clips
end

return Kit
