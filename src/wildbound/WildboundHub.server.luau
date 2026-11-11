-- Nest Heist hub (docs/maps/wildbound-hub.md): builds the central hub with eight personal bases at server start, east
-- of the forest (HF-T3). The hub is built from ServerStorage.WildboundHubBuilder (generated, parts only) at the
-- origin in WildboundWorldRules (Rules.HUB_X, Rules.HUB_Z), in workspace and never inside WildboundP0, so no marker the
-- inventory server looks up can be shadowed. Building at start means the place file never needs saving for the hub; a
-- hub already in the place (built in Edit) is reused while current (EV-W1). The forest is not moved (the hub is placed beside it,
-- Rules.HUB_X); new characters start on the hub's spawn pads (the inventory server, HB6). The stations are bound by
-- tag in WildboundHubStations (required by the inventory server).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Bases = require(script.Parent:WaitForChild("WildboundBases"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))

-- EV-W1: the hub can be built in Edit (the same builder, so the map is visible and editable) and saved with the
-- place; it is reused while it is the builder's current plan (Bases.hubCurrent) and rebuilt once when it is missing
-- or outdated, never duplicated.
local hub = workspace:FindFirstChild("WildboundHub")
do
	local builderModule = ServerStorage:FindFirstChild("WildboundHubBuilder")
	local loaded, Builder = false, nil
	if builderModule and builderModule:IsA("ModuleScript") then
		loaded, Builder = pcall(require, builderModule)
		if not loaded then
			warn("Wildbound hub: the builder failed to load: " .. tostring(Builder))
			Builder = nil
		end
	end
	if hub and not Bases.hubCurrent(hub, Builder) then
		hub:Destroy()
		hub = nil
	end
	if not hub then
		if not Builder then
			warn("Wildbound hub: ServerStorage.WildboundHubBuilder is missing; no hub this session.")
			return
		end
		local ok, result = pcall(function()
			return Builder.build(workspace, CFrame.new(Rules.HUB_X, 0, Rules.HUB_Z))
		end)
		if not ok then
			warn("Wildbound hub: the build failed: " .. tostring(result))
			return
		end
		hub = result
	end
end

-- HF-T3 (S1): the hub stands beside the forest, so the temporary camp link of HB-T1 is gone; one saved in the place is
-- removed. HB7: the forest edge trees under the NW and SW trails are removed from the forest map (by name, only
-- these). Both at start, so the place file never needs saving.
local leftover = workspace:FindFirstChild("WildboundHubLink")
if leftover then leftover:Destroy() end
-- EV-W3: the editor's preview gallery of the uploaded beast models (built in Edit) is never part of a session.
local gallery = workspace:FindFirstChild("WildboundBeastGallery")
if gallery then gallery:Destroy() end
local forest = workspace:FindFirstChild("WildboundP0")
if forest then
	for _, name in ipairs(Bases.REMOVED_FOREST_PROPS) do
		local prop = forest:FindFirstChild(name, true)
		if prop then prop:Destroy() end
	end
end

-- HB-T2: base assignment. The server alone writes OwnerUserId and OwnerName on the base model (WildboundBaseSlot) and
-- the sign's text; the stations module and the clients read them. A player beyond the eight slots uses the camp.
local registry = Bases.new(Bases.SLOTS)
local baseModels, signLabels = {}, {}
for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do
	local slot = model:GetAttribute("SlotIndex")
	if model:IsDescendantOf(hub) and type(slot) == "number" then baseModels[slot] = model end
end
for _, board in ipairs(CollectionService:GetTagged("WildboundBaseSign")) do
	local slot, label = board:GetAttribute("SlotIndex"), board:FindFirstChild("Label", true)
	if board:IsDescendantOf(hub) and type(slot) == "number" and label and label:IsA("TextLabel") then
		signLabels[slot] = label
	end
end
local function paint(slot, player)
	local model, label = baseModels[slot], signLabels[slot]
	if model then
		model:SetAttribute("OwnerUserId", player and player.UserId or 0)
		model:SetAttribute("OwnerName", player and player.DisplayName or "")
	end
	if label then label.Text = Bases.signText(Text, player and player.DisplayName or nil) end
end
for slot in pairs(baseModels) do paint(slot, nil) end
local function join(player)
	local slot = Bases.assign(registry, player.UserId)
	if not slot then return end
	paint(slot, player)
	local model = baseModels[slot]
	player:SetAttribute("WildboundBaseSlot", slot)
	player:SetAttribute("WildboundBaseColour", model and model:GetAttribute("ColourName") or nil)
end
Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
	local slot = Bases.release(registry, player.UserId)
	if not slot then return end
	paint(slot, nil)
	player:SetAttribute("WildboundBaseSlot", nil)
	player:SetAttribute("WildboundBaseColour", nil)
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(join, player) end
