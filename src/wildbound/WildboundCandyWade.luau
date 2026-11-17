-- Caramelo v4 wading (odd/tasks/wildbound-caramelo-v2.md V4-D2): the chocolate is 3.5 studs deep and walk-through;
-- a player wading in it moves at FACTOR of their speed, the creatures are not slowed. Pure rules for
-- WildboundCandyWadeService, which every STEP seconds probes each player's root and sets or clears the server-only
-- player attribute ATTRIBUTE (the factor while wading, nil otherwise); WildboundServer.applyCarry, the one WalkSpeed
-- writer, multiplies its own freshly computed speed by it (Wade.speed is the same rule), so nothing stacks and leaving
-- the chocolate restores the speed exactly. Server only (ServerStorage), no services, no clock.
-- Rules: WildboundCandyWade_Test.
local Wade = {}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

Wade.FACTOR = 0.6
Wade.MIN_FACTOR = 0.3 -- applyCarry never slows below this share, whatever the attribute says
Wade.ATTRIBUTE = "WildboundCandyWade"
Wade.FEET_UNDER = 1 -- feet this far under the surface wade; a deck, a dock or a platform stands over it
Wade.STEP = 0.15 -- seconds between two probes

-- speed(speed, factor) -> the walk speed with the wading factor (no factor, junk or >= 1: unchanged).
function Wade.speed(speed, factor)
	if not finite(speed) or not finite(factor) or factor >= 1 then return speed end
	return speed * math.max(factor, Wade.MIN_FACTOR)
end

-- probe(V3, centre, floorTop, rootPosition, rootHalfHeight, hipHeight, isR6) -> { liquid, feetY, surface }: the signed
-- distance to the chocolate at the root's plot point (negative inside), the feet's height (an R6 rig's legs are 2
-- studs under its root; an R15 rig stands HipHeight under it) and the chocolate's surface.
function Wade.probe(V3, centre, floorTop, rootPosition, rootHalfHeight, hipHeight, isR6)
	local legs = isR6 and 2 or (finite(hipHeight) and hipHeight or 2)
	local half = finite(rootHalfHeight) and rootHalfHeight or 1
	return {
		liquid = V3.liquidDistance(rootPosition.X - centre.x, rootPosition.Z - centre.z),
		feetY = rootPosition.Y - half - legs,
		surface = V3.surfaceY(floorTop),
	}
end

-- wading(was, info) -> whether the player wades. info: { liquid, feetY, surface, airborne, seated, alive }. In the
-- chocolate (liquid < 0) with the feet FEET_UNDER under its surface, alive and not seated. In the air (a jump) it keeps
-- `was` while over the chocolate, so a jump neither frees nor slows anyone; landing decides again.
function Wade.wading(was, info)
	if type(info) ~= "table" or info.alive ~= true or info.seated == true then return false end
	if not finite(info.liquid) or not finite(info.feetY) or not finite(info.surface) then return false end
	if info.liquid >= 0 then return false end
	if info.airborne == true then return was == true end
	return info.feetY < info.surface - Wade.FEET_UNDER
end

return table.freeze(Wade)
