-- Pure ambush relocation (M4.7). Silueta quietly moves its patrol near an objective on a server timer.
-- Inputs are positions and timers passed by value plus one roll in [0, 1]. It never reads where anyone
-- looks: no orientation, view or sight input exists here, by design (docs/mechanics/wildbound-fair-strike.md).
local Ambush = {}

Ambush.CONSTANTS = table.freeze({
	MIN_PLAYER_DISTANCE = 40, -- every live player this far from both the guardian and the anchor
	HUNT_QUIET_SECONDS = 20, -- no relocation this soon after a hunt
	RETRY_SECONDS = 15, -- a skipped attempt is retried after this long
	TOTEM_RANGE = 60, -- a totem holder this close doubles an anchor's weight
	DAY_MIN = 90, DAY_MAX = 150, NIGHT_MIN = 60, NIGHT_MAX = 90,
	SAME_PLACE = 1, -- an anchor this close to the guardian is where it already is
})
local K = Ambush.CONSTANTS

local ANCHORS = table.freeze({
	table.freeze({ id = "Home", x = 0, z = -85, weight = 30 }),
	table.freeze({ id = "NestSide", x = 40, z = -125, weight = 20 }),
	table.freeze({ id = "RuinEast", x = 55, z = -38, weight = 15 }),
	table.freeze({ id = "RuinWest", x = -30, z = -45, weight = 15 }),
	table.freeze({ id = "WestHollow", x = -40, z = -110, weight = 10 }),
	table.freeze({ id = "SouthGrove", x = 40, z = -140, weight = 10 }),
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function distance(x1, z1, x2, z2)
	return math.sqrt((x1 - x2) ^ 2 + (z1 - z2) ^ 2)
end

-- Fresh, editable copies, all active.
function Ambush.anchors()
	local list = {}
	for _, anchor in ipairs(ANCHORS) do
		table.insert(list, { id = anchor.id, x = anchor.x, z = anchor.z, weight = anchor.weight, active = true })
	end
	return list
end

-- Seconds until the next attempt: uniform over the day or night range by roll.
function Ambush.nextDelay(phase, roll)
	if not finite(roll) then roll = 0 end
	roll = math.clamp(roll, 0, 1)
	if phase == "Night" then return K.NIGHT_MIN + (K.NIGHT_MAX - K.NIGHT_MIN) * roll end
	return K.DAY_MIN + (K.DAY_MAX - K.DAY_MIN) * roll
end

-- Active anchors with p = w / sum(w). A totem holder within TOTEM_RANGE doubles that anchor's weight first.
function Ambush.weights(anchors, players)
	local list, total = {}, 0
	for _, anchor in ipairs(type(anchors) == "table" and anchors or {}) do
		if type(anchor) == "table" and anchor.active == true and finite(anchor.weight) and anchor.weight > 0
			and finite(anchor.x) and finite(anchor.z) then
			local weight = anchor.weight
			for _, player in ipairs(type(players) == "table" and players or {}) do
				if player.totem == true and finite(player.x) and finite(player.z)
					and distance(player.x, player.z, anchor.x, anchor.z) <= K.TOTEM_RANGE then
					weight *= 2
					break
				end
			end
			table.insert(list, { id = anchor.id, x = anchor.x, z = anchor.z, weight = weight })
			total += weight
		end
	end
	for _, item in ipairs(list) do item.p = item.weight / total end
	return list
end

local function stay(reason)
	return { move = false, reason = reason }
end

-- input = { now, nextAt, mode, roll, players = { {x, z, totem?} }, anchors, guardianX, guardianZ,
--           lastHuntAt, anyPlayerInFog }. Returns { move, anchorId?, x?, z?, reason }.
function Ambush.pick(input)
	if type(input) ~= "table" or not finite(input.now) or not finite(input.nextAt) or not finite(input.roll)
		or input.roll < 0 or input.roll > 1 or not finite(input.guardianX) or not finite(input.guardianZ)
		or type(input.players) ~= "table" then
		return stay("badInput")
	end
	for _, player in ipairs(input.players) do
		if type(player) ~= "table" or not finite(player.x) or not finite(player.z) then return stay("badInput") end
	end
	if input.now < input.nextAt then return stay("notYet") end
	if input.mode ~= "Patrol" then return stay("notPatrol") end
	if input.anyPlayerInFog ~= true then return stay("nobodyInFog") end
	if finite(input.lastHuntAt) and input.now - input.lastHuntAt < K.HUNT_QUIET_SECONDS then return stay("recentHunt") end
	for _, player in ipairs(input.players) do
		if distance(player.x, player.z, input.guardianX, input.guardianZ) < K.MIN_PLAYER_DISTANCE then
			return stay("playerNearGuardian")
		end
	end
	local candidates = {}
	for _, anchor in ipairs(type(input.anchors) == "table" and input.anchors or {}) do
		local allowed = type(anchor) == "table" and finite(anchor.x) and finite(anchor.z)
			and distance(anchor.x, anchor.z, input.guardianX, input.guardianZ) >= K.SAME_PLACE
		if allowed then
			for _, player in ipairs(input.players) do
				if distance(player.x, player.z, anchor.x, anchor.z) < K.MIN_PLAYER_DISTANCE then allowed = false; break end
			end
		end
		if allowed then table.insert(candidates, anchor) end
	end
	local weighted = Ambush.weights(candidates, input.players)
	if #weighted == 0 then return stay("noAnchor") end
	local cumulative = 0
	for index, item in ipairs(weighted) do
		cumulative += item.p
		if input.roll < cumulative or index == #weighted then
			return { move = true, anchorId = item.id, x = item.x, z = item.z, reason = "moved" }
		end
	end
	return stay("noAnchor")
end

return Ambush
