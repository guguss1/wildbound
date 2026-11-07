-- Invoke with require(freshTestClone)(WildboundServer.Source, WildboundWorld.Source, WildboundWorldClient.Source,
-- require(freshTextClone)). Dread pass, unit 1 (D3, D4 and decision D-D5): how the inventory server owns stamina,
-- WalkSpeed, the sprint noise and the carried Lumipol slipping free; how the world server lets a sprint reach the
-- guardian; and how the world client asks for a sprint without taking Shift from anything else. Source contracts
-- only: the behaviour is in WildboundStamina_Test and the Play check.
return function(serverSource, worldSource, clientSource, Text)
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

	case("D3: the server requires the pure rule and owns one stance remote", function()
		has(serverSource, 'require(script.Parent:WaitForChild("WildboundStamina"))')
		has(serverSource, 'stanceRemote.Name, stanceRemote.Parent = "Stance", network')
		has(serverSource, "stanceRemote.OnServerEvent:Connect(function(player, intent, ...)")
		has(serverSource, 'if type(intent) ~= "string" or select("#", ...) > 0 then return end', "one string, nothing else")
		has(serverSource, "STANCE_RATE", "rate limit")
		has(serverSource, "Stamina.intent(record.stamina, intent, now)")
	end)

	case("D3: WalkSpeed is the carry speed with the stance on top", function()
		has(serverSource, "record.baseSpeed = speed")
		has(serverSource, "speed = Stamina.speed(speed, record.stamina and record.stamina.stance or \"walk\")")
	end)

	case("D3: each step updates stamina, publishes it and makes the sprint noise outside camp", function()
		has(serverSource, "Stamina.step(record.stamina, dt, {")
		has(serverSource, 'player:SetAttribute("WildboundStamina"')
		has(serverSource, 'player:SetAttribute("WildboundStance"')
		has(serverSource, 'noiseEvent:Fire("sprint", tier, x, z)')
		has(serverSource, "blocked = capturing or hidden", "capture and hiding block a sprint")
	end)

	case("D3: respawn restores a full pool", function()
		has(serverSource, "record.stamina = Stamina.new(workspace:GetServerTimeNow())")
	end)

	case("D-D5: a frightened carried Lumipol warns, then slips free on the server", function()
		has(serverSource, "if out.warn then")
		has(serverSource, "Text.STAMINA.slipWarning")
		has(serverSource, "state:releaseCarried(player.UserId)")
		has(serverSource, "Text.STAMINA.slipped")
	end)

	case("D3: the world server lets a sprint reach the guardian", function()
		has(worldSource, 'if kind == "ring" or kind == "seal" or kind == "sprint" then hearNoise(kind, tier, x, z) end')
	end)

	case("D4: the client asks through a sinking high-priority action, so Shift does not toggle shift lock", function()
		has(clientSource, 'ContextActionService:BindActionAtPriority("WildboundSprint"')
		has(clientSource, "Enum.ContextActionPriority.High.Value")
		has(clientSource, "Enum.KeyCode.LeftShift")
		has(clientSource, "Enum.KeyCode.ButtonL3")
		has(clientSource, "return Enum.ContextActionResult.Sink")
		has(clientSource, 'stanceRemote:FireServer("sprint")')
		has(clientSource, 'stanceRemote:FireServer("walk")')
		has(clientSource, 'player:GetAttributeChangedSignal("WildboundStamina")')
	end)

	case("D4: stamina and slip words are Spanish and live in WildboundText", function()
		local words = Text.STAMINA
		assert(type(words) == "table", "STAMINA table")
		assert(words.label == "Aliento" and words.sprint == "Correr" and words.exhausted == "Sin aliento", "labels")
		assert(words.slipWarning == "¡Tu Lumipol se asusta! Deja de correr.", "warning: " .. tostring(words.slipWarning))
		assert(type(words.slipped) == "string" and words.slipped:find("Lumipol", 1, true), "slipped notice")
	end)

	return result
end
