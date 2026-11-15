-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4): gives the beast client Flanfuria's real model. WildboundBeastsClient
-- shows ReplicatedStorage.WildboundBeasts.Models.<beast> when it exists, so a copy of the rig prefab is parked there,
-- carrying the published clip ids (Clip_<name>) and the numbers of Onda de Caramelo (Onda_<name>) as attributes for
-- WildboundCandyFlanfuriaAnim on each client, which cannot read ServerStorage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Clips = require(ServerStorage:WaitForChild("WildboundCandyFlanfuriaClips"))
local Onda = require(ServerStorage:WaitForChild("WildboundCandyFlanfuriaAttack"))
local prefab = ServerStorage:WaitForChild("WildboundAssets"):WaitForChild("Flanfuria")
local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
if not models then
	warn("WildboundCandyFlanfuriaService: ReplicatedStorage.WildboundBeasts.Models never appeared, Flanfuria has no model.")
	return
end
if not models:FindFirstChild("Flanfuria") then
	local model = prefab:Clone()
	model.Name = "Flanfuria"
	for _, name in ipairs(Clips.ORDER) do model:SetAttribute("Clip_" .. name, Clips.animationId(name)) end
	model:SetAttribute("Onda_ReleaseSeconds", Onda.RELEASE_SECONDS)
	model:SetAttribute("Onda_RingFrom", Onda.RING_FROM_STUDS)
	model:SetAttribute("Onda_RingTo", Onda.RING_TO_STUDS)
	model:SetAttribute("Onda_PuddleRadius", Onda.PUDDLE_RADIUS_STUDS)
	model:SetAttribute("Onda_PuddleSeconds", Onda.PUDDLE_SECONDS)
	model.Parent = models
end
