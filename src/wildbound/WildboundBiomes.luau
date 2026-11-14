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

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function inside(area, x, z)
	if area.kind == "circle" then
		return (x - area.x) ^ 2 + (z - area.z) ^ 2 <= area.r * area.r
	end
	return x >= area.minX and x <= area.maxX and z >= area.minZ and z <= area.maxZ
end

-- The tags at a flat point, as a fresh table { [tag] = true } (empty between biomes and for a bad point).
function Biomes.at(x, z)
	local tags = {}
	if not finite(x) or not finite(z) then return tags end
	for _, area in ipairs(Biomes.AREAS) do
		if inside(area, x, z) then tags[area.tag] = true end
	end
	return tags
end

function Biomes.has(x, z, tag)
	return Biomes.at(x, z)[tag] == true
end

return Biomes
