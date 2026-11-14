-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3): gives the beast client Gomibu's real model. WildboundBeastsClient
-- shows ReplicatedStorage.WildboundBeasts.Models.<beast> when it exists, so a copy of the rig prefab is parked there,
-- carrying the published clip ids as attributes (Clip_<name>) for WildboundCandyGomibuAnim on each client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Clips = require(ServerStorage:WaitForChild("WildboundCandyGomibuClips"))
local prefab = ServerStorage:WaitForChild("WildboundAssets"):WaitForChild("Gomibu")
local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
if not models then
	warn("WildboundCandyGomibuService: ReplicatedStorage.WildboundBeasts.Models never appeared, Gomibu has no model.")
	return
end
if not models:FindFirstChild("Gomibu") then
	local model = prefab:Clone()
	model.Name = "Gomibu"
	for _, name in ipairs(Clips.ORDER) do model:SetAttribute("Clip_" .. name, Clips.animationId(name)) end
	model.Parent = models
end
