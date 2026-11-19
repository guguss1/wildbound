-- CA4 (user, 2026-11-15; Caramelo pack 05_SISTEMAS/02_ILUMINACION_POR_BIOMA.md, odd/tasks/wildbound-caramelo.md): fixed
-- light per biome, with no global day/night cycle. Caramelo is always day, the forest always night, the swamp a green
-- dusk, the cemetery a violet twilight; the other biomes have their own look. Roblox has one sky per client, so
-- each world client picks the preset of the biome its own character stands in and blends to it in about a second; the
-- server never changes anyone's light. Pure and shared (ReplicatedStorage): no services, no clock.
local BiomeLight = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The biome squares, the same numbers as WildboundBiomes.AREAS (server only; a suite keeps them equal). The 16-stud
-- swamp island inside the forest is left out on purpose: the forest's night holds over it, with no flicker.
local function square(tag, minX, maxX, minZ, maxZ)
	return { tag = tag, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end
-- K-D14 (owner request 2026-11-17, "es como el mundo de gatito: un parque verde lindo ..."): Caramelo Este (Pueblo
-- Gatito) is the first row, because presetAt answers with the first square that holds the point; where another square
-- overlaps the cloud band or the park, the park's light wins.
BiomeLight.AREAS = freeze({
	-- V8-D2 (owner request 2026-11-17): the cloud band and the second space, Pueblo Gatito since PG-D1 (WildboundBiomes
	-- "pueblo-gatito"). PGM-D3 (docs/design/wildbound-pueblo-gatito-move-plan.md; owner request 2026-11-18, "Sí,
	-- movelo"): the park moved, so the square is the whole big4 south arm (WildboundGatitoArea.ARM; was x 932..1468, z
	-- -263..257). Still first: here it overlaps Volcanic, Cemetery and Caves, and Pueblo Gatito wins
	-- GL-D2 (docs/design/wildbound-pueblo-gatito-long-plan.md; owner request 2026-11-19, "hace el mapa bastante mas
	-- largo"): the park grew to 600 x 1200, so the arm runs to z 1537 (was z 337..937), still the first row
	square("CandyEast", -3, 597, 337, 1537),
	square("Forest", -218, 182, -203, 197),
	square("Meadow", 412, 812, -203, 197),
	square("Swamp", 82, 482, -643, -243),
	square("Cemetery", 132, 432, 237, 537),
	square("Abyss", -258, 42, -543, -243),
	square("Mountains", 522, 1022, -743, -243),
	square("Volcanic", -308, 92, 237, 637),
	square("Caves", 472, 772, 237, 537),
})
-- The preset of each biome tag (the Meadow square is the Caramelo biome now). Between biomes, the hub's day.
-- Deliberately changed (K-D14): Caramelo Este is Pueblo Gatito, lit by its own Gatuno preset (a blue sky, white clouds
-- and a long, clear view; Day rules). V8-D2 had it keep the Caramelo preset.
BiomeLight.TAG_PRESET = freeze({
	Forest = "Forest", Meadow = "Caramelo", Swamp = "Swamp", Cemetery = "Cemetery", Abyss = "Abyss",
	Mountains = "Mountains", Volcanic = "Volcanic", Caves = "Caves", CandyEast = "Gatuno",
})

-- mood: the presentation phase (HUD hint, audio, the fear stalk, Night Nose). clockTime: the local sky. zone: an
-- Atmosphere row that replaces the server's open/fog/camp zone (nil keeps it). variants: whether the wave's biome
-- variant tints it. tint (RGB), saturation, contrast and lift (ColorCorrection Brightness): the local grading.
-- Values are hypotheses to calibrate in Studio; the pack's Caramelo grading is +0.08 / +0.04 / +0.03.
BiomeLight.PRESETS = freeze({
	Caramelo = { label = "Caramelo · siempre de día", mood = "Day", clockTime = 14, zone = "candy", variants = false,
		tint = { 255, 255, 255 }, saturation = 0.08, contrast = 0.04, lift = 0.03 },
	-- K-D14: the kitten park, always day in clear blue air (the Atmosphere park zone).
	Gatuno = { label = "Pueblo Gatito · siempre de día", mood = "Day", clockTime = 13, zone = "park", variants = false,
		tint = { 255, 255, 255 }, saturation = 0.06, contrast = 0.03, lift = 0.03 },
	Forest = { label = "Bosque · siempre de noche", mood = "Night", clockTime = 0, variants = true,
		tint = { 255, 255, 255 }, saturation = 0, contrast = 0, lift = 0 },
	Swamp = { label = "Pantano · atardecer", mood = "Dusk", clockTime = 19, variants = true,
		tint = { 214, 236, 196 }, saturation = -0.05, contrast = 0.02, lift = 0 },
	Cemetery = { label = "Cementerio · crepúsculo", mood = "Dusk", clockTime = 19, variants = true,
		tint = { 222, 206, 246 }, saturation = -0.08, contrast = 0.06, lift = 0 },
	Abyss = { label = "Abismo · noche", mood = "Night", clockTime = 0, variants = true,
		tint = { 255, 210, 210 }, saturation = -0.05, contrast = 0.08, lift = 0 },
	Mountains = { label = "Montañas · día", mood = "Day", clockTime = 13, variants = true,
		tint = { 232, 242, 255 }, saturation = -0.04, contrast = 0.02, lift = 0.02 },
	Volcanic = { label = "Volcán · atardecer", mood = "Dusk", clockTime = 19, variants = true,
		tint = { 255, 222, 200 }, saturation = 0.04, contrast = 0.06, lift = 0 },
	Caves = { label = "Cuevas · oscuridad", mood = "Night", clockTime = 0, variants = true,
		tint = { 236, 232, 226 }, saturation = -0.06, contrast = 0.04, lift = 0 },
	Hub = { label = "Refugio · día", mood = "Day", clockTime = 13, variants = false,
		tint = { 255, 255, 255 }, saturation = 0, contrast = 0, lift = 0 },
})

-- presetAt(x, z) -> name, preset: the preset of the biome a flat point stands in; "Hub" between biomes or for a bad
-- point.
function BiomeLight.presetAt(x, z)
	if finite(x) and finite(z) then
		for _, area in ipairs(BiomeLight.AREAS) do
			if x >= area.minX and x <= area.maxX and z >= area.minZ and z <= area.maxZ then
				local name = BiomeLight.TAG_PRESET[area.tag]
				if name then return name, BiomeLight.PRESETS[name] end
			end
		end
	end
	return "Hub", BiomeLight.PRESETS.Hub
end

-- CF1 (user, 2026-11-15, "Bosque siempre de noche"; odd/tasks/wildbound-caramelo.md): the gameplay phase of each
-- preset. No global cycle, but the forest and the other dark biomes play by Night rules always (La Silueta's night
-- profile and brain row, doubled beast odds, the islands' night wake, the night ambush timer); Caramelo, the hub,
-- Montañas and the dusk-looking biomes play by Day rules. Dusk and Dawn never happen: a dusk look is only a look.
BiomeLight.RULES = freeze({
	Forest = "Night", Abyss = "Night", Caves = "Night",
	Caramelo = "Day", Hub = "Day", Mountains = "Day", Swamp = "Day", Cemetery = "Day", Volcanic = "Day",
	Gatuno = "Day", -- K-D14: the kitten park plays by Day rules, like Caramelo
})
-- The clock time those rules read (the islands' deep sleep is 11:00-13:00, so neither is in it).
BiomeLight.RULES_CLOCK = freeze({ Day = 14, Night = 0 })

-- phaseAt(x, z) -> phase, clockTime: the gameplay phase of the place a flat point stands in (the hub's Day between
-- biomes or for a bad point). Servers key it on the position of the player or entity a rule concerns.
function BiomeLight.phaseAt(x, z)
	local name = BiomeLight.presetAt(x, z)
	local phase = BiomeLight.RULES[name] or "Day"
	return phase, BiomeLight.RULES_CLOCK[phase]
end

-- target(Atmosphere, name, serverZone, reduced, variant) -> the WildboundAtmosphere target for a preset, with `tint`
-- (the variant's, when the preset takes variants, times the preset's), saturation, contrast and lift. An unknown
-- preset reads as the hub's.
function BiomeLight.target(Atmosphere, name, serverZone, reduced, variant)
	local preset = BiomeLight.PRESETS[name] or BiomeLight.PRESETS.Hub
	local zone = preset.zone or serverZone
	local target = Atmosphere.variant(Atmosphere.at(preset.clockTime, zone, reduced), preset.variants and variant or nil)
	local tint = target.tint or { r = 255, g = 255, b = 255 }
	target.tint = { r = tint.r * preset.tint[1] / 255, g = tint.g * preset.tint[2] / 255, b = tint.b * preset.tint[3] / 255 }
	target.saturation, target.contrast, target.lift = preset.saturation, preset.contrast, preset.lift
	return target
end

-- The blend toward a new preset: 95% of the way after BLEND_SECONDS (the pack asks for 0.8 to 1.5 s, no flicker).
BiomeLight.BLEND_SECONDS = 1
function BiomeLight.alpha(dt)
	if not finite(dt) or dt <= 0 then return 0 end
	return 1 - math.exp(-dt * 3 / BiomeLight.BLEND_SECONDS)
end

return BiomeLight
