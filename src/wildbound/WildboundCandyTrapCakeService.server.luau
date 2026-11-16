-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG7 Torta trampa): runs WildboundCandyTrapCake in the place.
-- Builds the three decoy cakes at runtime (the Candy kit's CakeTower prefab, small; the place file never needs saving),
-- each with a ProximityPrompt for its slice. Every STEP it reads WildboundTelemetry.Beast_bossAwake (the beasts
-- server's one answer for "an encounter of Don Glaseon lives") and the players' server-side roots, and plays the
-- rule's events: the disguised cake breathes and drops crumbs; a spring raises a sleeping copy of him out of it for
-- the tell, the lash pushes the players near away (the beasts' push slot, WildboundBeastPush, so never two at once;
-- no damage, the egg stays), and the decoys pop until they grow back. Candy_bossDisguised tells
-- WildboundCandyDonGlaseonService to take the sleeper off BossHome while he is out in disguise. A slice's rush is a
-- server-only player attribute (WildboundCandyRushUntil) that WildboundServer.applyCarry, the one WalkSpeed writer,
-- applies.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Trap = require(ServerStorage:WaitForChild("WildboundCandyTrapCake"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local Kit = require(ServerStorage:WaitForChild("WildboundCandyKit"))
local DonGlaseon = require(ServerStorage:WaitForChild("WildboundCandyDonGlaseon"))
local Rules = require(ServerScriptService:WaitForChild("WildboundWorldRules"))
local assets = ServerStorage:WaitForChild("WildboundAssets")
local library = assets:WaitForChild(Kit.LIBRARY_NAME)
local prefab = assets:WaitForChild("DonGlaseon")
local telemetry = ServerStorage:WaitForChild("WildboundTelemetry", 60)

local STEP = 0.1
local BREATHING = { TiersA = true, TiersB = true, Icing = true, Fruit = true, Confetti = true }
local rng = Random.new()
local function pick(n) return rng:NextInteger(1, n) end
local function now() return workspace:GetServerTimeNow() end

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 60)
local floor = biome and biome:FindFirstChild("Ground")
local params = RaycastParams.new()
params.FilterType = floor and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { floor or workspace.Terrain }
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or Layout.FLOOR_TOP
end

local folder = Instance.new("Folder")
folder.Name = "WildboundCandyTrapCakes"
folder.Parent = workspace
local spots = Trap.spotsWorld(Layout.CENTRE)
local cakes = {} -- [index] = { model, base = { [part] = size }, crumbs, tweens }
local state = Trap.new(now(), pick)

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then return nil end
	return root
end

local function stopBreath(cake)
	for _, tween in ipairs(cake.tweens) do tween:Cancel() end
	cake.tweens = {}
	for part, size in pairs(cake.base) do part.Size = size end
	cake.crumbs.Enabled = false
end

-- The tell: a slow breath (every mesh grows by BREATH_SCALE and back) and a crumb now and then.
local function startBreath(cake)
	if #cake.tweens > 0 then return end
	local info = TweenInfo.new(Trap.BREATH_SECONDS / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for part, size in pairs(cake.base) do
		local tween = TweenService:Create(part, info, { Size = size * (1 + Trap.BREATH_SCALE) })
		tween:Play()
		table.insert(cake.tweens, tween)
	end
	cake.crumbs.Enabled = true
end

local onPrompt
local function buildCake(index)
	local spot = spots[index]
	local y = groundAt(spot.x, spot.z)
	local model = Kit.place(library, "CakeTower", CFrame.new(spot.x, y, spot.z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
		Trap.SCALE)
	model.Name = "TrapCake_" .. spot.key
	model:SetAttribute("TrapCake", spot.key)
	local base = {}
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("MeshPart") and BREATHING[d.Name] then base[d] = d.Size end
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.CFrame = CFrame.new(spot.x, y + 3, spot.z)
	anchor.Parent = model
	local crumbs = Instance.new("ParticleEmitter")
	crumbs.Name = "Crumbs"
	crumbs.Rate = Trap.CRUMB_RATE
	crumbs.Lifetime = NumberRange.new(1.2, 1.6)
	crumbs.Speed = NumberRange.new(0.5, 1.5)
	crumbs.SpreadAngle = Vector2.new(40, 40)
	crumbs.Acceleration = Vector3.new(0, -12, 0)
	crumbs.Size = NumberSequence.new(0.25)
	crumbs.Color = ColorSequence.new(Color3.fromRGB(248, 191, 102))
	crumbs.Enabled = false
	crumbs.Parent = anchor
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = Trap.TEXT.prompt, Trap.TEXT.object
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Trap.PROMPT_STUDS
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player) onPrompt(index, player) end)
	model.Parent = folder
	cakes[index] = { model = model, base = base, crumbs = crumbs, tweens = {}, y = y }
end

local function buildAll()
	for index = 1, #spots do buildCake(index) end
end

local function push(player, dx, dz, studs, seconds)
	local root = rootOf(player)
	if not root or root:FindFirstChild("WildboundBeastPush") then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "WildboundBeastPush"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(dx, dz) * (studs / seconds)
	velocity.MaxForce = 1e5
	velocity.Parent = attachment
	task.delay(seconds, function() attachment:Destroy() end)
end

-- The spring: a sleeping copy of him rises out of the cake during the tell, facing who sprang it.
local function popOut(event)
	local cake, spot = cakes[event.index], spots[event.index]
	if cake then stopBreath(cake) end
	local copy = DonGlaseon.asleep(prefab:Clone())
	copy.Name = "DonGlaseonTrap"
	copy:SetAttribute("BeastPhase", "Attack")
	local by = Players:GetPlayerByUserId(event.by)
	local root = by and rootOf(by)
	local y = cake and cake.y or Layout.FLOOR_TOP
	local face = root and Vector3.new(root.Position.X, y, root.Position.Z) or Vector3.new(spot.x + 1, y, spot.z)
	local size = copy:GetExtentsSize()
	local up = CFrame.lookAt(Vector3.new(spot.x, y, spot.z), face)
	copy:PivotTo(up * CFrame.new(0, -size.Y, 0))
	copy.Parent = folder
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - started) / Trap.TELL_SECONDS, 0, 1)
		if copy.Parent == nil then connection:Disconnect() return end
		copy:PivotTo(up * CFrame.new(0, -size.Y * (1 - t), 0))
		if t >= 1 then connection:Disconnect() end
	end)
	task.delay(Trap.TELL_SECONDS + Trap.POP_SECONDS + 0.3, function() copy:Destroy() end)
end

local function popAll()
	for index, cake in pairs(cakes) do
		local burst = Instance.new("Part")
		burst.Size, burst.Transparency = Vector3.new(1, 1, 1), 1
		burst.Anchored, burst.CanCollide, burst.CanTouch, burst.CanQuery = true, false, false, false
		burst.CFrame = CFrame.new(spots[index].x, cake.y + 2, spots[index].z)
		local confetti = Instance.new("ParticleEmitter")
		confetti.Rate, confetti.Speed, confetti.Lifetime = 0, NumberRange.new(8, 14), NumberRange.new(0.8, 1.2)
		confetti.SpreadAngle = Vector2.new(180, 180)
		confetti.Acceleration = Vector3.new(0, -20, 0)
		confetti.Color = ColorSequence.new(Color3.fromRGB(246, 150, 140), Color3.fromRGB(251, 225, 94))
		confetti.Parent = burst
		burst.Parent = folder
		confetti:Emit(30)
		task.delay(2, function() burst:Destroy() end)
		cake.model:Destroy()
		cakes[index] = nil
	end
end

local function play(events)
	for _, event in ipairs(events) do
		if event.kind == "Spring" then
			popOut(event)
		elseif event.kind == "Lash" then
			for _, p in ipairs(event.pushes) do
				local player = Players:GetPlayerByUserId(p.id)
				if player then push(player, p.dx, p.dz, p.studs, p.seconds) end
			end
		elseif event.kind == "Pop" then
			popAll()
		elseif event.kind == "Regrow" then
			buildAll()
		end
	end
end

onPrompt = function(index, player)
	local root = rootOf(player)
	local spot = spots[index]
	if not root or not spot then return end
	local distance = Vector3.new(root.Position.X - spot.x, 0, root.Position.Z - spot.z).Magnitude
	local awake = telemetry and telemetry:GetAttribute("Beast_bossAwake") == true
	local ok, result = Trap.take(state, index, player.UserId, distance, now(), true, awake)
	if not ok then return end
	if result.kind == "Spring" then
		play({ result })
	elseif result.kind == "Rush" then
		player:SetAttribute("WildboundCandyRushUntil", result.untilAt)
	end
end

buildAll()
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < STEP then return end
	clock = 0
	local at = now()
	local awake = telemetry and telemetry:GetAttribute("Beast_bossAwake") == true
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root then
			local _, safe = Rules.zone(root.Position.X, root.Position.Z)
			table.insert(players, { id = player.UserId, x = root.Position.X, z = root.Position.Z, alive = true, safe = safe == true })
		end
	end
	play(Trap.step(state, at, awake, players, pick, spots))
	local disguised = Trap.disguised(state, awake, at)
	for index, cake in pairs(cakes) do
		if disguised and index == state.trapIndex then startBreath(cake) elseif #cake.tweens > 0 or cake.crumbs.Enabled then stopBreath(cake) end
	end
	if telemetry and telemetry:GetAttribute("Candy_bossDisguised") ~= disguised then
		telemetry:SetAttribute("Candy_bossDisguised", disguised)
	end
end)
