-- Invoke with require(freshTestClone)(WildboundWorld.Source, require(freshWorldRulesClone), require(freshHideClone)).
-- AI rework (user, 2026-11-13: "Me dijeron que le de vuelta a la IA porque no les gusta"). The user chose, of the
-- options offered: S1 "Te ronda", S2 "Avanza durante el aviso", S3 "Todo el bosque de niebla", S4 "Revisa escondites
-- cercanos". Rule checks on WildboundWorldRules and WildboundHide, and source contracts for how the world server
-- uses them; the stalk rule itself is in WildboundSiluetaStalk_Test, and the feel is checked in Studio Play.
return function(world, Rules, Hide)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function at(text, label)
		local index = type(world) == "string" and world:find(text, 1, true)
		assert(index, label or ("missing: " .. text))
		return index
	end
	local function count(text)
		local total, from = 0, 1
		while true do
			local first, last = world:find(text, from, true)
			if not first then return total end
			total, from = total + 1, last + 1
		end
	end
	local R = Rules.SILUETA_REACH

	case("S3: her reach covers every corner of the fog forest; the territory keeps its 80 studs", function()
		assert(Rules.finite(R), "Rules.SILUETA_REACH")
		for _, corner in ipairs({ { -45, -165 }, { -45, 35 }, { 165, -165 }, { 165, 35 } }) do
			assert(Rules.distance(corner[1], corner[2], Rules.HOME_X, Rules.HOME_Z) <= R, "a corner of the fog rectangle is out of reach")
		end
		assert(Rules.HOME_LEASH == 80, "noise tiers, capture tiers, Refugios and beasts still read the old territory")
		assert(Rules.inTerritory(100, -85) == false and Rules.inTerritory(100, -85, R) == true)
	end)

	case("S3: with her reach a quarry anywhere in the forest is fair, never in a safe zone, on the spawn pad or outside the fog", function()
		assert(Rules.validTarget(true, 150, 20, 140, 20, 60, R) == true, "the far corner of the forest")
		assert(Rules.validTarget(true, 150, 20, 140, 20, 60) == false, "the default is still the territory")
		assert(Rules.validTarget(true, 0, 0, 5, -12, 60, R) == false, "the spawn pad")
		assert(Rules.validTarget(true, 200, -85, 190, -85, 60, R) == false, "outside the fog")
		Rules.setRefuges({ { id = "T", x = 120, z = -85 } }, 12)
		local kept = #Rules.refuges()
		local inside = Rules.validTarget(true, 120, -85, 110, -85, 60, R)
		local beside = Rules.validTarget(true, 140, -85, 130, -85, 60, R)
		Rules.setRefuges(nil)
		assert(kept == 1, "a Refugio outside the 80-stud territory is still accepted")
		assert(inside == false and beside == true, "a Refugio stays safe inside her reach")
	end)

	case("S3: a chase is kept out to her reach and still ends in a safe zone", function()
		local seen = { alive = true, visible = true, distance = 10, safe = false, homeDistance = 150 }
		assert(Rules.pursuit(seen) == false, "the default chase leash is unchanged")
		seen.leash = R
		assert(Rules.pursuit(seen) == true)
		seen.safe = true
		assert(Rules.pursuit(seen) == false)
	end)

	case("S3: the world server reads her reach for sight, steps, goals and strikes; noise tiers keep the territory", function()
		at("local function herReach(leash)")
		at("return math.max(leash or 0, Rules.SILUETA_REACH)")
		at("range, herReach(leash)) then return nil end", "sight and strike checks")
		at("leash = herReach(Rules.CHASE_LEASH)", "the chase")
		at("Rules.clampTerritory(x, z, herReach(leash))", "free points")
		at("local leash = herReach(h.mode == \"Hunt\" and Rules.CHASE_LEASH or nil)", "goals")
		at("if h.mode == \"Hunt\" then return herReach(Rules.CHASE_LEASH) end", "steps")
		assert(count("Rules.inTerritory(candidate.root.Position.X, candidate.root.Position.Z, herReach())") == 2,
			"the chase clock and the telegraph both read her reach")
		at("return Rules.inTerritory(x, z) and \"Territory\" or \"Fog\"", "noise tiers")
	end)

	case("S2: through the telegraph she keeps walking at a quarry she sees; the warning and the strike gates stay", function()
		local wind = at("elseif h.mode == \"Telegraph\" and now < h.telegraphEndsAt then")
		local impact = at("elseif h.mode == \"Telegraph\" and now >= h.telegraphEndsAt then")
		assert(wind < impact, "the wind-up is handled before the impact")
		local body = world:sub(wind, impact)
		-- Verification finding: aiming at the quarry itself let one step end inside a player who stood still to time the
		-- dodge. She aims at the point half her reach short of the quarry, so a step can never pass it.
		for _, text in ipairs({ "local stand = candidate.root.Position + toHer.Unit * (Rules.ATTACK_RANGE * 0.5)",
			"navigate(h, stand, profile.hunt, dt, now)" }) do
			assert(body:find(text, 1, true), "the wind-up lacks: " .. text)
		end
		-- Measured in Play: standing still, she came to 1.3 studs, because the hunt step before the warning aimed at the
		-- quarry itself. The hunt aims short of a quarry it sees, too.
		at("if candidate.visible then decision.destination = shortOf(h, candidate.root.Position) end")
		at("local function shortOf(h, position)")
		at("h.telegraphEndsAt = now + Rules.TELEGRAPH_SECONDS", "the warning keeps its length")
		at("local latest = binding and targetContext(h, target, Rules.ATTACK_RANGE) or nil", "the strike still needs reach and sight at impact")
		assert(Rules.TELEGRAPH_SECONDS >= 0.8, "never under the fair-strike warning lead")
	end)

	-- Deliberately changed (user decision 2026-11-14, "que siga patrullando normal"): losing a quarry resumes the patrol,
	-- so nothing fills the hide-spot list on loss; a search that does carry one still walks and looks long enough.
	case("S4: losing a quarry fills no hide-spot list; a search that has one looks long enough to find someone", function()
		assert(not world:find("hideSpotsNear(brain.point.x, brain.point.z)", 1, true), "losing a quarry still fills hide spots")
		at("\tclearTarget(h, now)\n\tif alive then\n\t\t-- When she loses sight completely", "she resumes the patrol")
		at("h.checkSpots = nil -- a search that starts from a noise has no spots to check")
		at("hideSpotPoints[id] = { x = zone.Position.X, z = zone.Position.Z }", "the spots are known from their own zones")
		at("elseif h.mode == \"Search\" and h.checkSpots and h.checkSpots[1] and now < brain.untilAt then")
		at("table.remove(h.checkSpots, 1)")
		at("\th.checkSpots = nil\n", "a new chase forgets the old list")
		local seconds = tonumber(world:match("local SPOT_SECONDS = ([%d%.]+)"))
		local stand = tonumber(world:match("local SPOT_STAND = ([%d%.]+)"))
		local radius = tonumber(world:match("local SPOT_RADIUS = ([%d%.]+)"))
		assert(seconds and stand and radius, "SPOT_SECONDS, SPOT_STAND and SPOT_RADIUS")
		for phase, rule in pairs(Hide.CONFIG.DISCOVER) do
			assert(seconds >= rule.dwell + 0.2, phase .. ": she leaves before the dwell that finds a hidden player")
			assert(stand < rule.radius, phase .. ": she stands outside the discover radius")
		end
		assert(radius >= 10 and radius <= 30, "hiding far from where she lost you still works")
	end)

	case("S1: on patrol she stalks her owner through the pure rule, holds her attack while she does, and rests after a chase", function()
		at("local Stalk = require(script.Parent:WaitForChild(\"WildboundSiluetaStalk\"))")
		at("return Stalk.step(h.stalk, {")
		at("present = fog and not safe and Rules.inTerritory(root.Position.X, root.Position.Z, herReach())", "only an owner she could reach")
		at("hidden = record ~= nil and record.hide ~= nil", "a hidden owner is never walked at")
		at("and not (stalk and stalk.hold) then", "she does not attack while she only stalks")
		local stalking = at("elseif h.mode == \"Patrol\" and stalk then")
		assert(stalking < at("elseif h.mode == \"Patrol\" then"), "the old rounds are the fallback")
		at("h.stalkQuietUntil = now + Stalk.CONSTANTS.QUIET", "quiet after pressure")
		at("Stalk.reset(h.stalk)")
		at("or now >= h.stalkQuietUntil", "after the quiet she comes back without walking all the way home")
		at("stalk = Stalk.new(), stalkQuietUntil = 0", "each hunter has its own")
	end)

	return result
end
