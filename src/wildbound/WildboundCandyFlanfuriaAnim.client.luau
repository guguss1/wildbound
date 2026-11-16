-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4): plays Flanfuria's clips and shows Onda de Caramelo on this client.
-- WildboundBeastsClient draws every beast as a client-only clone in workspace.WildboundBeastsLocal and publishes the
-- server's phase on it (attributes BeastPhase and BeastPhaseAt, a server time). Flanfuria's clone carries an Animator,
-- the published clip ids (Clip_<name>) and the attack's numbers (Onda_<name>), set by WildboundCandyFlanfuriaService.
-- This script plays the clip of the current phase and, from the Release phase, draws the ring front growing from the
-- flan and then the puddle it leaves. Both are pictures of what the server decides; nothing here slows anybody.
-- The pink floor swallows amber: the ring and the puddle carry a dark edge of dots so they read on it.
-- They lie on the ground, not on the clone (which hops away after the cast), and leaving combat removes them: they go
-- when the beast gives up or its clone disappears.
local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not folder then return end

-- B5 (odd/tasks/wildbound-caramelo-playfix.md): it hops home in Return (it used to fade out where it gave up).
local CLIP = { Spawn = "Idle", Calm = "Idle", Notice = "Alert", Chase = "Hop_Move", Telegraph = "Attack_Telegraph",
	Release = "Attack_Release", Recover = "Attack_Recover", Return = "Hop_Move" }
local LOOPED = { Idle = true, Hop_Move = true }
local CARAMEL, AMBER, EDGE = Color3.fromHex("#8A4B22"), Color3.fromHex("#F2A33A"), Color3.fromHex("#4A1608")
local DOTS = 28

local function flat(name, size, colour, transparency, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.Color, part.Transparency, part.Size = colour, transparency, size
	part.Parent = parent
	return part
end

-- The wave of one cast: a holder with the ring's dots, its amber band and, later, the puddle.
local function wave(model, startedAt)
	local releaseSeconds = model:GetAttribute("Onda_ReleaseSeconds") or 0.8
	local from, to = model:GetAttribute("Onda_RingFrom") or 2, model:GetAttribute("Onda_RingTo") or 11
	local puddleRadius, puddleSeconds = model:GetAttribute("Onda_PuddleRadius") or 4, model:GetAttribute("Onda_PuddleSeconds") or 3
	local centre = model:GetPivot().Position
	local holder = Instance.new("Folder")
	holder.Name = "OndaDeCaramelo"
	holder.Parent = workspace
	local dots = {}
	for i = 1, DOTS do dots[i] = flat("Front", Vector3.new(0.9, 0.5, 0.9), i % 2 == 0 and EDGE or AMBER, 0, holder) end
	local puddle, edge
	local connection
	local function stop()
		if connection then connection:Disconnect() end
		connection = nil
		holder:Destroy()
	end
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then stop() return end
		local t = workspace:GetServerTimeNow() - startedAt
		if t <= releaseSeconds then
			local radius = from + (to - from) * math.clamp(t / releaseSeconds, 0, 1)
			for i, dot in ipairs(dots) do
				local angle = (i / DOTS) * math.pi * 2
				dot.Position = centre + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
			end
			holder:SetAttribute("RingRadius", radius)
			return
		end
		if dots then
			for _, dot in ipairs(dots) do dot:Destroy() end
			dots = nil
			holder:SetAttribute("RingRadius", nil)
			puddle = flat("Puddle", Vector3.new(0.12, puddleRadius * 2, puddleRadius * 2), CARAMEL, 0.15, holder)
			puddle.Shape = Enum.PartType.Cylinder
			puddle.CFrame = CFrame.new(centre + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			edge = {}
			for i = 1, DOTS do
				local angle = (i / DOTS) * math.pi * 2
				edge[i] = flat("PuddleEdge", Vector3.new(0.6, 0.3, 0.6), EDGE, 0, holder)
				edge[i].Position = centre + Vector3.new(math.cos(angle) * puddleRadius, 0.2, math.sin(angle) * puddleRadius)
			end
			holder:SetAttribute("PuddleRadius", puddleRadius)
		end
		local left = releaseSeconds + puddleSeconds - t
		if left <= 0 then stop() return end
		if left < 0.4 then -- dries out
			local fade = 1 - left / 0.4
			puddle.Transparency = 0.15 + 0.85 * fade
			for _, dot in ipairs(edge) do dot.Transparency = fade end
		end
	end)
	return stop
end

local function setup(model)
	if not model:IsA("Model") or model.Name ~= "Flanfuria" then return end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then return end
	-- every rigid piece rides its bone on a RigidConstraint: it must stay unanchored to follow it
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part:FindFirstChild("BoneGrip") then part.Anchored = false end
	end
	local tracks, current, lastWave, stopWave = {}, nil, nil, nil
	local function play()
		local phase = model:GetAttribute("BeastPhase")
		if phase == "Release" then
			local at = model:GetAttribute("BeastPhaseAt")
			if type(at) == "number" and at ~= lastWave then
				lastWave = at
				if stopWave then stopWave() end
				stopWave = wave(model, at)
			end
		elseif (phase == "GiveUp" or phase == "Return" or phase == "Disengage") and stopWave then
			stopWave()
			stopWave = nil
		end
		local name = CLIP[phase] or "Idle"
		if name == current then return end
		if current and tracks[current] then tracks[current]:Stop(0.1) end
		current = name
		if not tracks[name] then
			local id = model:GetAttribute("Clip_" .. name)
			if type(id) ~= "string" then return end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			tracks[name] = animator:LoadAnimation(animation)
			tracks[name].Looped = LOOPED[name] == true
		end
		tracks[name]:Play(0.1)
		model:SetAttribute("FlanfuriaClip", name)
	end
	model:GetAttributeChangedSignal("BeastPhase"):Connect(play)
	play()
end

folder.ChildAdded:Connect(setup)
for _, child in ipairs(folder:GetChildren()) do setup(child) end
