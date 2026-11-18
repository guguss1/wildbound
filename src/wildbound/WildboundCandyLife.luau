-- Caramelo v6 "life on the map" (odd/tasks/wildbound-caramelo-v2.md V6-D6; docs/design/wildbound-caramelo-v3-plan.md
-- V6-D50 on). Pure rules for WildboundCandyLifeClient, which shows decoration only, on the local client only, while its
-- player is in the candy biome: gummy birds circling over the meadows, caramel butterflies fluttering at the houses and
-- the lollipop avenue, chocolate fish jumping out of the river and the lake now and then. No gameplay effect.
-- Here: the budgets per device, where each creature lives (plot coordinates: x east, z as in the world, from the plot
-- centre, like WildboundCandyLayout), its path at time t, and the nearest-N pick that culls what is far from the camera.
-- The layout modules live where clients cannot read them, so the few numbers needed are copied here; the house rows are
-- the layout's and WildboundCandyLife_Test pins every copy to the real layout. Every flock centre and fish spot below
-- was checked against the layout (the suite holds the rules). Shared (ReplicatedStorage), no services, no clock: every
-- time is passed in. Every number is a hypothesis to check in Studio Play.
local Life = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Copies of the layout (WildboundCandyLayout, WildboundCandyV3Layout), pinned by the suite.
-- Caramelo v8 (owner request 2026-11-17, "make the Reino Caramelo map a bit bigger, in width and in length, so there is
-- more space between things"; docs/design/wildbound-caramelo-v8-plan.md, V8-D1): the plot grows 1.3 times about its
-- centre, which moves (612, -3) -> (672, -3); HALF 200 -> 260. Positions below keep their v7 literals, mapped at load
-- by v8() (x S); sizes and radii stay, as in the layout.
local V8_S = 1.3
local function v8(n) return n * V8_S end
Life.ROOT_NAME = "Candy_Bioma_v1"
Life.CENTRE = freeze({ x = 672, z = -3 })
Life.HALF = 260
Life.FLOOR_TOP = 0.5
Life.CHOCO_DEPTH = 3.5 -- the chocolate's surface stands this far over the floor's top
local function scaled(rows)
	for _, row in ipairs(rows) do row.x, row.z = v8(row.x), v8(row.z) end
	return rows
end
-- V8-D1: the houses' spots scale like WildboundCandyV3Layout.HOUSES; their footprints stay.
Life.HOUSES = freeze(scaled({
	{ id = "H1", x = -148, z = 166, r = 28 },
	{ id = "H2", x = -100, z = 175, r = 15 },
	{ id = "H3", x = -158, z = -150, r = 22.4 },
	{ id = "H4", x = 178, z = 100, r = 20 },
	{ id = "H5", x = -168, z = -82, r = 21 },
	{ id = "H6", x = 150, z = -170, r = 16 },
	{ id = "H7", x = 110, z = 178, r = 20 },
}))

-- Budgets of creatures shown at once. Touch devices get half; Efectos suaves (the world gui's Reduced) shows none:
-- everything here is motion.
Life.FLOCK_SIZE = 3 -- birds per flock
Life.PER_SITE = 2 -- butterflies per site
Life.BUDGETS = freeze({
	desktop = { name = "desktop", birds = 12, butterflies = 16, fish = 6 },
	touch = { name = "touch", birds = 6, butterflies = 8, fish = 3 },
	soft = { name = "soft", birds = 0, butterflies = 0, fish = 0 },
})
-- Parts per creature: a butterfly is a body and two wings, a fish a body and a tail. V7-D4 (owner request 2026-11-17,
-- "a better bird model"): a gummy bird is a round body, a head, an orange beak, its eyes, a tail and two oval wings.
Life.PARTS = freeze({ bird = 7, butterfly = 3, fish = 2 })
-- Flat studs from the camera within which a flock, a butterfly site or a fish spot is shown (picked at 2 Hz).
Life.REACH = freeze({ birds = 320, butterflies = 120, fish = 150 })
Life.PICK_SECONDS = 0.5

function Life.budget(touch, soft)
	if soft == true then return Life.BUDGETS.soft end
	if touch == true then return Life.BUDGETS.touch end
	return Life.BUDGETS.desktop
end

-- Gummy birds -------------------------------------------------------------------------------------------------
-- The flocks circle over open meadow (off the chocolate, the houses and the cake tower), inside the plot.
-- { id, x, z (the circle's centre), r (its radius), alt (studs over the floor's top), dir (1 anticlockwise seen from
-- above, -1 clockwise), phase (radians), color (RGB) }. MIN_ALT clears the tallest piece in the open (mountain M1,
-- 40.7 studs); only the Gran Torta stands higher, and no flock comes near it.
Life.MIN_ALT = 46
Life.BIRD_SPEED = 9 -- studs per second along the circle
-- V8-D1: the circles' centres scale, their radii stay (each stays over open meadow, 10+ studs off the chocolate and
-- off the houses and the Torta; WildboundCandyLife_Test CL3 holds it).
Life.FLOCKS = freeze(scaled({
	{ id = "F1", x = -120, z = 40, r = 26, alt = 50, dir = 1, phase = 0, color = { 235, 70, 90 } },
	{ id = "F2", x = -80, z = -50, r = 24, alt = 53, dir = -1, phase = 1.3, color = { 120, 215, 90 } },
	{ id = "F3", x = 60, z = 150, r = 22, alt = 49, dir = 1, phase = 2.6, color = { 255, 205, 60 } },
	{ id = "F4", x = 130, z = -110, r = 22, alt = 52, dir = -1, phase = 3.9, color = { 255, 140, 60 } },
	{ id = "F5", x = -80, z = -160, r = 20, alt = 50, dir = 1, phase = 5.2, color = { 170, 110, 235 } },
	{ id = "F6", x = 150, z = 120, r = 20, alt = 54, dir = -1, phase = 0.7, color = { 235, 70, 90 } },
}))
local BIRD_TRAIL = 0.32 -- radians each bird trails the one before
local BIRD_RADIUS = { 0, 2.5, -2.5 } -- studs off the circle per bird of the flock
local BIRD_LIFT = { 0, 1.2, 2.4 }

-- birdPosition(flock, k, t) -> x, y, z: bird k's plot point at time t, y over the floor's top.
function Life.birdPosition(flock, k, t)
	t = finite(t) and t or 0
	local slot = ((k - 1) % Life.FLOCK_SIZE) + 1
	local angle = flock.phase + flock.dir * (t * Life.BIRD_SPEED / flock.r - (slot - 1) * BIRD_TRAIL)
	local radius = flock.r + BIRD_RADIUS[slot]
	local y = flock.alt + BIRD_LIFT[slot] + 1.5 * math.sin(t * 0.8 + slot)
	return flock.x + math.cos(angle) * radius, y, flock.z + math.sin(angle) * radius
end

-- Caramel butterflies -----------------------------------------------------------------------------------------
-- A pair flutters on the side of every house that faces the junction (the plot centre), just outside its footprint,
-- and round a few spots of the lollipop avenue (the right route; the candy "flowers").
-- V8-D1: both scale with the avenue (Avenue_W stays on its first leg's line).
Life.FLOWERS = freeze(scaled({
	{ id = "Avenue_W", x = -65, z = 95 },
	{ id = "Avenue_E", x = 60, z = 110 },
}))
Life.BUTTERFLY_COLORS = freeze({ { 255, 175, 70 }, { 255, 140, 190 }, { 255, 225, 120 } })
local HOUSE_GAP = 4 -- studs outside the footprint disc
local HOUSE_ARC = 1.2 -- radians either side of the face that looks at the junction
local FLOWER_RING = 3

local function hash(id)
	local h = 0
	local text = tostring(id)
	for i = 1, #text do h = (h * 31 + string.byte(text, i)) % 16777216 end
	return h
end

-- butterflySites() -> a new list of { id, x, z, r, ring, face, arc, phase, house (the house id, or nil) }.
function Life.butterflySites()
	local out = {}
	for _, house in ipairs(Life.HOUSES) do
		table.insert(out, { id = "House_" .. house.id, house = house.id, x = house.x, z = house.z, r = house.r,
			ring = house.r + HOUSE_GAP, face = math.atan2(-house.z, -house.x), arc = HOUSE_ARC,
			phase = (hash(house.id) % 628) / 100 })
	end
	for _, flower in ipairs(Life.FLOWERS) do
		table.insert(out, { id = flower.id, x = flower.x, z = flower.z, r = 0, ring = FLOWER_RING, face = 0, arc = math.pi,
			phase = (hash(flower.id) % 628) / 100 })
	end
	return out
end

-- butterflyPosition(site, k, t) -> x, y, z: butterfly k's plot point, y over the floor's top. It wanders along its
-- arc, in and out by 1.5 studs, and bobs with a quick flutter.
function Life.butterflyPosition(site, k, t)
	t = finite(t) and t or 0
	local p = site.phase + k * 2.1
	local angle = site.face + site.arc * math.sin(2 * math.pi * t / 11 + p)
	local radius = site.ring + 1.5 * math.sin(2 * math.pi * t / 5 + p * 1.7)
	local y = 4.5 + 1.5 * math.sin(2 * math.pi * t / 4.3 + p * 1.3) + 0.4 * math.sin(t * 9 + p)
	return site.x + math.cos(angle) * radius, y, site.z + math.sin(angle) * radius
end

-- Chocolate fish ----------------------------------------------------------------------------------------------
-- Jump spots in the river and the lake: { id, x, z, heading (radians; the jump runs along (cos, sin) in x, z, with the
-- river's flow) }. Each lies FISH_MARGIN studs inside the chocolate for the whole jump, off every bridge (and its
-- ramps), cookie platform and raft dock (the suite checks it against the real layout). period and phase are added.
Life.FISH_MARGIN = 3
Life.FISH_JUMP = freeze({ length = 7, height = 4, sink = 1, seconds = 1.2 })
local FISH_ROWS = {
	{ id = "River_N1", x = -6, z = 140, heading = -1.4 },
	{ id = "River_N2", x = 1, z = 93, heading = -1.22 },
	{ id = "River_N3", x = 8, z = 72, heading = -1.28 },
	-- V6-D66: River_S1 and Lake_1 stood where the lake's island (V3.ISLANDS I1) now is: moved up the river leg into the
	-- lake and to the lake's open east side
	{ id = "River_S1", x = 13.5, z = -46, heading = -1.27 },
	{ id = "Lake_1", x = 28, z = -82, heading = -1.3 },
	{ id = "Lake_2", x = 24, z = -100, heading = -2.3 },
	{ id = "Lake_3", x = 15, z = -112, heading = 0.4 },
	{ id = "Lake_4", x = -12, z = -108, heading = 0.7 },
	{ id = "River_S2", x = 28, z = -160, heading = 1.5 },
	{ id = "River_S3", x = 29.5, z = -185, heading = 1.54 },
}
-- V8-D1: a river spot scales (the river's points scale and its widths stay, so a spot on or near the centreline stays
-- there; the jump keeps its 7 studs and its heading). A lake spot moves with the big lake disc it lies in
-- (WildboundCandyV3Layout's withDisc: v7 (8, -98) -> (10.4, -127.4), radius 34.5 kept), like the cookie platforms,
-- dock B and the island that float in it, so it keeps its v7 water and clearances round them.
local LAKE_DISC_V7 = { x = 8, z = -98 }
do
	local list = {}
	for i, row in ipairs(FISH_ROWS) do
		local spot = table.clone(row)
		if string.sub(row.id, 1, 5) == "Lake_" then
			spot.x, spot.z = row.x + (v8(LAKE_DISC_V7.x) - LAKE_DISC_V7.x), row.z + (v8(LAKE_DISC_V7.z) - LAKE_DISC_V7.z)
		else
			spot.x, spot.z = v8(row.x), v8(row.z)
		end
		spot.period = 6 + (i % 4) * 1.25 -- seconds between jumps: 6 to 9.75
		spot.phase = (i * 2.3) % spot.period
		list[i] = spot
	end
	Life.FISH_SPOTS = freeze(list)
end

-- arcPoint(spot, u) -> { x, z, y (over the chocolate's surface), pitch (radians, nose up), heading } at progress u
-- (0..1) of a jump: a parabola from FISH_JUMP.sink under the surface up to FISH_JUMP.height and back under.
function Life.arcPoint(spot, u)
	local J = Life.FISH_JUMP
	u = math.clamp(finite(u) and u or 0, 0, 1)
	local rise = J.height + J.sink
	return {
		x = spot.x + math.cos(spot.heading) * J.length * u,
		z = spot.z + math.sin(spot.heading) * J.length * u,
		y = -J.sink + rise * 4 * u * (1 - u),
		pitch = math.atan2(rise * 4 * (1 - 2 * u), J.length),
		heading = spot.heading,
	}
end

-- fishJump(spot, t) -> the arc point plus u while the spot's fish is in the air, else nil (under the chocolate).
function Life.fishJump(spot, t)
	if not finite(t) then return nil end
	local cycle = (t + spot.phase) % spot.period
	if cycle > Life.FISH_JUMP.seconds then return nil end
	local u = cycle / Life.FISH_JUMP.seconds
	local point = Life.arcPoint(spot, u)
	point.u = u
	return point
end

-- Shared ------------------------------------------------------------------------------------------------------
-- flap(t, hz, degrees, phase) -> a wing's angle in radians.
function Life.flap(t, hz, degrees, phase)
	if not (finite(t) and finite(hz) and finite(degrees)) then return 0 end
	return math.rad(degrees) * math.sin(2 * math.pi * (t * hz + (finite(phase) and phase or 0)))
end

-- nearest(sites, eye, limit, reach) -> a new list of at most `limit` sites ({ id, x, z }) within `reach` flat studs of
-- the eye ({ x, z }, plot coordinates), nearest first, ties by id. The input list is not changed.
function Life.nearest(sites, eye, limit, reach)
	local out = {}
	if type(sites) ~= "table" or type(eye) ~= "table" or not (finite(eye.x) and finite(eye.z)) or not finite(limit)
		or limit < 1 or not finite(reach) then
		return out
	end
	local scored = {}
	for _, site in ipairs(sites) do
		if finite(site.x) and finite(site.z) then
			local d = math.sqrt((site.x - eye.x) ^ 2 + (site.z - eye.z) ^ 2)
			if d <= reach then table.insert(scored, { site = site, d = d, id = tostring(site.id) }) end
		end
	end
	table.sort(scored, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		return a.id < b.id
	end)
	for i = 1, math.min(math.floor(limit), #scored) do out[i] = scored[i].site end
	return out
end

-- plan(budget, eye) -> { flocks, sites, spots }: what is shown for a camera at eye (plot coordinates): whole flocks and
-- butterfly pairs within the budget, the nearest first, nothing beyond REACH.
local SITES = freeze(Life.butterflySites())
function Life.plan(budget, eye)
	budget = type(budget) == "table" and budget or Life.BUDGETS.soft
	return {
		flocks = Life.nearest(Life.FLOCKS, eye, math.floor((budget.birds or 0) / Life.FLOCK_SIZE), Life.REACH.birds),
		sites = Life.nearest(SITES, eye, math.floor((budget.butterflies or 0) / Life.PER_SITE), Life.REACH.butterflies),
		spots = Life.nearest(Life.FISH_SPOTS, eye, budget.fish or 0, Life.REACH.fish),
	}
end

-- plotFrame(x, y, z, sizeX, sizeY, sizeZ) -> { x, z (the plot centre in world studs), top (the floor's top) } from the
-- live floor part (Candy_Bioma_v1.Ground.Floor), or the layout's numbers when the floor is missing or bad.
function Life.plotFrame(x, y, z, sizeX, sizeY, sizeZ)
	if finite(x) and finite(y) and finite(z) and finite(sizeX) and finite(sizeY) and finite(sizeZ) and sizeX > 0 then
		return { x = x, z = z, top = y + sizeY / 2 }
	end
	return { x = Life.CENTRE.x, z = Life.CENTRE.z, top = Life.FLOOR_TOP }
end

return freeze(Life)
