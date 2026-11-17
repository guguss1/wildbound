-- A2 (odd/tasks/wildbound-caramelo-playfix.md): runs WildboundCandyDuquesa on the Gran Torta's summit. La Duquesa
-- Burbuja stays the seated scenery in Workspace.WildboundNewCandyPreview; while a player stands on the summit she throws
-- her "Bombas de chicle": on each Charge she gets a clip cue (WildboundCritterCue = "Charge:<volley>", then
-- "Whip:<volley>", which WildboundCandyCritterAnim plays as one-shots before her seated loop) and three pink rings appear
-- on the summit floor; on the Whip three bubbles leave her hands and fly slowly to the rings; on the pop each bubble
-- bursts. A player inside a pop is slowed through the beasts' one non-stacking slow slot (WildboundBeastSlowUntil,
-- clamped by WildboundBeastChase.EFFECTS) and pushed through the beasts' one push slot (WildboundBeastPush), like
-- Frutillon's bumps. Every part is server-made (seen by every player), anchored and never colliding. The bubbles deal
-- no damage and never touch the egg; CT3's summit nest and CT4 Frutillon are not touched.
-- DR (owner request 2026-11-16): her rage. The server knows her eggs by the nest models of her island in
-- WildboundP0.WildboundRuntime (attributes Island and EncounterId; the id stays on the carried egg's WildboundEggCarried
-- model as EggId). A thief carrying one makes her roar and turn red (a server Highlight and a line over her head, seen by
-- everybody), then she flies after the thief (her model is moved here, every frame, toward the rules' position; her
-- parts stop colliding until she sits again). Each lunge draws a red line and ring (server parts; they follow the thief
-- until the aim locks, then stay on the locked spot, D-1) and registers with the
-- shared WildboundDodgeService (the perfect dodge stuns her); a lunge that lands goes to the inventory server's BeastHit
-- with the egg NOT kept (the one egg drop path, also used by Don Glaseon's lash: damage only where the game allows it)
-- and pushes the thief. Her rage bubbles are the ordinary volleys, bigger and redder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Duq = require(ServerStorage:WaitForChild("WildboundCandyDuquesa"))
local Frut = require(ServerStorage:WaitForChild("WildboundCandyFrutillon"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local Chase = require(ReplicatedStorage:WaitForChild("WildboundBeastChase"))
local Rules = require(ServerScriptService:WaitForChild("WildboundWorldRules"))
local DodgeService = require(ServerScriptService:WaitForChild("WildboundDodgeService"))
-- V4-D12: the houses are a refuge: her flight stops at a house's edge and a lunge never lands on a player inside one
local Smarts = require(ServerScriptService:WaitForChild("WildboundCandySmarts"))
local houses, housesAt = {}, -math.huge
local function houseDiscs(at)
	if at - housesAt >= 5 or at < housesAt then
		housesAt = at
		houses = Smarts.houseDiscs(workspace:FindFirstChild(Layout.ROOT_NAME))
	end
	return houses
end

-- V5-D2 (Caramelo v5, odd/tasks/wildbound-caramelo-v2.md): hiding. A player hidden in a hide spot (WildboundWorld's
-- WildboundHidden) is never acquired: one who is not her thief is left out of her rules. Her thief who hides is
-- searched for: the rules get a point that walks round the spot (WildboundCandyHiding.searchPoint) as the thief's place,
-- marked hidden (no lunge, no bubbles, no hit), until the search runs out; then the thief is left out and she calms
-- ("Gone") and floats home. Hovering within WildboundHide's discover radius of the spot for its dwell time she finds
-- them (Hiding.finds) and tells the world script (HideFound), which pulls the thief out on her side.
local Hiding = require(ServerScriptService:WaitForChild("WildboundCandyHiding"))
local hideSearch, hideWatch = nil, nil
local function hiddenNow(player)
	return player:GetAttribute("WildboundHidden") ~= nil
end
-- V6-D1 (Caramelo v6): the tall licorice grass. A player in a patch who is not sprinting (worked out here from the
-- server's positions, Hiding.covered) and farther than Hiding.GRASS.seeStuds from her is not seen: one who is not her
-- thief is left out of her rules; her thief is kept for Hiding.GRASS.memorySeconds, then searched for like a hidden
-- thief (the search point as the thief's place, marked hidden) until the search runs out and she calms ("Gone"). There
-- is no discovery dwell in the grass: within seeStuds, or sprinting, she sees them again.
local grass = { patches = {}, at = -math.huge, since = nil, search = nil }
local function grassCover(player, x, z, now)
	if now - grass.at >= 5 or now < grass.at then
		grass.at = now
		grass.patches = Hiding.grassPatches(game:GetService("CollectionService"):GetTagged(Hiding.GRASS.tag))
	end
	return Hiding.covered(Hiding.inGrass(grass.patches, x, z), player:GetAttribute("WildboundStance"))
end

local STEP = 0.1
local BUBBLE, RING = Color3.fromRGB(255, 130, 205), Color3.fromRGB(255, 70, 170)
local RAGE_RED, RAGE_BUBBLE = Color3.fromRGB(230, 40, 40), Color3.fromRGB(240, 60, 90)
local summit = Frut.summit(Layout)
local state = Duq.new()

local folder = Instance.new("Folder")
folder.Name = "WildboundCandyDuquesa"
folder.Parent = workspace

local preview = workspace:WaitForChild("WildboundNewCandyPreview", 30)
local duquesa = preview and preview:WaitForChild("DuquesaBurbuja", 30)
if not duquesa then warn("WildboundCandyDuquesaService: no WildboundNewCandyPreview.DuquesaBurbuja; the bubbles leave the summit centre.") end
-- V4-D10 (owner request 2026-11-17, "the queen seated on top of the cake as before"): the GT cake move left her model
-- over the old summit. At start, a model off her seat (Duq.offSeat) is pivoted onto it (Duq.seatPivot), facing the
-- junction, before any rage reads her seat (leaveSeat's seatPivot and seatOffset); the server copy only (the
-- v4 migration or tools/wildbound-caramelo-queen-seat.luau moves the edit copy).
if duquesa then
	local at = duquesa:GetPivot().Position
	if Duq.offSeat({ x = at.X, y = at.Y, z = at.Z }, summit) then
		local junction = { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z }
		local s = Duq.seatPivot(summit, junction)
		duquesa:PivotTo(CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0))
	end
end

-- DR: every egg that ever lay in her nest, by its encounter id (it keeps that id while carried or dropped).
local herIsland, herEggs = Duq.herIsland(Layout), {}
local function noteEgg(child)
	local id = child:GetAttribute("EncounterId")
	if child:GetAttribute("Island") == herIsland and type(id) == "string" then herEggs[id] = true end
end
task.spawn(function()
	local map = workspace:WaitForChild("WildboundP0", 60)
	local runtime = map and map:WaitForChild("WildboundRuntime", 60)
	if not runtime then
		warn("WildboundCandyDuquesaService: no WildboundP0.WildboundRuntime; La Duquesa never knows her egg was taken.")
		return
	end
	runtime.ChildAdded:Connect(function(child) task.defer(noteEgg, child) end) -- its attributes come after the parent
	for _, child in ipairs(runtime:GetChildren()) do noteEgg(child) end
end)

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
	-- DR: away from her seat the bubbles leave her hands where she flies
	local her = Duq.position(state)
	if her then return Vector3.new(her.x, her.y, her.z) end
	-- V7-D1: seated on the cake's cherry, her hands are HANDS_STUDS over her seated base, not over the summit floor
	local seat = Duq.seatPivot(summit)
	local base = duquesa and duquesa.Parent and duquesa:GetPivot().Position or Vector3.new(seat.x, seat.y, seat.z)
	return Vector3.new(base.X, base.Y + Duq.HANDS_STUDS, base.Z)
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

-- Frutillon's push: one at a time (the beasts' slot), flat, clamped (12 studs at most, the beasts' own clamp).
local function push(player, dx, dz, studs, seconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("WildboundBeastPush") then return end
	studs, seconds = math.clamp(studs, 0, 12), math.clamp(seconds, 0.1, 1)
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

-- DR: the rage look and her flight ----------------------------------------------------------------------------------
local rageSerial, cueSerial = 0, 0
local seatPivot, seatOffset, savedCollide = nil, nil, {}
local marker = nil -- { line, ring, id } while a lunge is told

local function rageCue(clip)
	cueSerial += 1
	cue(clip, "r" .. cueSerial)
end

local function setRed(on)
	if not duquesa then return end
	local glow = duquesa:FindFirstChild("WildboundDuquesaRage")
	if on and not glow then
		glow = Instance.new("Highlight")
		glow.Name = "WildboundDuquesaRage"
		glow.FillColor, glow.FillTransparency = RAGE_RED, 0.35
		glow.OutlineColor, glow.OutlineTransparency = Color3.fromRGB(255, 90, 90), 0
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = duquesa
	elseif not on and glow then
		glow:Destroy()
	end
	local body = duquesa.PrimaryPart or duquesa:FindFirstChildWhichIsA("BasePart", true)
	local sign = body and body:FindFirstChild("WildboundDuquesaFurious")
	if on and body and not sign then
		sign = Instance.new("BillboardGui")
		sign.Name = "WildboundDuquesaFurious"
		sign.Size, sign.StudsOffsetWorldSpace = UDim2.fromOffset(280, 44), Vector3.new(0, 8, 0)
		sign.AlwaysOnTop, sign.MaxDistance, sign.LightInfluence = true, 160, 0
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextScaled, label.Font = Duq.TEXT.furious, true, Enum.Font.GothamBlack
		label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency = Color3.fromRGB(255, 70, 70), Color3.new(1, 1, 1), 0.2
		label.Parent = sign
		sign.Parent = body
	elseif not on and sign then
		sign:Destroy()
	end
end

-- her parts stop colliding while she flies (she would shove players), and come back as they were when she sits
local function leaveSeat()
	if not duquesa or seatPivot then return end
	seatPivot = duquesa:GetPivot()
	local seat = Duq.seat(summit)
	seatOffset = seatPivot.Position - Vector3.new(seat.x, seat.y, seat.z)
	for _, d in ipairs(duquesa:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			savedCollide[d] = true
			d.CanCollide = false
		end
	end
end

local function sitDown()
	if not duquesa or not seatPivot then return end
	duquesa:PivotTo(seatPivot)
	for d in pairs(savedCollide) do
		if d.Parent then d.CanCollide = true end
	end
	seatPivot, seatOffset, savedCollide = nil, nil, {}
end

local function clearMarker()
	if marker then
		marker.line:Destroy()
		marker.ring:Destroy()
		marker = nil
	end
end

local function lungeKey(id, lunge) return "Duquesa:" .. rageSerial .. ":" .. tostring(id) .. ":" .. lunge end

-- A perfect press inside the lunge's window (WildboundDodgeService) is the only way to dodge it.
local function resolve(id, lunge, now)
	local player = Players:GetPlayerByUserId(id)
	if not player then return "Unknown" end
	return DodgeService.resolve(player, lungeKey(id, lunge), now)
end

-- The lunge that lands: the one egg drop path (BeastHit, the egg not kept), then the push. A dodge's dash (its brief
-- invulnerability, which BeastHit checks first) cancels both.
local beastHit = nil
local function landLunge(player, ev)
	local body = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if body and Smarts.inHouse(body.Position.X, body.Position.Z, houseDiscs(workspace:GetServerTimeNow())) then return end -- V4-D12
	if body and hiddenNow(player) then return end -- V5-D2: hidden in a hide spot
	local network = ReplicatedStorage:FindFirstChild("WildboundNetwork")
	beastHit = beastHit or (network and network:FindFirstChild("BeastHit"))
	if beastHit and beastHit:IsA("BindableFunction") then
		local ok, effect = pcall(function() return beastHit:Invoke(player, "DuquesaBurbuja", ev.damage, ev.drop ~= true) end)
		if ok and type(effect) == "table" and effect.dodged == true then return end
		if not ok then warn("WildboundCandyDuquesaService: BeastHit failed: " .. tostring(effect)) end
	end
	push(player, ev.dx, ev.dz, ev.studs, ev.seconds)
end

local rings, bubbles = {}, {}
local function play(events, now)
	for _, ev in ipairs(events) do
		if ev.kind == "Charge" then
			cue("Charge", ev.volley)
			for i, s in ipairs(ev.spots) do
				local ring = part("Ring_" .. ev.volley .. "_" .. i, Enum.PartType.Cylinder,
					Vector3.new(0.1, Duq.POP_RADIUS_STUDS * 2, Duq.POP_RADIUS_STUDS * 2), ev.rage and RAGE_RED or RING, 0.45)
				ring.Material = Enum.Material.Neon
				ring.CFrame = CFrame.new(s.x, s.y + 0.08, s.z) * CFrame.Angles(0, 0, math.rad(90))
				rings[ev.volley .. ":" .. i] = ring
			end
		elseif ev.kind == "Throw" then
			cue("Whip", ev.volley)
			local from = hands()
			local angry = Duq.position(state) ~= nil -- DR: bigger, redder bubbles in her rage
			for i, s in ipairs(ev.spots) do
				local size = angry and 2.9 or 1.8
				local bubble = part("Bubble_" .. ev.volley .. "_" .. i, Enum.PartType.Ball, Vector3.new(size, size, size),
					angry and RAGE_BUBBLE or BUBBLE, 0.25)
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
			if player and not hiddenNow(player) then -- V5-D2
				slow(player, ev.slow, ev.slowSeconds)
				push(player, ev.dx, ev.dz, ev.studs, ev.seconds)
			end
		elseif ev.kind == "Rage" then
			rageSerial += 1
			leaveSeat()
			setRed(true)
			rageCue("Surprised")
		elseif ev.kind == "Lunge" then
			rageCue("Charge")
			local player = Players:GetPlayerByUserId(ev.id)
			if player then DodgeService.telegraph(player, lungeKey(ev.id, ev.lunge), Duq.DODGE_SOURCE, ev.startAt, ev.strikeAt) end
			clearMarker()
			local line = part("Lunge_" .. ev.lunge, Enum.PartType.Block, Vector3.new(0.35, 0.2, 1), RAGE_RED, 0.2)
			line.Material = Enum.Material.Neon
			local ring = part("LungeRing_" .. ev.lunge, Enum.PartType.Cylinder,
				Vector3.new(0.12, Duq.LUNGE_HIT_STUDS * 2, Duq.LUNGE_HIT_STUDS * 2), RAGE_RED, 0.4)
			ring.Material = Enum.Material.Neon
			marker = { line = line, ring = ring, id = ev.id }
		elseif ev.kind == "Lock" then
			-- D-1: the ring sits on the locked spot (its centre FEET_STUDS over the floor, like a root)
			if marker then marker.locked = Vector3.new(ev.x, ev.y + Duq.FEET_STUDS, ev.z) end
		elseif ev.kind == "LungeCancel" then
			local player = Players:GetPlayerByUserId(ev.id)
			if player then DodgeService.cancel(player, lungeKey(ev.id, ev.lunge)) end
			clearMarker()
		elseif ev.kind == "Strike" then
			clearMarker()
			rageCue(ev.outcome == "Dodged" and "Surprised" or "Whip")
			-- D-4: her model snaps to the strike point (the per-frame follow would arrive after the hit)
			if duquesa and duquesa.Parent and seatPivot then
				duquesa:PivotTo(CFrame.new(Vector3.new(ev.x, ev.y, ev.z) + seatOffset) * duquesa:GetPivot().Rotation)
			end
			local burst = part("Strike_" .. ev.lunge, Enum.PartType.Ball, Vector3.new(2, 2, 2), RAGE_RED, 0.3)
			burst.Position = Vector3.new(ev.x, ev.y, ev.z)
			TweenService:Create(burst, TweenInfo.new(0.3), { Size = Vector3.new(8, 8, 8), Transparency = 1 }):Play()
			Debris:AddItem(burst, 0.4)
			local player = ev.outcome == "Hit" and Players:GetPlayerByUserId(ev.id)
			if player then task.spawn(landLunge, player, ev) end
		elseif ev.kind == "Calm" then
			clearMarker()
			setRed(false)
		elseif ev.kind == "Vanish" then
			-- RC6: calmed outside the plot she vanishes in a pink burst there; the Home that follows sits her on her seat
			local burst = part("Vanish", Enum.PartType.Ball, Vector3.new(3, 3, 3), BUBBLE, 0.2)
			burst.Position = Vector3.new(ev.x, ev.y, ev.z)
			TweenService:Create(burst, TweenInfo.new(0.5), { Size = Vector3.new(10, 10, 10), Transparency = 1 }):Play()
			Debris:AddItem(burst, 0.6)
		elseif ev.kind == "Home" then
			sitDown()
		end
	end
end

-- DR: the lunge's line from her to the thief and the ring on the thief's floor follow the thief until the lock (D-1),
-- then stay on the locked spot until the strike.
local function drawMarker(rootOf)
	local her = Duq.position(state)
	local root = marker and her and not marker.locked and rootOf(marker.id)
	if not root and not (marker and her and marker.locked) then return end
	local from = Vector3.new(her.x, her.y, her.z)
	local to = marker.locked or root.Position
	local length = math.max((to - from).Magnitude, 0.5)
	marker.line.Size = Vector3.new(0.35, 0.2, length)
	marker.line.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	marker.ring.CFrame = CFrame.new(to.X, to.Y - Duq.FEET_STUDS + 0.1, to.Z) * CFrame.Angles(0, 0, math.rad(90))
end

local function rootOfId(id)
	local player = Players:GetPlayerByUserId(id)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
-- V5-D2: her line, ring and gaze never point at a hidden thief
local function seenRootOf(id)
	local player = Players:GetPlayerByUserId(id)
	if player and hiddenNow(player) then return nil end
	return rootOfId(id)
end

local function yawOf(v) return math.atan2(-v.X, -v.Z) end

local clock, lastPhase, glideAt = 0, "Seated", 0
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	-- DR: while she is away from her seat her model follows the rules' position every frame (no raycast)
	local her = Duq.position(state)
	if her and duquesa and duquesa.Parent and seatPivot then
		local target = Vector3.new(her.x, her.y, her.z) + seatOffset
		local current = duquesa:GetPivot().Position
		local at = current:Lerp(target, math.min(1, dt * 10))
		local rage = state.rage
		local root = rage and seenRootOf(rage.id)
		local look = root and (root.Position - at) or (seatPivot.Position - at)
		local yaw = Vector3.new(look.X, 0, look.Z).Magnitude > 0.5 and yawOf(look) - yawOf(seatPivot.LookVector) or nil
		local rotation = yaw and CFrame.Angles(0, yaw, 0) * seatPivot.Rotation or duquesa:GetPivot().Rotation
		duquesa:PivotTo(CFrame.new(at) * rotation)
	end
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
			local v = root.AssemblyLinearVelocity -- OF3: she aims ahead of a runner
			local entry = { id = player.UserId, alive = true, x = root.Position.X, y = root.Position.Y, z = root.Position.Z,
				vx = v.X, vz = v.Z, speed = humanoid.WalkSpeed }
			-- DR: her egg on this player's back (WildboundServer's WildboundEggCarried model names the egg)
			local arms = character:FindFirstChild("WildboundEggCarried")
			-- D-2: no model, no rage (an invisible Duquesa never hits). D-5: only the newest carried egg is visible here.
			if arms and duquesa and duquesa.Parent and herEggs[arms:GetAttribute("EggId")] then
				entry.carriesHerEgg = true
				entry.safe = select(2, Rules.zone(root.Position.X, root.Position.Z)) == true
			end
			-- V5-D2: hiding (see Hiding above)
			local hidden = player:GetAttribute("WildboundHidden") ~= nil
			local mine = state.rage ~= nil and state.rage.id == player.UserId
			if mine and not hidden then hideSearch, hideWatch = nil, nil end
			if hidden and mine and not hideSearch then
				hideSearch = Hiding.newSearch(root.Position.X, root.Position.Z, now, "Duquesa:" .. player.UserId)
				hideWatch = { dwell = Hiding.newWatch(), at = now }
			end
			local searching = hidden and mine and hideSearch ~= nil
			if hidden and not searching then entry = nil end
			if searching then
				local her = Duq.position(state)
				local dt = now - hideWatch.at
				hideWatch.at = now
				local d = her and math.sqrt((her.x - root.Position.X) ^ 2 + (her.z - root.Position.Z) ^ 2)
				if d and Hiding.finds(hideWatch.dwell, dt, d, "Day") then
					local network = ReplicatedStorage:FindFirstChild("WildboundNetwork")
					local found = network and network:FindFirstChild("HideFound")
					if found and found:IsA("BindableEvent") then found:Fire(player, her.x, her.z) end
					entry.hidden = true -- released by the world script before her next step
				elseif Hiding.expired(hideSearch, now) then
					entry = nil -- the search ran out: she calms (Gone) and floats home
				else
					entry.x, entry.z = Hiding.searchPoint(hideSearch, now)
					entry.vx, entry.vz = 0, 0
					entry.hidden = true
				end
			end
			-- V6-D1: the licorice grass (see grass above)
			if entry and not hidden then
				local her = Duq.position(state)
				local px, pz = root.Position.X, root.Position.Z
				local d = her and math.sqrt((her.x - px) ^ 2 + (her.z - pz) ^ 2) or nil
				local concealed = grassCover(player, px, pz, now) and Hiding.concealed(d, true, nil)
				if concealed and not mine then
					entry = nil -- never acquired
				elseif mine and not concealed then
					grass.since, grass.search = nil, nil
				elseif mine then
					grass.since = grass.since or now
					if now - grass.since >= Hiding.GRASS.memorySeconds - 1e-9 then
						grass.search = grass.search or Hiding.newSearch(px, pz, now, "DuquesaGrass:" .. player.UserId)
						if Hiding.expired(grass.search, now) then
							entry = nil -- the search ran out: she calms (Gone) and floats home
						else
							entry.x, entry.z = Hiding.searchPoint(grass.search, now)
							entry.vx, entry.vz = 0, 0
							entry.hidden = true
						end
					end
				end
			end
			if entry then table.insert(players, entry) end
		end
	end
	if not state.rage then hideSearch, hideWatch = nil, nil end
	if not state.rage then grass.since, grass.search = nil, nil end
	local was = Duq.position(state)
	local wasX, wasZ = was and was.x, was and was.z
	local events = Duq.step(state, now, players, summit, resolve)
	-- V4-D12: her flight never enters a house: she stops at its edge and waits (the rage is kept)
	local her = Duq.position(state)
	if her and wasX then her.x, her.z = Smarts.outsideHouses(wasX, wasZ, her.x, her.z, houseDiscs(now)) end
	play(events, now)
	drawMarker(seenRootOf)
	-- DR: her flying clip while she chases or floats home, cued again now and then (the preview player ends one-shots)
	local phase = Duq.phase(state)
	if duquesa then
		if phase ~= lastPhase then duquesa:SetAttribute("DuquesaPhase", phase) end
		if (phase == "Chase" or phase == "Return") and (phase ~= lastPhase or now >= glideAt) then
			rageCue("Glide")
			glideAt = now + 1.5
		end
	end
	lastPhase = phase
end)

-- D-6: a script stop mid-rage puts her back as she was (colour, collisions, seat) and removes the server parts.
local function stop()
	heartbeat:Disconnect()
	clearMarker()
	setRed(false)
	sitDown()
	folder:Destroy()
end
script.Destroying:Connect(stop)
game:BindToClose(stop)
