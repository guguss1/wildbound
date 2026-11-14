-- Pure stalking rule for La Silueta (AI rework; user, 2026-11-13, "Te ronda": "Se va acercando a la zona donde estás y
-- te sigue de lejos, apareciendo y desapareciendo, hasta que decide atacar."). While she is not chasing, she no longer
-- walks a fixed diamond: she goes to a ring round her owner and circles it, holding her attack, until her wait is over
-- or the owner walks up to her; then she commits, walks at the owner and the usual sight, warning and strike rules
-- take over. Positions, the clock, the phase and one roll in [0, 1) are passed in; nothing here reads the world.
-- All numbers are hypotheses to tune in play.
local Stalk = {}

Stalk.CONSTANTS = table.freeze({
	RING = 38, -- studs she keeps from her owner while she stalks
	CLOSE = 16, -- an owner this near ends the stalk at once
	ARC = 0.6, -- radians round the ring from where she stands to her next goal, so she keeps circling
	FAR = 15, -- farther than RING + FAR from her owner she hurries
	QUIET = 12, -- seconds of quiet after a chase before she stalks again (the world server keeps the time)
	HIDDEN_GRACE = 3, -- seconds she still waits after a hidden owner comes out
	COMMIT_SECONDS = 8, -- a commit that brought no chase for this long is given up, and she stalks again
	-- Seconds she stalks before she commits: from the first number to the second by the roll.
	WAIT = table.freeze({
		Day = table.freeze({ 14, 24 }), Dusk = table.freeze({ 10, 18 }), Dawn = table.freeze({ 10, 18 }),
		Night = table.freeze({ 6, 12 }),
	}),
})
local C = Stalk.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Stalk.new()
	return { commitAt = nil, committedAt = nil, side = 1, anchorX = nil, anchorZ = nil }
end

-- Forgets the wait and the place: after a chase, or when the owner is gone.
function Stalk.reset(state)
	if type(state) ~= "table" then return end
	state.commitAt, state.committedAt, state.anchorX, state.anchorZ = nil, nil, nil, nil
end

-- input = { now, phase, roll, gx, gz (her), px, pz (her owner), present (the owner is alive where she can reach),
--           hidden (the owner is in a hide spot), quietUntil }
-- Returns nil when she does not stalk (the world server falls back to her rounds), else
-- { x, z, pace = "hunt" | "investigate", commit, hold }: where to walk and how fast; hold means she must not attack yet.
function Stalk.step(state, input)
	if type(state) ~= "table" or type(input) ~= "table" then return nil end
	local now, gx, gz = input.now, input.gx, input.gz
	if not finite(now) or not finite(gx) or not finite(gz) then return nil end
	if input.present ~= true or not finite(input.px) or not finite(input.pz)
		or (finite(input.quietUntil) and now < input.quietUntil) then
		Stalk.reset(state)
		return nil
	end
	if not state.commitAt then
		local wait = C.WAIT[input.phase] or C.WAIT.Day
		local roll = finite(input.roll) and math.clamp(input.roll, 0, 1) or 0
		state.commitAt = now + wait[1] + (wait[2] - wait[1]) * roll
		state.side = roll < 0.5 and -1 or 1
	end
	local hidden = input.hidden == true
	-- A hidden owner is never walked at: she circles the place they stood before they hid, and her wait cannot end.
	if hidden then
		state.commitAt = math.max(state.commitAt, now + C.HIDDEN_GRACE)
		if not state.anchorX then state.anchorX, state.anchorZ = input.px, input.pz end
	else
		state.anchorX, state.anchorZ = input.px, input.pz
	end
	local cx, cz = state.anchorX, state.anchorZ
	local dx, dz = gx - cx, gz - cz
	local away = math.sqrt(dx * dx + dz * dz)
	if not hidden and (now >= state.commitAt or away <= C.CLOSE) then
		state.committedAt = state.committedAt or now
		if now - state.committedAt < C.COMMIT_SECONDS then
			return { x = cx, z = cz, pace = "hunt", commit = true, hold = false }
		end
		-- An owner she cannot start a chase on (the spawn pad, a ledge): she backs off to the ring and waits again.
		local wait = C.WAIT[input.phase] or C.WAIT.Day
		state.commitAt, state.committedAt = now + wait[1], nil
	else
		state.committedAt = nil
	end
	local angle = (away < 0.1 and 0 or math.atan2(dz, dx)) + state.side * C.ARC
	return { x = cx + math.cos(angle) * C.RING, z = cz + math.sin(angle) * C.RING,
		pace = away > C.RING + C.FAR and "hunt" or "investigate", commit = false, hold = true }
end

return Stalk
