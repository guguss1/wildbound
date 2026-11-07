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
-- Dread pass (user: taller trees and trunk cores to match, a denser, more disturbing forest so we feel small).
-- Trees grow uniformly on top of their layout scale; the trunk core grows with them.
Dress.TREE_GROWTH = table.freeze({ FK_Evergreen = 1.6, FK_DeadTree = 1.4 })
local GROWTH_ATTRIBUTE = 'WildboundGrowth'
-- Extra trees from thicken carry ids from 9001 up, so a second call can see it already ran.
Dress.THICKEN_MAX = 50
local THICKEN_FIRST_ID = 9001
local THICKEN_STEP = 11 -- candidate grid, studs
local THICKEN_ROUTE_MARGIN = 3 -- extra studs beyond the half route width
local THICKEN_SPACING = 5 -- studs between core edges
-- Each lantern holds one short-range light (lit only on the landmarks below since the dread pass). No shadows:
-- it must stay cheap on phones. Lights never affect the guardian's sight rays.
local LANTERN_GLASS = 'FK_LanternMarker_Glass'
local LANTERN_LIGHT = { Brightness = 1.0, Range = 18, Color = Color3.fromRGB(255, 165, 85) }
-- Dread pass (user: fewer lights, the flashlight is what helps): only these landmark lanterns stay lit, one near the
-- camp exit (012) and one at each main fork (014 west, 003 east). Every other lantern keeps its light disabled, not
-- deleted, and its glass stops glowing, so a lit lantern in the fog means a place you can find again.
Dress.LIT_LANTERNS = table.freeze({ FK_LanternMarker_012 = true, FK_LanternMarker_014 = true, FK_LanternMarker_003 = true })
local DARK_GLASS = { Material = Enum.Material.Glass, Color = Color3.fromRGB(58, 44, 34) }
-- Expedition relief (R4): props stand on the relief's height rule (a WildboundRelief object passed in as
-- `options.relief`, anything with heightAt and slopeAt), trees the relief planner lists as removed are not placed,
-- and no tree stands where the ground is steeper than this. Without a relief everything stands on the floor.
Dress.TREE_MAX_SLOPE = 12
local GROUND_ATTRIBUTE = 'WildboundGround'

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

local function groundAt(relief, x, z)
    return relief and relief:heightAt(x, z) or FLOOR_Y
end

-- Sizes and places a trunk core about its pivot: its top CORE_HEIGHT above the ground at the pivot, its bottom one
-- stud below the lowest ground under its rim (eight points), so no gap opens under it on a slope or a crest edge.
local function frameCore(core, radius, pivot, relief)
    local ground = groundAt(relief, pivot.X, pivot.Z)
    local sink = 0
    if relief then
        local lowest = ground
        for k = 0, 7 do
            local angle = k * math.pi / 4
            lowest = math.min(lowest, relief:heightAt(pivot.X + radius * math.cos(angle), pivot.Z + radius * math.sin(angle)))
        end
        sink = 1 + ground - lowest
    end
    local height = CORE_HEIGHT + sink
    core.Size = Vector3.new(height, radius * 2, radius * 2)
    core.CFrame = CFrame.new(pivot.X, ground + CORE_HEIGHT - height / 2, pivot.Z) * CFrame.Angles(0, 0, math.pi / 2)
end

-- Adds the core to one placed tree model, standing on the ground at its pivot. Returns the core.
local function addCore(model, prop, scale, relief)
    local radius = CORE_RADIUS[prop] * scale
    local pivot = model:GetPivot().Position
    local core = Instance.new('Part')
    core.Name = CORE_NAME
    core.Shape = Enum.PartType.Cylinder
    frameCore(core, radius, pivot, relief)
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

-- Patches an already dressed ForestKit folder: every tree not yet grown scales once about its pivot on the floor,
-- its trunk core included (radius and height times the growth). Returns how many it grew.
function Dress.growTrees(kit)
    local grown = 0
    for _, model in kit:GetChildren() do
        local prop = model:IsA('Model') and propOf(model.Name) or nil
        local factor = prop and Dress.TREE_GROWTH[prop]
        if factor and model:GetAttribute(GROWTH_ATTRIBUTE) == nil then
            model:ScaleTo(model:GetScale() * factor)
            model:SetAttribute(GROWTH_ATTRIBUTE, factor)
            grown += 1
        end
    end
    return grown
end

local function place(template, item, parent, relief)
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
    local growth = Dress.TREE_GROWTH[item.name]
    model:ScaleTo(item.scale * (growth or 1))
    model:PivotTo(CFrame.new(item.x, groundAt(relief, item.x, item.z), item.z) * CFrame.Angles(0, math.rad(item.rotation_y_deg), 0))
    if CORE_RADIUS[item.name] then
        addCore(model, item.name, item.scale * (growth or 1), relief)
    end
    if growth then model:SetAttribute(GROWTH_ATTRIBUTE, growth) end
    if relief then model:SetAttribute(GROUND_ATTRIBUTE, true) end
    model.Parent = parent
end

local function segmentDistance(x, z, ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    local length = dx * dx + dz * dz
    local t = length > 0 and math.clamp(((x - ax) * dx + (z - az) * dz) / length, 0, 1) or 0
    return math.sqrt((x - (ax + dx * t)) ^ 2 + (z - (az + dz * t)) ^ 2)
end

-- A small deterministic generator, so the same map always gets the same extra trees.
local function roll(seed)
    return ((seed * 1103515245 + 12345) % 2147483648) / 2147483648
end

-- Dread pass: adds up to THICKEN_MAX extra trees to a dressed root, on a fixed jittered grid, keeping the 14-stud
-- route plus a margin, other cores, the floor edge, `options.avoid` circles ({ x, z, r }) and `options.keepClear`
-- segments ({ ax, az, bx, bz }, sight lines) clear. Returns how many it added; a second call adds none.
function Dress.thicken(root, kit, options)
    for _, child in kit:GetChildren() do
        local number = tonumber(string.match(child.Name, '_(%d+)$'))
        if number and number >= THICKEN_FIRST_ID then return 0 end
    end
    local templates, avoid, keepClear = options.templates, options.avoid or {}, options.keepClear or {}
    local relief = options.relief
    local legs = {}
    for _, path in root.Paths:GetChildren() do
        local half = (path.Size.Z - path.Size.X) / 2
        local a, b = path.Position - path.CFrame.LookVector * half, path.Position + path.CFrame.LookVector * half
        table.insert(legs, { a.X, a.Z, b.X, b.Z, path.Size.X / 2 })
    end
    local cores = {}
    for _, part in kit:GetDescendants() do
        if part.Name == CORE_NAME then table.insert(cores, { part.Position.X, part.Position.Z, part.Size.Y / 2 }) end
    end
    local floor = root:FindFirstChild('Floor')
    local half = (floor and math.min(floor.Size.X, floor.Size.Z) / 2 or 170) - 8
    local cx, cz = floor and floor.Position.X or 0, floor and floor.Position.Z or 0
    local added, seed = 0, 0
    for gx = -half, half, THICKEN_STEP do
        for gz = -half, half, THICKEN_STEP do
            if added >= Dress.THICKEN_MAX then break end
            seed += 1
            local x = cx + gx + (roll(seed * 3) - 0.5) * THICKEN_STEP * 0.6
            local z = cz + gz + (roll(seed * 3 + 1) - 0.5) * THICKEN_STEP * 0.6
            local prop = roll(seed * 3 + 2) < 0.7 and 'FK_Evergreen' or 'FK_DeadTree'
            local scale = 0.9 + 0.25 * roll(seed * 7)
            local r = CORE_RADIUS[prop] * scale * Dress.TREE_GROWTH[prop]
            local ok = math.abs(x - cx) <= half and math.abs(z - cz) <= half
            for _, leg in ipairs(legs) do
                if not ok then break end
                ok = segmentDistance(x, z, leg[1], leg[2], leg[3], leg[4]) - r >= leg[5] + THICKEN_ROUTE_MARGIN
            end
            for _, core in ipairs(cores) do
                if not ok then break end
                ok = math.sqrt((core[1] - x) ^ 2 + (core[2] - z) ^ 2) - r - core[3] >= THICKEN_SPACING
            end
            for _, circle in ipairs(avoid) do
                if not ok then break end
                ok = math.sqrt((circle.x - x) ^ 2 + (circle.z - z) ^ 2) - r >= circle.r
            end
            for _, segment in ipairs(keepClear) do
                if not ok then break end
                ok = segmentDistance(x, z, segment.ax, segment.az, segment.bx, segment.bz) - r >= 2
            end
            if ok and relief then ok = relief:slopeAt(x, z) <= Dress.TREE_MAX_SLOPE end
            if ok then
                local item = { id = prop .. '_' .. (THICKEN_FIRST_ID + added), name = prop, x = x, z = z,
                    rotation_y_deg = math.floor(roll(seed * 11) * 360), scale = scale }
                place(templates:FindFirstChild(prop), item, kit, relief)
                table.insert(cores, { x, z, r })
                added += 1
                if added % YIELD_EVERY == 0 then task.wait() end
            end
        end
    end
    return added
end

-- Expedition relief (R4): patches an already dressed, flat ForestKit folder (the live map) onto the relief once. Trees
-- listed in `removed` (a set of ids) and extra trees left on ground steeper than TREE_MAX_SLOPE are destroyed; every
-- other prop moves up to the ground at its pivot and each trunk core is refitted. Returns how many props it settled
-- and how many it removed; a second call returns 0, 0.
function Dress.settleOnRelief(kit, relief, removed)
    assert(typeof(kit) == 'Instance', 'kit must be an Instance')
    assert(type(relief) == 'table' and relief.heightAt and relief.slopeAt, 'relief needs heightAt and slopeAt')
    removed = removed or {}
    local settled, gone = 0, 0
    for _, model in kit:GetChildren() do
        local prop = model:IsA('Model') and propOf(model.Name) or nil
        if prop and PROPS[prop] then
            local pivot = model:GetPivot()
            local fresh = model:GetAttribute(GROUND_ATTRIBUTE) == nil
            local steep = CORE_RADIUS[prop] ~= nil and relief:slopeAt(pivot.X, pivot.Z) > Dress.TREE_MAX_SLOPE
            if removed[model.Name] or (fresh and steep) then
                model:Destroy()
                gone += 1
            elseif fresh then
                local ground = relief:heightAt(pivot.X, pivot.Z)
                model:PivotTo(pivot + Vector3.new(0, ground - pivot.Y, 0))
                local core = model:FindFirstChild(CORE_NAME)
                if core then frameCore(core, core.Size.Y / 2, model:GetPivot().Position, relief) end
                model:SetAttribute(GROUND_ATTRIBUTE, true)
                settled += 1
                if settled % YIELD_EVERY == 0 then task.wait() end
            end
        end
    end
    return settled, gone
end

-- instances: { { id, name, x, z, rotation_y_deg, scale }, ... } from the layout plan. options (optional):
-- { relief = WildboundRelief object, removed = { [id] = true } } puts props on the relief and skips removed trees.
-- Returns the new Decorations.ForestKit folder.
function Dress.dress(root, templates, instances, options)
    local decorations = validate(root, templates, instances)
    local relief = options and options.relief
    local removed = options and options.removed or {}

    local kit = Instance.new('Folder')
    kit.Name = 'ForestKit'
    local ok, failure = pcall(function()
        for index, item in ipairs(instances) do
            if not removed[item.id] then place(templates:FindFirstChild(item.name), item, kit, relief) end
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
