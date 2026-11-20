-- Caramelo's chocolate look (TB-2, owner request 2026-11-20: "que el agua marron sea de la toolbox tambien, no se si se
-- puede cambiar los colores"). Client-only: a Texture with the Creator Store chocolate image (WildboundCandyChocoLook.IMAGE)
-- on the upward face of the chocolate liquid parts of Caramelo (CaramelV3.River's Choco_River_<n> and Choco_Pool,
-- CaramelV3.Lake's Choco_Lake_<n>, Candy_Este_v1.CloudWall.MouthSheet), tinted from the part's own colour, slowly
-- scrolling downstream. The round joints stay plain, and so does a pool or lake disc whose centre lies inside a
-- streamed river block (Look.insideBlock): overlapping see-through textures on one plane would draw doubled and
-- flicker. The rules (which parts, which face, the tint, the scroll math, the near test, the overlap test) live in
-- WildboundCandyChocoLook; this script only finds the parts, makes the textures and writes the offsets.
--   scan     at start, at most every DIRTY_SECONDS after a watched folder changes (the map streams in) and every
--            SCAN_SECONDS anyway: new parts get their texture, parts gone (streamed out) drop theirs, a part that
--            changed colour is re-tinted;
--   scroll   at most 10 Hz (STEP_SECONDS), only while the camera is within NEAR_STUDS of the chocolate's box, never with
--            "Efectos suaves" (the world gui's Reduced, set by WildboundStart from WildboundSettings): the texture then
--            stays still;
--   server   never: a LocalScript, and it returns at once if it ever runs where RunService is not the client;
--   cleanup  every texture goes when the script goes (script.Destroying).
-- The textures are made here only (nothing replicates) and touch nothing else of the parts. Nothing named
-- SistemaSonriente, or inside it, is ever touched. Rules: WildboundCandyChocoLook_Test.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsClient() then return end

local Look = require(ReplicatedStorage:WaitForChild("WildboundCandyChocoLook"))

local player = Players.LocalPlayer
local entries = {} -- [part] = { texture, face, color, du, dv, speed }
local watched = {} -- [container] = { connections }
local connections = {}
local box = nil -- the chocolate's flat box { minX, maxX, minZ, maxZ }, nil when none is streamed in
local dirty = true

local function allowed(item)
	return item.Name ~= Look.FORBIDDEN and item:FindFirstAncestor(Look.FORBIDDEN) == nil
end
local function worldGui()
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end
local function reduced()
	local gui = worldGui()
	return gui ~= nil and gui:GetAttribute("Reduced") == true
end

local function markDirty() dirty = true end
local function watch(container)
	if watched[container] then return end
	watched[container] = { container.ChildAdded:Connect(markDirty), container.ChildRemoved:Connect(markDirty) }
end
local function unwatchGone()
	for container, list in pairs(watched) do
		if container.Parent == nil then
			for _, connection in ipairs(list) do connection:Disconnect() end
			watched[container] = nil
		end
	end
end

local function flatUnit(v)
	local m = math.sqrt(v.X * v.X + v.Z * v.Z)
	if m < 1e-6 then return nil end
	return Vector3.new(v.X / m, 0, v.Z / m)
end

local function tintOf(color)
	local r, g, b = Look.tint(color.R, color.G, color.B)
	return Color3.new(r, g, b)
end

local function dropEntry(part)
	local entry = entries[part]
	if entry and entry.texture then entry.texture:Destroy() end
	entries[part] = nil
end

local function makeTexture(part, face, color)
	local spec = Look.spec(face, color.R, color.G, color.B)
	local old = part:FindFirstChild(spec.name)
	if old and old:IsA("Texture") then old:Destroy() end
	local texture = Instance.new("Texture")
	texture.Name = spec.name
	texture.Texture = spec.image
	texture.Face = Enum.NormalId[spec.face]
	texture.StudsPerTileU = spec.studsPerTile
	texture.StudsPerTileV = spec.studsPerTile
	texture.OffsetStudsU = 0
	texture.OffsetStudsV = 0
	texture.Transparency = spec.transparency
	texture.Color3 = Color3.new(spec.color[1], spec.color[2], spec.color[3])
	texture.Parent = part
	return texture
end

-- Every chocolate part streamed in now: { part, kind, index }, and the river blocks by leg.
local function findParts()
	local found, rivers = {}, {}
	local biome = workspace:FindFirstChild(Look.ROOT_NAME)
	if biome and allowed(biome) then
		watch(biome)
		local v3 = biome:FindFirstChild(Look.V3_FOLDER)
		if v3 and allowed(v3) then
			watch(v3)
			for _, folderName in ipairs(Look.FOLDERS) do
				local container = v3:FindFirstChild(folderName)
				if container and allowed(container) then
					watch(container)
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("BasePart") and allowed(child) then
							local kind, index = Look.classify(child.Name)
							if kind and Look.accepts(folderName, kind) then
								table.insert(found, { part = child, kind = kind, index = index })
								if kind == "river" and index then rivers[index] = child end
							end
						end
					end
				end
			end
		end
	end
	local east = workspace:FindFirstChild(Look.EAST_ROOT)
	if east and allowed(east) then
		watch(east)
		local wall = east:FindFirstChild(Look.EAST_FOLDER)
		if wall and allowed(wall) then
			watch(wall)
			local sheet = wall:FindFirstChild(Look.MOUTH_NAME)
			if sheet and sheet:IsA("BasePart") and allowed(sheet) and Look.accepts(Look.EAST_FOLDER, "mouth") then
				table.insert(found, { part = sheet, kind = "mouth" })
			end
		end
	end
	return found, rivers
end

-- Whether a streamed river block's footprint holds the part's centre (its texture already covers the part).
local function coveredByRiver(part, rivers)
	local at = part.Position
	for _, river in pairs(rivers) do
		local cf, size = river.CFrame, river.Size
		local p, look = cf.Position, cf.LookVector
		if Look.insideBlock(at.X, at.Z, p.X, p.Z, look.X, look.Z, size.X / 2, size.Z / 2) then return true end
	end
	return false
end

-- The one direction every textured lake disc flows (flat world unit vector): the river block nearest the centre of
-- those discs, so overlapping discs always scroll together; nil with no disc or no block.
local function lakeDirectionOf(found, rivers)
	local sumX, sumZ, count = 0, 0, 0
	for _, f in ipairs(found) do
		if f.kind == "lake" then
			sumX, sumZ, count = sumX + f.part.Position.X, sumZ + f.part.Position.Z, count + 1
		end
	end
	if count == 0 then return nil end
	local cx, cz = sumX / count, sumZ / count
	local best, bestDistance = nil, math.huge
	for _, river in pairs(rivers) do
		local p = river.Position
		local distance = (p.X - cx) ^ 2 + (p.Z - cz) ^ 2
		if distance < bestDistance then best, bestDistance = river, distance end
	end
	return best and flatUnit(best.CFrame.LookVector) or nil
end

-- The direction a part's chocolate flows (flat world unit vector), or nil when nothing gives one.
local function directionOf(f, rivers, lakeDirection)
	local leg = Look.legFor(f.kind, f.index, function(i) return rivers[i] ~= nil end)
	if leg and rivers[leg] then return flatUnit(rivers[leg].CFrame.LookVector) end
	if f.kind == "mouth" then return Vector3.new(Look.MOUTH_FLOW[1], 0, Look.MOUTH_FLOW[2]) end
	if f.kind == "lake" then return lakeDirection end
	return nil
end

local function scan()
	dirty = false
	unwatchGone()
	local all, rivers = findParts()
	local found = {}
	for _, f in ipairs(all) do
		if not (Look.coverable(f.kind) and coveredByRiver(f.part, rivers)) then table.insert(found, f) end
	end
	local lakeDirection = lakeDirectionOf(found, rivers)
	local keep = {}
	for _, f in ipairs(found) do keep[f.part] = true end
	for part in pairs(entries) do
		if not keep[part] or part.Parent == nil then dropEntry(part) end
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, f in ipairs(found) do
		local part = f.part
		local cf = part.CFrame
		local face = Look.upFace(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y)
		local color = part.Color
		local entry = entries[part]
		if not entry or entry.face ~= face or entry.texture.Parent ~= part then
			dropEntry(part)
			entry = { texture = makeTexture(part, face, color), face = face, color = color }
			entries[part] = entry
		elseif entry.color ~= color then
			entry.texture.Color3 = tintOf(color)
			entry.color = color
		end
		local du, dv = 0, 0
		local direction = directionOf(f, rivers, lakeDirection)
		if direction then
			local l = cf:VectorToObjectSpace(direction)
			du, dv = Look.project(face, l.X, l.Y, l.Z)
		end
		entry.du, entry.dv, entry.speed = du, dv, Look.speedFor(f.kind)
		local p, reach = part.Position, part.Size.Magnitude / 2
		minX, maxX = math.min(minX, p.X - reach), math.max(maxX, p.X + reach)
		minZ, maxZ = math.min(minZ, p.Z - reach), math.max(maxZ, p.Z + reach)
	end
	box = if #found > 0 then { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ } else nil
end

-- One scroll step (at most 10 Hz): every texture's offsets from the clock, while near and not with Efectos suaves.
local function step(now)
	local camera = workspace.CurrentCamera
	if not box or not camera then return end
	local at = camera.CFrame.Position
	if not Look.shouldScroll(reduced(), Look.near(box, at.X, at.Z, Look.NEAR_STUDS)) then return end
	for part, entry in pairs(entries) do
		if part.Parent and entry.texture.Parent == part and (entry.du ~= 0 or entry.dv ~= 0) then
			local u, v = Look.offsets(now, entry.speed, entry.du, entry.dv, Look.STUDS_PER_TILE)
			entry.texture.OffsetStudsU = u
			entry.texture.OffsetStudsV = v
		end
	end
end

local warned = false
local function guarded(run, ...)
	local ok, message = pcall(run, ...)
	if not ok and not warned then
		warned = true
		warn("Wildbound chocolate look: " .. tostring(message))
	end
end

guarded(scan)

table.insert(connections, workspace.ChildAdded:Connect(function(child)
	if child.Name == Look.ROOT_NAME or child.Name == Look.EAST_ROOT then markDirty() end
end))

local scanClock, stepClock = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	scanClock += dt
	stepClock += dt
	if scanClock >= Look.SCAN_SECONDS or (dirty and scanClock >= Look.DIRTY_SECONDS) then
		scanClock = 0
		guarded(scan)
	end
	if stepClock >= Look.STEP_SECONDS then
		stepClock = 0
		guarded(step, os.clock())
	end
end))

table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, list in pairs(watched) do
		for _, connection in ipairs(list) do connection:Disconnect() end
	end
	table.clear(watched)
	for part in pairs(entries) do dropEntry(part) end
	box = nil
end))
