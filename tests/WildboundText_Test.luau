-- Invoke with require(freshTestClone)(require(freshTextClone), freshTextClone.Source, { capture = WildboundCaptureSession.Source,
-- view = WildboundCaptureView.Source, client = WildboundCaptureClient.Source, server = WildboundServer.Source }).
-- Decision H3 (delivery A): every player-facing string on the capture path lives in ReplicatedStorage.WildboundText,
-- in neutral Spanish. Code, comments and docs stay English. Lengths are bytes, as the views measure them.
return function(Text, source, sources)
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
	local function text(value, label, limit)
		assert(type(value) == "string" and #value > 0, label .. " missing")
		assert(not limit or #value <= limit, label .. " is " .. #value .. " bytes, over " .. tostring(limit) .. ": " .. value)
		assert(utf8.len(value) ~= nil, label .. " is not valid UTF-8")
	end
	sources = type(sources) == "table" and sources or {}

	local ENDINGS = { "Completed", "LeftRing", "TimedOut", "TooFar", "Struck", "Defeated", "BackpackFull",
		"CollectionFull", "Cancelled", "Lost", "LostTrack", "Watchdog", "SealMissed" }
	local REFUSALS = { "AlreadyCapturing", "InvalidContext", "InvalidEncounter", "InvalidPlayer", "AlreadyClaimed",
		"Reserved", "RetryWait", "FirstCaptureOnly", "FirstCapturePending", "Wary" }
	local HEADLINED = { "LeftRing", "TimedOut", "TooFar", "Struck", "Defeated", "Cancelled", "Lost", "LostTrack",
		"Watchdog", "SealMissed" }

	case("H3: the module is a frozen tree of strings", function()
		assert(type(Text) == "table" and table.isfrozen(Text), "module frozen")
		for _, group in ipairs({ "CAPTURE_NOTICES", "CAPTURE_HEADLINES", "CAPTURE_VIEW", "ARROWS", "PROMPTS", "HINTS" }) do
			assert(type(Text[group]) == "table" and table.isfrozen(Text[group]), group .. " frozen")
		end
		for reason, row in pairs(Text.CAPTURE_HEADLINES) do assert(table.isfrozen(row), reason .. " row frozen") end
	end)

	case("H3: every capture ending and refusal has a notice of at most 64 bytes; leaving is silent", function()
		for _, reason in ipairs(ENDINGS) do text(Text.CAPTURE_NOTICES[reason], reason, 64) end
		for _, reason in ipairs(REFUSALS) do text(Text.CAPTURE_NOTICES[reason], reason, 64) end
		equal(Text.CAPTURE_NOTICES.Disconnected, "")
	end)

	case("H3: the notices are Spanish and name their cause", function()
		local N = Text.CAPTURE_NOTICES
		assert(N.LeftRing:find("anillo", 1, true), N.LeftRing)
		assert(N.TooFar:find("alejaste", 1, true), N.TooFar)
		assert(N.Struck:find("Silueta", 1, true), N.Struck)
		assert(N.TimedOut:find("quieto", 1, true), N.TimedOut)
		assert(N.Cancelled:find("detuviste", 1, true), N.Cancelled)
		assert(N.Completed:find("campamento", 1, true), N.Completed)
		assert(N.SealMissed:find("sello", 1, true), N.SealMissed)
		assert(N.Wary:find("despacio", 1, true), N.Wary)
		equal(N.Completed:sub(1, #Text.CAPTURE_VIEW.caught), Text.CAPTURE_VIEW.caught, "Completed opens with the Caught headline")
		for reason, value in pairs(N) do
			for _, english in ipairs({ "You ", "the ring", "Try again", "Lumipol fled" }) do
				assert(not value:find(english, 1, true), reason .. " still reads English: " .. value)
			end
		end
	end)

	case("H3: every ending headline has a full and a short form; short ones fit 14 bytes; full ones differ", function()
		local seen = {}
		for _, reason in ipairs(HEADLINED) do
			local row = Text.CAPTURE_HEADLINES[reason]
			assert(type(row) == "table", reason .. " has no headline")
			text(row[1], reason .. " full", 28)
			text(row[2], reason .. " short", 14)
			assert(not seen[row[1]], "shared headline " .. row[1])
			seen[row[1]] = true
		end
		equal(Text.CAPTURE_HEADLINES.Completed, nil, "the Caught headline lives in CAPTURE_VIEW")
	end)

	case("H3: ring, seal and stop words for the capture screen, within their budgets", function()
		local V = Text.CAPTURE_VIEW
		for key, limit in pairs({ waitingShort = 14, outsideShort = 10, slow = 14, step = 14, calm = 14, caught = 14,
			sealShort = 14, ended = 20, stop = 8, sealButton = 8 }) do
			text(V[key], key, limit)
		end
		for key, limit in pairs({ waiting = 28, outside = 20, seal = 28 }) do text(V[key], key, limit) end
		for _, key in ipairs({ "waitingDetail", "outsideDetail", "slowDetail", "stepDetail", "calmDetail", "sealDetail" }) do
			text(V[key], key, 64)
		end
		assert(V.move:find("%s", 1, true), "move is a format with one %s")
		equal(select(2, V.move:gsub("%%s", "")), 1)
		local words = {}
		for _, key in ipairs({ "waiting", "outside", "slow", "step", "calm", "caught", "seal", "ended" }) do
			assert(not words[V[key]], "two states share " .. V[key])
			words[V[key]] = true
		end
	end)

	case("H3: eight arrow words, clockwise from ahead, all distinct", function()
		equal(#Text.ARROWS, 8)
		local seen = {}
		for index, word in ipairs(Text.ARROWS) do
			text(word, "arrow " .. index, 28)
			assert(not seen[word], "duplicate arrow word " .. word)
			seen[word] = true
		end
		equal(Text.ARROWS[1], "adelante")
		equal(Text.ARROWS[5], "atrás")
	end)

	case("H3: prompt and reaction hint words", function()
		text(Text.PROMPTS.calm, "calm prompt", 16)
		text(Text.PROMPTS.lumipol, "lumipol prompt", 16)
		for _, mode in ipairs({ "Alert", "Flee", "Hide", "Peek" }) do text(Text.HINTS[mode], "hint " .. mode, 48) end
		equal(Text.HINTS.Idle, nil)
	end)

	case("H3: the capture path reads its words from this module, not from English literals", function()
		local capture, view, client, server = sources.capture, sources.view, sources.client, sources.server
		assert(type(capture) == "string" and type(view) == "string" and type(client) == "string" and type(server) == "string",
			"sources missing")
		assert(not capture:find("NOTICES", 1, true), "the capture rule keeps no words of its own")
		assert(view:find("WildboundText", 1, true), "the view reads WildboundText")
		assert(client:find("WildboundText", 1, true), "the capture client reads WildboundText")
		assert(server:find("WildboundText", 1, true), "the server reads WildboundText")
		for _, english in ipairs({ "\"Stop\"", "Stay still", "Back into the ring", "Waiting for server", "Caught!", "\"Move \"" }) do
			assert(not view:find(english, 1, true) and not client:find(english, 1, true), "English left: " .. english)
		end
		assert(not server:find("\"Calm\"", 1, true), "the Lumipol prompt still says Calm")
	end)

	case("B1: a capture refused or ended for a full carry slot says so in Spanish", function()
		local N = Text.CAPTURE_NOTICES
		text(N.AlreadyCarrying, "AlreadyCarrying", 64)
		assert(N.BackpackFull:find("criatura", 1, true), "BackpackFull now means the carry slot: " .. N.BackpackFull)
		assert(N.AlreadyCarrying:find("criatura", 1, true), N.AlreadyCarrying)
	end)

	case("D-C5: strike notices and the defeat screen in Spanish, within their budgets", function()
		local S, D = Text.STRIKE, Text.DEFEAT
		assert(type(S) == "table" and type(D) == "table", "STRIKE and DEFEAT tables")
		for _, key in ipairs({ "defeated", "marked", "dropped", "rest", "shortDropped", "shortMarked", "egg", "creature",
			"spared", "dodge", "rested", "restedShort" }) do text(S[key], "STRIKE." .. key, 72) end
		for _, name in ipairs({ S.egg, S.creature }) do
			assert(#S.shortDropped:format(name) <= 50, "short drop for " .. name)
			assert(S.shortDropped:format(name):find("30 s", 1, true), "names the 30 seconds")
		end
		text(S.shortMarked, "STRIKE.shortMarked", 50); text(S.spared, "STRIKE.spared", 64); text(S.dodge, "STRIKE.dodge", 40)
		for _, key in ipairs({ "title", "nothing", "lost", "more", "item", "items", "materials", "savedMany", "savedOne", "kept",
			"egg", "eggs", "safe", "material", "materialsWord", "close", "eggName", "bundle", "bundleCount", "notice" }) do
			text(D[key], "DEFEAT." .. key, 120)
		end
		for _, key in ipairs({ "fogbark", "glowmoss", "nightbloom" }) do text(D.materialNames[key], "DEFEAT.materialNames." .. key, 24) end
		assert(not D.title:find("Defeated", 1, true) and not D.close:find("Tap", 1, true), "Spanish, not English")
		assert(D.notice:find("campamento", 1, true) == nil or #D.notice <= 120)
	end)
	case("D6: hiding words in Spanish, within their budgets", function()
		local H = Text.HIDE
		assert(type(H) == "table", "HIDE table")
		equal(H.prompt, "Esconderse")
		equal(H.exit, "Salir")
		for _, key in ipairs({ "entered", "seen", "occupied", "busy", "tooLong", "found", "cooldown" }) do
			text(H[key], "HIDE." .. key, 64)
		end
		text(H.short, "HIDE.short", 40)
		equal(H.kind.bush, "Arbusto espeso")
		equal(H.kind.log, "Tronco hueco")
		assert(not H.entered:find("hide", 1, true) and not H.found:find("found", 1, true), "Spanish, not English")
	end)
	case("the module source holds data only", function()
		assert(type(source) == "string" and #source > 200, "source missing")
		for _, banned in ipairs({ "GetService", "require", "workspace", "game%.", "Instance" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	-- Expedition islands (I8, K2, EI-6): the island, cry, card and upgrade words, Spanish and within their budgets.
	case("I8: island words exist and are Spanish", function()
		local I = Text.ISLAND
		assert(type(I) == "table" and table.isfrozen(I), "ISLAND frozen")
		equal(I.names.I1, "Claro de los Lumipol"); equal(I.names.I2, "Hondonada del Musgo")
		equal(I.names.I3, "Pantano de los Juncos"); equal(I.names.I4, "Ruinas del Nido")
		equal(I.names.I5, "Corazón de la Niebla")
		for id, name in pairs(I.names) do text(name, "ISLAND.names." .. id, 28) end
		equal(I.takeCria, "Tomar la cría"); equal(I.takeEgg, "Tomar el huevo")
		text(I.takeCria, "takeCria", 24); text(I.takeEgg, "takeEgg", 24)
		for _, key in ipairs({ "stir", "woke", "guarded", "firstOnly", "caught", "chased", "screamHeard", "strike", "hit" }) do
			text(I[key], "ISLAND." .. key, 72)
		end
		equal(I.stir, "Shh... se están despertando.")
		equal(I.woke, "¡Te descubrieron! Su grito resuena en el bosque.")
		equal(I.guarded, "El nido está vigilado. Vuelve más tarde.")
		equal(I.firstOnly, "En el claro solo se toma la primera cría. Busca más adentro.")
		equal(Text.CARRY.cry, "La cría llora. ¡Algo la escucha!")
		equal(Text.CARD.newSpecies, "¡Nueva especie!")
		equal(Text.CARD.next, "Próxima isla: %s. Allí duermen los %s.")
		equal(Text.CARD.firstBonus, "+%d Ember por tu primera cría")
		equal(Text.UPGRADE.farolTapado.name, "Farol tapado")
		equal(Text.UPGRADE.farolTapado.description, "Tu linterna molesta menos a las criaturas dormidas.")
		for _, species in ipairs({ "Lumipol", "Cortezon", "Cestillo", "Polvilla", "Tizoncillo" }) do
			text(Text.CARD.species[species], "species " .. species, 16)
			text(Text.CARD.blurb[species], "blurb " .. species, 80)
		end
		equal(Text.CARD.species.Cortezon, "Cortezón")
		for key, value in pairs(I) do
			if type(value) == "string" then
				for _, english in ipairs({ "the ", "nest", "wake", "steal" }) do
					assert(not value:lower():find(english, 1, true), key .. " reads English: " .. value)
				end
			end
		end
	end)

	return result
end
