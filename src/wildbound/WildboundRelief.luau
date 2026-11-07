-- Pure height rule for the expedition relief (docs/mechanics/wildbound-expedition-islands.md section 1, task R2).
-- The same rule lives in tools/plan_relief.py; 64 golden samples in ServerStorage.WildboundReliefLayout tie the two.
-- A segment runs from (ax, az) to (bx, bz): a flat crest crestWidth wide, flanks and tapered ends at slopeDeg. Its
-- height at a point is height * min(cross, along), and the map height is the floor top plus the highest segment.
-- No require, no game access: the world server, the inventory server and the tests pass the layout in.
local Relief = {}
Relief.__index = Relief

Relief.FLOOR_TOP = 0.5
local SLOPE_STEP = 0.25
local SLOPE_DIRECTIONS = 16
local LIMIT = 1e6

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < LIMIT
end

-- Precomputes each valid segment's frame; malformed or degenerate segments are ignored, so a bad row cannot lift
-- the whole map.
local function prepare(seg)
	if type(seg) ~= "table" then return nil end
	local ax, az, bx, bz = seg.ax, seg.az, seg.bx, seg.bz
	local height, crest, slope = seg.height, seg.crestWidth, seg.slopeDeg
	for _, value in ipairs({ ax, az, bx, bz, height, crest, slope }) do
		if not finite(value) then return nil end
	end
	local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	if length < 1e-6 or height <= 0 or crest < 0 or slope <= 0 or slope >= 90 then return nil end
	local run = height / math.tan(math.rad(slope))
	return {
		mx = (ax + bx) / 2, mz = (az + bz) / 2, ux = (bx - ax) / length, uz = (bz - az) / length,
		halfLength = length / 2, halfCrest = crest / 2, run = run, height = height,
		reach = length / 2 + crest / 2 + 2 * run,
	}
end

function Relief.new(layout)
	local segments = {}
	if type(layout) == "table" and type(layout.segments) == "table" then
		for _, seg in ipairs(layout.segments) do
			local prepared = prepare(seg)
			if prepared then table.insert(segments, prepared) end
		end
	end
	return setmetatable({ segments = segments }, Relief)
end

function Relief:heightAt(x, z)
	if not finite(x) or not finite(z) then return Relief.FLOOR_TOP end
	local best = 0
	for _, s in ipairs(self.segments) do
		local px, pz = x - s.mx, z - s.mz
		if math.abs(px) <= s.reach and math.abs(pz) <= s.reach then
			local t = px * s.ux + pz * s.uz
			local d = -px * s.uz + pz * s.ux
			local cross = math.clamp((s.halfCrest + s.run - math.abs(d)) / s.run, 0, 1)
			local along = math.clamp((s.halfLength + s.run - math.abs(t)) / s.run, 0, 1)
			best = math.max(best, s.height * math.min(cross, along))
		end
	end
	return Relief.FLOOR_TOP + best
end

-- Steepest one-sided rise over 16 directions, in degrees. The relief is piecewise planar, so this reads the real
-- face slope and never overshoots at a crease the way a central difference does.
function Relief:slopeAt(x, z)
	if not finite(x) or not finite(z) then return 0 end
	local here = self:heightAt(x, z)
	local worst = 0
	for k = 0, SLOPE_DIRECTIONS - 1 do
		local angle = 2 * math.pi * k / SLOPE_DIRECTIONS
		local rise = math.abs(self:heightAt(x + SLOPE_STEP * math.cos(angle), z + SLOPE_STEP * math.sin(angle)) - here)
		worst = math.max(worst, rise / SLOPE_STEP)
	end
	return math.deg(math.atan(worst))
end

return table.freeze(Relief)
