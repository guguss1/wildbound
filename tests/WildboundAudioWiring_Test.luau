-- Invoke with require(freshTestClone)(WildboundAudioClient.Source). Delivery D10: source contracts for the audio
-- controller. What it sounds like is not testable here; Studio Play reads the Sound properties instead (D13).
return function(source)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(needle, label)
		assert(type(source) == "string" and source:find(needle, 1, true), (label or needle) .. " missing")
	end
	local function count(needle)
		local found, from = 0, 1
		while true do
			local at = source:find(needle, from, true)
			if not at then return found end
			found, from = found + 1, at + #needle
		end
	end
	source = type(source) == "string" and source or ""

	case("D10: only catalog ids are used", function()
		assert(not source:find("%d%d%d%d%d%d%d"), "an asset id is written in the controller")
		has("Catalog.SOUNDS[slot]", "sounds are looked up by slot")
		has("\"rbxassetid://\" .. chosen", "the id comes from the catalog entry")
	end)

	case("D10: no Sound is created without a group", function()
		assert(count("Instance.new(\"Sound\")") == 2, "only the load probe and newSound make sounds")
		has("sound.SoundGroup = groups[entry.group]")
		assert(not source:find("probe.Parent", 1, true) and not source:find("probe:Play", 1, true), "probes never play")
		has("count >= Mix.LIMITS.sounds", "the 14-instance cap")
	end)

	case("D10: a failed load is skipped without an error", function()
		has("if not failed[id] then chosen = id break end")
		has("if not chosen then return nil end")
		has("pcall(function()\n\t\tContentProvider:PreloadAsync(", "preload cannot throw")
		has("local ok, message = pcall(update, step)", "a bad frame never stops the controller")
	end)

	case("D10: events older than 2 s are ignored", function()
		has("if not Mix.fresh(at, now) then return end")
		has("Mix.jumpscareAllowed(jumpscare,", "the stinger goes through the gate")
	end)

	case("D10: cleanup destroys every Sound and group", function()
		has("holder:Destroy()")
		has("master:Destroy()")
		has("listen(script.Destroying, cleanup)")
		has("WildboundCue\" then child:Destroy()", "cue anchors are removed")
	end)

	case("D10: the controller reads only replicated state, never a remote", function()
		has("player:GetAttribute(\"WildboundThreatLevel\")")
		has("player:GetAttribute(\"WildboundHidden\")")
		assert(not source:find("FireServer", 1, true) and not source:find("InvokeServer", 1, true), "audio never talks to the server")
	end)

	return result
end
