-- Pueblo Gatito's place in the world (docs/design/wildbound-pueblo-gatito-move-plan.md PGM-D1; owner request 2026-11-18:
-- "dale, hacelo bioma aparte" and then "Sí, movelo": the kitten park, its own biome since PG-D1, moves from behind
-- Caramelo's cloud wall to its own side of the hub, the big4 south arm). One frame for the whole park: every park
-- position (paths, village, toys, nests, kitten posts, chests, the return portal, the arrival disc, the music rectangle)
-- is written park-local, (lx, lz) with lx from the gate (lx -260) to the far end (lx +260), and turned into world studs
-- here. Shared and pure: ReplicatedStorage, required by WildboundKittenPark, WildboundPraderaSites and
-- WildboundCandyKittens; WildboundPortal (the "parque" station), WildboundBiomes and WildboundBiomeLight (ARM) keep literal
-- copies, which their suites check against this module.
--   FRAME  origin (282, 600), yaw -90: local +x (gate -> far end) points to world +z (south, away from the hub), local +z
--          to world -x. So world(lx, lz) = (282 - lz, 600 + lx); the floor square is x 22..542, z 340..860, and the gate
--          arch at local (-254, 0) stands at world (282, 346), 21 studs south of the big4 road's end (282, 324.5).
--   ARM    the big4 south arm (x -3..597, z 337..937), the biome square: Pueblo Gatito replaces the volcanic decor.
--   V1     the frame the park was built in (K-D1..K-D21): origin (1208, -3), yaw 0, east of the cloud wall.
local Area = {}

local freeze = table.freeze

Area.VERSION = 2 -- 1: east of Caramelo's cloud wall (V1); 2: the big4 south arm
Area.ROOT_NAME = "PuebloGatito_v1"
Area.HALF = 260 -- the park floor is a 2 * HALF square, local x and z -HALF..HALF
Area.FLOOR_TOP = 0.5 -- the park floor's top (the plot's FLOOR_TOP)
Area.ORIGIN = freeze({ x = 282, z = 600 })
Area.YAW = -90 -- degrees; a multiple of 90 so every square stays axis-aligned and every number stays exact
Area.ARM = freeze({ minX = -3, maxX = 597, minZ = 337, maxZ = 937 })
Area.V1 = freeze({ x = 1208, z = -3, yaw = 0 })

-- exact sines and cosines for the four allowed yaws (no float noise in world numbers)
local TRIG = { [0] = { 1, 0 }, [90] = { 0, 1 }, [180] = { -1, 0 }, [270] = { 0, -1 } }
local function trig(yaw)
	local key = yaw % 360
	local t = TRIG[key]
	assert(t, "the park frame's yaw must be a multiple of 90: " .. tostring(yaw))
	return t[1], t[2]
end

-- A frame's world point: a CFrame.Angles(0, yaw, 0) turn of (lx, lz), then the origin.
-- With yaw y: x' = lx cos y + lz sin y, z' = -lx sin y + lz cos y (Roblox's turn about +Y).
local function turn(frame, lx, lz)
	local c, s = trig(frame.yaw)
	return frame.x + lx * c + lz * s, frame.z - lx * s + lz * c
end
local function unturn(frame, x, z)
	local c, s = trig(frame.yaw)
	local dx, dz = x - frame.x, z - frame.z
	return dx * c - dz * s, dx * s + dz * c
end

local CURRENT = freeze({ x = Area.ORIGIN.x, z = Area.ORIGIN.z, yaw = Area.YAW })

-- world(lx, lz) -> x, z: a park-local point in world studs.
function Area.world(lx, lz)
	return turn(CURRENT, lx, lz)
end

-- localOf(x, z) -> lx, lz: a world point in park-local studs.
function Area.localOf(x, z)
	return unturn(CURRENT, x, z)
end

-- worldYaw(yaw) -> degrees: a park-local yaw (0 = front toward local -z) in world degrees.
function Area.worldYaw(yaw)
	return (yaw or 0) + Area.YAW
end

-- frame() -> the park's CFrame at the floor's top: FRAME * CFrame.new(lx, 0, lz) is a park-local point on the floor.
function Area.frame()
	return CFrame.new(Area.ORIGIN.x, Area.FLOOR_TOP, Area.ORIGIN.z) * CFrame.Angles(0, math.rad(Area.YAW), 0)
end

-- pivot(lx, lz, yaw) -> the CFrame of a park item: its ground centre at (lx, lz) on the floor, turned by its local yaw.
function Area.pivot(lx, lz, yaw)
	return Area.frame() * CFrame.new(lx, 0, lz) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- rect(margin) -> { minX, maxX, minZ, maxZ }: the floor square in world studs, grown by margin (0 by default).
function Area.rect(margin)
	local m = margin or 0
	local h = Area.HALF + m
	local ax, az = Area.world(-h, -h)
	local bx, bz = Area.world(h, h)
	return freeze({ minX = math.min(ax, bx), maxX = math.max(ax, bx), minZ = math.min(az, bz), maxZ = math.max(az, bz) })
end

-- fromV1(x, z) -> x, z: a world point of the park as it was built (V1, east of the cloud wall) where it stands now.
function Area.fromV1(x, z)
	local lx, lz = unturn(Area.V1, x, z)
	return Area.world(lx, lz)
end

-- localOfV1(x, z) -> lx, lz: a V1 world point (the K-D tables) in park-local studs.
function Area.localOfV1(x, z)
	return unturn(Area.V1, x, z)
end

return freeze(Area)
