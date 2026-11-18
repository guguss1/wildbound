-- Caramelo ambience (owner request 2026-11-16: "music, sparkles, lights, so it feels more alive"). Pure rules for
-- WildboundCandyAmbienceClient, which decorates the Caramelo plot on the local client only while its player is in or
-- near it: soft coloured lights on the nearest candy props, sugar sparkles, a gentle lollipop sway and a flag that the
-- audio controller turns into the Caramelo music bed (WildboundAudioMix.targets). Here: the budgets per device, the
-- palette, what each kind of prop gets, the nearest-N pick, the emitter rates under a total, the plot's enter/leave
-- hysteresis and the slow motion curves. Shared (ReplicatedStorage), no services, no clock: every time is passed in.
-- Every number is a hypothesis to check in Studio Play. Rules: WildboundCandyAmbience_Test.
local Ambience = {}

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

-- The built biome and the folders whose props are decorated (any may be missing). Nothing named FORBIDDEN, or inside
-- it, is ever touched.
Ambience.ROOT_NAME = "Candy_Bioma_v1"
Ambience.FOLDERS = freeze({ "Lollipops", "CottonTrees", "Gumdrops", "Nests", "Lake", "GranTorta", "Portal", "Sweets", "Entrance" })
Ambience.FORBIDDEN = "SistemaSonriente"
-- Caramelo v3 (docs/design/wildbound-caramelo-v3-plan.md): the v3 pieces live in one folder of the biome
-- (WildboundCandyV3Builder); these sub-folders are decorated too: the new trees sparkle like the old ones, the
-- chocolate shimmers, the waterfall mists and flows, the houses glow warm at the door, the licorice glitters.
Ambience.V3_FOLDER = "CaramelV3"
Ambience.V3_FOLDERS = freeze({ "Trees", "River", "Lake", "Waterfall", "Houses", "Licorice" })
-- The catalog slot of a dedicated Caramelo track (WildboundAudioCatalog.SOUNDS; absent until the owner picks one) and
-- the local WildboundWorldUI attribute that tells the audio controller the player is in the plot.
Ambience.MUSIC_SLOT = "carameloMusic"
Ambience.GUI_ATTRIBUTE = "CandyAmbience"

Ambience.PICK_SECONDS = 0.5 -- the nearest props are re-picked at 2 Hz
Ambience.ENTER_MARGIN = 8 -- studs outside the plot's edge where the ambience starts
Ambience.LEAVE_MARGIN = 32 -- studs outside the edge where it stops (the gap stops flicker on the border)
Ambience.REACH = freeze({ light = 120, sparkle = 80, sway = 60 }) -- studs from the camera
Ambience.EGG_RADIUS = 5 -- a candy egg this close to a nest's centre sits in it
Ambience.MAX_RANGE = 16 -- no light reaches farther than this

-- Per device. Efectos suaves keeps a few steady lights and nothing that moves or sparkles; a touch device gets half.
-- V3 (owner, 2026-11-17: "more sparkle particles"): emitters 10 -> 16 and 60 -> 100 particles per second on desktop,
-- 5 -> 8 and 30 -> 50 on touch; the light count is unchanged.
Ambience.BUDGETS = freeze({
	desktop = { name = "desktop", lights = 12, emitters = 16, rate = 100, sway = 8, pulse = true, fireflies = true },
	touch = { name = "touch", lights = 6, emitters = 8, rate = 50, sway = 4, pulse = false, fireflies = true },
	soft = { name = "soft", lights = 6, emitters = 0, rate = 0, sway = 0, pulse = false, fireflies = false },
})

-- budget(touch, soft) -> the frozen budget row (Efectos suaves wins over touch).
function Ambience.budget(touch, soft)
	if soft == true then return Ambience.BUDGETS.soft end
	if touch == true then return Ambience.BUDGETS.touch end
	return Ambience.BUDGETS.desktop
end

-- Candy colours (RGB 0-255) and the order the lollipops, gumdrops and cake cycle through.
Ambience.PALETTE = freeze({
	pink = { 255, 150, 205 }, mint = { 140, 240, 200 }, lemon = { 255, 236, 130 }, sky = { 140, 205, 255 },
	warm = { 255, 196, 130 },
})
Ambience.PALETTE_ORDER = freeze({ "pink", "mint", "lemon", "sky" })

-- What each kind of prop gets. weight scales its distance in the pick (under 1 wins from farther away: the nests'
-- glow reads from afar). light: PointLight brightness and range; color fixed, else one of PALETTE_ORDER per prop;
-- cycle: the Gran Torta rim slowly cycles the palette. sparkle: a particle style and its base rate (particles/s).
-- Review follow-up: every light one step brighter (Caramelo is always in bright day light).
-- V3 (owner, 2026-11-17: "a little less bright light overall"): every light 20 % dimmer (lollipop 2 -> 1.6, gumdrop
-- 1.6 -> 1.3, nest 2.2 -> 1.75, egg nest 2.5 -> 2, cake and portal 2.4 -> 1.9); the particles keep their look. New
-- kinds for the v3 pieces: river (the chocolate's shimmer), waterfall (mist at its foot), house (a warm door light and
-- glitter), licorice (glitter).
Ambience.KINDS = freeze({
	lollipop = { weight = 1, light = { brightness = 1.6, range = 12 }, sparkle = { style = "glitter", rate = 6 }, sway = true },
	gumdrop = { weight = 1, light = { brightness = 1.3, range = 8 }, sparkle = { style = "glitter", rate = 5 } },
	cotton = { weight = 1, sparkle = { style = "glitter", rate = 5, color = "pink" } },
	sweet = { weight = 1.2, sparkle = { style = "glitter", rate = 4, color = "lemon" } },
	nest = { weight = 0.6, light = { brightness = 1.75, range = 14, color = "warm" } },
	eggNest = { weight = 0.5, light = { brightness = 2, range = 16, color = "warm" },
		sparkle = { style = "twinkle", rate = 8, color = "lemon" } },
	cake = { weight = 0.8, light = { brightness = 1.9, range = 16, cycle = true } },
	portal = { weight = 0.7, light = { brightness = 1.9, range = 14, color = "sky" }, sparkle = { style = "glitter", rate = 6, color = "sky" } },
	lake = { weight = 1, sparkle = { style = "shimmer", rate = 6, color = "lemon" } },
	river = { weight = 1.1, sparkle = { style = "shimmer", rate = 7, color = "warm" } },
	waterfall = { weight = 0.6, sparkle = { style = "mist", rate = 10, color = "warm" } },
	house = { weight = 0.8, light = { brightness = 1.4, range = 14, color = "warm" }, sparkle = { style = "glitter", rate = 5, color = "pink" } },
	licorice = { weight = 0.8, sparkle = { style = "glitter", rate = 8 } },
})
-- The sugar fireflies around the camera: one emitter in a box of `size` studs, counted in the emitter and rate budgets.
Ambience.FIREFLIES = freeze({ style = "fireflies", rate = 8, color = "lemon", size = { 36, 10, 36 } })
-- Particle looks (the default particle texture only). lifetime and speed are { min, max }; size is the start size in
-- studs (it shrinks to 0); spread in degrees; rise is the upward acceleration; area: emitted from a helper part's box;
-- brightness: the emitter's Brightness (above 1 the glitter still reads in day light, with no extra emitter).
Ambience.STYLES = freeze({
	glitter = { lifetime = { 1.6, 2.6 }, speed = { 0.6, 1.6 }, size = 0.3, spread = 35, rise = 0.8, emission = 0.8, brightness = 2 },
	twinkle = { lifetime = { 0.6, 1.1 }, speed = { 0.2, 0.6 }, size = 0.45, spread = 180, rise = 0.2, emission = 1, brightness = 3 },
	shimmer = { lifetime = { 1, 1.6 }, speed = { 0, 0.3 }, size = 0.3, spread = 10, rise = 0, emission = 1, area = true, brightness = 2 },
	fireflies = { lifetime = { 3, 5 }, speed = { 0.3, 0.9 }, size = 0.25, spread = 180, rise = 0.1, emission = 1, area = true,
		brightness = 2 },
	-- V3: the waterfall's spray, wider and softer
	mist = { lifetime = { 1, 1.8 }, speed = { 1, 2.5 }, size = 0.6, spread = 70, rise = 1.2, emission = 0.6, brightness = 1.5 },
})

Ambience.PULSE_PERIOD = 3 -- seconds of a light's slow breath
Ambience.PULSE_STEP = 0.1 -- the breath and the cake colour are written at most 10 times a second
Ambience.CAKE_PERIOD = 8 -- seconds for the cake rim to go round the palette
-- Review follow-up: a real sway. The whole lollipop's decoration (stick and head, never its collision part) leans
-- side to side about the stick's foot, in the plane the disc faces; 3 degrees moves a grown head about 1.5 studs.
Ambience.SWAY_DEGREES = 3
Ambience.SWAY_PERIOD = 3.6

-- V3: a waterfall streak's drop below its top at time t: it slides down `span` studs at `speed` studs/s and starts
-- again at the top, offset by its phase (0..1 of the span). In [0, span); a bad input is 0 (the streak rests).
function Ambience.flowOffset(t, speed, span, phase)
	if not (finite(t) and finite(speed) and finite(span)) or span <= 0 then return 0 end
	return (t * speed + (finite(phase) and phase or 0) * span) % span
end

-- A small stable hash of a prop id (the same id always gets the same colour and phase).
local function hash(id)
	local h = 0
	for i = 1, #tostring(id) do
		h = (h * 31 + string.byte(tostring(id), i)) % 16777216
	end
	return h
end

-- colorName(kind, id) -> a PALETTE key: the kind's fixed colour, else one of PALETTE_ORDER chosen by the id.
function Ambience.colorName(kind, id)
	local spec = Ambience.KINDS[kind]
	local fixed = spec and ((spec.light and spec.light.color) or (spec.sparkle and spec.sparkle.color))
	if fixed then return fixed end
	return Ambience.PALETTE_ORDER[hash(id) % #Ambience.PALETTE_ORDER + 1]
end

function Ambience.color(kind, id)
	return Ambience.PALETTE[Ambience.colorName(kind, id)]
end

-- phase(id, period) -> a stable offset in [0, period), so neighbouring props never move in step.
function Ambience.phase(id, period)
	return (hash(id) % 1000) / 1000 * (finite(period) and period or 1)
end

-- The plot's rectangle from its floor part (centre and size), and the plot's own rectangle when the floor has not
-- streamed in. V8-D1 (owner request 2026-11-17, "the Caramelo map a bit bigger"): the plot is Layout CENTRE (672, -3) and
-- HALF 260, a copy here because clients cannot read the ServerStorage layout; BiomeLight's classic Meadow row is still
-- the v7 square, so it is only the sign that the module is there.
Ambience.PLOT_FALLBACK = table.freeze({ minX = 412, maxX = 932, minZ = -263, maxZ = 257 })
function Ambience.boundsFromFloor(x, z, sizeX, sizeZ)
	if not (finite(x) and finite(z) and finite(sizeX) and finite(sizeZ)) then return nil end
	return { minX = x - sizeX / 2, maxX = x + sizeX / 2, minZ = z - sizeZ / 2, maxZ = z + sizeZ / 2 }
end

function Ambience.fallbackBounds(BiomeLight)
	if type(BiomeLight) ~= "table" or type(BiomeLight.AREAS) ~= "table" or type(BiomeLight.TAG_PRESET) ~= "table" then
		return nil
	end
	for _, area in ipairs(BiomeLight.AREAS) do
		if BiomeLight.TAG_PRESET[area.tag] == "Caramelo" then
			local P = Ambience.PLOT_FALLBACK
			return { minX = P.minX, maxX = P.maxX, minZ = P.minZ, maxZ = P.maxZ }
		end
	end
	return nil
end

-- distanceOutside(bounds, x, z) -> 0 inside the rectangle, else the flat distance to it.
function Ambience.distanceOutside(bounds, x, z)
	if type(bounds) ~= "table" or not (finite(x) and finite(z)) then return math.huge end
	local dx = math.max(bounds.minX - x, 0, x - bounds.maxX)
	local dz = math.max(bounds.minZ - z, 0, z - bounds.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- inside(was, bounds, x, z) -> whether the ambience is on: it starts within ENTER_MARGIN of the plot and, once on, stops
-- only past LEAVE_MARGIN. A missing rectangle or a bad point is off.
function Ambience.inside(was, bounds, x, z)
	local d = Ambience.distanceOutside(bounds, x, z)
	if d == math.huge then return false end
	return d <= (was == true and Ambience.LEAVE_MARGIN or Ambience.ENTER_MARGIN)
end

-- pick(candidates, eye, limit, need) -> a new list of at most `limit` candidates ({ id, kind, x, y, z }) whose kind
-- has `need` ("light", "sparkle" or "sway"), within REACH[need] of the eye, nearest first by distance x the kind's
-- weight, ties by id. The input list is not changed.
function Ambience.pick(candidates, eye, limit, need)
	local out = {}
	if type(candidates) ~= "table" or type(eye) ~= "table" or not (finite(eye.x) and finite(eye.y) and finite(eye.z))
		or not finite(limit) or limit < 1 then
		return out
	end
	local reach = Ambience.REACH[need] or 0
	local scored = {}
	for _, item in ipairs(candidates) do
		local spec = type(item) == "table" and Ambience.KINDS[item.kind]
		if spec and spec[need] and finite(item.x) and finite(item.y) and finite(item.z) then
			local dx, dy, dz = item.x - eye.x, item.y - eye.y, item.z - eye.z
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if distance <= reach then
				table.insert(scored, { item = item, score = distance * (spec.weight or 1), id = tostring(item.id) })
			end
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then return a.score < b.score end
		return a.id < b.id
	end)
	for i = 1, math.min(math.floor(limit), #scored) do out[i] = scored[i].item end
	return out
end

-- rates(list, total) -> each entry's base `rate`, scaled down together so they sum to at most `total`.
function Ambience.rates(list, total)
	local out, sum = {}, 0
	for i, item in ipairs(list) do
		out[i] = finite(item.rate) and math.max(item.rate, 0) or 0
		sum += out[i]
	end
	total = finite(total) and math.max(total, 0) or 0
	local scale = sum > total and (sum > 0 and total / sum or 0) or 1
	for i = 1, #out do out[i] *= scale end
	return out
end

-- A light's slow breath: a brightness factor in [0.75, 1]. A bad time is steady.
function Ambience.pulse(t, phase)
	if not finite(t) then return 1 end
	return 0.875 + 0.125 * math.sin(2 * math.pi * (t + (finite(phase) and phase or 0)) / Ambience.PULSE_PERIOD)
end

-- A lollipop head's sway angle in radians, within SWAY_DEGREES. A bad time is at rest.
function Ambience.sway(t, phase)
	if not finite(t) then return 0 end
	return math.rad(Ambience.SWAY_DEGREES) * math.sin(2 * math.pi * (t + (finite(phase) and phase or 0)) / Ambience.SWAY_PERIOD)
end

-- The cake rim's colour at time t: round PALETTE_ORDER once per CAKE_PERIOD, blending between neighbours.
function Ambience.cakeColor(t, phase)
	local order = Ambience.PALETTE_ORDER
	local u = finite(t) and (((t + (finite(phase) and phase or 0)) / Ambience.CAKE_PERIOD) % 1) * #order or 0
	local index = math.floor(u)
	local frac = u - index
	local a, b = Ambience.PALETTE[order[index % #order + 1]], Ambience.PALETTE[order[(index + 1) % #order + 1]]
	return {
		math.round(a[1] + (b[1] - a[1]) * frac), math.round(a[2] + (b[2] - a[2]) * frac), math.round(a[3] + (b[3] - a[3]) * frac),
	}
end

-- thinAxis(sx, sy, sz) -> "X", "Y" or "Z": a disc's thinnest local axis, the one its face looks along.
function Ambience.thinAxis(sx, sy, sz)
	if sx <= sy and sx <= sz then return "X" end
	if sy <= sz then return "Y" end
	return "Z"
end

-- swayAxis(nx, ny, nz) -> the flat (x, z) unit axis a lollipop leans about: its disc's face normal laid flat, so the
-- head swings side to side in the plane it faces. nil when the normal is (nearly) vertical.
function Ambience.swayAxis(nx, ny, nz)
	if not (finite(nx) and finite(nz)) then return nil end
	local length = math.sqrt(nx * nx + nz * nz)
	if length < 0.1 then return nil end
	return nx / length, nz / length
end

-- nearEgg(x, z, eggs, radius) -> whether any egg ({ x, z }) is within radius of the point.
function Ambience.nearEgg(x, z, eggs, radius)
	if not (finite(x) and finite(z)) or type(eggs) ~= "table" then return false end
	for _, egg in ipairs(eggs) do
		if finite(egg.x) and finite(egg.z) and (egg.x - x) ^ 2 + (egg.z - z) ^ 2 <= radius * radius then return true end
	end
	return false
end

-- nestKind(hasEgg, anyEggsKnown, enabled) -> "eggNest" (glow and twinkle) or "nest" (glow). With no egg seen anywhere
-- (the client may not see them), every live nest twinkles.
function Ambience.nestKind(hasEgg, anyEggsKnown, enabled)
	if hasEgg == true then return "eggNest" end
	if anyEggsKnown ~= true and enabled == true then return "eggNest" end
	return "nest"
end

return freeze(Ambience)
