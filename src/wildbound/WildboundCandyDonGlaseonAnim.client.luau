-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3): shows Don Glaseon's Latigo de Regaliz on this client.
-- WildboundBeastsClient draws every beast as a client-only clone in workspace.WildboundBeastsLocal and publishes the
-- server's phase on it (attributes BeastPhase and BeastPhaseAt, a server time). Don Glaseon's clone carries the lash's
-- numbers (Latigo_<name>), set by WildboundCandyDonGlaseonService. From the Attack phase this script unrolls a striped
-- pink-and-white licorice ribbon from the right hand down along the lane the beast client drew, then rolls it back in
-- the recovery. It is a picture of what the server decides; nothing here hits anybody.
-- A3 (odd/tasks/wildbound-caramelo-playfix.md): his clips, on the live clone and on the sleeping copy
-- (workspace.DonGlaseonDormant, whose Idle_Breath loop replaced PF5's chest sway), are played by the shared
-- WildboundCandyCritterAnim (live from the clip data, or the published Clip_<name> on the Animator when one exists), so
-- nothing here touches the rig.
local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not folder then return end

local PINK, WHITE = Color3.fromHex("#E23C8A"), Color3.fromHex("#FFF4F8")
local SEGMENTS = 11

local function handOf(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == "Hand_R" then return d end
	end
	return nil
end

-- The ribbon: unrolls from the hand to the end of the lane over the lash, holds, and rolls back in the recovery.
local function ribbon(model, startedAt)
	local seconds = model:GetAttribute("Latigo_ReleaseSeconds") or 0.35
	local length = model:GetAttribute("Latigo_LengthStuds") or 22
	local hand = handOf(model)
	local holder = Instance.new("Folder")
	holder.Name = "LatigoDeRegaliz"
	holder.Parent = workspace
	local links = {}
	for i = 1, SEGMENTS do
		local link = Instance.new("Part")
		link.Name = "Link" .. i
		link.Anchored, link.CanCollide, link.CanQuery, link.CanTouch, link.CastShadow = true, false, false, false, false
		link.Material = Enum.Material.SmoothPlastic
		link.Color = i % 2 == 0 and WHITE or PINK
		link.Transparency = 1
		link.Parent = holder
		links[i] = link
	end
	local pivot = model:GetPivot()
	local finish = pivot.Position + pivot.LookVector * length + Vector3.new(0, 0.6, 0)
	local connection
	local function stop()
		if connection then connection:Disconnect() end
		connection = nil
		holder:Destroy()
	end
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then stop() return end
		local t = workspace:GetServerTimeNow() - startedAt
		-- unroll over the lash, hold a moment, roll back over half a second of the recovery
		local reach = t < seconds and t / seconds or math.max(0, 1 - (t - seconds - 0.15) / 0.5)
		if t > seconds + 0.7 then stop() return end
		local from = hand and hand.TransformedWorldCFrame.Position or (pivot * CFrame.new(6, 6, -2)).Position
		local to = from:Lerp(finish, reach)
		local span = (to - from).Magnitude / SEGMENTS
		for i, link in ipairs(links) do
			local a, b = from:Lerp(to, (i - 1) / SEGMENTS), from:Lerp(to, i / SEGMENTS)
			if span < 0.05 then
				link.Transparency = 1
			else
				link.Transparency = 0
				link.Size = Vector3.new(0.9, 0.9, span)
				link.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
	end)
	return stop
end

local function setup(model)
	if not model:IsA("Model") or model.Name ~= "DonGlaseon" then return end
	local lastLash, stopLash = nil, nil
	local function onPhase()
		if model:GetAttribute("BeastPhase") ~= "Attack" then return end
		local at = model:GetAttribute("BeastPhaseAt")
		if type(at) == "number" and at ~= lastLash then
			lastLash = at
			if stopLash then stopLash() end
			stopLash = ribbon(model, at)
		end
	end
	model:GetAttributeChangedSignal("BeastPhase"):Connect(onPhase)
	onPhase()
end

folder.ChildAdded:Connect(setup)
for _, child in ipairs(folder:GetChildren()) do setup(child) end
