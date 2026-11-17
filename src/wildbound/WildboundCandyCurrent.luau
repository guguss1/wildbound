-- Caramelo v6, proposal 3: the river current (odd/tasks/wildbound-caramelo-v2.md V6-D3; docs/design/
-- wildbound-caramelo-v3-plan.md V6-D30 on). The chocolate flows from M1's waterfall (V3.RIVER[1], north) to the south
-- edge (the last V3.RIVER point). flow(V3, x, z) is a pure, layout-derived flow field in plot coordinates (x east, z as
-- in the world, like WildboundCandyV3Layout): it points downstream along the nearest river leg, RIVER_SPEED studs/s on
-- the river legs, LAKE_SPEED inside the lake (V3.LAKE discs), 0 out of the chocolate. Near a joint the legs within JOIN
-- studs of the nearest one blend their directions (weights fall smoothly with the distance), so the direction never
-- jumps; the speed eases from the river's to the lake's over LAKE_BLEND studs inside a disc's edge, and from 0 at the
-- bank to full over EDGE studs inside it.
-- Users: WildboundCandyRaft (the raft drifts with flow while afloat, through Raft.area(V3, centre, Current.flow)) and
-- WildboundCandyWadeService (the server sets the wader's push, push / pushVector, on the player attribute
-- PUSH_ATTRIBUTE; WildboundCandyCurrentClient applies it to its own character). The creatures are never pushed.
-- Shared (ReplicatedStorage), no services, no clock, no require. Rules: WildboundCandyCurrent_Test.
local Current = {}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Current.finite = finite

Current.RIVER_SPEED = 4 -- studs/s on the river legs (V6-D3)
Current.LAKE_SPEED = 1.5 -- studs/s inside a lake disc (V6-D3)
Current.WADE_SPEED = 1.5 -- studs/s at most on a wader (V6-D3)
Current.JOIN = 6 -- studs: legs this much farther than the nearest still blend their direction in (V6-D30)
Current.LAKE_BLEND = 8 -- studs inside a lake disc's edge where the speed reaches LAKE_SPEED (V6-D30)
Current.EDGE = 2 -- studs inside the bank where the speed reaches full (V6-D30)
Current.PUSH_ATTRIBUTE = "WildboundCandyCurrent" -- the player attribute (Vector3, world studs/s) the server sets
Current.PUSH_STEP = 0.05 -- studs/s: the push is rounded to this, so the attribute changes only when it matters
Current.PUSH_MIN = 0.05 -- studs/s: a weaker push is none

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end

-- flow(V3, x, z) -> vx, vz: the current at plot point (x, z) in studs/s (0, 0 out of the chocolate or for junk).
function Current.flow(V3, x, z)
	if type(V3) ~= "table" or type(V3.RIVER) ~= "table" or not finite(x) or not finite(z) then return 0, 0 end
	local liquid = V3.liquidDistance(x, z)
	if not finite(liquid) or liquid >= 0 then return 0, 0 end
	local river = V3.RIVER
	local legs = #river - 1
	if legs < 1 then return 0, 0 end
	local best = math.huge
	for i = 1, legs do
		local a, b = river[i], river[i + 1]
		best = math.min(best, V3.segmentDistance(x, z, a[1], a[2], b[1], b[2]))
	end
	local vx, vz = 0, 0
	for i = 1, legs do
		local a, b = river[i], river[i + 1]
		local share = 1 - (V3.segmentDistance(x, z, a[1], a[2], b[1], b[2]) - best) / Current.JOIN
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		if share > 0 and length > 0 then
			local weight = share * share
			vx += weight * dx / length
			vz += weight * dz / length
		end
	end
	local norm = math.sqrt(vx * vx + vz * vz)
	if norm < 1e-6 then return 0, 0 end
	local lake = math.huge
	for _, disc in ipairs(V3.LAKE or {}) do lake = math.min(lake, flat(x, z, disc.x, disc.z) - disc.r) end
	local inLake = finite(lake) and math.clamp(-lake / Current.LAKE_BLEND, 0, 1) or 0
	local speed = Current.RIVER_SPEED + (Current.LAKE_SPEED - Current.RIVER_SPEED) * inLake
	speed *= math.clamp(-liquid / Current.EDGE, 0, 1)
	return vx / norm * speed, vz / norm * speed
end

-- speedAt(V3, x, z) -> the current's speed at plot point (x, z), studs/s.
function Current.speedAt(V3, x, z)
	local vx, vz = Current.flow(V3, x, z)
	return math.sqrt(vx * vx + vz * vz)
end

-- push(V3, x, z) -> px, pz: what a wader at plot point (x, z) feels, studs/s: the flow's direction, at most
-- WADE_SPEED (V6-D31: so 1.5 on the river legs and in the lake alike, easing to 0 at the bank).
function Current.push(V3, x, z)
	local vx, vz = Current.flow(V3, x, z)
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed <= Current.WADE_SPEED then return vx, vz end
	return vx / speed * Current.WADE_SPEED, vz / speed * Current.WADE_SPEED
end

local function rounded(value)
	return math.floor(value / Current.PUSH_STEP + 0.5) * Current.PUSH_STEP
end

-- pushVector(wading, px, pz) -> Vector3 (world studs/s, y 0) for the player attribute, or nil: nil unless the player
-- wades (WildboundCandyWade.wading: in the chocolate, alive, not seated) and the push is finite and at least PUSH_MIN.
-- Rounded to PUSH_STEP and never more than WADE_SPEED.
function Current.pushVector(wading, px, pz)
	if wading ~= true or not finite(px) or not finite(pz) then return nil end
	local speed = math.sqrt(px * px + pz * pz)
	if speed < Current.PUSH_MIN then return nil end
	if speed > Current.WADE_SPEED then px, pz = px / speed * Current.WADE_SPEED, pz / speed * Current.WADE_SPEED end
	px, pz = rounded(px), rounded(pz)
	if math.sqrt(px * px + pz * pz) < Current.PUSH_MIN then return nil end
	return Vector3.new(px, 0, pz)
end

-- applies(push, alive, seated) -> whether the client moves its character by the server's push this frame: a Vector3
-- no stronger than WADE_SPEED (plus rounding), a live humanoid, not seated (a rider is never pushed twice).
function Current.applies(push, alive, seated)
	if typeof(push) ~= "Vector3" or alive ~= true or seated == true then return false end
	local speed = push.Magnitude
	return finite(speed) and speed >= Current.PUSH_MIN and speed <= Current.WADE_SPEED + Current.PUSH_STEP
end

return table.freeze(Current)
