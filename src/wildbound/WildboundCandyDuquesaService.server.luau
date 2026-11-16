-- A2 (odd/tasks/wildbound-caramelo-playfix.md): runs WildboundCandyDuquesa on the Gran Torta's summit. La Duquesa
-- Burbuja stays the seated scenery in Workspace.WildboundNewCandyPreview; while a player stands on the summit she throws
-- her "Bombas de chicle": on each Charge she gets a clip cue (WildboundCritterCue = "Charge:<volley>", then
-- "Whip:<volley>", which WildboundCandyCritterAnim plays as one-shots before her seated loop) and three pink rings appear
-- on the summit floor; on the Whip three bubbles leave her hands and fly slowly to the rings; on the pop each bubble
-- bursts. A player inside a pop is slowed through the beasts' one non-stacking slow slot (WildboundBeastSlowUntil,
-- clamped by WildboundBeastChase.EFFECTS) and pushed through the beasts' one push slot (WildboundBeastPush), like
-- Frutillon's bumps. Every part is server-made (seen by every player), anchored and never colliding. Damage 0, nothing
-- about the egg; CT3's summit nest and CT4 Frutillon are not touched.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Duq = require(ServerStorage:WaitForChild("WildboundCandyDuquesa"))
local Frut = require(ServerStorage:WaitForChild("WildboundCandyFrutillon"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local Chase = require(ReplicatedStorage:WaitForChild("WildboundBeastChase"))

local STEP = 0.1
local BUBBLE, RING = Color3.fromRGB(255, 130, 205), Color3.fromRGB(255, 70, 170)
local summit = Frut.summit(Layout)
local state = Duq.new()

local folder = Instance.new("Folder")
folder.Name = "WildboundCandyDuquesa"
folder.Parent = workspace

local preview = workspace:WaitForChild("WildboundNewCandyPreview", 30)
local duquesa = preview and preview:WaitForChild("DuquesaBurbuja", 30)
if not duquesa then warn("WildboundCandyDuquesaService: no WildboundNewCandyPreview.DuquesaBurbuja; the bubbles leave the summit centre.") end

local function part(name, shape, size, color, transparency)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color, p.Transparency = name, shape, size, color, transparency
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = folder
	return p
end

local function cue(clip, volley)
	if duquesa and duquesa.Parent then duquesa:SetAttribute("WildboundCritterCue", clip .. ":" .. volley) end
end

local function hands()
	local base = duquesa and duquesa.Parent and duquesa:GetPivot().Position or Vector3.new(summit.x, summit.top, summit.z)
	return Vector3.new(base.X, summit.top + Duq.HANDS_STUDS, base.Z)
end

-- The beasts' slow (WildboundBeasts applySlow): clamped, never stacked, put back only if nothing changed the speed.
local function slow(player, multiplier, seconds)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	multiplier, seconds = Chase.clampSlow(multiplier, seconds)
	if not humanoid or not multiplier or seconds <= 0 then return end
	local untilAt = humanoid:GetAttribute("WildboundBeastSlowUntil")
	if type(untilAt) == "number" and untilAt > workspace:GetServerTimeNow() then return end
	local slowed = humanoid.WalkSpeed * multiplier
	humanoid.WalkSpeed = slowed
	humanoid:SetAttribute("WildboundBeastSlowUntil", workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, function()
		if humanoid.Parent and math.abs(humanoid.WalkSpeed - slowed) < 1e-3 then humanoid.WalkSpeed = slowed / multiplier end
	end)
end

-- Frutillon's push: one at a time (the beasts' slot), flat, clamped.
local function push(player, dx, dz, studs, seconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("WildboundBeastPush") then return end
	studs, seconds = math.clamp(studs, 0, 8), math.clamp(seconds, 0.1, 1)
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

local rings, bubbles = {}, {}
local function play(events, now)
	for _, ev in ipairs(events) do
		if ev.kind == "Charge" then
			cue("Charge", ev.volley)
			for i, s in ipairs(ev.spots) do
				local ring = part("Ring_" .. ev.volley .. "_" .. i, Enum.PartType.Cylinder,
					Vector3.new(0.1, Duq.POP_RADIUS_STUDS * 2, Duq.POP_RADIUS_STUDS * 2), RING, 0.45)
				ring.Material = Enum.Material.Neon
				ring.CFrame = CFrame.new(s.x, s.y + 0.08, s.z) * CFrame.Angles(0, 0, math.rad(90))
				rings[ev.volley .. ":" .. i] = ring
			end
		elseif ev.kind == "Throw" then
			cue("Whip", ev.volley)
			local from = hands()
			for i, s in ipairs(ev.spots) do
				local bubble = part("Bubble_" .. ev.volley .. "_" .. i, Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), BUBBLE, 0.25)
				bubble.Material = Enum.Material.Glass
				bubble.Position = from
				TweenService:Create(bubble, TweenInfo.new(math.max(ev.popAt - now, 0.1), Enum.EasingStyle.Sine,
					Enum.EasingDirection.Out), { Position = Vector3.new(s.x, s.y + 0.9, s.z) }):Play()
				bubbles[ev.volley .. ":" .. i] = bubble
			end
		elseif ev.kind == "Pop" then
			local key = ev.volley .. ":" .. ev.index
			if rings[key] then rings[key]:Destroy() rings[key] = nil end
			if bubbles[key] then bubbles[key]:Destroy() bubbles[key] = nil end
			local burst = part("Pop_" .. key, Enum.PartType.Ball, Vector3.new(2, 2, 2), BUBBLE, 0.3)
			burst.Position = Vector3.new(ev.x, ev.y + 0.9, ev.z)
			local size = Duq.POP_RADIUS_STUDS * 2
			TweenService:Create(burst, TweenInfo.new(0.35), { Size = Vector3.new(size, size, size), Transparency = 1 }):Play()
			Debris:AddItem(burst, 0.45)
		elseif ev.kind == "Hit" then
			local player = Players:GetPlayerByUserId(ev.id)
			if player then
				slow(player, ev.slow, ev.slowSeconds)
				push(player, ev.dx, ev.dz, ev.studs, ev.seconds)
			end
		end
	end
end

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < STEP then return end
	clock = 0
	local now = workspace:GetServerTimeNow()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			table.insert(players, { id = player.UserId, alive = true, x = root.Position.X, y = root.Position.Y, z = root.Position.Z })
		end
	end
	play(Duq.step(state, now, players, summit), now)
end)
