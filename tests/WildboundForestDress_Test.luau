-- Standalone Studio test for the forest dressing step. Call it with fresh clones of the builder
-- module, the dress module and the layout module, plus the kit templates folder
-- (ServerStorage.WildboundAssets.ForestKit). It builds into a detached Folder; only the line-of-sight
-- checks park a copy in a uniquely named Workspace folder 5000 studs from the map, and remove it.
return function(builder, forest, templates, layout)
    local HttpService = game:GetService('HttpService')
    local failures, notes = {}, {}
    local passed = 0
    local function check(name, callback)
        local ok, err = pcall(callback)
        if ok then
            passed += 1
        else
            table.insert(failures, name .. ': ' .. tostring(err))
        end
    end
    local function expect(condition, message)
        assert(condition, message)
    end
    local function note(text)
        table.insert(notes, text)
    end

    local QUERY_PARTS = { FK_Evergreen_Trunk = true, FK_DeadTree_Wood = true }
    -- Delivery C, D-C1: each tree carries one invisible solid core, so players and La Silueta's paths go around
    -- trunks. It also answers sight rays, like the trunk it sits in.
    local CORE = 'FK_TrunkCore'
    local CORE_RADIUS = { FK_Evergreen = 2.5, FK_DeadTree = 3.4 }
    local TREES = { FK_Evergreen = true, FK_DeadTree = true }
    local NODE_ORDER = { 'camp', 'clearing', 'ruin', 'nest', 'marsh', 'shelter' }
    local FLOOR_Y = 0.5
    local EYE_Y = layout.nest_cover.eye_height -- guardian body height, as in WildboundWorld
    local TARGET_Y = 3.5 -- standing HumanoidRootPart: floor top plus 3
    local HALF_ROUTE = layout.inputs.route_width / 2
    local OFFSET = Vector3.new(5000, 0, 0)
    local TOLERANCE = 0.01

    local function propOf(id)
        return (string.match(id, '^(.+)_%d+$'))
    end

    local function countByName(parent)
        local counts = {}
        for _, child in parent:GetChildren() do
            counts[child.Name] = (counts[child.Name] or 0) + 1
        end
        return counts
    end

    local function segmentDistance(x, z, leg)
        local dx, dz = leg.b.X - leg.a.X, leg.b.Z - leg.a.Z
        local t = math.clamp(((x - leg.a.X) * dx + (z - leg.a.Z) * dz) / (dx * dx + dz * dz), 0, 1)
        return math.sqrt((x - (leg.a.X + dx * t)) ^ 2 + (z - (leg.a.Z + dz * t)) ^ 2)
    end

    -- The builder owns the route: recover each leg's centerline from its Path part (length + width).
    local function routeLegs(map)
        local legs = {}
        for _, path in map.Paths:GetChildren() do
            local index = tonumber(string.match(path.Name, '^Path(%d+)$'))
            local half = (path.Size.Z - path.Size.X) / 2
            legs[index] = { a = path.Position - path.CFrame.LookVector * half, b = path.Position + path.CFrame.LookVector * half }
        end
        return legs
    end

    -- Vertical span below/above the pivot and the widest horizontal reach from it, from part boxes.
    local function extents(model)
        local pivot = model:GetPivot().Position
        local lowest, highest, reach = math.huge, -math.huge, 0
        for _, part in model:GetDescendants() do
            if part:IsA('BasePart') then
                local half = part.Size / 2
                for _, sx in { -1, 1 } do
                    for _, sy in { -1, 1 } do
                        for _, sz in { -1, 1 } do
                            local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
                            lowest, highest = math.min(lowest, corner.Y), math.max(highest, corner.Y)
                            reach = math.max(reach, math.sqrt((corner.X - pivot.X) ^ 2 + (corner.Z - pivot.Z) ^ 2))
                        end
                    end
                end
            end
        end
        return lowest - pivot.Y, highest - pivot.Y, reach
    end

    local container = Instance.new('Folder') -- detached: never mutates Workspace
    local root, decorations, kit, kept, treeCount
    check('build detached root', function()
        root = builder.build(container)
        decorations = root:FindFirstChild('Decorations')
        expect(decorations, 'Decorations folder missing')
        kept, treeCount = {}, 0
        for _, child in decorations:GetChildren() do
            if child.Name == 'TreeTrunk' or child.Name == 'TreeCrown' then
                treeCount += 1
            else
                kept[child] = child.CFrame
            end
        end
        expect(treeCount > 0, 'the greybox must start with placeholder trees')
    end)

    check('dress yields and completes', function()
        expect(root ~= nil, 'root missing')
        local finished, failure = false, nil
        task.spawn(function()
            local ok, value = pcall(forest.dress, root, templates, layout)
            if not ok then
                failure = value
            end
            finished = true
        end)
        expect(not finished, 'dress must yield periodically instead of running in one frame')
        local deadline = os.clock() + 90
        while not finished and os.clock() < deadline do
            task.wait()
        end
        expect(finished, 'dress did not finish within 90 seconds')
        expect(failure == nil, 'dress failed: ' .. tostring(failure))
        kit = decorations:FindFirstChild('ForestKit')
    end)

    check('placeholder trees replaced, other decorations untouched', function()
        expect(kit and kit:IsA('Folder'), 'Decorations.ForestKit folder missing')
        local counts = countByName(decorations)
        expect(counts.TreeTrunk == nil and counts.TreeCrown == nil, 'TreeTrunk and TreeCrown must be removed')
        expect(counts.RuinPillar == 4, 'four RuinPillar must remain')
        expect(counts.NestStone == 8, 'eight NestStone must remain')
        expect(counts.ForestKit == 1, 'exactly one ForestKit folder')
        local remaining = 0
        for child, frame in kept do
            remaining += 1
            expect(child.Parent == decorations, child.Name .. ' must stay in Decorations')
            expect(child.CFrame == frame, child.Name .. ' must not move')
        end
        expect(#decorations:GetChildren() == remaining + 1, 'Decorations must hold only the kept parts and ForestKit')
        for _, name in { 'Paths', 'Markers', 'Decorations', 'Floor' } do
            expect(root:FindFirstChild(name), name .. ' must remain under the root')
        end
        for _, pillar in decorations:GetChildren() do
            if pillar.Name == 'RuinPillar' then
                expect(pillar.CanQuery, 'RuinPillar must keep blocking sight')
            end
        end
    end)

    check('one model per layout instance, counts per prop', function()
        expect(kit, 'ForestKit missing')
        expect(#layout == layout.totals.instances, 'layout length must match its totals')
        local children = kit:GetChildren()
        expect(#children == layout.totals.instances, string.format('expected %d models, found %d', layout.totals.instances, #children))
        local seen, counts = {}, {}
        for _, child in children do
            expect(child:IsA('Model'), child.Name .. ' must be a Model')
            expect(not seen[child.Name], 'duplicate id ' .. child.Name)
            seen[child.Name] = true
            local prop = propOf(child.Name)
            counts[prop] = (counts[prop] or 0) + 1
        end
        for _, item in ipairs(layout) do
            expect(seen[item.id], item.id .. ' missing')
        end
        for prop, info in layout.totals.by_name do
            expect(counts[prop] == info.count, string.format('%s: expected %d, found %s', prop, info.count, tostring(counts[prop])))
        end
    end)

    check('no PackageLink under ForestKit', function()
        expect(kit, 'ForestKit missing')
        for _, descendant in kit:GetDescendants() do
            expect(not descendant:IsA('PackageLink'), 'PackageLink left on ' .. descendant.Parent.Name)
        end
    end)

    check('pivot, yaw, scale and ground contact match the layout', function()
        expect(kit, 'ForestKit missing')
        local reference = {}
        for _, name in { 'FK_Evergreen', 'FK_DeadTree', 'FK_FallenLog', 'FK_RootArch', 'FK_RuinDoorway', 'FK_LanternMarker' } do
            local template = templates:FindFirstChild(name)
            expect(template, 'template ' .. name .. ' missing')
            expect(template:GetPivot().Position.Magnitude < 0.001, name .. ' template pivot must sit at the kit origin')
            local lowest, highest, reach = extents(template)
            reference[name] = { height = highest - lowest, reach = reach }
        end
        for _, item in ipairs(layout) do
            local model = kit:FindFirstChild(item.id)
            expect(model, item.id .. ' missing')
            local pivot = model:GetPivot()
            local expected = CFrame.new(item.x, FLOOR_Y, item.z) * CFrame.Angles(0, math.rad(item.rotation_y_deg), 0)
            expect((pivot.Position - expected.Position).Magnitude < TOLERANCE, item.id .. ' pivot position differs from the layout')
            expect((pivot.XVector - expected.XVector).Magnitude < 0.001 and (pivot.ZVector - expected.ZVector).Magnitude < 0.001,
                item.id .. ' yaw differs from rotation_y_deg')
            local lowest, highest, reach = extents(model)
            local wanted = reference[item.name]
            expect(math.abs((highest - lowest) / wanted.height - item.scale) < 0.005,
                string.format('%s height ratio %.4f differs from scale %.3f', item.id, (highest - lowest) / wanted.height, item.scale))
            expect(math.abs(reach / wanted.reach - item.scale) < 0.005, item.id .. ' horizontal reach does not follow scale')
            expect(math.abs(lowest) < 0.05, string.format('%s floats or sinks by %.3f studs', item.id, lowest))
        end
    end)

    check('every part anchored, non-colliding, non-touching; CanQuery only on trunks', function()
        expect(kit, 'ForestKit missing')
        local queryParts = 0
        for _, part in kit:GetDescendants() do
            if part:IsA('BasePart') and part.Name ~= CORE then
                expect(part.Anchored, part:GetFullName() .. ' must be anchored')
                expect(not part.CanCollide, part.Name .. ' must not collide')
                expect(not part.CanTouch, part.Name .. ' must not fire Touched')
                local wantsQuery = QUERY_PARTS[part.Name] == true
                expect(part.CanQuery == wantsQuery, string.format('%s CanQuery must be %s', part.Name, tostring(wantsQuery)))
                if wantsQuery then
                    queryParts += 1
                end
            end
        end
        local trees = 0
        for prop in TREES do
            trees += layout.totals.by_name[prop].count
        end
        expect(queryParts == trees, string.format('expected %d query trunks, found %d', trees, queryParts))
    end)

    check('every tree has one invisible solid trunk core sized from the layout, nothing else collides', function()
        expect(kit, 'ForestKit missing')
        expect(type(forest.CORE_RADIUS) == 'table', 'the dress module must expose CORE_RADIUS')
        for prop, radius in CORE_RADIUS do
            expect(forest.CORE_RADIUS[prop] == radius, prop .. ' core radius differs')
            expect(layout.inputs.props[prop].core_r == radius, prop .. ' core radius differs from the layout plan')
        end
        local cores = 0
        for _, item in ipairs(layout) do
            local model = kit[item.id]
            local found = {}
            for _, part in model:GetDescendants() do
                if part.Name == CORE then table.insert(found, part) end
            end
            if TREES[item.name] then
                expect(#found == 1, item.id .. ' needs exactly one ' .. CORE .. ', found ' .. #found)
                local core = found[1]
                cores += 1
                expect(core:IsA('Part') and core.Shape == Enum.PartType.Cylinder, item.id .. ' core must be a cylinder Part')
                expect(core.Anchored and core.CanCollide and core.CanQuery and not core.CanTouch, item.id .. ' core flags')
                expect(core.Transparency == 1 and core.CastShadow == false, item.id .. ' core must be invisible')
                local pivot = model:GetPivot().Position
                local radius = CORE_RADIUS[item.name] * item.scale
                expect(math.abs(core.Size.Y / 2 - radius) < TOLERANCE and math.abs(core.Size.Z / 2 - radius) < TOLERANCE,
                    string.format('%s core radius %.3f, wanted %.3f', item.id, core.Size.Y / 2, radius))
                expect(math.abs(core.Position.X - pivot.X) < TOLERANCE and math.abs(core.Position.Z - pivot.Z) < TOLERANCE,
                    item.id .. ' core must stand on the trunk axis')
                expect(core.CFrame.XVector:Dot(Vector3.yAxis) > 0.999, item.id .. ' core axis must be vertical')
                local bottom, top = core.Position.Y - core.Size.X / 2, core.Position.Y + core.Size.X / 2
                expect(math.abs(bottom - FLOOR_Y) < TOLERANCE and top - FLOOR_Y >= 12, item.id .. ' core must stand 12+ studs on the floor')
            else
                expect(#found == 0, item.id .. ' must not have a trunk core')
            end
            for _, part in model:GetDescendants() do
                if part:IsA('BasePart') and part.CanCollide then
                    expect(part.Name == CORE, part:GetFullName() .. ' collides but is not a trunk core')
                end
            end
        end
        local trees = layout.totals.by_name.FK_Evergreen.count + layout.totals.by_name.FK_DeadTree.count
        expect(cores == trees, string.format('expected %d cores, found %d', trees, cores))
    end)

    check('trunk cores keep the 14-stud route clear', function()
        expect(kit, 'ForestKit missing')
        local legs = routeLegs(root)
        local closest = math.huge
        for _, item in ipairs(layout) do
            if TREES[item.name] then
                local core = kit[item.id]:FindFirstChild(CORE, true)
                for index, leg in ipairs(legs) do
                    local edge = segmentDistance(core.Position.X, core.Position.Z, leg) - core.Size.Y / 2
                    closest = math.min(closest, edge)
                    expect(edge >= HALF_ROUTE, string.format('%s core reaches %.2f studs from route leg %d', item.id, edge, index))
                end
            end
        end
        note(string.format('closest trunk core edge to a route centerline: %.2f studs', closest))
    end)

    check('addTrunkCores patches an already dressed kit once and only trees', function()
        expect(kit, 'ForestKit missing')
        local copy = kit:Clone()
        local removed = 0
        for _, part in copy:GetDescendants() do
            if part.Name == CORE then part:Destroy(); removed += 1 end
        end
        expect(removed > 0, 'the copy must lose its cores first')
        expect(forest.addTrunkCores(copy) == removed, 'addTrunkCores must add one core per tree')
        expect(forest.addTrunkCores(copy) == 0, 'a second patch must add nothing')
        for _, item in ipairs(layout) do
            local original, patched = kit[item.id]:FindFirstChild(CORE, true), copy[item.id]:FindFirstChild(CORE, true)
            expect((original == nil) == (patched == nil), item.id .. ' core presence differs after the patch')
            if original then
                expect((original.Position - patched.Position).Magnitude < TOLERANCE
                    and (original.Size - patched.Size).Magnitude < TOLERANCE, item.id .. ' patched core differs')
            end
        end
        copy:Destroy()
    end)

    -- Dread pass (user: fewer lights, the flashlight is what helps): every lantern keeps its light, but only the
    -- few landmark lanterns (near camp and at two forks) are lit. The others are disabled, not deleted, and their
    -- glass no longer glows.
    check('each lantern glass carries one short-range PointLight without shadows; only the landmark lanterns are lit', function()
        expect(kit, 'ForestKit missing')
        local lights, enabled = 0, {}
        for _, descendant in kit:GetDescendants() do
            if descendant:IsA('Light') then
                lights += 1
                expect(descendant:IsA('PointLight'), descendant:GetFullName() .. ' must be a PointLight')
                expect(descendant.Parent.Name == 'FK_LanternMarker_Glass', 'light on ' .. descendant.Parent.Name .. ' instead of a lantern glass')
                expect(descendant.Shadows == false, descendant:GetFullName() .. ' must not cast shadows')
                expect(descendant.Range >= 12 and descendant.Range <= 24, string.format('light range %.1f must stay between 12 and 24', descendant.Range))
                expect(descendant.Brightness > 0 and descendant.Brightness <= 3, string.format('light brightness %.2f out of range', descendant.Brightness))
                local model = descendant:FindFirstAncestorWhichIsA('Model')
                while model and model.Parent ~= kit do model = model.Parent end
                local landmark = forest.LIT_LANTERNS[model.Name] == true
                expect(descendant.Enabled == landmark, model.Name .. (landmark and ' must stay lit' or ' must be dark'))
                expect((descendant.Parent.Material == Enum.Material.Neon) == landmark, model.Name .. ' glass glow must match its light')
                if descendant.Enabled then table.insert(enabled, model.Name) end
            end
        end
        local lanterns = layout.totals.by_name.FK_LanternMarker.count
        expect(lights == lanterns, string.format('expected %d lantern lights, found %d', lanterns, lights))
        local landmarks = 0
        for _ in pairs(forest.LIT_LANTERNS) do landmarks += 1 end
        expect(landmarks == 3 and #enabled == 3, string.format('expected 3 lit landmark lanterns, found %d', #enabled))
    end)

    check('dimLanterns patches an already dressed kit once and never deletes a lantern', function()
        expect(kit, 'ForestKit missing')
        local copy = kit:Clone()
        local before = 0
        for _, light in copy:GetDescendants() do
            if light:IsA('PointLight') then
                light.Enabled, light.Parent.Material = true, Enum.Material.Neon
                before += 1
            end
        end
        expect(forest.dimLanterns(copy) == before - 3, 'dimLanterns must darken every lantern but the landmarks')
        expect(forest.dimLanterns(copy) == 0, 'a second patch must change nothing')
        local after = 0
        for _, light in copy:GetDescendants() do
            if light:IsA('PointLight') then after += 1 end
        end
        expect(after == before, 'no lantern light may be deleted')
        copy:Destroy()
        for _, child in kit:GetChildren() do
            if propOf(child.Name) == 'FK_LanternMarker' then
                local own = 0
                for _, descendant in child:GetDescendants() do
                    if descendant:IsA('Light') then
                        own += 1
                    end
                end
                expect(own == 1, child.Name .. ' must hold exactly one light, found ' .. own)
            end
        end
    end)

    check('query trunks follow the real shape, not their bounding box', function()
        expect(kit, 'ForestKit missing')
        for _, part in kit:GetDescendants() do
            if part:IsA('MeshPart') and QUERY_PARTS[part.Name] then
                expect(part.CollisionFidelity ~= Enum.CollisionFidelity.Box, part.Name .. ' must not use Box fidelity')
            end
        end
    end)

    check('pivots stay inside the 400 by 400 map', function()
        expect(kit, 'ForestKit missing')
        local half = layout.inputs.map_size[1] / 2
        for _, model in kit:GetChildren() do
            local position = model:GetPivot().Position
            expect(math.abs(position.X) <= half and math.abs(position.Z) <= layout.inputs.map_size[2] / 2, model.Name .. ' pivot is off the map')
        end
    end)

    check('built route follows the layout nodes', function()
        local legs = routeLegs(root)
        expect(#legs == #NODE_ORDER, 'expected one leg per route node')
        for index, leg in ipairs(legs) do
            local from = layout.inputs.route_nodes[NODE_ORDER[index]]
            local to = layout.inputs.route_nodes[NODE_ORDER[index % #NODE_ORDER + 1]]
            expect(math.abs(leg.a.X - from[1]) < TOLERANCE and math.abs(leg.a.Z - from[2]) < TOLERANCE, 'leg ' .. index .. ' starts away from its node')
            expect(math.abs(leg.b.X - to[1]) < TOLERANCE and math.abs(leg.b.Z - to[2]) < TOLERANCE, 'leg ' .. index .. ' ends away from its node')
        end
    end)

    check('props keep their pivot half a route clear of every centerline', function()
        expect(kit, 'ForestKit missing')
        local legs = routeLegs(root)
        for _, item in ipairs(layout) do
            if item.name ~= 'FK_RootArch' and item.name ~= 'FK_RuinDoorway' then
                local position = kit[item.id]:GetPivot().Position
                for index, leg in ipairs(legs) do
                    local distance = segmentDistance(position.X, position.Z, leg)
                    expect(distance >= HALF_ROUTE, string.format('%s is %.2f studs from route leg %d', item.id, distance, index))
                end
            end
        end
    end)

    check('arch and doorway frame the route through their gap', function()
        expect(kit, 'ForestKit missing')
        local legs = routeLegs(root)
        local framed = 0
        for _, item in ipairs(layout) do
            if item.name == 'FK_RootArch' or item.name == 'FK_RuinDoorway' then
                framed += 1
                local pivot = kit[item.id]:GetPivot()
                local nearest, nearestDistance
                for _, leg in ipairs(legs) do
                    local distance = segmentDistance(pivot.X, pivot.Z, leg)
                    if not nearestDistance or distance < nearestDistance then
                        nearest, nearestDistance = leg, distance
                    end
                end
                local a = pivot:PointToObjectSpace(Vector3.new(nearest.a.X, pivot.Y, nearest.a.Z))
                local b = pivot:PointToObjectSpace(Vector3.new(nearest.b.X, pivot.Y, nearest.b.Z))
                expect(a.Z * b.Z < 0, item.id .. ': the nearest leg must cross the span line')
                local crossing = a.X + (b.X - a.X) * (a.Z / (a.Z - b.Z))
                local direction = (b - a).Unit
                local gap = layout.inputs.props[item.name].gap
                local halfGap = (gap[2] - gap[1]) / 2
                expect(math.abs(crossing) <= 1.2, string.format('%s: route crosses %.2f studs off the span centre', item.id, crossing))
                expect(math.abs(direction.Z) >= 0.99, item.id .. ': route direction must run along local Z')
                expect(halfGap >= 8 and halfGap > HALF_ROUTE, string.format('%s: half gap %.2f must exceed the half route', item.id, halfGap))
                local sideways = HALF_ROUTE / math.abs(direction.Z)
                expect(crossing + sideways <= gap[2] and crossing - sideways >= gap[1], item.id .. ': the 14-stud route does not fit the gap')
            end
        end
        expect(framed == 2, 'expected one arch and one doorway')
    end)

    local function treeTotal(map)
        local total = 0
        for _, child in map.Decorations:GetChildren() do
            if child.Name == 'TreeTrunk' or child.Name == 'TreeCrown' then
                total += 1
            end
        end
        return total
    end

    -- A refused (or failed) dress must leave a fresh root exactly as built.
    local function expectRefusal(name, prepare)
        check(name, function()
            local folder = Instance.new('Folder')
            local ok, problem = pcall(function()
                local fresh = builder.build(folder)
                local descendants, trees = #fresh:GetDescendants(), treeTotal(fresh)
                local useTemplates, rows = prepare()
                expect(not pcall(forest.dress, fresh, useTemplates, rows), 'dress must refuse')
                expect(fresh.Decorations:FindFirstChild('ForestKit') == nil, 'no partial ForestKit may remain')
                expect(#fresh:GetDescendants() == descendants, 'the root must be untouched')
                expect(treeTotal(fresh) == trees, 'placeholder trees must survive')
            end)
            folder:Destroy()
            assert(ok, problem)
        end)
    end

    expectRefusal('refuses an unknown prop name', function()
        local unknown = table.clone(layout[1])
        unknown.id, unknown.name = 'FK_Banana_001', 'FK_Banana'
        return templates, { layout[1], layout[2], unknown }
    end)
    expectRefusal('refuses a missing template', function()
        local partial = templates:Clone()
        partial.FK_LanternMarker:Destroy()
        return partial, layout
    end)
    expectRefusal('refuses duplicate ids', function()
        return templates, { layout[1], layout[2], layout[1] }
    end)
    expectRefusal('refuses a non-positive scale', function()
        local flat = table.clone(layout[2])
        flat.scale = 0
        return templates, { layout[1], flat }
    end)
    expectRefusal('refuses an empty layout', function()
        return templates, {}
    end)
    expectRefusal('leaves no partial output when placing fails midway', function()
        local broken = templates:Clone()
        broken.FK_LanternMarker.Archivable = false -- Clone() returns nil for the last props
        return broken, layout
    end)

    check('refuses a root that already has ForestKit', function()
        expect(kit, 'ForestKit missing')
        local descendants = #root:GetDescendants()
        expect(not pcall(forest.dress, root, templates, layout), 'a second dress must be refused')
        expect(decorations:FindFirstChild('ForestKit') == kit, 'the existing ForestKit must remain')
        expect(#root:GetDescendants() == descendants, 'the dressed root must be untouched')
    end)

    -- Real line-of-sight rays need parts that live in Workspace.
    local arena
    local function castWorld(from, to, ignore)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore or {}
        params.IgnoreWater = true
        return workspace:Raycast(from, to - from, params)
    end
    local function describe(hit, from)
        if not hit then
            return 'clear'
        end
        local owner = hit.Instance
        while owner and owner.Parent ~= kit do
            owner = owner.Parent
        end
        return string.format('%s%s @ %.2f', owner and (owner.Name .. '/') or '', hit.Instance.Name, (hit.Position - from).Magnitude)
    end
    local function queryTrunks()
        local list = {}
        for _, part in kit:GetDescendants() do
            if part:IsA('BasePart') and (QUERY_PARTS[part.Name] or part.Name == CORE) then
                table.insert(list, part)
            end
        end
        return list
    end
    local function firstOf(prop)
        for _, item in ipairs(layout) do
            if item.name == prop then
                return kit[item.id]
            end
        end
        error('no ' .. prop .. ' in the layout')
    end

    check('park the dressed root in a temporary Workspace arena', function()
        expect(kit, 'ForestKit missing')
        root:PivotTo(root:GetPivot() + OFFSET) -- unlike TranslateBy, this keeps nested model pivots in step
        arena = Instance.new('Folder')
        arena.Name = 'WildboundForestDressArena_' .. HttpService:GenerateGUID(false)
        arena.Parent = workspace
        root.Parent = arena
        task.wait()
        task.wait()
    end)

    check('rays: guardian sees the nest from patrol E and N, not from S and W', function()
        expect(arena, 'arena missing')
        local nest = layout.nest_cover.nest
        local target = Vector3.new(nest[1], TARGET_Y, nest[2]) + OFFSET
        for name, entry in layout.nest_cover.sight do
            local from = Vector3.new(entry.waypoint[1], EYE_Y, entry.waypoint[2]) + OFFSET
            local hit = castWorld(from, target)
            note(string.format('nest sight %s (%g, %g): %s [plan: %s]', name, entry.waypoint[1], entry.waypoint[2],
                describe(hit, from), entry.blocked and 'blocked' or 'clear'))
            if entry.blocked then
                expect(hit ~= nil, name .. ' should be blocked')
                expect(hit.Instance.Name == 'RuinPillar', name .. ' should be blocked by a RuinPillar, was ' .. describe(hit, from))
            else
                expect(hit == nil, name .. ' should see the nest, but ' .. describe(hit, from))
            end
        end
    end)

    check('rays: trunks block at eye height without over-blocking', function()
        expect(arena, 'arena missing')
        local trees = 0
        for _, item in ipairs(layout) do
            if TREES[item.name] then
                trees += 1
                local model = kit[item.id]
                local center = model:GetPivot().Position
                local into = castWorld(Vector3.new(center.X - 6, EYE_Y, center.Z), Vector3.new(center.X, EYE_Y, center.Z))
                expect(into and into.Instance:IsDescendantOf(model) and (QUERY_PARTS[into.Instance.Name] or into.Instance.Name == CORE),
                    item.id .. ' must block a ray aimed at its trunk, got ' .. describe(into, center))
                local aside = layout.inputs.props[item.name].core_r * item.scale + 2
                local beside = castWorld(Vector3.new(center.X - 8, EYE_Y, center.Z + aside), Vector3.new(center.X + 8, EYE_Y, center.Z + aside))
                expect(beside == nil or not beside.Instance:IsDescendantOf(model),
                    string.format('%s blocks a ray %.1f studs off its axis: %s', item.id, aside, describe(beside, center)))
            end
        end
        expect(trees == layout.totals.by_name.FK_Evergreen.count + layout.totals.by_name.FK_DeadTree.count, 'every tree trunk must be checked')
        note(string.format('trunk rays: %d trees blocked through the trunk and clear 2 studs outside the core', trees))
    end)

    -- A ray that must pass: free with the shipped flags, and it really crosses the part (CanQuery on = hit).
    local function expectFree(model, partName, localFrom, localTo, label)
        local part = model:FindFirstChild(partName, true)
        expect(part and part:IsA('BasePart'), partName .. ' missing from ' .. model.Name)
        local pivot = model:GetPivot()
        local from, to = pivot:PointToWorldSpace(localFrom), pivot:PointToWorldSpace(localTo)
        local ignore = queryTrunks()
        local free = castWorld(from, to, ignore)
        expect(free == nil, label .. ' must not block sight, but ' .. describe(free, from))
        part.CanQuery = true
        task.wait()
        local control = castWorld(from, to, ignore)
        part.CanQuery = false
        expect(control and control.Instance == part, label .. ': the control ray must cross ' .. partName .. ', got ' .. describe(control, from))
        note(label .. ': clear; with CanQuery on it hits ' .. describe(control, from))
    end
    local function centerLine(model, partName, axis)
        local center = model:GetPivot():PointToObjectSpace(model:FindFirstChild(partName, true).Position)
        return center - axis * 14, center + axis * 14
    end
    local AXIS_X, AXIS_Z = Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)

    check('rays: canopies, splinters and logs never block', function()
        expect(arena, 'arena missing')
        local evergreen, dead, log = firstOf('FK_Evergreen'), firstOf('FK_DeadTree'), firstOf('FK_FallenLog')
        local from, to = centerLine(evergreen, 'FK_Evergreen_Canopy', AXIS_X)
        expectFree(evergreen, 'FK_Evergreen_Canopy', from, to, 'evergreen canopy height')
        from, to = centerLine(dead, 'FK_DeadTree_Splinter', AXIS_X)
        expectFree(dead, 'FK_DeadTree_Splinter', from, to, 'dead tree splinter')
        from, to = centerLine(log, 'FK_FallenLog_Bark', AXIS_Z)
        expectFree(log, 'FK_FallenLog_Bark', from, to, 'fallen log')
    end)

    check('rays: arch, doorway and lantern never block', function()
        expect(arena, 'arena missing')
        local arch, doorway, lantern = firstOf('FK_RootArch'), firstOf('FK_RuinDoorway'), firstOf('FK_LanternMarker')
        expectFree(arch, 'FK_RootArch_Wood', Vector3.new(12, 5, -14), Vector3.new(12, 5, 14), 'solid arch leg')
        expectFree(doorway, 'FK_RuinDoorway_Stone', Vector3.new(13, 5, -10), Vector3.new(13, 5, 10), 'solid doorway wall')
        local from, to = centerLine(lantern, 'FK_LanternMarker_Wood', AXIS_Z)
        expectFree(lantern, 'FK_LanternMarker_Wood', from, to, 'lantern post')
        for _, gate in { arch, doorway } do
            local pivot = gate:GetPivot()
            local gapFrom, gapTo = pivot:PointToWorldSpace(Vector3.new(0, 3.2, -14)), pivot:PointToWorldSpace(Vector3.new(0, 3.2, 14))
            local hit = castWorld(gapFrom, gapTo, queryTrunks())
            expect(hit == nil, gate.Name .. ' gap must not block, but ' .. describe(hit, gapFrom))
        end
    end)

    if arena then
        arena:Destroy()
    end
    container:Destroy()
    return { passed = passed, failed = #failures, failures = failures, notes = notes }
end
