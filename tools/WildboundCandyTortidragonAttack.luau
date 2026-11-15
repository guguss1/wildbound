-- Abanico de Confites, Tortidragon's single attack (odd/tasks/wildbound-caramelo.md, CA2; pack
-- 03_PERSONAJES/03_TORTIDRAGON.md): three big candy shots in a frontal fan. Pure server rules: the caller passes the
-- server time and flat positions and applies the effects it gets back; animations and the flying candies only show it.
-- Timeline from Abanico.start: 1.00 s of aim (cheeks puff, a 55-degree fan of 12 studs shows in front); at 0.60 s the
-- direction locks and three small circles (radius 2.3) appear along it; at 1.00 s the shots fly for 0.65 s and land
-- on the circles (the impact, the only moment anybody is hit); 0.85 s of recovery; then 7 s of cooldown.
-- A player inside one or more circles at the impact is hit once (never three times): a light push away from the
-- dragon and a short stagger (slow x0.85 for 0.8 s). No damage, and the carried egg stays.
-- It never casts at a target behind it or outside the fan: stepping out of the fan sideways, after the lock, dodges it.
-- Every number is the pack's starting proposal. Rules: WildboundCandyTortidragonAttack_Test.
local Abanico = {}
Abanico.TELEGRAPH_SECONDS = 1.0
Abanico.LOCK_SECONDS = 0.6
Abanico.RELEASE_SECONDS = 0.65
Abanico.RECOVER_SECONDS = 0.85
Abanico.COOLDOWN_SECONDS = 7
Abanico.ARC_DEGREES = 55
Abanico.RANGE_STUDS = 12
Abanico.SHOTS = 3
Abanico.SHOT_RADIUS_STUDS = 2.3
-- The side shots fly this far off the middle one (inside the fan's 27.5-degree half arc).
Abanico.SPREAD_DEGREES = 20
-- The shots land at the target's distance, never nearer than this nor past the fan's edge.
Abanico.MIN_SHOT_STUDS = 4
Abanico.PUSH_STUDS = 4
Abanico.PUSH_SECONDS = 0.3
Abanico.SLOW_FACTOR = 0.85
Abanico.SLOW_SECONDS = 0.8
local EPSILON = 1e-6

local function unit(dx, dz)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-9 then return nil end
	return dx / length, dz / length
end

-- Whether a flat point is inside the fan of a dragon standing on origin ({ x, z }) and facing (dx, dz).
function Abanico.inFan(origin, dx, dz, point)
	local rx, rz = point.x - origin.x, point.z - origin.z
	local distance = math.sqrt(rx * rx + rz * rz)
	if distance > Abanico.RANGE_STUDS + EPSILON then return false end
	if distance < EPSILON then return true end
	local ux, uz = unit(dx, dz)
	if not ux then return false end
	local cosine = math.clamp((rx * ux + rz * uz) / distance, -1, 1)
	return math.deg(math.acos(cosine)) <= Abanico.ARC_DEGREES / 2 + EPSILON
end

-- A cast may start only at a target inside the fan the dragon faces now: never at one behind it or to its side.
function Abanico.canCast(origin, dx, dz, target)
	return Abanico.inFan(origin, dx, dz, target)
end

-- The aim the client draws during the tell: the fan as a sector (the shared shape kind; arc in degrees).
function Abanico.fan(origin, dx, dz)
	local ux, uz = unit(dx, dz)
	return { kind = "sector", x = origin.x, y = origin.y or 0, z = origin.z, dx = ux or 0, dz = uz or -1, r = Abanico.RANGE_STUDS,
		arc = Abanico.ARC_DEGREES }
end

-- The three landing circles for a locked direction and the target's distance then: the middle one on the direction,
-- the side ones SPREAD_DEGREES off it, all at the same distance (clamped so every circle stays inside the fan).
function Abanico.shots(origin, dx, dz, distance)
	local ux, uz = unit(dx, dz)
	ux, uz = ux or 0, uz or -1
	local d = math.clamp(distance or Abanico.RANGE_STUDS, Abanico.MIN_SHOT_STUDS, Abanico.RANGE_STUDS - Abanico.SHOT_RADIUS_STUDS)
	local list = {}
	for i = 1, Abanico.SHOTS do
		local angle = math.rad((i - (Abanico.SHOTS + 1) / 2) * Abanico.SPREAD_DEGREES)
		local c, s = math.cos(angle), math.sin(angle)
		local rx, rz = ux * c - uz * s, ux * s + uz * c
		table.insert(list, { kind = "circle", x = origin.x + rx * d, y = origin.y or 0, z = origin.z + rz * d, r = Abanico.SHOT_RADIUS_STUDS })
	end
	return { kind = "multi", list = list }
end

-- Starts a cast at server time now. creature.pet = true refuses: the farm version has no combat. Returns the cast
-- state, or nil and a reason.
function Abanico.start(now, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now, hit = {}, landed = false }
end

function Abanico.lockAt(state) return state.startedAt + Abanico.LOCK_SECONDS end
function Abanico.releaseAt(state) return state.startedAt + Abanico.TELEGRAPH_SECONDS end
function Abanico.impactAt(state) return Abanico.releaseAt(state) + Abanico.RELEASE_SECONDS end
function Abanico.endsAt(state) return Abanico.impactAt(state) + Abanico.RECOVER_SECONDS end

function Abanico.phase(state, now)
	if now < Abanico.releaseAt(state) - EPSILON then return "Telegraph" end
	if now < Abanico.impactAt(state) - EPSILON then return "Release" end
	if now < Abanico.endsAt(state) - EPSILON then return "Recover" end
	return "Done"
end

local function inside(shots, p)
	for _, c in ipairs(shots.list) do
		local dx, dz = p.x - c.x, p.z - c.z
		if dx * dx + dz * dz <= (c.r + EPSILON) ^ 2 then return true end
	end
	return false
end

-- The impact: who stands in any circle when the shots land. Runs once per cast (a second call returns nothing) and
-- hits each player once however many circles they stand in. origin is where the dragon stood (the push goes away from
-- it). players = { { id, x, z, alive, safe } ... }. Returns { { id, push = { dx, dz, studs, seconds },
-- slowFactor, slowSeconds, damage, dropEgg } ... }.
function Abanico.impact(state, shots, origin, players)
	local effects = {}
	if state.landed then return effects end
	state.landed = true
	for _, p in ipairs(players) do
		if p.alive == true and p.safe ~= true and not state.hit[p.id] and inside(shots, p) then
			state.hit[p.id] = true
			local ux, uz = unit(p.x - origin.x, p.z - origin.z)
			table.insert(effects, { id = p.id, push = { dx = ux or 0, dz = uz or -1, studs = Abanico.PUSH_STUDS, seconds = Abanico.PUSH_SECONDS },
				slowFactor = Abanico.SLOW_FACTOR, slowSeconds = Abanico.SLOW_SECONDS, damage = 0, dropEgg = false })
		end
	end
	return effects
end

-- Whether a new cast may start: never before the cooldown since the last one ended.
function Abanico.canStart(lastEndedAt, now)
	return lastEndedAt == nil or now - lastEndedAt >= Abanico.COOLDOWN_SECONDS - EPSILON
end

return Abanico
