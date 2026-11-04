-- Run once in Studio's Edit command context; this file is not a runtime script.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
assert(not Workspace:FindFirstChild("HorrorMapBlockout"), "Map already exists; do not overwrite it")
local baseplate = assert(Workspace:FindFirstChild("Baseplate"), "Expected original Baseplate")
local spawn = assert(Workspace:FindFirstChild("SpawnLocation"), "Expected original SpawnLocation")
assert(baseplate:IsA("BasePart") and spawn:IsA("BasePart"), "Unexpected original objects")
assert((baseplate.Position - Vector3.new(0, -8, 0)).Magnitude < 0.1, "Unexpected baseplate position")
assert((spawn.Position - Vector3.new(0, 0.5, 0)).Magnitude < 0.1, "Unexpected spawn position")

-- Attribute values are captured before any lighting changes. Existing effects are untouched.
local atmospheres = {}
for _, effect in ipairs(Lighting:GetChildren()) do
    if effect:IsA("Atmosphere") then table.insert(atmospheres, effect) end
end
assert(#atmospheres == 1, "Expected exactly one existing Atmosphere")
local atmosphere = atmospheres[1]
local baseline = {
    AtmosphereName = atmosphere.Name, AtmosphereDensity = atmosphere.Density,
    AtmosphereOffset = atmosphere.Offset, AtmosphereHaze = atmosphere.Haze,
    Ambient = {Lighting.Ambient.R, Lighting.Ambient.G, Lighting.Ambient.B},
    OutdoorAmbient = {Lighting.OutdoorAmbient.R, Lighting.OutdoorAmbient.G, Lighting.OutdoorAmbient.B},
    FogColor = {Lighting.FogColor.R, Lighting.FogColor.G, Lighting.FogColor.B},
    FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local root = Instance.new("Folder")
root.Name = "HorrorMapBlockout"
root:SetAttribute("LightingBaseline", HttpService:JSONEncode(baseline))
root:SetAttribute("Seed", 86041)
root:SetAttribute("MapWidth", 1600)
root:SetAttribute("RouteWidth", 42)
root:SetAttribute("SpawnClearRadius", 65)
root:SetAttribute("GeneratorVersion", 1)
root.Parent = Workspace
local random = Random.new(86041)
local count = 0
local chunkCount = 0
local biome
local chunk
local function flush()
    if chunk then
        chunk.Parent = biome
        chunk = nil
        task.wait()
    end
end
local function beginBiome(name)
    flush()
    biome = Instance.new("Folder")
    biome.Name = name
    biome.Parent = root
    chunk = nil
    chunkCount = 0
end
local function part(name, size, position, color, material, collidable, shape, rotation)
    if not chunk or chunkCount >= 180 then
        flush()
        chunk = Instance.new("Folder")
        chunk.Name = "Chunk"
        chunkCount = 0
    end
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Color = color
    p.Material = material
    p.CanCollide = collidable
    p.CanTouch = false
    p.CanQuery = collidable
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if shape then p.Shape = shape end
    if rotation then p.CFrame = CFrame.new(position) * CFrame.Angles(0, rotation, 0) end
    p.Parent = chunk
    chunkCount += 1
    count += 1
    return p
end
local routes = {
    {-500, -500, 0, -310}, {0, -310, 500, -500},
    {500, -500, 530, 100}, {530, 100, 410, 500},
    {410, 500, -410, 500}, {-410, 500, -530, 100},
    {-530, 100, -500, -500}, {0, 0, 0, -310},
    {0, 0, -530, 100}, {0, 0, 530, 100}, {0, 0, 0, 500},
}
local function segmentDistance(x, z, a, b, c, d)
    local dx, dz = c - a, d - b
    local t = math.clamp(((x-a)*dx + (z-b)*dz) / (dx*dx + dz*dz), 0, 1)
    local px, pz = a + t*dx, b + t*dz
    return math.sqrt((x-px)^2 + (z-pz)^2)
end
local function clear(x, z, radius)
    if math.sqrt(x*x + z*z) < 65 + radius then return false end
    for _, r in ipairs(routes) do
        if segmentDistance(x, z, table.unpack(r)) < 21 + radius then return false end
    end
    return true
end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function disk(name, x, z, sx, sz, color, material)
    part(name, Vector3.new(sx, 0.12, sz), Vector3.new(x, 0.08, z), color, material, false)
end
beginBiome("Ground")
for _, tile in ipairs({
    {-400, -400, rgb(64, 76, 61), Enum.Material.Grass},
    {400, -400, rgb(103, 102, 88), Enum.Material.Ground},
    {-400, 400, rgb(78, 86, 65), Enum.Material.Grass},
    {400, 400, rgb(79, 86, 68), Enum.Material.Ground},
}) do
    part("BiomeGround", Vector3.new(800, 0.04, 800), Vector3.new(tile[1], 0.02, tile[2]), tile[3], tile[4], false)
end

beginBiome("Paths")
for _, r in ipairs(routes) do
    local a, b = Vector3.new(r[1], 0.14, r[2]), Vector3.new(r[3], 0.14, r[4])
    local delta = b - a
    -- Blocks extend beyond each segment's ends so adjoining paths overlap.
    part("Trail", Vector3.new(42, 0.15, delta.Magnitude + 42), (a+b)/2,
        rgb(91, 83, 70), Enum.Material.Ground, false, nil, math.atan2(delta.X, delta.Z))
end
disk("Clearing", 0, 0, 125, 125, rgb(124, 116, 94), Enum.Material.Ground)

beginBiome("Forest")
for i = 1, 420 do
    local x, z = random:NextNumber(-740, -80), random:NextNumber(-740, -80)
    if clear(x, z, 23) then
        local h = random:NextNumber(26, 46)
        local width = random:NextNumber(4, 7)
        part("Trunk", Vector3.new(width, h, width), Vector3.new(x, h/2, z), rgb(59, 51, 43), Enum.Material.Wood, true)
        local leaf = random:NextNumber(25, 37)
        part("Canopy", Vector3.new(leaf, leaf*0.7, leaf), Vector3.new(x, h+leaf*0.15, z),
            rgb(37, random:NextInteger(52, 67), 45), Enum.Material.Grass, false, Enum.PartType.Ball)
    end
end

beginBiome("TransitionWoodland")
for i = 1, 400 do
    local x, z = random:NextNumber(-760, 760), random:NextNumber(-760, 760)
    if clear(x, z, 24) then
        local h = random:NextNumber(20, 36)
        local marsh = z > 200
        part("TreeTrunk", Vector3.new(4, h, 4), Vector3.new(x, h/2, z), rgb(68, 63, 52), Enum.Material.Wood, true)
        if not marsh or random:NextNumber() < 0.35 then
            part("TreeCrown", Vector3.new(22, 19, 22), Vector3.new(x, h+5, z), rgb(55, 70, 53), Enum.Material.Grass, false, Enum.PartType.Ball)
        else
            part("DeadBranch", Vector3.new(20, 3, 3), Vector3.new(x, h*0.8, z), rgb(68, 63, 52), Enum.Material.Wood, false, nil, random:NextNumber(0, math.pi))
        end
    end
end

beginBiome("Ridge")
for i = 1, 115 do
    local x, z = random:NextNumber(100, 735), random:NextNumber(-735, -80)
    local radius = random:NextNumber(8, 20)
    if clear(x, z, radius + 2) then
        local h = random:NextNumber(9, 38)
        part("Boulder", Vector3.new(radius*2, h, radius*1.5), Vector3.new(x, h*0.35, z),
            rgb(91, 94, 91), Enum.Material.Slate, true, Enum.PartType.Ball, random:NextNumber(0, math.pi))
    end
end
-- A broken arch is placed off-route with room around each column.
for _, x in ipairs({610, 666}) do
    part("RuinColumn", Vector3.new(12, 45, 12), Vector3.new(x, 22.5, -630), rgb(105, 103, 94), Enum.Material.Slate, true)
end
part("RuinLintel", Vector3.new(68, 8, 12), Vector3.new(638, 48, -630), rgb(105, 103, 94), Enum.Material.Slate, true)

beginBiome("Marsh")
for i = 1, 85 do
    local x, z = random:NextNumber(-725, 725), random:NextNumber(175, 730)
    local radius = random:NextNumber(12, 25)
    if clear(x, z, radius + 5) then
        disk("ShallowWater", x, z, radius*2, radius*1.25, rgb(57, 87, 80), Enum.Material.Glass)
        for j = 1, 3 do
            local rx, rz = x + random:NextNumber(-radius/2, radius/2), z + random:NextNumber(-radius/2, radius/2)
            part("Reeds", Vector3.new(1, 8, 1), Vector3.new(rx, 4, rz), rgb(102, 109, 68), Enum.Material.Grass, false)
        end
    end
end
beginBiome("Landmarks")
-- Low, non-collidable markers make junctions legible without obstructing travel.
for _, pos in ipairs({{-100, -110}, {100, -110}, {-100, 110}, {100, 110}}) do
    part("Waystone", Vector3.new(8, 15, 8), Vector3.new(pos[1], 7.5, pos[2]), rgb(130, 120, 99), Enum.Material.Slate, true)
end
-- A small warm shelter landmark stands away from the routes and spawn.
for _, x in ipairs({-145, -115}) do
    for _, z in ipairs({150, 170}) do
        part("ShelterPost", Vector3.new(3, 20, 3), Vector3.new(x, 10, z), rgb(92, 67, 46), Enum.Material.Wood, true)
    end
end
part("ShelterRoof", Vector3.new(40, 3, 29), Vector3.new(-130, 21, 160), rgb(84, 62, 47), Enum.Material.WoodPlanks, true)
part("Lantern", Vector3.new(4, 6, 4), Vector3.new(-130, 15, 159), rgb(245, 176, 82), Enum.Material.Neon, false)
flush()
root:SetAttribute("PartCount", count)
Lighting.Ambient = rgb(72, 73, 71)
Lighting.OutdoorAmbient = rgb(102, 102, 95)
Lighting.FogColor = rgb(120, 130, 126)
Lighting.FogStart = 180
Lighting.FogEnd = 1050
Lighting.Brightness = 1.7
Lighting.ClockTime = 17.6
Lighting.ExposureCompensation = 0
atmosphere.Density = 0.38
atmosphere.Offset = 0.2
atmosphere.Haze = 1
print("HorrorMapBlockout created with " .. count .. " parts. Run validate-map.luau in Edit mode.")
