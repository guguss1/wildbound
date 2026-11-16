-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG7 Torta trampa): three decoy cakes on the routes a thief must
-- use (the tower stair entrance, the main path to the Gran Torta, beside a rare nest). Each holds a slice anyone may
-- bite once per round: a short sugar rush (x1.25 walk, capped). While Don Glaseon sleeps, one of the three is him in
-- disguise: it breathes slightly and drops a crumb now and then (the readable tell). A player within SPRING_STUDS, or
-- one biting it, springs it: a 0.8 s tell, then a lash pushes everyone within LASH_STUDS away (no damage, the egg
-- stays), and the decoys pop until they grow back. He never does it while awake (any encounter, so never in a chase):
-- waking unmasks the disguise, and it re-arms REARM_SECONDS after he sleeps again. Pure: no services, no clock, no
-- random (the server passes `pick(n)`, its own roll of 1..n). WildboundCandyTrapCakeService runs it.
local Trap = {}

-- Local to the Candy layout's centre (WildboundCandyLayout.CENTRE). stair: just outside the bottom tier on the south
-- side, where the CT1 stair starts; path: the edge of the main route between the fork and the plaza; rareNest: beside
-- nest R1 (Rara), on the side away from Flanfuria's post.
Trap.SPOTS = table.freeze({
	table.freeze({ key = "stair", x = 6, z = -33 }),
	table.freeze({ key = "path", x = -60, z = 8 }),
	table.freeze({ key = "rareNest", x = -86, z = -21, nest = "R1" }),
})
Trap.SPRING_STUDS = 5
Trap.PROMPT_STUDS = 8
Trap.TELL_SECONDS = 0.8
Trap.LASH_STUDS = 9
Trap.PUSH_STUDS = 12
Trap.PUSH_SECONDS = 0.4
Trap.POP_SECONDS = 0.7
Trap.REGROW_SECONDS = 90
Trap.REARM_SECONDS = 30
Trap.RUSH_SECONDS = 5
Trap.RUSH_SCALE = 1.25
Trap.RUSH_CAP = 26
Trap.BREATH_SECONDS = 2.4
Trap.BREATH_SCALE = 0.04
Trap.CRUMB_RATE = 0.7
Trap.SCALE = 0.07 -- the kit's CakeTower at this scale: about 5 studs wide, 4.6 high
-- Player-facing words (DG7-D6: here until WildboundText is free to edit).
Trap.TEXT = table.freeze({ prompt = "Comer porción", object = "Torta" })

local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end

function Trap.spotsWorld(centre)
	local out = {}
	for i, spot in ipairs(Trap.SPOTS) do out[i] = { key = spot.key, x = centre.x + spot.x, z = centre.z + spot.z } end
	return out
end

function Trap.new(now, pick)
	return { status = "Ready", round = 1, trapIndex = pick(#Trap.SPOTS), armAt = now, eaten = {} }
end

-- Whether one decoy is him right now.
function Trap.disguised(state, awake, now)
	return state.status == "Ready" and state.trapIndex ~= nil and awake ~= true and state.armAt ~= nil and now >= state.armAt
end

local function spring(state, now, by)
	state.status, state.lashAt, state.popAt, state.lashed = "Springing", now + Trap.TELL_SECONDS,
		now + Trap.TELL_SECONDS + Trap.POP_SECONDS, false
	state.springIndex = state.trapIndex
	return { kind = "Spring", at = now, by = by, index = state.trapIndex, lashAt = state.lashAt }
end

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end

-- One server step. players = { { id, x, z, alive, safe } } (world), spots = Trap.spotsWorld(...). Returns the events:
-- Unmasked, Armed, Spring { by, index, lashAt }, Lash { index, pushes = { { id, dx, dz, studs, seconds } } }, Pop,
-- Regrow.
function Trap.step(state, now, awake, players, pick, spots)
	local events = {}
	if state.status == "Springing" then
		if not state.lashed and now >= state.lashAt then
			state.lashed = true
			local spot, pushes = spots[state.springIndex], {}
			for _, p in ipairs(players) do
				if p.alive == true and p.safe ~= true and finite(p.x) and finite(p.z)
					and flat(p.x, p.z, spot.x, spot.z) <= Trap.LASH_STUDS then
					local dx, dz = p.x - spot.x, p.z - spot.z
					local length = math.sqrt(dx * dx + dz * dz)
					if length < 1e-3 then dx, dz, length = 1, 0, 1 end
					table.insert(pushes, { id = p.id, dx = dx / length, dz = dz / length, studs = Trap.PUSH_STUDS,
						seconds = Trap.PUSH_SECONDS })
				end
			end
			table.insert(events, { kind = "Lash", at = state.lashAt, index = state.springIndex, pushes = pushes })
		end
		if now >= state.popAt then
			state.status, state.regrowAt, state.trapIndex = "Popped", state.popAt + Trap.REGROW_SECONDS, nil
			table.insert(events, { kind = "Pop", at = state.popAt, index = state.springIndex })
		end
		return events
	end
	if state.status == "Popped" then
		if now < state.regrowAt then return events end
		state.status, state.round, state.eaten, state.trapIndex, state.armAt = "Ready", state.round + 1, {}, nil, now
		table.insert(events, { kind = "Regrow", at = now })
	end
	-- Ready
	if awake == true then
		if state.trapIndex then table.insert(events, { kind = "Unmasked", at = now }) end
		state.trapIndex, state.armAt = nil, nil
		return events
	end
	if state.trapIndex == nil then
		state.armAt = state.armAt or now + Trap.REARM_SECONDS
		if now < state.armAt then return events end
		state.trapIndex = pick(#Trap.SPOTS)
		table.insert(events, { kind = "Armed", at = now, index = state.trapIndex })
	end
	if Trap.disguised(state, awake, now) then
		local spot = spots[state.trapIndex]
		for _, p in ipairs(players) do
			if p.alive == true and p.safe ~= true and finite(p.x) and finite(p.z)
				and flat(p.x, p.z, spot.x, spot.z) <= Trap.SPRING_STUDS then
				table.insert(events, spring(state, now, p.id))
				break
			end
		end
	end
	return events
end

-- A bite of decoy `index` by player `id` at `distance` studs (server-measured). Returns true and { kind = "Rush",
-- untilAt } or { kind = "Spring", ... } (it was him), or false and Invalid / TooFar / Gone / Eaten.
function Trap.take(state, index, id, distance, now, alive, awake)
	if alive ~= true or not Trap.SPOTS[index] then return false, "Invalid" end
	if not finite(distance) or distance > Trap.PROMPT_STUDS then return false, "TooFar" end
	if state.status ~= "Ready" then return false, "Gone" end
	if index == state.trapIndex and Trap.disguised(state, awake, now) then return true, spring(state, now, id) end
	local key = index .. ":" .. tostring(id)
	if state.eaten[key] then return false, "Eaten" end
	state.eaten[key] = true
	return true, { kind = "Rush", untilAt = now + Trap.RUSH_SECONDS }
end

-- The walk speed during a rush (the same rule as WildboundServer.applyCarry's inline line).
function Trap.rushSpeed(base, untilAt, now)
	if not finite(untilAt) or now >= untilAt then return base end
	return math.max(base, math.min(base * Trap.RUSH_SCALE, Trap.RUSH_CAP))
end

return Trap
