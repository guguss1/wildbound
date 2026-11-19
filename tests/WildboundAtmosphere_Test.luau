-- Invoke with require(freshTestClone)(require(freshAtmosphereClone), WildboundWorldClient.Source).
-- Delivery D1: whole-map fog by zone (camp, open, fog) and time of day (Day, Dusk, Night), blended by the
-- replicated clockTime. Retuned in the dread pass (user request): much mistier by day, near-blind with more mist at
-- night, the flashlight the main light. The only hard floors left keep the game playable: the player's own avatar
-- near the camera stays clear, and the flashlight reaches through the whole visible night depth.
return function(Atmosphere, clientSource)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	clientSource = type(clientSource) == "string" and clientSource or ""
	local ZONES = { "camp", "open", "fog" }
	local TIMES = { Day = 12, Dusk = 19, Night = 23 }
	local FIELDS = { "density", "offset", "haze", "fogStart", "fogEnd" }
	-- docs/ui/wildbound-world.md (dread pass table), copied here so a module edit cannot move both. Deliberately
	-- changed from delivery D1 (open Day was 0.30 / 450, fog Night 0.62 / 100).
	local TABLE = {
		open = { Day = { 0.68, 0.02, 3.0, 24, 140 }, Dusk = { 0.76, 0.01, 4.0, 18, 90 }, Night = { 0.82, 0, 5.0, 15, 60 } },
		fog = { Day = { 0.74, 0.01, 3.6, 20, 110 }, Dusk = { 0.82, 0, 4.8, 16, 70 }, Night = { 0.88, 0, 6.0, 15, 48 } },
		camp = { Day = { 0.55, 0.05, 2.2, 40, 260 }, Dusk = { 0.64, 0.03, 3.0, 26, 160 }, Night = { 0.72, 0, 3.8, 18, 100 } },
	}
	local function row(target, expected, label)
		for index, field in ipairs(FIELDS) do near(target[field], expected[index], label .. " " .. field) end
	end
	-- Dread pass floors. Kept: FogStart 15 (the camera sits 12.5 studs behind the avatar, so the avatar is never
	-- fogged) and a ramp, not a wall. Relaxed on purpose (the user asked for near-blind nights): FogEnd 90 to 45,
	-- density 0.65 to 0.9, haze 4 to 6.5; the lantern and path gates are gone, the flashlight carries the night.
	local function checkFloors(target, label)
		assert(target.fogStart >= 15, label .. ": FogStart below 15")
		assert(target.fogEnd >= 45, label .. ": FogEnd below 45")
		assert(target.fogEnd >= 3 * target.fogStart, label .. ": fog is a wall, not a ramp")
		assert(target.density <= 0.9, label .. ": density above 0.9")
		assert(target.haze <= 6.5, label .. ": haze above 6.5")
	end

	case("D1: keyframes at 18, 19, 20, 29, 29.5, 30 equal the tables", function()
		for _, zone in ipairs(ZONES) do
			row(Atmosphere.at(18, zone, false), TABLE[zone].Day, zone .. " 18")
			row(Atmosphere.at(19, zone, false), TABLE[zone].Dusk, zone .. " 19")
			row(Atmosphere.at(20, zone, false), TABLE[zone].Night, zone .. " 20")
			row(Atmosphere.at(5, zone, false), TABLE[zone].Night, zone .. " 29")
			row(Atmosphere.at(5.5, zone, false), TABLE[zone].Dusk, zone .. " 29.5")
			row(Atmosphere.at(6, zone, false), TABLE[zone].Day, zone .. " 30")
		end
		-- Halfway into dusk is halfway between the rows.
		near(Atmosphere.at(18.5, "fog", false).fogEnd, 90, "fog 18.5")
	end)

	case("D1: dawn mirrors dusk", function()
		for _, zone in ipairs(ZONES) do
			for _, offset in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
				local dusk = Atmosphere.at(18 + offset, zone, false)
				local dawn = Atmosphere.at(6 - offset * 0.5, zone, false)
				for _, field in ipairs(FIELDS) do near(dawn[field], dusk[field], zone .. " " .. field .. " " .. offset) end
			end
		end
	end)

	case("D1: clock wraps past 24", function()
		for _, zone in ipairs(ZONES) do
			local a, b = Atmosphere.at(2, zone, false), Atmosphere.at(26, zone, false)
			local c = Atmosphere.at(-22, zone, false)
			for _, field in ipairs(FIELDS) do
				near(b[field], a[field], zone .. " 26 " .. field)
				near(c[field], a[field], zone .. " -22 " .. field)
			end
		end
	end)

	case("D1: zone ordering camp < open < fog", function()
		for name, clock in pairs(TIMES) do
			for _, reduced in ipairs({ false, true }) do
				local camp, open, fog = Atmosphere.at(clock, "camp", reduced), Atmosphere.at(clock, "open", reduced),
					Atmosphere.at(clock, "fog", reduced)
				assert(camp.density < open.density and open.density < fog.density, name .. " density order")
				assert(camp.fogEnd > open.fogEnd and open.fogEnd > fog.fogEnd, name .. " fogEnd order")
			end
		end
	end)

	case("D1: time ordering day < dusk < night", function()
		for _, zone in ipairs(ZONES) do
			for _, reduced in ipairs({ false, true }) do
				local day, dusk, night = Atmosphere.at(TIMES.Day, zone, reduced), Atmosphere.at(TIMES.Dusk, zone, reduced),
					Atmosphere.at(TIMES.Night, zone, reduced)
				assert(day.density < dusk.density and dusk.density < night.density, zone .. " density order")
				assert(day.fogEnd > dusk.fogEnd and dusk.fogEnd > night.fogEnd, zone .. " fogEnd order")
				assert(day.brightness >= dusk.brightness and dusk.brightness > night.brightness, zone .. " brightness")
			end
		end
	end)

	case("D1: readability floors hold for all 18 combinations", function()
		local count = 0
		for _, zone in ipairs(ZONES) do
			for name, clock in pairs(TIMES) do
				for _, reduced in ipairs({ false, true }) do
					local target = Atmosphere.at(clock, zone, reduced)
					checkFloors(target, zone .. " " .. name .. " " .. tostring(reduced))
					if name == "Night" then
						for _, channel in ipairs({ "r", "g", "b" }) do
							assert(target.ambient[channel] >= 20, zone .. " night ambient " .. channel)
						end
					end
					count += 1
				end
			end
			-- Every quarter hour of the cycle, not only the keyframes.
			for step = 0, 95 do checkFloors(Atmosphere.at(step / 4, zone, false), zone .. " t" .. step) end
		end
		assert(count == 18, "expected 18 combinations, got " .. count)
	end)

	case("D1: reduced blends 50 percent toward Day and keeps the floors", function()
		local night = Atmosphere.at(23, "fog", true)
		near(night.density, 0.81, "density")
		near(night.fogStart, 17.5, "fogStart")
		near(night.fogEnd, 79, "fogEnd")
		near(night.ambientWeight, 0.5, "ambient weight")
		for _, zone in ipairs(ZONES) do
			local full, soft, day = Atmosphere.at(23, zone, false), Atmosphere.at(23, zone, true), Atmosphere.at(12, zone, false)
			for _, field in ipairs(FIELDS) do near(soft[field], (full[field] + day[field]) / 2, zone .. " " .. field) end
			near(soft.fogColor.r, (full.fogColor.r + day.fogColor.r) / 2, zone .. " fog colour")
			near(soft.brightness, (full.brightness + 1) / 2, zone .. " brightness")
		end
	end)

	-- Deliberately changed in the dread pass: days are misty now, so night is 1.25x (was 1.5x) as dense as day open.
	case("D1: night fog zone is at least 1.25x as dense and at most half as far as day open", function()
		local night, day = Atmosphere.at(23, "fog", false), Atmosphere.at(12, "open", false)
		assert(night.density >= 1.25 * day.density, "density")
		assert(night.fogEnd <= day.fogEnd / 2, "fogEnd")
		assert(night.fogColor.r < Atmosphere.at(23, "open", false).fogColor.r, "the fog territory is the darkest")
		near(night.fogColor.r, 14 * 0.92, "fog colour x 0.92")
		near(night.brightness, 0.4, "night brightness")
		near(night.exposure, -0.5, "night exposure")
		near(Atmosphere.at(12, "open", false).ambientWeight, 0, "day keeps the place's own ambient")
	end)

	case("D1: bad input (NaN, nil, huge) returns the Day open row", function()
		for _, clock in ipairs({ 0 / 0, math.huge, -math.huge, "12" }) do
			row(Atmosphere.at(clock, "fog", false), TABLE.open.Day, tostring(clock))
		end
		row(Atmosphere.at(nil, nil, nil), TABLE.open.Day, "nil")
		row(Atmosphere.at(12, "lava", false), TABLE.open.Day, "unknown zone")
		row(Atmosphere.at(12, "open", "yes"), TABLE.open.Day, "non-boolean reduced is off")
	end)

	case("Dread pass: day is much mistier and night has more mist than delivery D1", function()
		for _, zone in ipairs(ZONES) do
			local day, night = Atmosphere.at(12, zone, false), Atmosphere.at(23, zone, false)
			assert(day.fogEnd <= 260 and day.density >= 0.55, zone .. " day mist")
		end
		local openDay, fogNight = Atmosphere.at(12, "open", false), Atmosphere.at(23, "fog", false)
		assert(openDay.density >= 0.30 * 1.5 and openDay.fogEnd <= 450 / 2, "open day was 0.30 and 450")
		assert(fogNight.density >= 0.62 + 0.2 and fogNight.fogEnd <= 100 / 2, "fog night was 0.62 and 100")
		assert(fogNight.haze > 3.4 and fogNight.brightness < 0.55, "darker and hazier than before")
	end)

	case("Dread pass: the flashlight is the main light at night and reaches the whole visible depth", function()
		for _, zone in ipairs(ZONES) do
			local day, dusk, night = Atmosphere.at(12, zone, false), Atmosphere.at(19, zone, false), Atmosphere.at(23, zone, false)
			near(day.flashlight.brightness, 0, zone .. " off by day")
			assert(dusk.flashlight.brightness > 0 and night.flashlight.brightness > dusk.flashlight.brightness, zone .. " on at dusk, full at night")
			assert(night.flashlight.range <= 60, zone .. " SpotLight range is at most 60")
			assert(night.flashlight.angle >= 40 and night.flashlight.angle <= 90, zone .. " a cone, not a floodlight")
			-- Hard floor: in the thickest fog the beam reaches as far as anything can be seen.
			assert(night.flashlight.range >= Atmosphere.at(23, "fog", false).fogEnd, zone .. " beam shorter than the fog")
			local soft = Atmosphere.at(23, zone, true)
			near(soft.flashlight.brightness, night.flashlight.brightness, zone .. " Reduced never dims the flashlight")
			near(soft.flashlight.range, night.flashlight.range, zone .. " Reduced keeps the range")
		end
	end)

	-- K-D14 (owner request 2026-11-17, "es como el mundo de gatito: un parque verde lindo ..."): the kitten park's own zone
	-- (WildboundBiomeLight's Gatuno preset reads its Day row): clear light-blue air, a thin haze and the longest view.
	case("K-D14: the park zone: rows for Day, Dusk and Night, light-blue air and a view to 1100", function()
		local day = Atmosphere.at(13, "park", false)
		-- Deliberately changed (OQ1, owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto
		-- estirada"): the park's haze is 1.2 higher at every time of day (was 0.6, 0.8, 1.0), so it fades the place's
		-- painted skybox into a sky gradient behind the real 3D clouds; density and the view are unchanged.
		row(day, { 0.22, 0.1, 1.8, 150, 1100 }, "park Day")
		row(Atmosphere.at(19, "park", false), { 0.28, 0.08, 2.0, 110, 700 }, "park Dusk")
		row(Atmosphere.at(23, "park", false), { 0.34, 0.05, 2.2, 70, 450 }, "park Night")
		near(day.atmosphereColor.r, 199, "air r"); near(day.atmosphereColor.g, 226, "air g")
		near(day.atmosphereColor.b, 245, "air b")
		near(day.fogColor.r, 214, "fog r"); near(day.fogColor.g, 236, "fog g"); near(day.fogColor.b, 250, "fog b")
		local colours = Atmosphere.ZONE_COLOURS.park
		assert(colours and table.isfrozen(colours), "frozen park colours")
		for name, clock in pairs(TIMES) do
			for _, reduced in ipairs({ false, true }) do checkFloors(Atmosphere.at(clock, "park", reduced), "park " .. name) end
		end
		assert(day.fogEnd > Atmosphere.at(13, "candy", false).fogEnd, "clearer than Caramelo")
		assert(Atmosphere.at(13, "lava", false).fogEnd == 140, "an unknown zone still falls back to the open row")
	end)

	-- OQ1 (owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto estirada"): in the two bright
	-- biomes, where the sky shows, the haze is raised over the painted skybox picture (the real clouds are the client's
	-- Terrain Clouds); only the haze grows: the density and the view stay as they were. This checks the numbers only:
	-- whether the photo is hidden overhead is the solo Play check (look straight up), not this suite.
	case("OQ1-3: the candy and park hazes raised, and only the haze changed", function()
		local candy = { Day = { 0.28, 0.12, 3.0, 120, 900 }, Dusk = { 0.34, 0.08, 3.2, 90, 600 },
			Night = { 0.4, 0.05, 3.4, 60, 400 } }
		row(Atmosphere.at(14, "candy", false), candy.Day, "candy Day")
		row(Atmosphere.at(19, "candy", false), candy.Dusk, "candy Dusk")
		row(Atmosphere.at(23, "candy", false), candy.Night, "candy Night")
		for _, zone in ipairs({ "candy", "park" }) do
			for name, clock in pairs(TIMES) do
				for _, reduced in ipairs({ false, true }) do
					local target = Atmosphere.at(clock, zone, reduced)
					checkFloors(target, zone .. " " .. name)
					assert(target.haze >= 1.6, zone .. " " .. name .. ": the haze raised: " .. target.haze)
				end
			end
		end
		local candyDay, parkDay = Atmosphere.at(14, "candy", false), Atmosphere.at(13, "park", false)
		assert(candyDay.haze > parkDay.haze, "Caramelo's pink haze is the stronger (it carries the pink sky)")
		assert(candyDay.density <= 0.3 and parkDay.density <= 0.3, "the view is not fogged")
		local open = Atmosphere.at(12, "open", false)
		near(open.haze, 3.0, "the open day's haze is unchanged")
	end)

	case("D1: the world client applies the module, owns Offset, and has no inline fog numbers", function()
		assert(clientSource:find("WildboundAtmosphere", 1, true), "client does not require WildboundAtmosphere")
		assert(clientSource:find("Atmosphere.at(", 1, true) or clientSource:find("Atmos.at(", 1, true),
			"client does not call at()")
		assert(clientSource:find("Offset = atmosphere.Offset", 1, true), "Offset is not cached for restore")
		assert(clientSource:find("ExposureCompensation = Lighting.ExposureCompensation", 1, true), "exposure not cached")
		for _, literal in ipairs({ "fromRGB(40, 54, 72)", "fromRGB(78, 94, 116)", "reduced and 180 or 130", "fog and 45" }) do
			assert(not clientSource:find(literal, 1, true), "inline fog value left: " .. literal)
		end
		-- Dread pass: a local SpotLight on the player's own head follows the module's flashlight targets.
		assert(clientSource:find('Name = "WildboundFlashlight"', 1, true), "no flashlight SpotLight")
		assert(clientSource:find("target.flashlight.brightness", 1, true), "flashlight brightness not applied")
		assert(clientSource:find("target.flashlight.range", 1, true), "flashlight range not applied")
	end)

	return result
end
