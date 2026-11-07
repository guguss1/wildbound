-- Standalone Studio test: require this module and call it with the builder module and, for the relief cases (R3),
-- the relief layout module (ServerStorage.WildboundReliefLayout).
return function(builder, reliefLayout)
    local failures = {}
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

    local container = Instance.new('Folder') -- detached: never mutates Workspace
    local sentinel = Instance.new('Part')
    sentinel.Name = 'UnrelatedSentinel'
    sentinel.Parent = container
    local root
    check('build confined root', function()
        root = builder.build(container)
        expect(root ~= nil and root.Parent == container, 'build must return its root under the given parent')
        expect(root.Name == 'WildboundP0', 'root must be named WildboundP0')
        expect(container:FindFirstChild('UnrelatedSentinel') == sentinel, 'unrelated objects must survive')
    end)
    check('duplicate guard', function()
        expect(root ~= nil, 'root missing')
        local ok = pcall(function() builder.build(container) end)
        expect(not ok, 'a second build must reject an existing WildboundP0')
        expect(container:FindFirstChild('WildboundP0') == root, 'existing root must remain intact')
    end)
    check('floor and bounded anchored parts', function()
        expect(root ~= nil, 'root missing')
        local floor = root:FindFirstChild('Floor', true)
        expect(floor and floor:IsA('BasePart'), 'Floor part missing')
        expect(math.abs(floor.Size.X - 400) < 0.01 and math.abs(floor.Size.Z - 400) < 0.01, 'floor must be 400 by 400 studs')
        expect(math.abs(floor.Position.Y + floor.Size.Y / 2 - 0.5) < 0.01, 'floor top must be y=0.5')
        for _, part in root:GetDescendants() do
            if part:IsA('BasePart') then
                expect(part.Anchored, part.Name .. ' must be anchored')
                for _, xSign in ipairs({-1, 1}) do
                    for _, zSign in ipairs({-1, 1}) do
                        local corner = part.CFrame:PointToWorldSpace(Vector3.new(xSign * part.Size.X / 2, 0, zSign * part.Size.Z / 2))
                        expect(math.abs(corner.X) <= 200.01 and math.abs(corner.Z) <= 200.01, part.Name .. ' outside bounds')
                    end
                end
            end
        end
    end)
    check('interaction markers', function()
        expect(root ~= nil, 'root missing')
        local positions = {
            CampCenter = Vector2.new(-140, 140), ExtractionMarker = Vector2.new(-140, 140),
            HatchMarker = Vector2.new(-140, 140), ProtectionMarker = Vector2.new(-140, 140),
            LumipolMarker = Vector2.new(-95, 75), EggMarker = Vector2.new(35, -99),
            GuardianMarker = Vector2.new(0, -85),
        }
        for name, expected in pairs(positions) do
            local marker = root:FindFirstChild(name, true)
            expect(marker and marker:IsA('BasePart'), name .. ' missing')
            expect((Vector2.new(marker.Position.X, marker.Position.Z) - expected).Magnitude <= 25, name .. ' is outside its intended zone')
            expect(not marker.CanCollide, name .. ' must not obstruct traversal')
        end
    end)
    check('nest inside guardian reach', function()
        expect(root ~= nil, 'root missing')
        local egg = root:FindFirstChild('EggMarker', true)
        local guardian = root:FindFirstChild('GuardianMarker', true)
        expect(egg and guardian, 'EggMarker and GuardianMarker required')
        expect((egg.Position - guardian.Position).Magnitude <= 80, 'nest must sit inside the 80-stud guardian leash')
        local stones = 0
        for _, decoration in root:GetDescendants() do
            if decoration.Name == 'NestStone' then
                stones += 1
                expect((decoration.Position - egg.Position).Magnitude <= 12, 'nest stones must ring the egg marker')
            end
        end
        expect(stones >= 8, 'nest ring requires at least eight stones')
    end)
    check('route and decorations', function()
        expect(root ~= nil, 'root missing')
        local paths = root:FindFirstChild('Paths')
        local decorations = root:FindFirstChild('Decorations')
        expect(paths and decorations, 'Paths and Decorations folders required')
        local count = 0
        for _, path in paths:GetChildren() do
            expect(path:IsA('BasePart') and math.abs(path.Size.X - 14) < 0.01, 'each path must be 14 studs wide')
            count += 1
        end
        expect(count >= 6, 'loop requires at least six path segments')
        for _, decoration in decorations:GetDescendants() do
            if decoration:IsA('BasePart') then
                expect(not decoration.CanCollide, 'decorations must not block the route')
            end
        end
    end)
    -- Delivery B (B4): the camp stations. Refuge, chest, board, incubator and display sit in camp, apart from each
    -- other and from the route, never block Silueta's sight or the spawn, and glow warm unlike the forest.
    local function camp()
        local folder = root and root:FindFirstChild('Camp')
        expect(folder and folder:IsA('Folder'), 'Camp folder missing')
        return folder
    end
    local function flat(part)
        return Vector2.new(part.Position.X, part.Position.Z)
    end
    local CAMP_CENTER = Vector2.new(-140, 140)
    local STATIONS = { 'RefugeMarker', 'BoardMarker', 'IncubatorMarker', 'ExtractionMarker', 'HatchMarker', 'ProtectionMarker' }
    check('B4 camp stations sit in camp, at least 8 studs apart', function()
        camp()
        local found = {}
        for _, name in ipairs(STATIONS) do
            local marker = root:FindFirstChild(name, true)
            expect(marker and marker:IsA('BasePart'), name .. ' missing')
            expect(not marker.CanCollide and marker.Transparency == 1, name .. ' must be an invisible marker')
            expect((flat(marker) - CAMP_CENTER).Magnitude <= 20, name .. ' must be within the 20 stud camp range')
            found[name] = marker
        end
        for first = 1, #STATIONS do
            for second = first + 1, #STATIONS do
                local a, b = found[STATIONS[first]], found[STATIONS[second]]
                expect((flat(a) - flat(b)).Magnitude >= 8, STATIONS[first] .. ' and ' .. STATIONS[second] .. ' are too close')
            end
        end
        for index = 1, 4 do
            local spot = root:FindFirstChild('DisplaySpot' .. index, true)
            expect(spot and spot:IsA('BasePart') and spot.Transparency == 1, 'DisplaySpot' .. index .. ' missing')
            expect((flat(spot) - CAMP_CENTER).Magnitude <= 25, 'display spot outside camp')
        end
    end)
    check('B4 new stations stay off the route', function()
        local legs = {}
        for _, path in root.Paths:GetChildren() do
            local half = (path.Size.Z - path.Size.X) / 2
            local a, b = path.Position - path.CFrame.LookVector * half, path.Position + path.CFrame.LookVector * half
            table.insert(legs, { a = Vector2.new(a.X, a.Z), b = Vector2.new(b.X, b.Z) })
        end
        local names = { 'RefugeMarker', 'BoardMarker', 'IncubatorMarker', 'DisplaySpot1', 'DisplaySpot2', 'DisplaySpot3', 'DisplaySpot4' }
        for _, name in ipairs(names) do
            local point = flat(root:FindFirstChild(name, true))
            for _, leg in ipairs(legs) do
                local segment = leg.b - leg.a
                local t = math.clamp((point - leg.a):Dot(segment) / segment:Dot(segment), 0, 1)
                expect((point - (leg.a + segment * t)).Magnitude >= 9, name .. ' sits on the route')
            end
        end
    end)
    check('B4 camp parts never block sight, the spawn or the forest reads', function()
        local spawn = CAMP_CENTER + Vector2.new(0, 10)
        local parts = 0
        for _, part in camp():GetDescendants() do
            if part:IsA('BasePart') then
                parts += 1
                expect(part.Anchored and not part.CanQuery and not part.CanTouch, part.Name .. ' must be anchored, unqueryable, untouchable')
                if part.CanCollide then
                    expect((flat(part) - spawn).Magnitude >= 5, part.Name .. ' blocks the spawn point')
                end
            end
        end
        expect(parts >= 20, 'the camp needs real stations, found ' .. parts .. ' parts')
    end)
    check('B4 the camp glows warm, with a few shadowless lights', function()
        local warm = 0
        for _, light in camp():GetDescendants() do
            if light:IsA('PointLight') then
                expect(not light.Shadows, 'camp lights are shadowless')
                if light.Color.R > light.Color.G and light.Color.G > light.Color.B then warm += 1 end
            end
        end
        expect(warm >= 4 and warm <= 8, 'expected 4 to 8 warm lights, found ' .. warm)
    end)
    check('B4 station signs carry a text key and no baked words', function()
        local keys = {}
        for _, sign in camp():GetDescendants() do
            local key = sign:GetAttribute('SignKey')
            if key then
                keys[key] = true
                local label = sign:FindFirstChild('Label', true)
                expect(label and label:IsA('TextLabel') and label.Text == '', key .. ' sign must start empty; the server fills it')
            end
        end
        for _, key in ipairs({ 'refuge', 'chestObject', 'boardObject', 'incubatorObject', 'incubator', 'display' }) do
            expect(keys[key], 'no sign for ' .. key)
        end
    end)
    check('B4 the camp can be added to an existing map once', function()
        local holder = Instance.new('Folder')
        local bare = Instance.new('Model')
        bare.Name = 'WildboundP0'
        bare.Parent = holder
        local markers = Instance.new('Folder')
        markers.Name = 'Markers'
        markers.Parent = bare
        local made = builder.buildCamp(bare)
        expect(made and made.Parent == bare and made.Name == 'Camp', 'buildCamp returns the Camp folder')
        expect(not pcall(function() builder.buildCamp(bare) end), 'a second camp is refused')
        holder:Destroy()
    end)
    -- Delivery D7: ten hiding spots patched onto a map once (six bushes, four hollow logs).
    local function hideRoot()
        local holder = Instance.new('Folder')
        local bare = Instance.new('Model')
        bare.Name = 'WildboundP0'
        bare.Parent = holder
        return holder, bare, builder.buildHideSpots(bare)
    end
    check('D7: hide spots are tagged, named by id and carry one prompt each', function()
        local holder, _, spots = hideRoot()
        expect(spots and spots.Name == 'HideSpots', 'buildHideSpots returns the HideSpots folder')
        local CollectionService = game:GetService('CollectionService')
        local count, bushes, logs = 0, 0, 0
        for _, spot in ipairs(spots:GetChildren()) do
            count += 1
            expect(spot:IsA('Model') and CollectionService:HasTag(spot, 'WildboundHideSpot'), spot.Name .. ' is not tagged')
            local id = spot:GetAttribute('SpotId')
            expect(spot.Name == 'HideSpot_' .. tostring(id), spot.Name .. ' name does not carry its id')
            local zone = spot:FindFirstChild('HideZone')
            expect(zone and zone:IsA('BasePart'), spot.Name .. ' has no HideZone')
            local prompts = 0
            for _, child in ipairs(zone:GetChildren()) do if child:IsA('ProximityPrompt') then prompts += 1 end end
            expect(prompts == 1, spot.Name .. ' needs exactly one prompt')
            local kind = spot:GetAttribute('Kind')
            if kind == 'bush' then bushes += 1 elseif kind == 'log' then logs += 1 end
            expect((kind == 'log') == (spot:FindFirstChild('Hollow') ~= nil), spot.Name .. ' Hollow must mark logs only')
        end
        expect(count == 10 and bushes == 6 and logs == 4, ('expected 10 spots (6 bushes, 4 logs), got %d (%d, %d)'):format(count, bushes, logs))
        holder:Destroy()
    end)
    check('D7: zones do not collide or query, bush geometry queries, nothing touches', function()
        local holder, _, spots = hideRoot()
        for _, spot in ipairs(spots:GetChildren()) do
            local zone = spot.HideZone
            expect(zone.Transparency == 1 and not zone.CanCollide and not zone.CanQuery and not zone.CanTouch, spot.Name .. ' zone')
            expect(zone.Anchored, spot.Name .. ' zone must be anchored')
            for _, item in ipairs(spot:GetDescendants()) do
                if item:IsA('BasePart') and item ~= zone then
                    expect(item.Anchored and not item.CanCollide and not item.CanTouch, item:GetFullName() .. ' must be anchored, non-colliding')
                    if spot:GetAttribute('Kind') == 'bush' then expect(item.CanQuery, item:GetFullName() .. ' bush must block sight') end
                end
            end
        end
        holder:Destroy()
    end)
    check('D7: a second build is refused and the planned positions are kept', function()
        local holder, bare, spots = hideRoot()
        expect(not pcall(function() builder.buildHideSpots(bare) end), 'a second set of hide spots is refused')
        local h01 = spots:FindFirstChild('HideSpot_H01')
        expect(h01 and math.abs(h01.HideZone.Position.X - 34) < 0.01 and math.abs(h01.HideZone.Position.Z + 77) < 0.01, 'H01 at (34, -77)')
        holder:Destroy()
    end)
    -- Expedition relief (R3): ridge segments of parts, patched onto a map once.
    local function reliefRoot()
        local holder = Instance.new('Folder')
        local bare = Instance.new('Model')
        bare.Name = 'WildboundP0'
        bare.Parent = holder
        return holder, bare, builder.buildRelief(bare, reliefLayout)
    end
    local function reliefParts(relief)
        local parts = {}
        for _, item in ipairs(relief:GetDescendants()) do
            if item:IsA('BasePart') then table.insert(parts, item) end
        end
        return parts
    end
    check('R3: relief parts are anchored, collide and query, never touch', function()
        expect(type(reliefLayout) == 'table', 'relief layout missing')
        local holder, _, relief = reliefRoot()
        expect(relief and relief.Name == 'Relief', 'buildRelief returns the Relief folder')
        local parts = reliefParts(relief)
        expect(#parts > 0, 'relief has parts')
        for _, item in ipairs(parts) do
            expect(item.Anchored and item.CanCollide and item.CanQuery and not item.CanTouch, item:GetFullName())
            expect(item.Material == Enum.Material.Grass, item:GetFullName() .. ' must be grass')
        end
        holder:Destroy()
    end)
    check('R3: part count within 250', function()
        local holder, _, relief = reliefRoot()
        local count = #reliefParts(relief)
        expect(count == #reliefLayout.segments * 9, ('9 parts per segment, got %d for %d'):format(count, #reliefLayout.segments))
        expect(count <= 250, 'over the 250-part budget: ' .. count)
        holder:Destroy()
    end)
    check('R3: a downward ray hits each crest at heightAt within 0.1 (parked folder)', function()
        local holder, _, relief = reliefRoot()
        local arena = Instance.new('Folder')
        arena.Name = 'WildboundReliefProbe_' .. game:GetService('HttpService'):GenerateGUID(false)
        local offset = Vector3.new(5000, 0, 5000)
        for _, ridge in ipairs(relief:GetChildren()) do ridge:PivotTo(ridge:GetPivot() + offset) end
        relief.Parent = arena
        arena.Parent = workspace
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { arena }
        local ok, err = pcall(function()
            for index, sample in ipairs(reliefLayout.samples) do
                local hit = workspace:Raycast(Vector3.new(sample.x, 40, sample.z) + offset, Vector3.new(0, -60, 0), params)
                local y = hit and hit.Position.Y or 0.5
                expect(math.abs(y - sample.y) <= 0.1, ('sample %d at %.2f, %.2f: ray %.3f, heightAt %.3f'):format(index, sample.x, sample.z, y, sample.y))
            end
        end)
        arena:Destroy()
        holder:Destroy()
        expect(ok, tostring(err))
    end)
    check('R3: a second relief build is refused', function()
        local holder, bare, relief = reliefRoot()
        expect(not pcall(function() builder.buildRelief(bare, reliefLayout) end), 'a second relief is refused')
        expect(bare:FindFirstChild('Relief') == relief and #bare:GetChildren() == 1, 'the first relief stays intact')
        local empty = Instance.new('Model')
        expect(not pcall(function() builder.buildRelief(empty, nil) end), 'a missing layout is refused')
        expect(empty:FindFirstChild('Relief') == nil, 'a refused build leaves nothing behind')
        empty:Destroy()
        holder:Destroy()
    end)
    check('R3: camp stations still clear of every relief part', function()
        local holder, _, relief = reliefRoot()
        for _, item in ipairs(reliefParts(relief)) do
            -- The part's footprint edges, sampled: every point stays outside both safe circles plus 3 studs.
            for i = 0, 8 do
                for _, edge in ipairs({ { i / 8 - 0.5, -0.5 }, { i / 8 - 0.5, 0.5 }, { -0.5, i / 8 - 0.5 }, { 0.5, i / 8 - 0.5 } }) do
                    local point = item.CFrame:PointToWorldSpace(Vector3.new(edge[1] * item.Size.X, 0, edge[2] * item.Size.Z))
                    for _, circle in ipairs({ { -140, 140, 35 }, { 105, 125, 22 } }) do
                        local gap = Vector2.new(point.X - circle[1], point.Z - circle[2]).Magnitude
                        expect(gap >= circle[3] + 3, item:GetFullName() .. ' inside a safe circle plus 3')
                    end
                end
            end
        end
        holder:Destroy()
    end)
    container:Destroy()
    return { passed = passed, failed = #failures, failures = failures }
end
