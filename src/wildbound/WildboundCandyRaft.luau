-- Caramelo v3 raft, the Balsa Banana Split (owner request 2026-11-17: "a raft to cross to the other side"; free for now,
-- docs/design/wildbound-caramelo-v3-plan.md V3-D3 and V3-D13). Pure rules for WildboundCandyRaftService (server) and
-- WildboundCandyRaftClient: one raft shuttles along a lane of world points { x, z } between two docks (dock 1 at the
-- lane's first point, dock 2 at its last). A player near the docked raft boards it (one rider), it waits DEPART_SECONDS,
-- then sails to the other dock, speeding up by ACCEL and braking by BRAKE so it stops at the dock; there the rider is
-- set down and the raft waits for the next one. A rider who leaves mid-way (jumps, dies, leaves the game, or asks)
-- leaves the raft adrift: it slows to a stop and RESPAWN_SECONDS later it is back at its home dock. Riding is free: no
-- price, no product, no purchase. Shared (ReplicatedStorage), no services, no clock: every time is passed in.
-- Rules: WildboundCandyRaft_Test.
local Raft = {}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Raft.finite = finite

Raft.FREE = true
Raft.EVENT = "CandyRaftEvent" -- the RemoteEvent in ReplicatedStorage.WildboundNetwork
Raft.SPEED = 14 -- studs/s at most (the sheet asks 18-24 on open water; the crossing is short)
Raft.ACCEL = 6 -- studs/s^2
Raft.BRAKE = 8 -- studs/s^2, so it always stops at the dock
Raft.MIN_SPEED = 1.5 -- it never crawls slower than this while sailing
Raft.BOARD_STUDS = 12 -- a player this close to the docked raft may board
Raft.DEPART_SECONDS = 1
Raft.RESPAWN_SECONDS = 8
Raft.REQUEST_GAP = 0.5 -- seconds between two accepted client requests of one player
Raft.BOB = table.freeze({ amplitude = 0.15, period = 2.4 })
Raft.ACTIONS = table.freeze({ Leave = true })

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end

-- laneLength(lane) -> total length in studs, or nil for a bad lane (fewer than two finite points, or no length).
function Raft.laneLength(lane)
	if type(lane) ~= "table" or #lane < 2 then return nil end
	local total = 0
	for i = 1, #lane do
		local p = lane[i]
		if type(p) ~= "table" or not finite(p.x) or not finite(p.z) then return nil end
		if i > 1 then total += flat(lane[i - 1].x, lane[i - 1].z, p.x, p.z) end
	end
	return total > 0 and total or nil
end

-- pointAt(lane, s) -> x, z, yaw: the point `s` studs along the lane (clamped) and the yaw (radians about +Y) that
-- looks along the leg it is on (a model's -Z forward), towards the lane's end.
function Raft.pointAt(lane, s)
	local travelled = 0
	s = finite(s) and s or 0
	for i = 1, #lane - 1 do
		local a, b = lane[i], lane[i + 1]
		local length = flat(a.x, a.z, b.x, b.z)
		if s <= travelled + length or i == #lane - 1 then
			local t = length > 0 and math.clamp((s - travelled) / length, 0, 1) or 0
			local yaw = math.atan2(-(b.x - a.x), -(b.z - a.z))
			return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, yaw
		end
		travelled += length
	end
	return lane[1].x, lane[1].z, 0
end

-- new(lane, homeDock) -> state, or nil and why. The raft waits at its home dock (1 or 2).
function Raft.new(lane, homeDock)
	local length = Raft.laneLength(lane)
	if not length then return nil, "BadLane" end
	homeDock = homeDock == 2 and 2 or 1
	return { lane = lane, length = length, home = homeDock, dock = homeDock, s = homeDock == 1 and 0 or length,
		status = "Docked", rider = nil, speed = 0, dir = 0, departAt = nil, adriftAt = nil }
end

-- board(state, riderId, distance, alive, now) -> ok, reason. reason: "Busy" (someone rides), "Moving" (not docked),
-- "TooFar", "Dead", "Invalid".
function Raft.board(state, riderId, distance, alive, now)
	if type(state) ~= "table" or riderId == nil or not finite(distance) or not finite(now) then return false, "Invalid" end
	if alive ~= true then return false, "Dead" end
	if state.rider ~= nil then return false, "Busy" end
	if state.status ~= "Docked" then return false, "Moving" end
	if distance > Raft.BOARD_STUDS then return false, "TooFar" end
	state.rider = riderId
	state.status = "Boarding"
	state.departAt = now + Raft.DEPART_SECONDS
	state.dir = state.dock == 1 and 1 or -1
	return true
end

-- leave(state, riderId, now) -> ok, reason: only the rider may leave. Docked or boarding: the raft stays docked.
-- Sailing: it is adrift and respawns at its home dock RESPAWN_SECONDS later.
function Raft.leave(state, riderId, now)
	if type(state) ~= "table" or not finite(now) then return false, "Invalid" end
	if riderId == nil or state.rider ~= riderId then return false, "NotRider" end
	state.rider = nil
	if state.status == "Sailing" then
		state.status = "Adrift"
		state.adriftAt = now
	else
		state.status = "Docked"
		state.departAt = nil
	end
	return true
end

-- call(state, dock, now) -> ok, reason (review m6): a player at the other dock calls the empty, docked raft; it sails
-- there with no rider. reason: "Here" (already there), "Busy", "Moving", "Invalid".
function Raft.call(state, dock, now)
	if type(state) ~= "table" or (dock ~= 1 and dock ~= 2) or not finite(now) then return false, "Invalid" end
	if state.rider ~= nil then return false, "Busy" end
	if state.status ~= "Docked" then return false, "Moving" end
	if state.dock == dock then return false, "Here" end
	state.status = "Sailing"
	state.speed = 0
	state.dir = dock == 2 and 1 or -1
	return true
end

-- moving(state) -> whether the raft is under way (the server moves the model only then).
function Raft.moving(state)
	return type(state) == "table" and (state.status == "Sailing" or state.status == "Adrift")
end

-- step(state, dt, now, riderSeated) -> events: { { kind, rider } } with kind "Depart", "Arrived" (the rider to set down
-- at the dock), "Left" (the rider got off), "Respawn". riderSeated: whether the rider still sits on the raft (the
-- server's check of the seat); false makes the rider leave.
function Raft.step(state, dt, now, riderSeated)
	local events = {}
	if type(state) ~= "table" or not finite(dt) or dt < 0 or not finite(now) then return events end
	dt = math.min(dt, 0.5)
	if state.rider ~= nil and riderSeated ~= true then
		local rider = state.rider
		Raft.leave(state, rider, now)
		table.insert(events, { kind = "Left", rider = rider })
	end
	if state.status == "Boarding" and now >= state.departAt then
		state.status = "Sailing"
		state.speed = 0
		table.insert(events, { kind = "Depart", rider = state.rider })
	end
	if state.status == "Sailing" then
		local target = state.dir > 0 and state.length or 0
		local remaining = math.abs(target - state.s)
		local cap = math.sqrt(2 * Raft.BRAKE * remaining)
		state.speed = math.max(math.min(state.speed + Raft.ACCEL * dt, Raft.SPEED, cap), Raft.MIN_SPEED)
		local move = state.speed * dt
		if move >= remaining then
			state.s = target
			state.speed = 0
			state.status = "Docked"
			state.dock = state.dir > 0 and 2 or 1
			local rider = state.rider
			state.rider = nil
			state.dir = 0
			table.insert(events, { kind = "Arrived", rider = rider })
		else
			state.s += move * state.dir
		end
	elseif state.status == "Adrift" then
		state.speed = math.max(state.speed - Raft.BRAKE * dt, 0)
		state.s = math.clamp(state.s + state.speed * dt * state.dir, 0, state.length)
		if now - state.adriftAt >= Raft.RESPAWN_SECONDS then
			state.status = "Docked"
			state.dock = state.home
			state.s = state.home == 1 and 0 or state.length
			state.speed, state.dir, state.adriftAt = 0, 0, nil
			table.insert(events, { kind = "Respawn" })
		end
	end
	return events
end

-- request(payload) -> the action a client asks for ("Leave"), or nil for anything else. Clients send { action = "Leave" }.
function Raft.request(payload)
	if type(payload) ~= "table" then return nil end
	local action = payload.action
	if type(action) ~= "string" or #action > 16 or not Raft.ACTIONS[action] then return nil end
	return action
end

-- allowed(lastAt, now) -> whether a player's request may be handled (one every REQUEST_GAP seconds).
function Raft.allowed(lastAt, now)
	if not finite(now) then return false end
	return not finite(lastAt) or now - lastAt >= Raft.REQUEST_GAP
end

-- The raft's bob on the surface, in studs, at time t (a bad time is still).
function Raft.bob(t)
	if not finite(t) then return 0 end
	return Raft.BOB.amplitude * math.sin(2 * math.pi * t / Raft.BOB.period)
end

-- The dock (1 or 2) a docked raft waits at, and its point; nil while it is away.
function Raft.dockedAt(state)
	if type(state) ~= "table" or state.status ~= "Docked" then return nil end
	return state.dock
end

return table.freeze(Raft)
