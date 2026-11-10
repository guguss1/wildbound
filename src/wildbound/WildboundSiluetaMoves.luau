-- Fix pass (FP4, plan Part 2): La Silueta's extra moves as pure rules, each behind a tuning toggle (default on; a toggle
-- is a number, 1 on and 0 off, so the dev tuning panel can flip it). The world server asks these every 0.2 s step:
--   (a) lunge: after LUNGE_AFTER s of continuous Hunt, a LUNGE_TELL s visible and audible tell, then LUNGE_SECONDS at
--       LUNGE_SPEED, then LUNGE_COOLDOWN s; never during Telegraph (a telegraph cancels it). The burst stays below a
--       rested sprint (16 x 1.45 = 23.2), and it never strikes: only the fair-strike telegraph (0.9 s) does.
--   (b) fake retreat: a search starts, FAKE_CHANCE of the time, by walking away from the last known spot for
--       FAKE_SECONDS, then turning back to it at hunt speed.
--   (c) flashlight glare: the owner's light (the server's own forward vector, like the island light test: GLARE_RANGE
--       studs, a GLARE_DOT cone, Dusk or Night) held on her for GLARE_HOLD s while she hunts staggers her GLARE_STAGGER
--       s (no movement, no strike), once per chase.
--   (d) scream: the chase-start scream reaches SCREAM_REACH studs (0 when off); the world sends it through the guardian
--       noise path and the inventory server wakes the islands it reaches.
-- Positions, time, phase and random rolls are passed in; nothing here reads the world.
local Moves = {}

Moves.CONSTANTS = table.freeze({
	LUNGE_ON = 1,
	LUNGE_AFTER = 3,
	LUNGE_TELL = 0.5,
	LUNGE_SECONDS = 0.8,
	LUNGE_SPEED = 22,
	LUNGE_COOLDOWN = 8,
	FAKE_ON = 1,
	FAKE_CHANCE = 0.25,
	FAKE_SECONDS = 4,
	FAKE_DISTANCE = 30, -- how far away the walk aims; she walks at search speed for FAKE_SECONDS, so she never gets there
	FAKE_ARRIVE = 3,
	GLARE_ON = 1,
	GLARE_RANGE = 12,
	GLARE_DOT = 0.85,
	GLARE_HOLD = 1.5,
	GLARE_STAGGER = 1,
	SCREAM_ON = 1,
	SCREAM_REACH = 70,
})
local TELL_FLOOR = 0.35 -- the readable-tell floor shared with the island strikes
local EPSILON = 1e-6

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules read `live`, a
-- copy the server's tuning bridge may override at runtime. No override, no change.
local C = {}
Moves.live = C

function Moves.tunable()
	local defaults = {}
	for key, value in pairs(Moves.CONSTANTS) do defaults[key] = value end
	return defaults
end

function Moves.tune(overrides)
	for key, value in pairs(Moves.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if Moves.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
		end
	end
	C.LUNGE_TELL = math.max(C.LUNGE_TELL, TELL_FLOOR)
end
Moves.tune(nil)

function Moves.enabled(key)
	return finite(C[key]) and C[key] >= 0.5
end

-- (a) Lunge. state: { phase = "idle" | "tell" | "burst", huntSince, untilAt, readyAt }.
function Moves.newLunge()
	return { phase = "idle", huntSince = nil, untilAt = 0, readyAt = -math.huge }
end

-- Returns { phase, speed (only during the burst), started (the tell began this step), tellEndsAt }.
function Moves.lungeStep(state, now, mode)
	local out = { phase = "idle", speed = nil, started = false, tellEndsAt = nil }
	if type(state) ~= "table" or not finite(now) then return out end
	if mode ~= "Hunt" or not Moves.enabled("LUNGE_ON") then
		if state.phase == "burst" then state.readyAt = now + C.LUNGE_COOLDOWN end
		state.phase, state.huntSince = "idle", nil
		return out
	end
	state.huntSince = state.huntSince or now
	if state.phase == "tell" and now >= state.untilAt - EPSILON then
		state.phase, state.untilAt = "burst", now + C.LUNGE_SECONDS
	elseif state.phase == "burst" and now >= state.untilAt - EPSILON then
		state.phase, state.readyAt, state.huntSince = "idle", now + C.LUNGE_COOLDOWN, now
	elseif state.phase == "idle" and now - state.huntSince >= C.LUNGE_AFTER - EPSILON and now >= state.readyAt - EPSILON then
		state.phase, state.untilAt = "tell", now + C.LUNGE_TELL
		out.started = true
	end
	out.phase = state.phase
	if state.phase == "tell" then out.tellEndsAt = state.untilAt end
	if state.phase == "burst" then out.speed = C.LUNGE_SPEED end
	return out
end

-- (b) Fake retreat. roll in [0, 1).
function Moves.fakeRetreat(roll)
	return Moves.enabled("FAKE_ON") and finite(roll) and roll >= 0 and roll < C.FAKE_CHANCE
end

function Moves.newFake(now, lastX, lastZ)
	return { startedAt = now, x = lastX, z = lastZ, dirX = nil, dirZ = nil }
end

-- Returns { leg = "away" | "back", destination = { x, z }, speed = "search" | "hunt", done }.
function Moves.fakeStep(fake, now, gx, gz)
	if type(fake) ~= "table" or not finite(now) or not finite(gx) or not finite(gz) then
		return { leg = "back", destination = nil, speed = "hunt", done = true }
	end
	if now - fake.startedAt < C.FAKE_SECONDS - EPSILON then
		if not fake.dirX then
			local dx, dz = gx - fake.x, gz - fake.z
			local length = math.sqrt(dx * dx + dz * dz)
			if length < 0.05 then dx, dz, length = 0, 1, 1 end
			fake.dirX, fake.dirZ = dx / length, dz / length
		end
		return { leg = "away", speed = "search", done = false,
			destination = { x = gx + fake.dirX * C.FAKE_DISTANCE, z = gz + fake.dirZ * C.FAKE_DISTANCE } }
	end
	local away = math.sqrt((gx - fake.x) ^ 2 + (gz - fake.z) ^ 2)
	return { leg = "back", speed = "hunt", destination = { x = fake.x, z = fake.z }, done = away <= C.FAKE_ARRIVE }
end

-- (c) Flashlight glare. input = { phase, distance (flat studs, owner to her), dot (owner's look . direction to her),
-- mode }. Returns { stagger, seconds }.
function Moves.newGlare()
	return { held = 0, used = false }
end

function Moves.resetGlare(glare)
	if type(glare) == "table" then glare.held, glare.used = 0, false end
end

local DARK = { Dusk = true, Night = true }
local CHASING = { Hunt = true, Alert = true }
function Moves.glareStep(glare, dt, input)
	local out = { stagger = false, seconds = 0 }
	if type(glare) ~= "table" or type(input) ~= "table" or not finite(dt) or dt < 0 then return out end
	local lit = Moves.enabled("GLARE_ON") and DARK[input.phase] == true and CHASING[input.mode] == true
		and finite(input.distance) and input.distance <= C.GLARE_RANGE
		and finite(input.dot) and input.dot >= C.GLARE_DOT - EPSILON
	if not lit then
		-- Inside a telegraph the hold pauses; anything else breaks it.
		if input.mode ~= "Telegraph" then glare.held = 0 end
		return out
	end
	glare.held += dt
	if not glare.used and glare.held >= C.GLARE_HOLD - EPSILON then
		glare.used, glare.held = true, 0
		out.stagger, out.seconds = true, C.GLARE_STAGGER
	end
	return out
end

-- (d) How far the chase-start scream carries; 0 when it is off.
function Moves.screamReach()
	return Moves.enabled("SCREAM_ON") and math.max(0, C.SCREAM_REACH) or 0
end

return Moves
