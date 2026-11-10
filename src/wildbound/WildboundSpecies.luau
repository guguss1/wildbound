-- Expedition islands (I8, decision EI-4): how each island species looks until an upload is approved. Every species is
-- a primitive stand-in (a body, an accent, two eyes and a glow) in the colours of its exported rig
-- (tools/build-species-rigs.py, SPECS). The servers build adults, crias, the capsule, the display and the companion
-- from these looks, so a later swap to the real rigs changes this one module: `rig` names the exported rig, and `asset`
-- will hold the uploaded asset when the user approves it. Data and two small helpers only.
local Species = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function hexColor(hex)
	return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

-- size: the adult's bounding box in studs (x, y, z), from the rig specs; Lumipol keeps its provisional model's size.
-- rarity: the random world's tier for the species (RW2).
Species.LOOKS = freeze({
	Lumipol = { name = "Lumipol", rarity = "Comun", size = { 3, 2, 2.4 }, body = { 121, 202, 160 }, accent = { 81, 151, 117 },
		eye = { 25, 43, 48 }, glow = { 151, 236, 175 }, rig = nil, asset = nil },
	Cortezon = { name = "Cortezon", rarity = "Comun", size = { 3.6, 4.0, 2.4 }, body = hexColor("5B4630"), accent = hexColor("7E9440"),
		eye = hexColor("E8D25A"), glow = hexColor("E8D25A"), rig = "assets/exports/species/SP_Cortezon", asset = nil },
	Cestillo = { name = "Cestillo", rarity = "Rara", size = { 2.6, 2.8, 4.0 }, body = hexColor("B98E55"), accent = hexColor("7E8C47"),
		eye = hexColor("F2F0C8"), glow = hexColor("F2F0C8"), rig = "assets/exports/species/SP_Cestillo", asset = nil },
	Polvilla = { name = "Polvilla", rarity = "Epica", size = { 4.4, 1.6, 4.0 }, body = hexColor("5A5560"), accent = hexColor("B9AE98"),
		eye = hexColor("C9A24A"), glow = hexColor("C9A24A"), rig = "assets/exports/species/SP_Polvilla", asset = nil },
	Tizoncillo = { name = "Tizoncillo", rarity = "Legendaria", size = { 3.0, 5.0, 2.6 }, body = hexColor("241F1D"), accent = hexColor("3A3330"),
		eye = hexColor("C8481A"), glow = hexColor("C8481A"), rig = "assets/exports/species/SP_Tizoncillo", asset = nil },
})
-- A cria is this fraction of an adult; the nest glow is teal for a cria and pale gold for an egg (clarity first).
Species.CRIA_SCALE = 0.55
Species.NEST_GLOW = freeze({ cria = { 90, 230, 210 }, egg = { 245, 225, 150 } })

-- Random world (RW2): each species' rarity tier; a random spawn of a tier picks one of its species. The order matches
-- the island reward tiers (Safe and Fog Comun, FogFar Rara, Territory Epica, Heart Legendaria).
function Species.byRarity(tier)
	local names = {}
	for name, look in pairs(Species.LOOKS) do
		if look.rarity == tier then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

function Species.look(name)
	return type(name) == "string" and Species.LOOKS[name] or Species.LOOKS.Lumipol
end

function Species.hex(rgb)
	return ("%02X%02X%02X"):format(rgb[1], rgb[2], rgb[3])
end

return Species
