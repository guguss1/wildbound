-- Standalone Studio test: require this module and call it with the builder module.
return function(builder)
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
    container:Destroy()
    return { passed = passed, failed = #failures, failures = failures }
end

