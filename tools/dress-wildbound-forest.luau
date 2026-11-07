-- Dresses a built WildboundP0 root with the original forest kit. Nothing is attached to the root
-- until every prop is placed, so a refusal or a failure leaves the root exactly as it was.
local Dress = {}

local FLOOR_Y = 0.5 -- Floor top; each kit origin sits on the ground
local PLACEHOLDERS = { TreeTrunk = true, TreeCrown = true } -- greybox trees the kit replaces
local PROPS = {
    FK_Evergreen = true, FK_DeadTree = true, FK_FallenLog = true,
    FK_RootArch = true, FK_RuinDoorway = true, FK_LanternMarker = true,
}
-- The guardian's sight raycasts hit anything with CanQuery on. Only these two parts, the visible
-- trunks, may block them; canopies, arches, doorways, logs and lanterns never hide a player.
-- Their templates carry a collision fidelity that follows the mesh (Box would block the whole
-- root flare); a detached clone cannot take a new fidelity, so it is set on the templates.
local QUERY_PARTS = { FK_Evergreen_Trunk = true, FK_DeadTree_Wood = true }
-- Delivery C, decision D-C1: trees are solid for everyone. Each tree gets one invisible, anchored cylinder about
-- its trunk radius (the layout plan's core_r times the scale), so players bump into trunks and La Silueta's
-- PathfindingService routes go around them. Every other kit part stays non-colliding. The core also answers sight
-- rays, like the trunk it sits inside. tests/WildboundForestDress_Test.luau checks the 14-stud route stays clear.
local CORE_NAME = 'FK_TrunkCore'
local CORE_RADIUS = { FK_Evergreen = 2.5, FK_DeadTree = 3.4 }
local CORE_HEIGHT = 14 -- above a jump, below every tree top
Dress.CORE_RADIUS = table.freeze(table.clone(CORE_RADIUS))
local YIELD_EVERY = 12 -- props per frame, so Studio stays responsive
-- Each lantern holds one short-range light (lit only on the landmarks below since the dread pass). No shadows:
-- it must stay cheap on phones. Lights never affect the guardian's sight rays.
local LANTERN_GLASS = 'FK_LanternMarker_Glass'
local LANTERN_LIGHT = { Brightness = 1.0, Range = 18, Color = Color3.fromRGB(255, 165, 85) }
-- Dread pass (user: fewer lights, the flashlight is what helps): only these landmark lanterns stay lit, one near the
-- camp exit (012) and one at each main fork (014 west, 003 east). Every other lantern keeps its light disabled, not
-- deleted, and its glass stops glowing, so a lit lantern in the fog means a place you can find again.
Dress.LIT_LANTERNS = table.freeze({ FK_LanternMarker_012 = true, FK_LanternMarker_014 = true, FK_LanternMarker_003 = true })
local DARK_GLASS = { Material = Enum.Material.Glass, Color = Color3.fromRGB(58, 44, 34) }

local function refuse(message)
    error('forest dress refused: ' .. message, 0)
end

local function validate(root, templates, instances)
    if typeof(root) ~= 'Instance' then
        refuse('root must be an Instance')
    end
    local decorations = root:FindFirstChild('Decorations')
    if not decorations then
        refuse('root has no Decorations folder')
    end
    if root:FindFirstChild('ForestKit', true) then
        refuse('root already has a ForestKit')
    end
    if typeof(templates) ~= 'Instance' then
        refuse('templates must be an Instance')
    end
    if type(instances) ~= 'table' or #instances == 0 then
        refuse('instances must be a non-empty array')
    end
    local seen = {}
    for index, item in ipairs(instances) do
        if type(item) ~= 'table' or type(item.id) ~= 'string' or item.id == '' then
            refuse('instance #' .. index .. ' needs a string id')
        end
        if seen[item.id] then
            refuse('duplicate id ' .. item.id)
        end
        seen[item.id] = true
        if not PROPS[item.name] then
            refuse(item.id .. ' has unknown prop ' .. tostring(item.name))
        end
        local template = templates:FindFirstChild(item.name)
        if not (template and template:IsA('Model')) then
            refuse('missing template ' .. item.name)
        end
        for _, field in ipairs({ 'x', 'z', 'rotation_y_deg', 'scale' }) do
            local value = item[field]
            if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then
                refuse(item.id .. ' has a bad ' .. field)
            end
        end
        if item.scale <= 0 then
            refuse(item.id .. ' needs a positive scale')
        end
    end
    return decorations
end

local function propOf(id)
    return (string.match(id, '^(.+)_%d+$'))
end

-- Adds the core to one placed tree model, standing on the floor at its pivot. Returns the core.
local function addCore(model, prop, scale)
    local radius = CORE_RADIUS[prop] * scale
    local pivot = model:GetPivot().Position
    local core = Instance.new('Part')
    core.Name = CORE_NAME
    core.Shape = Enum.PartType.Cylinder
    core.Size = Vector3.new(CORE_HEIGHT, radius * 2, radius * 2)
    core.CFrame = CFrame.new(pivot.X, FLOOR_Y + CORE_HEIGHT / 2, pivot.Z) * CFrame.Angles(0, 0, math.pi / 2)
    core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch = true, true, true, false
    core.Transparency, core.CastShadow = 1, false
    core.Parent = model
    return core
end

-- Patches an already dressed ForestKit folder: one core for every tree that has none. Returns how many it added.
function Dress.addTrunkCores(kit)
    local added = 0
    for _, model in kit:GetChildren() do
        local prop = model:IsA('Model') and propOf(model.Name) or nil
        if prop and CORE_RADIUS[prop] and not model:FindFirstChild(CORE_NAME) then
            addCore(model, prop, model:GetScale())
            added += 1
        end
    end
    return added
end

-- Dread pass: patches an already dressed ForestKit folder so only the landmark lanterns glow. Returns how many it
-- darkened; a second call changes nothing. No lantern or light is deleted.
function Dress.dimLanterns(kit)
    local dimmed = 0
    for _, model in kit:GetChildren() do
        if model:IsA('Model') and propOf(model.Name) == 'FK_LanternMarker' and not Dress.LIT_LANTERNS[model.Name] then
            local glass = model:FindFirstChild(LANTERN_GLASS, true)
            local light = glass and glass:FindFirstChildOfClass('PointLight')
            if light and (light.Enabled or glass.Material == Enum.Material.Neon) then
                light.Enabled = false
                glass.Material, glass.Color = DARK_GLASS.Material, DARK_GLASS.Color
                dimmed += 1
            end
        end
    end
    return dimmed
end

local function place(template, item, parent)
    local model = template:Clone()
    assert(model, 'template ' .. item.name .. ' cannot be cloned')
    model.Name = item.id
    for _, descendant in model:GetDescendants() do
        if descendant:IsA('PackageLink') then
            descendant:Destroy()
        elseif descendant:IsA('BasePart') then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = QUERY_PARTS[descendant.Name] == true
        end
    end
    if item.name == 'FK_LanternMarker' then
        local glass = model:FindFirstChild(LANTERN_GLASS, true)
        assert(glass and glass:IsA('BasePart'), 'lantern template needs ' .. LANTERN_GLASS)
        local light = Instance.new('PointLight')
        light.Brightness, light.Range, light.Color = LANTERN_LIGHT.Brightness, LANTERN_LIGHT.Range, LANTERN_LIGHT.Color
        light.Shadows = false
        light.Parent = glass
        if not Dress.LIT_LANTERNS[item.id] then
            light.Enabled = false
            glass.Material, glass.Color = DARK_GLASS.Material, DARK_GLASS.Color
        end
    end
    model:ScaleTo(item.scale)
    model:PivotTo(CFrame.new(item.x, FLOOR_Y, item.z) * CFrame.Angles(0, math.rad(item.rotation_y_deg), 0))
    if CORE_RADIUS[item.name] then
        addCore(model, item.name, item.scale)
    end
    model.Parent = parent
end

-- instances: { { id, name, x, z, rotation_y_deg, scale }, ... } from the layout plan.
-- Returns the new Decorations.ForestKit folder.
function Dress.dress(root, templates, instances)
    local decorations = validate(root, templates, instances)

    local kit = Instance.new('Folder')
    kit.Name = 'ForestKit'
    local ok, failure = pcall(function()
        for index, item in ipairs(instances) do
            place(templates:FindFirstChild(item.name), item, kit)
            if index % YIELD_EVERY == 0 then
                task.wait()
            end
        end
    end)
    if not ok then
        kit:Destroy()
        error(failure, 0)
    end

    -- The root may have changed while the props were placed.
    if not decorations:IsDescendantOf(root) or root:FindFirstChild('ForestKit', true) then
        kit:Destroy()
        refuse('root changed while it was being dressed')
    end
    for _, child in decorations:GetChildren() do
        if PLACEHOLDERS[child.Name] then
            child:Destroy()
        end
    end
    kit.Parent = decorations
    return kit
end

return Dress
