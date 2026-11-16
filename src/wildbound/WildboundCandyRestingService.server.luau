-- PF3 (odd/tasks/wildbound-caramelo-playfix.md): the resting posts of the Caramelo creatures that live at a fixed post.
-- Between encounters each client shows a resting copy of the creature there (WildboundCandyRestingClient), the way
-- Don Glaseon sleeps on BossHome (he keeps his own server-side dormant copy, so he is not listed here); the live view
-- replaces it while an encounter of that beast exists, and every calm encounter ends with a walk home to this same
-- spot, so a creature never appears from nothing or vanishes into nothing. This script only publishes where each post
-- is: ReplicatedStorage.WildboundBeasts attribute RestingPost_<name> = the ground point under its home site, raised by
-- the hover height of a flier (Mielita), the point the beast server starts the encounter at.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("WildboundBeastConfig"))
local Sites = require(ServerScriptService:WaitForChild("WildboundPraderaSites"))

local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
if not root then
	warn("WildboundCandyRestingService: ReplicatedStorage.WildboundBeasts never appeared, no resting copies.")
	return
end

local biome = workspace:WaitForChild("Candy_Bioma_v1", 60)
local floor = biome and biome:FindFirstChild("Ground")
local params = RaycastParams.new()
-- the candy floor only (never a nest or a marker over it); without it, the terrain and anything solid
params.FilterType = floor and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { floor or workspace:FindFirstChild("WildboundBeastsLocal") or root }

for _, name in ipairs(NAMES) do
	local beast = Config.BEASTS[name]
	local site = beast and Sites.HOME[name] and Sites.world(nil, Sites.HOME[name])
	if site then
		local hit = workspace:Raycast(Vector3.new(site.x, 200, site.z), Vector3.new(0, -400, 0), params)
		local y = (hit and hit.Position.Y or 0) + (beast.grounded ~= true and beast.tuning.HoverStuds or 0)
		root:SetAttribute("RestingPost_" .. name, Vector3.new(site.x, y, site.z))
	else
		warn("WildboundCandyRestingService: no home site for " .. name)
	end
end
