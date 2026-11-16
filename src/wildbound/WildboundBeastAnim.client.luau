-- Wave 2 beast animations (odd/tasks/wildbound-beasts-wave2.md): a rigged Streamer, Root, Gaze or Lurker that
-- WildboundBeastsClient draws (workspace.WildboundBeastsLocal, client-only clones) moves its bones on this client.
-- The clips are the Blender actions of assets/bestias_rig/<beast>, baked into WildboundBeastAnim<Beast> and written to
-- Bone.Transform here (the Lumipol approach, WildboundLumipolRig: no uploaded animation, works live). Which clip plays
-- comes from WildboundBeastAnimPlan and the phase the beast client publishes on the model (attributes BeastPhase,
-- BeastPhaseAt, BeastPhaseUntil). A model without bones (the Part proxies) is left alone. QA attributes on the model:
-- BeastAnimFit, BeastAnimClip, BeastAnimError.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rig = require(ReplicatedStorage:WaitForChild("WildboundLumipolRig", 20))
local Plan = require(ReplicatedStorage:WaitForChild("WildboundBeastAnimPlan", 20))

local FADE = 0.2 -- seconds to blend from one clip to the next
local RANGE = 250 -- studs from the camera; farther rigs are not posed

local dataCache = {} -- beast -> data module (or false)
local clipCache = {} -- beast .. scale -> clips
local active = {} -- model -> entry

local function dataFor(beast)
	if dataCache[beast] == nil then
		local module = ReplicatedStorage:FindFirstChild("WildboundBeastAnim" .. beast)
		local ok, data = false, nil
		if module and module:IsA("ModuleScript") then ok, data = pcall(require, module) end
		dataCache[beast] = ok and type(data) == "table" and data or false
	end
	return dataCache[beast] or nil
end

local function rigOnPart(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item:FindFirstChildWhichIsA("Bone") then
			local bones = {}
			for _, bone in ipairs(item:GetDescendants()) do
				if bone:IsA("Bone") then bones[bone.Name] = bone end
			end
			return { mesh = item, bones = bones }
		end
	end
	return nil
end

local function setup(model)
	if active[model] or not model:IsA("Model") or not model.Parent then return end
	if not Plan.PLANS[model.Name] then return end
	-- BR1/BR2 (odd/tasks/wildbound-beast-revision.md): the uploaded Viper and Pouncer FBX imports keep their bones under
	-- the plain "RootPart" Part (their MeshParts are skinned to those bones), not under a MeshPart: accept that holder too.
	local rig = Rig.find(model) or rigOnPart(model)
	if not rig then return end -- a proxy: nothing to animate
	local data = dataFor(model.Name)
	if not data then
		model:SetAttribute("BeastAnimError", "no data")
		return
	end
	local fit = Rig.fit(data, rig)
	if not fit then
		model:SetAttribute("BeastAnimError", "fit failed")
		return
	end
	local key = model.Name .. string.format("%.3f", fit.s)
	clipCache[key] = clipCache[key] or Rig.build(data, rig, fit)
	-- The cached clips belong to the first rig of this beast and size; map them onto this clone's bones by name.
	local clips, lengths = {}, {}
	for name, clip in pairs(clipCache[key]) do
		local keys = {}
		for _, k in ipairs(clip.keys) do
			local pose = {}
			for bone, cf in pairs(k.pose) do
				local mine = rig.bones[bone.Name]
				if mine then pose[mine] = cf end
			end
			table.insert(keys, { t = k.t, pose = pose })
		end
		clips[name] = { length = clip.length, keys = keys }
		lengths[name] = clip.length
	end
	model:SetAttribute("BeastAnimFit", string.format("err %.3f s %.3f n %d", fit.err, fit.s, fit.count))
	active[model] = { model = model, beast = model.Name, rig = rig, clips = clips, lengths = lengths,
		last = model:GetPivot(), speed = 0, phase = nil, run = nil, from = nil, fade = 0 }
end

local function sample(entry, clip, time, oneShot, out)
	local c = entry.clips[clip]
	if not c then return nil end
	if oneShot then time = math.clamp(time, 0, math.max(c.length - 1e-3, 0)) end
	return Rig.sample(c, time, out)
end

local scratchA, scratchB = {}, {}
local function step(entry, dt, camera)
	local model = entry.model
	-- Forward speed from the pivot the beast client places every frame (negative when backing off).
	local pivot = model:GetPivot()
	local delta = pivot.Position - entry.last.Position
	entry.last = pivot
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local raw = dt > 0 and flat.Magnitude / dt or 0
	if raw > 120 then raw = 0 end -- a blink or a teleport, not a run
	if flat.Magnitude > 1e-4 and flat:Dot(pivot.LookVector) < 0 then raw = -raw end
	entry.speed += (raw - entry.speed) * math.min(1, dt * 6)

	local phase = model:GetAttribute("BeastPhase") or "Spawn"
	local phaseAt = model:GetAttribute("BeastPhaseAt")
	if phase ~= entry.phase or phaseAt ~= entry.phaseAt then
		local previous = entry.phase
		entry.phase, entry.phaseAt = phase, phaseAt
		local untilAt = model:GetAttribute("BeastPhaseUntil")
		local duration = (type(untilAt) == "number" and type(phaseAt) == "number") and untilAt - phaseAt or nil
		-- SC8: Scuttler's Fallen publishes its fall (Crash or Stumble) as BeastPhaseVariant.
		local steps = Plan.steps(entry.beast, previous, phase, model:GetAttribute("BeastPhaseVariant"))
		local current = entry.run and entry.run.clip
		local currentTime = entry.run and entry.run.time
		local run = Plan.start(steps, duration, entry.lengths, current, currentTime, math.abs(entry.speed) > 2)
		if run.clip ~= current and current then
			entry.from = { clip = current, time = currentTime, oneShot = entry.oneShot }
			entry.fade = FADE
		end
		entry.run = run
	end
	local clip, time, oneShot = Plan.advance(entry.run, dt, entry.speed, entry.lengths)
	if clip ~= entry.clip then
		if entry.clip and not entry.from then
			entry.from = { clip = entry.clip, time = entry.time, oneShot = entry.oneShot }
			entry.fade = FADE
		end
		entry.clip = clip
		-- QA: the clip this client plays.
		model:SetAttribute("BeastAnimClip", clip)
	end
	entry.time, entry.oneShot = time, oneShot
	if entry.fade > 0 then
		entry.fade = math.max(0, entry.fade - dt)
		if entry.fade == 0 then entry.from = nil end
	end
	if camera and (camera.CFrame.Position - pivot.Position).Magnitude > RANGE then return end
	local now = clip and sample(entry, clip, time, oneShot, scratchA) or nil
	local before = entry.from and sample(entry, entry.from.clip, entry.from.time, entry.from.oneShot, scratchB) or nil
	local alpha = entry.fade > 0 and 1 - entry.fade / FADE or 1
	for _, bone in pairs(entry.rig.bones) do
		local target = now and now[bone] or CFrame.identity
		if before then target = (before[bone] or CFrame.identity):Lerp(target, alpha) end
		bone.Transform = target
	end
end

local function watch(folder)
	for _, child in ipairs(folder:GetChildren()) do task.defer(setup, child) end
	folder.ChildAdded:Connect(function(child) task.defer(setup, child) end)
	folder.ChildRemoved:Connect(function(child) active[child] = nil end)
end

task.spawn(function()
	watch(workspace:WaitForChild("WildboundBeastsLocal"))
end)

-- Heartbeat like WildboundBeastsClient (it also runs while the Studio window does not render).
RunService.Heartbeat:Connect(function(dt)
	local camera = workspace.CurrentCamera
	for model, entry in pairs(active) do
		if not model.Parent then
			active[model] = nil
		else
			local ok, message = pcall(step, entry, dt, camera)
			if not ok then
				model:SetAttribute("BeastAnimError", tostring(message))
				active[model] = nil
			end
		end
	end
end)
