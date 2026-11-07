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
local YIELD_EVERY = 12 -- props per frame, so Studio stays responsive
-- Each lantern glows with one short-range light, so the path edge and avatar stay readable in the
-- dark. No shadows: it must stay cheap on phones. Lights never affect the guardian's sight rays.
local LANTERN_GLASS = 'FK_LanternMarker_Glass'
local LANTERN_LIGHT = { Brightness = 1.0, Range = 18, Color = Color3.fromRGB(255, 165, 85) }

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
    end
    model:ScaleTo(item.scale)
    model:PivotTo(CFrame.new(item.x, FLOOR_Y, item.z) * CFrame.Angles(0, math.rad(item.rotation_y_deg), 0))
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
