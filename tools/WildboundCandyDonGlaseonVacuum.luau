-- Boca aspiradora, Don Glaseon's vacuum mouth (odd/tasks/wildbound-caramelo-v2.md, DG2; user decision 2026-11-15).
-- Pure server rules: the caller passes the server time and flat positions and sends the pulls it gets back; the target's
-- own client moves its character (it owns its physics), so a player can run against the pull or hide behind cover.
-- Timeline from Vacuum.start: 0.9 s of tell (he opens his mouth; a fixed 70-degree cone of 30 studs shows in front);
-- then 2 s of pull; 0.6 s of recovery; then 12 s of cooldown. During the pull every target in the cone, with a clear
-- line to him and more than STOP_STUDS away, is pulled toward him at PULL_SPEED (a walking player, 16, still wins).
-- He uses it only on a target that stayed out of the lash's reach for CHASE_BEFORE_SECONDS (WildboundBeastDonGlaseon).
-- No hit, no damage, never the egg: the lash stays his only egg-drop attack.
-- Every number is a starting proposal to tune in play. Rules: WildboundCandyDonGlaseonVacuum_Test.
local Vacuum = {}
Vacuum.TELEGRAPH_SECONDS = 0.9
Vacuum.PULL_SECONDS = 2
Vacuum.RECOVER_SECONDS = 0.6
Vacuum.COOLDOWN_SECONDS = 12
Vacuum.RANGE_STUDS = 30
Vacuum.ARC_DEGREES = 70
Vacuum.PULL_SPEED = 7 -- studs per second toward his mouth
Vacuum.STOP_STUDS = 5 -- no pull closer than this
Vacuum.CHASE_BEFORE_SECONDS = 2
-- The server re-sends a pull every REFRESH_SECONDS; each one is valid PULL_HOLD_SECONDS, so the pull stops within a
-- moment of the target leaving the cone or breaking the line of sight.
Vacuum.REFRESH_SECONDS = 0.25
Vacuum.PULL_HOLD_SECONDS = 0.35
local EPSILON = 1e-6

local function unit(dx, dz)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-9 then return nil end
	return dx / length, dz / length
end

function Vacuum.start(now, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now }
end

function Vacuum.pullAt(state) return state.startedAt + Vacuum.TELEGRAPH_SECONDS end
function Vacuum.pullEndsAt(state) return Vacuum.pullAt(state) + Vacuum.PULL_SECONDS end
function Vacuum.endsAt(state) return Vacuum.pullEndsAt(state) + Vacuum.RECOVER_SECONDS end
function Vacuum.totalSeconds() return Vacuum.TELEGRAPH_SECONDS + Vacuum.PULL_SECONDS + Vacuum.RECOVER_SECONDS end

function Vacuum.phase(state, now)
	if now < Vacuum.pullAt(state) - EPSILON then return "Inhale" end
	if now < Vacuum.pullEndsAt(state) - EPSILON then return "Vacuum" end
	if now < Vacuum.endsAt(state) - EPSILON then return "Recover" end
	return "Done"
end

-- The cone the client draws: the shared sector shape (arc in degrees), from his feet along his facing.
function Vacuum.cone(origin, dx, dz)
	local ux, uz = unit(dx, dz)
	return { kind = "sector", x = origin.x, y = origin.y or 0, z = origin.z, dx = ux or 0, dz = uz or 1, r = Vacuum.RANGE_STUDS,
		arc = Vacuum.ARC_DEGREES }
end

-- Whether a flat point is inside the cone of a boss standing on origin and facing (dx, dz).
function Vacuum.inCone(origin, dx, dz, point)
	local rx, rz = point.x - origin.x, point.z - origin.z
	local distance = math.sqrt(rx * rx + rz * rz)
	if distance > Vacuum.RANGE_STUDS + EPSILON then return false end
	if distance < EPSILON then return true end
	local ux, uz = unit(dx, dz)
	if not ux then return false end
	local cosine = math.clamp((rx * ux + rz * uz) / distance, -1, 1)
	return math.deg(math.acos(cosine)) <= Vacuum.ARC_DEGREES / 2 + EPSILON
end

-- The pull on a target at server time now, or nil: only in the Vacuum phase, on a living target outside a safe zone,
-- inside the cone, with a clear line to him (clear == true) and more than STOP_STUDS away. Returns
-- { dx, dz (a unit direction toward him), speed, untilAt }. Never a damage or an egg drop.
function Vacuum.pull(state, now, origin, dx, dz, target, clear)
	if Vacuum.phase(state, now) ~= "Vacuum" then return nil end
	if not target or target.alive ~= true or target.safe == true or clear ~= true then return nil end
	if not Vacuum.inCone(origin, dx, dz, target) then return nil end
	local tx, tz = origin.x - target.x, origin.z - target.z
	if math.sqrt(tx * tx + tz * tz) <= Vacuum.STOP_STUDS + EPSILON then return nil end
	local ux, uz = unit(tx, tz)
	return { dx = ux, dz = uz, speed = Vacuum.PULL_SPEED,
		untilAt = math.min(now + Vacuum.PULL_HOLD_SECONDS, Vacuum.pullEndsAt(state)) }
end

-- Whether a new vacuum may start: never before the cooldown since the last one ended.
function Vacuum.canStart(lastEndedAt, now)
	return lastEndedAt == nil or now - lastEndedAt >= Vacuum.COOLDOWN_SECONDS - EPSILON
end

return Vacuum
