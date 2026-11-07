-- Run in the Play client DataModel after the player has spawned.
local player = game:GetService("Players").LocalPlayer
local gui = assert(player.PlayerGui:FindFirstChild("RescueUI"), "Rescue UI missing")
assert(gui:FindFirstChild("InventoryButton", true), "Inventory button missing")
assert(gui:FindFirstChild("InventoryPanel", true), "Inventory panel missing")
assert(gui:FindFirstChild("Objective", true), "Objective missing")
assert(gui:FindFirstChild("SessionLabel", true), "Session limitation missing")
-- A synthetic entry exercises card rendering only; it cannot mutate server state.
local inventory = player:WaitForChild("RescueInventory")
local entry = Instance.new("StringValue"); entry.Name = "Creature99"; entry.Value = "Pending"; entry.Parent = inventory
task.wait()
local card = assert(gui:FindFirstChild("Creature99", true), "Card missing")
assert(card:FindFirstChild("Thumbnail"), "Frog thumbnail missing")
assert(card:FindFirstChildOfClass("UIScale"), "Hover scale missing")
local folder = workspace:WaitForChild("RescueGameplay"):WaitForChild("Creatures")
local streamed = Instance.new("Model")
streamed.Name = "SyntheticStreamed"
streamed:SetAttribute("CreatureId", "Creature99")
streamed.Parent = folder
local part = Instance.new("Part")
part.Parent = streamed
local prompt = Instance.new("ProximityPrompt")
prompt.Parent = part
task.wait()
assert(part.LocalTransparencyModifier == 1 and not prompt.Enabled, "Late streamed creature not hidden")
streamed:Destroy()
entry:Destroy()
-- On a touch simulator, validate the HUD against Roblox's visible movement control.
local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
if touchGui then
    local thumbstick = touchGui:FindFirstChild("ThumbstickStart", true)
    assert(thumbstick and thumbstick.Visible, "Visible thumbstick missing from touch simulator")
    if thumbstick and thumbstick.Visible then
        local button = gui.InventoryButton
        local a, b = button.AbsolutePosition, thumbstick.AbsolutePosition
        local as, bs = button.AbsoluteSize, thumbstick.AbsoluteSize
        local overlap = a.X < b.X + bs.X and b.X < a.X + as.X
            and a.Y < b.Y + bs.Y and b.Y < a.Y + as.Y
        assert(not overlap, "Inventory button overlaps thumbstick")
    end
    local previousNotice = inventory:GetAttribute("Notice")
    local previousPending = inventory:GetAttribute("PendingCount")
    inventory:SetAttribute("Notice", "Creature found! Return it to the refuge.")
    task.wait()
    local fitsFinding = gui.Objective.TextFits
    inventory:SetAttribute("PendingCount", 1)
    task.wait()
    local fitsReturning = gui.Objective.TextFits
    inventory:SetAttribute("PendingCount", previousPending)
    inventory:SetAttribute("Notice", previousNotice)
    assert(fitsFinding and fitsReturning, "Objective text does not fit")
end
return "Client integration passed"
