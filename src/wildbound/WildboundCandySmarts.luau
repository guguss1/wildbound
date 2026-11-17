-- Owner feedback 3 (odd/tasks/wildbound-caramelo-playfix.md, OF3): smarter and faster candy creatures. Shared, pure
-- helpers every candy brain uses (WildboundBeastCandyCritter, Gomibu, Flanfuria, Tortidragon, Don Glaseon). Server only:
-- no services, no clock (the brains pass `now`). Data lives in PROFILES (per creature) over DEFAULTS.
--   speed   a sprint burst (sprint studs/s for sprintSeconds) the first time a chase starts, then the base chase speed.
--   lead    predictive pursuit: the target's position plus its velocity times `seconds`, at most maxLead studs ahead;
--           none while the creature reacts to a dodge (the dash's velocity spike would throw the aim far off).
--   goal    where to run: the lead point, and when 2+ candy creatures chase the same player (same world, same userId,
--           stepped within PEER_SECONDS) each one after the first runs for a point flankStuds beside the target at
--           its own angle, so they come from different sides; close to that point (or the target) it closes in.
--   steer   anti-stuck: a cast (world.castLane, 2.5 studs over the ground, so small ledges never block) lookStuds
--           ahead; when blocked it side-steps by 35, 70, 105 or 140 degrees, keeping the side it chose last.
--   dodged  a dodge press (world.lastDash) in the last DASH_FRESH seconds makes it stop and re-aim for dodgePause.
--   guards  a target within `guard` studs of the creature's home (its nest or post) is noticed even past its sight.
--   alarm / called  a creature that notices an intruder calls its calm allies (same player) whose home is within
--           callStuds of its own; they notice too (no chain: a called creature never calls).
-- The peers and calls are kept per base world table (weakly): the beast script's per-encounter adapters share one base
-- through their metatable, while each test's fake world is its own.
local Smarts = {}

local DEFAULTS = table.freeze({
	sprint = 0, sprintSeconds = 0, lead = 0.45, aimLead = 0.35, maxLead = 7, flankStuds = 8, lookStuds = 4,
	dodgePause = 0.45, callStuds = 70, callSeconds = 2, guard = nil,
})
local function profile(t)
	return table.freeze(setmetatable(t, { __index = DEFAULTS }))
end
-- Base chase speeds stay in WildboundBeastConfig (21-23 now); the sprint matches or slightly beats a running player
-- (16 x 1.45 = 23.2) for a short burst after noticing.
-- CH2 (owner request 2026-11-16, "make them go faster"): every candy sprint +3 or +4 (24-27 -> 28-30), same durations,
-- each as far as the escape allows: the burst never closes a sprinter noticed at the edge of its sight into its attack
-- range, and gains under 15 studs (WildboundCandySmarts_Test CH2), so Gomibu, Mielita and Tortidragon get +3, the
-- others +4. Don Glaseon keeps 25.
Smarts.PROFILES = table.freeze({
	Mochimiau = profile({ sprint = 30, sprintSeconds = 2 }),
	Canelin = profile({ sprint = 29, sprintSeconds = 1.5 }),
	Flanin = profile({ sprint = 28, sprintSeconds = 1.5 }),
	Mielita = profile({ sprint = 30, sprintSeconds = 2 }),
	GatoRepartidor = profile({ sprint = 28, sprintSeconds = 2 }),
	Gomibu = profile({ sprint = 29, sprintSeconds = 2, guard = 30 }),
	Flanfuria = profile({ sprint = 28, sprintSeconds = 1.5, guard = 24 }),
	Tortidragon = profile({ sprint = 29, sprintSeconds = 2, guard = 28 }),
	DonGlaseon = profile({ sprint = 25, sprintSeconds = 1.5 }),
})
Smarts.DEFAULTS = DEFAULTS
Smarts.PEER_SECONDS = 0.3
Smarts.DASH_FRESH = 0.5
Smarts.STEER_DEGREES = table.freeze({ 35, 70, 105, 140 })
-- OF3 review: a dodge only counts within DODGE_REACT_STUDS, and a creature can be stopped again only after
-- DODGE_COOLDOWN_SECONDS (the server takes a missed dodge every 1.2 s: spamming it must not freeze the chase).
Smarts.DODGE_REACT_STUDS = 12
Smarts.DODGE_COOLDOWN_SECONDS = 3
-- OF3 review: chase and sprint scale with a trained walker (training adds 2 studs/s per level), within caps.
Smarts.CHASE_SHARE = 0.92
Smarts.SPRINT_SHARE = 1.1
Smarts.CHASE_CAP = 36 -- CH2: 34 -> 36
Smarts.SPRINT_CAP = 40 -- CH2: 38 -> 40

local NONE = profile({})
local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil end
	return x / length, z / length
end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

function Smarts.profile(name) return Smarts.PROFILES[name] or NONE end

local boards = setmetatable({}, { __mode = "k" })
local function board(world, userId)
	local mt = type(world) == "table" and getmetatable(world)
	local base = mt and type(mt.__index) == "table" and mt.__index or world
	if type(base) ~= "table" then return nil end
	boards[base] = boards[base] or {}
	local key = userId or 0
	boards[base][key] = boards[base][key] or { peers = {}, calls = {} }
	return boards[base][key]
end

-- The chase speed now: the sprint for sprintSeconds from the first chase step of the encounter, then `base`.
-- OF3 review: against a trained walker (target.walk, its walk speed without the sprint) the chase is at least
-- CHASE_SHARE of that walk (up to CHASE_CAP) and the sprint at least SPRINT_SHARE of it (up to SPRINT_CAP).
function Smarts.speed(e, now, base, target)
	local P = Smarts.profile(e.beast)
	local walk = target and finite(target.walk) and target.walk or 0
	local chase = math.max(base, math.min(walk * Smarts.CHASE_SHARE, Smarts.CHASE_CAP))
	local sprint = math.max(P.sprint, math.min(walk * Smarts.SPRINT_SHARE, Smarts.SPRINT_CAP))
	e.sprintFrom = e.sprintFrom or now
	if P.sprint > 0 and sprint > chase and now - e.sprintFrom < P.sprintSeconds then return sprint end
	return chase
end

-- Where the target will be in `seconds` (P.lead by default), at most maxLead studs ahead.
function Smarts.lead(e, target, now, seconds)
	local P = Smarts.profile(e.beast)
	local vx, vz = target.vx, target.vz
	if not finite(vx) or not finite(vz) or (e.dazedUntil and now < e.dazedUntil) then return target.x, target.z end
	local s = seconds or P.lead
	local ox, oz = vx * s, vz * s
	local length = math.sqrt(ox * ox + oz * oz)
	if length > P.maxLead then ox, oz = ox / length * P.maxLead, oz / length * P.maxLead end
	return target.x + ox, target.z + oz
end

-- Marks the creature as hunting its player this step (every engaged phase: chase, tell, strike, recovery).
function Smarts.track(e, world, now)
	local b = board(world, e.userId)
	if b then b.peers[e.id] = { e = e, at = now } end
	return b
end

-- Where to run this step (the lead point, or a flank point when it hunts with others).
function Smarts.goal(e, world, now, target)
	local gx, gz = Smarts.lead(e, target, now)
	local b = Smarts.track(e, world, now)
	if not b then return gx, gz end
	local list = {}
	for id, peer in pairs(b.peers) do
		local age = now - peer.at
		if peer.e.done or peer.e.phase == "Return" or age < 0 or age > Smarts.PEER_SECONDS then
			b.peers[id] = nil
		else
			table.insert(list, peer.e)
		end
	end
	if #list < 2 then return gx, gz end
	table.sort(list, function(a, c) return tostring(a.id) < tostring(c.id) end)
	local slot = table.find(list, e)
	if not slot or slot == 1 then return gx, gz end
	local P = Smarts.profile(e.beast)
	local first = list[1]
	local bx, bz = unit(first.pos.x - target.x, first.pos.z - target.z)
	if not bx then bx, bz = 1, 0 end
	local offset = #list == 2 and math.rad(100) or (slot - 1) * 2 * math.pi / #list
	local angle = math.atan2(bz, bx) + offset
	local fx, fz = gx + math.cos(angle) * P.flankStuds, gz + math.sin(angle) * P.flankStuds
	if flat(e.pos.x, e.pos.z, fx, fz) <= 2 or flat(e.pos.x, e.pos.z, target.x, target.z) <= P.flankStuds * 0.75 then
		return gx, gz
	end
	return fx, fz
end

-- The direction to walk instead of (dx, dz) when something solid stands lookStuds ahead; nil when boxed in.
function Smarts.steer(e, world, dx, dz)
	if not dx or type(world) ~= "table" or type(world.castLane) ~= "function" then return dx, dz end
	local P = Smarts.profile(e.beast)
	local function clear(x, z) return world.castLane(e.pos.x, e.pos.y, e.pos.z, x, z, P.lookStuds) == nil end
	if clear(dx, dz) then return dx, dz end
	-- the side it chose last time first, through every angle, so it walks round an obstacle instead of zigzagging
	local side = e.steerSide or 1
	for _, s in ipairs({ side, -side }) do
		for _, degrees in ipairs(Smarts.STEER_DEGREES) do
			local a = math.rad(degrees) * s
			local rx, rz = dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a)
			if clear(rx, rz) then
				e.steerSide = s
				return rx, rz
			end
		end
	end
	e.steerSide = -side
	return nil
end

-- The steered unit direction from the creature to (x, z), or nil (there already, or boxed in).
function Smarts.direction(e, world, x, z)
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	if not dx then return nil end
	return Smarts.steer(e, world, dx, dz)
end

-- True while it reacts to the target's dodge (it stands and re-aims).
-- Only a dodge pressed within DODGE_REACT_STUDS of the creature, once per DODGE_COOLDOWN_SECONDS.
function Smarts.dodged(e, world, now, target)
	local at = type(world) == "table" and type(world.lastDash) == "function" and world.lastDash() or nil
	if finite(at) and at ~= e.dashSeen and now - at >= 0 and now - at <= Smarts.DASH_FRESH then
		e.dashSeen = at
		local near = not target or flat(e.pos.x, e.pos.z, target.x, target.z) <= Smarts.DODGE_REACT_STUDS
		if near and at >= (e.dodgeReadyAt or -math.huge) then
			e.dazedUntil = at + Smarts.profile(e.beast).dodgePause
			e.dodgeReadyAt = at + Smarts.DODGE_COOLDOWN_SECONDS
		end
	end
	return e.dazedUntil ~= nil and now < e.dazedUntil
end

function Smarts.guards(e, target)
	local P = Smarts.profile(e.beast)
	return P.guard ~= nil and e.home ~= nil and flat(e.home.x, e.home.z, target.x, target.z) <= P.guard
end

function Smarts.alarm(e, world, now)
	local b = board(world, e.userId)
	if not b or not e.home then return end
	b.calls[e.id] = { x = e.home.x, z = e.home.z, at = now }
end

function Smarts.called(e, world, now)
	local b = board(world, e.userId)
	if not b or not e.home then return false end
	local P = Smarts.profile(e.beast)
	for id, call in pairs(b.calls) do
		local age = now - call.at
		if age < 0 or age > P.callSeconds then
			b.calls[id] = nil
		elseif id ~= e.id and flat(call.x, call.z, e.home.x, e.home.z) <= P.callStuds then
			return true
		end
	end
	return false
end

return Smarts
