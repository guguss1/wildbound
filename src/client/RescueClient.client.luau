-- Read-only client presentation of the server-owned session inventory.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local inventory = player:WaitForChild("RescueInventory")

local gui = Instance.new("ScreenGui")
gui.Name = "RescueUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local pine, teal, gold = Color3.fromRGB(18, 35, 33), Color3.fromRGB(81, 172, 145), Color3.fromRGB(241, 203, 125)
local function round(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end
local function textLabel(parent, name, text, size)
    local label = Instance.new("TextLabel")
    label.Name, label.Text = name, text
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(231, 239, 230)
    label.Font, label.TextSize = Enum.Font.Gotham, size
    label.TextWrapped = true
    label.Parent = parent
    return label
end
local function button(parent, name, text)
    local result = Instance.new("TextButton")
    result.Name, result.Text = name, text
    result.BackgroundColor3, result.TextColor3 = teal, pine
    result.Font, result.TextSize = Enum.Font.GothamBold, 16
    result.AutoButtonColor = true
    result.Parent = parent
    round(result, 10)
    return result
end
local objective = textLabel(gui, "Objective", "", 15)
objective.Size, objective.Position = UDim2.new(0.85, 0, 0, 76), UDim2.new(0.5, 0, 0, 8)
objective.AnchorPoint = Vector2.new(0.5, 0)
objective.BackgroundTransparency, objective.BackgroundColor3 = 0.12, pine
round(objective, 10)
local objectiveConstraint = Instance.new("UISizeConstraint")
objectiveConstraint.MaxSize = Vector2.new(600, 76)
objectiveConstraint.Parent = objective
local toggle = button(gui, "InventoryButton", "Inventory  [I]")
toggle.AnchorPoint = Vector2.new(0.5, 1)
toggle.Size, toggle.Position = UDim2.new(0, 150, 0, 44), UDim2.new(0.5, 0, 1, -16)
local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.BackgroundColor3, panel.BackgroundTransparency = pine, 0.04
panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52)
panel.Size, panel.Visible = UDim2.new(0.9, 0, 0.72, 0), false
panel.Parent = gui
round(panel, 16)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(500, 520)
constraint.Parent = panel
local title = textLabel(panel, "Title", "CREATURE RESCUE", 21)
title.Font, title.TextColor3 = Enum.Font.GothamBold, gold
title.Position, title.Size = UDim2.new(0, 16, 0, 8), UDim2.new(1, -72, 0, 34)
title.TextXAlignment = Enum.TextXAlignment.Left
local close = button(panel, "CloseButton", "×")
close.Position, close.Size = UDim2.new(1, -48, 0, 10), UDim2.fromOffset(36, 36)
local session = textLabel(panel, "SessionLabel", "Session only • Progress resets when you leave", 13)
session.Position, session.Size = UDim2.new(0, 16, 0, 45), UDim2.new(1, -32, 0, 28)
session.TextXAlignment = Enum.TextXAlignment.Left
local summary = textLabel(panel, "Summary", "", 15)
summary.Position, summary.Size = UDim2.new(0, 16, 0, 74), UDim2.new(1, -32, 0, 35)
summary.TextXAlignment = Enum.TextXAlignment.Left
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Cards"
scroll.Position, scroll.Size = UDim2.new(0, 12, 0, 114), UDim2.new(1, -24, 1, -126)
scroll.BackgroundTransparency, scroll.BorderSizePixel = 1, 0
scroll.ScrollBarThickness = 5
scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.new()
scroll.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.Parent = scroll
local empty = textLabel(scroll, "Empty", "No creatures yet. Explore the paths!", 15)
empty.Size, empty.LayoutOrder = UDim2.new(1, -8, 0, 50), 0

local function setVisible(visible) panel.Visible = visible end
toggle.Activated:Connect(function() setVisible(not panel.Visible) end)
close.Activated:Connect(function() setVisible(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.I then
        setVisible(not panel.Visible)
    end
end)
local function hideCollected()
    local root = workspace:FindFirstChild("RescueGameplay")
    local folder = root and root:FindFirstChild("Creatures")
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        local collected = inventory:FindFirstChild(model:GetAttribute("CreatureId") or "")
        if collected then
            for _, item in ipairs(model:GetDescendants()) do
                if item:IsA("BasePart") then item.LocalTransparencyModifier = 1
                elseif item:IsA("ProximityPrompt") or item:IsA("PointLight") then item.Enabled = false end
            end
        end
    end
end
local function refresh()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local count = 0
    for _, entry in ipairs(inventory:GetChildren()) do
        if entry:IsA("StringValue") then
            count += 1
            local card = Instance.new("Frame")
            card.Name, card.BackgroundColor3 = entry.Name, Color3.fromRGB(33, 62, 55)
            card.Size, card.LayoutOrder = UDim2.new(1, -8, 0, 58), count
            card.Parent = scroll
            round(card, 8)
            local icon = Instance.new("ImageLabel")
            icon.Name, icon.BackgroundTransparency = "Thumbnail", 1
            icon.Image = "rbxthumb://type=Asset&id=106808835&w=150&h=150"
            icon.Position, icon.Size = UDim2.fromOffset(8, 5), UDim2.fromOffset(48, 48)
            icon.Parent = card
            local label = textLabel(card, "Name", "Moss Frog #" .. entry.Name:sub(-2), 15)
            label.Position, label.Size = UDim2.new(0, 62, 0, 0), UDim2.new(0.65, -62, 1, 0)
            label.TextXAlignment = Enum.TextXAlignment.Left
            local status = textLabel(card, "Status", entry.Value, 14)
            status.TextColor3 = entry.Value == "Rescued" and gold or teal
            status.Position, status.Size = UDim2.new(0.65, 0, 0, 0), UDim2.new(0.35, -8, 1, 0)
            local scale = Instance.new("UIScale")
            scale.Parent = card
            card.MouseEnter:Connect(function()
                TweenService:Create(scale, TweenInfo.new(0.15), {Scale = 1.02}):Play()
                TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(43, 80, 69)}):Play()
            end)
            card.MouseLeave:Connect(function()
                TweenService:Create(scale, TweenInfo.new(0.15), {Scale = 1}):Play()
                TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(33, 62, 55)}):Play()
            end)
        end
    end
    empty.Visible = count == 0
    local pending = inventory:GetAttribute("PendingCount") or 0
    local rescued = inventory:GetAttribute("TotalRescued") or 0
    local speed = inventory:GetAttribute("WalkSpeed") or 16
    summary.Text = string.format("Bag %d/3     Rescued %d/8     Speed %d", pending, rescued, speed)
    if rescued >= 8 then
        objective.Text = "All creatures rescued!  •  Session only"
    elseif pending > 0 then
        objective.Text = "Return to the refuge and rescue your creatures."
    else
        objective.Text = "Explore the paths and find lost creatures."
    end
    local notice = inventory:GetAttribute("Notice")
    if notice and notice ~= "" then objective.Text = objective.Text .. "\n" .. notice end
    hideCollected()
end
local function connectEntry(entry)
    if entry:IsA("StringValue") then entry.Changed:Connect(refresh) end
    refresh()
end
inventory.ChildAdded:Connect(connectEntry)
inventory.ChildRemoved:Connect(refresh)
inventory.AttributeChanged:Connect(refresh)
for _, entry in ipairs(inventory:GetChildren()) do connectEntry(entry) end
local observedRoot
local function observeRoot(root)
    if observedRoot == root then return end
    observedRoot = root
    root.DescendantAdded:Connect(function()
        task.defer(hideCollected)
    end)
    task.defer(hideCollected)
end
workspace.ChildAdded:Connect(function(child)
    if child.Name == "RescueGameplay" then observeRoot(child) end
end)
local existingRoot = workspace:FindFirstChild("RescueGameplay")
if existingRoot then observeRoot(existingRoot) end
refresh()
