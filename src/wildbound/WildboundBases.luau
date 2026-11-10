-- Nest Heist hub (docs/maps/wildbound-hub.md): pure rules for the hub's personal bases and the walkable link from the
-- camp. No services, no instances, no clock: numbers and tables in, answers out. The hub script and the stations
-- module apply them on the server.
local Bases = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- HB-T1: the link. Until the forest shift (open-world gaps S1) the hub is previewed away from the forest, so a straight
-- paved path joins the camp to the hub's NW trail (the trail that faces the camp). LINK_END is that trail's outer end
-- in the hub frame (assets/maps/hub-layout/hub-bases-v1.json, entrances NW, trail.to). The path starts LINK_INSET studs
-- from the camp centre (inside the 35-stud camp circle) and overlaps the trail by LINK_OVERLAP studs.
Bases.LINK_END = table.freeze({ x = -112, z = -90 })
Bases.LINK_INSET = 24
Bases.LINK_OVERLAP = 4
Bases.LINK_WIDTH = 12

function Bases.link(campX, campZ, hubX, hubZ)
	if not (finite(campX) and finite(campZ) and finite(hubX) and finite(hubZ)) then return nil end
	local endX, endZ = hubX + Bases.LINK_END.x, hubZ + Bases.LINK_END.z
	local dx, dz = endX - campX, endZ - campZ
	local span = math.sqrt(dx * dx + dz * dz)
	if span <= Bases.LINK_INSET then return nil end
	local ux, uz = dx / span, dz / span
	local fromX, fromZ = campX + ux * Bases.LINK_INSET, campZ + uz * Bases.LINK_INSET
	local toX, toZ = endX + ux * Bases.LINK_OVERLAP, endZ + uz * Bases.LINK_OVERLAP
	local length = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
	return { fromX = fromX, fromZ = fromZ, toX = toX, toZ = toZ, width = Bases.LINK_WIDTH, length = length,
		centreX = (fromX + toX) / 2, centreZ = (fromZ + toZ) / 2, dirX = ux, dirZ = uz }
end

-- HB-T2: base slots. Each player gets the lowest free slot when they join and keeps it while present (a respawn or a
-- repeated join keeps it); it is released when they leave. A player beyond SLOTS gets no base and uses the camp.
Bases.SLOTS = 8
local function validUser(userId)
	return finite(userId) and userId == math.floor(userId) and userId ~= 0
end
function Bases.new(count)
	local slots = finite(count) and math.max(1, math.floor(count)) or Bases.SLOTS
	return { count = slots, owners = {}, byUser = {} }
end
function Bases.assign(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	local held = registry.byUser[userId]
	if held then return held end
	for slot = 1, registry.count do
		if registry.owners[slot] == nil then
			registry.owners[slot], registry.byUser[userId] = userId, slot
			return slot
		end
	end
	return nil
end
function Bases.release(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	local slot = registry.byUser[userId]
	if not slot then return nil end
	registry.byUser[userId], registry.owners[slot] = nil, nil
	return slot
end
function Bases.slotOf(registry, userId)
	if type(registry) ~= "table" or not validUser(userId) then return nil end
	return registry.byUser[userId]
end
function Bases.ownerOf(registry, slot)
	if type(registry) ~= "table" then return nil end
	return registry.owners[slot]
end
-- The name sign: "Base libre" while nobody owns it (decision HB4), "Base de <name>" with the owner's display name.
function Bases.signText(Text, name)
	if type(name) ~= "string" or name == "" then return Text.HUB.freeSign end
	return Text.HUB.ownedSign:format(name)
end

return Bases
