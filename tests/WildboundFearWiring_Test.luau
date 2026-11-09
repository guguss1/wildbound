-- Invoke with require(freshTestClone)({ fear = WildboundFearClient.Source, world = WildboundWorldClient.Source,
-- audio = WildboundAudioClient.Source }). Fear pass (FA3, the feature document's "Fear and adrenaline pass"): source contracts
-- for the fear client (the adrenaline burst, the hit feedback, the heartbeat intensity), the world client's field
-- of view and the audio client's new cues. The numbers are pure rules in WildboundHudView and WildboundAudioMix; what
-- it looks and sounds like is checked in Studio Play.
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
	local function hasNot(source, needle, label)
		assert(not source:find(needle, 1, true), (label or "unexpected") .. ": " .. needle)
	end
	local fear, world, audio = sources.fear or "", sources.world or "", sources.audio or ""

	case("FA3: the fear client reads the server's island and capture events, never sends anything", function()
		has(fear, 'WaitForChild("WildboundNetwork"')
		has(fear, "state.OnClientEvent")
		for _, action in ipairs({ '"IslandChase"', '"IslandWoke"', '"IslandStrike"', '"IslandCaught"', '"Capture"', '"Pickup"' }) do
			has(fear, action)
		end
		hasNot(fear, "FireServer", "the fear client never asks the server for anything")
		hasNot(fear, "InvokeServer", "the fear client never asks the server for anything")
	end)

	case("FA3: the burst is drawn from the pure rules and respects Efectos suaves", function()
		has(fear, "View.fear(")
		has(fear, "View.threat(")
		has(fear, 'GetAttribute("Reduced")')
		has(fear, "Text.FEAR")
		has(fear, "BindToRenderStep")
		has(fear, "Enum.RenderPriority.Camera.Value + 2", "after the camera and the chase feel")
	end)

	case("FA3: a landed hit pushes the player away, flashes and shows the damage", function()
		has(fear, "View.knockback(")
		has(fear, "AssemblyLinearVelocity", "the client owns its character, so the push is applied here")
		has(fear, "HealthChanged")
		has(fear, '"WildboundIslandAdult"')
		has(fear, 'SetAttribute("LastHitSound", "hit")', "the audio client's hit hook")
	end)

	case("FA3: the fear client hands the audio and the camera their numbers through the world interface", function()
		has(fear, 'SetAttribute("FearHeart"')
		has(fear, 'SetAttribute("FearCue"')
		has(fear, 'SetAttribute("FearCueAt"')
		has(fear, 'SetAttribute("FearFov"')
		has(world, 'GetAttribute("FearFov")', "the world client adds the punch to its field of view goal")
	end)

	case("FA3: the audio client plays the heartbeat, the roar, the grab stinger and the distant call", function()
		has(audio, 'GetAttribute("FearHeart")')
		has(audio, "Mix.heart(")
		has(audio, 'setLayer("heartbeat"')
		has(audio, 'GetAttributeChangedSignal("FearCueAt")')
		has(audio, '"roar"')
		has(audio, '"call"')
		has(audio, 'GetAttribute("Awake")', "a parent that wakes roars")
	end)

	return result
end
