-- Caramelo v6 "life on the map" (odd/tasks/wildbound-caramelo-v2.md V6-D6; docs/design/wildbound-caramelo-v3-plan.md
-- V6-D50 on). Client-only decoration of the candy biome (Workspace.Candy_Bioma_v1): gummy birds circling over the
-- meadows, caramel butterflies fluttering at the houses and the lollipop avenue, chocolate fish jumping out of the river
-- and the lake now and then. No gameplay effect: plain anchored parts that never collide, touch or block a ray, made at
-- runtime in one folder under the camera (nothing replicates) and removed when the player leaves the biome.
--   biome    the same enter and leave rule as the candy ambience (WildboundCandyAmbience.inside, with its hysteresis),
--            from the live floor's rectangle or the Caramelo square of WildboundBiomeLight;
--   culling  at 2 Hz, WildboundCandyLife.plan picks the flocks, butterfly sites and fish spots nearest the camera within
--            their reach and the device's budget; the rest are destroyed (no work for what is far away);
--   budget   fewer on touch devices; with Efectos suaves (the world gui's Reduced) nothing at all: it is all motion;
--   frame    every frame (Heartbeat), one bulk move for every shown part.
-- The plot's centre and floor height come from the live floor part (Ground.Floor), else the layout's numbers. Nothing
-- is sent anywhere: no remote, no attribute written.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Life = require(ReplicatedStorage:WaitForChild("WildboundCandyLife"))
local Ambience = require(ReplicatedStorage:WaitForChild("WildboundCandyAmbience"))
local fallbackBounds = nil
do
	local found = ReplicatedStorage:WaitForChild("WildboundBiomeLight", 10)
	local ok, value = pcall(function() return found and Ambience.fallbackBounds(require(found)) end)
	fallbackBounds = ok and value or nil
end

local player = Players.LocalPlayer
local biome = nil
local floorBounds, frame = nil, nil
local inCandy = false
local budget = Life.budget(false, false)
local holder = nil
local flocks, sites, spots = {}, {}, {} -- [id] = { parts..., per-creature records }
local connections = {}

local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local function worldGui()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end

-- Parts -------------------------------------------------------------------------------------------------------
local function newPart(name, shape, size, color, parent)
	local part = Instance.new("Part")
	part.Name, part.Shape, part.Size, part.Color = name, shape, size, color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Massless = true
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.CFrame = CFrame.new(0, -500, 0)
	part.Parent = parent
	return part
end

local function ensureHolder()
	if holder and holder.Parent then return end
	if holder then holder:Destroy() end
	holder = Instance.new("Folder")
	holder.Name = "WildboundCandyLife"
	holder.Parent = workspace.CurrentCamera or workspace
	flocks, sites, spots = {}, {}, {}
end

local function newFlock(flock)
	local color = rgb(flock.color)
	local entry = { flock = flock, birds = {} }
	for k = 1, Life.FLOCK_SIZE do
		entry.birds[k] = {
			body = newPart("GummyBird", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), color, holder),
			left = newPart("WingL", Enum.PartType.Block, Vector3.new(3, 0.25, 1.6), color, holder),
			right = newPart("WingR", Enum.PartType.Block, Vector3.new(3, 0.25, 1.6), color, holder),
			phase = k * 0.27,
		}
		entry.birds[k].body.Transparency = 0.1
	end
	return entry
end

local function newSite(site)
	local entry = { site = site, flies = {} }
	for k = 1, Life.PER_SITE do
		local colors = Life.BUTTERFLY_COLORS
		local color = rgb(colors[math.floor(site.phase * 10 + k) % #colors + 1])
		entry.flies[k] = {
			body = newPart("Butterfly", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.8), Color3.fromRGB(110, 62, 40), holder),
			left = newPart("WingL", Enum.PartType.Block, Vector3.new(0.9, 0.06, 0.8), color, holder),
			right = newPart("WingR", Enum.PartType.Block, Vector3.new(0.9, 0.06, 0.8), color, holder),
			phase = k * 0.31,
		}
	end
	return entry
end

local function newSpot(spot)
	local body = newPart("ChocoFish", Enum.PartType.Cylinder, Vector3.new(2.4, 1.1, 1.1), Color3.fromRGB(110, 62, 40), holder)
	local tail = newPart("Tail", Enum.PartType.Block, Vector3.new(0.7, 1, 0.2), Color3.fromRGB(80, 44, 28), holder)
	body.Transparency, tail.Transparency = 1, 1
	return { spot = spot, body = body, tail = tail, up = false }
end

local function dropEntry(entry)
	for _, list in ipairs({ entry.birds or {}, entry.flies or {} }) do
		for _, c in ipairs(list) do
			c.body:Destroy(); c.left:Destroy(); c.right:Destroy()
		end
	end
	if entry.body then entry.body:Destroy() end
	if entry.tail then entry.tail:Destroy() end
end

-- Keeps what is still picked, destroys the rest, makes the new ones.
local function reconcile(store, picks, make)
	local wanted = {}
	for _, item in ipairs(picks) do wanted[item.id] = item end
	for id, entry in pairs(store) do
		if not wanted[id] then
			dropEntry(entry)
			store[id] = nil
		end
	end
	for _, item in ipairs(picks) do
		if not store[item.id] then store[item.id] = make(item) end
	end
end

local function teardown()
	if holder then holder:Destroy() end
	holder = nil
	flocks, sites, spots = {}, {}, {}
end

-- The plot ---------------------------------------------------------------------------------------------------
local function readFloor()
	if (floorBounds and frame) or not biome then return end
	local ground = biome:FindFirstChild("Ground")
	local floor = ground and ground:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		local p, s = floor.Position, floor.Size
		floorBounds = Ambience.boundsFromFloor(p.X, p.Z, s.X, s.Z)
		frame = Life.plotFrame(p.X, p.Y, p.Z, s.X, s.Y, s.Z)
	end
end

local FALLBACK_FRAME = Life.plotFrame(nil)
local function plotFrame()
	return frame or FALLBACK_FRAME
end

-- The 2 Hz step: in or out, the budget, then the nearest creatures.
local function refresh()
	if not biome or biome.Parent == nil then
		biome, floorBounds, frame = workspace:FindFirstChild(Life.ROOT_NAME), nil, nil
	end
	readFloor()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local at = root and root.Position or (camera and camera.Focus.Position)
	inCandy = biome ~= nil and at ~= nil and Ambience.inside(inCandy, floorBounds or fallbackBounds, at.X, at.Z)
	local gui = worldGui()
	local soft = gui ~= nil and gui:GetAttribute("Reduced") == true
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	budget = Life.budget(touch, soft)
	if budget.birds + budget.butterflies + budget.fish == 0 then inCandy = false end
	if not inCandy then
		teardown()
		return
	end
	ensureHolder()
	local f = plotFrame()
	local eyePos = camera and camera.CFrame.Position or at
	local plan = Life.plan(budget, { x = eyePos.X - f.x, z = eyePos.Z - f.z })
	reconcile(flocks, plan.flocks, newFlock)
	reconcile(sites, plan.sites, newSite)
	reconcile(spots, plan.spots, newSpot)
end

-- Every frame ------------------------------------------------------------------------------------------------
local moveParts, moveFrames = {}, {}
local function push(part, cf)
	table.insert(moveParts, part)
	table.insert(moveFrames, cf)
end

-- A body facing from a to b (flat when the two are too close), with its two wings flapping about its sides.
local function placeWinged(c, a, b, wingAngle, span)
	local look = b - a
	local cf = look.Magnitude > 1e-3 and CFrame.lookAt(a, b) or CFrame.new(a)
	push(c.body, cf)
	local half = c.left.Size.X / 2
	push(c.left, cf * CFrame.Angles(0, 0, wingAngle) * CFrame.new(-half - span, 0, 0))
	push(c.right, cf * CFrame.Angles(0, 0, -wingAngle) * CFrame.new(half + span, 0, 0))
end

local function animate(t)
	table.clear(moveParts)
	table.clear(moveFrames)
	local f = plotFrame()
	local function world(x, y, z) return Vector3.new(f.x + x, f.top + y, f.z + z) end
	for _, entry in pairs(flocks) do
		for k, c in ipairs(entry.birds) do
			local a = world(Life.birdPosition(entry.flock, k, t))
			local b = world(Life.birdPosition(entry.flock, k, t + 0.1))
			placeWinged(c, a, b, Life.flap(t, 2.5, 35, c.phase), 0.9)
		end
	end
	for _, entry in pairs(sites) do
		for k, c in ipairs(entry.flies) do
			local a = world(Life.butterflyPosition(entry.site, k, t))
			local b = world(Life.butterflyPosition(entry.site, k, t + 0.1))
			placeWinged(c, a, b, Life.flap(t, 7, 55, c.phase), 0.05)
		end
	end
	local surface = Life.CHOCO_DEPTH
	for _, entry in pairs(spots) do
		local jump = Life.fishJump(entry.spot, t)
		local up = jump ~= nil
		if up ~= entry.up then
			entry.up = up
			entry.body.Transparency, entry.tail.Transparency = up and 0 or 1, up and 0 or 1
		end
		if jump then
			local pos = world(jump.x, surface + jump.y, jump.z)
			local dir = Vector3.new(math.cos(jump.heading), 0, math.sin(jump.heading))
			-- the cylinder's axis is its X: turn X along the jump, then tip the nose up by the pitch
			local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(jump.pitch, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
			push(entry.body, cf)
			-- the tail behind the body (its -X), wagging side to side
			push(entry.tail, cf * CFrame.new(-1.45, 0, 0) * CFrame.Angles(0, Life.flap(t, 4, 25, 0), 0))
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

task.spawn(function()
	biome = workspace:WaitForChild(Life.ROOT_NAME, 120)
end)

local pickClock = Life.PICK_SECONDS
local warned = false
local function report(message)
	if not warned then
		warned = true
		warn("Wildbound candy life: " .. tostring(message))
	end
end
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	pickClock += dt
	if pickClock >= Life.PICK_SECONDS then
		pickClock = 0
		local ok, message = pcall(refresh)
		if not ok then
			teardown()
			report(message)
		end
	end
	if inCandy and holder then
		local ok, message = pcall(animate, os.clock())
		if not ok then
			teardown()
			report(message)
		end
	end
end))

table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	teardown()
end))
