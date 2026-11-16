-- Live animation of the six Caramelo critters with NO published Animation asset (odd/tasks/wildbound-candy-critters.md).
-- It samples each creature's clip data (ReplicatedStorage.WildboundCandyCritterClips<Name>, via WildboundCandyClipKit)
-- and writes Bone.Transform every Heartbeat, the same live path WildboundBeastAnim uses for the wave-2 beasts.
-- Models: any Model named after one of the six (or with attribute WildboundCritter = <name>) inside
--   * Workspace.WildboundNewCandyPreview: a default loop (Duquesa SitIdle, Mielita Fly, the rest Idle) with a short
--     one-shot every few seconds, then back to the loop;
--   * Workspace.WildboundBeastsLocal (the beast client's live clones): the clip comes from the BeastPhase attribute
--     through the per-creature PHASE map below (unknown phase -> the idle loop).
-- Rest is read once per model from the bone CFrame chain (independent of any Transform already written). Clips
-- cross-fade over FADE seconds. Models farther than FAR studs from the camera are skipped; a model is dropped when it
-- leaves the DataModel. If the model carries a "Clip_<name>" attribute (a published Animation id) for the clip it
-- should play, that clip is left to the Animator: its bones go back to rest here and nothing is written.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage:WaitForChild("WildboundCandyClipKit"))

local FADE = 0.15
local FAR = 250
local PREVIEW_FOLDER = "WildboundNewCandyPreview"
local BEASTS_FOLDER = "WildboundBeastsLocal"

-- idle: the default loop. extras: preview one-shots. phase: BeastPhase -> clip for live clones.
local CALM = { "Spawn", "Calm", "Dormant", "Patrol", "Guard", "Wake", "Return", "Disengage", "Ended", "GiveUp", "Recover" }
local function phases(idle, map)
	local out = {}
	for _, name in ipairs(CALM) do out[name] = idle end
	for name, clip in pairs(map) do out[name] = clip end
	return out
end
local SPEC = {
	DuquesaBurbuja = { idle = "SitIdle", extras = { "Surprised" }, phase = phases("Idle", {
		Notice = "Surprised", Chase = "Glide", Telegraph = "Charge", Release = "Whip", Strike = "Whip", Attack = "Whip",
		Recover = "Recover", Stagger = "Surprised",
	}) },
	Mochimiau = { idle = "Idle", extras = { "Bounce" }, phase = phases("Idle", {
		Notice = "Bounce", Chase = "Trot", Telegraph = "Charge", Release = "Bounce", Strike = "Bounce", Jump = "Bounce",
	}) },
	Canelin = { idle = "Idle", extras = { "Alert" }, phase = phases("Idle", {
		Notice = "Alert", Chase = "Walk", Telegraph = "Charge", Release = "Spin", Strike = "Spin",
	}) },
	Flanin = { idle = "Idle", extras = { "Wave" }, phase = phases("Idle", {
		Notice = "Wave", Chase = "Walk", Telegraph = "Charge", Release = "Jump", Jump = "Jump", Strike = "Land",
	}) },
	Mielita = { idle = "Fly", extras = { "Pollen" }, phase = phases("Fly", {
		Notice = "Orbit", Chase = "Patrol", Telegraph = "Pollen", Release = "Dash", Strike = "Dash", Stagger = "Dizzy",
	}) },
	GatoRepartidor = { idle = "Idle", extras = { "Call" }, phase = phases("Idle", {
		Notice = "Surprised", Chase = "Run", Telegraph = "Call", Release = "Throw", Strike = "Throw",
	}) },
}
local EXTRA_EVERY = { 5, 9 } -- seconds between preview one-shots (random in this range)

local clipModules = {}
local function clipsOf(name)
	if clipModules[name] == nil then
		local module = ReplicatedStorage:WaitForChild("WildboundCandyCritterClips" .. name, 10)
		clipModules[name] = module and require(module) or false
	end
	return clipModules[name] or nil
end

local states = {} -- [model] = state
local random = Random.new()

local function critterName(model)
	local tagged = model:GetAttribute("WildboundCritter")
	if type(tagged) == "string" and SPEC[tagged] then return tagged end
	if SPEC[model.Name] then return model.Name end
	return nil
end

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
				table.insert(list, { bone = child, name = child.Name, rest = rest, restInv = rest:Inverse(), moved = false })
				walk(child, world)
			end
		end
	end
	walk(root, root.CFrame)
	return #list > 0 and list or nil
end

local function play(state, clipName, now)
	local clip = state.clips.CLIPS[clipName]
	if not clip then
		clipName = state.spec.idle
		clip = state.clips.CLIPS[clipName]
	end
	if not clip or state.current == clipName then return end
	if state.currentClip then
		state.previous, state.previousStart, state.fadeStart = state.currentClip, state.currentStart, now
	end
	state.current, state.currentClip, state.currentStart = clipName, clip, now
	state.model:SetAttribute("WildboundCritterClip", clipName)
end

local function resetBones(state)
	for _, item in ipairs(state.bones) do
		if item.moved then
			item.bone.Transform = CFrame.identity
			item.moved = false
		end
	end
end

local function setup(model, live)
	if states[model] or not model:IsA("Model") then return end
	local name = critterName(model)
	if not name then return end
	states[model] = false -- pending
	task.spawn(function()
		local clips = clipsOf(name)
		local bones
		for _ = 1, 20 do -- streamed models may arrive before their bones
			if not model:IsDescendantOf(game) then break end
			bones = readBones(model)
			if bones then break end
			task.wait(0.5)
		end
		if not clips or not bones or not model:IsDescendantOf(game) then
			states[model] = nil
			return
		end
		local state = {
			model = model, name = name, spec = SPEC[name], clips = clips, bones = bones, live = live,
			bufA = {}, bufB = {}, nextExtraAt = os.clock() + random:NextNumber(EXTRA_EVERY[1], EXTRA_EVERY[2]),
		}
		states[model] = state
		local now = os.clock()
		if live then
			local function onPhase()
				local phase = model:GetAttribute("BeastPhase")
				play(state, phase and state.spec.phase[phase] or state.spec.idle, os.clock())
			end
			state.connection = model:GetAttributeChangedSignal("BeastPhase"):Connect(onPhase)
			onPhase()
		else
			play(state, state.spec.idle, now)
		end
	end)
end

local function drop(model)
	local state = states[model]
	if state and state.connection then state.connection:Disconnect() end
	states[model] = nil
end

local function step(state, now, cameraPosition)
	local model = state.model
	if (model:GetPivot().Position - cameraPosition).Magnitude > FAR then return end
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
	if type(model:GetAttribute("Clip_" .. state.current)) == "string" then
		resetBones(state) -- a published id exists for this clip: the Animator owns it
		return
	end
	local values = Kit.sample(state.currentClip, now - state.currentStart, state.bufA)
	local weight = 1
	local other
	if state.previous then
		weight = (now - state.fadeStart) / FADE
		if weight >= 1 then
			state.previous = nil
			weight = 1
		else
			other = Kit.sample(state.previous, now - state.previousStart, state.bufB)
		end
	end
	local zero = Kit.ZERO
	for _, item in ipairs(state.bones) do
		local v = values[item.name] or zero
		if other then
			local p = other[item.name] or zero
			local mixed = item.mixed or table.create(6, 0)
			item.mixed = mixed
			for i = 1, 6 do mixed[i] = p[i] + (v[i] - p[i]) * weight end
			v = mixed
		end
		if v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0 or v[4] ~= 0 or v[5] ~= 0 or v[6] ~= 0 then
			item.bone.Transform = item.restInv * (CFrame.new(v[1], v[2], v[3])
				* CFrame.Angles(math.rad(v[4]), math.rad(v[5]), math.rad(v[6]))) * item.rest
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
			else
				local ok, problem = pcall(step, state, now, cameraPosition)
				if not ok then
					warn("[WildboundCandyCritterAnim] " .. model.Name .. ": " .. tostring(problem))
					drop(model)
				end
			end
		end
	end
end)

local function watch(folder, live)
	for _, child in ipairs(folder:GetChildren()) do setup(child, live) end
	folder.ChildAdded:Connect(function(child) setup(child, live) end)
	folder.ChildRemoved:Connect(function(child)
		if not child:IsDescendantOf(game) then drop(child) end
	end)
end

local watched = {}
local function consider(child)
	if watched[child] then return end
	if child.Name == PREVIEW_FOLDER then
		watched[child] = true
		watch(child, false)
	elseif child.Name == BEASTS_FOLDER then
		watched[child] = true
		watch(child, true)
	end
end
for _, child in ipairs(workspace:GetChildren()) do consider(child) end
workspace.ChildAdded:Connect(consider)
