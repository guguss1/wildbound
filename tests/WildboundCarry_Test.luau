-- Invoke with require(freshTestClone)(require(freshCarryClone), freshCarryClone.Source, require(freshTextClone),
-- { server = WildboundServer.Source, world = WildboundWorldClient.Source, client = WildboundClient.Source }).
-- Delivery B (B2): the carried creature's mood from the existing threat reading, its glow and small movements,
-- the sound hook and the HUD line. Pure rules; the server builds the capsule and the clients animate it.
return function(Carry, source, Text, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local K = Carry.CONFIG
	sources = type(sources) == "table" and sources or {}
	local function reading(mode, distance, inFog, safe, alive)
		return { mode = mode, distance = distance, inFog = inFog, safe = safe, alive = alive ~= false }
	end

	case("B2: mood is afraid when Silueta hunts close in the fog, uneasy farther, calm otherwise", function()
		equal(Carry.mood(reading("Chase", K.FEAR_RADIUS, true, false)), "afraid")
		equal(Carry.mood(reading("Patrol", 10, true, false)), "afraid")
		equal(Carry.mood(reading("Chase", K.FEAR_RADIUS + 1, true, false)), "uneasy")
		equal(Carry.mood(reading("Chase", K.UNEASY_RADIUS, true, false)), "uneasy")
		equal(Carry.mood(reading("Chase", K.UNEASY_RADIUS + 1, true, false)), "calm")
		equal(Carry.mood(reading("Retreat", 10, true, false)), "uneasy", "a retreating Silueta still unsettles it up close")
		equal(Carry.mood(reading("Retreat", K.FEAR_RADIUS + 1, true, false)), "calm")
	end)

	case("B2: camp, the open field, death and a missing reading are calm", function()
		equal(Carry.mood(reading("Chase", 5, true, true)), "calm", "safe zone")
		equal(Carry.mood(reading("Chase", 5, false, false)), "calm", "out of the fog")
		equal(Carry.mood(reading("Chase", 5, true, false, false)), "calm", "dead")
		equal(Carry.mood(nil), "calm")
		equal(Carry.mood({}), "calm")
		for _, bad in ipairs({ 0 / 0, math.huge, -1, "5" }) do
			equal(Carry.mood(reading("Chase", bad, true, false)), "calm", tostring(bad))
		end
	end)

	case("B2: each mood has its own glow, and an unknown mood looks calm", function()
		local seen = {}
		for _, mood in ipairs(Carry.MOODS) do
			local look = Carry.look(mood)
			for _, channel in ipairs({ "r", "g", "b" }) do
				local value = look.glow[channel]
				assert(type(value) == "number" and value >= 0 and value <= 255, mood .. " " .. channel)
			end
			assert(look.brightness > 0 and look.brightness <= 3, mood .. " brightness")
			local key = look.glow.r .. "," .. look.glow.g .. "," .. look.glow.b
			assert(not seen[key], "two moods share a glow")
			seen[key] = true
		end
		equal(#Carry.MOODS, 3)
		equal(Carry.look("nope").glow.r, Carry.look("calm").glow.r)
		assert(Carry.look("afraid").brightness > Carry.look("calm").brightness, "fear glows brighter")
	end)

	case("B2: small movements stay small; a calm creature bobs without shaking, a scared one shakes", function()
		local calmShake, fearShake, maxBob = 0, 0, 0
		for step = 0, 400 do
			local t = step / 60
			local calm, fear = Carry.pose("calm", t), Carry.pose("afraid", t)
			calmShake = math.max(calmShake, math.abs(calm.x))
			fearShake = math.max(fearShake, math.abs(fear.x))
			maxBob = math.max(maxBob, math.abs(calm.y), math.abs(fear.y))
			assert(math.abs(fear.roll) <= K.SHAKE_ROLL + 1e-9, "roll bounded")
		end
		equal(calmShake, 0, "calm never shakes")
		assert(fearShake > 0.05 and fearShake <= K.SHAKE_AMPLITUDE + 1e-9, "fear shakes within bounds: " .. fearShake)
		assert(maxBob > 0 and maxBob <= K.BOB_AMPLITUDE + 1e-9, "bob within bounds: " .. maxBob)
		local a, b = Carry.pose("uneasy", 1.25), Carry.pose("uneasy", 1.25)
		equal(a.x, b.x); equal(a.y, b.y)
		local bad = Carry.pose("calm", 0 / 0)
		equal(bad.x, 0); equal(bad.y, 0); equal(bad.roll, 0)
	end)

	case("B2: the sound hook fires on a rise in fear, once, never while calm and never constantly", function()
		local memory = Carry.newSoundMemory()
		equal(Carry.soundCue(memory, "calm", 0), nil)
		equal(Carry.soundCue(memory, "afraid", 1), "fear")
		local repeats = 0
		for second = 2, 120 do
			if Carry.soundCue(memory, "afraid", second) then repeats += 1 end
		end
		equal(repeats, 0, "staying afraid makes no further sound")
		equal(Carry.soundCue(memory, "calm", 121), nil)
		equal(Carry.soundCue(memory, "uneasy", 121.5), "unease")
		equal(Carry.soundCue(memory, "calm", 122), nil)
		equal(Carry.soundCue(memory, "afraid", 123), nil, "within the cooldown")
		equal(Carry.soundCue(memory, "calm", 124), nil)
		equal(Carry.soundCue(memory, "afraid", 121.5 + K.SOUND_COOLDOWN), "fear")
		local flicker = Carry.newSoundMemory()
		local cues = 0
		for step = 0, 600 do
			if Carry.soundCue(flicker, step % 2 == 0 and "afraid" or "calm", step * 0.5) then cues += 1 end
		end
		assert(cues <= math.ceil(300 / K.SOUND_COOLDOWN) + 1, "a flickering mood is rate limited: " .. cues)
		equal(Carry.soundCue(flicker, "afraid", 0 / 0), nil)
	end)

	case("B2: the HUD line names the creature and its state in Spanish, within any budget", function()
		equal(Carry.hudLine(nil, "calm", Text, 60), nil)
		local carried = { uid = "wb:1", kind = "Creature", species = "Lumipol", protected = false }
		local full = Carry.hudLine(carried, "afraid", Text, 80)
		assert(full.text:find("Lumipol", 1, true), full.text)
		assert(full.text:find(Text.CARRY.moods.afraid, 1, true), full.text)
		assert(full.text:find(Text.CARRY.unwarded, 1, true), full.text)
		equal(full.tone, "risk")
		equal(Carry.hudLine(carried, "calm", Text, 80).tone, "calm")
		local warded = Carry.hudLine({ species = "Lumipol", protected = true }, "calm", Text, 80)
		assert(warded.text:find(Text.CARRY.warded, 1, true), warded.text)
		for budget = 7, 90 do
			local line = Carry.hudLine(carried, "uneasy", Text, budget)
			assert(#line.text <= budget, budget .. ": " .. line.text)
			assert(utf8.len(line.text) ~= nil, "valid UTF-8 at " .. budget)
		end
	end)

	case("B2: the carry words live in the Spanish text module", function()
		local C = Text.CARRY
		assert(type(C) == "table" and table.isfrozen(C), "CARRY group frozen")
		for _, mood in ipairs(Carry.MOODS) do
			assert(type(C.moods[mood]) == "string" and #C.moods[mood] > 0 and #C.moods[mood] <= 14, mood)
		end
		for _, key in ipairs({ "label", "warded", "unwarded" }) do
			assert(type(C[key]) == "string" and #C[key] > 0 and #C[key] <= 16, key)
		end
	end)

	case("B2: the capsule is built by the server and animated by every client", function()
		local server, world, client = sources.server, sources.world, sources.client
		assert(type(server) == "string" and type(world) == "string" and type(client) == "string", "sources missing")
		assert(server:find("WildboundCarry", 1, true), "the server reads the carry rules")
		assert(server:find("\"WildboundCarryCapsule\"", 1, true), "the server names the capsule")
		assert(server:find("SetAttribute(\"Mood\"", 1, true), "the server publishes the mood")
		assert(server:find("SetAttribute(\"SoundCue\"", 1, true), "the server publishes the sound hook")
		assert(world:find("WildboundCarryCapsule", 1, true) and world:find("Carry.pose", 1, true),
			"the world client animates every capsule")
		assert(client:find("Carry.hudLine", 1, true), "the HUD shows the carried creature")
		assert(not server:find("Instance.new(\"Sound\")", 1, true), "no sound in delivery B")
	end)

	case("the module source is pure", function()
		assert(type(source) == "string" and #source > 200, "source missing")
		for _, banned in ipairs({ "GetService", "require", "workspace", "game%.", "Instance", "os%.", "tick%(" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end
