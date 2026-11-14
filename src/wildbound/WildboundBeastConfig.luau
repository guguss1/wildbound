-- Nest Heist phase 4a (NB2, NB3): the beast pack's numbers and the attack geometry, in one shared module so the
-- server's hitboxes and the target client's telegraphs are computed from the same values. Pure: no services, no clock,
-- no random. Sources: docs/design/beast-pack/CONFIG_INICIAL.json, 01_VIPER.md, 02_POUNCER.md.
local Config = {}

-- Every attack's tell lasts at least this long (docs/mechanics/wildbound-fair-strike.md, the 0.8 s lead).
Config.MIN_TELL = 0.8

-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, owner decision 2026-11-11: the pack's numbers win). The roll moved from
-- every 10 s to every 20 s. Every base chance in this file was tuned per 10 s roll, so it is carried to the 20 s roll by
-- compounding two 10 s rolls: p20 = 1 - (1 - p10)^2. The per-second odds of every existing beast stay exactly what they
-- were (no retune); only the moment of the roll changes. The 10 s values stay visible as `chance10`.
Config.LEGACY_TICK_SECONDS = 10
local TICK_SECONDS = 20
function Config.perRoll(p10)
	if type(p10) ~= "number" or p10 ~= p10 then return 0 end
	p10 = math.clamp(p10, 0, 1)
	return 1 - (1 - p10) ^ (TICK_SECONDS / Config.LEGACY_TICK_SECONDS)
end

Config.DIRECTOR = table.freeze({
	-- Pack 01_SISTEMA_COMPARTIDO (owner decision): each beast rolls on a calendar, phase + k x 20 s, the beasts of one
	-- player 1 s apart (Config.ORDER), and a missed slot is never made up (no accumulated rolls).
	TICK_SECONDS = TICK_SECONDS,
	BEAST_OFFSET = 1,
	POLL_SECONDS = 0.25, -- how often the beast script asks the calendar which slots are due (not a roll interval)
	MAX_POINTS = 3, -- threat budget per player: the pack's DifficultyCapacityInitial 3
	MAX_ACTIVE = 2, -- encounters at once per player (owner decision 2 of the spawn design; configurable here)
	-- Risk (pack): the condition product below starts at INITIAL_RISK and is capped at MAX_MULTIPLIER. The pack's
	-- RiskMaximum is pending (owner); until it is set, MAX_MULTIPLIER is the cap.
	INITIAL_RISK = 1,
	-- Effective chance cap per beast and roll: 0.20 per 10 s roll, carried to the 20 s roll like every base chance.
	MAX_CHANCE = Config.perRoll(0.20),
	-- Anti-frustration (pack 05_MATRIZ_COMBINACIONES): two telegraphed strikes on one player never land closer than this.
	STRIKE_SEPARATION = 0.8,
	MAX_MULTIPLIER = 4, -- product cap of the condition multipliers
	GLOBAL_COOLDOWN = 15, -- seconds after any encounter of that player ends
	RESPAWN_GRACE = 10, -- no spawn this long after a respawn
	FAR_FROM_BASE = 150, -- studs from both the camp's and the hub's centre that count as far from base (HF-T5)
	LONG_EXPEDITION = 180, -- seconds continuously outside a safe zone that count as a long expedition
	-- egg (beast spawn design, owner decision 1, 2026-11-11): the soft Risk step while the player carries an egg. x1.2 is
	-- a tunable hypothesis ("around x1.2, to be tuned"); if the two-player test feels unfair, remove this step first. It
	-- multiplies with the rest, so MAX_MULTIPLIER and MAX_CHANCE still cap it.
	MULTIPLIERS = table.freeze({ night = 2, farFromBase = 1.2, dangerousZone = 1.5, longExpedition = 1.3, storm = 1,
		egg = 1.2 }),
	-- The context field that switches each multiplier on, when it is not the multiplier's own name.
	CONDITIONS = table.freeze({ egg = "carryingEgg" }),
})

-- Beast spawn design section 2: A "Guardian" (outside the budget, not run by the director today), B "Biome" (rolls only
-- inside its biome tag), C "Global" (anywhere except safe zones and the biomes below). riskModifier scales one beast's
-- base chance (1 = neutral; P0 sets every beast to 1, so nothing is retuned).
Config.CATEGORIES = table.freeze({ Guardian = true, Biome = true, Global = true })
-- Biome tags where no Global beast may appear (owner decision 3: Pradera Arcoiris has a no-damage rule). Safe zones are
-- excluded for every beast already. Nothing fills the "Meadow" tag until the P1 biome tags exist.
Config.NO_GLOBAL_BIOMES = table.freeze({ Meadow = true })

-- Wave 2: the base chance of the four new beasts. The pack gives none ("REVISAR_CONFIG_EXISTENTE"); the owner asked for
-- Viper's base chance (1/45 per 10 s roll, so 1 - (44/45)^2 = 89/2025, about 0.0440, per 20 s roll). PROPUESTA, open.
local VIPER_CHANCE10 = 1 / 45
-- Wave 2: the species cooldown of the four new beasts. The pack gives none; Viper's 35 s, PROPUESTA, open.
local VIPER_COOLDOWN = 35

Config.BEASTS = table.freeze({
	Viper = table.freeze({
		category = "Global", riskModifier = 1,
		points = 1, chance10 = VIPER_CHANCE10, chance = Config.perRoll(VIPER_CHANCE10), cooldown = 35, biome = nil, damage = 35,
		spawnMin = 35, spawnMax = 70, spawnSeconds = 0.75,
		stalkSeconds = 4, stalkSpeed = 14, attackMin = 18, attackMax = 30,
		clearSearch = 1.5, strafeSpeed = 7, -- in range but a trunk in the way: sidestep this long for a clear lane
		windup = 1.15, lockLead = 0.45, -- the lane follows the target for 0.7 s, then its angle is locked for 0.45 s
		laneLength = 32, laneWidth = 4.5, dashSpeed = 60, hitHeight = 5,
		recover = 1.25, recoverCrash = 1.8, maxAttacks = 3, maxSeconds = 32,
		escapeDistance = 100, escapeSeconds = 4, disengage = 0.9,
	}),
	Pouncer = table.freeze({
		category = "Global", riskModifier = 1,
		points = 1, chance10 = 1 / 55, chance = Config.perRoll(1 / 55), cooldown = 40, biome = nil, damage = 40,
		spawnMin = 35, spawnMax = 75, spawnSeconds = 0.8,
		huntSeconds = 5, huntSpeed = 16, attackMin = 20, attackMax = 34, predictSeconds = 0.3,
		telegraph = 1.3, freezeAfter = 0.25, radius = 6.5, flight = 0.75, arcHeight = 10, hitHeight = 6, maxStep = 12,
		recover = 1.2, jumps = 2, maxJumps = 3, maxSkips = 3, maxSeconds = 33,
		escapeDistance = 105, escapeSeconds = 4, disengage = 0.9,
	}),
	-- Config only: no behaviour yet, so the director never rolls them (Config.PLAYABLE), even inside their biome.
	Gargoyle = table.freeze({ category = "Biome", riskModifier = 1,
		points = 2, chance10 = 1 / 100, chance = Config.perRoll(1 / 100), cooldown = 60, biome = "Cemetery", damage = 25 }),
	Mire = table.freeze({ category = "Biome", riskModifier = 1,
		points = 2, chance10 = 1 / 80, chance = Config.perRoll(1 / 80), cooldown = 50, biome = "Swamp", damage = 40 }),

	-- Wave 2 (pack 02_BESTIAS/<X>/03_GUIA_MECANICAS.md). `tuning` is the pack's TuningProposal copied key by key:
	-- every value there is PROPUESTA DE BALANCE, to be tuned in Studio (a Python test keeps it equal to the pack JSON).
	-- The fields outside `tuning` that the pack does not give are marked PROPUESTA with where they come from.
	Streamer = table.freeze({
		category = "Global", riskModifier = 1, points = 2, biome = nil,
		chance10 = VIPER_CHANCE10, chance = Config.perRoll(VIPER_CHANCE10), -- PROPUESTA (Viper's, see above)
		cooldown = VIPER_COOLDOWN, -- PROPUESTA (Viper's)
		damage = 28, -- the rush (tuning.RushDamage); the scream's is tuning.ScreamDamage
		spawnMin = 35, spawnMax = 70, spawnSeconds = 0.75, -- PROPUESTA (Viper's spawn ring and rise)
		laneWidth = 4.5, hitHeight = 5, -- PROPUESTA (Viper's lane): the pack draws the rush lane "as wide as the hitbox"
		lockLead = 0.25, -- pack: the lane never changes in the last 0.25 s of the rush telegraph
		escapeDistance = 100, escapeSeconds = 4, disengage = 0.9, -- PROPUESTA (Viper's)
		tuning = table.freeze({ -- PROPUESTA DE BALANCE (pack TuningProposal)
			AggroRadiusStuds = 17, WarningSeconds = 1.0, ScreamWindupSeconds = 0.75, ScreamRadiusStuds = 10,
			ScreamDamage = 8, ScreamKnockbackStudsPerSecond = 19, WalkSpeedStudsPerSecond = 12,
			RushTelegraphSeconds = 0.9, RushSpeedStudsPerSecond = 52, RushMaxRangeStuds = 36, RushDamage = 28,
			RushCooldownSeconds = 4.7, RushMissRecoverySeconds = 1.2, PerfectDodgeStunSeconds = 2.1,
			EncounterTimeoutSeconds = 45,
		}),
	}),
	Root = table.freeze({
		category = "Biome", riskModifier = 1, points = 2, biome = "Swamp", -- pack: Root only in the Pantano
		chance10 = VIPER_CHANCE10, chance = Config.perRoll(VIPER_CHANCE10), -- PROPUESTA (Viper's)
		cooldown = VIPER_COOLDOWN, -- PROPUESTA (Viper's)
		damage = 22, -- the whip (tuning.WhipDamage); the trap's is tuning.TrapDamage
		spawnMin = 18, spawnMax = 30, -- PROPUESTA (derived: inside tuning.DetectionRadiusStuds 34)
		spawnSeconds = 1.0, -- PROPUESTA (the rise out of the mud before any tell)
		trapLanes = 3, trapSegments = 4, -- PROPUESTA (derived: 3 x 4 = tuning.MaxActiveRootSegments 12)
		trapSpread = 20, -- PROPUESTA: degrees between two lanes
		trapActiveSeconds = 0.5, -- pack: "ventana activa corta ~0.5 s"
		enclosureRadius = 9, -- PROPUESTA (derived: the gap, tuning.SafeGapMinimumStuds, fits the ring)
		whipRange = 16, -- PROPUESTA (derived: 2 x enclosureRadius - 2, so the gap side stays out of reach)
		whipDelay = 1.0, -- PROPUESTA: seconds of WallHold before the whip winds up
		hitHeight = 6, -- PROPUESTA (Pouncer's)
		escapeSeconds = 4, disengage = 0.9, -- PROPUESTA (Viper's); escape distance is tuning.DetectionRadiusStuds
		tuning = table.freeze({ -- PROPUESTA DE BALANCE (pack TuningProposal)
			DetectionRadiusStuds = 34, TrapTelegraphSeconds = 1.15, TrapLaneWidthStuds = 4, TrapDamage = 15,
			TrapSlowMultiplier = 0.76, TrapSlowSeconds = 1.5, WallTelegraphSeconds = 1.25, WallHoldSeconds = 3.2,
			SafeGapMinimumStuds = 9, WhipTelegraphSeconds = 0.85, WhipArcDegrees = 125, WhipDamage = 22,
			AttackCooldownSeconds = 3.5, MaxActiveRootSegments = 12, EncounterTimeoutSeconds = 48,
		}),
	}),
	Gaze = table.freeze({
		category = "Global", riskModifier = 1, points = 2, biome = nil,
		chance10 = VIPER_CHANCE10, chance = Config.perRoll(VIPER_CHANCE10), -- PROPUESTA (Viper's)
		cooldown = VIPER_COOLDOWN, -- PROPUESTA (Viper's)
		damage = 18, -- the zone (tuning.ZoneDamage)
		spawnMin = 32, spawnMax = 65, -- tuning.MinSpawnDistanceStuds, MaxSpawnDistanceStuds
		manifestSeconds = 2, -- PROPUESTA: "time to discover it before any exposure"
		dissipateSeconds = 1, -- PROPUESTA: the pause after a discharge before it watches again
		hitHeight = 6, -- PROPUESTA (Pouncer's)
		eyeHeight = 6.1, -- studs over its feet where the eyes are (the rig's Eye bones, assets/bestias_rig/gaze); the gaze cone aims there
		disengage = 0.9, -- PROPUESTA (Viper's)
		-- SightConeDegrees is read as the largest angle between the view and the line to Gaze (a half-angle).
		tuning = table.freeze({ -- PROPUESTA DE BALANCE (pack TuningProposal)
			MinSpawnDistanceStuds = 32, MaxSpawnDistanceStuds = 65, SightConeDegrees = 17, MaxViewDistanceStuds = 75,
			ExposureToAttackSeconds = 3.5, ExposureDecayPerSecond = 1.8, SightBreakGraceSeconds = 0.25,
			ZoneTelegraphSeconds = 1.25, ZoneRadiusStuds = 7, ZoneDamage = 18, DisengageIfUnseenSeconds = 6,
			EncounterTimeoutSeconds = 42, MaxScreenBlurSize = 4,
		}),
	}),
	Lurker = table.freeze({
		category = "Global", riskModifier = 1, points = 2, biome = nil,
		chance10 = VIPER_CHANCE10, chance = Config.perRoll(VIPER_CHANCE10), -- PROPUESTA (Viper's)
		cooldown = VIPER_COOLDOWN, -- PROPUESTA (Viper's)
		damage = 24, -- the leap (tuning.LeapDamage)
		presenceSeconds = 3, -- PROPUESTA: "primeros segundos sin ataque"
		observeCone = 35, -- PROPUESTA: half-angle of "in view" (a default 70 degree camera)
		observeHysteresis = 0.25, -- PROPUESTA (Gaze's SightBreakGraceSeconds reused): no flicker on small turns
		burstSeconds = 1.2, pauseSeconds = 0.4, -- PROPUESTA: the approach "en ráfagas con pequeñas pausas"
		leapRadius = 6.5, arcHeight = 6, hitHeight = 6, -- PROPUESTA (Pouncer's landing circle; a lower arc)
		escapeDistance = 100, escapeSeconds = 4, disengage = 0.9, -- PROPUESTA (Viper's)
		tuning = table.freeze({ -- PROPUESTA DE BALANCE (pack TuningProposal)
			InitialSpawnDistanceStuds = 44, ObservedPauseSeconds = 1.4, UnobservedApproachSpeedStudsPerSecond = 15,
			ObservedRetreatSpeedStudsPerSecond = 6, LeapMinDistanceStuds = 9, LeapMaxDistanceStuds = 21,
			LeapTelegraphSeconds = 0.8, LeapTravelSeconds = 0.55, LeapDamage = 24, LeapOverrunDistanceStuds = 7,
			PerfectDodgeStunSeconds = 1.8, LeapCooldownSeconds = 4.0, EncounterTimeoutSeconds = 50,
		}),
	}),
})
-- The calendar order: beast i rolls (i - 1) x BEAST_OFFSET seconds after the first, every TICK_SECONDS.
Config.ORDER = table.freeze({ "Viper", "Pouncer", "Gargoyle", "Mire", "Streamer", "Root", "Gaze", "Lurker" })
-- Beasts that have an encounter behaviour. The director only rolls and starts these.
Config.PLAYABLE = table.freeze({ Viper = true, Pouncer = true, Streamer = true, Root = true, Gaze = true, Lurker = true })
-- Wave 2 beasts run through a behaviour module registered with WildboundBeastEncounters (Enc.register).
Config.WAVE2 = table.freeze({ Streamer = true, Root = true, Gaze = true, Lurker = true })
-- The beasts that read the target's camera through the validated observation (WildboundBeastSight).
Config.OBSERVERS = table.freeze({ Gaze = true, Lurker = true })

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

-- Wave 2 shapes. The server checks hits and the client draws tells with the same tables, so what is drawn is the hit
-- volume. A shape is a plain table, sent as is over BeastEvent:
--   { kind = "circle", x, y, z, r }
--   { kind = "lane", ox, oy, oz, dx, dz, length, width }          (Config.lane / inLane)
--   { kind = "sector", x, y, z, dx, dz, r, arc }                  (arc: full opening in degrees, centred on dx, dz)
--   { kind = "multi", list = { shape, ... } }
--   { kind = "walls", x, y, z, r, gx, gz, gap, list = { {from, to}, ... } }  (blocks only, never hits: shapeHit false)

-- Whether a flat point lies inside a sector of radius r and full opening `arc` degrees around (dx, dz).
function Config.inSector(px, pz, cx, cz, dx, dz, r, arc)
	if not finite(px) or not finite(pz) or not finite(r) or not finite(arc) then return false end
	local rx, rz = px - cx, pz - cz
	local distance = math.sqrt(rx * rx + rz * rz)
	if distance > r then return false end
	if distance < 1e-6 then return true end
	local ux, uz = Config.unit(dx, dz)
	if not ux then return false end
	local cosine = math.clamp((rx * ux + rz * uz) / distance, -1, 1)
	return math.deg(math.acos(cosine)) <= arc / 2 + 1e-9
end

-- Whether a flat point is inside the hit volume of a shape. Walls never hit.
function Config.shapeHit(shape, px, pz)
	if type(shape) ~= "table" then return false end
	local kind = shape.kind
	if kind == "circle" then return Config.inCircle(px, pz, shape.x, shape.z, shape.r) end
	if kind == "lane" then
		return Config.inLane(px, pz, shape.ox, shape.oz, shape.dx, shape.dz, 0, shape.length, shape.width)
	end
	if kind == "sector" then return Config.inSector(px, pz, shape.x, shape.z, shape.dx, shape.dz, shape.r, shape.arc) end
	if kind == "multi" and type(shape.list) == "table" then
		for _, child in ipairs(shape.list) do
			if Config.shapeHit(child, px, pz) then return true end
		end
	end
	return false
end

-- Root's trap: `count` lanes from (ox, oz) toward (tx, tz), `spread` degrees apart around the middle one, each `width`
-- wide and as long as the target's distance plus a lane width (so the target's spot is covered), at most maxLength.
function Config.rootLanes(ox, oy, oz, tx, tz, count, spread, width, maxLength)
	local dx, dz = Config.unit(tx - ox, tz - oz)
	if not dx then return nil end
	local length = math.clamp(Config.flat(ox, oz, tx, tz) + width, width * 2, maxLength)
	local list = {}
	for i = 1, count do
		local angle = math.rad((i - (count + 1) / 2) * spread)
		local c, s = math.cos(angle), math.sin(angle)
		table.insert(list, { kind = "lane", ox = ox, oy = oy, oz = oz, dx = dx * c - dz * s, dz = dx * s + dz * c,
			length = length, width = width })
	end
	return { kind = "multi", list = list }
end

-- Root's enclosure: a ring of radius r around (x, z) with one gap `gap` studs wide centred on (gx, gz). Two walls meet
-- opposite the gap. Angles (radians) are measured from the gap direction. Returns nil when the gap cannot fit.
function Config.enclosure(x, y, z, gx, gz, r, gap)
	local ux, uz = Config.unit(gx, gz)
	if not ux or not finite(r) or not finite(gap) or r <= 0 or gap <= 0 or gap >= 2 * r then return nil end
	local half = math.asin(gap / (2 * r)) -- half the gap's opening angle
	return { kind = "walls", x = x, y = y, z = z, r = r, gx = ux, gz = uz, gap = gap,
		list = { { from = half, to = math.pi }, { from = math.pi, to = 2 * math.pi - half } } }
end

-- The chord between the two wall ends: the gap's real width (equal to `gap` by construction).
function Config.gapWidth(walls)
	if type(walls) ~= "table" or walls.kind ~= "walls" then return 0 end
	return 2 * walls.r * math.sin(walls.list[1].from)
end

return Config
