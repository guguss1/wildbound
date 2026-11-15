-- CE3 / T08a + T08b (odd/tasks/wildbound-caramelo.md, odd/tasks/wildbound-2-0.md; pack 04_ENTORNO/03 "Portal"): the
-- return portals' pure rules. A portal takes its user home to their own base pad in the hub after 5 s with no threat
-- nearby and a 2 s channel, then rests 30 s for that player (Balance.portal; the Caramelo layout's Portal marker). A
-- threat noted during the channel, stepping away, leaving the portal's range or dying cuts it, with no rest. The egg in
-- the arms rides along (pack: a legitimate teleport never resets or consumes the egg), so carrying is never a refusal.
-- Numbers, tables and the caller's clock in, answers out: WildboundPortalService applies them on the server.
local Portal = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

Portal.CONFIG = table.freeze({
	calmSeconds = 5, -- seconds with no threat before a channel may start (Balance.portal.calmSeconds)
	channelSeconds = 2, -- seconds of channel before the teleport (Balance.portal.channelSeconds)
	cooldown = 30, -- seconds a player waits between two uses, any station (Balance.portal.cooldown)
	useRange = 10, -- studs from the server-side root to the station's centre; the prompt reaches a little less
	allowance = 2, -- studs of latency slack on top of useRange
	moveTolerance = 3, -- studs the root may drift from where the channel started
	threatRadius = 40, -- studs within which an awake nest parent counts as a threat
	signalSeconds = 1, -- how long a server stamp (a beast on the player, a bat hit) keeps counting as a threat
	hurtMin = 3, -- health a sample must drop to count as a hit (Play: regeneration resets dip about 1 point a second)
})
local C = Portal.CONFIG

-- What happens to the carried egg: it stays in the arms (decision CE3; the base banks it on arrival as usual).
Portal.CARRY = "keep"

-- The stations, in world coordinates. "candy": the Candy builder's Portal model (Candy_Bioma_v1.Portal, the layout's
-- Portal marker (160, 0) on the plot centre (612, -3)). "build": the service builds it at server start (place file never
-- saved), in the forest's deep fog, south-west, on a clear patch of floor 55 studs from La Silueta's home.
Portal.STATIONS = table.freeze({
	table.freeze({ id = "caramelo", source = "candy", x = 772, z = -3 }),
	table.freeze({ id = "bosque", source = "build", x = -28, z = -132, y = 1, yaw = 90 }),
})

function Portal.station(id)
	for _, station in ipairs(Portal.STATIONS) do
		if station.id == id then return station end
	end
	return nil
end

-- La Silueta's published threat levels that count (WildboundThreatLevel: Near and Chase; Distant and Safe do not).
Portal.SILUETA_LEVELS = table.freeze({ Near = true, Chase = true })

function Portal.new()
	return { lastThreatAt = -math.huge, cooldownUntil = -math.huge, channel = nil }
end

-- A threat seen at `at`; an older stamp never moves the calm clock back.
function Portal.noteThreat(st, at)
	if type(st) ~= "table" or not finite(at) then return end
	if at > st.lastThreatAt then st.lastThreatAt = at end
end

function Portal.calmLeft(st, now)
	if type(st) ~= "table" or not finite(now) then return C.calmSeconds end
	return math.max(0, st.lastThreatAt + C.calmSeconds - now)
end

function Portal.cooldownLeft(st, now)
	if type(st) ~= "table" or not finite(now) then return C.cooldown end
	return math.max(0, st.cooldownUntil - now)
end

local function recent(stamp, now)
	return finite(stamp) and stamp <= now + 0.05 and now - stamp <= C.signalSeconds
end

-- signals: { x, z, siluetaLevel, beastEngagedAt, batHitAt, ragdollUntil, hurt, adults = { { x, z }, ... } }.
-- Returns true and the first reason ("Silueta", "Beast", "Hit", "Parent"), or false.
function Portal.threatened(signals, now)
	if type(signals) ~= "table" or not finite(now) then return false end
	if Portal.SILUETA_LEVELS[signals.siluetaLevel] then return true, "Silueta" end
	if recent(signals.beastEngagedAt, now) then return true, "Beast" end
	if recent(signals.batHitAt, now) or signals.hurt == true
		or (finite(signals.ragdollUntil) and signals.ragdollUntil > now) then
		return true, "Hit"
	end
	if type(signals.adults) == "table" and finite(signals.x) and finite(signals.z) then
		for _, adult in ipairs(signals.adults) do
			if type(adult) == "table" and finite(adult.x) and finite(adult.z) then
				local dx, dz = adult.x - signals.x, adult.z - signals.z
				if dx * dx + dz * dz <= C.threatRadius * C.threatRadius then return true, "Parent" end
			end
		end
	end
	return false
end

local function inRange(distance)
	return finite(distance) and distance >= 0 and distance <= C.useRange + C.allowance
end

-- ctx: { enabled, alive, ragdolled, distance, hasDestination, station, x, z }. On success the channel opens.
-- Refusals, in order: Disabled, Dead, TooFar, Busy, Cooldown, Threat, NoBase.
function Portal.request(st, ctx, now)
	if type(st) ~= "table" or type(ctx) ~= "table" or not finite(now) then return false, "Invalid" end
	if ctx.enabled ~= true then return false, "Disabled" end
	if ctx.alive ~= true or ctx.ragdolled == true then return false, "Dead" end
	if not inRange(ctx.distance) then return false, "TooFar" end
	if st.channel then return false, "Busy" end
	if Portal.cooldownLeft(st, now) > 0 then return false, "Cooldown" end
	if Portal.calmLeft(st, now) > 0 then return false, "Threat" end
	if ctx.hasDestination ~= true then return false, "NoBase" end
	st.channel = { station = ctx.station, startedAt = now, endsAt = now + C.channelSeconds, x = ctx.x, z = ctx.z }
	return true
end

function Portal.cancel(st)
	if type(st) == "table" then st.channel = nil end
end

-- ctx: { alive, x, z, distance }. "Idle" (no channel), "Channeling", "Ready" (the caller moves them, then complete),
-- or "Interrupted" with "Dead", "Threat" or "Moved" (the channel closes, no rest).
function Portal.step(st, ctx, now)
	if type(st) ~= "table" or not st.channel then return "Idle" end
	local channel = st.channel
	local function cut(reason)
		st.channel = nil
		return "Interrupted", reason
	end
	if type(ctx) ~= "table" or ctx.alive ~= true then return cut("Dead") end
	if st.lastThreatAt >= channel.startedAt then return cut("Threat") end
	if not finite(ctx.x) or not finite(ctx.z) or not finite(channel.x) or not finite(channel.z) then return cut("Moved") end
	local dx, dz = ctx.x - channel.x, ctx.z - channel.z
	if dx * dx + dz * dz > C.moveTolerance * C.moveTolerance or not inRange(ctx.distance) then return cut("Moved") end
	if finite(now) and now >= channel.endsAt then return "Ready" end
	return "Channeling"
end

-- The teleport happened: the channel closes and the portal rests for this player.
function Portal.complete(st, now)
	if type(st) ~= "table" then return end
	st.channel = nil
	if finite(now) then st.cooldownUntil = now + C.cooldown end
end

return Portal
