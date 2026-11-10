-- Invoke with require(freshTestClone)(require(freshSchemaClone), { Stamina = require(freshStaminaClone),
-- Island = require(freshIslandClone), Brain = require(freshBrainClone), Rules = require(freshRulesClone),
-- Hide = require(freshHideClone), Carry = require(freshCarryClone), Capture = require(freshCaptureClone),
-- View = require(freshHudViewClone), Incubator = require(freshIncubatorClone),
-- Moves = require(freshSiluetaMovesClone), SpawnClock = require(freshSpawnClockClone) }).
-- Dev tuning (docs/testing/wildbound-tuning.md): the schema of every tunable
-- value, its parity with the module defaults, clamping, the developer gate, the request checks, the rate limit, the
-- export snippet, and the modules' live overrides. Module defaults stay the source of truth: no override, no change.
return function(Schema, modules)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function entries()
		local list = {}
		for _, system in ipairs(Schema.SYSTEMS) do
			for _, entry in ipairs(system.entries) do table.insert(list, { system = system, entry = entry }) end
		end
		return list
	end
	-- A reader over a plain table: values[system][key], as the attributes would hold them.
	local function reader(values)
		return function(system, key)
			local group = values[system]
			return group and group[key]
		end
	end
	local function applyServer(values)
		Schema.apply({ Stamina = modules.Stamina, Island = modules.Island, Brain = modules.Brain, Rules = modules.Rules,
			Hide = modules.Hide, Carry = modules.Carry, Capture = modules.Capture }, reader(values), "server")
	end
	local DEV = { studio = true, placeId = 1, userId = 5, creatorId = 9, creatorType = "User" }

	case("DT1: every system and value is well formed", function()
		assert(#Schema.SYSTEMS >= 7, "at least seven systems")
		local seen = {}
		for _, item in ipairs(entries()) do
			local system, entry = item.system, item.entry
			assert(type(system.id) == "string" and system.id:match("^[%a_][%w_]*$"), "system id " .. tostring(system.id))
			assert(type(system.label) == "string" and #system.label > 0, "system label")
			local id = system.id .. "." .. tostring(entry.key)
			assert(not seen[id], "duplicate " .. id)
			seen[id] = true
			assert(type(entry.key) == "string" and entry.key:match("^[%a_][%w_]*$") and #entry.key <= 100, "attribute name " .. id)
			assert(type(entry.label) == "string" and #entry.label > 0, "label " .. id)
			assert(Schema.MODULES[entry.module], "module " .. id .. " " .. tostring(entry.module))
			assert(entry.side == "server" or entry.side == "client", "side " .. id)
			assert(type(entry.target) == "string", "target " .. id)
			assert(type(entry.min) == "number" and type(entry.max) == "number" and entry.min < entry.max, "range " .. id)
			assert(entry.default >= entry.min and entry.default <= entry.max, "default inside range " .. id)
			assert(type(entry.step) == "number" and entry.step > 0, "step " .. id)
		end
	end)

	case("DT1: the schema defaults match the module defaults (a divergence fails here)", function()
		for _, item in ipairs(entries()) do
			local entry = item.entry
			local module = modules[entry.module]
			assert(module and type(module.tunable) == "function", entry.module .. ".tunable")
			local defaults = module.tunable()
			equal(entry.default, defaults[entry.target], item.system.id .. "." .. entry.key .. " (" .. entry.target .. ")")
		end
	end)

	case("DT1: the schema covers the values a designer tweaks", function()
		for _, id in ipairs({ "Silueta.HUNT_NIGHT", "Silueta.SIGHT_DAY", "Silueta.MEMORY_NIGHT", "Silueta.GIVE_UP_DISTANCE",
			"Silueta.CHASE_LEASH", "Silueta.TELEGRAPH_SECONDS", "Silueta.ATTACK_COOLDOWN", "Sprint.SPRINT_MULTIPLIER",
			"Sprint.DRAIN", "Carry.FEAR_SLIP", "Islands.WAKE", "Islands.CHASE_SPEED", "Islands.DAMAGE",
			"Islands.STRIKE_WINDUP", "Capture.CALM_REQUIRED", "Hide.NIGHT_RADIUS", "Camera.SPRINT_FOV_KICK",
			-- Fear pass (FA2): the grab's noise is tunable.
			"Islands.GRAB",
			-- Next batch NB4 (delivery E): the incubation time.
			"Incubator.HATCH_SECONDS",
			-- Look pass: La Silueta's height (art only).
			"Silueta.VISUAL_SCALE",
			-- Fix pass (FP2): one Silueta per player, the cap and how faint another player's is drawn.
			"Silueta.MAX_HUNTERS", "Camera.OTHER_SILUETA_FADE",
			-- Fix pass (FP3): the chase limit per phase.
			"Silueta.CHASE_DAY", "Silueta.CHASE_TWILIGHT", "Silueta.CHASE_NIGHT",
			-- Fix pass (FP4): La Silueta's moves, each with a toggle.
			"Silueta.LUNGE_ON", "Silueta.LUNGE_SPEED", "Silueta.FAKE_ON", "Silueta.FAKE_CHANCE", "Silueta.GLARE_ON",
			"Silueta.GLARE_HOLD", "Silueta.SCREAM_ON", "Silueta.SCREAM_REACH",
			-- Fix pass (FP5): the parents' moves.
			"Islands.POUNCE_ON", "Islands.POUNCE_RANGE", "Islands.EGG_RECOVERY_ON", "Islands.DEEP_SLEEP_ON", "Islands.DEEP_SCALE",
			"Islands.BREATH_SECONDS",
			-- Random world (RW2): the spawn clock.
			"World.LIFETIME", "World.RESPAWN_COMUN", "World.RESPAWN_LEGENDARIA", "World.MAX_COMUN", "World.MAX_LEGENDARIA",
			"World.EGG_SHARE" }) do
			local system, key = id:match("^(%w+)%.([%w_]+)$")
			assert(Schema.find(system, key), "missing " .. id)
		end
		equal(Schema.find("Camera", "SPRINT_FOV_KICK").side, "client", "the camera kick is read on the client")
		equal(Schema.find("Camera", "OTHER_SILUETA_FADE").side, "client", "the fade of another player's Silueta is a client value")
		equal(Schema.find("Silueta", "MAX_HUNTERS").min, 1, "at least one Silueta")
		-- Fix pass (FP4): a toggle is 0 (off) or 1 (on), on by default; the lunge tell keeps the readable floor.
		for _, key in ipairs({ "LUNGE_ON", "FAKE_ON", "GLARE_ON", "SCREAM_ON" }) do
			local toggle = Schema.find("Silueta", key)
			equal(toggle.min, 0, key); equal(toggle.max, 1, key); equal(toggle.step, 1, key); equal(toggle.default, 1, key)
		end
		assert(Schema.find("Silueta", "LUNGE_TELL").min >= 0.35, "the lunge tell never drops under 0.35 s")
		equal(Schema.find("Sprint", "SPRINT_MULTIPLIER").side, "server", "sprint is read on the server")
		equal(Schema.find("Nope", "X"), nil)
	end)

	case("DT1: sanitize clamps numbers into range and ignores anything else", function()
		local entry = Schema.find("Sprint", "SPRINT_MULTIPLIER")
		equal(Schema.sanitize(entry, 1.6), 1.6)
		equal(Schema.sanitize(entry, -5), entry.min, "below the minimum")
		equal(Schema.sanitize(entry, 999), entry.max, "above the maximum")
		for _, bad in ipairs({ "1.6", true, 0 / 0, math.huge, -math.huge }) do
			equal(Schema.sanitize(entry, bad), nil, "ignored " .. tostring(bad))
		end
		equal(Schema.sanitize(entry, nil), nil)
		equal(Schema.sanitize(nil, 1), nil)
	end)

	case("DT1: only Studio, or the place owner or an allowlisted user on the private place, is a developer", function()
		local P = Schema.PRIVATE_PLACE_ID
		equal(P, 122652861404212)
		equal(Schema.isDeveloper({ studio = true, placeId = 1, userId = 5 }), true, "Studio")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 9, creatorId = 9, creatorType = "User" }), true, "owner")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 5, creatorId = 9, creatorType = "User" }), false, "stranger")
		equal(Schema.isDeveloper({ studio = false, placeId = 7, userId = 9, creatorId = 9, creatorType = "User" }), false,
			"the owner on another place")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 5, creatorId = 9, creatorType = "User",
			allowlist = { 5 } }), true, "allowlist")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 5, creatorId = 3, creatorType = "Group",
			groupRank = 255 }), true, "group owner")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 5, creatorId = 3, creatorType = "Group",
			groupRank = 254 }), false, "group member")
		equal(Schema.isDeveloper({ studio = false, placeId = P, userId = 3, creatorId = 3, creatorType = "Group" }), false,
			"a user id equal to a group id is not the owner")
		equal(Schema.isDeveloper(nil), false)
		equal(Schema.isDeveloper({ studio = "yes", placeId = P }), false, "only a real true counts")
	end)

	case("DT1: a request from a non-developer is rejected before anything else", function()
		local stranger = { studio = false, placeId = Schema.PRIVATE_PLACE_ID, userId = 5, creatorId = 9, creatorType = "User" }
		local ok, reason = Schema.validateRequest(stranger, "set", "Sprint", "SPRINT_MULTIPLIER", 1.6)
		equal(ok, false); equal(reason, "NotDeveloper")
		ok, reason = Schema.validateRequest(stranger, "reset")
		equal(ok, false); equal(reason, "NotDeveloper")
	end)

	case("DT1: a developer request needs a known key, a number and a value in range", function()
		local function check(expected, ...)
			local ok, reason = Schema.validateRequest(DEV, ...)
			equal(ok, false, expected); equal(reason, expected)
		end
		check("UnknownAction", "delete", "Sprint", "SPRINT_MULTIPLIER", 1.6)
		check("UnknownKey", "set", "Sprint", "POOL", 50)
		check("UnknownKey", "set", "Nope", "SPRINT_MULTIPLIER", 1.6)
		check("UnknownKey", "set", {}, "SPRINT_MULTIPLIER", 1.6)
		check("BadValue", "set", "Sprint", "SPRINT_MULTIPLIER", "1.6")
		check("BadValue", "set", "Sprint", "SPRINT_MULTIPLIER", 0 / 0)
		check("OutOfRange", "set", "Sprint", "SPRINT_MULTIPLIER", 50)
		check("UnknownSystem", "reset", "Nope")
		local ok, reason, value = Schema.validateRequest(DEV, "set", "Sprint", "SPRINT_MULTIPLIER", 1.6)
		equal(ok, true, tostring(reason)); equal(value, 1.6)
		equal((Schema.validateRequest(DEV, "reset", "Sprint")), true, "reset one system")
		equal((Schema.validateRequest(DEV, "reset")), true, "reset everything")
	end)

	case("DT1: the rate limit allows a burst, then refills over time", function()
		local limiter = Schema.newLimiter()
		local allowed = 0
		for _ = 1, 50 do if Schema.allow(limiter, 10) then allowed += 1 end end
		equal(allowed, Schema.RATE.burst, "one burst at the same instant")
		equal(Schema.allow(limiter, 10), false)
		equal(Schema.allow(limiter, 10 + 1 / Schema.RATE.perSecond + 1e-6), true, "a token refills")
		equal(Schema.allow(limiter, 0 / 0), false, "a bad clock refuses")
		equal(Schema.allow(nil, 10), false)
	end)

	case("DT1: the snippet lists every value as Luau and marks the changed ones", function()
		local text = Schema.snippet(reader({ Sprint = { SPRINT_MULTIPLIER = 1.6 } }))
		assert(type(text) == "string", "snippet")
		assert(text:find("return {", 1, true), "a table literal")
		assert(text:find("SPRINT_MULTIPLIER = 1.6, -- CHANGED (default 1.45)", 1, true), "changed line:\n" .. text)
		assert(text:find("DRAIN = 25,", 1, true), "unchanged values are listed")
		assert(text:find("1 changed", 1, true), "the count of changed values")
		-- Found in Play: in 70 lines a change is easy to miss, so the header lists every change first.
		local header = text:sub(1, (text:find("return {", 1, true)))
		assert(header:find("--   Sprint.SPRINT_MULTIPLIER = 1.6 (default 1.45) in src/wildbound/WildboundStamina.luau", 1, true),
			"the changed value is summarised before the table:\n" .. header)
		assert(text:find("src/wildbound/WildboundStamina.luau", 1, true), "where to commit it")
		for _, item in ipairs(entries()) do
			assert(text:find(item.entry.key .. " = ", 1, true), "listed " .. item.entry.key)
		end
		local clean = Schema.snippet(reader({}))
		assert(clean:find("0 changed", 1, true), "nothing changed without overrides")
		assert(not clean:find("-- CHANGED", 1, true), "no line is marked changed")
	end)

	case("DT1: ensureFolder builds the Configuration with the defaults and keeps existing values", function()
		local parent = Instance.new("Folder")
		local folder = Schema.ensureFolder(parent)
		equal(folder.Name, Schema.FOLDER); equal(folder.ClassName, "Configuration")
		for _, system in ipairs(Schema.SYSTEMS) do
			local child = folder:FindFirstChild(system.id)
			assert(child and child:IsA("Configuration"), "system folder " .. system.id)
			for _, entry in ipairs(system.entries) do equal(child:GetAttribute(entry.key), entry.default, entry.key) end
		end
		folder.Sprint:SetAttribute("SPRINT_MULTIPLIER", 1.7)
		equal(Schema.ensureFolder(parent), folder, "the same folder")
		equal(folder.Sprint:GetAttribute("SPRINT_MULTIPLIER"), 1.7, "a designer's value survives")
		parent:Destroy()
	end)

	case("DT2: no folder or no attribute behaves exactly as today", function()
		applyServer({})
		near(modules.Stamina.speed(16, "sprint"), 23.2, "sprint 16 x 1.45")
		equal(modules.Brain.speed("Hunt", "Night"), 17)
		equal(modules.Rules.TELEGRAPH_SECONDS, 0.9)
		-- Deliberately changed in the fear pass (FA2): the adult's chase speed default was 17.
		equal(modules.Island.live.CHASE_SPEED, 19)
		equal(modules.Island.hitEffect({ damageMode = "private", lethal = true }).damage, 35)
		equal(modules.View.sprintFov(70, "sprint", false), 80)
		equal(modules.Carry.mood({ alive = true, inFog = true, safe = false, mode = "Hunt", distance = 39 }), "afraid")
	end)

	case("DT2: a live override changes the behaviour value, and clearing it restores the default", function()
		applyServer({ Sprint = { SPRINT_MULTIPLIER = 1.2 },
			Silueta = { HUNT_TWILIGHT = 20, TELEGRAPH_SECONDS = 1.5, VISUAL_SCALE = 3 },
			Islands = { CHASE_SPEED = 10, DAMAGE = 50 }, Hide = { NIGHT_RADIUS = 9 }, Carry = { FEAR_RADIUS = 10 },
			Capture = { CALM_REQUIRED = 6 } })
		near(modules.Stamina.speed(16, "sprint"), 19.2, "sprint x1.2")
		equal(modules.Brain.speed("Hunt", "Dusk"), 20, "twilight is dusk")
		equal(modules.Brain.speed("Hunt", "Dawn"), 20, "and dawn")
		equal(modules.Brain.profile("Dusk").hunt, 20)
		equal(modules.Rules.TELEGRAPH_SECONDS, 1.5)
		equal(modules.Rules.resolveCreatureProfile("Silueta", "Day", false).visualScale, 3, "look pass: the art scale")
		local chase = modules.Island.newChase({ id = "I2", x = 0, z = 0 }, { x = 0, z = 0 })
		modules.Island.chaseStep(chase, 1, 0, 0) -- the wake wind-up
		modules.Island.chaseStep(chase, 0.1, 0, 30)
		near(chase.z, 1, "10 studs/s for 0.1 s")
		equal(modules.Island.hitEffect({ damageMode = "private", lethal = true }).damage, 50)
		local dwell = modules.Hide.newDwell()
		local found = false
		for _ = 1, 20 do
			found = modules.Hide.discover(dwell, { dt = 0.1, mode = "Search", distance = 8, phase = "Night" }) or found
		end
		equal(found, true, "a 9-stud night radius finds a player 8 studs away")
		equal(modules.Carry.mood({ alive = true, inFog = true, safe = false, mode = "Hunt", distance = 20 }), "uneasy")
		Schema.apply({ View = modules.View }, reader({ Camera = { SPRINT_FOV_KICK = 20 } }), "client")
		equal(modules.View.sprintFov(70, "sprint", false), 90, "client value on the client")
		-- The server never applies a client value, and the client never a server value.
		Schema.apply({ Stamina = modules.Stamina }, reader({ Sprint = { SPRINT_MULTIPLIER = 1.6 } }), "client")
		near(modules.Stamina.speed(16, "sprint"), 19.2, "a client never re-tunes the server modules")
		applyServer({})
		Schema.apply({ View = modules.View }, reader({}), "client")
		near(modules.Stamina.speed(16, "sprint"), 23.2, "back to the default")
		equal(modules.Brain.speed("Hunt", "Dawn"), 15)
		equal(modules.Rules.TELEGRAPH_SECONDS, 0.9)
		equal(modules.Rules.resolveCreatureProfile("Silueta", "Day", false).visualScale, 3.8)
		equal(modules.Island.live.CHASE_SPEED, 19)
		equal(modules.View.sprintFov(70, "sprint", false), 80)
	end)

	case("DT2: out-of-range attributes are clamped, wrong types and unknown keys are ignored", function()
		applyServer({ Sprint = { SPRINT_MULTIPLIER = 50, DRAIN = "fast" }, Islands = { NOT_A_KEY = 3 } })
		near(modules.Stamina.speed(10, "sprint"), 10 * Schema.find("Sprint", "SPRINT_MULTIPLIER").max, "clamped to the maximum")
		equal(modules.Stamina.live.DRAIN, 25, "a string is ignored")
		modules.Stamina.tune({ POOL_X = 5, DRAIN = 0 / 0, SPRINT_MULTIPLIER = "x" })
		equal(modules.Stamina.live.DRAIN, 25); equal(modules.Stamina.live.SPRINT_MULTIPLIER, 1.45)
		modules.Stamina.tune(nil)
		equal(modules.Stamina.CONSTANTS.SPRINT_MULTIPLIER, 1.45, "the defaults never change")
		assert(table.isfrozen(modules.Stamina.CONSTANTS), "the defaults stay frozen")
		assert(table.isfrozen(modules.Brain.PROFILES.Night), "the profile defaults stay frozen")
		applyServer({})
	end)

	case("DT2: tuning bumps the stamina version so the server re-applies WalkSpeed", function()
		local before = modules.Stamina.version
		assert(type(before) == "number", "version")
		modules.Stamina.tune({ SPRINT_MULTIPLIER = 1.3 })
		assert(modules.Stamina.version > before, "bumped")
		modules.Stamina.tune(nil)
	end)

	return result
end
