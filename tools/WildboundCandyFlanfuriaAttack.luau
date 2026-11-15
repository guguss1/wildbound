-- Onda de Caramelo, Flanfuria's single attack (odd/tasks/caramelo-bioma.md, T4; pack 03_PERSONAJES/02_FLANFURIA.md):
-- zone control. A ring of caramel grows out of the flan and a sticky puddle stays under it. Pure server rules: the
-- caller passes the server time and flat positions and applies the effects it gets back. Animations only show it.
-- Timeline from Attack.start: 1.00 s of tell (the flan stands still, the edge of radius 11 shows); 0.80 s of release,
-- the ring front growing from radius 2 to radius 11 at a steady pace; 0.85 s of recovery; then 8 s of cooldown.
-- The ring hits a player once per cast, at the moment its front passes them: slow x0.65 for 1.5 s. A player in the air
-- (jumping the front) is missed. When the release ends a puddle of radius 4 stays at the flan for 3 s and slows x0.8
-- while stood on. It never damages and never drops the egg.
-- In the game both slows are applied by the beast script's applySlow, which ignores a slow while another is live and
-- puts the speed back with a delayed task. So the puddle slow is a short pulse (PUDDLE_PULSE_SECONDS) repeated while
-- the player stands on it, and no slow of this attack may start until SLOW_GAP_SECONDS after the one before it has
-- ended: a slow landing on a speed not yet restored would stay. The caller keeps that gap (WildboundBeastFlanfuria).
-- Attack.Slows is a modifier table with expiries (one per source, the strongest wins, never multiplied, the base
-- speed never rewritten) for a server that owns the base speed; the beast script does not use it yet.
-- Every number is the pack's starting proposal. Rules: WildboundCandyFlanfuriaAttack_Test.
local Attack = {}
Attack.TELEGRAPH_SECONDS = 1.0
Attack.RELEASE_SECONDS = 0.8
Attack.RECOVER_SECONDS = 0.85
Attack.COOLDOWN_SECONDS = 8
Attack.RING_FROM_STUDS = 2
Attack.RING_TO_STUDS = 11
Attack.RING_SLOW_FACTOR = 0.65
Attack.RING_SLOW_SECONDS = 1.5
Attack.PUDDLE_RADIUS_STUDS = 4
Attack.PUDDLE_SECONDS = 3
Attack.PUDDLE_SLOW_FACTOR = 0.8
-- A puddle slow is one pulse of this length, repeated while the player stands in it; two slows of this attack on one
-- player are kept this far apart (see the header).
Attack.PUDDLE_PULSE_SECONDS = 0.6
Attack.SLOW_GAP_SECONDS = 0.15
Attack.PUDDLE_REPEAT_SECONDS = Attack.PUDDLE_PULSE_SECONDS + Attack.SLOW_GAP_SECONDS
-- Server times are sums of floats; every boundary is reached this much early so "at 1.00 s" means at 1.00 s.
local EPSILON = 1e-6

-- Starts a cast at server time now with the flan standing on origin ({ x, z }). creature.pet = true refuses: the farm
-- version has no combat. Returns the cast state, or nil and a reason.
function Attack.start(now, origin, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now, origin = { x = origin.x, z = origin.z }, swept = 0, hit = {}, last = {}, cancelled = false }
end

function Attack.releaseAt(state) return state.startedAt + Attack.TELEGRAPH_SECONDS end
function Attack.puddleAt(state) return Attack.releaseAt(state) + Attack.RELEASE_SECONDS end
function Attack.endsAt(state) return Attack.puddleAt(state) + Attack.RECOVER_SECONDS end
function Attack.puddleEndsAt(state) return Attack.puddleAt(state) + Attack.PUDDLE_SECONDS end

function Attack.phase(state, now)
	if now < Attack.releaseAt(state) - EPSILON then return "Telegraph" end
	if now < Attack.puddleAt(state) - EPSILON then return "Release" end
	if now < Attack.endsAt(state) - EPSILON then return "Recover" end
	return "Done"
end

-- The radius of the ring front at server time now, or nil when there is no ring (before the release, after it, or
-- once the cast was cancelled).
function Attack.ringRadius(state, now)
	if state.cancelled then return nil end
	local t = now - Attack.releaseAt(state)
	if t < -EPSILON or t > Attack.RELEASE_SECONDS + EPSILON then return nil end
	local progress = math.clamp(t / Attack.RELEASE_SECONDS, 0, 1)
	return Attack.RING_FROM_STUDS + (Attack.RING_TO_STUDS - Attack.RING_FROM_STUDS) * progress
end

-- Advances the ring to server time now and returns who its front passed since the last call: every living player
-- outside a safe zone and on the ground who was at or beyond the last front and is at or inside this one. Both ends
-- move between two calls, so the player's last distance is kept: somebody walking into the ring crosses the front
-- without ever standing in the thin band it swept. The first sweep starts at the flan itself, so nobody hides inside
-- the starting radius. Each player once per cast; crossing the front in the air is a miss for good.
-- players = { { id, x, z, alive, safe, airborne } ... }. Returns { { id, slowFactor, slowSeconds, damage, dropEgg } ... }.
function Attack.sweep(state, now, players)
	local effects = {}
	if state.cancelled or now < Attack.releaseAt(state) - EPSILON then return effects end
	local t = math.min(now - Attack.releaseAt(state), Attack.RELEASE_SECONDS)
	local front = Attack.RING_FROM_STUDS + (Attack.RING_TO_STUDS - Attack.RING_FROM_STUDS) * math.clamp(t / Attack.RELEASE_SECONDS, 0, 1)
	local from = state.swept
	if front <= from then return effects end
	state.swept = front
	for _, p in ipairs(players) do
		local dx, dz = p.x - state.origin.x, p.z - state.origin.z
		local distance = math.sqrt(dx * dx + dz * dz)
		local before = state.last[p.id] or distance
		state.last[p.id] = distance
		if p.alive == true and p.safe ~= true and p.airborne ~= true and not state.hit[p.id] then
			if math.max(before, distance) >= from - EPSILON and distance <= front + EPSILON then
				state.hit[p.id] = true
				table.insert(effects, { id = p.id, slowFactor = Attack.RING_SLOW_FACTOR, slowSeconds = Attack.RING_SLOW_SECONDS,
					damage = 0, dropEgg = false })
			end
		end
	end
	return effects
end

-- Whether the puddle lies on the ground at server time now.
function Attack.puddleActive(state, now)
	return not state.cancelled and now >= Attack.puddleAt(state) - EPSILON and now < Attack.puddleEndsAt(state) - EPSILON
end

-- Who stands in the puddle at server time now. Returns { { id, slowFactor, slowSeconds, damage, dropEgg } ... }: one
-- pulse each, which the caller repeats every PUDDLE_REPEAT_SECONDS while the player stays.
function Attack.puddle(state, now, players)
	local effects = {}
	if not Attack.puddleActive(state, now) then return effects end
	for _, p in ipairs(players) do
		if p.alive == true and p.safe ~= true and p.airborne ~= true then
			local dx, dz = p.x - state.origin.x, p.z - state.origin.z
			if math.sqrt(dx * dx + dz * dz) <= Attack.PUDDLE_RADIUS_STUDS + EPSILON then
				table.insert(effects, { id = p.id, slowFactor = Attack.PUDDLE_SLOW_FACTOR, slowSeconds = Attack.PUDDLE_PULSE_SECONDS,
					damage = 0, dropEgg = false })
			end
		end
	end
	return effects
end

-- Leaving combat: the ring and the puddle are gone at once.
function Attack.cancel(state) state.cancelled = true end

-- Whether a new cast may start: never before the cooldown since the last one ended. With an 8 s cooldown the old
-- puddle (gone 2.15 s after the cast ends) is always dry first: one puddle per Flanfuria at most.
function Attack.canStart(lastEndedAt, now)
	return lastEndedAt == nil or now - lastEndedAt >= Attack.COOLDOWN_SECONDS - EPSILON
end

-- Speed modifiers with an expiry. slows = Slows.new(); Slows.apply(slows, id, source, factor, untilAt) sets or renews
-- the one modifier of that source on that player; Slows.factor(slows, id, now) is the walk-speed multiplier to use
-- now: the strongest live modifier, 1 when none. The caller computes speed = base * factor each step and never stores
-- the slowed speed as the base.
local Slows = {}
function Slows.new() return {} end
function Slows.apply(slows, id, source, factor, untilAt)
	local mine = slows[id]
	if not mine then
		mine = {}
		slows[id] = mine
	end
	mine[source] = { factor = factor, untilAt = untilAt }
end
function Slows.factor(slows, id, now)
	local mine = slows[id]
	if not mine then return 1 end
	local factor, live = 1, false
	for source, modifier in pairs(mine) do
		if now >= modifier.untilAt - EPSILON then
			mine[source] = nil
		else
			live = true
			factor = math.min(factor, modifier.factor)
		end
	end
	if not live then slows[id] = nil end
	return factor
end
function Slows.clear(slows, id) slows[id] = nil end
Attack.Slows = Slows

return Attack
