-- Pure atmosphere targets (delivery D1): whole-map fog by zone and time of day, blended by the replicated
-- clockTime. No services; the world client applies the targets to its local Lighting and restores on cleanup.
-- Numbers are hypotheses from docs/mechanics/wildbound-delivery-d.md section 1; the floors are contracts.
local Atmosphere = {}

-- density, offset, haze, fogStart, fogEnd per zone and time of day.
local ROWS = table.freeze({
	open = { Day = { 0.30, 0.15, 1.0, 70, 450 }, Dusk = { 0.40, 0.08, 1.8, 40, 260 }, Night = { 0.52, 0, 2.6, 25, 150 } },
	fog = { Day = { 0.40, 0.10, 1.6, 40, 240 }, Dusk = { 0.52, 0.04, 2.4, 28, 160 }, Night = { 0.62, 0, 3.4, 16, 100 } },
	camp = { Day = { 0.22, 0.15, 0.6, 90, 700 }, Dusk = { 0.30, 0.08, 1.0, 60, 380 }, Night = { 0.38, 0, 1.8, 40, 260 } },
})
-- Colours and light per time of day. ambientWeight 0 keeps the place's own Ambient and OutdoorAmbient.
local LIGHT = table.freeze({
	Day = { atmosphere = { 150, 160, 152 }, fog = { 104, 116, 110 }, ambient = { 62, 70, 84 }, outdoor = { 74, 82, 96 },
		ambientWeight = 0, brightness = 1, exposure = 0 },
	Dusk = { atmosphere = { 112, 104, 114 }, fog = { 66, 66, 84 }, ambient = { 62, 70, 84 }, outdoor = { 74, 82, 96 },
		ambientWeight = 1, brightness = 0.8, exposure = -0.15 },
	Night = { atmosphere = { 64, 78, 100 }, fog = { 26, 36, 54 }, ambient = { 30, 40, 68 }, outdoor = { 36, 48, 76 },
		ambientWeight = 1, brightness = 0.55, exposure = -0.30 },
})
Atmosphere.FOG_ZONE_DARKEN = 0.92
Atmosphere.REDUCED_BLEND = 0.5
Atmosphere.FLOORS = table.freeze({ fogStart = 15, fogEnd = 90, ramp = 4, density = 0.65, haze = 4 })
-- Keyframes on a clock unrolled to 6..30 (05:00 is 29): Day, Dusk, Night, Night, Dusk, Day.
local KEYS = table.freeze({ { 6, "Day" }, { 18, "Day" }, { 19, "Dusk" }, { 20, "Night" }, { 29, "Night" },
	{ 29.5, "Dusk" }, { 30, "Day" } })

local function lerp(a, b, t) return a + (b - a) * t end
local function colour(values, scale)
	return { r = values[1] * scale, g = values[2] * scale, b = values[3] * scale }
end
local function mix(a, b, t)
	return { r = lerp(a.r, b.r, t), g = lerp(a.g, b.g, t), b = lerp(a.b, b.b, t) }
end

-- One time of day's full target for a zone.
local function pure(zone, time)
	local row, light = ROWS[zone][time], LIGHT[time]
	local darken = zone == "fog" and Atmosphere.FOG_ZONE_DARKEN or 1
	return { density = row[1], offset = row[2], haze = row[3], fogStart = row[4], fogEnd = row[5],
		atmosphereColor = colour(light.atmosphere, darken), fogColor = colour(light.fog, darken),
		ambient = colour(light.ambient, 1), outdoorAmbient = colour(light.outdoor, 1),
		ambientWeight = light.ambientWeight, brightness = light.brightness, exposure = light.exposure }
end
local function blend(a, b, t)
	local out = {}
	for key, value in pairs(a) do
		out[key] = type(value) == "table" and mix(value, b[key], t) or lerp(value, b[key], t)
	end
	return out
end

-- at(clockTime, zone, reduced) -> targets. Bad input falls back to the Day open row; reduced must be true.
function Atmosphere.at(clockTime, zone, reduced)
	if not ROWS[zone] then zone = "open" end
	if type(clockTime) ~= "number" or clockTime ~= clockTime or math.abs(clockTime) == math.huge then
		clockTime, zone = 12, "open"
	end
	local t = clockTime % 24
	if t < 6 then t += 24 end
	local target = pure(zone, "Day")
	for index = 1, #KEYS - 1 do
		local a, b = KEYS[index], KEYS[index + 1]
		if t >= a[1] and t <= b[1] then
			target = blend(pure(zone, a[2]), pure(zone, b[2]), (t - a[1]) / (b[1] - a[1]))
			break
		end
	end
	if reduced == true then
		local ambient, outdoor = target.ambient, target.outdoorAmbient
		target = blend(target, pure(zone, "Day"), Atmosphere.REDUCED_BLEND)
		-- Day keeps the place's own ambient, so halfway toward Day halves the weight and keeps the colour.
		target.ambient, target.outdoorAmbient = ambient, outdoor
	end
	return target
end

return Atmosphere
