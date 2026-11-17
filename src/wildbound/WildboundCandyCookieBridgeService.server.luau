-- Caramelo v6, proposal 2: crumbling cookie bridges (odd/tasks/wildbound-caramelo-v2.md V6-D2;
-- docs/design/wildbound-caramelo-v3-plan.md V6-D20 on). Once the live biome carries the v3 mark, this reads the live
-- bridge models Candy_Bioma_v1.CaramelV3.Bridges.Bridge_Top and Bridge_Bottom (WildboundCandyV3Builder.layBridge) and
-- every Cookie.STEP seconds steps WildboundCandyCookieBridge's state machine for each:
--   Crack:   cracks appear on the deck over CRACK_SECONDS, crumbs fall from under it, a crack sound and a sign.
--   Fall:    every part of the bridge stops colliding and being queried (players drop into the chocolate and wade,
--            WildboundCandyWadeService; the creatures' ground rays pass through to the river floor), then sinks and
--            fades under the floor.
--   Rebuild: every part gets back its original CFrame, transparency, collisions and queries, exactly.
-- The junction bridges are never read or touched. A missing model is skipped. No damage, no speed change, no client
-- request: the server decides from the root's position, the egg on the back and the hunt stamps.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Cookie = require(ServerStorage:WaitForChild("WildboundCandyCookieBridge"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local V3 = require(ServerStorage:WaitForChild("WildboundCandyV3Layout"))
local Wade = require(ServerStorage:WaitForChild("WildboundCandyWade"))

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 120)
if not biome then return end
while biome:GetAttribute(V3.MARK) == nil do
	biome:GetAttributeChangedSignal(V3.MARK):Wait()
end
local caramel = biome:FindFirstChild(V3.FOLDER) or biome:WaitForChild(V3.FOLDER, 30)
local bridgesFolder = caramel and (caramel:FindFirstChild("Bridges") or caramel:WaitForChild("Bridges", 30))
if not bridgesFolder then return end

-- Optional words and sound: the sign's line (WildboundText.CANDY_BRIDGE.crack, with the Spanish fallback until the key
-- lands) and the catalog's crack sound (WildboundAudioCatalog.SOUNDS.crack). Either may be missing; nothing breaks.
local function optional(name)
	local module = ReplicatedStorage:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then return nil end
	local ok, value = pcall(require, module)
	return ok and type(value) == "table" and value or nil
end
local words = optional("WildboundText")
local bridgeWords = words and type(words.CANDY_BRIDGE) == "table" and words.CANDY_BRIDGE or {}
local CRACK_LINE = type(bridgeWords.crack) == "string" and bridgeWords.crack or "¡El puente de galleta se rompe!"
local catalog = optional("WildboundAudioCatalog")
local crackSlot = catalog and type(catalog.SOUNDS) == "table" and catalog.SOUNDS.crack or nil
local CRACK_SOUND = crackSlot and type(crackSlot.ids) == "table" and tonumber(crackSlot.ids[1]) or nil

local CRACK_COLOR = Color3.fromRGB(70, 40, 22)
local CRUMB_COLOR = ColorSequence.new(Color3.fromRGB(196, 140, 78), Color3.fromRGB(150, 98, 50))
local CRACK_COUNT = 9

-- The runtime effects live in their own folder, never inside a bridge model (whose parts are recorded below).
local fxFolder = Instance.new("Folder")
fxFolder.Name = "CookieBridgeFx"
fxFolder.Parent = caramel

local function fxPart(into, name, size, cframe)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cframe
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = into
	return p
end

-- One live cookie bridge: its model, its deck, every part's original state, the pure state and its effects.
local bridges = {}
for _, id in ipairs(Cookie.IDS) do
	local model = bridgesFolder:FindFirstChild(Cookie.MODEL_PREFIX .. id)
	if not model then
		warn("Wildbound cookie bridge: no " .. Cookie.MODEL_PREFIX .. id .. " in " .. bridgesFolder:GetFullName() .. "; skipped")
	else
		local row
		for _, B in ipairs(V3.BRIDGES) do
			if B.id == id then row = B end
		end
		local deck = model:FindFirstChild("Deck")
		if row and deck and deck:IsA("BasePart") then
			local records = {}
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(records, {
						part = part, cframe = part.CFrame, transparency = part.Transparency, canCollide = part.CanCollide,
						canQuery = part.CanQuery, canTouch = part.CanTouch,
					})
				end
			end
			model:SetAttribute(Cookie.PHASE_ATTRIBUTE, "Up")
			table.insert(bridges, { id = id, row = row, model = model, deck = deck, records = records,
				st = Cookie.new(id), tweens = {}, fx = nil, cracks = 0 })
		end
	end
end
if #bridges == 0 then
	fxFolder:Destroy()
	return
end

local function clearFx(b)
	if b.fx then b.fx:Destroy() end
	b.fx, b.cracks = nil, 0
end

local function stopTweens(b)
	for _, tween in ipairs(b.tweens) do tween:Cancel() end
	table.clear(b.tweens)
end

-- Crack: an effects model over the deck: a crumb emitter under it, the crack sound and the sign.
local function startCrack(b)
	clearFx(b)
	local fx = Instance.new("Model")
	fx.Name = "Fx_" .. b.id
	fx.Parent = fxFolder
	b.fx = fx
	local deckCF, size = b.deck.CFrame, b.deck.Size
	local under = fxPart(fx, "Crumbs", Vector3.new(size.X, 0.2, size.Z), deckCF * CFrame.new(0, -size.Y / 2 - 0.15, 0))
	under.Transparency = 1
	local crumbs = Instance.new("ParticleEmitter")
	crumbs.Name = "CrumbEmitter"
	crumbs.Texture = "rbxasset://textures/particles/smoke_main.dds"
	crumbs.Color = CRUMB_COLOR
	crumbs.Size = NumberSequence.new(0.5, 0.25)
	crumbs.Lifetime = NumberRange.new(0.9, 1.5)
	crumbs.Speed = NumberRange.new(1, 3)
	crumbs.SpreadAngle = Vector2.new(30, 30)
	crumbs.EmissionDirection = Enum.NormalId.Bottom
	crumbs.Acceleration = Vector3.new(0, -25, 0)
	crumbs.Rate = 45
	crumbs.Parent = under
	if CRACK_SOUND then
		local sound = Instance.new("Sound")
		sound.Name = "Crack"
		sound.SoundId = "rbxassetid://" .. CRACK_SOUND
		sound.RollOffMaxDistance = 140
		sound.Volume = 0.9
		sound.Parent = under
		sound:Play()
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(260, 44)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	sign.MaxDistance = 90
	sign.Adornee = under
	sign.Parent = under
	local line = Instance.new("TextLabel")
	line.Size = UDim2.fromScale(1, 1)
	line.BackgroundTransparency = 1
	line.Text = CRACK_LINE
	line.TextScaled = true
	line.Font = Enum.Font.GothamBold
	line.TextColor3 = Color3.fromRGB(255, 236, 214)
	line.TextStrokeTransparency = 0.3
	line.Parent = sign
end

-- The cracks grow over the cracking: thin dark lines on the deck's top at fixed spots (the same every time).
local function growCracks(b, progress)
	if not b.fx then return end
	local want = math.min(CRACK_COUNT, math.ceil(progress * CRACK_COUNT))
	local deckCF, size = b.deck.CFrame, b.deck.Size
	local random = Random.new(#b.id * 7919)
	for i = 1, CRACK_COUNT do
		local x = (random:NextNumber() - 0.5) * size.X * 0.8
		local z = (random:NextNumber() - 0.5) * size.Z * 0.85
		local yaw = random:NextNumber() * math.pi
		local length = 2.5 + random:NextNumber() * 4
		if i > b.cracks and i <= want then
			local crack = fxPart(b.fx, "Crack_" .. i, Vector3.new(0.25, 0.05, length),
				deckCF * CFrame.new(x, size.Y / 2 + 0.03, z) * CFrame.Angles(0, yaw, 0))
			crack.Color = CRACK_COLOR
		end
	end
	b.cracks = math.max(b.cracks, want)
end

-- Fall: nothing of the bridge holds anyone or meets a ray any more, then every part sinks and fades.
local function fall(b)
	stopTweens(b)
	if b.fx then
		local emitter = b.fx:FindFirstChild("CrumbEmitter", true)
		if emitter then
			emitter.Rate = 0
			emitter:Emit(80)
		end
		local sound = b.fx:FindFirstChild("Crack", true)
		if sound then
			sound.PlaybackSpeed = 0.75
			sound:Play()
		end
		for _, child in ipairs(b.fx:GetChildren()) do
			if string.sub(child.Name, 1, 6) == "Crack_" then child:Destroy() end
		end
		local sign = b.fx:FindFirstChild("Sign", true)
		if sign then sign:Destroy() end
		local fx = b.fx
		task.delay(3, function()
			if b.fx == fx then clearFx(b) end
		end)
	end
	local info = TweenInfo.new(Cookie.FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for i, rec in ipairs(b.records) do
		local part = rec.part
		if part.Parent then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local tilt = CFrame.Angles(math.rad((i % 5 - 2) * 4), 0, math.rad((i % 3 - 1) * 6))
			local target = rec.cframe * tilt + Vector3.new(0, -Cookie.SINK, 0)
			local tween = TweenService:Create(part, info, { CFrame = target, Transparency = 1 })
			table.insert(b.tweens, tween)
			tween:Play()
		end
	end
end

-- Rebuild: every part exactly as it was laid.
local function rebuild(b)
	stopTweens(b)
	clearFx(b)
	for _, rec in ipairs(b.records) do
		local part = rec.part
		if part.Parent then
			part.CFrame = rec.cframe
			part.Transparency = rec.transparency
			part.CanCollide = rec.canCollide
			part.CanQuery = rec.canQuery
			part.CanTouch = rec.canTouch
		end
	end
end

-- What the rules need from one player, or nil (no live character).
local function sample(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil end
	local probe = Wade.probe(V3, Layout.CENTRE, Layout.FLOOR_TOP, root.Position, root.Size.Y / 2, humanoid.HipHeight,
		humanoid.RigType == Enum.HumanoidRigType.R6)
	return {
		x = root.Position.X - Layout.CENTRE.x, z = root.Position.Z - Layout.CENTRE.z, feetY = probe.feetY,
		alive = humanoid.Health > 0,
		carriesEgg = character:FindFirstChild("WildboundEggCarried") ~= nil,
		engagedAt = player:GetAttribute("WildboundBeastEngagedAt"),
		threatLevel = player:GetAttribute("WildboundThreatLevel"),
	}
end

local function tick()
	local now = workspace:GetServerTimeNow()
	local samples = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, info = pcall(sample, player)
		if ok and info then table.insert(samples, info) end
	end
	for _, b in ipairs(bridges) do
		local triggered, blocked = false, false
		for _, info in ipairs(samples) do
			if Cookie.triggers(V3, Layout.FLOOR_TOP, info, now) == b.id then triggered = true end
			if info.alive and Cookie.blocks(V3, b.id, info.x, info.z) then blocked = true end
		end
		local event = Cookie.step(b.st, now, triggered, blocked)
		if event == "Crack" then
			startCrack(b)
		elseif event == "Fall" then
			fall(b)
		elseif event == "Rebuild" then
			rebuild(b)
		end
		if b.st.phase == "Cracking" then growCracks(b, Cookie.progress(b.st, now)) end
		if event then b.model:SetAttribute(Cookie.PHASE_ATTRIBUTE, b.st.phase) end
	end
end

-- A script stop (or a reload) leaves every bridge as it was laid.
script.Destroying:Connect(function()
	for _, b in ipairs(bridges) do rebuild(b) end
	fxFolder:Destroy()
end)

while true do
	task.wait(Cookie.STEP)
	local ok, message = pcall(tick)
	if not ok then warn("Wildbound cookie bridge: step error: " .. tostring(message)) end
end
