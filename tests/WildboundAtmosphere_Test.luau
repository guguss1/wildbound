-- Invoke with require(freshTestClone)(require(freshAtmosphereClone), WildboundWorldClient.Source).
-- Delivery D1: whole-map fog by zone (camp, open, fog) and time of day (Day, Dusk, Night), blended by the
-- replicated clockTime, with readability floors so a tuning change can never fog the avatar or the path on phones.
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
	-- Section 1 of docs/mechanics/wildbound-delivery-d.md, copied here so a module edit cannot move both.
	local TABLE = {
		open = { Day = { 0.30, 0.15, 1.0, 70, 450 }, Dusk = { 0.40, 0.08, 1.8, 40, 260 }, Night = { 0.52, 0, 2.6, 25, 150 } },
		fog = { Day = { 0.40, 0.10, 1.6, 40, 240 }, Dusk = { 0.52, 0.04, 2.4, 28, 160 }, Night = { 0.62, 0, 3.4, 16, 100 } },
		camp = { Day = { 0.22, 0.15, 0.6, 90, 700 }, Dusk = { 0.30, 0.08, 1.0, 60, 380 }, Night = { 0.38, 0, 1.8, 40, 260 } },
	}
	local function row(target, expected, label)
		for index, field in ipairs(FIELDS) do near(target[field], expected[index], label .. " " .. field) end
	end
	local function checkFloors(target, label)
		assert(target.fogStart >= 15, label .. ": FogStart below 15")
		assert(target.fogEnd >= 90, label .. ": FogEnd below 90")
		assert(target.fogEnd >= 4 * target.fogStart, label .. ": fog is a wall, not a ramp")
		assert(target.density <= 0.65, label .. ": density above 0.65")
		assert(target.haze <= 4, label .. ": haze above 4")
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
		near(Atmosphere.at(18.5, "fog", false).fogEnd, 200, "fog 18.5")
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
							assert(target.ambient[channel] >= 26, zone .. " night ambient " .. channel)
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
		near(night.density, 0.51, "density")
		near(night.fogStart, 28, "fogStart")
		near(night.fogEnd, 170, "fogEnd")
		near(night.ambientWeight, 0.5, "ambient weight")
		for _, zone in ipairs(ZONES) do
			local full, soft, day = Atmosphere.at(23, zone, false), Atmosphere.at(23, zone, true), Atmosphere.at(12, zone, false)
			for _, field in ipairs(FIELDS) do near(soft[field], (full[field] + day[field]) / 2, zone .. " " .. field) end
			near(soft.fogColor.r, (full.fogColor.r + day.fogColor.r) / 2, zone .. " fog colour")
			near(soft.brightness, (full.brightness + 1) / 2, zone .. " brightness")
		end
	end)

	case("D1: night fog zone is at least 1.5x as dense and at most half as far as day open", function()
		local night, day = Atmosphere.at(23, "fog", false), Atmosphere.at(12, "open", false)
		assert(night.density >= 1.5 * day.density, "density")
		assert(night.fogEnd <= day.fogEnd / 2, "fogEnd")
		assert(night.fogColor.r < Atmosphere.at(23, "open", false).fogColor.r, "the fog territory is the darkest")
		near(night.fogColor.r, 26 * 0.92, "fog colour x 0.92")
		near(night.brightness, 0.55, "night brightness")
		near(night.exposure, -0.30, "night exposure")
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

	case("D1: the world client applies the module, owns Offset, and has no inline fog numbers", function()
		assert(clientSource:find("WildboundAtmosphere", 1, true), "client does not require WildboundAtmosphere")
		assert(clientSource:find("Atmosphere.at(", 1, true) or clientSource:find("Atmos.at(", 1, true),
			"client does not call at()")
		assert(clientSource:find("Offset = atmosphere.Offset", 1, true), "Offset is not cached for restore")
		assert(clientSource:find("ExposureCompensation = Lighting.ExposureCompensation", 1, true), "exposure not cached")
		for _, literal in ipairs({ "fromRGB(40, 54, 72)", "fromRGB(78, 94, 116)", "reduced and 180 or 130", "fog and 45" }) do
			assert(not clientSource:find(literal, 1, true), "inline fog value left: " .. literal)
		end
	end)

	return result
end
