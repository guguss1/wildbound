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

-- K-D7 (Pueblo Gatito, owner request 2026-11-17 "un parque verde lindo con las criaturas gatitas"): the four kittens
-- rest at their park posts too (home posts here, east extra posts below).
local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon",
	"GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" }

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
if not root then
	warn("WildboundCandyRestingService: ReplicatedStorage.WildboundBeasts never appeared, no resting copies.")
	return
end

local biome = workspace:WaitForChild("Candy_Bioma_v1", 60)
local floor = biome and biome:FindFirstChild("Ground")
-- K-D7: the kitten park's floor (Candy_Este_v1.Ground) as well, each one only when present (no nil holes)
local east = workspace:WaitForChild("Candy_Este_v1", 10)
local eastFloor = east and east:FindFirstChild("Ground")
local floors = {}
if floor then table.insert(floors, floor) end
if eastFloor then table.insert(floors, eastFloor) end
local params = RaycastParams.new()
-- the candy floors only (never a nest or a marker over them); without them, the terrain and anything solid
params.FilterType = #floors > 0 and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = #floors > 0 and floors or { workspace:FindFirstChild("WildboundBeastsLocal") or root }

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

-- CH1 (owner request "more repeated creatures"): each extra post (WildboundPraderaSites.EXTRA_POSTS) the same way, as
-- RestingPost_<name>_<post>; the client hides only the copy of the post a live view started on.
for _, extra in ipairs(Sites.EXTRA_POSTS) do
	local beast = Config.BEASTS[extra.name]
	local site = beast and Sites.world(nil, extra.key)
	if site then
		local hit = workspace:Raycast(Vector3.new(site.x, 200, site.z), Vector3.new(0, -400, 0), params)
		local y = (hit and hit.Position.Y or 0) + (beast.grounded ~= true and beast.tuning.HoverStuds or 0)
		root:SetAttribute("RestingPost_" .. extra.name .. "_" .. extra.key, Vector3.new(site.x, y, site.z))
	else
		warn("WildboundCandyRestingService: no extra post " .. tostring(extra.key) .. " for " .. tostring(extra.name))
	end
end

-- K-D7: the kittens' east extra posts (WildboundPraderaSites.EAST_EXTRA_POSTS), the same way
for _, extra in ipairs(Sites.EAST_EXTRA_POSTS) do
	local beast = Config.BEASTS[extra.name]
	local site = beast and Sites.world(nil, extra.key)
	if site then
		local hit = workspace:Raycast(Vector3.new(site.x, 200, site.z), Vector3.new(0, -400, 0), params)
		local y = (hit and hit.Position.Y or 0) + (beast.grounded ~= true and beast.tuning.HoverStuds or 0)
		root:SetAttribute("RestingPost_" .. extra.name .. "_" .. extra.key, Vector3.new(site.x, y, site.z))
	else
		warn("WildboundCandyRestingService: no east post " .. tostring(extra.key) .. " for " .. tostring(extra.name))
	end
end
