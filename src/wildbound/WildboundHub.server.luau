-- Nest Heist hub (docs/maps/wildbound-hub.md): builds the central hub with eight personal bases at server start, and a
-- walkable link from the camp. The hub is built from ServerStorage.WildboundHubBuilder (generated, parts only) at the
-- origin in WildboundWorldRules (Rules.HUB_X, Rules.HUB_Z), in workspace and never inside WildboundP0, so no marker the
-- inventory server looks up can be shadowed. Building at start means the place file never needs saving for the hub; a
-- hub already in the place (built in Edit) is reused as it is. The forest is not moved here (open-world gaps S1) and the
-- spawn stays at the camp. The stations are bound by tag in WildboundHubStations (required by the inventory server).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Bases = require(script.Parent:WaitForChild("WildboundBases"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))

local hub = workspace:FindFirstChild("WildboundHub")
if not hub then
	local builderModule = ServerStorage:FindFirstChild("WildboundHubBuilder")
	if not (builderModule and builderModule:IsA("ModuleScript")) then
		warn("Wildbound hub: ServerStorage.WildboundHubBuilder is missing; no hub this session.")
		return
	end
	local ok, result = pcall(function()
		local Builder = require(builderModule)
		return Builder.build(workspace, CFrame.new(Rules.HUB_X, 0, Rules.HUB_Z))
	end)
	if not ok then
		warn("Wildbound hub: the build failed: " .. tostring(result))
		return
	end
	hub = result
end

-- HB-T1: the link from the camp to the hub's NW trail, until the forest shift puts the hub next to the forest. Floors
-- collide and answer queries like the hub's trails (top 0.61, the trails' height); nothing can be touched.
-- It starts inside the camp's safe circle (Rules.CAMP_X, Rules.CAMP_Z): from the CampCenter marker the straight line
-- would cross a tree's solid trunk core (found in Play).
local function buildLink()
	local geometry = Bases.link(Rules.CAMP_X, Rules.CAMP_Z, Rules.HUB_X, Rules.HUB_Z)
	if not geometry then return end
	local link = Instance.new("Model")
	link.Name = "WildboundHubLink"
	link.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local along = Vector3.new(geometry.dirX, 0, geometry.dirZ)
	local function part(name, size, frame, color, material, solid)
		local value = Instance.new("Part")
		value.Name, value.Size, value.CFrame = name, size, frame
		value.Anchored, value.CanTouch = true, false
		value.CanCollide, value.CanQuery = solid == true, solid == true
		value.Color, value.Material = color, material
		value.TopSurface, value.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		value.Parent = link
		return value
	end
	local centre = Vector3.new(geometry.centreX, 0.01, geometry.centreZ)
	part("LinkPath", Vector3.new(geometry.width, 1.2, geometry.length), CFrame.lookAt(centre, centre + along),
		Color3.fromRGB(217, 199, 163), Enum.Material.Sand, true)
	local wood, lamp = Color3.fromRGB(139, 94, 60), Color3.fromRGB(255, 217, 160)
	local side = Vector3.new(-geometry.dirZ, 0, geometry.dirX) * (geometry.width / 2 + 1)
	-- Three lanterns along the way (the camp's warm light), so the path reads at night and in the fog.
	for index, share in ipairs({ 0.25, 0.5, 0.75 }) do
		local at = Vector3.new(geometry.fromX, 0, geometry.fromZ) + along * geometry.length * share + side
		part("LinkLanternPost" .. index, Vector3.new(0.4, 6, 0.4), CFrame.new(at + Vector3.new(0, 3, 0)), wood,
			Enum.Material.Wood)
		local bulb = part("LinkLantern" .. index, Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 6.4, 0)), lamp,
			Enum.Material.Neon)
		bulb.Shape, bulb.CastShadow = Enum.PartType.Ball, false
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(255, 176, 96), 0.8, 16, false
		light.Parent = bulb
	end
	-- A sign at the camp end, readable from any side.
	local start = Vector3.new(geometry.fromX, 0, geometry.fromZ) + side
	local post = part("LinkSignPost", Vector3.new(0.4, 7, 0.4), CFrame.new(start + Vector3.new(0, 3.5, 0)), wood,
		Enum.Material.Wood)
	local sign = Instance.new("BillboardGui")
	sign.Name, sign.Size, sign.StudsOffset = "LinkSign", UDim2.fromOffset(220, 40), Vector3.new(0, 4.2, 0)
	sign.MaxDistance, sign.LightInfluence = 90, 0
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, Text.HUB.linkSign
	label.TextColor3, label.TextStrokeTransparency, label.Font = Color3.fromRGB(255, 240, 215), 0.3, Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = sign
	sign.Parent = post
	link.Parent = workspace
end

if not workspace:FindFirstChild("WildboundHubLink") then buildLink() end

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
