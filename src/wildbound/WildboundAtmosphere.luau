-- Pure atmosphere targets (delivery D1): whole-map fog by zone and time of day, blended by the replicated
-- clockTime. No services; the world client applies the targets to its local Lighting and restores on cleanup.
-- Numbers are hypotheses from docs/mechanics/wildbound-delivery-d.md section 1; the floors are contracts.
local Atmosphere = {}

-- density, offset, haze, fogStart, fogEnd per zone and time of day. Dread pass (user request): much mistier by day,
-- near-blind with more mist at night. Delivery D1 had open Day 0.30 / 450 and fog Night 0.62 / 100.
local ROWS = table.freeze({
	open = { Day = { 0.68, 0.02, 3.0, 24, 140 }, Dusk = { 0.76, 0.01, 4.0, 18, 90 }, Night = { 0.82, 0, 5.0, 15, 60 } },
	fog = { Day = { 0.74, 0.01, 3.6, 20, 110 }, Dusk = { 0.82, 0, 4.8, 16, 70 }, Night = { 0.88, 0, 6.0, 15, 48 } },
	camp = { Day = { 0.55, 0.05, 2.2, 40, 260 }, Dusk = { 0.64, 0.03, 3.0, 26, 160 }, Night = { 0.72, 0, 3.8, 18, 100 } },
})
-- Colours and light per time of day. ambientWeight 0 keeps the place's own Ambient and OutdoorAmbient. The flashlight
-- is a SpotLight on the player's own head (brightness, range, angle): off by day, the main light at night.
local LIGHT = table.freeze({
	Day = { atmosphere = { 170, 176, 170 }, fog = { 150, 158, 152 }, ambient = { 58, 64, 78 }, outdoor = { 66, 74, 88 },
		ambientWeight = 0, brightness = 1, exposure = 0, flashlight = { 0, 55, 60 } },
	Dusk = { atmosphere = { 100, 96, 108 }, fog = { 58, 58, 74 }, ambient = { 46, 52, 66 }, outdoor = { 54, 60, 76 },
		ambientWeight = 1, brightness = 0.7, exposure = -0.25, flashlight = { 2.5, 55, 60 } },
	Night = { atmosphere = { 40, 48, 64 }, fog = { 14, 18, 28 }, ambient = { 22, 28, 46 }, outdoor = { 26, 32, 52 },
		ambientWeight = 1, brightness = 0.4, exposure = -0.5, flashlight = { 5, 55, 60 } },
})
Atmosphere.FOG_ZONE_DARKEN = 0.92
Atmosphere.REDUCED_BLEND = 0.5
-- Dread pass: only the playable floors are kept (avatar never fogged, a ramp); the rest relaxed for near-blind nights.
Atmosphere.FLOORS = table.freeze({ fogStart = 15, fogEnd = 45, ramp = 3, density = 0.9, haze = 6.5 })
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
		ambientWeight = light.ambientWeight, brightness = light.brightness, exposure = light.exposure,
		flashlight = { brightness = light.flashlight[1], range = light.flashlight[2], angle = light.flashlight[3] } }
end
local function blend(a, b, t)
	local out = {}
	for key, value in pairs(a) do
		if key == "flashlight" then
			out[key] = { brightness = lerp(value.brightness, b[key].brightness, t), range = lerp(value.range, b[key].range, t),
				angle = lerp(value.angle, b[key].angle, t) }
		else
			out[key] = type(value) == "table" and mix(value, b[key], t) or lerp(value, b[key], t)
		end
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
		local ambient, outdoor, flashlight = target.ambient, target.outdoorAmbient, target.flashlight
		target = blend(target, pure(zone, "Day"), Atmosphere.REDUCED_BLEND)
		-- Day keeps the place's own ambient, so halfway toward Day halves the weight and keeps the colour. Reduced
		-- lowers dread, not the player's own light: the flashlight is untouched.
		target.ambient, target.outdoorAmbient, target.flashlight = ambient, outdoor, flashlight
	end
	return target
end

return Atmosphere
