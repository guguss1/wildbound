-- Touch-first capture screen (M3.4). Presentation only: the server owns every outcome, and this script
-- reports nothing about the session except the Stop button's token. The ring is drawn from the server clock.
-- All wording, colours, shapes and placement come from the pure modules WildboundCaptureView and WildboundHudLayout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("WildboundCaptureUI") then
	warn("Wildbound capture screen already exists; duplicate controller refused.")
	return
end
local sessionModule = ReplicatedStorage:WaitForChild("WildboundCaptureSession", 10)
local viewModule = ReplicatedStorage:WaitForChild("WildboundCaptureView", 10)
local layoutModule = ReplicatedStorage:WaitForChild("WildboundHudLayout", 10)
if not (sessionModule and viewModule and layoutModule) then
	warn("Wildbound capture screen: shared modules are missing; controller refused.")
	return
end
local Session, View, Layout = require(sessionModule), require(viewModule), require(layoutModule)

local function make(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties) do item[key] = value end
	item.Parent = parent
	return item
end
local function rgb(value) return Color3.fromRGB(value.r, value.g, value.b) end

-- Above the inventory and the world HUD, so the result is never hidden behind them.
local gui = make("ScreenGui", { Name = "WildboundCaptureUI", ResetOnSpawn = false, DisplayOrder = 20 }, playerGui)
local panel = make("Frame", { Name = "CapturePanel", Visible = false, BorderSizePixel = 0 }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
local panelStroke = make("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
local badge = make("TextLabel", { Name = "Badge", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 26,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(26, 24), Size = UDim2.fromOffset(40, 40),
	Text = "" }, panel)
local headline = make("TextLabel", { Name = "Headline", BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.None, Text = "" }, panel)
local detail = make("TextLabel", { Name = "Detail", BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
	TextTruncate = Enum.TextTruncate.AtEnd, Text = "" }, panel)
local track = make("Frame", { Name = "Track", BorderSizePixel = 0 }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, track)
local fill = make("Frame", { Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, fill)
local stop = make("TextButton", { Name = "StopButton", Visible = false, Text = "Stop", Font = Enum.Font.GothamBold,
	TextSize = 20, BackgroundColor3 = Color3.fromRGB(70, 30, 30), TextColor3 = Color3.fromRGB(255, 255, 255),
	AutoButtonColor = true }, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, stop)
make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 255, 255), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stop)

local connections = {}
local function listen(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

-- Layout ----------------------------------------------------------------------------------------------
local spot
local function touchPrimary()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local function applyLayout()
	local size = gui.AbsoluteSize
	local layout = Layout.compute(size.X, size.Y, { touch = touchPrimary() })
	spot = View.layout(layout)
	if not spot then
		-- No free spot found: a plain strip at the bottom edge, never silently hidden.
		local w = math.min(size.X - 8, 300)
		spot = { panel = { x = (size.X - w) / 2, y = size.Y - 60, w = w, h = 52 },
			stop = { x = size.X - 72, y = size.Y - 140, w = 64, h = 64 }, textSize = 13, chars = 20, compact = true }
	end
	panel.Position, panel.Size = UDim2.fromOffset(spot.panel.x, spot.panel.y), UDim2.fromOffset(spot.panel.w, spot.panel.h)
	stop.Position, stop.Size = UDim2.fromOffset(spot.stop.x, spot.stop.y), UDim2.fromOffset(spot.stop.w, spot.stop.h)
	local roomy = spot.panel.h >= 70
	headline.TextSize = spot.textSize + 1
	headline.Position, headline.Size = UDim2.fromOffset(52, 5), UDim2.fromOffset(spot.panel.w - 60, 22)
	detail.Visible = roomy
	detail.Position, detail.Size = UDim2.fromOffset(52, 28), UDim2.fromOffset(spot.panel.w - 60, 24)
	track.Position, track.Size = UDim2.fromOffset(8, spot.panel.h - 18), UDim2.fromOffset(spot.panel.w - 16, 10)
	badge.Position = UDim2.fromOffset(26, roomy and 24 or math.floor((spot.panel.h - 18) / 2))
	gui:SetAttribute("PanelMode", spot.takesOver and "takeover" or "free")
end
applyLayout()
listen(gui:GetPropertyChangedSignal("AbsoluteSize"), applyLayout)
listen(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"), applyLayout)

-- The ring on the ground (drawn only on this client; nothing replicates) ----------------------------------
local ringFolder = make("Folder", { Name = "WildboundCaptureRingLocal" }, workspace)
local segmentParts = {}
local function ensureSegments(count)
	for index = #segmentParts + 1, count do
		segmentParts[index] = make("Part", { Name = "RingSegment", Anchored = true, CanCollide = false, CanTouch = false,
			CanQuery = false, CastShadow = false, Material = Enum.Material.Neon, Transparency = 1,
			Size = Vector3.new(1, 0.12, View.CONSTANTS.RING_WIDTH) }, ringFolder)
	end
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundHeight(x, z, fallback)
	local excluded = { ringFolder }
	if player.Character then table.insert(excluded, player.Character) end
	rayParams.FilterDescendantsInstances = excluded
	local hit = workspace:Raycast(Vector3.new(x, fallback + 6, z), Vector3.new(0, -14, 0), rayParams)
	-- A hit far from where the avatar stands is a prop or a roof, not the ground the player walks on.
	if hit and math.abs(hit.Position.Y - fallback) <= 2.5 then return hit.Position.Y end
	return fallback
end
local function drawRing(cx, cz, ring, style, tone, width)
	local list = View.ringSegments(cx, cz, ring.radius, View.CONSTANTS.RING_SEGMENTS, style)
	ensureSegments(#list)
	local y = groundHeight(cx, cz, ring.y - 3) + 0.15
	local color = rgb(View.RING_COLORS[tone] or View.RING_COLORS.inside)
	for index, segment in ipairs(list) do
		local part = segmentParts[index]
		if segment.visible then
			part.Size = Vector3.new(segment.length, 0.12, width)
			part.CFrame = CFrame.new(segment.x, y, segment.z) * CFrame.Angles(0, segment.rotY, 0)
			part.Color = color
			part.Transparency = 0
		else
			part.Transparency = 1
		end
	end
	for index = #list + 1, #segmentParts do segmentParts[index].Transparency = 1 end
end
local function hideRing()
	for _, part in ipairs(segmentParts) do part.Transparency = 1 end
end

-- Server messages -----------------------------------------------------------------------------------------
local held, receivedAt, endedAt = nil, 0, nil
local actionRemote
local function setCapturing(value)
	if player:GetAttribute("WildboundCapturing") ~= value then player:SetAttribute("WildboundCapturing", value) end
end
local lastStop = 0
local function requestStop()
	local token = View.stopToken(held)
	if not token or not actionRemote then return end
	local now = os.clock()
	if now - lastStop < 0.4 then return end
	lastStop = now
	actionRemote:FireServer("CaptureCancel", token)
end
listen(stop.Activated, requestStop)
listen(UserInputService.InputBegan, function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.X and View.stopToken(held) then requestStop() end
end)

local function reducedEffects()
	local world = playerGui:FindFirstChild("WildboundWorldUI")
	local value = world and world:GetAttribute("Reduced")
	return value ~= false
end

-- Each frame: words from the held snapshot, the ring from the server clock. Nothing here decides an outcome.
local ringTime = 0
listen(RunService.RenderStepped, function(dt)
	if not gui.Parent then return end
	ringTime += dt
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local ring = held and held.ring
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cx, cz
	if ring then cx, cz = View.ringCenterAt(ring, serverNow, Session) end
	local ringDistance
	if cx and root then
		ringDistance = math.sqrt((root.Position.X - cx) ^ 2 + (root.Position.Z - cz) ^ 2)
	end
	local view = View.status(held, { age = now - receivedAt, sinceEnd = endedAt and (now - endedAt) or nil,
		ringDistance = ringDistance, reduced = reducedEffects(), compact = spot.compact })
	panel.Visible = view.visible
	stop.Visible = view.visible and View.stopToken(held) ~= nil
	if not view.visible then
		hideRing()
		if held and held.phase ~= "Active" then setCapturing(false) end
		return
	end
	local tone = View.TONES[view.tone]
	panel.BackgroundColor3, panelStroke.Color = rgb(tone.bg), rgb(tone.border)
	headline.Text, headline.TextColor3 = view.headline, rgb(tone.text)
	detail.Text, detail.TextColor3 = view.detail, rgb(tone.text)
	track.BackgroundColor3, fill.BackgroundColor3 = rgb(tone.track), rgb(tone.fill)
	fill.Size = UDim2.fromScale(view.fraction, 1)
	badge.TextColor3 = rgb(tone.fill)
	-- The direction cue is an arrow plus a word, so it works without colour. It replaces the glyph while it applies.
	badge.Text, badge.Rotation = view.glyph, 0
	if view.arrow and cx and root then
		local camera = workspace.CurrentCamera
		local look = camera and camera.CFrame.LookVector
		local degrees, word = View.arrow(root.Position.X, root.Position.Z, cx, cz, look and look.X or 0, look and look.Z or -1)
		if degrees then
			badge.Text, badge.Rotation = "^", degrees
			if detail.Visible then detail.Text = "Move " .. word .. "." end
		end
	end
	panelStroke.Thickness = view.state == "Outside" and 5 or 3
	-- Ring: solid inside, dashed outside, hidden once it ends.
	if ring and cx and view.ringStyle ~= "hidden" then
		drawRing(cx, cz, ring, view.ringStyle, view.ringTone, View.ringWidth(view.pulse, ringTime))
	else
		hideRing()
	end
end)

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("WildboundNetwork", 10)
	local action = folder and folder:WaitForChild("Action", 10)
	local feed = folder and folder:WaitForChild("CaptureState", 10)
	if not gui.Parent then return end
	if not (action and action:IsA("RemoteEvent") and feed and feed:IsA("RemoteEvent")) then
		warn("Wildbound capture screen: the capture feed is unavailable.")
		return
	end
	actionRemote = action
	listen(feed.OnClientEvent, function(payload)
		local merged = View.merge(held, payload)
		if merged == held then return end
		held, receivedAt = merged, os.clock()
		if merged.phase == "Active" then endedAt = nil else endedAt = os.clock() end
		setCapturing(merged.phase == "Active")
	end)
end)

listen(gui.Destroying, function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	ringFolder:Destroy()
	setCapturing(false)
end)
