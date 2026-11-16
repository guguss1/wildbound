-- Live animation of the six Caramelo critters (odd/tasks/wildbound-candy-critters-anim.md).
-- With no published Animation asset it samples each creature's clip data (ReplicatedStorage.WildboundCandyCritterClips
-- <Name>, via WildboundCandyClipKit) and writes Bone.Transform every Heartbeat, the same live path WildboundBeastAnim
-- uses for the wave-2 beasts. Which clip plays comes from WildboundCandyCritterAnimSpec.
-- Models: any Model named after one of the six (or with attribute WildboundCritter = <name>) inside
--   * Workspace.WildboundNewCandyPreview: a default loop (Duquesa SitIdle, Mielita Fly, the rest Idle) with a short
--     one-shot every few seconds, then back to the loop;
--   * Workspace.WildboundBeastsLocal (the beast client's live clones): the clip follows the BeastPhase attribute
--     through Spec.clipFor (unknown phase -> the idle loop).
-- Rest is read once per model from the bone CFrame chain (independent of any Transform already written). A clip change
-- cross-fades over Spec.FADE seconds from the pose last written, so a quick chain of changes never snaps. Models farther
-- than Spec.FAR studs from the camera are skipped; a model is dropped when it leaves the DataModel.
-- Published ids: when the model carries a "Clip_<clip>" string attribute for the current clip and has an Animator, this
-- script plays that Animation on the Animator itself (loaded once per clip, Looped from the clip data, stopped on the
-- next clip change or when the model is dropped) and puts the bones back to rest; clips without an id keep the live
-- path. Without an Animator the live path is used even when an id exists.
-- A Heartbeat error resets the model's bones, stops its tracks and retries the model after RETRY_DELAY (MAX_RETRIES).
-- A3 (odd/tasks/wildbound-caramelo-playfix.md): Tortidragon and Don Glaseon too. Their services copy their older
-- { time, pose } clip modules to ReplicatedStorage.WildboundCandyCritterClips<Name>; Spec marks them legacy and
-- Kit.fromLegacy converts them here. Spec.SCENERY models in Workspace (Don Glaseon's sleeping copy) follow their
-- BeastPhase like a live clone. A streamed model is waited for until its bones arrive, however far the player starts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage:WaitForChild("WildboundCandyClipKit"))
local Spec = require(ReplicatedStorage:WaitForChild("WildboundCandyCritterAnimSpec"))

local FADE, FAR, EXTRA_EVERY = Spec.FADE, Spec.FAR, Spec.EXTRA_EVERY
local RETRY_DELAY, MAX_RETRIES = 2, 3

local clipModules = {}
local function clipsOf(name)
	if clipModules[name] == nil then
		local module = ReplicatedStorage:WaitForChild("WildboundCandyCritterClips" .. name, 10)
		if not module then return nil end -- not there yet: the next model of this name tries again
		local data = require(module)
		clipModules[name] = Spec.SPEC[name].legacy and Kit.fromLegacy(data) or data
	end
	return clipModules[name]
end

local states = {} -- [model] = state (false while pending)
local failures = {} -- [model] = Heartbeat errors so far
local random = Random.new()

-- Each bone's rest rotation relative to the model pivot, from the CFrame chain (Transform ignored).
local function readBones(model)
	local root = model.PrimaryPart
	if not root then return nil end
	local pivot = model:GetPivot()
	local list = {}
	local function walk(parent, parentWorld)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("Bone") then
				local world = parentWorld * child.CFrame
				local rest = pivot:ToObjectSpace(world).Rotation
				table.insert(list, {
					bone = child, name = child.Name, rest = rest, restInv = rest:Inverse(), moved = false,
					last = table.create(6, 0), from = table.create(6, 0), mixed = table.create(6, 0),
				})
				walk(child, world)
			end
		end
	end
	walk(root, root.CFrame)
	return #list > 0 and list or nil
end

local function findAnimator(model)
	local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
	return controller and controller:FindFirstChildOfClass("Animator") or nil
end

local function resetBones(state)
	for _, item in ipairs(state.bones) do
		if item.moved then
			item.bone.Transform = CFrame.identity
			item.moved = false
		end
		for i = 1, 6 do item.last[i] = 0 end
	end
end

local function stopTrack(state, fade)
	if state.track then
		state.track:Stop(fade)
		state.track, state.trackClip = nil, nil
	end
end

-- Starts a clip (or the idle loop when the name is unknown). The fade source is the pose last written.
local function play(state, clipName, now)
	local clip = state.clips.CLIPS[clipName]
	if not clip then
		clipName = state.spec.idle
		clip = state.clips.CLIPS[clipName]
	end
	if not clip or state.current == clipName then return end
	if state.current then
		for _, item in ipairs(state.bones) do
			for i = 1, 6 do item.from[i] = item.last[i] end
		end
		state.fading, state.fadeStart = true, now
	end
	state.current, state.currentClip, state.currentStart = clipName, clip, now
	state.model:SetAttribute("WildboundCritterClip", clipName)
end

local function setup(model, live)
	if states[model] ~= nil or not model:IsA("Model") then return end
	local name = Spec.critterName(model)
	if not name then return end
	states[model] = false -- pending
	task.spawn(function()
		local clips = clipsOf(name)
		local bones
		while model:IsDescendantOf(game) and states[model] == false do -- streamed models may arrive before their bones
			bones = readBones(model)
			if bones then break end
			task.wait(0.5)
		end
		if not clips or not bones or not model:IsDescendantOf(game) or states[model] ~= false then
			if states[model] == false then states[model] = nil end
			return
		end
		local state = {
			model = model, name = name, spec = Spec.SPEC[name], clips = clips, bones = bones, live = live, buf = {},
			tracks = {}, trackIds = {}, nextExtraAt = os.clock() + random:NextNumber(EXTRA_EVERY[1], EXTRA_EVERY[2]),
		}
		states[model] = state
		if live then
			local function onPhase()
				play(state, Spec.clipFor(name, model:GetAttribute("BeastPhase"), clips.CLIPS), os.clock())
			end
			state.connection = model:GetAttributeChangedSignal("BeastPhase"):Connect(onPhase)
			onPhase()
		else
			play(state, state.spec.idle, os.clock())
			-- A2 (odd/tasks/wildbound-caramelo-playfix.md): a server cue "<clip>:<serial>" plays that one-shot now, then the
			-- loop comes back (La Duquesa's Charge and Whip when she throws her bubbles from the summit).
			state.connection = model:GetAttributeChangedSignal("WildboundCritterCue"):Connect(function()
				local clip = string.match(tostring(model:GetAttribute("WildboundCritterCue")), "^(%a+):")
				if clip and clips.CLIPS[clip] then play(state, clip, os.clock()) end
			end)
		end
	end)
end

local function drop(model)
	local state = states[model]
	states[model] = nil
	if not state then return end
	if state.connection then state.connection:Disconnect() end
	pcall(stopTrack, state, 0)
	if model:IsDescendantOf(game) then pcall(resetBones, state) end
end

-- Plays the current clip's published Animation on the model's Animator. Returns false when the live path must run.
local function playPublished(state)
	local id = Spec.publishedId(state.model, state.current)
	local animator = id and findAnimator(state.model)
	if not animator then
		stopTrack(state, 0)
		return false
	end
	if state.trackClip ~= state.current then
		stopTrack(state, FADE)
		local track = state.tracks[state.current]
		if not track or state.trackIds[state.current] ~= id then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			track = animator:LoadAnimation(animation)
			track.Looped = state.currentClip.loop == true
			state.tracks[state.current] = track
			state.trackIds[state.current] = id
		end
		track:Play(FADE)
		state.track, state.trackClip = track, state.current
		resetBones(state)
	end
	return true
end

local function step(state, now, cameraPosition)
	local model = state.model
	-- preview: a short one-shot every few seconds, then back to the loop
	if not state.live then
		if state.current == state.spec.idle and now >= state.nextExtraAt then
			local extras = state.spec.extras
			play(state, extras[random:NextInteger(1, #extras)], now)
		elseif state.current ~= state.spec.idle and now - state.currentStart >= state.currentClip.length then
			play(state, state.spec.idle, now)
			state.nextExtraAt = now + random:NextNumber(EXTRA_EVERY[1], EXTRA_EVERY[2])
		end
	end
	if playPublished(state) then return end
	if (model:GetPivot().Position - cameraPosition).Magnitude > FAR then return end
	local values = Kit.sample(state.currentClip, now - state.currentStart, state.buf)
	local weight = 1
	if state.fading then
		weight = (now - state.fadeStart) / FADE
		if weight >= 1 then
			state.fading, weight = false, 1
		end
	end
	local zero = Kit.ZERO
	for _, item in ipairs(state.bones) do
		local v = values[item.name] or zero
		if state.fading then
			local p, mixed = item.from, item.mixed
			for i = 1, 6 do mixed[i] = p[i] + (v[i] - p[i]) * weight end
			v = mixed
		end
		local last = item.last
		for i = 1, 6 do last[i] = v[i] end
		if v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0 or v[4] ~= 0 or v[5] ~= 0 or v[6] ~= 0 then
			item.bone.Transform = Kit.transform(item.rest, v, item.restInv)
			item.moved = true
		elseif item.moved then
			item.bone.Transform = CFrame.identity
			item.moved = false
		end
	end
end

RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	for model, state in pairs(states) do
		if state then
			if not model:IsDescendantOf(game) then
				drop(model)
				failures[model] = nil
			else
				local ok, problem = pcall(step, state, now, cameraPosition)
				if not ok then
					warn("[WildboundCandyCritterAnim] " .. model.Name .. ": " .. tostring(problem))
					drop(model)
					local count = (failures[model] or 0) + 1
					failures[model] = count
					if count <= MAX_RETRIES then
						task.delay(RETRY_DELAY, function()
							if model:IsDescendantOf(game) then setup(model, state.live) end
						end)
					end
				end
			end
		end
	end
end)

local function watch(folder, live)
	for _, child in ipairs(folder:GetChildren()) do setup(child, live) end
	folder.ChildAdded:Connect(function(child) setup(child, live) end)
	folder.ChildRemoved:Connect(function(child)
		if not child:IsDescendantOf(game) then
			drop(child)
			failures[child] = nil
		end
	end)
end

local watched = {}
local function consider(child)
	if watched[child] then return end
	if child.Name == Spec.PREVIEW_FOLDER then
		watched[child] = true
		watch(child, false)
	elseif child.Name == Spec.BEASTS_FOLDER then
		watched[child] = true
		watch(child, true)
	elseif Spec.SCENERY[child.Name] then
		setup(child, true) -- A3: dropped by the Heartbeat when it leaves; set up again each time it comes back
	end
end
for _, child in ipairs(workspace:GetChildren()) do consider(child) end
workspace.ChildAdded:Connect(consider)
