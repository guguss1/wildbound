-- Pure server rules: no services, client state, wall clock, persistence or RNG.
local Rules = {}

-- M5.7, D5: a 12-minute cycle with the old proportions (Day 50%, Dusk 10%, Night 30%, Dawn 10%). The
-- numbers match the "cycle" block of docs/mechanics/wildbound-economy-p0.md; a contract compares them.
local PHASES = table.freeze({
	table.freeze({ name = "Day", seconds = 360, clockStart = 6, clockEnd = 18 }),
	table.freeze({ name = "Dusk", seconds = 72, clockStart = 18, clockEnd = 20 }),
	table.freeze({ name = "Night", seconds = 216, clockStart = 20, clockEnd = 29 }),
	table.freeze({ name = "Dawn", seconds = 72, clockStart = 5, clockEnd = 6 }),
})
Rules.CYCLE_SECONDS = 720
Rules.REVEAL_SECONDS = 4
Rules.REVEAL_RANGE = 55
-- Chase pass (CP-D1): a 0.9 s telegraph (was 1.4) and a 2.5 s repeat (was 4). Still a full, standing wind-up with the
-- target's warning, above the 0.35 s floor of a readable tell; the fair-strike warning lead is 0.8 s.
Rules.TELEGRAPH_SECONDS = 0.9
Rules.ATTACK_COOLDOWN = 2.5
Rules.ATTACK_RANGE = 7
Rules.HOME_X, Rules.HOME_Z = 0, -85
Rules.HOME_LEASH = 80
-- The proximity cue and the awareness ally range; since the chase pass a hunt uses GIVE_UP_DISTANCE.
Rules.CHASE_RANGE = 65
-- Chase pass (CP-D2): a hunt keeps its quarry up to 100 studs away (beyond what the mist shows by day, 60 to 80, and
-- far beyond the night fog, about 39), and may follow it out of the territory up to 100 studs from home. A strike
-- still needs the target inside the territory (HOME_LEASH), so the pursuit leash never adds a place to be struck.
Rules.GIVE_UP_DISTANCE = 100
Rules.CHASE_LEASH = 100
-- The place's default SpawnLocation (12 x 12 at the origin) reaches one stud into the territory; its half diagonal
-- (8.49) rounded up is never a strike or acquisition point (CP-D3).
Rules.SPAWN_PAD_X, Rules.SPAWN_PAD_Z, Rules.SPAWN_PAD_RADIUS = 0, 0, 9
Rules.MAX_CHASE_SECONDS = 10
-- Look pass (user: "mucho más alto y tenebroso"): La Silueta's art scale, about 32.6 studs over the 8.57-stud
-- SiluetaV3 art (was 2.6, 22.3 studs). Art only: the gameplay body, sight, ATTACK_RANGE and the pathing agent never
-- read it. Tunable live (Silueta.VISUAL_SCALE); WildboundSiluetaVisual accepts 0.5 to 4.5.
Rules.SILUETA_VISUAL_SCALE = 3.8
-- Fix pass (FP2): one Silueta per player, at most this many on a server (the first eight players get one at once; a
-- later player takes a freed slot). Tunable live (Silueta.MAX_HUNTERS, 1 to 16).
Rules.MAX_HUNTERS = 8
Rules.DAMAGE = 20
-- Nest Heist hub (HB-T1): where the hub's centre is in this world, and the radius of its safe disc. This is the one
-- value the forest shift (docs/design/wildbound-open-world-gaps.md step S1) changes: the hub script builds there, the
-- camp link ends there and Rules.zone reads it. A translation only (the hub plan assumes no rotation). Until S1 the
-- hub is previewed 600 studs south of the forest's origin, on open ground.
Rules.HUB_X, Rules.HUB_Z, Rules.HUB_RADIUS = 0, 600, 90
-- The camp's safe circle (its centre is not the CampCenter marker, which sits 18 studs west of it); the hub link
-- starts inside it.
Rules.CAMP_X, Rules.CAMP_Z, Rules.CAMP_RADIUS = -140, 140, 35

function Rules.finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): the values above are the defaults the tests pin. The server's tuning
-- bridge may override these five at runtime; the territory (HOME_LEASH) and the strike range never change, so a
-- tuned chase never adds a place to be struck. No override, no change. The look pass adds the art scale (art only).
local TUNABLE = { "TELEGRAPH_SECONDS", "ATTACK_COOLDOWN", "GIVE_UP_DISTANCE", "CHASE_LEASH", "SILUETA_VISUAL_SCALE",
	"MAX_HUNTERS" }
local DEFAULTS = {}
for _, key in ipairs(TUNABLE) do DEFAULTS[key] = Rules[key] end
table.freeze(DEFAULTS)

function Rules.tunable()
	return table.clone(DEFAULTS)
end

-- overrides: { [field] = number }. Unknown keys and non-finite values are ignored; nil restores the defaults. The
-- chase leash never drops under the territory.
function Rules.tune(overrides)
	for key, value in pairs(DEFAULTS) do Rules[key] = value end
	if type(overrides) ~= "table" then return end
	for key, value in pairs(overrides) do
		if DEFAULTS[key] ~= nil and Rules.finite(value) then Rules[key] = value end
	end
	Rules.CHASE_LEASH = math.max(Rules.CHASE_LEASH, Rules.HOME_LEASH)
	Rules.MAX_HUNTERS = math.max(1, math.floor(Rules.MAX_HUNTERS + 0.5))
end

function Rules.distance(x1, z1, x2, z2)
	if not Rules.finite(x1) or not Rules.finite(z1) or not Rules.finite(x2) or not Rules.finite(z2) then
		return math.huge
	end
	return math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2)
end

function Rules.cycle(elapsed)
	if not Rules.finite(elapsed) or elapsed < 0 then elapsed = 0 end
	local time = elapsed % Rules.CYCLE_SECONDS
	local found = PHASES[#PHASES]
	local phaseStart = Rules.CYCLE_SECONDS - found.seconds
	local startedAt = 0
	for _, phase in ipairs(PHASES) do
		if time < startedAt + phase.seconds then
			found, phaseStart = phase, startedAt
			break
		end
		startedAt += phase.seconds
	end
	local duration = found.seconds
	local progress = (time - phaseStart) / duration
	return {
		elapsed = time, phase = found.name, progress = progress,
		remaining = duration - (time - phaseStart),
		clockTime = (found.clockStart + (found.clockEnd - found.clockStart) * progress) % 24,
	}
end

-- M5.7, D5: where in the cycle a new server starts. One roll in [0, 1), drawn once by the server, is
-- spread uniformly over the time that is not Night, so a session never opens in the dark. Anything that is
-- not a finite roll below one reads as the start of the cycle.
function Rules.startOffset(roll)
	if not Rules.finite(roll) or roll < 0 or roll >= 1 then roll = 0 end
	local open = 0
	for _, phase in ipairs(PHASES) do
		if phase.name ~= "Night" then open += phase.seconds end
	end
	local remaining, startedAt = roll * open, 0
	for _, phase in ipairs(PHASES) do
		if phase.name ~= "Night" then
			if remaining < phase.seconds then return startedAt + remaining end
			remaining -= phase.seconds
		end
		startedAt += phase.seconds
	end
	return 0
end

-- Random world (RW4): the wave clock's Refugios, safe circles that move each wave. The inventory server sets them and
-- every script that asks Rules.zone sees them (one module instance per server). A circle that would reach the
-- territory is refused, so a Refugio never takes away a place La Silueta may strike. Camp and shelter stay permanent.
local refugeList = {}
function Rules.setRefuges(list, radius)
	table.clear(refugeList)
	if type(list) ~= "table" then return end
	radius = Rules.finite(radius) and radius > 0 and radius or 12
	for _, refuge in ipairs(list) do
		if type(refuge) == "table" and type(refuge.id) == "string" and Rules.finite(refuge.x) and Rules.finite(refuge.z)
			and Rules.distance(refuge.x, refuge.z, Rules.HOME_X, Rules.HOME_Z) - radius > Rules.HOME_LEASH then
			table.insert(refugeList, table.freeze({ id = refuge.id, x = refuge.x, z = refuge.z, r = radius }))
		end
	end
end
function Rules.refuges()
	return table.clone(refugeList)
end
function Rules.refugeAt(x, z)
	if not Rules.finite(x) or not Rules.finite(z) then return nil end
	for _, refuge in ipairs(refugeList) do
		if Rules.distance(x, z, refuge.x, refuge.z) <= refuge.r then return refuge.id end
	end
	return nil
end

function Rules.zone(x, z)
	if not Rules.finite(x) or not Rules.finite(z) then return false, false end
	-- HB-T6: the hub disc is safe like the camp (no PvP, no beasts, no strikes, chases end).
	local safe = Rules.distance(x, z, Rules.CAMP_X, Rules.CAMP_Z) <= Rules.CAMP_RADIUS
		or Rules.distance(x, z, 105, 125) <= 22 or Rules.refugeAt(x, z) ~= nil
		or Rules.distance(x, z, Rules.HUB_X, Rules.HUB_Z) <= Rules.HUB_RADIUS
	local fog = x >= -45 and x <= 165 and z >= -165 and z <= 35
	return fog, safe
end

-- leash: optional, studs from home (default HOME_LEASH, the territory); the chase pass passes CHASE_LEASH while hunting.
local function leashOf(leash)
	return Rules.finite(leash) and leash > 0 and leash or Rules.HOME_LEASH
end

function Rules.inTerritory(x, z, leash)
	local fog, safe = Rules.zone(x, z)
	return fog and not safe and Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z) <= leashOf(leash)
end

function Rules.clampTerritory(x, z, leash)
	if not Rules.finite(x) or not Rules.finite(z) then return Rules.HOME_X, Rules.HOME_Z end
	leash = leashOf(leash)
	x, z = math.clamp(x, -45, 165), math.clamp(z, -165, 35)
	local distance = Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z)
	if distance > leash then
		local scale = leash / distance
		x = Rules.HOME_X + (x - Rules.HOME_X) * scale
		z = Rules.HOME_Z + (z - Rules.HOME_Z) * scale
	end
	return x, z
end

-- Profiles stay private and frozen; resolution returns a fresh, flat value each time.
-- Each creature declares its own night scope instead of inheriting a global boost.
local CREATURE_PROFILES = table.freeze({
	Silueta = table.freeze({
		-- Dread pass: 2.0 (was 1.30) makes the 8.57-stud SiluetaV3 art about 17 studs, three avatars tall. Art only:
		-- the gameplay body, sight, reach and pathing agent are unchanged, so the fair-strike rules hold as they were.
		-- Chase pass (CP-D4): 2.6, about 22.3 studs. Look pass: the scale is Rules.SILUETA_VISUAL_SCALE (3.8), tunable.
		name = "Silueta", specialBehaviorId = "Silueta", visualScaleKey = "SILUETA_VISUAL_SCALE",
		base = table.freeze({ speed = 6, detectionRange = 28 }),
		night = table.freeze({ scope = "Fog", speed = 8, detectionRange = 38 }),
	}),
})

function Rules.resolveCreatureProfile(name, phase, inFog)
	if type(name) ~= "string" then return nil end
	local profile = CREATURE_PROFILES[name]
	if not profile then return nil end
	local night = profile.night
	local applies = phase == "Night" and night.scope == "Fog" and inFog == true
	local stats = applies and night or profile.base
	return {
		name = profile.name, specialBehaviorId = profile.specialBehaviorId,
		visualScale = Rules[profile.visualScaleKey], speed = stats.speed, detectionRange = stats.detectionRange,
	}
end

function Rules.guardianParameters(phase, inFog)
	local profile = Rules.resolveCreatureProfile("Silueta", phase, inFog)
	return { speed = profile.speed, detectionRange = profile.detectionRange }
end

-- leash as in inTerritory: the default is the territory, used for acquisition and every strike check.
function Rules.validTarget(alive, x, z, guardianX, guardianZ, range, leash)
	local fog, safe = Rules.zone(x, z)
	return alive == true and fog and not safe and Rules.inTerritory(x, z, leash)
		and Rules.distance(x, z, Rules.SPAWN_PAD_X, Rules.SPAWN_PAD_Z) > Rules.SPAWN_PAD_RADIUS
		and Rules.finite(range) and range >= 0
		and Rules.distance(x, z, guardianX, guardianZ) <= range
end

-- Memory fix (2026-11-09): whether a hunt keeps its quarry this step. observation = { alive, hidden, visible, distance }
-- where visible is legal sight (validTarget, same floor, nothing between) and distance is flat studs to the guardian.
-- Only a gone quarry, one that hid unseen, or one beyond the give-up distance ends the chase; anything else that is not
-- legal sight (cover, the spawn pad, the fog edge, the pursuit leash, another floor) only reads as out of sight, so the
-- phase's memory runs before the search. Fix pass (FP3): the chase also ends at once when the quarry stands in a safe
-- zone (observation.safe, camp or a shelter) or past the pursuit leash from home (observation.homeDistance beyond
-- CHASE_LEASH; a missing or unreadable homeDistance reads as inside).
function Rules.pursuit(observation)
	if type(observation) ~= "table" or observation.alive ~= true then return false end
	if observation.safe == true then return false end
	local home = observation.homeDistance
	if Rules.finite(home) and home > Rules.CHASE_LEASH then return false end
	if observation.hidden == true and observation.visible ~= true then return false end
	local distance = observation.distance
	return Rules.finite(distance) and distance >= 0 and distance <= Rules.GIVE_UP_DISTANCE
end

function Rules.canStrike(now, telegraphEndsAt, lastAttackAt, distance, alive, safe, visible)
	return Rules.finite(now) and Rules.finite(telegraphEndsAt) and telegraphEndsAt > 0
		and Rules.finite(lastAttackAt) and now >= telegraphEndsAt
		and now - lastAttackAt >= Rules.ATTACK_COOLDOWN
		and Rules.finite(distance) and distance >= 0 and distance <= Rules.ATTACK_RANGE
		and alive == true and safe == false and visible == true
end

-- M2.2: the proximity cue for one player. A guardian that is retreating is not a threat, so the
-- cue never outlives the hunt. It is a presentation cue only and must never gate a strike.
function Rules.isThreat(mode, alive, inFog, safe, distance)
	return type(mode) == "string" and mode ~= "Retreat" and alive == true and inFog == true and safe ~= true
		and Rules.finite(distance) and distance >= 0 and distance <= Rules.CHASE_RANGE
end

-- M2.3: the ground disc under Silueta. While any player is seen it turns amber and also grows and
-- becomes more solid, so colour is not the only cue. Values are hypotheses.
local DISC = table.freeze({
	idle = table.freeze({ r = 177, g = 201, b = 180, transparency = 0.35, diameter = 5.5 }),
	seen = table.freeze({ r = 240, g = 183, b = 92, transparency = 0.05, diameter = 7.5 }),
})

function Rules.groundCue(seen)
	local source = seen == true and DISC.seen or DISC.idle
	return { r = source.r, g = source.g, b = source.b, transparency = source.transparency, diameter = source.diameter }
end

-- One non-yielding decision consumes only an authorized action's cooldown.
-- A valid use may miss; range/LOS/facing determine reveal, never client-supplied IDs.
function Rules.tryAbility(cooldowns, action, now, context)
	if action ~= "Flashlight" and action ~= "LumipolPulse" then return false, "InvalidAction", false end
	if not Rules.finite(now) or now < 0 or type(context) ~= "table" or context.alive ~= true then
		return false, "InvalidContext", false
	end
	if action == "LumipolPulse" and context.eligible ~= true then return false, "NotEquipped", false end
	local readyAt = cooldowns[action]
	if not Rules.finite(readyAt) or readyAt < 0 then readyAt = 0 end
	if now < readyAt then return false, "Cooldown", false end
	cooldowns[action] = now + (action == "Flashlight" and 12 or 30)
	local distance = context.distance
	local hit = Rules.finite(distance) and distance >= 0 and distance <= Rules.REVEAL_RANGE
		and context.visible == true and (action == "LumipolPulse" or context.facing == true)
	return true, hit and "Revealed" or "Miss", hit
end

return Rules
