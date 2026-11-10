-- Invoke with require(freshTestClone)({ bridge = WildboundTuning.Source, panel = WildboundTuningClient.Source,
-- server = WildboundServer.Source, world = WildboundWorld.Source }). Dev tuning (docs/testing/wildbound-tuning.md):
-- source contracts for the server bridge (the folder, the live apply, the remote's server checks and its log), the
-- developer panel (built only for a developer, the toggles, reset and export) and the world server's live art scale.
-- The behaviour is in WildboundTuning_Test and the Play check.
return function(sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and source:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function before(source, first, second, label)
		local a, b = source:find(first, 1, true), source:find(second, 1, true)
		assert(a and b and a < b, (label or "order") .. ": " .. first .. " before " .. second)
	end
	local bridge, panel, server = sources.bridge, sources.panel, sources.server

	case("DT3: the bridge builds the folder from the schema and applies it to the server modules", function()
		has(bridge, 'require(ReplicatedStorage:WaitForChild("WildboundTuningSchema"))')
		has(bridge, "Schema.ensureFolder(ReplicatedStorage)")
		has(bridge, 'Schema.apply(modules, read, "server")')
		has(bridge, ".AttributeChanged:Connect(")
		for _, name in ipairs({ "WildboundStamina", "WildboundIsland", "WildboundGuardianBrain", "WildboundWorldRules",
			"WildboundHide", "WildboundCarry", "WildboundCaptureSession",
			-- Fix pass (FP4): La Silueta's moves.
			"WildboundSiluetaMoves",
			-- Random world (RW2): the spawn clock.
			"WildboundSpawnClock",
			-- Random world (RW3): the wave clock.
			"WildboundWaveClock",
			-- Items and totem (plan Part 4): the gear rules.
			"WildboundGear" }) do
			has(bridge, '"' .. name .. '"', "server module")
		end
		has(bridge, "Schema.changed(read)", "values that differ from the defaults are logged at start")
	end)

	case("DT3: an out-of-range attribute is clamped and written back; a wrong type is ignored", function()
		has(bridge, "Schema.sanitize(entry, raw)")
		has(bridge, "child:SetAttribute(name, clean)")
	end)

	case("DT3: the remote checks the caller, the rate, the key, the type and the range on the server", function()
		has(bridge, 'Instance.new("RemoteFunction")')
		has(bridge, "remote.OnServerInvoke = function(player, action, systemId, key, value, ...)")
		has(bridge, 'if select("#", ...) > 0 then return reject(player, "ExtraArguments") end')
		has(bridge, "Schema.allow(limiter, os.clock())")
		has(bridge, "Schema.validateRequest(contextFor(player), action, systemId, key, value)")
		before(bridge, "Schema.allow(limiter, os.clock())", "Schema.validateRequest(contextFor(player)", "rate first")
		has(bridge, "RunService:IsStudio()")
		has(bridge, "game.PlaceId")
		has(bridge, "game.CreatorId")
		has(bridge, "GetRankInGroup")
		has(bridge, "warn(", "rejections are logged")
		has(bridge, "Tuning_rejected", "and counted")
	end)

	case("DT3: only the server decides who is a developer; a Studio check can pose as a non-developer", function()
		has(bridge, "player:SetAttribute(Schema.DEV_ATTRIBUTE, Schema.isDeveloper(contextFor(player)))")
		has(bridge, '"TuningSimulateNonDev"')
		has(bridge, "ServerStorage", "the simulation flag lives where no client can reach it")
	end)

	case("DT3: the inventory server re-applies WalkSpeed after a sprint value changes and reads live island values", function()
		has(server, "if out.changed or record.tuned ~= Stamina.version then")
		has(server, "record.tuned = Stamina.version")
		assert(not server:find("Island.CONSTANTS", 1, true), "the server reads Island.live, never the frozen defaults")
		has(server, "local C = Island.live")
	end)

	case("DT4: the panel applies client values for everyone but is built only for a developer", function()
		-- Items and totem (IT1): the amulet's fear softening (Gear) is a client value too. Deliberately changed from
		-- { View = View }.
		has(panel, 'Schema.apply({ View = View, Gear = Gear }, read, "client")')
		has(panel, "player:GetAttribute(Schema.DEV_ATTRIBUTE) == true")
		before(panel, 'Schema.apply({ View = View, Gear = Gear }, read, "client")', "player:GetAttribute(Schema.DEV_ATTRIBUTE) == true")
		before(panel, "player:GetAttribute(Schema.DEV_ATTRIBUTE) == true", 'Instance.new("ScreenGui")',
			"no interface before the developer check")
	end)

	case("DT4: the panel has a key, a button, collapsible systems, reset and the export box", function()
		has(panel, "Enum.KeyCode.F8")
		has(panel, '"Restablecer"')
		has(panel, '"Copiar valores"')
		has(panel, "Schema.snippet(read)")
		has(panel, "ClearTextOnFocus = false")
		has(panel, '"ScrollingFrame"')
		has(panel, "remote:InvokeServer(")
		has(panel, "Los cambios en Play se pierden al parar", "the persistence note")
	end)

	-- Look pass: Silueta.VISUAL_SCALE is read when the art is built and again whenever the tuned value changes.
	case("Look pass: the world server rescales La Silueta's art live from the tuned scale", function()
		local world = sources.world
		has(world, "Rules.resolveCreatureProfile(\"Silueta\", \"Day\", false)")
		has(world, "Rules.SILUETA_VISUAL_SCALE ~= artScale")
		has(world, "visual:setScale(Rules.SILUETA_VISUAL_SCALE)")
	end)

	return result
end
