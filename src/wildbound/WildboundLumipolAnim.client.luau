-- Lumipol rig pass (user, 2026-11-11): every rigged Lumipol (tag "WildboundLumipolRig", set by WildboundLumipolArt)
-- moves its bones on this client only. A sleeping island parent (attribute Awake == false) plays Sleep; an awake one
-- plays Run when it moves fast (the chase, CHASE_SPEED 19) and Walk when it moves slowly (the walk home, RETURN_SPEED 8);
-- standing still it holds its rest pose. Wild Lumipols and crias follow the same speed rule. A Lumipol inside a
-- player's character (the carried capsule) is left at rest.
-- The poses come from WildboundLumipolAnimData (baked from Blender) and are written to Bone.Transform here, so no
-- uploaded animation is needed. If the place owner publishes the three KeyframeSequences
-- (ServerStorage.WildboundAssets.LumipolAnims), set this script's attributes SleepAnimationId / WalkAnimationId /
-- RunAnimationId ("rbxassetid://...") and the Animator plays those instead.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TAG = "WildboundLumipolRig"
local RUN_ABOVE = 9.5 -- studs/s: faster than this is the chase (Play: the chase lunges at 10-13, the walk home is 8)
local WALK_ABOVE = 1.2 -- studs/s: slower than this is standing still
local WALK_RATE_SPEED = 8 -- the walk clip plays at rate 1 at this speed
local RUN_RATE_SPEED = 19
local FADE = 0.25 -- seconds to blend from one clip to the next
local HOLD = 0.5 -- seconds a moving clip (Walk, Run, Rest) is kept before it may change
local RANGE = 220 -- studs from the camera; farther rigs are not animated

local Rig = require(ReplicatedStorage:WaitForChild("WildboundLumipolRig", 20))
local data = require(ReplicatedStorage:WaitForChild("WildboundLumipolAnimData", 20))

local cache = {} -- scale key -> clips
local active = {} -- model -> entry

local function publishedIds()
	local ids = {}
	for _, name in ipairs({ "Sleep", "Walk", "Run" }) do
		local id = script:GetAttribute(name .. "AnimationId")
		if type(id) == "string" and id ~= "" then ids[name] = id end
	end
	return ids
end
local published = publishedIds()

local function carried(model)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and model:IsDescendantOf(player.Character) then return true end
	end
	return false
end

local BONE_COUNT = 0
for _ in pairs(data.restPos) do BONE_COUNT += 1 end

local function setup(model, tries)
	if active[model] or not model:IsA("Model") or not model.Parent then return end
	local rig = Rig.find(model)
	local count = 0
	if rig then for _ in pairs(rig.bones) do count += 1 end end
	if count < BONE_COUNT then
		-- StreamingEnabled: the mesh or its bones may still be on the way.
		tries = (tries or 0) + 1
		if tries <= 40 then task.delay(0.5, setup, model, tries) end
		return
	end
	local fit = Rig.fit(data, rig)
	if not fit then
		model:SetAttribute("LumipolAnimError", "fit failed")
		return
	end
	local entry = { model = model, rig = rig, time = 0, state = nil, from = nil, fromTime = 0, fade = 0,
		last = model:GetPivot().Position, speed = 0, carried = carried(model) }
	if published.Sleep and published.Walk and published.Run then
		local animator = model:FindFirstChildWhichIsA("Animator", true)
		if animator then
			entry.tracks = {}
			for name, id in pairs(published) do
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
				if ok and track then
					track.Looped = true
					entry.tracks[name] = track
				end
			end
		end
	end
	if not entry.tracks then
		local key = string.format("%.2f", fit.s)
		cache[key] = cache[key] or Rig.build(data, rig, fit)
		local clips = cache[key]
		-- The cached clips belong to the first rig of that size; map them onto this rig's bones by name.
		entry.clips = {}
		for name, clip in pairs(clips) do
			local keys = {}
			for _, k in ipairs(clip.keys) do
				local pose = {}
				for bone, cf in pairs(k.pose) do
					local mine = rig.bones[bone.Name]
					if mine then pose[mine] = cf end
				end
				table.insert(keys, { t = k.t, pose = pose })
			end
			entry.clips[name] = { length = clip.length, keys = keys }
		end
	end
	model:SetAttribute("LumipolAnimFit", string.format("err %.3f s %.3f n %d", fit.err, fit.s, fit.count))
	active[model] = entry
end

local function wanted(entry, dt)
	local model = entry.model
	local position = model:GetPivot().Position
	local flat = Vector3.new(position.X - entry.last.X, 0, position.Z - entry.last.Z)
	entry.last = position
	local speed = dt > 0 and flat.Magnitude / dt or 0
	if speed > 200 then speed = 0 end -- a teleport, not a run
	-- Replicated positions arrive in uneven steps, so the speed is smoothed over about half a second, a clip is
	-- left only below a lower speed than the one that starts it, and each clip is held at least HOLD seconds.
	entry.speed += (speed - entry.speed) * math.min(1, dt * 2.5)
	entry.held = (entry.held or 0) + dt
	if entry.carried then return nil, 0 end
	if model:GetAttribute("Awake") == false then return "Sleep", 1 end
	local current, s = entry.state, entry.speed
	local pick
	if s > RUN_ABOVE or (current == "Run" and s > RUN_ABOVE - 2) then
		pick = "Run"
	elseif s > WALK_ABOVE or (current == "Walk" and s > WALK_ABOVE * 0.5) or (current == "Run" and s > WALK_ABOVE) then
		pick = "Walk"
	end
	if pick ~= current and current ~= "Sleep" and entry.held < HOLD then pick = current end
	if pick ~= current then entry.held = 0 end
	if pick == "Run" then return "Run", math.clamp(s / RUN_RATE_SPEED, 0.6, 1.6) end
	if pick == "Walk" then return "Walk", math.clamp(s / WALK_RATE_SPEED, 0.4, 1.6) end
	return nil, 0
end

local scratchA, scratchB = {}, {}
local function step(entry, dt, camera)
	local state, rate = wanted(entry, dt)
	if entry.tracks then
		for name, track in pairs(entry.tracks) do
			if name == state then
				if not track.IsPlaying then track:Play(FADE) end
				track:AdjustSpeed(rate)
			elseif track.IsPlaying then
				track:Stop(FADE)
			end
		end
		return
	end
	if state ~= entry.state then
		entry.from, entry.fromTime, entry.fade = entry.state, entry.time, FADE
		entry.state, entry.time = state, 0
		-- QA: the clip this client plays ("Sleep", "Walk", "Run" or "Rest").
		entry.model:SetAttribute("LumipolAnimState", state or "Rest")
	end
	entry.time += dt * rate
	if entry.fade > 0 then entry.fade = math.max(0, entry.fade - dt) end
	if camera and (camera.CFrame.Position - entry.last).Magnitude > RANGE then return end
	local bones = entry.rig.bones
	local now = state and Rig.sample(entry.clips[state], entry.time, scratchA) or nil
	local before = entry.fade > 0 and entry.from and Rig.sample(entry.clips[entry.from], entry.fromTime, scratchB) or nil
	local alpha = entry.fade > 0 and 1 - entry.fade / FADE or 1
	for _, bone in pairs(bones) do
		local target = now and now[bone] or CFrame.identity
		if entry.fade > 0 then
			local source = before and before[bone] or CFrame.identity
			target = source:Lerp(target, alpha)
		end
		bone.Transform = target
	end
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do task.spawn(setup, model) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
	-- The server parents the art parts right after tagging; give replication a moment.
	task.delay(0.2, setup, model)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model) active[model] = nil end)

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	for model, entry in pairs(active) do
		if not model.Parent then
			active[model] = nil
		else
			local ok, message = pcall(step, entry, dt, camera)
			if not ok then
				model:SetAttribute("LumipolAnimError", tostring(message))
				active[model] = nil
			end
		end
	end
end)
