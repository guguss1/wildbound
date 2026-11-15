-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2): plays Tortidragon's clips and shows Abanico de Confites on
-- this client. WildboundBeastsClient draws every beast as a client-only clone in workspace.WildboundBeastsLocal and
-- publishes the server's phase on it (attributes BeastPhase and BeastPhaseAt, a server time). Tortidragon's clone
-- carries an Animator, the published clip ids (Clip_<name>) and the attack's numbers (Abanico_<name>), set by
-- WildboundCandyTortidragonService. This script plays the clip of the current phase (a trot while it moves slowly, a
-- gallop in the chase) and, from the Release phase, flies three big candies from its mouth to the three circles the
-- beast client drew (TortidragonExtras > TortidragonTell > Disc1..3). They are pictures of what the server decides;
-- nothing here hits anybody.
local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not folder then return end

local CLIP = { Spawn = "Idle", Calm = "Idle", Notice = "Alert", Chase = "Run_Quadruped", GiveUp = "Walk_Quadruped",
	Disengage = "Walk_Quadruped", Telegraph = "Attack_Telegraph", Release = "Attack_Release", Recover = "Attack_Recover" }
local LOOPED = { Idle = true, Walk_Quadruped = true, Run_Quadruped = true }
local CANDY = { Color3.fromHex("#3EC9D6"), Color3.fromHex("#F6C343"), Color3.fromHex("#E0263C") }
local EDGE = Color3.fromHex("#4A1608")

-- The three circle centres the beast client drew for the Tortidragon tell nearest to this clone.
local function landing(model)
	local extras = folder:FindFirstChild("TortidragonExtras")
	local best, bestDistance = nil, math.huge
	local here = model:GetPivot().Position
	for _, holder in ipairs(extras and extras:GetChildren() or {}) do
		if holder.Name == "TortidragonTell" then
			local points = {}
			for i = 1, 3 do
				local disc = holder:FindFirstChild("Disc" .. i)
				if disc then points[i] = disc.Position end
			end
			if #points == 3 then
				local distance = (points[2] - here).Magnitude
				if distance < bestDistance then best, bestDistance = points, distance end
			end
		end
	end
	return best
end

-- Three candies on short arcs from the mouth to the circles over the release.
local function volley(model, startedAt)
	local points = landing(model)
	if not points then return function() end end
	local seconds = model:GetAttribute("Abanico_ReleaseSeconds") or 0.65
	local mouth = model:GetPivot() * CFrame.new(0, 7.2, -4.2)
	local holder = Instance.new("Folder")
	holder.Name = "AbanicoDeConfites"
	holder.Parent = workspace
	local candies = {}
	for i = 1, 3 do
		local candy = Instance.new("Part")
		candy.Name = "Confite" .. i
		candy.Shape = Enum.PartType.Ball
		candy.Size = Vector3.new(1.3, 1.3, 1.3)
		candy.Anchored, candy.CanCollide, candy.CanQuery, candy.CanTouch, candy.CastShadow = true, false, false, false, false
		candy.Material = Enum.Material.SmoothPlastic
		candy.Color = CANDY[i]
		local outline = Instance.new("SelectionSphere")
		outline.Adornee, outline.Color3, outline.Transparency = candy, EDGE, 0.3
		outline.Parent = candy
		candy.Parent = holder
		candies[i] = candy
	end
	local connection
	local function stop()
		if connection then connection:Disconnect() end
		connection = nil
		holder:Destroy()
	end
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then stop() return end
		local t = (workspace:GetServerTimeNow() - startedAt) / seconds
		if t >= 1 then stop() return end
		for i, candy in ipairs(candies) do
			local from, to = mouth.Position, points[i] + Vector3.new(0, 0.6, 0)
			local p = from:Lerp(to, math.clamp(t, 0, 1))
			candy.Position = p + Vector3.new(0, 4 * t * (1 - t) * 3, 0) -- a 3-stud arc
		end
	end)
	return stop
end

local function setup(model)
	if not model:IsA("Model") or model.Name ~= "Tortidragon" then return end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then return end
	local tracks, current, lastVolley, stopVolley = {}, nil, nil, nil
	local function play()
		local phase = model:GetAttribute("BeastPhase")
		if phase == "Release" then
			local at = model:GetAttribute("BeastPhaseAt")
			if type(at) == "number" and at ~= lastVolley then
				lastVolley = at
				if stopVolley then stopVolley() end
				stopVolley = volley(model, at)
			end
		end
		local name = CLIP[phase] or "Idle"
		if name == current then return end
		if current and tracks[current] then tracks[current]:Stop(0.15) end
		current = name
		if not tracks[name] then
			local id = model:GetAttribute("Clip_" .. name)
			if type(id) ~= "string" then return end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			tracks[name] = animator:LoadAnimation(animation)
			tracks[name].Looped = LOOPED[name] == true
		end
		tracks[name]:Play(0.15)
		model:SetAttribute("TortidragonClip", name)
	end
	model:GetAttributeChangedSignal("BeastPhase"):Connect(play)
	play()
end

folder.ChildAdded:Connect(setup)
for _, child in ipairs(folder:GetChildren()) do setup(child) end
