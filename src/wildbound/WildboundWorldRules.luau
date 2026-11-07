-- Pure server rules: no services, client state, wall clock, persistence or RNG.
local Rules = {}

Rules.CYCLE_SECONDS = 1200
Rules.REVEAL_SECONDS = 4
Rules.REVEAL_RANGE = 55
Rules.TELEGRAPH_SECONDS = 1.4
Rules.ATTACK_COOLDOWN = 4
Rules.ATTACK_RANGE = 7
Rules.HOME_X, Rules.HOME_Z = 0, -85
Rules.HOME_LEASH = 80
Rules.CHASE_RANGE = 65
Rules.MAX_CHASE_SECONDS = 10
Rules.DAMAGE = 20

function Rules.finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
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
	local phase, phaseStart, duration, clockStart, clockEnd
	if time < 600 then
		phase, phaseStart, duration, clockStart, clockEnd = "Day", 0, 600, 6, 18
	elseif time < 720 then
		phase, phaseStart, duration, clockStart, clockEnd = "Dusk", 600, 120, 18, 20
	elseif time < 1080 then
		phase, phaseStart, duration, clockStart, clockEnd = "Night", 720, 360, 20, 29
	else
		phase, phaseStart, duration, clockStart, clockEnd = "Dawn", 1080, 120, 5, 6
	end
	local progress = (time - phaseStart) / duration
	return {
		elapsed = time, phase = phase, progress = progress,
		remaining = duration - (time - phaseStart),
		clockTime = (clockStart + (clockEnd - clockStart) * progress) % 24,
	}
end

function Rules.zone(x, z)
	if not Rules.finite(x) or not Rules.finite(z) then return false, false end
	local safe = Rules.distance(x, z, -140, 140) <= 35 or Rules.distance(x, z, 105, 125) <= 22
	local fog = x >= -45 and x <= 165 and z >= -165 and z <= 35
	return fog, safe
end

function Rules.inTerritory(x, z)
	local fog, safe = Rules.zone(x, z)
	return fog and not safe and Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z) <= Rules.HOME_LEASH
end

function Rules.clampTerritory(x, z)
	if not Rules.finite(x) or not Rules.finite(z) then return Rules.HOME_X, Rules.HOME_Z end
	x, z = math.clamp(x, -45, 165), math.clamp(z, -165, 35)
	local distance = Rules.distance(x, z, Rules.HOME_X, Rules.HOME_Z)
	if distance > Rules.HOME_LEASH then
		local scale = Rules.HOME_LEASH / distance
		x = Rules.HOME_X + (x - Rules.HOME_X) * scale
		z = Rules.HOME_Z + (z - Rules.HOME_Z) * scale
	end
	return x, z
end

-- Profiles stay private and frozen; resolution returns a fresh, flat value each time.
-- Each creature declares its own night scope instead of inheriting a global boost.
local CREATURE_PROFILES = table.freeze({
	Silueta = table.freeze({
		name = "Silueta", specialBehaviorId = "Silueta", visualScale = 1.30,
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
		visualScale = profile.visualScale, speed = stats.speed, detectionRange = stats.detectionRange,
	}
end

function Rules.guardianParameters(phase, inFog)
	local profile = Rules.resolveCreatureProfile("Silueta", phase, inFog)
	return { speed = profile.speed, detectionRange = profile.detectionRange }
end

function Rules.validTarget(alive, x, z, guardianX, guardianZ, range)
	local fog, safe = Rules.zone(x, z)
	return alive == true and fog and not safe and Rules.inTerritory(x, z)
		and Rules.finite(range) and range >= 0
		and Rules.distance(x, z, guardianX, guardianZ) <= range
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
