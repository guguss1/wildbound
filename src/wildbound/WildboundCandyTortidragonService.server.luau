-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2): gives the beast client Tortidragon's real model.
-- WildboundBeastsClient shows ReplicatedStorage.WildboundBeasts.Models.<beast> when it exists, so a copy of the rig
-- prefab is parked there, carrying the published clip ids (Clip_<name>) and the numbers of Abanico de Confites
-- (Abanico_<name>) as attributes for WildboundCandyTortidragonAnim on each client, which cannot read ServerStorage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Clips = require(ServerStorage:WaitForChild("WildboundCandyTortidragonClips"))
local Abanico = require(ServerStorage:WaitForChild("WildboundCandyTortidragonAttack"))
local prefab = ServerStorage:WaitForChild("WildboundAssets"):WaitForChild("Tortidragon")
local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
if not models then
	warn("WildboundCandyTortidragonService: ReplicatedStorage.WildboundBeasts.Models never appeared, Tortidragon has no model.")
	return
end
if not models:FindFirstChild("Tortidragon") then
	local model = prefab:Clone()
	model.Name = "Tortidragon"
	-- only published clips: until a clip has an id the client leaves the model in its rest pose for that phase
	for _, name in ipairs(Clips.ORDER) do
		if Clips.IDS[name] then model:SetAttribute("Clip_" .. name, Clips.animationId(name)) end
	end
	model:SetAttribute("Abanico_ReleaseSeconds", Abanico.RELEASE_SECONDS)
	model:SetAttribute("Abanico_ShotRadius", Abanico.SHOT_RADIUS_STUDS)
	model.Parent = models
end
