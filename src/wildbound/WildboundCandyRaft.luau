-- Caramelo raft, the Balsa Banana Split (owner request 2026-11-17: "a raft to cross to the other side"; free for now,
-- docs/design/wildbound-caramelo-v3-plan.md V3-D3 and V3-D13; Caramelo v4 "a raft you can steer", odd/tasks/
-- wildbound-caramelo-v2.md V4-D3). Pure rules for WildboundCandyRaftService (server) and WildboundCandyRaftClient.
-- One raft waits at a dock tip. A player near the docked raft boards it (one rider); after DEPART_SECONDS the rider
-- steers it with the seat's throttle and steer (W/S, A/D, the touch thumbstick): it speeds up by ACCEL to SPEED
-- (REVERSE backwards), brakes by BRAKE, drifts to a stop by DRAG, and turns at TURN_RATE at speed (TURN_MIN of it when
-- still). It never leaves the chocolate nor passes under a bridge: the area says where its hull (HULL studs) fits, and a
-- bank met at an angle lets it slide along. Brought slowly (DOCK_SPEED) within DOCK_STUDS of a dock tip, once it has
-- been ARM_STUDS away from every tip, it docks and the rider is set down. A rider who leaves near a dock leaves it
-- docked there; mid-river it drifts, stops, and RESPAWN_SECONDS later is back at its home dock (or docks where it stops
-- near a tip). A player at the other dock calls the empty raft: CALL_SECONDS later it is there. Riding is free: no
-- price, no product, no purchase. V6-D3 (Caramelo v6, the river current): while afloat (Sailing or Adrift) the raft
-- also drifts with the current the area's flow gives (WildboundCandyCurrent), so it goes faster downstream and slower
-- upstream; docked, boarding or called it stays put. Shared (ReplicatedStorage), no services, no clock: every time is
-- passed in.
-- Coordinates are world studs; yaw is radians about +Y, the model looking along -Z (look = (-sin yaw, -cos yaw)).
-- Rules: WildboundCandyRaft_Test.
local Raft = {}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Raft.finite = finite

Raft.FREE = true
Raft.EVENT = "CandyRaftEvent" -- the RemoteEvent in ReplicatedStorage.WildboundNetwork
-- V5-D5: 16 -> 20 (+25 %, "a little faster"); reverse 6 -> 7.5, the same share.
Raft.SPEED = 20 -- studs/s ahead at most
Raft.REVERSE = 7.5 -- studs/s astern at most
Raft.ACCEL = 6 -- studs/s^2 speeding up
Raft.BRAKE = 10 -- studs/s^2 against the throttle, and while adrift
Raft.DRAG = 3 -- studs/s^2 with no throttle
Raft.TURN_RATE = math.rad(70) -- radians/s at TURN_FULL speed or more
Raft.TURN_FULL = 6 -- studs/s
Raft.TURN_MIN = 0.3 -- share of TURN_RATE when still
Raft.HULL = 3 -- studs the hull keeps off a bank or a bridge
Raft.DOCK_STUDS = 6 -- a slow raft this close to a dock tip docks
Raft.DOCK_SPEED = 4 -- studs/s at most to dock
Raft.ARM_STUDS = 9 -- it docks only after being this far from every tip; within it the hull may touch the bank
Raft.SLIDE_SHARE = 0.1 -- a slide along a bank must keep this share of the step
Raft.BOARD_STUDS = 12 -- a player this close to the docked raft may board
Raft.DEPART_SECONDS = 1
Raft.RESPAWN_SECONDS = 8
Raft.CALL_SECONDS = 3
Raft.REQUEST_GAP = 0.5 -- seconds between two accepted client requests of one player
-- V6-D3, V6-D32: while afloat (Sailing or Adrift) the raft drifts with the river's current (area.flow, from
-- WildboundCandyCurrent: 4 studs/s on the river legs, 1.5 in the lake) on top of its own speed through the water, by the
-- same hull and bridge rule; docked, boarding or called it stays put. speed (and DOCK_SPEED) stays the speed through the
-- water. CURRENT_MAX caps whatever a flow returns.
Raft.CURRENT_MAX = 4
Raft.BOB = table.freeze({ amplitude = 0.15, period = 2.4 })
Raft.ACTIONS = table.freeze({ Leave = true })

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function toward(value, target, step)
	if value < target then return math.min(value + step, target) end
	return math.max(value - step, target)
end

-- docksFrom(V3, centre) -> the layout's docks in world studs: { x, z (the tip, where the raft waits), standX, standZ
-- (where a rider is set down), yaw (looking out from the stand through the tip) }, or nil for a bad layout.
function Raft.docksFrom(V3, centre)
	if type(V3) ~= "table" or type(V3.DOCKS) ~= "table" or type(centre) ~= "table" then return nil end
	local out = {}
	for i, d in ipairs(V3.DOCKS) do
		if type(d) ~= "table" or not (finite(d.tipX) and finite(d.tipZ) and finite(d.standX) and finite(d.standZ)) then return nil end
		local yaw = math.atan2(-(d.tipX - d.standX), -(d.tipZ - d.standZ))
		out[i] = { id = d.id, x = centre.x + d.tipX, z = centre.z + d.tipZ, standX = centre.x + d.standX,
			standZ = centre.z + d.standZ, yaw = yaw }
	end
	return out
end

-- area(V3, centre, flow) -> { inside = function(x, z, r), flow = function(x, z) or nil }: inside says whether a hull
-- of reach r at world (x, z) is in the chocolate (V3.liquidDistance <= -r, plot-local) and clear of every bridge (not
-- V3.nearBridge). V6-D3: flow (optional, WildboundCandyCurrent.flow: (V3, plotX, plotZ) -> vx, vz) gives the river's
-- current at world (x, z), studs/s; without it the chocolate is still.
function Raft.area(V3, centre, flow)
	return {
		inside = function(x, z, r)
			if not finite(x) or not finite(z) then return false end
			r = finite(r) and r or 0
			local lx, lz = x - centre.x, z - centre.z
			return V3.liquidDistance(lx, lz) <= -r and not V3.nearBridge(lx, lz, r)
		end,
		flow = type(flow) == "function" and function(x, z)
			return flow(V3, x - centre.x, z - centre.z)
		end or nil,
	}
end

-- drift(area, x, z) -> vx, vz: the current under a raft at world (x, z), studs/s; 0, 0 without a flow or for junk, and
-- never more than CURRENT_MAX.
function Raft.drift(area, x, z)
	if type(area) ~= "table" or type(area.flow) ~= "function" or not finite(x) or not finite(z) then return 0, 0 end
	local ok, vx, vz = pcall(area.flow, x, z)
	if not ok or not finite(vx) or not finite(vz) then return 0, 0 end
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed > Raft.CURRENT_MAX then vx, vz = vx / speed * Raft.CURRENT_MAX, vz / speed * Raft.CURRENT_MAX end
	return vx, vz
end

-- new(docks, homeDock) -> state, or nil and why. The raft waits at its home dock's tip, looking out.
function Raft.new(docks, homeDock)
	if type(docks) ~= "table" or #docks < 2 then return nil, "BadDocks" end
	for _, d in ipairs(docks) do
		if type(d) ~= "table" or not (finite(d.x) and finite(d.z) and finite(d.yaw)) then return nil, "BadDocks" end
	end
	homeDock = (homeDock == 2 and #docks >= 2) and 2 or 1
	local home = docks[homeDock]
	return { docks = docks, home = homeDock, dock = homeDock, x = home.x, z = home.z, yaw = home.yaw,
		status = "Docked", rider = nil, speed = 0, armed = false, departAt = nil, adriftAt = nil, callAt = nil, target = nil }
end

-- The nearest dock tip within `reach` of (x, z): index, distance; or nil.
function Raft.nearDock(state, x, z, reach)
	local best, bestDistance = nil, math.huge
	for i, d in ipairs(state.docks) do
		local distance = flat(x, z, d.x, d.z)
		if distance <= reach and distance < bestDistance then best, bestDistance = i, distance end
	end
	return best, best and bestDistance or nil
end

local function dockAt(state, i)
	local d = state.docks[i]
	state.status, state.dock = "Docked", i
	state.x, state.z, state.yaw = d.x, d.z, d.yaw
	state.speed, state.armed = 0, false
	state.departAt, state.adriftAt, state.callAt, state.target = nil, nil, nil, nil
end

-- input(throttle, steer) -> both clamped to [-1, 1]; anything not a finite number is 0.
function Raft.input(throttle, steer)
	throttle = finite(throttle) and math.clamp(throttle, -1, 1) or 0
	steer = finite(steer) and math.clamp(steer, -1, 1) or 0
	return throttle, steer
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
	return true
end

-- leave(state, riderId, now) -> ok, reason, dock: only the rider may leave. Docked or boarding: the raft stays docked.
-- Under way within DOCK_STUDS of a dock tip: it docks there (dock names it, for the set-down). Elsewhere: adrift.
function Raft.leave(state, riderId, now)
	if type(state) ~= "table" or not finite(now) then return false, "Invalid" end
	if riderId == nil or state.rider ~= riderId then return false, "NotRider" end
	state.rider = nil
	if state.status == "Sailing" then
		local i = Raft.nearDock(state, state.x, state.z, Raft.DOCK_STUDS)
		if i then
			dockAt(state, i)
			return true, nil, i
		end
		state.status = "Adrift"
		state.adriftAt = now
	else
		state.status = "Docked"
		state.departAt = nil
	end
	return true
end

-- call(state, dock, now) -> ok, reason: a player at the other dock calls the empty, docked raft; CALL_SECONDS later it
-- waits at that dock (V4-D11-R1: brought over, not sailed: no path to plan round bends and bridges). reason: "Here",
-- "Busy", "Moving", "Invalid".
function Raft.call(state, dock, now)
	if type(state) ~= "table" or not finite(now) or type(dock) ~= "number" or not state.docks[dock] then return false, "Invalid" end
	if state.rider ~= nil then return false, "Busy" end
	if state.status ~= "Docked" then return false, "Moving" end
	if state.dock == dock then return false, "Here" end
	state.status = "Called"
	state.callAt = now + Raft.CALL_SECONDS
	state.target = dock
	return true
end

-- moving(state) -> whether the raft is under way (the server moves the model only then, and once after each event).
function Raft.moving(state)
	return type(state) == "table" and (state.status == "Sailing" or state.status == "Adrift")
end

-- One shift of (dx, dz) studs: whole if the hull fits, else a slide along x or z if that keeps SLIDE_SHARE of the
-- step, else none. Near a dock tip (ARM_STUDS) the hull may touch the bank (reach 0). Returns "Moved", "Slid" or
-- "Blocked". V6-D3: the current's drift goes through the same rule as the raft's own move.
local function shift(state, dx, dz, area)
	if dx == 0 and dz == 0 then return "Moved" end
	if type(area) ~= "table" or type(area.inside) ~= "function" then return "Blocked" end
	local function fits(x, z)
		local reach = Raft.nearDock(state, x, z, Raft.ARM_STUDS) and 0 or Raft.HULL
		return area.inside(x, z, reach) == true
	end
	local nx, nz = state.x + dx, state.z + dz
	if fits(nx, nz) then
		state.x, state.z = nx, nz
		return "Moved"
	end
	local least = Raft.SLIDE_SHARE * math.sqrt(dx * dx + dz * dz)
	if math.abs(dx) >= least and fits(nx, state.z) then
		state.x = nx
		return "Slid"
	end
	if math.abs(dz) >= least and fits(state.x, nz) then
		state.z = nz
		return "Slid"
	end
	return "Blocked"
end

-- One move of `distance` studs along the raft's look (its own speed through the water).
local function move(state, distance, area)
	if distance == 0 then return "Moved" end
	return shift(state, -math.sin(state.yaw) * distance, -math.cos(state.yaw) * distance, area)
end

-- The current's drift for dt seconds, by the hull and bridge rule (a bank or a bridge stops it; it never changes the
-- raft's own speed).
local function drift(state, dt, area)
	local vx, vz = Raft.drift(area, state.x, state.z)
	return shift(state, vx * dt, vz * dt, area)
end

-- step(state, dt, now, input, seated, area) -> events: { { kind, rider, dock } } with kind "Depart", "Arrived" (docked
-- with its rider to set down at `dock`, or an empty called raft), "Left" (the rider got off; `dock` when it docked
-- there), "Docked" (a drifting raft stopped by a dock), "Respawn". input: { throttle, steer } from the rider's seat
-- (nil: none). seated: whether the rider still sits on the raft; false makes the rider leave. area: Raft.area(...).
function Raft.step(state, dt, now, input, seated, area)
	local events = {}
	if type(state) ~= "table" or not finite(dt) or dt < 0 or not finite(now) then return events end
	dt = math.min(dt, 0.5)
	if state.rider ~= nil and seated ~= true then
		local rider = state.rider
		local _, _, dock = Raft.leave(state, rider, now)
		table.insert(events, { kind = "Left", rider = rider, dock = dock })
	end
	if state.status == "Boarding" and now >= state.departAt then
		state.status = "Sailing"
		state.speed, state.armed, state.departAt = 0, false, nil
		table.insert(events, { kind = "Depart", rider = state.rider })
	end
	if state.status == "Sailing" then
		local throttle, steer = 0, 0
		if type(input) == "table" then throttle, steer = Raft.input(input.throttle, input.steer) end
		local speed = state.speed
		if throttle == 0 then
			speed = toward(speed, 0, Raft.DRAG * dt)
		else
			local target = throttle > 0 and throttle * Raft.SPEED or throttle * Raft.REVERSE
			local speedingUp = (target > speed and speed >= 0) or (target < speed and speed <= 0)
			speed = toward(speed, target, (speedingUp and Raft.ACCEL or Raft.BRAKE) * dt)
		end
		local share = math.clamp(math.abs(speed) / Raft.TURN_FULL, Raft.TURN_MIN, 1)
		local sense = speed < 0 and -1 or 1 -- astern, the bow swings the other way, as in a car
		state.yaw -= steer * sense * Raft.TURN_RATE * share * dt
		local moved = move(state, speed * dt, area)
		if moved == "Blocked" then speed = 0 elseif moved == "Slid" then speed = toward(speed, 0, Raft.BRAKE * dt) end
		state.speed = speed
		drift(state, dt, area) -- V6-D3: the current carries it on top of its own speed
		if not state.armed and not Raft.nearDock(state, state.x, state.z, Raft.ARM_STUDS) then state.armed = true end
		local i = state.armed and math.abs(speed) <= Raft.DOCK_SPEED and Raft.nearDock(state, state.x, state.z, Raft.DOCK_STUDS)
		if i then
			local rider = state.rider
			state.rider = nil
			dockAt(state, i)
			table.insert(events, { kind = "Arrived", rider = rider, dock = i })
		end
	elseif state.status == "Adrift" then
		state.speed = toward(state.speed, 0, Raft.BRAKE * dt)
		if move(state, state.speed * dt, area) == "Blocked" then state.speed = 0 end
		drift(state, dt, area) -- V6-D3: an abandoned raft drifts downstream until it docks or respawns
		local i = state.speed == 0 and Raft.nearDock(state, state.x, state.z, Raft.DOCK_STUDS)
		if i then
			dockAt(state, i)
			table.insert(events, { kind = "Docked", dock = i })
		elseif now - state.adriftAt >= Raft.RESPAWN_SECONDS then
			dockAt(state, state.home)
			table.insert(events, { kind = "Respawn", dock = state.home })
		end
	elseif state.status == "Called" and now >= state.callAt then
		local target = state.target
		dockAt(state, target)
		table.insert(events, { kind = "Arrived", rider = nil, dock = target })
	end
	return events
end

-- request(payload) -> the action a client asks for ("Leave"), or nil for anything else. Clients send { action = "Leave" }.
-- Steering is never a request: the server reads the rider's VehicleSeat.
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

-- The dock (1 or 2) a docked raft waits at; nil while it is away, boarding or called.
function Raft.dockedAt(state)
	if type(state) ~= "table" or state.status ~= "Docked" then return nil end
	return state.dock
end

return table.freeze(Raft)
