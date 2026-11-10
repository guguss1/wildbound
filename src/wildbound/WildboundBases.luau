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

return Bases
