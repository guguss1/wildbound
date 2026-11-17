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
-- RC (owner request 2026-11-16, "all the creatures keep chasing you, and fast, until you reach the base"): relentless =
-- true makes a creature that noticed a player hunt it until the player is safe (base or hub), defeated or gone; see
-- Smarts.RELENTLESS. Don Glaseon stays territorial (no relentless flag).
Smarts.PROFILES = table.freeze({
	Mochimiau = profile({ sprint = 30, sprintSeconds = 2, relentless = true }),
	Canelin = profile({ sprint = 29, sprintSeconds = 1.5, relentless = true }),
	Flanin = profile({ sprint = 28, sprintSeconds = 1.5, relentless = true }),
	Mielita = profile({ sprint = 30, sprintSeconds = 2, relentless = true }),
	GatoRepartidor = profile({ sprint = 28, sprintSeconds = 2, relentless = true }),
	Gomibu = profile({ sprint = 29, sprintSeconds = 2, guard = 30, relentless = true }),
	Flanfuria = profile({ sprint = 28, sprintSeconds = 1.5, guard = 24, relentless = true }),
	Tortidragon = profile({ sprint = 29, sprintSeconds = 2, guard = 28, relentless = true }),
	DonGlaseon = profile({ sprint = 25, sprintSeconds = 1.5 }),
})
-- RC: the relentless chase.
--   hardSeconds   a safety end: no hunt lasts longer than this (then it ends like any other far-from-home ending).
--   fadeStuds     an ending farther than this from its post fades out where it stands (the shared Disengage fade) and
--                 its resting copy is back at the post; nearer, it walks home as before ("vuelve a su nido").
--   windFirst / windEvery / windSeconds   the second wind: windFirst seconds into a chase, and every windEvery after,
--                 it runs at its noticing sprint for windSeconds, so a player whose stamina ran out (walking 16) is caught
--                 and must dodge, while a sprinting player still gains whenever it has stamina.
--   maxChasers    at most this many candy creatures hunt one player at once; another one that sees the player stays calm
--                 until a place frees (the director keeps them outside MAX_ACTIVE, PF1, so this is their cap).
--   rampStart / rampEverySeconds / rampMax / rampResetSeconds   V4-D9, numbers of V4-D13 (owner 2026-11-17: "at
--                 first they must chase less, it progresses, and when you steal an egg it should rise a lot"): the calm
--                 per-player cap (Smarts.cap) starts at rampStart when the first hunter engages (the player's pressure
--                 starts) and rises by one every rampEverySeconds, up to rampMax; with no hunter on that player for
--                 rampResetSeconds the pressure ends and the next hunt starts again at rampStart.
--   frenzySeconds / frenzyStuds   V4-D13: a steal (Smarts.frenzy) sets the cap to maxChasers at once for frenzySeconds
--                 and calls every candy creature whose post lies within frenzyStuds of the nest (Smarts.called); then the
--                 cap falls back to the calm ramp.
Smarts.RELENTLESS = table.freeze({ hardSeconds = 180, fadeStuds = 120, windFirst = 8, windEvery = 8, windSeconds = 1.5,
	maxChasers = 5, rampStart = 1, rampEverySeconds = 20, rampMax = 3, rampResetSeconds = 10, frenzySeconds = 60,
	frenzyStuds = 150 })
-- V4-D12 (owner 2026-11-17: "no creature may enter the houses"): a creature keeps this far outside a house's footprint
-- disc (Smarts.houseDiscs); a player inside the footprint itself is sheltered (no hit lands, the hunt is kept).
Smarts.HOUSE_MARGIN_STUDS = 1.5
-- RC4: the global strike ledger (every candy beast and the Zumbidulces share it, per player): at most STRIKE_MAX strikes
-- from different attackers land within STRIKE_WINDOW seconds of each other on one player.
Smarts.STRIKE_WINDOW = 0.6
Smarts.STRIKE_MAX = 2
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
	if P.sprint > 0 and sprint > chase and Smarts.secondWind(e, now) then return sprint end -- RC2
	return chase
end

-- RC2: whether a relentless creature runs its second wind now (windSeconds every windEvery, from windFirst seconds after
-- its first chase step).
function Smarts.secondWind(e, now)
	if not Smarts.profile(e.beast).relentless or not finite(e.sprintFrom) or not finite(now) then return false end
	local R = Smarts.RELENTLESS
	local t = now - e.sprintFrom - R.windFirst
	return t >= 0 and t % R.windEvery < R.windSeconds
end

-- RC1: the hunt. A relentless creature starts hunting when it notices (Smarts.engage) and from then on no leash, abandon
-- distance, escape distance or chase timer ends it: only the safe zone, the target's death or leave (Attack.guard), or
-- the hard limit (Smarts.overtime).
local QUIET = table.freeze({ Spawn = true, Calm = true, Patrol = true, Return = true, GiveUp = true, Disengage = true,
	Ended = true })
function Smarts.hunting(e)
	return e.huntFrom ~= nil and Smarts.profile(e.beast).relentless == true
end
function Smarts.overtime(e, now)
	return Smarts.hunting(e) and finite(now) and now - e.huntFrom >= Smarts.RELENTLESS.hardSeconds
end
-- RC3: farther than fadeStuds from its post: an ending fades out there instead of a long walk home.
function Smarts.farFromHome(e)
	return e.home ~= nil and flat(e.pos.x, e.pos.z, e.home.x, e.home.z) > Smarts.RELENTLESS.fadeStuds
end
-- RC4: how many relentless creatures hunt this player now (other than `except`); a finished or quiet one leaves.
-- V4-D9: it also keeps the board's lastHunted (the last time a hunter was seen on this player): `now` while one still
-- hunts, else the last step of the ones that left.
function Smarts.chasers(world, userId, now, except)
	local b = board(world, userId)
	if not b then return 0 end
	b.hunters = b.hunters or {}
	local n = 0
	for id, e in pairs(b.hunters) do
		local stale = finite(now) and finite(e.lastStep) and now - e.lastStep > 2
		if e.done or QUIET[e.phase] or stale then
			b.hunters[id] = nil
			if finite(e.lastStep) then b.lastHunted = math.max(b.lastHunted or -math.huge, e.lastStep) end
		else
			if finite(now) then b.lastHunted = math.max(b.lastHunted or -math.huge, now) end
			if id ~= except then n += 1 end
		end
	end
	return n
end
-- V4-D9: the chaser cap on this player now: rampStart + one per rampEverySeconds of pressure, at most maxChasers.
-- The pressure (board.pressureFrom) starts when the first hunter engages and ends once no hunter has been on the
-- player for rampResetSeconds. Without a board or a clock the old flat cap (maxChasers).
function Smarts.cap(world, userId, now)
	local R = Smarts.RELENTLESS
	local b = board(world, userId)
	if not b or not finite(now) then return R.maxChasers end
	-- V4-D13: during a steal's frenzy, the full cap at once
	if b.frenzyUntil ~= nil and now < b.frenzyUntil then return R.maxChasers end
	local n = Smarts.chasers(world, userId, now)
	-- the frenzy counts as hunted to its end: the calm ramp after it goes on from the steal's pressure
	local last = math.max(b.lastHunted or -math.huge, b.frenzyUntil or -math.huge)
	if b.pressureFrom ~= nil and n == 0 and now - last >= R.rampResetSeconds then
		b.pressureFrom = nil
	end
	if b.pressureFrom == nil then return math.min(R.rampStart, R.rampMax) end
	local steps = math.floor(math.max(now - b.pressureFrom, 0) / R.rampEverySeconds)
	return math.min(R.rampMax, R.rampStart + steps)
end
-- V4-D13: a steal by this player at world (x, z) (the nest): frenzySeconds of the full cap and a call to every candy
-- creature whose post is within frenzyStuds of it. The pressure starts too (so the calm ramp after it is not reset).
function Smarts.frenzy(world, userId, now, x, z)
	local b = board(world, userId)
	if not b or not finite(now) or not finite(x) or not finite(z) then return false end
	local R = Smarts.RELENTLESS
	b.frenzyUntil, b.frenzyX, b.frenzyZ = now + R.frenzySeconds, x, z
	b.pressureFrom = b.pressureFrom or now
	b.lastHunted = math.max(b.lastHunted or -math.huge, now)
	return true
end
-- V4-D13: the frenzy on this player now, { x, z, studs, untilAt }, or nil.
function Smarts.frenzyAt(world, userId, now)
	local b = board(world, userId)
	if not b or not finite(now) or b.frenzyUntil == nil or now >= b.frenzyUntil then return nil end
	return { x = b.frenzyX, z = b.frenzyZ, studs = Smarts.RELENTLESS.frenzyStuds, untilAt = b.frenzyUntil }
end

-- V4-D12: the houses as footprint discs. houseDisc: a house whose pivot (its ground centre) is (px, pz) and whose
-- bounding box is centred on (cx, cz) with flat size (sx, sz): a disc round the pivot that holds the whole box.
function Smarts.houseDisc(id, px, pz, cx, cz, sx, sz)
	if not (finite(px) and finite(pz) and finite(cx) and finite(cz) and finite(sx) and finite(sz)) then return nil end
	return { id = id, x = px, z = pz, r = math.max(sx, sz) / 2 + flat(px, pz, cx, cz) }
end
-- The live houses under `root` (Candy_Bioma_v1): CaramelV3.Houses' Models with a HouseId, as discs. Reads instances only.
function Smarts.houseDiscs(root)
	local list = {}
	local v3 = typeof(root) == "Instance" and root:FindFirstChild("CaramelV3") or nil
	local folder = v3 and v3:FindFirstChild("Houses")
	if not folder then return list end
	for _, house in ipairs(folder:GetChildren()) do
		if house:IsA("Model") and house:GetAttribute("HouseId") ~= nil then
			local frame, size = house:GetBoundingBox()
			local p = house:GetPivot().Position
			local disc = Smarts.houseDisc(house:GetAttribute("HouseId"), p.X, p.Z, frame.Position.X, frame.Position.Z, size.X, size.Z)
			if disc then table.insert(list, disc) end
		end
	end
	return list
end
-- The disc (of `discs`) whose radius plus `margin` holds (x, z), or nil.
function Smarts.inHouse(x, z, discs, margin)
	if not (finite(x) and finite(z)) then return nil end
	for _, d in ipairs(type(discs) == "table" and discs or {}) do
		if flat(x, z, d.x, d.z) < d.r + (margin or 0) then return d end
	end
	return nil
end
-- V4-D12: a creature's move from (px, pz) to (nx, nz), kept outside every disc grown by `margin` (default
-- HOUSE_MARGIN_STUDS): a point inside one goes out to its edge along the line from its centre (from the old point when it
-- stands on the centre), so the creature stops at the edge, or slides round it, and waits there. Returns x, z.
function Smarts.outsideHouses(px, pz, nx, nz, discs, margin)
	if not (finite(nx) and finite(nz)) then return nx, nz end
	margin = finite(margin) and margin or Smarts.HOUSE_MARGIN_STUDS
	local x, z = nx, nz
	for _ = 1, 2 do -- two passes: a push out of one disc never lands in a neighbour
		for _, d in ipairs(type(discs) == "table" and discs or {}) do
			local r = d.r + margin
			local dx, dz = x - d.x, z - d.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < r then
				if dist < 1e-6 then
					dx, dz = (finite(px) and px or d.x + 1) - d.x, (finite(pz) and pz or d.z) - d.z
					dist = math.sqrt(dx * dx + dz * dz)
					if dist < 1e-6 then dx, dz, dist = 1, 0, 1 end
				end
				x, z = d.x + dx / dist * (r + 1e-3), d.z + dz / dist * (r + 1e-3)
			end
		end
	end
	return x, z
end
-- V4-D9: puts a player under pressure from `from` (hunted until `at`), as if hunted since then: the cap is then
-- Smarts.cap(world, userId, at). For suites that need several hunters at once, and any caller that wants it.
function Smarts.press(world, userId, from, at)
	local b = board(world, userId)
	if not b or not finite(from) then return end
	b.pressureFrom = from
	b.lastHunted = finite(at) and at or from
end
-- RC4: called when a creature would notice its target. A relentless one starts its hunt only while fewer than the cap
-- (V4-D9: Smarts.cap, the ramp up to maxChasers) hunt that player (false: it stays calm this step and asks again on a
-- later step). Any other creature always may. The first hunter on a player starts its pressure.
function Smarts.engage(e, world, now)
	if not Smarts.profile(e.beast).relentless or e.huntFrom ~= nil then return true end
	local cap = Smarts.cap(world, e.userId, now)
	if Smarts.chasers(world, e.userId, now, e.id) >= cap then
		-- V4-D9: held back while it sees (or was called to) its player, a critter is not idle (PF2's IdleSeconds would
		-- send it home before the ramp lets it in): its idle clock restarts
		e.patrolSince = nil
		return false
	end
	local b = board(world, e.userId)
	if b then
		b.hunters[e.id] = e
		if finite(now) then
			b.pressureFrom = b.pressureFrom or now
			b.lastHunted = math.max(b.lastHunted or -math.huge, now)
		end
	end
	e.huntFrom = now
	return true
end

-- RC4: the strike ledger, shared by every script that requires this module (the beast server and the flyers' service
-- run in one server VM). claimStrike books a strike at strikeAt for `owner` (an encounter or a swarm id) on one player:
-- false when STRIKE_MAX strikes of other owners would then land within STRIKE_WINDOW of each other (try again on a later
-- step); force books it anyway (an attack whose timing never changes). Entries older than a second are dropped.
local ledgers = {}
function Smarts.claimStrike(userId, owner, strikeAt, now, force)
	if not finite(strikeAt) then return true end
	local key = userId or 0
	local list = ledgers[key] or {}
	ledgers[key] = list
	local clock = finite(now) and now or strikeAt
	local near = 0
	for i = #list, 1, -1 do
		local c = list[i]
		if c.at < clock - 1 then
			table.remove(list, i)
		elseif c.owner ~= owner and math.abs(c.at - strikeAt) < Smarts.STRIKE_WINDOW then
			near += 1
		end
	end
	if near >= Smarts.STRIKE_MAX and force ~= true then return false end
	table.insert(list, { at = strikeAt, owner = owner })
	return true
end
-- An owner's booked strikes go (its encounter ended or its attack was called off); forget drops a player's ledger.
function Smarts.releaseStrikes(userId, owner)
	local list = ledgers[userId or 0]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i].owner == owner then table.remove(list, i) end
	end
end
function Smarts.forgetStrikes(userId)
	ledgers[userId or 0] = nil
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
	-- V4-D13: a steal's frenzy calls every candy creature whose post lies within frenzyStuds of the nest
	local f = Smarts.frenzyAt(world, e.userId, now)
	if f and Smarts.profile(e.beast).relentless and flat(f.x, f.z, e.home.x, e.home.z) <= f.studs then return true end
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
