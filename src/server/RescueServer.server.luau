-- Server authority for the session-only rescue loop.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RescueState = require(script.Parent:WaitForChild("RescueState"))

local positions = {
    Vector3.new(-35, 2, -20), Vector3.new(-62, 2, 8), Vector3.new(-92, 2, 40),
    Vector3.new(-113, 2, 80), Vector3.new(-105, 2, 120), Vector3.new(-65, 2, 95),
    Vector3.new(-20, 2, 58), Vector3.new(20, 2, 15),
}
local root = Instance.new("Folder")
root.Name = "RescueGameplay"
root.Parent = workspace
local creatures = Instance.new("Folder")
creatures.Name = "Creatures"
creatures.Parent = root
local states, inventories, lastInteraction = {}, {}, {}

local function marker(name, position, color)
    local part = Instance.new("Part")
    part.Name, part.Size, part.Position = name, Vector3.new(2, 2, 2), position
    part.Shape, part.Material, part.Color = Enum.PartType.Ball, Enum.Material.Neon, color
    part.Anchored, part.CanCollide, part.Transparency = true, false, 0.35
    return part
end
local function prompt(parent, action, object, distance)
    local result = Instance.new("ProximityPrompt")
    result.ActionText, result.ObjectText = action, object
    result.KeyboardKeyCode = Enum.KeyCode.E
    result.MaxActivationDistance = distance
    result.RequiresLineOfSight = false
    result.Parent = parent
    return result
end
local function context(player, target)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not hrp then return false, math.huge end
    return true, (hrp.Position - target.Position).Magnitude
end
local function allowed(player)
    local now = os.clock()
    if lastInteraction[player] and now - lastInteraction[player] < 0.3 then return false end
    lastInteraction[player] = now
    return true
end
local function update(player, notice)
    local state, inventory = states[player], inventories[player]
    if not state or not inventory then return end
    local snapshot = state:snapshot()
    for _, entry in ipairs(snapshot.entries) do
        local value = inventory:FindFirstChild(entry.id)
        if not value then
            value = Instance.new("StringValue")
            value.Name = entry.id
            value.Parent = inventory
        end
        value.Value = entry.status
    end
    inventory:SetAttribute("PendingCount", snapshot.pendingCount)
    inventory:SetAttribute("TotalRescued", snapshot.totalRescued)
    inventory:SetAttribute("WalkSpeed", snapshot.walkSpeed)
    if notice then inventory:SetAttribute("Notice", notice) end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then humanoid.WalkSpeed = snapshot.walkSpeed end
end
local notices = {
    AlreadyCollected = "You already found this creature.",
    BackpackFull = "Bag full. Return to the refuge.",
    InvalidContext = "Move closer and try again.",
    Empty = "Your bag is empty. Find a creature first.",
}
for index, position in ipairs(positions) do
    local id = string.format("Creature%02d", index)
    local model = Instance.new("Model")
    model.Name = id
    model:SetAttribute("CreatureId", id)
    local assets = ServerStorage:FindFirstChild("RescueAssets")
    local template = assets and assets:FindFirstChild("Frog")
    if template and template:IsA("Model") then
        local visual = template:Clone()
        visual.Name = "Visual"
        visual:ScaleTo(1.5)
        visual:PivotTo(CFrame.new(position))
        for _, item in ipairs(visual:GetDescendants()) do
            if item:IsA("BasePart") then item.Anchored = true; item.CanCollide = false end
        end
        visual.Parent = model
    end
    local glow = marker("Glow", position, Color3.fromRGB(95, 218, 170))
    glow.Parent = model
    local light = Instance.new("PointLight")
    light.Color, light.Brightness, light.Range = glow.Color, 1, 10
    light.Parent = glow
    local capture = prompt(glow, "Collect", "Lost creature", 10)
    model.Parent = creatures
    capture.Triggered:Connect(function(player)
        if not states[player] or not allowed(player) then return end
        if not capture.Enabled or capture.Parent ~= glow or model.Parent ~= creatures
            or model:GetAttribute("CreatureId") ~= id then return end
        local alive, distance = context(player, glow)
        local ok, reason = states[player]:capture(id, alive, distance)
        update(player, ok and "Creature found! Return it to the refuge." or notices[reason])
    end)
end
local refuge = marker("Refuge", Vector3.new(-130, 3, 145), Color3.fromRGB(244, 198, 103))
refuge.Size = Vector3.new(3, 3, 3)
refuge.Parent = root
local deposit = prompt(refuge, "Rescue", "Refuge", 12)
deposit.Triggered:Connect(function(player)
    if not states[player] or not allowed(player) then return end
    if not deposit.Enabled or deposit.Parent ~= refuge or refuge.Parent ~= root then return end
    local alive, distance = context(player, refuge)
    local count, reason = states[player]:deposit(alive, distance)
    update(player, count > 0 and ("Rescued " .. count .. " creature(s)!") or notices[reason])
end)
local function addPlayer(player)
    if states[player] then return end
    states[player] = RescueState.new()
    local inventory = Instance.new("Folder")
    inventory.Name = "RescueInventory"
    inventory.Parent = player
    inventories[player] = inventory
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid and states[player] then humanoid.WalkSpeed = states[player]:snapshot().walkSpeed end
    end)
    update(player, "Find a lost creature near the path.")
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    states[player], inventories[player], lastInteraction[player] = nil, nil, nil
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
