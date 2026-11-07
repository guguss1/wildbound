-- Removes what the world script owns when that script is destroyed or deleted. The world script cannot do it
-- itself: its connections die with it (docs/ui/wildbound-start-and-settings.md, A3). Only tagged objects go;
-- the map, the inventory network and other scripts' objects are never touched.
local CollectionService = game:GetService("CollectionService")
local Ownership = require(script.Parent:WaitForChild("WildboundOwnership"))
local world = script.Parent:WaitForChild("WildboundWorld", 30)
if not world then
	warn("Wildbound world guard: no WildboundWorld script to watch.")
	return
end
local swept = false
local function sweep()
	if swept then return end
	swept = true
	Ownership.sweep(CollectionService)
end
world.Destroying:Connect(sweep)
world.AncestryChanged:Connect(function()
	if not world:IsDescendantOf(game) then sweep() end
end)
