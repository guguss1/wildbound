-- Invoke with require(freshTestClone)(require(freshServiceClone), require(freshPortalClone), require(freshTextClone),
-- { server = WildboundServer.Source, beasts = WildboundBeasts.Source, service = freshServiceClone.Source,
-- client = WildboundPortalClient.Source }).
-- CE3 / T08b (odd/tasks/wildbound-caramelo.md, odd/tasks/wildbound-2-0.md): the return portal service. The server alone
-- decides: a portal's prompt names only the player (the client sends nothing), the server measures its own root against
-- the station, reads the threat signals it wrote itself (La Silueta's level, the beasts' stamp, bat hits, ragdoll, health,
-- awake parents), runs the channel on its own clock and moves the character onto the player's own base pad. CG2: a player
-- carrying an egg is refused (decision 47) and a station switched off mid-channel cuts it (F6). Fakes only:
-- fake players (attribute tables), parentless parts as roots and pads, a scripted clock, recorded teleports.
return function(Service, Portal, Text, sources)
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
	local C = Portal.CONFIG
	local STATION = Vector3.new(588, 0.5, -3) -- the Caramelo arch (GT cake move: 772 -> 588)

	local function fakePlayer(userId)
		local attributes = {}
		return {
			UserId = userId, Name = "P" .. userId,
			GetAttribute = function(_, key) return attributes[key] end,
			SetAttribute = function(_, key, value) attributes[key] = value end,
		}
	end
	-- A world: one station, the player's base pad, a clock, recorded calls.
	local function world(options)
		options = options or {}
		local w = { clock = 1000, teleports = {}, notes = {}, fired = {}, alive = true, health = 100, adults = {},
			carrying = false }
		w.player = fakePlayer(7)
		w.root = Instance.new("Part")
		w.root.Position = STATION + Vector3.new(3, 3, 0)
		w.pad = Instance.new("Part")
		w.pad.Size = Vector3.new(29, 0.4, 23)
		w.pad.Position = Vector3.new(348.5, 0.7, 24.5)
		local stationEnabled = options.enabled ~= false
		w.service = Service.new({
			Portal = Portal, Text = Text,
			now = function() return w.clock end,
			alive = function() return w.alive end,
			rootOf = function() return w.alive and w.root or nil end,
			teleport = function(player, frame) table.insert(w.teleports, { player = player, frame = frame }); return true end,
			bases = function()
				if options.noBase then return {} end
				return { { ownerUserId = 99, pad = Instance.new("Part") }, { ownerUserId = 7, pad = w.pad } }
			end,
			spawnFrame = function() return options.spawnFrame end,
			adults = function() return w.adults end,
			health = function() return w.health end,
			carrying = function() return w.carrying end,
			notify = function(player, ok, text) table.insert(w.notes, { player = player, ok = ok, text = text }) end,
			fire = function(player, payload) table.insert(w.fired, payload) end,
			hubCentre = Vector3.new(282, 0, -3),
		})
		w.service:addStation("caramelo", STATION, function() return stationEnabled end)
		function w.setEnabled(value) stationEnabled = value end
		w.service:track(w.player)
		function w.advance(seconds, step)
			step = step or 0.1
			local t = 0
			while t < seconds - 1e-9 do
				w.clock += step
				t += step
				w.service:tick()
			end
		end
		function w.lastNote() return w.notes[#w.notes] end
		function w.lastFired() return w.fired[#w.fired] end
		return w
	end

	case("SV-1: a calm player at the portal starts the channel; the client is told how long", function()
		local w = world()
		w.advance(1)
		local ok, reason = w.service:trigger(w.player, "caramelo")
		equal(ok, true, "ok " .. tostring(reason))
		equal(w.lastFired().kind, "Channel", "Channel event")
		equal(w.lastFired().seconds, C.channelSeconds, "seconds")
		equal(w.lastNote().text, Text.PORTAL.channel, "notice")
		equal(#w.teleports, 0, "not moved yet")
	end)

	case("SV-2: the server measures its own root: far away, an unknown station or no character is refused", function()
		local w = world()
		w.root.Position = STATION + Vector3.new(30, 0, 0)
		local ok, reason = w.service:trigger(w.player, "caramelo")
		equal(ok, false); equal(reason, "TooFar")
		equal(w.lastNote().text, Text.PORTAL.tooFar, "tooFar notice")
		equal(w.lastNote().ok, false, "a refusal")
		equal((w.service:trigger(w.player, "bosque")), false, "a station never attached")
		equal((w.service:trigger(w.player, 42)), false, "a bad id")
		w.root.Position = STATION
		w.alive = false
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Dead", "no character")
		equal(select(2, w.service:trigger(fakePlayer(8), "caramelo")), "Dead", "an untracked player")
	end)

	case("SV-3: after 2 s the character lands on its own base pad, facing the hub, and the portal rests 30 s", function()
		local w = world()
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(C.channelSeconds - 0.2)
		equal(#w.teleports, 0, "still channelling")
		w.advance(0.3)
		equal(#w.teleports, 1, "moved once")
		local frame = w.teleports[1].frame
		local top = w.pad.Position + Vector3.new(0, w.pad.Size.Y / 2 + 3, 0)
		assert((frame.Position - top).Magnitude < 1e-3, "on the own pad, got " .. tostring(frame.Position))
		local look = frame.LookVector
		assert(look.X < 0 and math.abs(look.Y) < 1e-3, "faces the hub centre")
		equal(w.lastNote().text, Text.PORTAL.arrived, "arrived notice")
		equal(w.lastFired().kind, "Arrived", "Arrived event")
		local readyAt = w.player:GetAttribute("WildboundPortalReadyAt")
		assert(type(readyAt) == "number" and math.abs(readyAt - (w.clock + C.cooldown)) < 0.11, "ReadyAt attribute")
		w.root.Position = STATION
		w.advance(5)
		local ok, reason = w.service:trigger(w.player, "caramelo")
		equal(ok, false); equal(reason, "Cooldown")
		assert(string.find(w.lastNote().text, "%d"), "the wait is shown: " .. w.lastNote().text)
		w.advance(C.cooldown)
		equal((w.service:trigger(w.player, "caramelo")), true, "rested")
	end)

	case("SV-4: La Silueta hunting cuts the channel and then blocks the portal until 5 s of calm", function()
		local w = world()
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(0.5)
		w.player:SetAttribute("WildboundThreatLevel", "Chase")
		w.advance(0.2)
		equal(w.lastFired().kind, "Cut", "cut")
		equal(w.lastFired().reason, "Threat", "reason")
		equal(w.lastNote().text, Text.PORTAL.cutThreat, "notice")
		w.advance(3)
		equal(#w.teleports, 0, "never moved")
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Threat", "still hunted")
		w.player:SetAttribute("WildboundThreatLevel", "Safe")
		w.advance(C.calmSeconds - 0.5)
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Threat", "not calm long enough")
		w.advance(0.6)
		equal((w.service:trigger(w.player, "caramelo")), true, "5 s of calm")
	end)

	case("SV-5: a beast on the player, a bat hit, a health drop or an awake parent nearby count as threats", function()
		local w = world()
		w.player:SetAttribute("WildboundBeastEngagedAt", w.clock)
		w.advance(0.1)
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Threat", "beast stamp")
		w.advance(C.signalSeconds + C.calmSeconds + 0.2) -- the stamp counts for signalSeconds, then 5 s of calm
		assert(w.service:trigger(w.player, "caramelo"))
		w.health = 80
		w.advance(0.2)
		equal(w.lastFired().reason, "Threat", "health drop cuts")
		w.advance(C.calmSeconds + 0.2)
		w.player:SetAttribute("WildboundBatHit", w.clock)
		w.advance(0.1)
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Threat", "bat hit")
		w.advance(C.calmSeconds + 0.2)
		w.adults = { { x = w.root.Position.X + 10, z = w.root.Position.Z } }
		w.advance(0.1)
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Threat", "awake parent")
		w.adults = {}
		w.advance(C.calmSeconds + 0.2)
		equal((w.service:trigger(w.player, "caramelo")), true, "calm again")
	end)

	case("SV-5b: the regeneration's one-point dips are not a hit (Play: health 36 -> 35 every second)", function()
		local w = world()
		w.health = 35
		w.advance(0.2)
		for _ = 1, 8 do
			w.health = 36.016
			w.advance(0.5)
			w.health = 35
			w.advance(0.5)
		end
		equal((w.service:trigger(w.player, "caramelo")), true, "small dips never block the portal")
		w.health = 35 - C.hurtMin - 0.5
		w.advance(0.2)
		equal(w.lastFired().reason, "Threat", "a real hit still cuts")
	end)

	case("SV-6: stepping away cuts the channel", function()
		local w = world()
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(0.5)
		w.root.Position += Vector3.new(0, 0, C.moveTolerance + 1)
		w.advance(0.2)
		equal(w.lastFired().reason, "Moved", "moved")
		equal(w.lastNote().text, Text.PORTAL.cutMoved, "notice")
		w.advance(3)
		equal(#w.teleports, 0, "never moved")
		equal((w.service:trigger(w.player, "caramelo")), true, "no rest after a cut")
	end)

	case("SV-7: without an own base the hub spawn pad is used; with neither the portal refuses", function()
		local spawn = CFrame.new(300, 4, 0)
		local w = world({ noBase = true, spawnFrame = spawn })
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(C.channelSeconds + 0.1)
		equal(#w.teleports, 1, "moved")
		assert((w.teleports[1].frame.Position - spawn.Position).Magnitude < 1e-3, "hub spawn pad")
		local none = world({ noBase = true })
		equal(select(2, none.service:trigger(none.player, "caramelo")), "NoBase", "nowhere to go")
		equal(none.lastNote().text, Text.PORTAL.noBase)
	end)

	case("SV-8: a switched-off station refuses", function()
		local w = world({ enabled = false })
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Disabled")
		equal(w.lastNote().text, Text.PORTAL.disabled)
	end)

	case("SV-9: a ragdolled player cannot start, and dying cuts the channel", function()
		local w = world()
		w.player:SetAttribute("WildboundRagdollUntil", w.clock + 1)
		equal(select(2, w.service:trigger(w.player, "caramelo")), "Dead", "ragdolled")
		w.player:SetAttribute("WildboundRagdollUntil", nil)
		w.advance(C.calmSeconds + 0.2) -- the ragdoll was a threat too
		assert(w.service:trigger(w.player, "caramelo"))
		w.alive = false
		w.advance(0.2)
		equal(w.lastFired().kind, "Cut", "cut")
		equal(w.lastFired().reason, "Dead", "dead")
		w.advance(3)
		equal(#w.teleports, 0, "never moved")
	end)

	case("SV-10: leaving forgets the player; a forgotten channel never moves anyone", function()
		local w = world()
		assert(w.service:trigger(w.player, "caramelo"))
		w.service:forget(w.player)
		w.advance(C.channelSeconds + 0.5)
		equal(#w.teleports, 0, "no teleport after leaving")
		equal(w.service.states[w.player], nil, "state dropped")
	end)

	case("SV-11: CG2 (decision 47): a carrier is refused with the walk-it-home notice; an egg picked up mid-channel cuts it", function()
		local w = world()
		w.carrying = true
		local ok, reason = w.service:trigger(w.player, "caramelo")
		equal(ok, false, "refused"); equal(reason, "Carrying", "reason")
		equal(w.lastNote().text, Text.PORTAL.carrying, "the Spanish notice")
		equal(w.lastFired().kind, "Refused", "the client is told")
		w.advance(C.channelSeconds + 0.5)
		equal(#w.teleports, 0, "never moved")
		w.carrying = false
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(0.5)
		w.carrying = true
		w.advance(0.2)
		equal(w.lastFired().kind, "Cut", "cut"); equal(w.lastFired().reason, "Carrying", "carrying cut")
		equal(w.lastNote().text, Text.PORTAL.carrying, "the same notice")
		w.advance(C.channelSeconds + 0.5)
		equal(#w.teleports, 0, "never moved with an egg")
		assert(not string.find(sources.service, "dropEgg", 1, true), "the service never drops an egg")
	end)

	case("SV-14: CG2 (F6): a station switched off mid-channel cancels it; no teleport, no rest", function()
		local w = world()
		assert(w.service:trigger(w.player, "caramelo"))
		w.advance(0.5)
		w.setEnabled(false)
		w.advance(0.2)
		equal(w.lastFired().kind, "Cut", "cut"); equal(w.lastFired().reason, "Disabled", "reason")
		equal(w.lastNote().text, Text.PORTAL.cutDisabled, "notice")
		w.advance(C.channelSeconds + 0.5)
		equal(#w.teleports, 0, "never moved")
		w.setEnabled(true)
		equal((w.service:trigger(w.player, "caramelo")), true, "no rest after the cut")
	end)

	case("SV-12: the forest station builder: a lit arch with a prompt, anchored, at its spot", function()
		local spec = Portal.station("bosque")
		local folder = Instance.new("Folder")
		local model = Service.buildStation(spec, folder, Text)
		equal(model.Parent, folder, "parent")
		equal(model:GetAttribute("PortalId"), "bosque", "PortalId")
		equal(model:GetAttribute("Enabled"), true, "Enabled")
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		assert(prompt, "a prompt")
		equal(prompt.ActionText, Text.PORTAL.prompt, "action"); equal(prompt.HoldDuration, 0, "no hold: the channel is the wait")
		assert(prompt.MaxActivationDistance <= C.useRange, "prompt within the server range")
		local count = 0
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				count += 1
				equal(part.Anchored, true, part.Name .. " anchored")
			end
		end
		assert(count >= 3 and count <= 12, "a few parts: " .. count)
		local pivot = model:GetPivot().Position
		assert(math.abs(pivot.X - spec.x) < 0.01 and math.abs(pivot.Z - spec.z) < 0.01, "at the station spot")
		folder:Destroy()
	end)

	case("SV-13: wiring: the server starts the service; the beasts stamp their target; the client sends nothing", function()
		assert(string.find(sources.server, 'WaitForChild("WildboundPortalService")', 1, true), "server requires the service")
		assert(string.find(sources.server, "PortalService.new(", 1, true), "server builds it")
		assert(string.find(sources.server, "carrying = function(player)", 1, true), "server tells it who carries an egg")
		assert(string.find(sources.beasts, '"WildboundBeastEngagedAt"', 1, true), "beasts stamp their target")
		-- CH1 (decision 53): only an engaging phase stamps; a Calm or merely present beast never does.
		local gate = string.find(sources.beasts, "Portal.engaging(phase)", 1, true)
		local stamp = string.find(sources.beasts, 'target:SetAttribute("WildboundBeastEngagedAt", at)', 1, true)
		assert(gate and stamp and gate < stamp, "the stamp is gated by Portal.engaging")
		assert(string.find(sources.beasts, 'WaitForChild("WildboundPortal")', 1, true), "beasts require the portal rules")
		assert(not string.find(sources.client, "FireServer", 1, true), "the client never fires the server")
		assert(not string.find(sources.client, "InvokeServer", 1, true), "nor invokes it")
		assert(string.find(sources.service, "Triggered", 1, true), "the prompt's server-side Triggered is the only input")
		assert(string.find(sources.service, "PlayerRemoving", 1, true), "cleanup on leave")
		-- The Play check's stand-in for the prompt: a server-only BindableFunction, made only in Studio.
		local probe = string.find(sources.service, 'probe.Name = "PortalProbe"', 1, true)
		assert(probe, "a Studio PortalProbe")
		local guard = string.find(sources.service, "if RunService:IsStudio() then", 1, true)
		assert(guard and guard < probe, "the probe exists only in Studio")
		assert(not string.find(sources.service, 'Instance.new("RemoteFunction")', 1, true), "never a remote probe")
	end)

	-- UR-P (owner request 2026-11-20, "quiero que la ui de mi juego sea exactamente igual a la de la foto que te envie";
	-- docs/design/refs/store-ui-reference.png): the channel bar wears the UI kit (WildboundUiStyle). Source pins only;
	-- the look itself is checked in Play.
	case("UR-P: the channel bar is a dark kit panel with outlined words and a glossy purple bar, styled off the main thread", function()
		local client = sources.client
		assert(type(client) == "string", "pass the portal client source")
		for _, needle in ipairs({ 'WaitForChild("WildboundUiStyle", 10)', 'Style.dressPanel(panel, "dark", 0.08)',
			"Style.loudText(title)", 'Style.glossBar(track, fill, "purple")', "track.Size = UDim2.new(1, -24, 0, 16)",
			"limit.MaxSize = Vector2.new(360, 56)" }) do
			assert(string.find(client, needle, 1, true), "missing: " .. needle)
		end
		local styled = string.find(client, "task.spawn(function()", 1, true)
		local kit = string.find(client, 'WaitForChild("WildboundUiStyle"', 1, true)
		local events = string.find(client, "remote.OnClientEvent:Connect", 1, true)
		assert(styled and kit and events and styled < kit and kit < events, "the kit never holds up the portal events")
		assert(not string.find(client, "rbxassetid", 1, true), "no image")
	end)

	return result
end
