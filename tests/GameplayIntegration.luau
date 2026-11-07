-- Run in the Play server DataModel after the player has spawned.
local player = assert(game:GetService("Players"):GetPlayers()[1], "Player missing")
local world = assert(workspace:FindFirstChild("RescueGameplay"), "Gameplay root missing")
local creatures = assert(world:FindFirstChild("Creatures"), "Creature folder missing")
assert(#creatures:GetChildren() == 8, "Expected eight creatures")
for _, model in ipairs(creatures:GetChildren()) do
    assert(model:GetAttribute("CreatureId"), "Creature ID missing")
    assert(model:FindFirstChildWhichIsA("ProximityPrompt", true), "Capture prompt missing")
end
assert(world:FindFirstChild("Refuge", true):FindFirstChildWhichIsA("ProximityPrompt", true), "Refuge prompt missing")
local inventory = assert(player:FindFirstChild("RescueInventory"), "Inventory missing")
assert(inventory:GetAttribute("PendingCount") == 0 and inventory:GetAttribute("TotalRescued") == 0, "Initial counts incorrect")
assert(inventory:GetAttribute("WalkSpeed") == 16, "Initial speed incorrect")
return "Server integration passed"
