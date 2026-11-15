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
BiomeLight.AREAS = freeze({
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
BiomeLight.TAG_PRESET = freeze({
	Forest = "Forest", Meadow = "Caramelo", Swamp = "Swamp", Cemetery = "Cemetery", Abyss = "Abyss",
	Mountains = "Mountains", Volcanic = "Volcanic", Caves = "Caves",
})

-- mood: the presentation phase (HUD hint, audio, the fear stalk, Night Nose). clockTime: the local sky. zone: an
-- Atmosphere row that replaces the server's open/fog/camp zone (nil keeps it). variants: whether the wave's biome
-- variant tints it. tint (RGB), saturation, contrast and lift (ColorCorrection Brightness): the local grading.
-- Values are hypotheses to calibrate in Studio; the pack's Caramelo grading is +0.08 / +0.04 / +0.03.
BiomeLight.PRESETS = freeze({
	Caramelo = { label = "Caramelo · siempre de día", mood = "Day", clockTime = 14, zone = "candy", variants = false,
		tint = { 255, 255, 255 }, saturation = 0.08, contrast = 0.04, lift = 0.03 },
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
