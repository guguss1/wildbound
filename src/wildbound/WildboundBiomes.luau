-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-3; beast spawn design P1): the biome tags the beast director reads
-- as ctx.biomes. Pure data and lookups (server only): no services, no clock. The squares are the open-world placement's
-- `bounds_world` (assets/maps/open-world/biome-placement-v1.json, made for the hub at (282, -3), radius 90); a Python
-- test (tools/test_wildbound_beasts_wave2.py) keeps them equal to that file. Tags are the director's names:
-- Swamp = Pantano (the `living-forest` square, north of the hub), Meadow = Pradera Arcoíris, Cemetery = Cementerio.
-- The Pantano square is a plan until its builder runs in Studio; until then the only swamp in the place is the forest's
-- nest island I3, "Pantano de los Juncos" (WildboundIslandLayout, key "pantano"), tagged Swamp on its floor circle
-- (open owner decision: drop that row to keep Root out of the forest).
local Biomes = {}

local function square(tag, key, minX, maxX, minZ, maxZ)
	return table.freeze({ tag = tag, key = key, kind = "square", minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
end

Biomes.AREAS = table.freeze({
	square("Forest", "forest", -218, 182, -203, 197),
	square("Meadow", "pradera", 412, 812, -203, 197),
	square("Swamp", "living-forest", 82, 482, -643, -243),
	square("Cemetery", "cryptic-ruins", 132, 432, 237, 537),
	square("Abyss", "demon-abyss", -258, 42, -543, -243),
	square("Mountains", "frozen-mountains", 522, 1022, -743, -243),
	square("Volcanic", "volcanic-lands", -308, 92, 237, 637),
	square("Caves", "rock-caves", 472, 772, 237, 537),
	table.freeze({ tag = "Swamp", key = "island-pantano", kind = "circle", x = 115, z = 15, r = 16 }),
})

-- Big4 map experiment (odd/tasks/wildbound-big4-map.md): four larger biomes only. Forest and Caramelo keep their plots
-- and grow by annexes; Montañas and Volcán are scaled clones pinned at the corner nearest the hub. Pantano, Cementerio,
-- Cuevas and Abismo are archived, so their squares read as no biome (the hub's day). The I3 swamp circle stays.
Biomes.AREAS_BIG4 = table.freeze({
	square("Forest", "forest", -618, 182, -563, 197),
	square("Meadow", "pradera", 412, 1012, -203, 537),
	square("Mountains", "frozen-mountains", 247, 1022, -1018, -243),
	square("Volcanic", "volcanic-lands", -668, 92, 237, 997),
	table.freeze({ tag = "Swamp", key = "island-pantano", kind = "circle", x = 115, z = 15, r = 16 }),
})

-- The map mode: the replicated Workspace attribute WildboundMapMode ("big4"; absent or anything else = "classic", the
-- place as it was). Read through the DataModel inside a pcall, so a pure caller with no game reads "classic".
Biomes.MODE_ATTRIBUTE = "WildboundMapMode"
-- MAPMODE BEGIN
local modeRoot
function Biomes.mode()
	if modeRoot == nil then
		local ok, root = pcall(function() return game:GetService("Workspace") end)
		modeRoot = ok and root or false
	end
	if not modeRoot then return "classic" end
	local ok, value = pcall(modeRoot.GetAttribute, modeRoot, Biomes.MODE_ATTRIBUTE)
	return (ok and value == "big4") and "big4" or "classic"
end
-- MAPMODE END

-- areasFor(mode) -> the area list of a mode ("big4" or "classic"; nil reads the place's current mode).
function Biomes.areasFor(mode)
	if mode == nil then mode = Biomes.mode() end
	return mode == "big4" and Biomes.AREAS_BIG4 or Biomes.AREAS
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function inside(area, x, z)
	if area.kind == "circle" then
		return (x - area.x) ^ 2 + (z - area.z) ^ 2 <= area.r * area.r
	end
	return x >= area.minX and x <= area.maxX and z >= area.minZ and z <= area.maxZ
end

-- The tags at a flat point, as a fresh table { [tag] = true } (empty between biomes and for a bad point). mode is
-- optional ("classic" or "big4"); without it the place's current mode is used.
function Biomes.at(x, z, mode)
	local tags = {}
	if not finite(x) or not finite(z) then return tags end
	for _, area in ipairs(Biomes.areasFor(mode)) do
		if inside(area, x, z) then tags[area.tag] = true end
	end
	return tags
end

function Biomes.has(x, z, tag, mode)
	return Biomes.at(x, z, mode)[tag] == true
end

return Biomes
