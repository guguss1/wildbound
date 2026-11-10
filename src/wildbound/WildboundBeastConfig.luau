-- Nest Heist phase 4a (NB2, NB3): the beast pack's numbers and the attack geometry, in one shared module so the
-- server's hitboxes and the target client's telegraphs are computed from the same values. Pure: no services, no clock,
-- no random. Sources: docs/design/beast-pack/CONFIG_INICIAL.json, 01_VIPER.md, 02_POUNCER.md.
local Config = {}

-- Every attack's tell lasts at least this long (docs/mechanics/wildbound-fair-strike.md, the 0.8 s lead).
Config.MIN_TELL = 0.8

Config.DIRECTOR = table.freeze({
	TICK_SECONDS = 10, -- one independent roll per eligible beast and living player, every 10 s
	MAX_POINTS = 3, -- threat budget per player
	MAX_ACTIVE = 2, -- encounters at once per player
	MAX_CHANCE = 0.20, -- effective chance cap per beast and roll
	MAX_MULTIPLIER = 4, -- product cap of the condition multipliers
	GLOBAL_COOLDOWN = 15, -- seconds after any encounter of that player ends
	RESPAWN_GRACE = 10, -- no spawn this long after a respawn
	FAR_FROM_BASE = 150, -- studs from the camp centre that count as far from base
	LONG_EXPEDITION = 180, -- seconds continuously outside a safe zone that count as a long expedition
	MULTIPLIERS = table.freeze({ night = 2, farFromBase = 1.2, dangerousZone = 1.5, longExpedition = 1.3, storm = 1 }),
})

Config.BEASTS = table.freeze({
	Viper = table.freeze({
		points = 1, chance = 1 / 45, cooldown = 35, biome = nil, damage = 35,
		spawnMin = 35, spawnMax = 70, spawnSeconds = 0.75,
		stalkSeconds = 4, stalkSpeed = 14, attackMin = 18, attackMax = 30,
		clearSearch = 1.5, strafeSpeed = 7, -- in range but a trunk in the way: sidestep this long for a clear lane
		windup = 1.15, lockLead = 0.45, -- the lane follows the target for 0.7 s, then its angle is locked for 0.45 s
		laneLength = 32, laneWidth = 4.5, dashSpeed = 60, hitHeight = 5,
		recover = 1.25, recoverCrash = 1.8, maxAttacks = 3, maxSeconds = 32,
		escapeDistance = 100, escapeSeconds = 4, disengage = 0.9,
	}),
	Pouncer = table.freeze({
		points = 1, chance = 1 / 55, cooldown = 40, biome = nil, damage = 40,
		spawnMin = 35, spawnMax = 75, spawnSeconds = 0.8,
		huntSeconds = 5, huntSpeed = 16, attackMin = 20, attackMax = 34, predictSeconds = 0.3,
		telegraph = 1.3, freezeAfter = 0.25, radius = 6.5, flight = 0.75, arcHeight = 10, hitHeight = 6, maxStep = 12,
		recover = 1.2, jumps = 2, maxJumps = 3, maxSkips = 3, maxSeconds = 33,
		escapeDistance = 105, escapeSeconds = 4, disengage = 0.9,
	}),
	-- Config only: biome beasts stay off until Cementerio and Pantano exist (no zone carries those biomes yet).
	Gargoyle = table.freeze({ points = 2, chance = 1 / 100, cooldown = 60, biome = "Cemetery", damage = 25 }),
	Mire = table.freeze({ points = 2, chance = 1 / 80, cooldown = 50, biome = "Swamp", damage = 40 }),
})
Config.ORDER = table.freeze({ "Viper", "Pouncer", "Gargoyle", "Mire" })
-- Beasts that have an encounter behaviour. The director only starts these.
Config.PLAYABLE = table.freeze({ Viper = true, Pouncer = true })

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Config.finite = finite

-- A flat unit direction, or nil for a zero or broken vector.
function Config.unit(dx, dz)
	if not finite(dx) or not finite(dz) then return nil end
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then return nil end
	return dx / length, dz / length
end

function Config.flat(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Viper's red lane: a rectangle from the origin along the direction, `length` long and `width` wide. Returns the
-- centre and the yaw the client draws it with (a part whose length runs along its local -Z, the LookVector).
function Config.lane(ox, oz, dx, dz, length, width)
	return { cx = ox + dx * length / 2, cz = oz + dz * length / 2, yaw = math.atan2(-dx, -dz), length = length, width = width }
end

-- Whether a point lies inside the lane between `from` and `to` studs along it: the exact rectangle that is drawn.
function Config.inLane(px, pz, ox, oz, dx, dz, from, to, width)
	if not finite(px) or not finite(pz) then return false end
	local rx, rz = px - ox, pz - oz
	local along = rx * dx + rz * dz
	local across = math.abs(rx * -dz + rz * dx)
	return along >= from and along <= to and across <= width / 2
end

-- Pouncer's landing circle: the same radius is drawn and checked, by flat distance to the frozen centre.
function Config.inCircle(px, pz, cx, cz, radius)
	if not finite(px) or not finite(pz) then return false end
	return Config.flat(px, pz, cx, cz) <= radius
end

-- The leap: linear in plan, plus a 4*h*t*(1-t) arc. t is clamped to [0, 1].
function Config.arc(ax, ay, az, bx, by, bz, height, t)
	t = math.clamp(finite(t) and t or 0, 0, 1)
	return ax + (bx - ax) * t, ay + (by - ay) * t + 4 * height * t * (1 - t), az + (bz - az) * t
end

return Config
