-- Editable, self-contained P0 greybox. No services or existing instances are changed.
local Builder = {}

local palette = {
    ground = Color3.fromRGB(67, 83, 70),
    path = Color3.fromRGB(145, 130, 100),
    bark = Color3.fromRGB(67, 72, 57),
    leaves = Color3.fromRGB(54, 91, 77),
    stone = Color3.fromRGB(100, 108, 98),
    marsh = Color3.fromRGB(52, 104, 101),
    amber = Color3.fromRGB(223, 160, 70),
    cyan = Color3.fromRGB(102, 210, 202),
}

local points = {
    Vector3.new(-140, 0, 140), -- camp
    Vector3.new(-95, 0, 75), -- clearing
    Vector3.new(0, 0, -85), -- ruin
    Vector3.new(110, 0, -130), -- egg nest
    Vector3.new(115, 0, 15), -- marsh
    Vector3.new(105, 0, 125), -- shelter
}

local function folder(parent, name)
    local item = Instance.new('Folder')
    item.Name = name
    item.Parent = parent
    return item
end

local function part(parent, name, size, frame, color, material, collision)
    local item = Instance.new('Part')
    item.Name = name
    item.Size = size
    item.CFrame = frame
    item.Color = color
    item.Material = material or Enum.Material.SmoothPlastic
    item.Anchored = true
    item.CanCollide = collision == true
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    item.Parent = parent
    return item
end

local function distanceToSegment(point, a, b)
    local segment = b - a
    local t = math.clamp((point - a):Dot(segment) / segment:Dot(segment), 0, 1)
    return (point - (a + segment * t)).Magnitude
end

local function awayFromRoute(x, z, margin)
    local point = Vector3.new(x, 0, z)
    for index, a in ipairs(points) do
        local b = points[index % #points + 1]
        if distanceToSegment(point, a, b) < margin then
            return false
        end
    end
    for _, center in ipairs(points) do
        if (point - center).Magnitude < 22 then
            return false
        end
    end
    return true
end

local function addMarker(parent, name, x, z)
    local marker = part(parent, name, Vector3.new(2, 1, 2), CFrame.new(x, 1.5, z), palette.cyan, nil, false)
    marker.Transparency = 1
    marker.CanTouch = false
    marker.CanQuery = false
end

function Builder.build(parent)
    assert(typeof(parent) == 'Instance', 'parent must be an Instance')
    assert(not parent:FindFirstChild('WildboundP0'), 'WildboundP0 already exists')

    -- Construct detached and publish the complete root only after the final guard.
    local root = Instance.new('Model')
    root.Name = 'WildboundP0'
    local paths = folder(root, 'Paths')
    local decorations = folder(root, 'Decorations')
    local markers = folder(root, 'Markers')
    part(root, 'Floor', Vector3.new(400, 1, 400), CFrame.new(0, 0, 0), palette.ground, Enum.Material.Grass, true)

    for index, a in ipairs(points) do
        local b = points[index % #points + 1]
        local middle = (a + b) / 2 + Vector3.new(0, 0.55, 0)
        local path = part(paths, 'Path' .. index, Vector3.new(14, 0.1, (b - a).Magnitude + 14),
            CFrame.lookAt(middle, middle + (b - a)), palette.path, Enum.Material.Ground, true)
        path:SetAttribute('FromZone', index)
    end

    addMarker(markers, 'CampCenter', -140, 140)
    addMarker(markers, 'ExtractionMarker', -146, 140)
    addMarker(markers, 'HatchMarker', -135, 146)
    addMarker(markers, 'ProtectionMarker', -135, 134)
    addMarker(markers, 'LumipolMarker', -95, 75)
    addMarker(markers, 'GuardianMarker', 0, -85)
    addMarker(markers, 'EggMarker', 110, -130)

    -- Readable, nonblocking landmark shapes; marker interactions are added elsewhere.
    part(decorations, 'CampfireBase', Vector3.new(5, 0.5, 5), CFrame.new(-140, 0.8, 140), palette.stone, nil, false)
    local fire = part(decorations, 'CampfireGlow', Vector3.new(2.2, 3, 2.2), CFrame.new(-140, 2.5, 140), palette.amber, Enum.Material.Neon, false)
    fire.Shape = Enum.PartType.Ball
    local light = Instance.new('PointLight')
    light.Color = palette.amber
    light.Brightness = 1.2
    light.Range = 22
    light.Parent = fire
    local clearing = part(decorations, 'ClearingBeacon', Vector3.new(3, 5, 3), CFrame.new(-95, 3, 75), palette.cyan, Enum.Material.Neon, false)
    clearing.Shape = Enum.PartType.Ball
    for _, offset in ipairs({Vector3.new(-10, 0, -7), Vector3.new(10, 0, -7), Vector3.new(-10, 0, 8), Vector3.new(10, 0, 8)}) do
        part(decorations, 'RuinPillar', Vector3.new(3, 12, 3), CFrame.new(Vector3.new(0, 6.5, -85) + offset), palette.stone, Enum.Material.Slate, false)
    end
    for index = 1, 8 do
        local angle = index * math.pi / 4
        local x, z = 110 + math.cos(angle) * 9, -130 + math.sin(angle) * 9
        local rock = part(decorations, 'NestStone', Vector3.new(4, 2, 3), CFrame.new(x, 1.5, z), palette.stone, Enum.Material.Slate, false)
        rock.Shape = Enum.PartType.Ball
    end
    local water = part(decorations, 'MarshPool', Vector3.new(32, 0.12, 24), CFrame.new(128, 0.58, 15), palette.marsh, Enum.Material.SmoothPlastic, false)
    water.Transparency = 0.3
    part(decorations, 'ShelterRoof', Vector3.new(18, 1, 12), CFrame.new(105, 10, 125), palette.bark, Enum.Material.WoodPlanks, false)
    for _, offset in ipairs({Vector3.new(-7, 0, -4), Vector3.new(7, 0, -4), Vector3.new(-7, 0, 4), Vector3.new(7, 0, 4)}) do
        part(decorations, 'ShelterPost', Vector3.new(1.5, 9, 1.5), CFrame.new(Vector3.new(105, 5, 125) + offset), palette.bark, Enum.Material.Wood, false)
    end

    -- Fixed seed keeps rebuilding reproducible; route buffer avoids obscuring sightlines.
    local random = Random.new(42015)
    local created = 0
    for _ = 1, 120 do
        local x, z = random:NextNumber(-180, 180), random:NextNumber(-180, 180)
        if awayFromRoute(x, z, 20) then
            local height = random:NextNumber(12, 19)
            part(decorations, 'TreeTrunk', Vector3.new(2.5, height, 2.5), CFrame.new(x, 0.5 + height / 2, z), palette.bark, Enum.Material.Wood, false)
            local crown = part(decorations, 'TreeCrown', Vector3.new(10, 11, 10), CFrame.new(x, height + 1, z), palette.leaves, nil, false)
            crown.Shape = Enum.PartType.Ball
            created += 2
            if created % 100 == 0 then
                task.wait()
            end
        end
    end
    if parent:FindFirstChild('WildboundP0') then
        root:Destroy()
        error('WildboundP0 appeared during construction')
    end
    root.Parent = parent
    return root
end

return Builder
