-- Delivery D10: layered horror audio, played only from replicated state (the threat level and hiding attributes
-- the world server publishes, the phase and Reduced attributes and the hit hook the world client sets, the carried
-- capsule's sound cue). Every id comes from WildboundAudioCatalog and every volume from WildboundAudioMix. The
-- server never waits on audio, and a sound that fails to load is skipped. docs/mechanics/wildbound-delivery-d.md 4-5.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local catalogModule = ReplicatedStorage:WaitForChild("WildboundAudioCatalog", 10)
local mixModule = ReplicatedStorage:WaitForChild("WildboundAudioMix", 10)
local worldGui = player:WaitForChild("PlayerGui"):WaitForChild("WildboundWorldUI", 30)
if not (catalogModule and mixModule and worldGui) then
	warn("Wildbound audio: catalog, mix or world interface missing; audio off.")
	return
end
if SoundService:FindFirstChild("WildboundMix") then
	warn("Wildbound audio already exists; duplicate controller refused.")
	return
end
local Catalog, Mix = require(catalogModule), require(mixModule)

local connections = {}
local function listen(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local master = Instance.new("SoundGroup")
master.Name = "WildboundMix"
local groups = {}
for _, name in ipairs(Catalog.GROUPS) do
	local group = Instance.new("SoundGroup")
	group.Name, group.Parent = name, master
	groups[name] = group
end
-- Hidden: the world beds and the music are muffled, as if heard from inside the bush.
local muffles = {}
for _, name in ipairs({ "Ambient", "Music" }) do
	local effect = Instance.new("EqualizerSoundEffect")
	effect.HighGain, effect.MidGain, effect.LowGain, effect.Parent = 0, 0, 0, groups[name]
	muffles[name] = effect
end
local holder = Instance.new("Folder")
holder.Name = "WildboundSounds"
master.Parent = SoundService
holder.Parent = SoundService

-- Load check: one probe per id; a failed or moderated id is never used and the slot falls back or stays silent.
local failed, loaded = {}, {}
task.spawn(function()
	local probes = {}
	for _, entry in pairs(Catalog.SOUNDS) do
		for _, id in ipairs(entry.ids) do
			if not probes[id] then
				local probe = Instance.new("Sound")
				probe.SoundId = "rbxassetid://" .. id
				probes[id] = probe
			end
		end
	end
	local list = {}
	for _, probe in pairs(probes) do table.insert(list, probe) end
	pcall(function()
		ContentProvider:PreloadAsync(list, function(content, status)
			local id = tonumber(string.match(content, "%d+$"))
			if id then
				if status == Enum.AssetFetchStatus.Success then loaded[id] = true else failed[id] = true end
			end
		end)
	end)
	local names = {}
	for id in pairs(failed) do table.insert(names, tostring(id)) end
	master:SetAttribute("FailedIds", table.concat(names, ","))
	for _, probe in pairs(probes) do probe:Destroy() end
end)

local count = 0
-- The only place a Sound is made: a known slot, a loaded or not yet failed id, a group, and the instance cap.
local function newSound(slot, parent)
	local entry = Catalog.SOUNDS[slot]
	if not entry or count >= Mix.LIMITS.sounds then return nil end
	local chosen
	for _, id in ipairs(entry.ids) do
		if not failed[id] then chosen = id break end
	end
	if not chosen then return nil end
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId, sound.Looped = slot, "rbxassetid://" .. chosen, entry.loop
	sound.PlaybackSpeed, sound.Volume = entry.pitch, 0
	sound.SoundGroup = groups[entry.group]
	if entry.spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance, sound.RollOffMaxDistance = Mix.rollOff(slot)
	end
	count += 1
	sound.Destroying:Once(function() count -= 1 end)
	sound.Parent = parent or holder
	return sound
end
local function fadeTo(sound, volume, seconds)
	TweenService:Create(sound, TweenInfo.new(math.max(seconds, 0.05)), { Volume = volume }):Play()
end
-- A one-shot fades in over at least 80 ms and removes itself when it ends.
local function playOnce(slot, parent, volume, fadeIn, pitch)
	local sound = newSound(slot, parent)
	if not sound then return nil end
	if pitch then sound.PlaybackSpeed = pitch end
	sound:Play()
	fadeTo(sound, volume, math.max(fadeIn or 0.08, 0.08))
	sound.Ended:Once(function() sound:Destroy() end)
	task.delay(math.max(sound.TimeLength, 1) + 20, function() if sound.Parent then sound:Destroy() end end)
	return sound
end

local function guardianBody()
	local map = workspace:FindFirstChild("WildboundP0")
	local runtime = map and map:FindFirstChild("WildboundWorldRuntime")
	local guardian = runtime and runtime:FindFirstChild("Silueta")
	local body = guardian and guardian.PrimaryPart
	return body and body:IsA("BasePart") and body or nil
end

-- Looping layers are made when they are wanted and removed once faded out.
local layers, layerTargets = {}, {}
local function setLayer(slot, target, reduced, parent)
	local sound = layers[slot]
	if sound and parent and sound.Parent ~= parent then
		sound:Destroy()
		sound, layers[slot] = nil, nil
	end
	if target <= 0.001 then
		if sound and layerTargets[slot] ~= 0 then
			layerTargets[slot] = 0
			fadeTo(sound, 0, Mix.fadeSeconds(slot, false, reduced))
			task.delay(Mix.fadeSeconds(slot, false, reduced) + 0.1, function()
				if layers[slot] == sound and layerTargets[slot] == 0 then
					sound:Destroy()
					layers[slot] = nil
				end
			end)
		end
		return
	end
	if not sound then
		sound = newSound(slot, parent)
		if not sound then return end
		layers[slot], layerTargets[slot] = sound, 0
		sound:Play() -- a new chase layer always starts from the top
	end
	if math.abs((layerTargets[slot] or 0) - target) > 0.001 then
		fadeTo(sound, target, Mix.fadeSeconds(slot, target > (layerTargets[slot] or 0), reduced))
		layerTargets[slot] = target
	end
end

local state = { level = "Safe", nextAt = {}, lastStep = 0, chaseStartedAt = nil, signatures = 0, defeated = false, hidden = false }
local jumpscare = Mix.newJumpscare()
local chaseSting = Mix.newChaseSting()
local rng = Random.new()
local lastBody, lastBodyPosition, guardianSpeed = nil, nil, 0
local duckUntil = 0
local CollectionService = game:GetService("CollectionService")
local swinging, awakened = {}, {}

local function cue(kind, level, reduced, body, root)
	local shot = Mix.oneShot(kind, reduced)
	local parent = body
	-- The signature and the groan come from its body; everything else sounds from the forest toward it.
	if kind ~= "signature" and kind ~= "groan" then
		local point = root and Mix.cuePosition(root.Position.X, root.Position.Z, body and body.Position.X,
			body and body.Position.Z, rng:NextNumber(), rng:NextNumber())
		if not point then return end
		-- Fear pass (FA3): La Silueta's call comes from twice as far, out in the fog toward it.
		if kind == "call" then
			point = { x = root.Position.X + (point.x - root.Position.X) * 2, z = root.Position.Z + (point.z - root.Position.Z) * 2 }
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "WildboundCue"
		attachment.WorldPosition = Vector3.new(point.x, root.Position.Y, point.z)
		attachment.Parent = workspace.Terrain
		task.delay(8, function() attachment:Destroy() end)
		parent = attachment
	end
	if parent then playOnce(shot.slot, parent, shot.volume, shot.fadeIn) end
end

local function update(dt)
	if state.defeated then return end
	local level = player:GetAttribute("WildboundThreatLevel")
	level = (level == "Distant" or level == "Near" or level == "Chase") and level or "Safe"
	local reduced = worldGui:GetAttribute("Reduced") == true
	local phase = worldGui:GetAttribute("Phase")
	local hidden = type(player:GetAttribute("WildboundHidden")) == "string"
	local now = os.clock()
	local targets = Mix.targets(level, phase, reduced)
	local body = guardianBody()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	master.Volume = Mix.master(reduced) * (now < duckUntil and Mix.DUCK.scale or 1)
	for slot, volume in pairs(targets) do
		if slot == "breathing" then
			setLayer(slot, body and volume or 0, reduced, body)
		elseif slot ~= "steps" and slot ~= "giantSteps" and slot ~= "approach" and slot ~= "creak" then
			setLayer(slot, volume, reduced)
		end
	end
	-- Chase pass (CP1): the player's own breath while sprinting or out of breath, on the same layer as hiding.
	local stance = player:GetAttribute("WildboundStance")
	setLayer("hiddenBreath", Mix.breath(hidden, stance, reduced), reduced)
	-- Fear pass (FA3): the heartbeat in the player's head, from the fear client's intensity (nearest threat, burst).
	local heart = Mix.heart(tonumber(worldGui:GetAttribute("FearHeart")) or 0, reduced)
	setLayer("heartbeat", heart.volume, reduced)
	if layers.heartbeat then layers.heartbeat.PlaybackSpeed = heart.speed end
	if state.hidden ~= hidden then
		state.hidden = hidden
		local goal = hidden and { HighGain = Mix.MUFFLE.highGain, MidGain = Mix.MUFFLE.midGain } or { HighGain = 0, MidGain = 0 }
		for _, effect in pairs(muffles) do TweenService:Create(effect, TweenInfo.new(Mix.MUFFLE.seconds), goal):Play() end
	end
	-- Footsteps: one step per stride at the guardian's measured speed, at most three at once.
	if body ~= lastBody then lastBody, lastBodyPosition = body, body and body.Position end
	if body and lastBodyPosition and dt > 0 then
		local moved = Vector3.new(body.Position.X - lastBodyPosition.X, 0, body.Position.Z - lastBodyPosition.Z).Magnitude
		guardianSpeed += (moved / dt - guardianSpeed) * 0.3
		lastBodyPosition = body.Position
	end
	-- Dread pass: the giant's thumps loop on its body at its gait, over a far approach bed and creaking trees.
	setLayer("giantSteps", body and targets.giantSteps or 0, reduced, body)
	setLayer("approach", body and targets.approach or 0, reduced, body)
	setLayer("creak", body and targets.creak or 0, reduced, body)
	if layers.giantSteps then layers.giantSteps.PlaybackSpeed = Mix.gait(guardianSpeed) end
	local interval = Mix.stepInterval(guardianSpeed)
	if body and targets.steps > 0 and interval and now - state.lastStep >= interval then
		local steps = 0
		for _, child in ipairs(body:GetChildren()) do if child.Name == "steps" then steps += 1 end end
		if steps < Mix.LIMITS.steps then
			state.lastStep = now
			playOnce("steps", body, targets.steps, 0.08, Mix.stepPitch(level))
		end
	end
	-- Chase start: the signature once, then on its schedule (once per chase with Reduced).
	if level == "Chase" and state.level ~= "Chase" then
		state.chaseStartedAt, state.signatures = now, 0
		-- Next batch NB2: a sharp sting in the player's head the moment it sees them, once per cooldown.
		if Mix.chaseStingAllowed(chaseSting, now) then
			Mix.markChaseSting(chaseSting, now)
			local sting = Mix.oneShot("chaseSting", reduced)
			playOnce(sting.slot, nil, sting.volume, sting.fadeIn)
			master:SetAttribute("LastChaseSting", now)
		end
		if body then cue("signature", level, reduced, body, root) state.signatures = 1 end
		-- Chase pass (CP3): the chase opens with a roar from its body (the groan, existing id; quieter with Reduced).
		if body then cue("groan", level, reduced, body, root) end
		if character then
			local capsule = character:FindFirstChild("WildboundCarryCapsule")
			for _, sound in ipairs(capsule and capsule:GetDescendants() or {}) do
				if sound:IsA("Sound") and sound.Name == "fear" then sound:Destroy() end
			end
		end
	end
	-- Chase pass (CP-D5): an island adult's swing is heard as well as seen (the crack, an existing id, on the adult).
	-- Fear pass (FA3): a parent that wakes roars, and roars again on every swing (the lion growl, pitched down).
	for _, adult in ipairs(CollectionService:GetTagged("WildboundIslandAdult")) do
		local swing = adult:GetAttribute("Swing") == true
		local awake = adult:GetAttribute("Awake") == true
		local roar = Mix.oneShot("roar", reduced)
		if swing and not swinging[adult] and adult.PrimaryPart then
			playOnce("crack", adult.PrimaryPart, reduced and 0.3 or 0.6, 0.02, 1.25)
			playOnce(roar.slot, adult.PrimaryPart, roar.volume, roar.fadeIn, 1)
		end
		if awake and not awakened[adult] and adult.PrimaryPart then
			playOnce(roar.slot, adult.PrimaryPart, roar.volume, roar.fadeIn)
		end
		swinging[adult] = swing or nil
		awakened[adult] = awake or nil
	end
	if level ~= state.level then state.nextAt = {} end
	state.level = level
	for _, kind in ipairs({ "snap", "dirt", "whisper", "signature", "crack", "groan", "call" }) do
		local due = state.nextAt[kind]
		if due == nil then
			local delay = Mix.nextDelay(kind, level, reduced, rng:NextNumber())
			state.nextAt[kind] = delay and now + delay or false
		elseif due and now >= due then
			state.nextAt[kind] = nil
			local active = 0
			for _, child in ipairs(workspace.Terrain:GetChildren()) do if child.Name == "WildboundCue" then active += 1 end end
			local once = kind == "signature" and reduced and state.signatures >= 1
			if active < Mix.LIMITS.snaps and not once and ((kind ~= "signature" and kind ~= "groan") or body) then
				cue(kind, level, reduced, body, root)
				if kind == "signature" then state.signatures += 1 end
			end
		end
	end
end

-- Hits and defeats: the world client names the hook (LastHitSound) and stamps it (LastHitAt, server time).
listen(worldGui:GetAttributeChangedSignal("LastHitAt"), function()
	local at, kind = worldGui:GetAttribute("LastHitAt"), worldGui:GetAttribute("LastHitSound")
	local now = workspace:GetServerTimeNow()
	if not Mix.fresh(at, now) then return end
	local reduced = worldGui:GetAttribute("Reduced") == true
	if kind == "hit" then
		local shot = Mix.oneShot("hit", reduced)
		playOnce(shot.slot, nil, shot.volume, shot.fadeIn)
		duckUntil = os.clock() + Mix.DUCK.seconds
	elseif kind == "defeat" then
		-- The chase and every layer are cut first, so the stinger never lands on a fading chase.
		state.defeated = true
		for name, group in pairs(groups) do
			if name ~= "Impact" then TweenService:Create(group, TweenInfo.new(0.15), { Volume = 0 }):Play() end
		end
		local shot = Mix.oneShot("stinger", reduced)
		local stingerId = Catalog.SOUNDS[shot.slot] and Catalog.SOUNDS[shot.slot].ids[1]
		local ready = stingerId ~= nil and loaded[stingerId] == true
		local life = player.Character
		task.delay(0.2, function()
			if Mix.jumpscareAllowed(jumpscare, os.clock(), life, ready) then
				Mix.markJumpscare(jumpscare, os.clock(), life)
				playOnce(shot.slot, nil, shot.volume, shot.fadeIn)
				master:SetAttribute("LastStinger", shot.slot)
			else
				local hit = Mix.oneShot("hit", reduced)
				playOnce(hit.slot, nil, hit.volume, hit.fadeIn)
				master:SetAttribute("LastStinger", "refused")
			end
			master:SetAttribute("StingerCount", (master:GetAttribute("StingerCount") or 0) + 1)
		end)
	end
end)
-- Fear pass (FA3): the fear client's cues. A grab is an alarm: the stinger (the soft one with Efectos suaves).
listen(worldGui:GetAttributeChangedSignal("FearCueAt"), function()
	local at, kind = worldGui:GetAttribute("FearCueAt"), worldGui:GetAttribute("FearCue")
	if not Mix.fresh(at, workspace:GetServerTimeNow()) or state.defeated then return end
	if kind == "grab" then
		local shot = Mix.oneShot("stinger", worldGui:GetAttribute("Reduced") == true)
		playOnce(shot.slot, nil, shot.volume, shot.fadeIn)
		master:SetAttribute("LastFearCue", kind)
	elseif kind == "stalk" and worldGui:GetAttribute("Reduced") ~= true then
		-- A stalk sighting: a faint whisper from where it stands (never with Efectos suaves).
		local spot = worldGui:GetAttribute("StalkSpot")
		if typeof(spot) == "Vector3" then
			local attachment = Instance.new("Attachment")
			attachment.Name = "WildboundCue"
			attachment.WorldPosition = spot
			attachment.Parent = workspace.Terrain
			task.delay(8, function() attachment:Destroy() end)
			local shot = Mix.oneShot("whisper", false)
			playOnce(shot.slot, attachment, shot.volume, shot.fadeIn)
			master:SetAttribute("LastFearCue", kind)
		end
	end
end)
-- Layers come back 2 s after respawn, fading in over 2 s.
listen(player.CharacterAdded, function()
	task.delay(2, function()
		state.defeated = false
		for _, group in pairs(groups) do TweenService:Create(group, TweenInfo.new(2), { Volume = 1 }):Play() end
	end)
end)
-- B2 hook: the carried creature's unease and fear cues, 3D on the capsule, once per server cue.
local lastCueAt
listen(RunService.Heartbeat, function()
	local character = player.Character
	local capsule = character and character:FindFirstChild("WildboundCarryCapsule")
	if not capsule then return end
	local at, kind = capsule:GetAttribute("SoundCueAt"), capsule:GetAttribute("SoundCue")
	if at == lastCueAt or (kind ~= "unease" and kind ~= "fear") then return end
	lastCueAt = at
	local part = capsule:IsA("BasePart") and capsule or capsule:FindFirstChildWhichIsA("BasePart", true)
	if part and state.level ~= "Chase" then playOnce(kind, part, kind == "fear" and 0.20 or 0.15, 0.08) end
end)

local accumulator = 0
listen(RunService.Heartbeat, function(dt)
	accumulator += dt
	if accumulator < 0.25 then return end
	local step = accumulator
	accumulator = 0
	local ok, message = pcall(update, step)
	if not ok then master:SetAttribute("LastError", tostring(message)) end
end)

local function cleanup()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	holder:Destroy()
	master:Destroy()
	for _, child in ipairs(workspace.Terrain:GetChildren()) do
		if child.Name == "WildboundCue" then child:Destroy() end
	end
end
listen(script.Destroying, cleanup)
listen(worldGui.Destroying, cleanup)
