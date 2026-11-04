-- Run after generation in the same Studio Edit context; this is not installed in the place.
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local root = assert(Workspace:FindFirstChild("HorrorMapBlockout"), "Missing map")
local baseplate = assert(Workspace:FindFirstChild("Baseplate"), "Missing original Baseplate")
local spawn = assert(Workspace:FindFirstChild("SpawnLocation"), "Missing original SpawnLocation")
assert(baseplate:IsA("BasePart") and spawn:IsA("SpawnLocation"), "Original object types changed")
assert((baseplate.Position - Vector3.new(0, -8, 0)).Magnitude < 0.1, "Baseplate moved")
assert((spawn.Position - Vector3.new(0, 0.5, 0)).Magnitude < 0.1, "Spawn moved")
local baseline = HttpService:JSONDecode(assert(root:GetAttribute("LightingBaseline"), "Missing lighting baseline"))
assert(baseline.Ambient and baseline.OutdoorAmbient and baseline.FogColor and baseline.FogEnd, "Incomplete baseline")
local count = 0
for _, object in ipairs(root:GetDescendants()) do
    assert(not object:IsA("LuaSourceContainer"), "Unexpected executable source: " .. object:GetFullName())
    if object:IsA("BasePart") then
        count += 1
        assert(object.Anchored, "Unanchored: " .. object:GetFullName())
        -- Check all rotated corners rather than only each object's center.
        for _, x in ipairs({-1, 1}) do
            for _, y in ipairs({-1, 1}) do
                for _, z in ipairs({-1, 1}) do
                    local corner = object.CFrame:PointToWorldSpace(object.Size * Vector3.new(x, y, z) / 2)
                    assert(math.abs(corner.X) <= 800 and math.abs(corner.Z) <= 800, "Outside map: " .. object:GetFullName())
                end
            end
        end
    end
end
assert(count == root:GetAttribute("PartCount") and count > 100 and count <= 2500, "Unexpected part count")
for _, name in ipairs({"Ground", "Paths", "Forest", "TransitionWoodland", "Ridge", "Marsh", "Landmarks"}) do
    local biome = assert(root:FindFirstChild(name), "Missing biome: " .. name)
    assert(#biome:GetDescendants() > 1, "Empty biome: " .. name)
    for _, chunk in ipairs(biome:GetChildren()) do
        assert(#chunk:GetChildren() <= 180, "Chunk exceeds bound")
    end
end
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {root}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = {baseplate}
local function check(x, z)
    local hit = Workspace:Raycast(Vector3.new(x, 12, z), Vector3.new(0, -30, 0), ray)
    assert(hit and hit.Instance == baseplate, string.format("Missing floor at %.1f, %.1f", x, z))
    local parts = Workspace:GetPartBoundsInBox(CFrame.new(x, 4, z), Vector3.new(4, 7, 4), overlap)
    for _, p in ipairs(parts) do
        assert(not p.CanCollide, string.format("Blocked at %.1f, %.1f by %s", x, z, p:GetFullName()))
    end
end
local routes = {
    {-500,-500,0,-310}, {0,-310,500,-500}, {500,-500,530,100},
    {530,100,410,500}, {410,500,-410,500}, {-410,500,-530,100},
    {-530,100,-500,-500}, {0,0,0,-310}, {0,0,-530,100},
    {0,0,530,100}, {0,0,0,500},
}
for _, r in ipairs(routes) do
    local dx, dz = r[3]-r[1], r[4]-r[2]
    local length = math.sqrt(dx*dx + dz*dz)
    local steps = math.ceil(length/8)
    for i = 0, steps do
        local t = i/steps
        for _, offset in ipairs({-19, -10, 0, 10, 19}) do
            check(r[1]+dx*t-dz/length*offset, r[2]+dz*t+dx/length*offset)
        end
    end
end
for x = -60, 60, 10 do
    for z = -60, 60, 10 do
        if x*x + z*z <= 60*60 then check(x, z) end
    end
end
print(string.format("Map validation passed: %d anchored parts; routes and spawn sampled with floor support.", count))
