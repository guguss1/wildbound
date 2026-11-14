-- Invoke with require(freshTestClone)({ server = WildboundServer.Source, worldServer = WildboundWorld.Source,
-- worldClient = WildboundWorldClient.Source, audio = WildboundAudioClient.Source, record = WildboundRecord.Source,
-- save = WildboundSave.Source, arrulloService = WildboundArrulloService.Source,
-- arrulloClient = WildboundArrulloClient.Source, dodgeService = WildboundDodgeService.Source,
-- tuning = WildboundTuning.Source, text = require(freshTextClone), schema = require(freshSchemaClone) }).
-- New mechanics wiring (docs/mechanics/wildbound-new-mechanics.md, odd/tasks/wildbound-new-mechanics.md W1 to W5):
-- source contracts for how the five prepared rules (Arrullo, Esquiva perfecta, the bat knockback, the luck totem's
-- schema 4 and the dusk warnings) are wired into the running scripts. The rules themselves are pinned by their own
-- suites (WildboundArrullo_Test, WildboundDodge_Test, WildboundBatKnock_Test, WildboundTotemRecord_Test,
-- WildboundDusk_Test). A missing source fails its case.
return function(sources)
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
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	local function block(text, startNeedle, endNeedle)
		assert(type(text) == "string", "source missing for " .. startNeedle)
		local i = text:find(startNeedle, 1, true)
		assert(i, "block start missing: " .. startNeedle)
		local j = text:find(endNeedle, i + #startNeedle, true)
		assert(j, "block end missing: " .. endNeedle)
		return text:sub(i, j)
	end
	sources = type(sources) == "table" and sources or {}
	local server = sources.server or ""

	-- NH-W13: the server script is at Luau's 200-local limit; the wiring adds no top-level local. The count is of names
	-- declared at column 0 (as tools/test_wildbound_mechanics_wiring.py counts them): 225 before the wiring (df278fd).
	local SERVER_LOCALS_BEFORE = 225
	local function topLevelLocals(code)
		local count = 0
		for line in (code .. "\n"):gmatch("([^\n]*)\n") do
			if line:sub(1, 6) == "local " then
				if line:find("^local%s+function%s+[%a_]") then
					count += 1
				else
					local head = line:sub(7):match("^([^=]*)") or ""
					for part in head:gmatch("[^,]+") do
						local name = part:match("^%s*([%a_][%w_]*)")
						if name then count += 1 end
					end
				end
			end
		end
		return count
	end
	case("NH-W13: the wiring adds no top-level local to the server script", function()
		assert(#server > 0, "server source missing")
		local count = topLevelLocals(server)
		assert(count <= SERVER_LOCALS_BEFORE, "top-level locals: " .. count .. ", was " .. SERVER_LOCALS_BEFORE)
		for _, name in ipairs({ "Arrullo", "Dodge", "DodgeService", "Knock", "Dusk", "dusk", "knocks", "knockRemote" }) do
			hasNot(server, "\nlocal " .. name .. " ", "a top-level local")
			hasNot(server, "\nlocal " .. name .. ",", "a top-level local")
		end
	end)

	-- W1 (Q2b, D10 pending): the Arrullo replaces the steal hold for the rare eggs.
	case("W1: one config list of Arrullo eggs (D10: Épica, Legendaria, the event egg) and a server-simulated session", function()
		local service = sources.arrulloService or ""
		has(service, 'Service.EGGS = table.freeze({ "Epica", "Legendaria", "Evento" })', "the D10 list, pending the owner")
		has(service, 'require(ReplicatedStorage:WaitForChild("WildboundArrullo"))')
		has(service, "Arrullo.session(rarity, Random.new(options.seed), options.now)")
		has(service, "Arrullo.advance(item.session, now)", "the server simulates on its own clock")
		has(service, "Arrullo.input(item.session, value, workspace:GetServerTimeNow())", "only hold or release, rate-limited")
		has(service, 'if select("#", ...) > 0 then return end', "one argument only")
		has(service, "1 / Service.VIEW_RATE"); has(service, "Service.VIEW_RATE = 10", "about 10 views a second")
		has(service, "remote:FireClient(player, payload)", "to that player only")
		hasNot(service, "FireAllClients")
		has(server, 'Heist.Arrullo = require(script.Parent:WaitForChild("WildboundArrulloService"))')
		has(server, "Heist.Arrullo.start(network)")
		has(server, "Heist.Arrullo.cancel(player)", "leaving ends it with no penalty")
	end)

	case("W1: a rare egg's prompt opens the Arrullo; a win steals through claimEgg, a loss is a failed ring", function()
		local spawn = block(server, "spawnEncounter = function(slot)", "\nend\n")
		has(spawn, "entry.arrullo = isEgg and Heist.Arrullo.qualifies(rarity, slot.special)")
		has(spawn, "isEgg and not entry.arrullo and EggCarry.holdFor(rarity, slot.special) or 0", "no hold on an Arrullo egg")
		local trigger = block(server, "entry.trigger = function(player)", "entry.connection = entry.prompt.Triggered")
		has(trigger, "if entry.arrullo then"); has(trigger, "Heist.Arrullo.begin(player, {")
		assert(trigger:find("if entry.arrullo then", 1, true) < trigger:find("EggCarry.holdComplete(", 1, true),
			"a rare egg never needs the hold")
		has(trigger, 'if status == "won" then'); has(trigger, "entry.claimEgg(player)")
		has(trigger, 'noiseEvent:Fire("ring", slot.tier or "Fog", at.X, at.Z)', "a loss is heard like a ring")
		has(trigger, 'Island.event(island.meter, "Failed",', "and is a mistake on the island meter")
		has(trigger, "Text.ARRULLO.timeout"); has(trigger, "Text.ARRULLO.lost"); has(trigger, "Text.ARRULLO.won")
		has(trigger, "distance <= reach", "the thief stays in the prompt's reach")
		has(trigger, "math.min(entry.prompt.MaxActivationDistance, 10)", "never past State:pickup's 10 studs")
		has(trigger, 'return distance <= reach or "far"', "walking away is a loss")
		has(sources.arrulloService or "", 'finish(player, "lost", "TooFar")')
		local claim = block(server, "entry.claimEgg = function(player)", "entry.trigger = function(player)")
		has(claim, "EggCarry.canSteal(eggs, id, player.UserId)"); has(claim, "state:pickup(player.UserId, id, alive, distance,")
		has(claim, "EggCarry.steal(eggs, id, player.UserId, reason)")
	end)

	case("W1: the client draws the meter, sends only hold and release, and is readable on a phone", function()
		local client = sources.arrulloClient or ""
		has(client, 'folder:WaitForChild("Arrullo", 15)')
		has(client, 'remote:FireServer(holding and "hold" or "release")', "only the two words")
		has(client, "if value == holding then return end", "only on a change")
		has(client, "Enum.KeyCode.Space, Enum.KeyCode.ButtonA"); has(client, "Enum.UserInputType.Touch")
		has(client, "Enum.ContextActionResult.Sink", "Space never jumps while the meter is open")
		has(client, "UISizeConstraint"); has(client, "TextWrapped = true")
		has(client, 'payload.kind == "open"'); has(client, 'payload.kind == "view"'); has(client, 'payload.kind == "close"')
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.ARRULLO) == "table", "Text.ARRULLO")
		for _, key in ipairs({ "title", "hint", "hold", "holdKey", "time", "won", "lost", "timeout" }) do
			assert(type(Text.ARRULLO[key]) == "string" and #Text.ARRULLO[key] > 0, "ARRULLO." .. key)
		end
		equal(Text.ARRULLO.won, "¡El huevo se calmó! Es tuyo.")
		local Schema = sources.schema
		for _, key in ipairs({ "TIMEOUT", "START", "LIFT", "GRAVITY", "MAX_SPEED", "ZONE_Rara", "ZONE_Epica",
			"ZONE_Legendaria", "SEGMENT_Rara", "SEGMENT_Epica", "SEGMENT_Legendaria", "FILL_Rara", "FILL_Epica",
			"FILL_Legendaria", "DRAIN_Rara", "DRAIN_Epica", "DRAIN_Legendaria" }) do
			assert(Schema and Schema.find("Arrullo", key), "tuning row Arrullo." .. key)
		end
		has(sources.tuning or "", 'Arrullo = "WildboundArrullo"')
	end)

	-- W4 (Q10): the luck totems are saved (schema 4).
	case("W4: the record is schema 4 through the sibling totem step: ladder, known field, blank, validate, profile seam", function()
		local record = sources.record or ""
		has(record, 'script.Parent:FindFirstChild("WildboundTotemRecord")')
		has(record, "Record.SCHEMA = TotemRecord.SCHEMA")
		has(record, "Record.MIGRATIONS = TotemRecord.ladder({")
		has(record, "totems = true,", "a known field, never copied as an unknown one")
		has(block(record, "function Record.blank()", "\nend\n"), "totems = {}")
		has(block(record, "function Record.fromProfile(", "\nend\n"), "record.totems = TotemRecord.fromProfile(profile, base)")
		has(block(record, "function Record.toProfile(", "\nend\n"), "TotemRecord.toProfile(record, profile)")
		has(block(record, "function Record.validate(", "\nend\n"), "TotemRecord.validate(record)")
		hasNot(record, "DataStoreService", "the record never names the store")
		local save = sources.save or ""
		has(block(save, "local function digestOf(self, view)", "\nend\n"), "view.luckTotems", "a totem change is saved")
	end)

	-- W2 (Q3b): Esquiva perfecta replaces the Burst.
	case("W2: one shared dodge state per player; the press, the speed and the prune live in the inventory server", function()
		local service = sources.dodgeService or ""
		has(service, 'require(ReplicatedStorage:WaitForChild("WildboundDodge"))')
		for _, needle in ipairs({ "function Service.telegraph(player, id, source, startAt, strikeAt)",
			"function Service.resolve(player, id, now)", "function Service.cancel(player, id)",
			"function Service.press(player, now, blocked)", "function Service.speed(player, base, now)",
			"function Service.prune(now)", "function Service.forget(player)" }) do
			has(service, needle)
		end
		has(service, "WildboundDodgeStrike"); has(service, "WildboundDodgeReady"); has(service, "WildboundDodgeBoost")
		has(server, 'Heist.DodgeService = require(script.Parent:WaitForChild("WildboundDodgeService"))')
		local fn = block(server, "function Heist.dodge(player, record, now)", "\nend\n")
		has(fn, "Heist.DodgeService.press(player, now, blocked)")
		has(fn, "capturing or hidden", "blocked while hidden or capturing")
		has(fn, "Heist.Arrullo.active(player)", "the Arrullo counts as capturing")
		has(fn, "Heist.Knock.ragdolled(Heist.knocks, player.UserId, now)", "and while ragdolled")
		has(fn, "context(player) ~= true", "and while dead")
		has(fn, "Text.DODGE.perfect"); has(fn, "Text.DODGE.early"); has(fn, "Text.DODGE.late")
		hasNot(server, "function Heist.burst(", "the Burst is retired")
		hasNot(server, "Stamina.burst(", "nothing starts a Burst")
		local stance = block(server, "stanceRemote.OnServerEvent:Connect(function(player, intent, ...)", "\nend)")
		has(stance, 'if intent == "dodge" then'); hasNot(stance, '"burst"')
		has(block(server, "local function applyCarry(player)", "\nend\n"), "Heist.DodgeService.speed(player, speed,")
		has(block(server, "RunService.Heartbeat:Connect(function(dt)", "\nend)"), "Heist.DodgeService.prune(now)")
		has(server, "Heist.DodgeService.forget(player)")
	end)

	case("W2: the parents' close swing and La Silueta's strike register their telegraphs and skip a dodged hit", function()
		local islands = block(server, "local function stepIslands(now, dt)", "\nend\n")
		has(islands, 'Heist.DodgeService.telegraph(target, chase.dodgeId, "Parent", now, now + Island.live.STRIKE_WINDUP)')
		has(islands, 'Heist.DodgeService.resolve(target, chase.dodgeId, now) == "Dodged"')
		has(islands, "Heist.DodgeService.cancel(target, chase.dodgeId)", "a miss or a give-up drops the telegraph")
		assert(islands:find('== "Dodged"', 1, true) < islands:find('if event == "Hit" and live then adultHit(island, target) end', 1, true),
			"the dodge is asked before the hit lands")
		local world = sources.worldServer or ""
		has(world, 'local DodgeService = require(script.Parent:WaitForChild("WildboundDodgeService"))')
		has(block(world, "local function issueAttack(h, now)", "\nend\n"),
			'DodgeService.telegraph(target, attack.attackId, "Silueta", now, h.telegraphEndsAt)')
		local impact = block(world, "local function resolveImpact(h, now)", "\nend\n")
		has(impact, 'DodgeService.resolve(target, attack.attackId, now) == "Dodged"')
		has(impact, "local geometry = not dodged and", "a dodged strike resolves as a miss through the fair-strike gates")
		assert(impact:find("local dodged", 1, true) < impact:find("FairStrike.resolve(", 1, true), "asked before the gates")
		has(block(world, "local function cancelOpenAttack(h, reason)", "\nend\n"), "DodgeService.cancel(target, closed.attackId)",
			"an attack closed before its strike is no longer dodgeable")
	end)

	case("W2: the Esquivar button replaces Impulso on Z and R3; the clients hear a perfect dodge", function()
		local client = sources.worldClient or ""
		local dodge = block(client, "-- Esquiva perfecta (decision Q3b;", "\nend\n")
		has(dodge, '"DodgeButton"'); has(dodge, 'stanceRemote:FireServer("dodge")', "only the word")
		has(dodge, "Enum.KeyCode.Z, Enum.KeyCode.ButtonR3"); has(dodge, '"WildboundDodge"')
		has(dodge, "WildboundDodgeReady"); has(dodge, "WildboundDodgeStrike"); has(dodge, "dodgeWords.cue")
		hasNot(client, "BurstButton", "the Impulso button is gone")
		has(sources.audio or "", 'other:GetAttribute("WildboundDodgeBoost")')
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.DODGE) == "table", "Text.DODGE")
		equal(Text.DODGE.button, "Esquivar"); equal(Text.DODGE.perfect, "¡Esquiva perfecta!")
		equal(Text.DODGE.cue, "¡Esquiva!"); equal(Text.DODGE.early, "Muy pronto"); equal(Text.DODGE.late, "Muy tarde")
		for key, value in pairs(Text.DODGE) do assert(#value <= 64, "DODGE." .. key .. " fits 64 bytes") end
		local Schema = sources.schema
		for _, key in ipairs({ "WINDOW", "MIN_TELEGRAPH", "BOOST_SECONDS", "BOOST_MULTIPLIER", "BOOST_CAP",
			"SUCCESS_COOLDOWN", "MISS_COOLDOWN", "SPAM_LIMIT", "SPAM_SECONDS", "SPAM_LOCKOUT", "LATE_MEMORY" }) do
			assert(Schema and Schema.find("Dodge", key), "tuning row Dodge." .. key)
		end
		equal(Schema.find("Dodge", "MIN_TELEGRAPH").min, 0.8, "never under the fair-strike floor")
		has(sources.tuning or "", 'Dodge = "WildboundDodge"')
	end)

	-- W3 (Q4, Q4b): the bat knockback.
	case("W3: the bat swings through the knock rule, ragdolls and pushes on the server (SistemaSonriente) and rechecks the travel", function()
		has(server, 'Heist.Knock = require(script.Parent:WaitForChild("WildboundBatKnock"))')
		has(server, "Heist.knocks = Heist.Knock.new()")
		has(server, 'Heist.knockRemote.Name, Heist.knockRemote.Parent = "BatKnock", network')
		has(server, "Heist.knockRemote.OnServerEvent:Connect(function() end)", "a client message is dropped")
		local zones = block(server, "function Heist.knockZones()", "\nend\n")
		has(zones, "Rules.HUB_X, z = Rules.HUB_Z, radius = Rules.HUB_RADIUS", "the hub disc and its bases")
		has(zones, "Rules.CAMP_RADIUS", "the camp")
		local fn = block(server, "function Heist.swingBat(player, record, now)", "\nend\n")
		has(fn, "Knock.swing(Heist.knocks, player.UserId, now,"); has(fn, "zones = Heist.knockZones()")
		has(fn, "Bat.pickTarget(from, candidates,", "the hitbox stays WildboundBat's")
		has(fn, "Knock.knock(Heist.knocks, from, target.key,")
		has(fn, 'Heist.dropEgg(victim, "Bat")', "a carried egg drops for anyone")
		has(fn, "Heist.knockRemote:FireClient(victim, { x = push.x, y = push.y, z = push.z, ragdoll = effect.ragdoll })")
		has(fn, "Heist.Ragdoll.aplicar(victim, effect.ragdoll, Vector3.new(push.x, push.y, push.z))", "the server ragdoll (R6/R15)")
		has(fn, "Knock.MAX_FLIGHT + 10", "the server rechecks the travel")
		has(fn, ":PivotTo(", "and puts a body that went too far back")
		hasNot(fn, "Bat.swing(", "the old cooldown is retired"); hasNot(fn, "Bat.hit(", "the old stumble is retired")
		hasNot(fn, "TakeDamage", "the bat never hurts")
		has(block(server, "local function applyCarry(player)", "\nend\n"), "Heist.Knock.ragdolled(")
		has(block(server, "local function applyCarry(player)", "\nend\n"), "speed = Heist.Velocidad.ajustar(player, speed)",
			"SistemaSonriente speed modifiers (ragdoll, caps, slows) are applied by the one WalkSpeed writer")
		has(server, "Heist.Velocidad.alCambiar(applyCarry)", "a modifier change recomputes the speed at once")
		has(server, "Heist.Knock.forget(Heist.knocks, player.UserId)")
		local client = sources.worldClient or ""
		local bat = block(client, "-- Nest Heist phase 2 (NP5): the bat.", "\nend\n")
		-- SistemaSonriente (etapa 1): the client no longer ragdolls or pushes itself; the server owns both.
		hasNot(bat, "Enum.HumanoidStateType.Physics", "no client-side ragdoll")
		hasNot(bat, "root.AssemblyLinearVelocity =", "no client-side push")
		local Schema = sources.schema
		for _, key in ipairs({ "COOLDOWN", "RAGDOLL_SECONDS", "IMMUNITY", "IMPULSE", "LIFT" }) do
			assert(Schema and Schema.find("BatKnock", key), "tuning row BatKnock." .. key)
		end
		equal(Schema.find("BatKnock", "COOLDOWN").default, 5)
		has(sources.tuning or "", 'Knock = "WildboundBatKnock"')
	end)

	-- W5 (Q11): the dusk warnings (the beast buff is the beast script's).
	case("W5: the server warns every player at dusk and before night from one Dusk state on the islands' cycle", function()
		has(server, 'Heist.Dusk = require(ReplicatedStorage:WaitForChild("WildboundDusk"))')
		local fn = block(server, "function Heist.stepDusk(now)", "\nend\n")
		has(fn, "Heist.Dusk.step(Heist.dusk.state, islandCycle())", "the same cycle (and Studio clock shift) as the islands")
		has(fn, "Text.DUSK.dusk"); has(fn, "Text.DUSK.soon:format(")
		has(fn, "stateRemote:FireClient(player, { action = \"Dusk\", ok = true, notice = line })", "a HUD notice")
		has(fn, "Heist.dusk.nextAt = now + 1", "once a second")
		has(block(server, "RunService.Heartbeat:Connect(function(dt)", "\nend)"), "Heist.stepDusk(now)")
		hasNot(fn, "buff", "the beast buff is not applied here")
		local Text = sources.text
		assert(type(Text) == "table" and type(Text.DUSK) == "table", "Text.DUSK")
		assert(Text.DUSK.dusk:find("anocheciendo", 1, true), "Spanish dusk line")
		assert(Text.DUSK.soon:find("%d", 1, true), "the seconds go into the second line")
		local Schema = sources.schema
		for _, key in ipairs({ "SPEED_MULTIPLIER", "ROLL_MULTIPLIER", "DETECTION_MULTIPLIER", "NIGHT_SOON" }) do
			assert(Schema and Schema.find("Dusk", key), "tuning row Dusk." .. key)
		end
		has(sources.tuning or "", 'Dusk = "WildboundDusk"', "the bridge tunes the shared Dusk module")
	end)

	return result
end
