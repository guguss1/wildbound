-- Hub expansion T8 (docs/design/wildbound-hub-expansion.md section 7): the base zone rule, server only and pure. Each
-- base has an invisible BaseZone box (tag WildboundBaseZone, the base rim). A player is inside when the live root's
-- position, in the zone's own frame, is inside its half extents and height; leaving needs the half extents plus the
-- exit margin (hysteresis), so standing on the rim never flickers. The server steps it at STEP_HZ for players in the
-- hub disc and acts only on the owner's own zone. No touch events: the caller passes positions.
local BaseZone = {}

BaseZone.CONSTANTS = table.freeze({
	STEP_HZ = 4,
	-- Used when the zone part has no ExitMargin attribute.
	EXIT_MARGIN = 2,
	-- The "¡Estás a salvo!" banner: its time on screen (client) and the shortest gap between two (server).
	BANNER_SECONDS = 2.5,
	BANNER_COOLDOWN = 10,
})
local C = BaseZone.CONSTANTS

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- zone = { frame = CFrame, size = Vector3 (the box; size.Y is the height), margin = studs or nil }.
function BaseZone.contains(zone, position, margin)
	if type(zone) ~= "table" or typeof(zone.frame) ~= "CFrame" or typeof(zone.size) ~= "Vector3" then return false end
	if typeof(position) ~= "Vector3" then return false end
	local extra = finite(margin) and margin or 0
	local p = zone.frame:PointToObjectSpace(position)
	return math.abs(p.X) <= zone.size.X / 2 + extra and math.abs(p.Z) <= zone.size.Z / 2 + extra
		and math.abs(p.Y) <= zone.size.Y / 2 + extra
end

function BaseZone.new()
	return { inside = {}, shown = {} }
end

-- One step for one player: "Enter" on the step they walk in, "Leave" on the step they leave (past the margin, or
-- when they no longer have a zone), nil otherwise.
function BaseZone.step(tracker, key, zone, position)
	local was = tracker.inside[key] == true
	local margin = was and (finite(zone and zone.margin) and zone.margin or C.EXIT_MARGIN) or 0
	local now = BaseZone.contains(zone, position, margin)
	tracker.inside[key] = now or nil
	if now and not was then return "Enter" end
	if was and not now then return "Leave" end
	return nil
end

-- Egg loop: whether this player stands in their own base now (the hatch step refills the cradle only then).
function BaseZone.isInside(tracker, key)
	return type(tracker) == "table" and type(tracker.inside) == "table" and tracker.inside[key] == true
end

function BaseZone.forget(tracker, key)
	tracker.inside[key] = nil
end

-- True when this player's banner may show now (at most every BANNER_COOLDOWN seconds); records it.
function BaseZone.banner(tracker, key, now)
	if not finite(now) then return false end
	local last = tracker.shown[key]
	if last and now - last < C.BANNER_COOLDOWN then return false end
	tracker.shown[key] = now
	return true
end

-- The line under the banner. egg: "Incubating", "Banked" or nil; items: other items saved.
function BaseZone.line(H, egg, items)
	local parts = {}
	if egg == "Incubating" then table.insert(parts, H.safeEgg) elseif egg == "Banked" then table.insert(parts, H.safeEggBanked) end
	if finite(items) and items > 0 then table.insert(parts, H.safeItems:format(items)) end
	return table.concat(parts, H.safeJoin)
end

return BaseZone