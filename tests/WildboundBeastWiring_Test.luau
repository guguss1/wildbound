-- Invoke with require(freshTestClone)({ beasts = WildboundBeasts.Source, client = WildboundBeastsClient.Source,
-- server = WildboundServer.Source, proxies = WildboundBeastProxies.Source, text = require(freshTextClone),
-- config = require(freshBeastConfigClone), director = require(freshBeastDirectorClone),
-- audience = require(freshBeastAudienceClone) }, require(freshBeastProxiesClone)).
-- Nest Heist phase 4a (NB4 to NB6): the beast proxies (real Instances, built and destroyed here) and the source
-- contracts for how the beast script, the inventory server and the beast client wire the director and the encounters.
return function(sources, Proxies)
	local result = { passed = 0, failed = 0, messages = {} }
	local owned = {}
	local function case(name, run)
		local ok, message = pcall(run)
		for _, item in ipairs(owned) do item:Destroy() end
		table.clear(owned)
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
	sources = type(sources) == "table" and sources or {}
	local function keep(instance) table.insert(owned, instance); return instance end
	local function parts(model)
		local list = {}
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then table.insert(list, d) end end
		return list
	end
	local function named(model, prefix)
		local n = 0
		for _, p in ipairs(parts(model)) do if p.Name:sub(1, #prefix) == prefix then n += 1 end end
		return n
	end

	local function builders()
		assert(type(Proxies.viper) == "function" and type(Proxies.pouncer) == "function", "both proxy builders")
		return { Viper = Proxies.viper, Pouncer = Proxies.pouncer }
	end

	-- NB4 the proxies.
	case("NB4: both proxies are labelled placeholder models with a ground pivot", function()
		for beast, build in pairs(builders()) do
			local model = keep(build())
			equal(model.ClassName, "Model"); equal(model.Name, beast .. "Proxy")
			equal(model:GetAttribute("Proxy"), true, beast); equal(model:GetAttribute("Beast"), beast)
			assert(type(model:GetAttribute("ProxyNote")) == "string", "a swap note")
			assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", beast .. " pivot")
			assert(math.abs(model.PrimaryPart.Position.Y - 0.1) < 1e-3, "on the ground")
		end
	end)

	case("NB4: every proxy part is a visual only (anchored, no collision, query or touch)", function()
		for _, build in pairs(builders()) do
			local model = keep(build())
			local list = parts(model)
			assert(#list >= 20, model.Name .. " has " .. #list .. " parts")
			for _, p in ipairs(list) do
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p:GetFullName())
			end
		end
	end)

	case("NB4: Viper follows the reference: coil, wedge head forward, beige jaw, ivory fangs, amber Neon eyes", function()
		local model = keep(Proxies.viper())
		local C = Proxies.PALETTE
		assert(named(model, "Coil") >= 8, "a segmented coil")
		local head = model:FindFirstChild("Head")
		assert(head and head.Position.Z < -1, "the head faces the pivot's LookVector (-Z)")
		equal(model:FindFirstChild("Jaw").Color, C.viperJaw)
		equal(named(model, "Fang"), 2)
		equal(model.FangL.Color, C.viperFang)
		for _, name in ipairs({ "EyeL", "EyeR" }) do
			equal(model[name].Material, Enum.Material.Neon, name); equal(model[name].Color, C.viperEye, name)
		end
		equal(C.viperEye, Color3.fromHex("FF7A0A"))
		local _, size = model:GetBoundingBox()
		assert(math.max(size.X, size.Z) >= 8 and math.max(size.X, size.Z) <= 13, "about 10 studs long: " .. tostring(size))
	end)

	case("NB4: Pouncer follows the reference: broad plum body, 8 angular legs, ivory fangs, magenta Neon eyes", function()
		local model = keep(Proxies.pouncer())
		local C = Proxies.PALETTE
		equal(named(model, "Femur"), 8); equal(named(model, "Tibia"), 8); equal(named(model, "Claw"), 8)
		equal(model.Body.Color, C.pouncerPlum)
		equal(model.FangL.Color, C.pouncerIvory)
		local eyes = 0
		for _, p in ipairs(parts(model)) do
			if p.Name:sub(1, 3) == "Eye" then
				eyes += 1
				equal(p.Material, Enum.Material.Neon, p.Name); equal(p.Color, C.pouncerEye, p.Name)
			end
		end
		assert(eyes >= 4, "a cluster of eyes")
		assert(model.Head.Position.Z < -1, "the head faces -Z")
		local _, size = model:GetBoundingBox()
		assert(size.X >= 8 and size.X <= 12 and size.Y <= 7, "wide and low: " .. tostring(size))
	end)

	case("NB4: telegraphs are never part of a model; no asset ids, no contact events", function()
		for _, build in pairs(builders()) do
			local model = keep(build())
			for _, p in ipairs(parts(model)) do
				for _, bad in ipairs({ "Lane", "Circle", "Telegraph", "Ring" }) do
					assert(not p.Name:find(bad, 1, true), p.Name)
				end
			end
		end
		hasNot(sources.proxies, "rbxassetid", "proxies"); hasNot(sources.proxies, "Touched", "proxies")
	end)

	case("NB4: ensure builds the folder once and never replaces the user's imported model", function()
		local fake = keep(Instance.new("Folder"))
		local models = Proxies.ensure(fake)
		equal(models.Parent.Name, "WildboundBeasts"); equal(models.Name, "Models")
		assert(models:FindFirstChild("ViperProxy") and models:FindFirstChild("PouncerProxy"), "both proxies")
		for _, beast in ipairs({ "Streamer", "Root", "Gaze", "Lurker" }) do
			assert(models:FindFirstChild(beast .. "Proxy"), "wave 2 proxy " .. beast)
		end
		Proxies.ensure(fake)
		assert(models:FindFirstChild("ScuttlerProxy"), "SC8 Scuttler proxy")
		equal(#models:GetChildren(), 9, "no duplicate on a second call (7 forest proxies with Scuttler, the Nube and the Abeja)")
		equal(Proxies.modelFor(models, "Viper"), models.ViperProxy, "the proxy while there is no import")
		local imported = Instance.new("Model")
		imported.Name = "Viper"
		imported.Parent = models
		equal(Proxies.modelFor(models, "Viper"), imported, "an import named Viper wins")
		Proxies.ensure(fake)
		equal(models:FindFirstChild("Viper"), imported, "kept")
		equal(Proxies.modelFor(models, "Mire"), nil)
	end)

	-- EV-W3 the uploaded models. ServerStorage.WildboundAssets.Beasts holds the four uploaded rigged models as templates
	-- (Root on the ground, head along its LookVector); the server adopts Viper and Pouncer into the replicated folder.
	local function template(beast, withRoot)
		local model = keep(Instance.new("Model"))
		model.Name = beast
		local body = Instance.new("Part")
		body.Name = beast .. "_Body"
		body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch = false, true, true, true
		body.Parent = model
		if withRoot then
			local root = Instance.new("Part")
			root.Name = "Root"
			root.Parent = model
			model.PrimaryPart = root
		end
		local link = Instance.new("Configuration")
		link.Name = "PackageLinkStandIn"
		link.Parent = model
		return model
	end
	case("EV-W3: adopt clones a template with a ground Root into an inert visual named after the beast", function()
		assert(type(Proxies.adopt) == "function", "Proxies.adopt")
		local source = template("Viper", true)
		local model = keep(Proxies.adopt(source, "Viper"))
		assert(model and model ~= source, "a clone")
		equal(model.Name, "Viper")
		equal(model.PrimaryPart and model.PrimaryPart.Name, "Root", "pivot on the ground")
		equal(model:GetAttribute("Beast"), "Viper")
		equal(model:GetAttribute("Proxy"), false, "not a placeholder")
		for _, p in ipairs(parts(model)) do
			assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p.Name .. " is inert")
		end
		equal(source:FindFirstChild(source.Name .. "_Body").CanCollide, true, "the template itself is untouched")
		equal(Proxies.adopt(template("Viper", false), "Viper"), nil, "no Root: no adoption, the proxy stays")
		equal(Proxies.adopt(nil, "Viper"), nil)
	end)
	case("EV-W3: ensure adopts the Viper and Pouncer templates, keeps the proxies as fallback, never Gargoyle or Mire", function()
		local fake = keep(Instance.new("Folder"))
		local templates = keep(Instance.new("Folder"))
		for _, beast in ipairs({ "Viper", "Pouncer", "Gargoyle", "Mire" }) do template(beast, true).Parent = templates end
		local models = Proxies.ensure(fake, templates)
		assert(models:FindFirstChild("ViperProxy") and models:FindFirstChild("PouncerProxy"), "the proxies stay as fallback")
		equal(Proxies.modelFor(models, "Viper"), models:FindFirstChild("Viper"), "the real Viper wins")
		equal(Proxies.modelFor(models, "Pouncer"), models:FindFirstChild("Pouncer"), "the real Pouncer wins")
		equal(models:FindFirstChild("Gargoyle"), nil, "Gargoyle: template only")
		equal(models:FindFirstChild("Mire"), nil, "Mire: template only")
		Proxies.ensure(fake, templates)
		equal(#models:GetChildren(), 11, "no duplicate on a second call (9 proxies with SC8 Scuttler, 2 adopted)")
		local empty = keep(Instance.new("Folder"))
		local only = Proxies.ensure(empty, nil)
		equal(Proxies.modelFor(only, "Viper"), only.ViperProxy, "no templates: the proxy")
	end)
	case("EV-W3: the beast script passes the uploaded templates; hit checks stay server-side and model-free", function()
		has(sources.beasts, 'Proxies.ensure(ReplicatedStorage, ', "templates passed")
		has(sources.beasts, 'FindFirstChild("Beasts")', "ServerStorage.WildboundAssets.Beasts")
		hasNot(sources.proxies, "rbxassetid", "proxies"); hasNot(sources.proxies, "InsertService", "proxies")
		hasNot(sources.proxies, "Touched", "proxies")
	end)

	-- NB5 the server wiring.
	case("NB5: one scheduler: only the beast script rolls, through the director's 20 s calendar", function()
		local beasts = sources.beasts
		has(beasts, 'require(script.Parent:WaitForChild("WildboundBeastDirector"))')
		has(beasts, 'require(script.Parent:WaitForChild("WildboundBeastEncounters"))')
		has(beasts, "local due = Director.due(director, player.UserId, at)")
		has(beasts, "Director.roll(director, player.UserId, contextFor(player, at), at, due)")
		has(beasts, "pollClock >= D.POLL_SECONDS")
		hasNot(beasts, "TICK_SECONDS", "the script never times a roll itself")
		has(beasts, "Director.new({ random = function() return rng:NextNumber() end })")
		for key, text in pairs({ server = sources.server }) do hasNot(text, "WildboundBeastDirector", key) end
		hasNot(beasts, "math.random", "beasts")
	end)

	case("NB5: target-only and server-authoritative: FireClient to the owner, no client handler, no contact events", function()
		local beasts = sources.beasts
		has(beasts, "beastEvent:FireClient(player, payload)")
		for _, bad in ipairs({ "FireAllClients", "OnServerInvoke", "Touched", "SetNetworkOwner" }) do
			hasNot(beasts, bad, "beasts")
		end
		-- Wave 2: the one client-to-server path is the observation, stored through the validator and nothing else.
		local _, handlers = beasts:gsub("OnServerEvent", "")
		equal(handlers, 1, "only BeastObserve has a server handler")
		has(beasts, "observeEvent.OnServerEvent:Connect(function(player, payload)")
		has(beasts, "if not Sight.accept(state, now(), payload) then count(\"observeDropped\") end")
		hasNot(beasts, "beastEvent.OnServerEvent", "BeastEvent stays server to client")
		has(beasts, 'beastEvent.Name = "BeastEvent"')
		has(beasts, 'if network:FindFirstChild("BeastEvent") then', "the duplicate-start guard")
		has(beasts, "character ~= entry.character", "a respawned body is a new life")
	end)

	case("NB5: the context reads real server state; storm stays x1 and no biome exists yet", function()
		local beasts = sources.beasts
		has(beasts, "local fog, safe = Rules.zone(p.X, p.Z)")
		has(beasts, "return Rules.cycle(at - origin + shift).phase")
		has(beasts, 'night = phase == "Night"')
		has(beasts, "dangerousZone = fog or Rules.inTerritory(p.X, p.Z)")
		has(beasts, "storm = false")
		has(beasts, "biomes = Biomes.at(p.X, p.Z)", "wave 2: the biome tags")
		has(beasts, 'if state == "Hunt" or state == "Telegraph" then return true end', "La Silueta hunting or telegraphing")
	end)

	case("NB5: every end releases the budget once: step End, error, no spawn, no behaviour, leave", function()
		local beasts = sources.beasts
		has(beasts, "if Director.release(director, id, reason, at) then")
		has(beasts, 'close(id, "Error", at)'); has(beasts, 'close(reservation.id, "NoSpawn", at)')
		has(beasts, 'close(reservation.id, "NoBehaviour", at)'); has(beasts, "close(id, event.reason, at, event)")
		has(beasts, "Director.forget(director, player.UserId, at)")
		has(beasts, "pcall(stepEncounter, id, entry, at)", "an error never leaks an encounter")
	end)

	-- Nest Heist Phase 3 (verifier finding): an error while an encounter starts ends it as Error and frees its budget.
	case("NS-B1: an encounter start runs under pcall; a failure closes it with reason Error and releases the budget", function()
		local beasts = sources.beasts
		has(beasts, "pcall(start, player, reservation, at)", "the start is protected")
		has(beasts, 'close(reservation.id, "Error", at)', "a failed start closes as Error (close releases the budget)")
		has(beasts, "for _, reservation in ipairs(started) do safeStart(player, reservation, at) end", "the tick starts safely")
		has(beasts, "return safeStart(player, value, at)", "the Studio force spawn starts safely")
		local bare = 0
		local calls = string.gsub(beasts, "local function start%(player, reservation, at%)", "")
		for _ in string.gmatch(calls, "[^%w]start%(player, ") do bare += 1 end
		equal(bare, 0, "no unprotected start call")
	end)

	case("NB5: a hit goes through the inventory server's existing drop and damage path", function()
		local beasts, server = sources.beasts, sources.server
		has(beasts, 'network:FindFirstChild("BeastHit")')
		has(beasts, "beastHit:Invoke(entry.player, entry.e.beast, event.damage)")
		has(server, 'beastHit.Name = "BeastHit"')
		has(server, 'local eggDropped = Heist.dropEgg(player, "Hit") ~= nil', "the one egg drop path")
		has(server, 'if damageMode == "private" and lethalPlayer(player) then', "damage only in private mode, after a paid trip")
		has(server, "humanoid:TakeDamage(damage)")
		local i = server:find('beastHit.Name = "BeastHit"', 1, true)
		local before = server:sub(1, i)
		assert(before:find("\ndo\n\tlocal beastHit = Instance.new%(\"BindableFunction\"%)\n[^\n]*$"), "kept in a do block (200-local limit)")
		hasNot(server, "\nlocal beastHit", "no new top-level local")
		hasNot(server, "WildboundBeastEncounters", "server")
	end)

	case("NB5: ForceSpawnBeast is Studio only, server only, and goes through the director's reservation", function()
		local beasts = sources.beasts
		local i = beasts:find("if RunService:IsStudio() then", 1, true)
		assert(i, "a Studio block")
		local block = beasts:sub(i)
		has(block, 'force.Name = "ForceSpawnBeast"'); has(block, "force.Parent = telemetry")
		has(block, "Director.reserve(director, player.UserId, name, contextFor(player, at), at, { force = true })")
		hasNot(beasts:sub(1, i), "ForceSpawnBeast", "outside the Studio block")
		hasNot(block, "RemoteEvent", "no client remote")
	end)

	case("NB5: player strings are Spanish and live in WildboundText", function()
		local T = sources.text.BEAST
		assert(type(T) == "table", "Text.BEAST")
		has(T.Viper.warn, "línea roja"); has(T.Pouncer.warn, "círculo rojo")
		assert(T.Viper.hit and T.Pouncer.hit and T.hit, "hit notices")
	end)

	-- NB6 the client.
	case("NB6: the client only listens: no request, no hit or dodge report, its own local folder", function()
		local client = sources.client
		has(client, "beastEvent.OnClientEvent:Connect(")
		for _, bad in ipairs({ "InvokeServer", "Touched", "beastEvent:FireServer" }) do hasNot(client, bad, "client") end
		-- Wave 2: the one message the client sends is the camera look vector, throttled.
		local _, fires = client:gsub("FireServer%(", "")
		equal(fires, 1, "one FireServer")
		has(client, "observeEvent:FireServer({ x = v.X, y = v.Y, z = v.Z })")
		has(client, "os.clock() - lastObserve >= Sight.SEND_INTERVAL")
		has(client, 'folder.Name = "WildboundBeastsLocal"')
		has(client, "folder.Parent = workspace", "client-made, so it exists on this client only")
	end)

	case("NB6: the tells come from the shared geometry and the server's timestamps, never hard-coded", function()
		local client = sources.client
		has(client, "Config.lane(L.ox, L.oz, L.dx, L.dz, L.length, L.width)", "the lane is the hit rectangle")
		has(client, "c.radius * 2", "the circle uses the server's radius")
		has(client, "Config.arc(l.from.x, l.from.y, l.from.z, l.to.x, l.to.y, l.to.z, l.height, t)", "the leap is the server's parabola")
		has(client, "workspace:GetServerTimeNow()")
		for _, literal in ipairs({ "32,", "4.5", "6.5", "1.15", "1.3," }) do hasNot(client, literal, "client") end
		has(client, "view.laneSpec.locked = ev.dx, ev.dz, ev.length, true", "the lock carries the cut length")
		has(client, "task.delay(0.35, function() clearCircle(view) end)", "the circle outlives the landing")
	end)

	case("NB6: the tells are effects, not models, and never collide, query or touch", function()
		local client = sources.client
		has(client, "part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false")
		has(client, 'lane.Name = "ViperLane"'); has(client, 'circle.Name = "PouncerCircle"')
		has(client, "lane.Parent = folder"); has(client, "circle.Parent = folder")
	end)

	case("NB6: a sound and a Spanish line with every tell; Efectos suaves drops only shake and dust", function()
		local client = sources.client
		has(client, "Text.BEAST[beast]"); has(client, 'showWarning("Viper", ev.dashAt)'); has(client, 'showWarning("Pouncer", ev.landAt)')
		has(client, 'play("whisper", rootOf(view), 1.7, 0.9)', "Viper's hiss"); has(client, 'play("snap", rootOf(view), 1.2, 0.9)', "Pouncer's click")
		has(client, "Catalog.SOUNDS[slot]", "catalogue ids only")
		assert(not client:find("rbxassetid://%d"), "no hard-coded asset id")
		local shakeAt = client:find("local function shake(", 1, true)
		local dustAt = client:find("local function dust(", 1, true)
		assert(shakeAt and dustAt, "shake and dust exist")
		has(client:sub(shakeAt, shakeAt + 80), "if reduced() then return end", "shake")
		has(client:sub(dustAt, dustAt + 80), "if reduced() then return end", "dust")
		local _, guards = client:gsub("if reduced%(%) then return end", "")
		equal(guards, 2, "only shake and dust are reduced")
	end)

	case("NB6: an imported model wins over the proxy, and every view is destroyed on End", function()
		local client = sources.client
		has(client, "local real = models:FindFirstChild(beast)")
		has(client, 'models:FindFirstChild(beast .. "Proxy")')
		has(client, "function handlers.End(ev)")
		has(client, "if view.model then view.model:Destroy() end")
	end)

	-- Beast spawn P0 (docs/design/wildbound-beast-spawn.md section 5).
	case("BS-P0: the context carries the egg from the server's backpack and the dusk roll buff from WildboundDusk", function()
		local beasts = sources.beasts
		has(beasts, 'carryingEgg = character:FindFirstChild("WildboundEggCarried") ~= nil', "the egg step's condition")
		has(sources.server, 'local EGG_ARMS = "WildboundEggCarried"', "the inventory server still names the backpack so")
		has(beasts, 'ReplicatedStorage:WaitForChild("WildboundDusk", 10)', "a missing module never stalls the beasts")
		has(beasts, "duskRoll = Dusk and Dusk.buff(phase).roll or 1")
		-- The script's comment names EggCarry; what must never appear is a require or a call into it.
		hasNot(beasts, "WildboundEggCarry", "read-only: the beast script never requires the egg registry")
		hasNot(beasts, "EggCarry.", "read-only: the beast script never calls the egg registry")
		hasNot(beasts, "Dusk.step(", "the dusk warnings stay with the server's cycle loop")
		equal(sources.config.DIRECTOR.TICK_SECONDS, 20, "wave 2 owner decision: 20 s")
	end)

	-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md).
	case("BW2: the four proxies are labelled, inert placeholders with a ground pivot and their danger colour", function()
		local W = Proxies.WAVE2_PALETTE
		local eyes = { Streamer = W.magenta, Root = W.green, Gaze = W.magenta, Lurker = W.fuchsia }
		for beast, color in pairs(eyes) do
			local build = Proxies.BUILDERS[beast]
			assert(type(build) == "function", beast .. " builder")
			local model = keep(build())
			equal(model.Name, beast .. "Proxy"); equal(model:GetAttribute("Beast"), beast); equal(model:GetAttribute("Proxy"), true)
			assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", beast .. " pivot")
			assert(math.abs(model.PrimaryPart.Position.Y - 0.1) < 1e-3, beast .. " on the ground")
			local list = parts(model)
			assert(#list >= 15, beast .. " has " .. #list .. " parts")
			local neon = 0
			for _, p in ipairs(list) do
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p:GetFullName())
				for _, bad in ipairs({ "Lane", "Circle", "Telegraph", "Ring", "Wall" }) do assert(not p.Name:find(bad, 1, true), p.Name) end
				if p.Material == Enum.Material.Neon and p.Color == color then neon += 1 end
			end
			assert(neon >= 2, beast .. " shows its danger colour")
			local head = model:FindFirstChild("Head")
			assert(head and head.Position.Z < 0, beast .. " faces -Z")
		end
	end)

	case("BW2: the server registers the four behaviours, rolls them through the director and ends them cleanly", function()
		local beasts = sources.beasts
		has(beasts, 'Enc.register(name, require(script.Parent:WaitForChild("WildboundBeast" .. name)))')
		has(beasts, 'for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker", "Scuttler" }) do', "SC7 appended Scuttler")
		has(beasts, "if not (Config.PLAYABLE[beast] or Config.SUMMONED[beast]) or not Enc.registered(beast) then")
		has(beasts, "world = worldFor(player)")
		has(beasts, "Attack.closeAll(entry.e, entry.world)", "close cancels every open attack")
		has(beasts, "Attack.closeAll(entry.e, nil)", "a leave too")
		has(beasts, "sights[player] = nil"); has(beasts, "claims[player] = nil")
		has(beasts, "local target = targetOf(entry)")
		has(beasts, "Enc.step(entry.e, at, target, entry.world or world)")
	end)

	case("BW2: dodgeable attacks go through WildboundDodgeService; the client never claims one", function()
		local beasts = sources.beasts
		has(beasts, 'require(script.Parent:WaitForChild("WildboundDodgeService"))')
		has(beasts, "DodgeService.telegraph(player, id, beast, startAt, strikeAt)")
		has(beasts, "DodgeService.resolve(player, id, at)")
		has(beasts, "DodgeService.cancel(player, id)")
		hasNot(beasts, "DodgeService.press", "only the inventory server takes the press")
	end)

	case("BW2: biome tags, Root's spawn in the Pantano, Lurker behind, Gaze in sight", function()
		local beasts = sources.beasts
		has(beasts, 'require(script.Parent:WaitForChild("WildboundBiomes"))')
		has(beasts, "(not spec.biome or Biomes.has(x, z, spec.biome))")
		has(beasts, "return { min = d, max = d, visible = false, behind = true }")
		has(beasts, 'visible = beast == "Gaze"')
		has(beasts, "target.biomes = Biomes.at(p.X, p.Z)")
	end)

	case("BW2: the observation is server-checked: head origin, server raycast, validated look; never damage", function()
		local beasts = sources.beasts
		has(beasts, "local head = p + Vector3.new(0, 1.5, 0)")
		has(beasts, "los = sightClear(head, Vector3.new(point.x, point.y, point.z))")
		has(beasts, "Sight.observes(sights[entry.player], now(),")
		local i = beasts:find("local function landHit", 1, true)
		local j = beasts:find("local function stepEncounter", 1, true)
		assert(i and j, "landHit")
		hasNot(beasts:sub(i, j), "sights", "a hit never reads the observation")
	end)

	case("BW2: Root's slow never stacks and is put back only when unchanged; Streamer's push is clamped", function()
		local beasts, client = sources.beasts, sources.client
		has(beasts, "if type(untilAt) == \"number\" and untilAt > now() then return end")
		has(beasts, "math.abs(humanoid.WalkSpeed - slowed) < 1e-3")
		has(client, "local speed = math.clamp(knock.speed, 0, cap)")
		hasNot(client, "HumanoidStateType.Physics", "the push is never a ragdoll")
	end)

	case("BW2: the client names its visual after the beast, draws the server's shapes and keeps walls local", function()
		local client = sources.client
		has(client, "view.model.Name = ev.beast")
		has(client, "drawShape(item.model, ev.shape, TELL_COLOR[view.beast] or RED, false)")
		has(client, "Config.lane(shape.ox, shape.oz, shape.dx, shape.dz, shape.length, shape.width)")
		has(client, "part.CanCollide = not overlapping", "a wall never closes on the player")
		has(client, "blur.Size = wantBlur and math.min(GAZE.MaxScreenBlurSize")
		has(client, "edge.BackgroundTransparency = 1 - 0.55 * exposure", "a vignette, never a blackout")
		local T = sources.text.BEAST
		for _, beast in ipairs({ "Streamer", "Root", "Gaze", "Lurker" }) do
			assert(T[beast] and T[beast].warn and T[beast].hit and T[beast].phases, beast .. " strings")
		end
		assert(T.Gaze.meter and T.Gaze.broken, "Gaze meter and break lines")
	end)

	case("HF-T5: far from base is measured from the camp and the hub through the world rules", function()
		local beasts = sources.beasts
		has(beasts, "farFromBase = Rules.farFromBase(p.X, p.Z, D.FAR_FROM_BASE)", "the shared rule")
		hasNot(beasts, "CAMP_X", "no camp-only centre")
	end)

	-- Kids biome (odd/tasks/wildbound-kids-beasts.md, KB-4).
	case("KB-4: the Nube and the Abeja proxies are inert, labelled, soft-coloured and hover over a ground pivot", function()
		local P = Proxies.PALETTE
		for beast, spec in pairs({ NubeGrunona = { colour = P.nubePuff, hover = 10, prefix = "Puff" },
			AbejaReina = { colour = P.abejaYellow, hover = 6, prefix = "Band" } }) do
			local build = Proxies.BUILDERS[beast]
			assert(type(build) == "function", beast .. " builder")
			local model = keep(build())
			equal(model.Name, beast .. "Proxy"); equal(model:GetAttribute("Beast"), beast); equal(model:GetAttribute("Proxy"), true)
			assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", beast .. " pivot")
			assert(math.abs(model.PrimaryPart.Position.Y - 0.1) < 1e-3, beast .. " pivot on the ground")
			local list = parts(model)
			assert(#list >= 12, beast .. " has " .. #list .. " parts")
			for _, p in ipairs(list) do
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p:GetFullName())
				for _, bad in ipairs({ "Lane", "Circle", "Telegraph", "Ring", "Wall" }) do assert(not p.Name:find(bad, 1, true), p.Name) end
				assert(p.Color ~= Color3.fromRGB(255, 40, 30), "never the red danger colour")
			end
			assert(named(model, spec.prefix) >= 5, beast .. " body pieces")
			local body = model:FindFirstChild(spec.prefix .. "1")
			equal(body.Color, spec.colour, beast .. " colour")
			assert(math.abs(body.Position.Y - spec.hover) < 2, beast .. " hovers")
			local head = model:FindFirstChild("Head")
			assert(head and head.Position.Z < 0, beast .. " faces -Z")
		end
		equal(P.nubePuff, Color3.fromHex("B4A8D2")); equal(P.nubeBelly, Color3.fromHex("8C7FB0"))
		equal(P.abejaYellow, Color3.fromHex("FFD54A")); equal(P.abejaBrown, Color3.fromHex("B8793A"))
		equal(P.abejaCrown, Color3.fromHex("F7E3A1")); equal(P.abejaTip, Color3.fromHex("FFE27A"))
		local nube = keep(Proxies.nube())
		equal(nube.Shadow.Transparency > 0.5, true, "a translucent shadow disc")
		local abeja = keep(Proxies.abeja())
		equal(abeja.AntennaTipL.Material, Enum.Material.Neon); equal(abeja.WingL.Transparency > 0.3, true, "translucent wings")
	end)

	case("KB-4: the server registers both summoned behaviours and summons them by presence, never by a roll", function()
		local beasts = sources.beasts
		has(beasts, '{ name = "NubeGrunona", module = "WildboundBeastNube" }, { name = "AbejaReina", module = "WildboundBeastAbeja" }')
		has(beasts, '{ name = "Gomibu", module = "WildboundBeastGomibu" }') -- Caramelo biome
		has(beasts, '{ name = "Flanfuria", module = "WildboundBeastFlanfuria" }') -- Caramelo biome
		has(beasts, '{ name = "Tortidragon", module = "WildboundBeastTortidragon" }') -- Caramelo biome, CA2
		has(beasts, "for _, kid in ipairs(KIDS) do Enc.register(kid.name, require(script.Parent:WaitForChild(kid.module))) end")
		has(beasts, 'require(script.Parent:WaitForChild("WildboundPraderaSites"))')
		has(beasts, "Director.summon(director, player.UserId, kid.name, ctx, at)")
		has(beasts, "if Sites.wants(kid.name, want) then")
		has(beasts, "if ok then safeStart(player, value, at) end", "a summon starts safely")
		has(beasts, "summonPass(player, at)")
		has(beasts, "local site = world.site(Sites.HOME[beast])", "spawned at their site")
	end)

	case("KB-4: damage 0 for the summoned beasts and in the Pradera; forest beasts are closed on entering it", function()
		local beasts = sources.beasts
		has(beasts, "if Config.SUMMONED[entry.e.beast] or (body and inMeadow(body.Position.X, body.Position.Z)) then event.damage = 0 end")
		local i = beasts:find("event.damage = 0", 1, true)
		local j = beasts:find("beastHit:Invoke(entry.player, entry.e.beast, event.damage)", 1, true)
		assert(i and j and i < j, "zeroed before BeastHit")
		has(beasts, 'if target and target.meadow and not Config.SUMMONED[entry.e.beast] then')
		has(beasts, 'close(id, "Pradera", at)')
		for _, name in ipairs({ "NubeGrunona", "AbejaReina" }) do equal(sources.config.BEASTS[name].damage, 0, name) end
		has(beasts, "local STICKY_FLOOR, STICKY_CAP = 9, 6")
		has(beasts, "speed, seconds = math.max(speed, STICKY_FLOOR), math.clamp(seconds, 0, STICKY_CAP)")
		has(beasts, "if before <= speed then return end", "Pegajoso never raises the speed")
		has(beasts, 'humanoid:SetAttribute("WildboundKidsMarkUntil", now() + math.clamp(event.mark, 0, 30))')
	end)

	case("KB-4: the Nube's sky ray and the Abeja's BiomeEvent window are read on the server", function()
		local beasts = sources.beasts
		has(beasts, 'CollectionService:GetTagged("WildboundRoof")')
		has(beasts, "roofParams.FilterType = Enum.RaycastFilterType.Include")
		has(beasts, 'telemetry:GetAttributeChangedSignal("BiomeEvent")')
		has(beasts, 'local biomeEvent = telemetry:GetAttribute("BiomeEvent")')
		hasNot(beasts, 'SetAttribute("BiomeEvent"', "read only: the server's event clock owns it")
		has(beasts, "target.noise = Sites.noiseRadius(")
		has(beasts, "humanoid.FloorMaterial == Enum.Material.Air")
		has(beasts, 'workspace:FindFirstChild("WildboundPradera")')
		local i = beasts:find("if RunService:IsStudio() then", 1, true)
		has(beasts:sub(i), 'abeja.Name = "ForceAbejaEvent"', "the override is Studio only")
		hasNot(beasts:sub(1, i), 'Instance.new("BindableFunction")', "no bindable outside the Studio block")
	end)

	case("KB-4: the client draws the kids tells in yellow and honey with their own sounds, never the scary ones", function()
		local client = sources.client
		has(client, 'NubeGrunona = Color3.fromHex("FFD23F"), AbejaReina = Color3.fromHex("F2A33A")')
		has(client, 'NubeGrunona = { Notice = { "groan", 1.1 }, Telegraph = { "crack", 1.3 } }')
		has(client, 'AbejaReina = { Telegraph = { "unease", 1.2 } }')
		has(client, 'local KIDS_HIT_SOUND = { NubeGrunona = "softStinger", AbejaReina = "softStinger" }')
		has(client, 'local KIDS_HUM = { AbejaReina = "insectsDusk" }')
		local i = client:find("local KIDS_PHASE_SOUND", 1, true)
		local j = client:find("local KIDS_HUM", 1, true)
		local block = client:sub(i, j + 60)
		for _, bad in ipairs({ "chaseMusic", "heartbeat", "roar", '"stinger"' }) do hasNot(block, bad, "kids sounds") end
		local T = sources.text.BEAST
		for _, beast in ipairs({ "NubeGrunona", "AbejaReina" }) do
			assert(T[beast] and T[beast].warn and T[beast].hit and T[beast].phases, beast .. " strings")
		end
	end)

	-- Esquiva perfecta (Q3b, odd/tasks/wildbound-new-mechanics.md W2): the beasts' tells feed the shared dodge states.
	case("Q3b: Viper's windup and Pouncer's telegraph register a dodgeable attack; a Hit asks resolve() first", function()
		local beasts = sources.beasts
		has(beasts, 'require(script.Parent:WaitForChild("WildboundDodgeService"))')
		has(beasts, 'DodgeService.telegraph(entry.player, key .. (attack + 1), "Viper", event.at, event.dashAt)')
		has(beasts, 'DodgeService.telegraph(entry.player, key .. (attack + 1), "Pouncer", event.at, event.landAt)')
		has(beasts, 'DodgeService.resolve(entry.player, key .. tostring(event.attack), event.at) == "Dodged"')
		has(beasts, "elseif dodgeStep(entry, event) then", "a dodged hit is neither landed nor sent")
		local stepBody = beasts:match("local function stepEncounter%(id, entry, at%)(.-)\nend\n") or ""
		local dodgeAt, landAt = stepBody:find("dodgeStep(entry, event)", 1, true), stepBody:find("landHit(entry, event)", 1, true)
		assert(dodgeAt and landAt and dodgeAt < landAt, "resolve before the hit lands")
	end)

	-- SC0 (odd/tasks/wildbound-scuttler.md): shared beast visibility. Visual events reach bystanders in range through
	-- WildboundBeastAudience; effects (hit, slow, sticky, mark, knock, egg drop) stay on the target.
	local function body(text, header)
		local i = text:find(header, 1, true)
		assert(i, "missing " .. header)
		local j = text:find("\nend\n", i, true)
		return text:sub(i, j or #text)
	end

	case("SC0: the beast script fans visual events out through WildboundBeastAudience and keeps effects on the target", function()
		local beasts = sources.beasts
		has(beasts, 'local Audience = require(script.Parent:WaitForChild("WildboundBeastAudience"))')
		has(beasts, "local audience = Audience.new()")
		has(beasts, "local copy = Audience.forBystander(event)", "only the filtered copy goes to bystanders")
		local step = body(beasts, "local function stepEncounter(id, entry, at)")
		local targetAt = step:find("send(entry.player, event)", 1, true)
		local fanAt = step:find("sendBystanders(id, event)", 1, true)
		assert(targetAt and fanAt and targetAt < fanAt, "the target first, then the bystanders")
		for _, header in ipairs({ "local function landHit(entry, event)", "local function applySlow(player, multiplier, seconds)",
			"local function applySticky(player, speed, seconds)", "local function dodgeStep(entry, event)" }) do
			local text = body(beasts, header)
			hasNot(text, "Audience", header); hasNot(text, "sendBystanders", header)
		end
		hasNot(beasts, "FireAllClients", "never a broadcast to everyone")
		local _, handlers = beasts:gsub("OnServerEvent", "")
		equal(handlers, 1, "no new client-to-server traffic")
	end)

	case("SC0: bystanders join and leave as players move, get throttled snapshots, and are cleaned up on every end", function()
		local beasts = sources.beasts
		has(beasts, "Audience.refresh(audience, ", "membership re-evaluated on a clock")
		has(beasts, "audienceClock >= AUDIENCE.REFRESH_SECONDS")
		has(beasts, "send(viewer, Audience.spawnFor(", "a late joiner gets a spawn snapshot")
		has(beasts, "send(viewer, Audience.leaveFor(", "a leaver gets a cleanup")
		has(beasts, "Audience.snapDue(audience, e.id, ", "bystander movement is throttled")
		local closeBody = body(beasts, "local function close(id, reason, at, event)")
		has(closeBody, "sendBystanders(id, ending)", "bystanders see the end")
		has(closeBody, "Audience.close(audience, id)", "and are forgotten once")
		local removing = beasts:sub(beasts:find("Players.PlayerRemoving:Connect", 1, true) or 1)
		has(removing, "Audience.forgetViewer(audience, player.UserId)", "a leaving viewer is dropped")
		has(removing, "Audience.close(audience, id)", "a leaving target's beasts end for their bystanders")
		equal(sources.config.AUDIENCE.RADIUS, 150, "proposed radius, configurable in WildboundBeastConfig")
	end)

	case("SC0: the client draws a bystander's beast quietly: no HUD line, sound, shake, knock, wall or observation", function()
		local client = sources.client
		has(client, "view.bystander = ev.bystander == true")
		for _, header in ipairs({ "local function play(slot, parent, pitch, volume)", "local function showWarning(beast, untilAt)",
			"local function showLine(line, untilAt)", "local function shake(strength)" }) do
			has(body(client, header), "if muting then return end", header)
		end
		has(body(client, "function handlers.Hit(ev, view)"), "if view.bystander then return end", "no hit feedback or knock")
		has(body(client, "function handlers.Exposure(ev, view)"), "view.bystander", "no Gaze meter")
		has(client, "if Config.OBSERVERS[view.beast] and not view.bystander then observing = true end", "no BeastObserve")
		has(client, "if not view.bystander then raiseWalls(item.model) end", "Root's walls never hold a bystander back")
		has(client, "local function soften(view, model)", "neutral, lower-opacity tells")
		has(client, "muting = (view ~= nil and view.bystander) or ev.bystander == true")
		local _, fires = client:gsub("FireServer%(", "")
		equal(fires, 1, "still one FireServer")
	end)

	case("SC0 correction: Pradera and safe viewers, committed spawns with a replay, smooth and single-dimmed bystander views", function()
		local beasts, client = sources.beasts, sources.client
		local refresh = body(beasts, "local function refreshAudience(at)")
		has(refresh, "summoned = Config.SUMMONED[e.beast] == true", "the module knows which beasts the Pradera allows")
		has(refresh, "meadow = inMeadow(", "a meadow viewer is marked")
		has(refresh, "safe = safe", "a safe-zone viewer is marked")
		has(refresh, "Audience.replay(audience, item.id, at)", "a late joiner gets the live tells, lane and move")
		has(refresh, "return true", "membership is committed only after the spawn was sent")
		has(body(beasts, "local function sendBystanders(id, event)"), "Audience.remember(audience, id, copy)",
			"every visual copy is remembered for late joiners")
		has(client, "view.behind = view.bystander and BYSTANDER_BEHIND or BEHIND", "a bystander renders behind its 5 Hz snapshots")
		has(client, "local BYSTANDER_BEHIND = Config.AUDIENCE.SNAP_SECONDS + ", "the delay follows the snapshot interval")
		has(body(client, "local function placeOf(view, at)"), "local renderAt = at - (view.behind or BEHIND)")
		has(body(client, "local function soften(view, model)"), 'GetAttribute("Softened")', "soften never dims a part twice")
	end)

	-- SC7 (odd/tasks/wildbound-scuttler.md): the Scuttler behaviour wired into the beast script.
	case("SC7: the beast script registers Scuttler and spawns it on a plain ring, hidden point preferred, no biome or bias", function()
		local beasts = sources.beasts
		has(beasts, 'for _, name in ipairs({ "Streamer", "Root", "Gaze", "Lurker", "Scuttler" }) do', "registered")
		local spec = body(beasts, "local function spawnSpec(beast)")
		has(spec, 'if beast == "Scuttler" then', "its own spawnSpec entry")
		has(spec, "return { min = C.spawnMin, max = C.spawnMax, visible = false }", "a plain ring like Viper's")
		hasNot(beasts, "SPAWN_BIAS", "no route weighting (plan section 8)")
		local C = sources.config.BEASTS.Scuttler
		equal(C.spawnMin, 40); equal(C.spawnMax, 75)
		equal(sources.config.homeBiome("Scuttler"), nil, "no home biome")
		equal(sources.config.BIOME_PREFERENCE, false, "no biome preference")
	end)

	case("SC7: the adapter gives Scuttler the server's dash time and a server Random; its target carries egg and Silueta", function()
		local beasts = sources.beasts
		local adapter = body(beasts, "local function worldFor(player)")
		has(adapter, "function w.lastDash()", "the bait detector")
		has(adapter, 'player:GetAttribute("WildboundDash")', "the server-written press time (WildboundDodgeService)")
		has(adapter, "function w.random() return rng:NextNumber() end", "the feint roll uses the server's Random")
		hasNot(beasts, "math.random", "beasts")
		local target = body(beasts, "local function targetOf(entry)")
		has(target, 'if entry.e.beast == "Scuttler" then', "Scuttler's target extras")
		has(target, 'target.carryingEgg = character:FindFirstChild("WildboundEggCarried") ~= nil', "the egg, server-made child")
		has(target, "target.siluetaActive = siluetaActive(entry.player.UserId)", "the Silueta yield (rule 6)")
	end)

	case("SC7: Afflict only slows the target (applySlow), never reaches BeastHit and is never shown to a bystander", function()
		local beasts = sources.beasts
		local afflict = body(beasts, "local function afflict(entry, event)")
		has(afflict, "applySlow(entry.player, event.slow, event.slowSeconds)", "the slow, clamped by applySlow")
		has(afflict, 'count("afflicted")', "a counter")
		for _, bad in ipairs({ "beastHit", "landHit", "BeastHit", "applySticky", "WildboundKidsMarkUntil", "Audience",
			"sendBystanders", "damage" }) do
			hasNot(afflict, bad, "afflict")
		end
		local step = body(beasts, "local function stepEncounter(id, entry, at)")
		has(step, 'if event.type == "Afflict" then afflict(entry, event) end', "handled in the step")
		local Audience = sources.audience
		assert(type(Audience) == "table", "sources.audience")
		equal(Audience.VISUAL.Afflict, nil, "Afflict is not a visual event")
		equal(Audience.forBystander({ type = "Afflict", id = "beast:1", slow = 0.75, slowSeconds = 1.5, shake = true }), nil,
			"target-only: never copied to a bystander")
		has(beasts, "afflicted = 0", "the counter starts at 0")
	end)

	case("SC7: Scuttler's ends go through the shared close: budget released once; Patio hooks and SC0 fan-out kept", function()
		local beasts = sources.beasts
		has(beasts, "close(id, event.reason, at, event)", "Disengage Silueta/EggDropped/Outplayed end through close")
		has(beasts, "if Director.release(director, id, reason, at) then", "released once")
		has(beasts, 'if target and target.meadow and not Config.SUMMONED[entry.e.beast] then', "the Pradera ends it")
		has(beasts, 'player:GetAttribute("PatioDentro") ~= true', "the yard's roll guard")
		has(beasts, 'patio.Name = "PatioBestia"', "the yard's hook")
		has(beasts, "sendBystanders(id, event)", "SC0 fan-out")
		local i = beasts:find("if RunService:IsStudio() then", 1, true)
		has(beasts:sub(i), 'force.Name = "ForceSpawnBeast"', "the Studio force spawn")
		equal(sources.config.BEASTS.Scuttler.points, 3, "fills the budget")
	end)

	-- SC8 (odd/tasks/wildbound-scuttler.md): Scuttler's proxy and its client tells.
	case("SC8: Scuttler's proxy is a labelled, inert Part placeholder 12-14 studs tall, pivot on the ground, head -Z", function()
		local build = Proxies.BUILDERS.Scuttler
		assert(type(build) == "function" and build == Proxies.scuttler, "Proxies.scuttler is the Scuttler builder")
		local model = keep(build())
		equal(model.Name, "ScuttlerProxy"); equal(model:GetAttribute("Beast"), "Scuttler"); equal(model:GetAttribute("Proxy"), true)
		assert(type(model:GetAttribute("ProxyNote")) == "string", "a swap note")
		assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", "pivot")
		assert(math.abs(model.PrimaryPart.Position.Y - 0.1) < 1e-3, "the pivot sits on the ground")
		local box, size = model:GetBoundingBox()
		local top, bottom = box.Position.Y + size.Y / 2, box.Position.Y - size.Y / 2
		assert(top >= 12 and top <= 14, "12-14 studs tall (Q1): " .. top)
		assert(bottom > -0.05 and bottom < 0.5, "it stands on the ground: " .. bottom)
		local P = Proxies.SCUTTLER_PALETTE
		assert(type(P) == "table", "Proxies.SCUTTLER_PALETTE")
		local list = parts(model)
		assert(#list >= 25, "Scuttler has " .. #list .. " parts")
		local counts = { eye = 0, chevron = 0, moss = 0, carapace = 0 }
		for _, p in ipairs(list) do
			assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p:GetFullName())
			for _, bad in ipairs({ "Lane", "Circle", "Telegraph", "Ring", "Zone", "Wall" }) do
				assert(not p.Name:find(bad, 1, true), p.Name)
			end
			if p.Material == Enum.Material.Neon and p.Color == P.eye then counts.eye += 1 end
			if p.Color == P.chevron then counts.chevron += 1 end
			if p.Color == P.moss then counts.moss += 1 end
			if p.Color == P.carapace or p.Color == P.carapaceDark then counts.carapace += 1 end
		end
		assert(counts.eye >= 2, "amber Neon eyes: " .. counts.eye)
		assert(counts.chevron >= 3, "cream chevrons: " .. counts.chevron)
		assert(counts.moss >= 2, "moss accents: " .. counts.moss)
		assert(counts.carapace >= 4, "a maroon carapace: " .. counts.carapace)
		local head = model:FindFirstChild("Head")
		assert(head and head.Position.Z < -2, "the head faces the pivot's LookVector (-Z)")
		for _, name in ipairs({ "AntennaTipL", "AntennaTipR" }) do
			local tip = model:FindFirstChild(name)
			assert(tip and tip.Material == Enum.Material.Neon, name .. " glows (the lock's antenna flash)")
		end
		for _, side in ipairs({ "L", "R" }) do
			assert(model:FindFirstChild("Pincer" .. side .. "A") and model:FindFirstChild("Pincer" .. side .. "B"), "claw " .. side)
		end
	end)

	case("SC8: the client draws Scuttler's feint as an outline, the zone hatched, the pulse rings and the fall stars", function()
		local client = sources.client
		has(client, "Scuttler = Color3.fromRGB(", "a tell colour")
		local tell = body(client, "function handlers.Tell(ev, view)")
		has(tell, "if ev.feint then outline(item.model) end", "the feint: an outline without fill")
		has(tell, "if ev.zone then hatch(item.model, ev.shape, color) end", "the intercept zone, hatched")
		has(tell, "if not ev.feint then flash(view) end", "the antenna flash only on a real lock")
		local outline = body(client, "local function outline(model)")
		has(outline, 'name == "Fill"', "the fill goes"); has(outline, 'name:sub(1, 7) == "Chevron"', "and the chevrons")
		has(client, "local function pulseRings(view, item, at)", "rings expanding to the true radius")
		has(body(client, "local function pulseRings(view, item, at)"), "item.shape.r", "the drawn radius, never a guess")
		has(client, 'if ev.phase == "Stunned" or ev.phase == "OverrunStunned" or ev.phase == "Fallen" then',
			"stars while Fallen")
		has(client, "STAR_HEIGHT[view.beast]", "the stars over a tall body")
		has(client, 'ev.kind == "run"', "the intercept's straight run follows the server's timeline")
		local phase = body(client, "function handlers.Phase(ev, view)")
		has(phase, "OWN_PHASE_SOUND[view.beast]", "its own sounds")
		has(phase, "publishVariant(view, ev.fall)", "the fall's variant")
	end)

	case("SC8: a landed pulse (Afflict) shakes and desaturates only the target, never with Efectos suaves", function()
		local client = sources.client
		local afflict = body(client, "function handlers.Afflict(ev, view)")
		has(afflict, "if view.bystander then return end", "never a bystander")
		has(afflict, "if ev.shake ~= true or reduced() then return end", "Efectos suaves skips it")
		has(afflict, "shake(", "a camera shake"); has(afflict, "desaturate(", "a brief desaturation")
		for _, bad in ipairs({ "WalkSpeed", "FireServer", "AssemblyLinearVelocity", "Health" }) do
			hasNot(afflict, bad, "afflict (the server already applied the slow)")
		end
		has(body(client, "local function desaturate(seconds)"), "ColorCorrectionEffect")
	end)

	case("SC8: Scuttler's sounds are existing catalogue slots from plan section 9 and its lines exist", function()
		local client = sources.client
		local i = client:find("local OWN_PHASE_SOUND = {", 1, true)
		assert(i, "OWN_PHASE_SOUND")
		local j = client:find("\n}\n", i, true)
		local block = client:sub(i, j)
		local allowed = { steps = true, snap = true, roar = true, unease = true, crack = true, hit = true, stinger = true,
			softStinger = true, dirt = true }
		local n = 0
		for slot in block:gmatch('{ "(%w+)"') do
			n += 1
			assert(allowed[slot], "slot " .. slot .. " is not in plan section 9")
		end
		assert(n >= 6, "Scuttler phases with a sound: " .. n)
		has(block, 'Pulse = { "roar"', "the pulse release roars")
		has(block, 'Snap = { "snap"', "the Snap")
		has(block, 'PunishTell = { "stinger"', "the bait taken")
		hasNot(block, "FeintTell", "the feint has no cue (only real attacks do)")
		has(client, 'Scuttler = "dirt"', "the spawn rise")
		local words = sources.text.BEAST.Scuttler
		assert(type(words) == "table" and words.phases and words.phases.PulseCharge, "Text.BEAST.Scuttler")
	end)

	return result
end
