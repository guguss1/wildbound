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

	-- Stalk sightings: a client-only apparition at the edge of sight, from the pure rules, that never collides, is
	-- never seen by La Silueta's sight casts and never reaches the server.
	case("Stalk: the fear client stages sightings from the pure rules, behind trunk cores, client-only", function()
		has(fear, "View.stalkAllowed(")
		has(fear, "View.stalkInterval(")
		has(fear, "View.stalkSpot(")
		has(fear, "View.stalkVanish(")
		has(fear, "View.STALK_KEEP_OUT")
		has(fear, "View.farFromHome(root.Position.X, root.Position.Z)", "HV-H1: the hub counts as home")
		has(fear, "View.inHub(root.Position.X, root.Position.Z)", "HV-H1: no sighting is staged inside the hub")
		assert(not fear:find("FAR_FROM_CAMP", 1, true), "HV-H1: the camp-only distance is gone")
		has(fear, '"FK_TrunkCore"')
		has(fear, "CanCollide = false")
		has(fear, "CanQuery = false")
		has(fear, 'GetAttribute("Phase")')
		has(fear, 'SetAttribute("StalkCount"')
		-- Play finding: at the night fog's edge the art's thin pale eye slit did not read. Two red eyes drawn on a
		-- billboard that ignores the light (still hidden behind trunks) are what the player sees first.
		has(fear, '"BillboardGui"')
		has(fear, "LightInfluence = 0")
		has(fear, "AlwaysOnTop = false")
		-- Play finding: the ground probe hit a tree crown and refused the spot; only colliding ground counts.
		has(fear, "RespectCanCollide = true")
	end)

	case("Stalk: the audio client whispers on a sighting, but not with Efectos suaves", function()
		has(audio, 'kind == "stalk"')
	end)

	-- Look pass: the server shows La Silueta's HorrorGrin when she hunts; this client only animates its arrival.
	case("Look pass: the fear client pops the horror grin from the pure rule and Efectos suaves", function()
		has(fear, '"HorrorGrin"')
		has(fear, 'GetPropertyChangedSignal("Enabled")')
		has(fear, "View.grinPop(")
		has(fear, "GroupTransparency")
		has(fear, '"Pop"')
	end)
	case("Look pass: a stalk sighting never copies the grin", function()
		has(fear, 'item.Name == "HorrorGrin"')
	end)

	-- Fix pass (FP5d): sleeping parents breathe on every client (slower in the deep noon sleep); presentation only.
	case("FP5d: the world client makes sleeping adults breathe through the pure rule", function()
		local world = sources.world or ""
		assert(world:find("View.breath(", 1, true), "the pure breathing rule")
		assert(world:find('GetAttribute("Awake") ~= true', 1, true), "only a sleeping adult breathes")
		assert(world:find('GetAttribute("Deep") == true', 1, true), "deep sleep breathes slower")
	end)

	-- Added (UR-H4, owner request 2026-11-20: "quiero que la ui de mi juego sea exactamente igual a la de la foto que te
	-- envie"): the shouts and the damage number in the reference's loud outlined letters; words and timing unchanged.
	case("UR-H4: the shouts are loud outlined capitals and both outlines fade with their words", function()
		has(fear, "shout.Font = Enum.Font.LuckiestGuy")
		has(fear, "local shoutStroke = thickOutline(shout, 4,")
		has(fear, "local damageStroke = thickOutline(damage, 3,")
		has(fear, "ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual", "an outline of the letters, not of the box")
		has(fear, "TweenService:Create(shoutStroke, TweenInfo.new(0.3), { Transparency = 1 })", "the shout's outline fades")
		has(fear, "TweenService:Create(damageStroke, info, { Transparency = 1 })", "the damage outline fades")
		has(fear, "(WORDS.damage or \"-%d\")", "the damage words still come from WildboundText")
		hasNot(fear, "ImageLabel", "nothing uploaded"); hasNot(fear, "ImageButton", "nothing uploaded")
	end)
	return result
end
