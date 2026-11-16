-- Latigo de Regaliz, Don Glaseon's single attack (odd/tasks/wildbound-caramelo.md, CA3; pack
-- 03_PERSONAJES/04_DON_GLASEON_BOSS.md): the arm stretches into a rigid licorice whip and lashes a straight lane.
-- Pure server rules: the caller passes the server time and flat positions and applies the effects it gets back; the
-- animation and the licorice ribbon only show it.
-- DG1 (user, 2026-11-15; odd/tasks/wildbound-caramelo-v2.md): a combo of LASHES lashes, left lane, right lane, then
-- centre, three 22 x 5 lanes side by side, all drawn on the ground from the start. Timeline from Latigo.start: 0.80 s of
-- tell (jaw open, arm raised); at 0.35 s the lanes lock (the boss stops following the target); from 0.80 s the lashes
-- run back to back, 0.35 s each, and each hits at its end whoever stands in its own lane (impacts at 1.15, 1.50 and
-- 1.85 s: every lash lands at least 0.8 s after its lane appeared); 1.0 s of recovery; then 7 s of cooldown. Was one
-- lash: tell 1.10 s, lock 0.60 s.
-- A player is hit at most once per combo: an egg carrier drops the egg (the server's one drop path, BeastHit) and is
-- pushed 12 studs along the lash; anyone else is pushed 12 studs and slowed x0.85 for 0.7 s. No damage. The lash stays
-- the only attack of the boss that drops the egg. Stepping out of the three lanes after the lock, stepping into a lane
-- whose lash already landed, a perfect dodge in the last window, or cover dodges it.
-- Every number is the pack's starting proposal. Rules: WildboundCandyDonGlaseonAttack_Test.
local Latigo = {}
Latigo.TELEGRAPH_SECONDS = 0.8
Latigo.LOCK_SECONDS = 0.35
Latigo.RELEASE_SECONDS = 0.35 -- each lash
Latigo.LASHES = 3
-- Where each lash's lane sits, in lane widths to the boss's right: left, right, then centre.
Latigo.SIDES = table.freeze({ -1, 1, 0 })
Latigo.RECOVER_SECONDS = 1.0
Latigo.COOLDOWN_SECONDS = 7
Latigo.LENGTH_STUDS = 22
Latigo.WIDTH_STUDS = 5
Latigo.PUSH_STUDS = 12
Latigo.PUSH_SECONDS = 0.45
Latigo.SLOW_FACTOR = 0.85
Latigo.SLOW_SECONDS = 0.7
local EPSILON = 1e-6

local function unit(dx, dz)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-9 then return nil end
	return dx / length, dz / length
end

-- The lane of a boss standing on origin ({ x, y, z }) and facing (dx, dz): the shared lane shape (WildboundBeastConfig
-- shapeHit and the beast client's lane), from the boss's feet forward.
function Latigo.lane(origin, dx, dz)
	local ux, uz = unit(dx, dz)
	return { kind = "lane", ox = origin.x, oy = origin.y or 0, oz = origin.z, dx = ux or 0, dz = uz or -1,
		length = Latigo.LENGTH_STUDS, width = Latigo.WIDTH_STUDS }
end

-- DG1: the combo's lanes, in lash order (left, right, centre), side by side with no overlap. The boss's right for a
-- facing (dx, dz) is (-dz, dx).
function Latigo.lanes(origin, dx, dz)
	local list = {}
	for i, side in ipairs(Latigo.SIDES) do
		local lane = Latigo.lane(origin, dx, dz)
		local shift = side * Latigo.WIDTH_STUDS
		lane.ox, lane.oz = lane.ox - lane.dz * shift, lane.oz + lane.dx * shift
		list[i] = lane
	end
	return list
end

-- Whether a flat point lies inside the lane: the exact rectangle that is drawn.
function Latigo.inLane(lane, point)
	local rx, rz = point.x - lane.ox, point.z - lane.oz
	local along = rx * lane.dx + rz * lane.dz
	local across = math.abs(rx * -lane.dz + rz * lane.dx)
	return along >= -EPSILON and along <= lane.length + EPSILON and across <= lane.width / 2 + EPSILON
end

-- Starts a cast at server time now. creature.pet = true refuses: the farm version has no combat. Returns the cast
-- state, or nil and a reason.
function Latigo.start(now, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now, hit = {}, landed = {} }
end

function Latigo.lockAt(state) return state.startedAt + Latigo.LOCK_SECONDS end
-- The first lash's release; the others follow back to back.
function Latigo.releaseAt(state) return state.startedAt + Latigo.TELEGRAPH_SECONDS end
-- The end of lash i (default: the last one).
function Latigo.impactAt(state, i) return Latigo.releaseAt(state) + (i or Latigo.LASHES) * Latigo.RELEASE_SECONDS end
function Latigo.endsAt(state) return Latigo.impactAt(state) + Latigo.RECOVER_SECONDS end
-- How long a whole combo lasts, tell to the end of the recovery.
function Latigo.comboSeconds() return Latigo.TELEGRAPH_SECONDS + Latigo.LASHES * Latigo.RELEASE_SECONDS + Latigo.RECOVER_SECONDS end

function Latigo.phase(state, now)
	if now < Latigo.releaseAt(state) - EPSILON then return "Telegraph" end
	if now < Latigo.impactAt(state) - EPSILON then return "Attack" end
	if now < Latigo.endsAt(state) - EPSILON then return "Recover" end
	return "Done"
end

-- The impact of lash i (default 1): who stands in its lane at its end. Runs once per lash (a second call returns
-- nothing) and hits each player once per combo. players = { { id, x, z, alive, safe, carrying } ... }. Returns
-- { { id, push = { dx, dz, studs, seconds }, slowFactor, slowSeconds, damage, dropEgg } ... }; a carrier gets no slow
-- (the egg drop is the cost).
function Latigo.impact(state, lane, players, i)
	local effects = {}
	i = i or 1
	if state.landed[i] then return effects end
	state.landed[i] = true
	for _, p in ipairs(players) do
		if p.alive == true and p.safe ~= true and not state.hit[p.id] and Latigo.inLane(lane, p) then
			state.hit[p.id] = true
			local carrying = p.carrying == true
			table.insert(effects, { id = p.id, push = { dx = lane.dx, dz = lane.dz, studs = Latigo.PUSH_STUDS, seconds = Latigo.PUSH_SECONDS },
				slowFactor = not carrying and Latigo.SLOW_FACTOR or nil, slowSeconds = not carrying and Latigo.SLOW_SECONDS or nil,
				damage = 0, dropEgg = carrying })
		end
	end
	return effects
end

-- Whether a new cast may start: never before the cooldown since the last one ended.
function Latigo.canStart(lastEndedAt, now)
	return lastEndedAt == nil or now - lastEndedAt >= Latigo.COOLDOWN_SECONDS - EPSILON
end

return Latigo
