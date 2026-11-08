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
    Vector3.new(35, 0, -99), -- egg nest
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

-- Delivery B (B4): the camp stations. Warm wood, canvas and brick under a few shadowless lights, so the camp reads
-- safe and unlike the grey-green forest. Every part is anchored and never queried or touched, so nothing here can
-- block Silueta's sight or count as Lumipol cover; only the solid bases collide, all away from the spawn point.
-- Signs carry a SignKey attribute and an empty label: the server fills them from ReplicatedStorage.WildboundText.
local CAMP = Vector3.new(-140, 0.5, 140)
local campColors = {
    wood = Color3.fromRGB(132, 92, 58),
    darkWood = Color3.fromRGB(92, 64, 42),
    canvas = Color3.fromRGB(214, 190, 150),
    warm = Color3.fromRGB(255, 176, 96),
    brick = Color3.fromRGB(150, 104, 80),
    slate = Color3.fromRGB(120, 112, 104),
    brass = Color3.fromRGB(206, 160, 82),
    rug = Color3.fromRGB(150, 70, 52),
    sand = Color3.fromRGB(181, 150, 108),
    glass = Color3.fromRGB(200, 230, 255),
    ink = Color3.fromRGB(255, 228, 180),
}

local function campPart(parent, name, size, frame, color, material, collide, shape)
    local item = part(parent, name, size, frame, color, material, collide)
    item.CanQuery = false
    item.CanTouch = false
    if shape then item.Shape = shape end
    return item
end

local function campMarker(markers, name, x, z)
    local marker = part(markers, name, Vector3.new(2, 1, 2), CFrame.new(x, 1.5, z), palette.cyan, nil, false)
    marker.Transparency = 1
    marker.CanTouch = false
    marker.CanQuery = false
end

local function lamp(parent, name, frame, range, brightness)
    local glow = campPart(parent, name, Vector3.new(0.8, 0.9, 0.8), frame, campColors.warm, Enum.Material.Neon, false)
    local light = Instance.new('PointLight')
    light.Color = campColors.warm
    light.Brightness = brightness or 1
    light.Range = range or 14
    light.Shadows = false
    light.Parent = glow
    return glow
end

local function sign(parent, key, size, frame)
    local board = campPart(parent, 'Sign_' .. key, size, frame, campColors.darkWood, Enum.Material.WoodPlanks, false)
    board:SetAttribute('SignKey', key)
    local gui = Instance.new('SurfaceGui')
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.LightInfluence = 0
    gui.Parent = board
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = campColors.ink
    label.Text = ''
    label.Parent = gui
    return board
end

-- A frame at (x, z) on the ground whose front (-Z) faces the camp fire.
local function facingCamp(x, z)
    return CFrame.lookAt(Vector3.new(x, 0.5, z), Vector3.new(CAMP.X, 0.5, CAMP.Z))
end

local function lanternPost(parent, x, z)
    local base = facingCamp(x, z)
    campPart(parent, 'LanternPost', Vector3.new(0.4, 4.2, 0.4), base * CFrame.new(0, 2.1, 0), campColors.darkWood, Enum.Material.Wood, false)
    lamp(parent, 'CampLantern', base * CFrame.new(0, 4.5, 0), 14, 0.9)
end

local function buildRefuge(parent)
    local refuge = folder(parent, 'Refuge')
    local base = facingCamp(-152, 128)
    campPart(refuge, 'RefugeFloor', Vector3.new(7, 0.4, 7), base * CFrame.new(0, 0.2, 0), campColors.wood, Enum.Material.WoodPlanks, false)
    campPart(refuge, 'RefugeRug', Vector3.new(5, 0.08, 4), base * CFrame.new(0, 0.44, 0), campColors.rug, Enum.Material.Fabric, false)
    for _, corner in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
        campPart(refuge, 'RefugePost', Vector3.new(0.8, 6, 0.8), base * CFrame.new(corner[1], 3, corner[2]), campColors.darkWood, Enum.Material.Wood, true)
    end
    campPart(refuge, 'RefugeRoof', Vector3.new(8, 0.4, 4.6), base * CFrame.new(0, 6.6, -1.9) * CFrame.Angles(-0.44, 0, 0), campColors.canvas, Enum.Material.Fabric, false)
    campPart(refuge, 'RefugeRoof', Vector3.new(8, 0.4, 4.6), base * CFrame.new(0, 6.6, 1.9) * CFrame.Angles(0.44, 0, 0), campColors.canvas, Enum.Material.Fabric, false)
    campPart(refuge, 'RefugeNest', Vector3.new(0.6, 3.2, 3.2), base * CFrame.new(0, 0.7, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 98, 62), Enum.Material.Fabric, false, Enum.PartType.Cylinder)
    lamp(refuge, 'RefugeGlow', base * CFrame.new(0, 1.6, 0.6), 16, 1.2).Shape = Enum.PartType.Ball
    sign(refuge, 'refuge', Vector3.new(4, 1.1, 0.25), base * CFrame.new(0, 5.4, -3.5))
end

local function buildDisplay(parent)
    local display = folder(parent, 'Display')
    for index, z in ipairs({ 136, 140, 144, 148 }) do
        local base = CFrame.lookAt(Vector3.new(-160, 0.5, z), Vector3.new(CAMP.X, 0.5, z))
        campPart(display, 'Pedestal', Vector3.new(1.4, 2.4, 2.4), base * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), campColors.brick, Enum.Material.Brick, true, Enum.PartType.Cylinder)
        local spot = campPart(display, 'DisplaySpot' .. index, Vector3.new(1, 0.2, 1), base * CFrame.new(0, 1.5, 0), palette.cyan, nil, false)
        spot.Transparency = 1
        local plaque = campPart(display, 'Plaque' .. index, Vector3.new(1.8, 0.5, 0.1), base * CFrame.new(0, 0.7, -1.25), campColors.brass, Enum.Material.Metal, false)
        local gui = Instance.new('SurfaceGui')
        gui.Face = Enum.NormalId.Front
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 50
        gui.LightInfluence = 0
        gui.Parent = plaque
        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.fromRGB(60, 40, 24)
        label.Text = ''
        label.Parent = gui
    end
    local back = CFrame.lookAt(Vector3.new(-162.5, 0.5, 142), Vector3.new(CAMP.X, 0.5, 142))
    for _, side in ipairs({ -8.5, 8.5 }) do
        campPart(display, 'DisplayPost', Vector3.new(0.5, 5.6, 0.5), back * CFrame.new(side, 2.8, 0), campColors.darkWood, Enum.Material.Wood, false)
    end
    campPart(display, 'DisplayBeam', Vector3.new(17.5, 0.5, 0.5), back * CFrame.new(0, 5.4, 0), campColors.darkWood, Enum.Material.Wood, false)
    sign(display, 'display', Vector3.new(6, 1.1, 0.25), back * CFrame.new(0, 4.5, -0.3))
    lamp(display, 'DisplayLantern', back * CFrame.new(0, 6.1, 0), 16, 1)
end

local function buildChest(parent)
    local chest = folder(parent, 'Chest')
    local base = facingCamp(-147.5, 140)
    campPart(chest, 'ChestBody', Vector3.new(2.8, 1.4, 1.8), base * CFrame.new(0, 0.7, 0), campColors.wood, Enum.Material.WoodPlanks, true)
    campPart(chest, 'ChestLid', Vector3.new(2.9, 0.5, 1.9), base * CFrame.new(0, 1.65, 0), campColors.darkWood, Enum.Material.WoodPlanks, false)
    for _, x in ipairs({ -0.9, 0.9 }) do
        campPart(chest, 'ChestBand', Vector3.new(0.2, 1.95, 1.95), base * CFrame.new(x, 0.95, 0), campColors.brass, Enum.Material.Metal, false)
    end
    sign(chest, 'chestObject', Vector3.new(3, 0.7, 0.2), base * CFrame.new(0, 2.6, 0.6))
end

local function buildBoard(parent)
    local board = folder(parent, 'Board')
    local base = facingCamp(-150, 154)
    for _, x in ipairs({ -1.9, 1.9 }) do
        campPart(board, 'BoardPost', Vector3.new(0.5, 4.6, 0.5), base * CFrame.new(x, 2.3, 0), campColors.darkWood, Enum.Material.Wood, true)
    end
    campPart(board, 'BoardPanel', Vector3.new(4.2, 2.6, 0.3), base * CFrame.new(0, 3, -0.2), campColors.wood, Enum.Material.WoodPlanks, false)
    for index, offset in ipairs({ { -1.2, 3.3 }, { 0.1, 2.7 }, { 1.2, 3.2 } }) do
        campPart(board, 'BoardNote' .. index, Vector3.new(0.9, 1.1, 0.05), base * CFrame.new(offset[1], offset[2], -0.4) * CFrame.Angles(0, 0, (index - 2) * 0.08), campColors.canvas, Enum.Material.Fabric, false)
    end
    sign(board, 'boardObject', Vector3.new(4.4, 0.8, 0.25), base * CFrame.new(0, 4.75, -0.2))
    lamp(board, 'BoardLantern', base * CFrame.new(2.4, 4.4, -0.3), 12, 0.9)
end

local function buildIncubator(parent)
    local incubator = folder(parent, 'Incubator')
    local base = facingCamp(-136, 158)
    campPart(incubator, 'IncubatorBase', Vector3.new(1.2, 3.4, 3.4), base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), campColors.slate, Enum.Material.Slate, true, Enum.PartType.Cylinder)
    local dome = campPart(incubator, 'IncubatorDome', Vector3.new(3, 3, 3), base * CFrame.new(0, 2.2, 0), campColors.glass, Enum.Material.Glass, false, Enum.PartType.Ball)
    dome.Transparency = 0.55
    campPart(incubator, 'IncubatorPlaceholderEgg', Vector3.new(1.1, 1.5, 1.1), base * CFrame.new(0, 1.95, 0), campColors.canvas, Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
    campPart(incubator, 'IncubatorSignPost', Vector3.new(0.4, 4.6, 0.4), base * CFrame.new(2.5, 2.3, 0), campColors.darkWood, Enum.Material.Wood, false)
    sign(incubator, 'incubatorObject', Vector3.new(3, 0.7, 0.2), base * CFrame.new(2.5, 4.4, -0.3))
    sign(incubator, 'incubator', Vector3.new(3, 0.6, 0.2), base * CFrame.new(2.5, 3.6, -0.3))
    lamp(incubator, 'IncubatorLamp', base * CFrame.new(0, 4, 0), 10, 0.7)
end

-- Adds the camp to an existing WildboundP0 root (also used to patch a dressed map without a rebuild). It refuses a
-- second camp and builds detached, attaching the folder only once it is complete.
function Builder.buildCamp(root)
    assert(typeof(root) == 'Instance', 'root must be an Instance')
    assert(not root:FindFirstChild('Camp'), 'Camp already exists')
    local camp = Instance.new('Folder')
    camp.Name = 'Camp'
    local disc = campPart(camp, 'CampGround', Vector3.new(0.06, 40, 40), CFrame.new(-146, 0.53, 143) * CFrame.Angles(0, 0, math.rad(90)), campColors.sand, Enum.Material.Sand, false, Enum.PartType.Cylinder)
    disc.CastShadow = false
    buildRefuge(camp)
    buildDisplay(camp)
    buildChest(camp)
    buildBoard(camp)
    buildIncubator(camp)
    lanternPost(camp, -147, 131)
    lanternPost(camp, -131, 152)
    campPart(camp, 'BenchLog', Vector3.new(4.5, 0.9, 0.9), CFrame.new(-140, 0.95, 133.5), campColors.darkWood, Enum.Material.Wood, false, Enum.PartType.Cylinder)
    campPart(camp, 'BenchLog', Vector3.new(4.5, 0.9, 0.9), CFrame.new(-146.5, 0.95, 147) * CFrame.Angles(0, math.rad(60), 0), campColors.darkWood, Enum.Material.Wood, false, Enum.PartType.Cylinder)
    local markers = root:FindFirstChild('Markers') or camp
    campMarker(markers, 'RefugeMarker', -152, 128)
    campMarker(markers, 'BoardMarker', -150, 154)
    campMarker(markers, 'IncubatorMarker', -136, 158)
    camp.Parent = root
    return camp
end

-- Delivery D7: hiding spots from assets/maps/forest-layout/hide-spots-v1.json (tools/plan_hide_spots.py); a Python
-- test keeps this table equal to the file. Bushes are primitive placeholders; logs mark existing FK_FallenLog models.
local HIDE_SPOTS = {
    { id = 'H01', kind = 'bush', x = 34.0, z = -77.0, yaw = 0.0, scale = 1.0 },
    { id = 'H02', kind = 'bush', x = -45.0, z = -36.0, yaw = 0.0, scale = 1.0 },
    { id = 'H03', kind = 'bush', x = 82.0, z = -8.0, yaw = 0.0, scale = 1.0 },
    { id = 'H04', kind = 'bush', x = 125.0, z = 6.0, yaw = 0.0, scale = 1.0 },
    { id = 'H05', kind = 'bush', x = 101.0, z = 47.0, yaw = 0.0, scale = 1.0 },
    { id = 'H06', kind = 'bush', x = -116.0, z = 83.0, yaw = 0.0, scale = 1.0 },
    { id = 'H07', kind = 'log', x = 26.035, z = -127.646, yaw = 69.307, scale = 1.023 },
    { id = 'H08', kind = 'log', x = 106.187, z = -38.363, yaw = 201.296, scale = 0.927 },
    { id = 'H09', kind = 'log', x = 56.05, z = -37.936, yaw = 344.359, scale = 0.994 },
    { id = 'H10', kind = 'log', x = -43.753, z = 24.663, yaw = 318.678, scale = 0.911 },
}
local HIDE_GROUND = 0.5
local hideColors = { bush = Color3.fromRGB(34, 58, 38), bushDark = Color3.fromRGB(24, 42, 30), hollow = Color3.fromRGB(14, 12, 10) }

local function hidePart(parent, name, size, frame, color, query, shape)
    local item = part(parent, name, size, frame, color, Enum.Material.Grass, false)
    item.CanQuery = query
    item.CanTouch = false
    item.CastShadow = query
    if shape then item.Shape = shape end
    return item
end

-- Adds the hiding spots to an existing WildboundP0 root (patches a dressed map without a rebuild), once.
function Builder.buildHideSpots(root)
    assert(typeof(root) == 'Instance', 'root must be an Instance')
    assert(not root:FindFirstChild('HideSpots'), 'HideSpots already exists')
    local CollectionService = game:GetService('CollectionService')
    local spots = Instance.new('Folder')
    spots.Name = 'HideSpots'
    for _, spec in ipairs(HIDE_SPOTS) do
        local model = Instance.new('Model')
        model.Name = 'HideSpot_' .. spec.id
        model:SetAttribute('SpotId', spec.id)
        model:SetAttribute('Kind', spec.kind)
        local frame = CFrame.new(spec.x, HIDE_GROUND, spec.z) * CFrame.Angles(0, math.rad(spec.yaw), 0)
        if spec.kind == 'bush' then
            hidePart(model, 'Bush', Vector3.new(4.6, 3.5, 4.6), frame * CFrame.new(0, 1.6, 0), hideColors.bush, true, Enum.PartType.Ball)
            hidePart(model, 'Bush', Vector3.new(3.4, 2.6, 3.4), frame * CFrame.new(1.6, 1.2, 0.8), hideColors.bushDark, true, Enum.PartType.Ball)
            hidePart(model, 'Bush', Vector3.new(3.2, 2.4, 3.2), frame * CFrame.new(-1.5, 1.1, -0.9), hideColors.bushDark, true, Enum.PartType.Ball)
        else
            -- The log itself stays untouched; a dark disc at one end reads as the hollow.
            local reach = 8.2 * spec.scale
            hidePart(model, 'Hollow', Vector3.new(0.3, 2.6 * spec.scale, 2.6 * spec.scale),
                frame * CFrame.new(reach, 1.9 * spec.scale, 0), hideColors.hollow, false, Enum.PartType.Cylinder)
        end
        local zone = part(model, 'HideZone', Vector3.new(5, 3, 5), frame * CFrame.new(0, 1.5, 0), hideColors.bush, nil, false)
        zone.Transparency, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, false, false, false
        local prompt = Instance.new('ProximityPrompt')
        prompt.Name = 'HidePrompt'
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 7
        prompt.HoldDuration = 0.4
        prompt.Parent = zone
        model.PrimaryPart = zone
        CollectionService:AddTag(model, 'WildboundHideSpot')
        model.Parent = spots
    end
    spots.Parent = root
    return spots
end

-- Expedition relief (R3, decision EI-1): low ridges of anchored parts from ServerStorage.WildboundReliefLayout
-- (tools/plan_relief.py, tools/export_relief_luau.py), never Roblox Terrain. Each segment is a flat crest Part, two
-- flank WedgeParts, two end-cap WedgeParts and four CornerWedgeParts, so its surface is exactly the height rule in
-- src/wildbound/WildboundRelief.luau. Every part collides (players and La Silueta walk on it) and answers queries (a
-- crest blocks sight rays); none is touched. Builds detached and attaches the folder once complete; refuses a second.
local RELIEF_FLOOR = 0.5
local RELIEF_UP = Vector3.new(0, 1, 0)

local function reliefPart(parent, class, name, size, frame)
    local item = Instance.new(class)
    item.Name = name
    item.Size = size
    item.CFrame = frame
    item.Color = palette.ground
    item.Material = Enum.Material.Grass
    item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, true, true, false
    item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    item.Parent = parent
    return item
end

-- A WedgePart rises toward its local +Z: `rise` is the horizontal direction toward the high side.
local function reliefWedge(parent, name, centre, rise, width, height, run)
    local xAxis = Vector3.new(rise.Z, 0, -rise.X)
    return reliefPart(parent, 'WedgePart', name, Vector3.new(width, height, run), CFrame.fromMatrix(centre, xAxis, RELIEF_UP))
end

-- A CornerWedgePart's apex is over its local (+X, -Z) corner; the apex goes to the crest corner, opposite `across`
-- and `along` (the outward directions of the corner region).
local function reliefCorner(parent, centre, across, along, height, run)
    local xAxis = -across
    if xAxis:Cross(RELIEF_UP):Dot(along) < 0.5 then xAxis = -along end
    return reliefPart(parent, 'CornerWedgePart', 'RidgeCorner', Vector3.new(run, height, run), CFrame.fromMatrix(centre, xAxis, RELIEF_UP))
end

local function finiteNumber(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e6
end

local function buildRidge(parent, seg)
    for _, key in ipairs({ 'ax', 'az', 'bx', 'bz', 'height', 'crestWidth', 'slopeDeg' }) do
        assert(finiteNumber(seg[key]), 'relief segment ' .. tostring(seg.id) .. ' has a bad ' .. key)
    end
    local a, b = Vector3.new(seg.ax, 0, seg.az), Vector3.new(seg.bx, 0, seg.bz)
    local length, height, crest = (b - a).Magnitude, seg.height, seg.crestWidth
    assert(length > 0.01 and height > 0 and crest > 0 and seg.slopeDeg > 0 and seg.slopeDeg <= 20,
        'relief segment ' .. tostring(seg.id) .. ' is degenerate or too steep')
    local run = height / math.tan(math.rad(seg.slopeDeg))
    local u = (b - a).Unit
    local v = Vector3.new(-u.Z, 0, u.X) -- across the ridge, as WildboundRelief measures d
    local middle = (a + b) / 2 + Vector3.new(0, RELIEF_FLOOR + height / 2, 0)
    local model = Instance.new('Model')
    model.Name = 'Ridge_' .. tostring(seg.id)
    model:SetAttribute('Feature', seg.feature)
    reliefPart(model, 'Part', 'RidgeCrest', Vector3.new(crest, height, length), CFrame.fromMatrix(middle, v, RELIEF_UP))
    local flankOut, capOut = crest / 2 + run / 2, length / 2 + run / 2
    for _, side in ipairs({ 1, -1 }) do
        reliefWedge(model, 'RidgeFlank', middle + v * side * flankOut, -v * side, length, height, run)
        reliefWedge(model, 'RidgeCap', middle + u * side * capOut, -u * side, crest, height, run)
    end
    for _, along in ipairs({ 1, -1 }) do
        for _, across in ipairs({ 1, -1 }) do
            reliefCorner(model, middle + u * along * capOut + v * across * flankOut, v * across, u * along, height, run)
        end
    end
    model.Parent = parent
    return model
end

function Builder.buildRelief(root, layout)
    assert(typeof(root) == 'Instance', 'root must be an Instance')
    assert(not root:FindFirstChild('Relief'), 'Relief already exists')
    assert(type(layout) == 'table' and type(layout.segments) == 'table', 'relief layout needs segments')
    local relief = Instance.new('Folder')
    relief.Name = 'Relief'
    local ok, failure = pcall(function()
        for _, seg in ipairs(layout.segments) do buildRidge(relief, seg) end
    end)
    if not ok then
        relief:Destroy()
        error(failure, 0)
    end
    relief.Parent = root
    return relief
end

-- Expedition islands (I8, docs/mechanics/wildbound-expedition-islands.md section 2): one nest per island from the
-- island layout (ServerScriptService.WildboundIslandLayout, generated by tools/plan_islands.py). A nest is a low bed, a
-- glowing ring and a transparent NestMarker the inventory server spawns the cria or egg on. Nothing here collides,
-- answers queries or is touched: the relief rims are the only island geometry that blocks. Trees whose trunk stands
-- on an island floor (the planner's removed trees and any extra tree grown there) are taken out of the ForestKit.
-- Builds detached, attaches the folder once complete and refuses a second build.
local ISLAND_FLOOR = 0.5
local TREE_PREFIXES = { 'FK_Evergreen', 'FK_DeadTree' }
local islandColors = {
    bed = Color3.fromRGB(110, 82, 54),
    straw = Color3.fromRGB(186, 160, 98),
    glow = Color3.fromRGB(90, 230, 210),
}

local function islandPart(parent, name, size, frame, color, material, shape)
    local item = part(parent, name, size, frame, color, material, false)
    item.CanQuery, item.CanTouch, item.CastShadow = false, false, false
    if shape then item.Shape = shape end
    return item
end

local function isTree(name)
    for _, prefix in ipairs(TREE_PREFIXES) do
        if string.sub(name, 1, #prefix) == prefix then return true end
    end
    return false
end

local function clearIslandTrees(root, islands)
    local kit = root:FindFirstChild('ForestKit', true)
    if not kit then return 0 end
    local removed = 0
    for _, model in ipairs(kit:GetChildren()) do
        if model:IsA('Model') and isTree(model.Name) then
            local pivot = model:GetPivot().Position
            for _, spec in ipairs(islands) do
                if Vector2.new(pivot.X - spec.x, pivot.Z - spec.z).Magnitude < spec.floorRadius + 2 then
                    model:Destroy()
                    removed += 1
                    break
                end
            end
        end
    end
    return removed
end

function Builder.buildIslands(root, layout)
    assert(typeof(root) == 'Instance', 'root must be an Instance')
    assert(not root:FindFirstChild('Islands'), 'Islands already exists')
    assert(type(layout) == 'table' and type(layout.islands) == 'table', 'island layout needs islands')
    local islands = Instance.new('Folder')
    islands.Name = 'Islands'
    for _, spec in ipairs(layout.islands) do
        local model = Instance.new('Model')
        model.Name = 'Island_' .. spec.id
        model:SetAttribute('IslandId', spec.id)
        model:SetAttribute('Species', spec.species)
        local base = CFrame.new(spec.x, ISLAND_FLOOR, spec.z)
        local upright = CFrame.Angles(0, 0, math.rad(90))
        islandPart(model, 'NestBed', Vector3.new(0.8, 6.5, 6.5), base * CFrame.new(0, 0.4, 0) * upright,
            islandColors.bed, Enum.Material.Wood, Enum.PartType.Cylinder)
        islandPart(model, 'NestStraw', Vector3.new(0.3, 5.2, 5.2), base * CFrame.new(0, 0.9, 0) * upright,
            islandColors.straw, Enum.Material.Fabric, Enum.PartType.Cylinder)
        local glow = islandPart(model, 'NestGlow', Vector3.new(0.12, 7.2, 7.2), base * CFrame.new(0, 0.14, 0) * upright,
            islandColors.glow, Enum.Material.Neon, Enum.PartType.Cylinder)
        glow.Transparency = 0.35
        local light = Instance.new('PointLight')
        light.Color, light.Brightness, light.Range, light.Shadows = islandColors.glow, 1.2, 14, false
        light.Parent = glow
        local marker = islandPart(model, 'NestMarker', Vector3.new(1, 1, 1), base * CFrame.new(0, 0.5, 0),
            islandColors.glow, Enum.Material.SmoothPlastic)
        marker.Transparency = 1
        model.PrimaryPart = marker
        model.Parent = islands
    end
    clearIslandTrees(root, layout.islands)
    islands.Parent = root
    return islands
end

function Builder.build(parent, reliefLayout, islandLayout)
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
    addMarker(markers, 'EggMarker', 35, -99)

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
        local x, z = 35 + math.cos(angle) * 9, -99 + math.sin(angle) * 9
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
    Builder.buildCamp(root)
    if reliefLayout ~= nil then Builder.buildRelief(root, reliefLayout) end
    if islandLayout ~= nil then Builder.buildIslands(root, islandLayout) end
    if parent:FindFirstChild('WildboundP0') then
        root:Destroy()
        error('WildboundP0 appeared during construction')
    end
    root.Parent = parent
    return root
end

return Builder
