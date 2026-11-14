-- Golpe de Goma, Gomibu's single attack (odd/tasks/caramelo-bioma.md, T3; pack 03_PERSONAJES/01_GOMIBU.md): a short
-- jump that lands on a circle. Pure server rules: the caller passes the server time and flat positions and applies the
-- effects it gets back. Animations and their markers only show it; nothing here waits for them.
-- Timeline from Attack.start: 0.90 s of tell, the circle following the target until 0.55 s and fixed after that; a
-- 0.45 s arc to the circle; the hit, measured here at the landing; 0.70 s of recovery; then 5.5 s of cooldown.
-- A hit pushes 8 studs away from the centre and slows to x0.8 for 1 s. It never damages and never drops the egg.
-- Every number is the pack's starting proposal. Rules: WildboundCandyGomibuAttack_Test.
local Attack = {}
Attack.TELEGRAPH_SECONDS = 0.9
Attack.LOCK_SECONDS = 0.55
Attack.JUMP_SECONDS = 0.45
Attack.RECOVER_SECONDS = 0.7
Attack.COOLDOWN_SECONDS = 5.5
Attack.RADIUS_STUDS = 4.5
Attack.PUSH_STUDS = 8
Attack.SLOW_FACTOR = 0.8
Attack.SLOW_SECONDS = 1
Attack.MAX_JUMP_STUDS = 10 -- "salto corto": the circle never goes further than this from where Gomibu stands
Attack.ARC_HEIGHT_STUDS = 3 -- the Attack_Release clip rises this much
-- Server times are sums of floats: 100 + 0.9 + 0.45 is a hair over 101.35 and 100.55 - 100 a hair under 0.55. Every
-- boundary is reached this much early, so "at 0.55 s" means at 0.55 s (the first version missed its own deadlines).
local EPSILON = 1e-6

local function clamp(origin, target)
	local dx, dz = target.x - origin.x, target.z - origin.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance <= Attack.MAX_JUMP_STUDS then return { x = target.x, z = target.z } end
	local scale = Attack.MAX_JUMP_STUDS / distance
	return { x = origin.x + dx * scale, z = origin.z + dz * scale }
end

-- Starts an attack at server time now, from origin towards target ({ x, z }). creature.pet = true refuses: stored
-- pets are harmless. Returns the attack state, or nil and a reason.
function Attack.start(now, origin, target, creature)
	if type(creature) == "table" and creature.pet == true then return nil, "Pet" end
	return { startedAt = now, origin = { x = origin.x, z = origin.z }, centre = clamp(origin, target), resolved = false }
end

function Attack.locked(state, now) return now - state.startedAt >= Attack.LOCK_SECONDS - EPSILON end
function Attack.impactAt(state) return state.startedAt + Attack.TELEGRAPH_SECONDS + Attack.JUMP_SECONDS end
function Attack.endsAt(state) return Attack.impactAt(state) + Attack.RECOVER_SECONDS end

-- Lets the circle follow the target; does nothing once it is locked.
function Attack.aim(state, now, target)
	if not Attack.locked(state, now) then state.centre = clamp(state.origin, target) end
	return state.centre
end

function Attack.phase(state, now)
	local t = now - state.startedAt
	if t < Attack.TELEGRAPH_SECONDS - EPSILON then return "Telegraph" end
	if now < Attack.impactAt(state) - EPSILON then return "Jump" end
	if now < Attack.endsAt(state) - EPSILON then return "Recover" end
	return "Done"
end

-- Where Gomibu is at server time now: { x, y, z } with y the height over the ground. It stands still during the
-- tell, flies one arc to the locked centre and stays there.
function Attack.position(state, now)
	local progress = math.clamp((now - state.startedAt - Attack.TELEGRAPH_SECONDS) / Attack.JUMP_SECONDS, 0, 1)
	return { x = state.origin.x + (state.centre.x - state.origin.x) * progress, z = state.origin.z + (state.centre.z - state.origin.z) * progress,
		y = 4 * Attack.ARC_HEIGHT_STUDS * progress * (1 - progress) }
end

-- The hit, once, at or after the landing: every living player outside a safe zone within the radius of the centre.
-- players = { { id, x, z, alive, safe } ... }. Returns { { id, push = { x, z }, slowFactor, slowSeconds, damage, dropEgg } ... }.
function Attack.resolve(state, now, players)
	local effects = {}
	if state.resolved or now < Attack.impactAt(state) - EPSILON then return effects end
	state.resolved = true
	for _, p in ipairs(players) do
		if p.alive == true and p.safe ~= true then
			local dx, dz = p.x - state.centre.x, p.z - state.centre.z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance <= Attack.RADIUS_STUDS + EPSILON then
				if distance < 1e-6 then -- standing on the centre: push the way Gomibu was travelling
					dx, dz = state.centre.x - state.origin.x, state.centre.z - state.origin.z
					distance = math.sqrt(dx * dx + dz * dz)
					if distance < 1e-6 then dx, dz, distance = 1, 0, 1 end
				end
				table.insert(effects, { id = p.id, push = { x = dx / distance * Attack.PUSH_STUDS, z = dz / distance * Attack.PUSH_STUDS },
					slowFactor = Attack.SLOW_FACTOR, slowSeconds = Attack.SLOW_SECONDS, damage = 0, dropEgg = false })
			end
		end
	end
	return effects
end

-- Whether a new attack may start: never before the cooldown since the last one ended.
function Attack.canStart(lastEndedAt, now)
	return lastEndedAt == nil or now - lastEndedAt >= Attack.COOLDOWN_SECONDS - EPSILON
end

return Attack
