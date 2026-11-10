-- Authoritative adapter. Deploy beside WildboundState in ServerScriptService.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local AssetService = game:GetService("AssetService")
local State = require(script.Parent:WaitForChild("WildboundState"))
local Wild = require(script.Parent:WaitForChild("WildboundLumipolWild"))
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Keys = require(script.Parent:WaitForChild("WildboundPromptKeys"))
local Capture = require(ReplicatedStorage:WaitForChild("WildboundCaptureSession"))
-- H3: the capture path's player-facing words, in Spanish.
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
-- Delivery B (B2): the carried creature's mood, glow and sound hook rules.
local Carry = require(ReplicatedStorage:WaitForChild("WildboundCarry"))
-- Delivery B (B3 to B5): the refuge deposit, the display spots and the companion's follow offset.
local Refuge = require(ReplicatedStorage:WaitForChild("WildboundRefuge"))
-- M5.2: the pure economy rules and the generated tuning copy (docs/mechanics/wildbound-economy-p0.md).
local Economy = require(ReplicatedStorage:WaitForChild("WildboundEconomy"))
local EconomyConfig = require(ReplicatedStorage:WaitForChild("WildboundEconomyConfig"))
local Spawn = require(script.Parent:WaitForChild("WildboundSpawn"))
local Relief = require(script.Parent:WaitForChild("WildboundRelief"))
-- Dread pass (D2, D3, D-D5): stamina, sprint and its two costs (noise, a frightened carried Lumipol).
local Stamina = require(script.Parent:WaitForChild("WildboundStamina"))
-- Expedition islands (I6): the island rule (sleep meter, nest roll, the woken adult's chase) and the species looks.
local Island = require(script.Parent:WaitForChild("WildboundIsland"))
-- Chase pass (CP-D5): the damage gates La Silueta uses (private mode on the listed place, lethal after a paid trip).
local FairStrike = require(script.Parent:WaitForChild("WildboundFairStrike"))
local CollectionService = game:GetService("CollectionService")
local Species = require(ReplicatedStorage:WaitForChild("WildboundSpecies"))
-- MeshGen1 pass (user, 2026-11-10): every Lumipol wears the user's model, ServerStorage.WildboundAssets.LumipolMeshGen.
-- Without a valid template every Lumipol keeps its primitive look.
local Art = require(script.Parent:WaitForChild("WildboundLumipolArt"))
local lumipolAssets = ServerStorage:FindFirstChild("WildboundAssets")
local lumipolTemplate = lumipolAssets and lumipolAssets:FindFirstChild(Art.CONFIG.TEMPLATE)
if not Art.valid(lumipolTemplate) then
	lumipolTemplate = nil
	warn("Wildbound: the Lumipol model template is missing or invalid; Lumipol keep the primitive look.")
else
	-- Play finding: a session can be refused the generated meshes ("Requester does not have permission"), and a mesh
	-- that never loads draws nothing, so a dressed Lumipol would be invisible. Each mesh is loaded once here, all at
	-- once, for at most VERIFY_SECONDS (a one-shot wake-up, no waiting loop); unless every one loads, the template is
	-- dropped.
	local ids, loaded, waiting = Art.meshIds(lumipolTemplate), {}, 0
	local thread, yielded, resumed = coroutine.running(), false, false
	local function wake()
		if yielded and not resumed then
			resumed = true
			task.spawn(thread)
		end
	end
	for _, id in ipairs(ids) do
		waiting += 1
		task.spawn(function()
			loaded[id] = pcall(function() AssetService:CreateMeshPartAsync(id):Destroy() end)
			waiting -= 1
			if waiting == 0 then wake() end
		end)
	end
	if waiting > 0 then
		yielded = true
		task.delay(Art.CONFIG.VERIFY_SECONDS, wake)
		coroutine.yield()
	end
	if not Art.verified(ids, loaded) then
		lumipolTemplate = nil
		warn("Wildbound: the Lumipol model's meshes did not load in this session; Lumipol keep the primitive look.")
	end
end
-- Random world (plan Part 3, RW2): the spawn clock over the spawn graph (eggs and crias that live 300 s and move).
local SpawnClock = require(script.Parent:WaitForChild("WildboundSpawnClock"))
local spawnGraph = require(script.Parent:WaitForChild("WildboundSpawnGraph"))
-- Random world (plan Part 6, RW3): the wave clock, the wave board and the WorldEvent messages (shared with clients).
local WaveClock = require(ReplicatedStorage:WaitForChild("WildboundWaveClock"))
-- Items and totem (plan Part 4, IT1): the equipment's pure rules (shared with the world script and the fear client).
local Gear = require(ReplicatedStorage:WaitForChild("WildboundGear"))
-- Nest Heist (NH1 to NH8): the stolen egg's rules (fast steal, the carry in the arms, drop and pickup).
local EggCarry = require(script.Parent:WaitForChild("WildboundEggCarry"))
local eggs = EggCarry.new()
-- The Nest Heist helpers share one table: this script is close to Luau's 200-local limit (a Play finding).
local Heist = {}
-- Nest Heist phase 2 (NP4): the bat rule and its registry ride in the same table.
Heist.Bat = require(script.Parent:WaitForChild("WildboundBat"))
Heist.bats = Heist.Bat.new()
local state = State.new(Economy, EconomyConfig)
local SHELTER_X, SHELTER_Z = EconomyConfig.capsule.x, EconomyConfig.capsule.z
local capture = Capture.new()
local map = workspace:WaitForChild("WildboundP0", 15)
if not map then warn("Wildbound: build the P0 map before starting gameplay."); return end

local function marker(name)
	local value = map:FindFirstChild(name, true)
	assert(value and value:IsA("BasePart"), "Wildbound missing marker: " .. name)
	return value
end
local creatureMarker, eggMarker = marker("LumipolMarker"), marker("EggMarker")
local extraction = marker("ExtractionMarker")
local campCenter = marker("CampCenter")
local hatchMarker, protectionMarker = marker("HatchMarker"), marker("ProtectionMarker")
-- Delivery B camp stations (tools/build-wildbound-p0-map.luau, buildCamp). Optional, so an older map still runs.
local function optionalMarker(name)
	local value = map:FindFirstChild(name, true)
	return value and value:IsA("BasePart") and value or nil
end
local refugeMarker, boardMarker = optionalMarker("RefugeMarker"), optionalMarker("BoardMarker")
-- Next batch NB4 (delivery E, docs/mechanics/wildbound-incubator.md): eggs incubate at the incubator; an older map
-- without one uses the hatch altar instead.
local incubatorMarker = map:FindFirstChild("IncubatorMarker", true)
if not (incubatorMarker and incubatorMarker:IsA("BasePart")) then incubatorMarker = hatchMarker end
local Incubator = require(ReplicatedStorage:WaitForChild("WildboundIncubator"))
-- Expedition islands (I6): where each island is and what it carries (tools/plan_islands.py). Without the layout the
-- game runs with no nests and says so.
local islandLayoutModule = script.Parent:FindFirstChild("WildboundIslandLayout")
local islandsLoaded, islandLayout = pcall(function()
	return islandLayoutModule and islandLayoutModule:IsA("ModuleScript") and require(islandLayoutModule) or nil
end)
if not islandsLoaded or type(islandLayout) ~= "table" or type(islandLayout.islands) ~= "table" then
	warn("Wildbound: WildboundIslandLayout is missing; no island nests this session.")
	islandLayout = { islands = {} }
end
-- Never overwrite an unowned or already-running root on duplicate startup.
if map:FindFirstChild("WildboundRuntime") or ReplicatedStorage:FindFirstChild("WildboundNetwork") then
	warn("Wildbound: runtime/network already exists; duplicate startup refused.")
	return
end
local runtime = Instance.new("Folder")
runtime.Name, runtime.Parent = "WildboundRuntime", map
local network = Instance.new("Folder")
network.Name = "WildboundNetwork"
network:SetAttribute("SessionOnly", true)
local actionRemote, stateRemote = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
actionRemote.Name, actionRemote.Parent = "Action", network
stateRemote.Name, stateRemote.Parent = "State", network
-- M3.3: the capture screen's feed. Only the session owner is ever sent a message on it.
local captureRemote = Instance.new("RemoteEvent")
captureRemote.Name, captureRemote.Parent = "CaptureState", network
-- Server-to-server only: a client can fire its own copy of a BindableEvent, which reaches nothing here.
local strikeEvent = Instance.new("BindableEvent")
strikeEvent.Name, strikeEvent.Parent = "CaptureStrike", network
-- M5.5: server-only totem holders for the world script, which applies the totem's downside.
local totemEvent = Instance.new("BindableEvent")
totemEvent.Name, totemEvent.Parent = "TotemChanged", network
-- M5.6 reverse event: the world script reports a pulse that revealed Silueta to a player in the fog.
local pulseHit = Instance.new("BindableEvent")
pulseHit.Name, pulseHit.Parent = "PulseHit", network
-- Delivery C1: capture noise for La Silueta (ring at the start, seal at the tap), with the slot tier. Server only.
local noiseEvent = Instance.new("BindableEvent")
noiseEvent.Name, noiseEvent.Parent = "GuardianNoise", network
-- Dread pass (D3): the client's sprint intent, "sprint" or "walk". The server owns stamina, stance and WalkSpeed.
local stanceRemote = Instance.new("RemoteEvent")
stanceRemote.Name, stanceRemote.Parent = "Stance", network
network.Parent = ReplicatedStorage

-- Measurement for the capture exit tests. Lives in ServerStorage, so no client can read or change it.
local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
if not telemetry then
	telemetry = Instance.new("Folder")
	telemetry.Name, telemetry.Parent = "WildboundTelemetry", ServerStorage
end

-- W16 (M9.5): analytics seam. WildboundFlags.analyticsMode "off" (the default, or any missing or odd value) builds a
-- no-op object; "record" keeps events in memory for tests and Play checks. No remote reaches it and no service is called.
local Analytics = require(script.Parent:WaitForChild("WildboundAnalytics"))
local flagsModule = script.Parent:FindFirstChild("WildboundFlags")
local flagsOk, flags = false, nil
if flagsModule and flagsModule:IsA("ModuleScript") then flagsOk, flags = pcall(require, flagsModule) end
local analytics, recorder = Analytics.fromMode(flagsOk and type(flags) == "table" and flags.analyticsMode or "off")
-- Chase pass (CP-D5): an adult's strike hurts only where La Silueta's would (WildboundFlags, this exact place).
local damageMode = FairStrike.effectiveMode(flagsOk and flags or nil, game.PlaceId)
if recorder then
	-- Server-only: ServerStorage never replicates. Returns the recorded events and the counters, for tests.
	local dump = Instance.new("BindableFunction")
	dump.Name = "AnalyticsDump"
	dump.OnInvoke = function() return table.clone(recorder.events), table.clone(analytics.counters) end
	dump.Parent = telemetry
end
-- Nest Heist Phase 3 (NS1, NS2): saved progress (docs/mechanics/wildbound-persistence.md, "Live saving"). WildboundSave
-- joins the State profile to one session-locked record per player; WildboundStoreRoblox is the only module that names
-- the data store. WildboundFlags.persistenceMode: "datastore" (default), "memory" or "off".
Heist.Save = require(script.Parent:WaitForChild("WildboundSave"))
-- Nest Heist Phase 3 (NS5): the treadmill's rule (shared, so the camp screen can word it).
Heist.Training = require(ReplicatedStorage:WaitForChild("WildboundTraining"))
Heist.joining = {}
Heist.saves = Heist.Save.start({
	state = state, record = require(script.Parent:WaitForChild("WildboundRecord")),
	persistence = require(script.Parent:WaitForChild("WildboundPersistence")),
	store = require(script.Parent:WaitForChild("WildboundStoreRoblox")),
	economy = Economy, config = EconomyConfig, telemetry = telemetry,
	mode = flagsOk and type(flags) == "table" and flags.persistenceMode or "datastore",
	notify = function(userId) if Heist.saveNotice then Heist.saveNotice(userId) end end,
})
game:BindToClose(function()
	analytics:closeAll()
	Heist.saves:closeAll()
end)

-- Server-to-server proof of registered ownership; clients cannot invoke bindables.
-- Never use a replicated Player attribute alone to authorize a companion ability.
local eligibility = Instance.new("BindableFunction")
eligibility.Name = "Eligibility"
eligibility.OnInvoke = function(player, ability)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false end
	-- Delivery C, D-C3: progress counts for the lethality gate (WildboundFairStrike.lethal decides). Counts only.
	if ability == "Progress" then
		local snapshot = state:snapshot(player.UserId)
		if not snapshot then return nil end
		local banked = 0
		for _, value in pairs(snapshot.banked or {}) do
			if type(value) == "number" and value > 0 then banked += value end
		end
		return { registered = #snapshot.registered, banked = banked, ember = snapshot.ember or 0 }
	end
	-- Delivery D6: whether this player has a capture open, so the world script refuses hiding. A yes or no only.
	if ability == "Capturing" then
		for _, session in ipairs(capture:activeSessions()) do
			if session.playerKey == player.UserId then return true end
		end
		return false
	end
	-- Expedition islands (I5): whether this player's carried cria is crying now. A yes or no only.
	if ability == "Crying" then
		local record = records[player]
		return record ~= nil and record.crying == true
	end
	if ability ~= "LumipolPulse" then return false end
	local snapshot = state:snapshot(player.UserId)
	if not snapshot or not snapshot.equippedUid then return false end
	for _, pet in ipairs(snapshot.registered) do
		if pet.uid == snapshot.equippedUid and pet.species == "Lumipol" then return true end
	end
	return false
end
eligibility.Parent = network

local records, serial = {}, 0
local playersByUserId = {}
-- Next batch NB3: every refusal and reply of this script, in Spanish, from WildboundText.NOTICES.
local notices = Text.NOTICES
-- The capture path's own refusals and endings read the shared text module first (H3).
local function captureNotice(reason)
	return Text.CAPTURE_NOTICES[reason] or notices[reason] or Text.CAPTURE_NOTICES.InvalidPlayer
end
-- Delivery B (B2): the carried creature rides in a small capsule on the carrier's back. The server builds it inside
-- the character, so every player sees it; its mood and sound hook are attributes the clients read, and each client
-- only animates the creature's seat joint. It weighs nothing, never collides and never blocks a ray.
local CAPSULE = "WildboundCarryCapsule"
local function capsulePart(model, name, size, shape, color, material, transparency)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Shape = name, size, shape
	part.Color, part.Material, part.Transparency = color, material, transparency or 0
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
	part.CastShadow = false
	part.Parent = model
	return part
end
local function weld(name, part0, part1, offset)
	local joint = Instance.new("Weld")
	joint.Name, joint.Part0, joint.Part1, joint.C0 = name, part0, part1, offset
	joint.Parent = part1
	return joint
end
local function paintCapsule(model, mood)
	local look = Carry.look(mood)
	local color = Color3.fromRGB(look.glow.r, look.glow.g, look.glow.b)
	local shell = model:FindFirstChild("Shell")
	if shell then
		shell.Color = color
		local light = shell:FindFirstChildOfClass("PointLight")
		if light then light.Color, light.Brightness = color, look.brightness end
	end
	model:SetAttribute("Mood", mood)
end
local function buildCapsule(character, carried)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return nil end
	-- I8: the cria inside wears its species' stand-in colours.
	local look = Species.look(carried.species)
	local model = Instance.new("Model")
	model.Name = CAPSULE
	model:SetAttribute("Uid", carried.uid)
	model:SetAttribute("Species", carried.species)
	local back = torso.Size.Z / 2
	local strap = capsulePart(model, "Strap", Vector3.new(0.9, 1.6, 0.14), Enum.PartType.Block,
		Color3.fromRGB(96, 70, 46), Enum.Material.Fabric)
	weld("StrapJoint", torso, strap, CFrame.new(0, 0, back + 0.08))
	local shell = capsulePart(model, "Shell", Vector3.new(1.8, 1.8, 1.8), Enum.PartType.Ball, Color3.new(1, 1, 1),
		Enum.Material.Glass, 0.6)
	weld("Mount", torso, shell, CFrame.new(0, 0.15, back + 0.95))
	local light = Instance.new("PointLight")
	light.Range, light.Shadows, light.Parent = 7, false, shell
	-- A wooden base ring, its rim showing outside the glass, that the creature sits on.
	local base = capsulePart(model, "Base", Vector3.new(0.25, 1.95, 1.95), Enum.PartType.Cylinder,
		Color3.fromRGB(120, 86, 52), Enum.Material.Wood)
	weld("BaseJoint", shell, base, CFrame.new(0, -0.45, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local creature = capsulePart(model, "Creature", Vector3.new(1.15, 0.85, 1), Enum.PartType.Ball,
		Color3.fromRGB(look.body[1], look.body[2], look.body[3]), Enum.Material.SmoothPlastic)
	weld("Seat", shell, creature, CFrame.new(0, 0.1, 0))
	-- MeshGen1 pass: a Lumipol rides as the user's model, its feet on the base ring, welded to the seat ball (the
	-- clients animate the seat joint) and hiding it; other species and a missing template keep the primitive.
	local art = Art.uses(look) and lumipolTemplate and Art.dress(model, lumipolTemplate,
		creature.CFrame * CFrame.new(0, -creature.Size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0), Art.CONFIG.CARRIED_HEIGHT)
	if art then
		creature.Transparency = 1
		for _, part in ipairs(art) do
			part.Anchored = false
			weld("ArtJoint", creature, part, creature.CFrame:ToObjectSpace(part.CFrame))
		end
	end
	-- It faces away from the carrier's back, so whoever follows sees its face.
	for _, x in ipairs(art and {} or { -0.25, 0.25 }) do
		local eye = capsulePart(model, "Eye", Vector3.new(0.14, 0.16, 0.1), Enum.PartType.Block,
			Color3.fromRGB(look.eye[1], look.eye[2], look.eye[3]), Enum.Material.SmoothPlastic)
		weld("EyeJoint", creature, eye, CFrame.new(x, 0.12, 0.47))
		local ear = capsulePart(model, "Ear", Vector3.new(0.22, 0.5, 0.26), Enum.PartType.Block,
			Color3.fromRGB(look.accent[1], look.accent[2], look.accent[3]), Enum.Material.SmoothPlastic)
		weld("EarJoint", creature, ear, CFrame.new(x, 0.45, 0) * CFrame.Angles(0, 0, x * 1.2))
	end
	paintCapsule(model, "calm")
	model.Parent = character
	return model
end
-- One capsule per carried creature, on the current living character only. Rebuilt for a new character when a
-- ward kept the creature through a defeat; removed when the creature is registered, lost or let go.
local function syncCapsule(player)
	local record, character = records[player], player.Character
	local snapshot = state:snapshot(player.UserId)
	local carried = snapshot and snapshot.carrying
	local existing = character and character:FindFirstChild(CAPSULE)
	if not carried or not record or record.character ~= character or record.defeated then
		if existing then existing:Destroy() end
		return
	end
	if existing and existing:GetAttribute("Uid") ~= carried.uid then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = buildCapsule(character, carried)
		record.sound = Carry.newSoundMemory()
	end
	if existing then existing:SetAttribute("Warded", carried.protected == true) end
end
-- Walk speed is the slower of the egg and carried-creature speed (M3.5, B1) and the pouch load step (M5.2).
-- Set when a reply is sent, for each new character and when the stance changes. The dread pass (D3) keeps that as
-- the base and puts the stance on top, so a sprint still pays every carry cost.
local function applyCarry(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local snapshot = state:snapshot(player.UserId)
	local record = records[player]
	if not humanoid or not snapshot or not record then return end
	local units = 0
	for _, quantity in pairs(snapshot.carried) do units += quantity end
	local carrySpeed = Wild.carrySpeed(Wild.eggsCarried(snapshot), snapshot.carrying ~= nil)
	local speed = Economy.carrySpeed(EconomyConfig, units, snapshot.pouchCapacity, carrySpeed, snapshot.skills)
	-- NS5: trained walk levels, only while unencumbered and never over Training.WALK_CAP (sprint and Burst keep theirs).
	-- NS7: the worn glove's Velocidad rides on the same rule and cap.
	speed = Heist.Training.walkSpeed(speed, EconomyConfig.carry.baseSpeed, snapshot.training,
		Gear.moveBonus(snapshot.glove, EconomyConfig.carry.baseSpeed))
	record.baseSpeed = speed
	speed = Stamina.speed(speed, record.stamina and record.stamina.stance or "walk")
	-- NH4: a running burst pushes the speed for its 0.8 s (capped, never stacked on the sprint).
	if record.stamina and Stamina.bursting(record.stamina, workspace:GetServerTimeNow()) then
		speed = math.max(speed, Stamina.speed(record.baseSpeed, record.stamina.stance, true))
	end
	-- NP4: a bat stumble slows the player for a fraction of a second (never faster).
	speed = Heist.Bat.speed(speed, Heist.bats, player.UserId, workspace:GetServerTimeNow())
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end
-- B4 and B5: set below, once the display spots and the companion are known. Every reply refreshes both.
local refreshDisplay, syncCompanion
-- RW3: set with the wave clock below; Esencia a player gains reaches the wave board.
local bankEsencia
-- NS7: the worn glove's "Robo rápido" goes to the owner's client as an attribute only this server writes: it shortens
-- that client's own egg prompts' hold (never under Gear.STEAL_FLOOR). Every other glove effect is applied here.
local function syncGear(player, snapshot)
	if not snapshot or not records[player] then return end
	local steal = Gear.effect(snapshot.glove, "steal")
	if player:GetAttribute("WildboundGloveSteal") ~= steal then player:SetAttribute("WildboundGloveSteal", steal) end
end
-- card: a registration receipt for the presentation card (B3); the client words it with WildboundRefuge.card.
local function send(player, action, ok, notice, lossSummary, card)
	local record = records[player]
	if not record or player.Parent ~= Players then return end
	applyCarry(player)
	syncCapsule(player)
	if refreshDisplay then refreshDisplay(player) end
	-- HB-T5: the owner's base display follows the same snapshot.
	if Heist.hub then Heist.hub:refreshDisplay(player) end
	if syncCompanion then syncCompanion(player) end
	local snapshot = state:snapshot(player.UserId)
	-- NS1: the HUD says "saved" only while this player's progress really is being saved.
	if snapshot then snapshot.sessionOnly = not Heist.saves:isSaving(player.UserId) end
	-- RW3: Esencia gained since the last snapshot counts for this wave's board (spending never does).
	if snapshot then
		local ember = snapshot.ember or 0
		if record.ember ~= nil and ember > record.ember and bankEsencia then bankEsencia(player, ember - record.ember) end
		record.ember = ember
	end
	syncGear(player, snapshot)
	if snapshot and record.totem ~= snapshot.totemActive then
		record.totem = snapshot.totemActive
		totemEvent:Fire(player, snapshot.totemActive)
	end
	stateRemote:FireClient(player, {
		snapshot = snapshot, action = action, ok = ok, notice = notice or "", lossSummary = lossSummary, card = card,
	})
end
local function allowed(player, action)
	local record = records[player]
	if not record then return false end
	local now = os.clock()
	if now - record.lastAny < 0.08 or now - (record.rates[action] or -math.huge) < 0.3 then return false end
	record.lastAny, record.rates[action] = now, now
	return true
end
local function context(player, target)
	local record, character = records[player], player.Character
	if not record or not character or record.character ~= character or not character:IsDescendantOf(workspace) then
		return false, math.huge
	end
	local humanoid, root = character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
	if record.defeated or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, math.huge
	end
	if not target then return true, 0 end
	if not target:IsDescendantOf(map) then return false, math.huge end
	return true, (root.Position - target.Position).Magnitude
end
local function reply(player, action, ok, reason, success)
	send(player, action, ok, ok and success or (notices[reason] or notices.fallback))
end
-- input = one entry of WildboundPromptKeys. Camp prompts each have their own, so the nearest marker cannot take
-- the key of another (found in W3b); Lumipol and drop prompts keep E.
local function prompt(target, action, object, range, hold, input)
	local value = Instance.new("ProximityPrompt")
	local choice = input or Keys.LUMIPOL
	value.ActionText, value.ObjectText = action, object
	value.MaxActivationDistance, value.HoldDuration = range, hold or 0.25
	value.RequiresLineOfSight = false
	value.KeyboardKeyCode, value.GamepadKeyCode = Enum.KeyCode[choice.key], Enum.KeyCode[choice.pad]
	value.UIOffset = Vector2.new(choice.offset[1], choice.offset[2])
	value.Parent = target
	return value
end
local function validPrompt(value, target)
	return value.Enabled and value.Parent == target and target:IsDescendantOf(map)
end
-- NB4: the Hatch action and the incubator prompt put an owned banked egg in the incubator, on the server's clock and
-- with the live, tunable time; the hatch step below hatches it. The client names only the egg.
-- HB-T4: measured = the server's distance to the player's own base incubator (its prompt); otherwise the nearer of the
-- camp's incubator and the own base's one in reach (the Bag's "Incubar"). Same state, one slot, saved (Phase 3).
local function hatch(player, uid, measured)
	local alive, distance = context(player, incubatorMarker)
	distance = math.min(distance, measured or (Heist.hub and Heist.hub:distance(player, "WildboundIncubatorStation"))
		or math.huge)
	local ok, result = state:incubate(player.UserId, uid, alive, distance, workspace:GetServerTimeNow(),
		Incubator.live.HATCH_SECONDS, Incubator.live.SLOTS)
	local started = ok and Text.INCUBATOR.started:format(math.ceil(result.readyAt - result.startedAt)) or nil
	reply(player, "Hatch", ok, result, started)
end
-- B8: a seal wards a bag item anywhere while alive (M5.5). It is spent only if it saves the item.
local function protect(player, uid)
	local ok, reason = state:protect(player.UserId, uid, context(player))
	reply(player, "Protect", ok, reason, notices.warded)
end
local function extractNotice(count, receipt)
	local units = 0
	for _, quantity in pairs(receipt.units) do units += quantity end
	return Text.CAMP.stored:format(count, units, receipt.ember)
end

-- B4: the storage chest is the old Extract prompt at ExtractionMarker. It moves the temporary bag and the pouch to
-- permanent storage; a carried creature is told to go to the refuge instead.
local extractPrompt = prompt(extraction, Text.CAMP.chest, Text.CAMP.chestObject, 12, nil, Keys.CAMP.extract)
extractPrompt.Triggered:Connect(function(player)
	if not validPrompt(extractPrompt, extraction) or not allowed(player, "Extract") then return end
	local alive, distance = context(player, extraction)
	local ok, count, receipt = state:extract(player.UserId, alive, distance, workspace:GetServerTimeNow())
	if ok then
		analytics:extracted(player.UserId)
		-- NH6: the egg in the arms was banked with the bag: Secured, out of the arms.
		Heist.secure(player)
		send(player, "Extract", true, extractNotice(count, receipt))
	elseif count == "Empty" then
		local snapshot = state:snapshot(player.UserId)
		send(player, "Extract", false, snapshot and snapshot.carrying and Text.CAMP.chestCreature or Text.CAMP.chestEmpty)
	else
		reply(player, "Extract", false, count)
	end
end)
local hatchPrompt = prompt(incubatorMarker, Text.INCUBATOR.prompt, Text.INCUBATOR.object, Incubator.CONSTANTS.RANGE, nil,
	Keys.CAMP.hatch)
hatchPrompt.Triggered:Connect(function(player)
	if not validPrompt(hatchPrompt, incubatorMarker) or not allowed(player, "Hatch") then return end
	-- NH6: an egg carried to the incubator is delivered there: banked with the bag (Secured), then incubated.
	local carried = EggCarry.carriedBy(eggs, player.UserId)
	if carried then
		local uid = carried.uid
		local alive, distance = context(player, incubatorMarker)
		local ok, count, receipt = state:extract(player.UserId, alive, distance, workspace:GetServerTimeNow())
		if not ok then
			reply(player, "Extract", false, count)
			return
		end
		analytics:extracted(player.UserId)
		Heist.secure(player)
		send(player, "Extract", true, extractNotice(count, receipt))
		hatch(player, uid)
		return
	end
	local snapshot = state:snapshot(player.UserId)
	local egg = snapshot and snapshot.bankedEggs[1]
	if not egg then
		send(player, "Hatch", false, Text.INCUBATOR.noEgg)
		return
	end
	hatch(player, egg.uid)
end)
-- NB4: an egg whose time has come hatches on the server's clock, checked once a second, wherever its owner is. The
-- creature joins the collection and the presentation card opens; hatching pays nothing.
local nextHatchAt = 0
local function stepIncubators(now)
	if now < nextHatchAt then return end
	nextHatchAt = now + 1
	for player in pairs(records) do
		for _, born in ipairs(state:hatchReady(player.UserId, now)) do
			-- NS3: a newborn with no companion out follows at once (send rebuilds the companion from the snapshot).
			if born.equipped then
				player:SetAttribute("WildboundEquippedUid", born.uid)
				player:SetAttribute("WildboundHasLumipol", true)
			end
			local words = born.equipped and Text.INCUBATOR.hatchedEquipped or Text.INCUBATOR.hatched
			send(player, "Hatched", true, words:format(Text.CARD.species[born.species] or born.species), nil,
				{ uid = born.uid, species = born.species, ember = 0, isNew = born.isNew, repeated = false })
		end
	end
end
local protectionPrompt = prompt(protectionMarker, notices.protectPrompt, notices.protectObject, 12, nil, Keys.CAMP.protect)
protectionPrompt.Triggered:Connect(function(player)
	if not validPrompt(protectionPrompt, protectionMarker) or not allowed(player, "ProtectHint") then return end
	local alive, distance = context(player, protectionMarker)
	if alive and distance == distance and distance <= 12 then
		send(player, "ProtectHint", true, notices.protectHint)
	end
end)

local function block(model, name, size, offset, color, shape)
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, offset
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Material, part.Color = Enum.Material.SmoothPlastic, color
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end
-- I8 (decision EI-4): a creature is its species' primitive stand-in (WildboundSpecies), `scale` times an adult; a
-- Lumipol at scale 1 is the old provisional model. An island egg is pale gold; the old Lumipol egg stays green.
local function rgb(value) return Color3.fromRGB(value[1], value[2], value[3]) end
local function visual(kind, position, species, scale)
	local model = Instance.new("Model")
	local bloom = kind == "Nightbloom"
	local look = Species.look(species)
	scale = type(scale) == "number" and scale > 0 and scale or 1
	model.Name = kind == "Egg" and "LumipolEgg" or bloom and "NightbloomBundle" or "Lumipol"
	local creatureSize = Vector3.new(look.size[1], look.size[2], look.size[3]) * scale
	local size = kind == "Egg" and Vector3.new(2, 2.8, 2) or bloom and Vector3.new(1.6, 1.6, 1.6) or creatureSize
	local color = bloom and Color3.fromRGB(150, 110, 230) or kind == "Egg" and species and rgb(Species.NEST_GLOW.egg)
		or rgb(look.body)
	local lift = kind == "Creature" and size.Y / 2 + 1 or 2
	local body = block(model, "Body", size, CFrame.new(position + Vector3.new(0, lift, 0)), color, Enum.PartType.Ball)
	if kind == "Creature" then
		-- MeshGen1 pass: a Lumipol wears the user's model, its feet on the ground under the ball. The ball stays the
		-- gameplay body (prompt, light, tags, every move) and is hidden; without the template it keeps its eyes and ears.
		local dressed = Art.uses(look) and lumipolTemplate ~= nil
			and Art.dress(model, lumipolTemplate, CFrame.new(position), Art.CONFIG.HEIGHT * scale) ~= nil
		if dressed then
			body.Transparency = 1
			model:SetAttribute(Art.CONFIG.ATTRIBUTE, true)
		end
		local glowing = look.name ~= "Lumipol"
		for _, side in ipairs(if not dressed then { -1, 1 } else {}) do
			local eye = block(model, "Eye", Vector3.new(0.35, 0.4, 0.25) * scale,
				body.CFrame * CFrame.new(side * size.X * 0.22, size.Y * 0.15, -size.Z / 2 + 0.05), rgb(look.eye))
			if glowing then eye.Material = Enum.Material.Neon end
			block(model, "Ear", Vector3.new(0.6, 1.3, 0.7) * scale,
				body.CFrame * CFrame.new(side * size.X * 0.22, size.Y * 0.55, 0) * CFrame.Angles(0, 0, side * 0.195),
				rgb(look.accent))
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = rgb(look.glow), 0.7, 10, body
	model.PrimaryPart, model.Parent = body, runtime
	return model, body
end

-- Delivery B, camp ------------------------------------------------------------------------------------------
-- Station signs carry a SignKey and an empty label; their words come from the Spanish text module.
for _, item in ipairs(map:GetDescendants()) do
	local key = item:GetAttribute("SignKey")
	local label = key and item:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") and type(Text.CAMP[key]) == "string" then label.Text = Text.CAMP[key] end
end

-- B4: the camp display. Each player with a registered Lumipol gets one pedestal, first come first served, showing
-- the equipped (else the first registered) Lumipol and the owner's name. Everyone sees every spot; nothing on it can
-- be taken or moved by another player. Each client adds the idle motion locally from the Base attribute.
local displaySpots, displayOwners, displayModels = {}, {}, {}
for index = 1, Refuge.CONFIG.DISPLAY_SPOTS do displaySpots[index] = optionalMarker("DisplaySpot" .. index) end
local function plaqueOf(index)
	local spot = displaySpots[index]
	local plaque = spot and spot.Parent and spot.Parent:FindFirstChild("Plaque" .. index)
	local label = plaque and plaque:FindFirstChild("Label", true)
	return label and label:IsA("TextLabel") and label or nil
end
local function clearDisplay(player)
	local model = displayModels[player]
	if model then model:Destroy() end
	displayModels[player] = nil
	local index = displayOwners[player.UserId]
	local label = index and plaqueOf(index)
	if label then label.Text = "" end
	Refuge.releaseSpot(displayOwners, player.UserId)
end
refreshDisplay = function(player)
	local choice = Refuge.displayChoice(state:snapshot(player.UserId))
	if not choice then
		if displayModels[player] then clearDisplay(player) end
		return
	end
	local index = Refuge.assignSpot(displayOwners, player.UserId, Refuge.CONFIG.DISPLAY_SPOTS)
	local spot = index and displaySpots[index]
	if not spot then return end
	local current = displayModels[player]
	if current and current.Parent and current:GetAttribute("Uid") == choice.uid then return end
	if current then current:Destroy() end
	local model = visual("Creature", spot.Position, choice.species)
	model.Name = "DisplayLumipol"
	model:ScaleTo(0.6)
	-- MeshGen1 pass: the art's feet (1.2 under the scaled ball's centre) stand on the pedestal, 0.4 over the spot.
	local at = spot.Position + Vector3.new(0, model:GetAttribute(Art.CONFIG.ATTRIBUTE) == true and 1.6 or 0.75, 0)
	local base = CFrame.lookAt(at, Vector3.new(campCenter.Position.X, at.Y, campCenter.Position.Z))
	model:PivotTo(base)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", choice.uid)
	model:SetAttribute("Spot", index)
	model:SetAttribute("Base", base)
	displayModels[player] = model
	local label = plaqueOf(index)
	if label then label.Text = Text.DISPLAY.owner:format(player.DisplayName) end
end

-- B3: the deposit. The creature leaves the capsule on the carrier's back and arcs into the refuge's nest, shrinking.
local function playDeposit(from, species)
	local nest = refugeMarker.Position + Vector3.new(0, 0.6, 0)
	local model = visual("Creature", from, species)
	model.Name = "RefugeDeposit"
	model:ScaleTo(0.4)
	local glow = map:FindFirstChild("RefugeGlow", true)
	local light = glow and glow:FindFirstChildOfClass("PointLight")
	-- A tweened clock drives the pose, so the adapter keeps no waiting loop (ECO-20 AFK-1).
	local clock = Instance.new("NumberValue")
	clock.Changed:Connect(function(t)
		if not model.Parent then return end
		local pose = Refuge.depositPose(t)
		model:ScaleTo(0.4 * pose.scale)
		model:PivotTo(CFrame.new(from:Lerp(nest, pose.alpha) + Vector3.new(0, pose.lift, 0)))
	end)
	local tween = TweenService:Create(clock, TweenInfo.new(Refuge.CONFIG.DEPOSIT_SECONDS, Enum.EasingStyle.Linear),
		{ Value = Refuge.CONFIG.DEPOSIT_SECONDS })
	tween.Completed:Connect(function()
		if light then light.Brightness = 3 end
		task.delay(0.4, function()
			if light then light.Brightness = 1.2 end
			model:Destroy()
			clock:Destroy()
		end)
	end)
	tween:Play()
end

-- B3: the creature refuge. The server picks the token, the carried creature's uid; a repeat is idempotent in State
-- (a double press or a resent request is told it is already registered and pays nothing).
if refugeMarker then
	local refugePrompt = prompt(refugeMarker, Text.CAMP.register, Text.CAMP.refuge, 10, 0.4, Keys.CAMP.register)
	refugePrompt.Triggered:Connect(function(player)
		if not validPrompt(refugePrompt, refugeMarker) or not allowed(player, "Register") then return end
		local record = records[player]
		local snapshot = state:snapshot(player.UserId)
		local carried = snapshot and snapshot.carrying
		local uid = carried and carried.uid or (record and record.lastRegistered)
		local capsule = player.Character and player.Character:FindFirstChild(CAPSULE)
		local shell = capsule and capsule:FindFirstChild("Shell")
		local from = shell and shell.Position or (refugeMarker.Position + Vector3.new(0, 3, 0))
		local alive, distance = context(player, refugeMarker)
		local ok, result, receipt = state:register(player.UserId, uid, alive, distance, workspace:GetServerTimeNow())
		if not ok then
			send(player, "Register", false, result == "NotCarried" and Text.CAMP.nothingCarried or notices[result]
				or Text.CAPTURE_NOTICES.InvalidContext)
			return
		end
		if receipt.repeated then
			send(player, "Register", true, Text.CAMP.alreadyRegistered)
			return
		end
		if record then record.lastRegistered = uid end
		analytics:registered(player.UserId)
		playDeposit(from, receipt.species)
		-- K2: the card pays the first-steal bonus on its own line and names the next island to find.
		local after = state:snapshot(player.UserId)
		local nextIsland = Refuge.nextIsland(islandLayout.islands, after and after.discovered)
		send(player, "Register", true, Text.CAMP.registered:format(Text.CARD.species[receipt.species] or receipt.species),
			nil, { uid = receipt.uid, species = receipt.species, ember = receipt.ember, isNew = receipt.isNew,
				repeated = false, firstBonus = receipt.firstBonus, firstEver = receipt.firstEver,
				nextIsland = nextIsland and nextIsland.id, nextSpecies = nextIsland and nextIsland.species })
	end)
end

-- B4: the upgrade board opens the camp screen (upgrades, skills, crafting), paid with what trips banked.
if boardMarker then
	local boardPrompt = prompt(boardMarker, Text.CAMP.board, Text.CAMP.boardObject, 10, nil, Keys.CAMP.board)
	boardPrompt.Triggered:Connect(function(player)
		if not validPrompt(boardPrompt, boardMarker) or not allowed(player, "OpenBoard") then return end
		local alive, distance = context(player, boardMarker)
		if alive and distance <= 12 then send(player, "OpenBoard", true, Text.CAMP.boardOpen) end
	end)
end

-- Slots, sessions and wildlife -------------------------------------------------------------------
-- Every wild encounter lives in `entries`, keyed by its never-reused id. Slot ids decide where and when.
local rng = Random.new()
local function rand() return rng:NextNumber() end
local entries = {}
local sessionMeta = {}
local captureLog = {}
local counters = { started = 0, completed = 0, failed = 0, cancelled = 0, grantRefused = 0, rejected = 0 }
-- Expedition relief (R5): every creature, egg and drop stands on the ground at its own position, from the shared
-- height rule over ServerStorage.WildboundReliefLayout (a flat floor when the layout is missing or broken). Visuals
-- keep the creature marker's lift over the floor top, now over their own ground.
local reliefLayoutModule = ServerStorage:FindFirstChild("WildboundReliefLayout")
local reliefLoaded, reliefLayout = pcall(function()
	return reliefLayoutModule and reliefLayoutModule:IsA("ModuleScript") and require(reliefLayoutModule) or nil
end)
local relief = Relief.new(reliefLoaded and reliefLayout or nil)
local MARKER_LIFT = creatureMarker.Position.Y - Relief.FLOOR_TOP
local function groundAt(x, z)
	return relief:heightAt(x, z) + MARKER_LIFT
end
local handleEnding

-- A1: cover for hiding Lumipol, read once from the dressed map's props and passed to the pure brain as data.
local COVER_NAMES = { FK_Evergreen_Trunk = true, FK_DeadTree_Wood = true, FK_DeadTree_Splinter = true,
	FK_FallenLog_Bark = true, FK_LanternMarker_Stones = true, RuinPillar = true }
local coverCandidates = {}
for _, part in ipairs(map:GetDescendants()) do
	if part:IsA("BasePart") and COVER_NAMES[part.Name] then
		table.insert(coverCandidates, { x = part.Position.X, z = part.Position.Z,
			r = math.min(part.Size.X, part.Size.Z) / 2 })
	end
end

-- I6: a short server-only log of island events for the Play checks (ServerStorage, never replicated).
local islandEvents = {}
local function islandLog(kind, islandId, userId)
	table.insert(islandEvents, { kind = kind, island = islandId, user = userId, at = math.floor(workspace:GetServerTimeNow() * 10) / 10 })
	while #islandEvents > 40 do table.remove(islandEvents, 1) end
	telemetry:SetAttribute("IslandLog", HttpService:JSONEncode(islandEvents))
end

local function publishTelemetry()
	telemetry:SetAttribute("CaptureAnomaly", capture.counters.anomaly)
	telemetry:SetAttribute("CaptureWatchdog", capture.counters.watchdog)
	for key, value in pairs(counters) do telemetry:SetAttribute("Capture_" .. key, value) end
	telemetry:SetAttribute("CaptureLog", HttpService:JSONEncode(captureLog))
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- B5: the equipped companion. Server-owned and replicated, so every player sees it. It follows its owner through an
-- AlignPosition to an attachment in the owner's root, with no reaction force, so it never pushes or blocks the owner;
-- every part is massless, non-colliding, untouchable and unqueryable. The owner's client simulates it (network owner)
-- and adds the hover bob and the pulse hop to that attachment. A registered companion is never lost: it is rebuilt
-- for each new character, so it comes back after a defeat.
local COMPANION = "WildboundCompanion"
local companionFolder = Instance.new("Folder")
companionFolder.Name, companionFolder.Parent = "WildboundCompanions", runtime
local companions = {}
-- NS4: the companion's PointLight (built by `visual` on its body) follows the live, tunable values.
function Heist.lightCompanion(model)
	local body = model.PrimaryPart
	local light = body and body:FindFirstChildOfClass("PointLight")
	if not light then return end
	if light.Brightness ~= Refuge.live.LIGHT_BRIGHTNESS then light.Brightness = Refuge.live.LIGHT_BRIGHTNESS end
	if light.Range ~= Refuge.live.LIGHT_RANGE then light.Range = Refuge.live.LIGHT_RANGE end
	-- The owner's client animates the pulse locally and rests at this value afterwards.
	if light:GetAttribute("WildboundBaseBrightness") ~= Refuge.live.LIGHT_BRIGHTNESS then
		light:SetAttribute("WildboundBaseBrightness", Refuge.live.LIGHT_BRIGHTNESS)
	end
end
local function removeCompanion(player)
	local entry = companions[player]
	if not entry then return end
	companions[player] = nil
	entry.model:Destroy()
	entry.anchor:Destroy()
end
syncCompanion = function(player)
	local snapshot = state:snapshot(player.UserId)
	local uid = snapshot and snapshot.equippedUid
	local record, root = records[player], rootOf(player)
	if not uid or not record or record.defeated or not root or context(player) ~= true then
		removeCompanion(player)
		return
	end
	local current = companions[player]
	if current and current.uid == uid and current.root == root and current.model.Parent == companionFolder then
		Heist.lightCompanion(current.model)
		return
	end
	removeCompanion(player)
	local offset = Refuge.companionOffset(0, nil)
	local anchor = Instance.new("Attachment")
	anchor.Name = "WildboundCompanionAnchor"
	anchor.Position = Vector3.new(offset.x, offset.y, offset.z)
	anchor.Parent = root
	local species
	for _, pet in ipairs(snapshot.registered) do
		if pet.uid == uid then species = pet.species end
	end
	local model, body = visual("Creature", (root.CFrame * CFrame.new(offset.x, offset.y - 2, offset.z)).Position, species)
	model.Name = COMPANION
	model:ScaleTo(0.5)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
			part.CastShadow = false
			if part ~= body then
				local joint = Instance.new("WeldConstraint")
				joint.Part0, joint.Part1, joint.Parent = body, part, part
			end
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local align = Instance.new("AlignPosition")
	align.Attachment0, align.Attachment1 = attachment, anchor
	align.Responsiveness, align.MaxForce, align.MaxVelocity = 18, 1e5, 80
	align.Parent = body
	local turn = Instance.new("AlignOrientation")
	turn.Attachment0, turn.Attachment1 = attachment, anchor
	turn.Responsiveness, turn.MaxTorque = 12, 1e5
	turn.Parent = body
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", uid)
	model.Parent = companionFolder
	pcall(function() body:SetNetworkOwner(player) end)
	companions[player] = { model = model, anchor = anchor, uid = uid, root = root }
	Heist.lightCompanion(model)
end

-- Values the capture rule trusts: all read here, none from a client.
local function observe(player, now)
	local record = records[player]
	local alive = context(player)
	local root = rootOf(player)
	local bag, collection = state:captureRoom(player.UserId)
	local position = root and root.Position
	return { now = now, alive = alive == true and root ~= nil, life = record and record.generation,
		x = position and position.X, y = position and position.Y, z = position and position.Z,
		bagRoom = bag, collectionRoom = collection }
end

-- Fix pass (FP2, one Silueta per player): the reading is this player's own hunter, the model the world marks with the
-- player's user id; without one (over the cap) there is no guardian reading.
local function guardianReading(player, position)
	local world = map:FindFirstChild("WildboundWorldRuntime")
	if not world then return nil, nil end
	for _, guardian in ipairs(world:GetChildren()) do
		if guardian.Name == "Silueta" and guardian:GetAttribute("Owner") == player.UserId then
			local body = guardian:FindFirstChild("Body")
			if body and body:IsA("BasePart") then return guardian:GetAttribute("State"), (body.Position - position).Magnitude end
		end
	end
	return nil, nil
end

local function removeEntry(entry, now)
	if entries[entry.id] ~= entry then return end
	entries[entry.id] = nil
	entry.prompt.Enabled = false
	if entry.connection then entry.connection:Disconnect() end
	entry.model:Destroy()
	state:retireEncounter(entry.id)
	EggCarry.retire(eggs, entry.id)
	local out = capture:retire(entry.id, now or workspace:GetServerTimeNow())
	if out then handleEnding(out) end
end

-- Expedition islands (I6, docs/mechanics/wildbound-expedition-islands.md section 2) ------------------------
-- The wandering slots are retired: every cria or egg lies in an island nest. Each island has one shared sleep meter
-- (WildboundIsland), fed only by values this script reads (positions, speed, the server's forward vector, the
-- stance, capture endings and the guardian noises); no client can read or set it. When it wakes, the adults
-- scream (a guardian noise, EI-5) and one adult chases the thief for a few seconds inside its island (EI-2): a
-- touch makes the thief drop the cria, which runs home; nobody is hurt. Adults, nests and readouts are visuals.
local islands, islandList = {}, {}
local nestState, nestGen = {}, {}
local islandFolder = map:FindFirstChild("Islands")
local READOUT = { sleep = Color3.fromRGB(170, 205, 255), stir = Color3.fromRGB(255, 190, 80),
	alert = Color3.fromRGB(255, 70, 70) }

-- The phase, with the Studio-only Play clock shift the world script also reads (D-D7), so both agree in Play.
local function islandCycle()
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local origin = world and world:GetAttribute("CycleStartedAt")
	local shift = 0
	local value = RunService:IsStudio() and telemetry:FindFirstChild("StudioClockShift")
	if value and value:IsA("NumberValue") and Rules.finite(value.Value) then shift = value.Value end
	return Rules.cycle((Rules.finite(origin) and workspace:GetServerTimeNow() - origin or 0) + shift)
end
local function islandPhase()
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local origin = world and world:GetAttribute("CycleStartedAt")
	local shift = 0
	local value = RunService:IsStudio() and telemetry:FindFirstChild("StudioClockShift")
	if value and value:IsA("NumberValue") and Rules.finite(value.Value) then shift = value.Value end
	return Rules.cycle((Rules.finite(origin) and workspace:GetServerTimeNow() - origin or 0) + shift).phase
end

local function nestSlot(island, index, kind)
	local spec = island.spec
	local offset = index == 1 and 0 or 3
	return { id = spec.id .. ":" .. index, island = spec.id, index = index, kind = kind, tier = spec.tier,
		rewardTier = spec.rewardTier, species = spec.species, x = spec.x + offset, z = spec.z,
		leash = math.max(4, spec.floorRadius - 4) }
end

-- An adult lies on its side asleep (eyes shut) and stands facing out, or toward whoever it chases, when awake.
-- Chase pass (CP-D5): rearing is the swing's wind-up tell: it rises and leans back, its eyes turn red, and the audio
-- client plays a crack on it (an existing catalog id) when its "Swing" attribute turns on.
local ADULT_EYES_SWING = Color3.fromRGB(235, 40, 30)
local function poseAdult(adult, awake, x, z, fx, fz, rearing)
	x, z = x or adult.point.x, z or adult.point.z
	fx, fz = fx or adult.point.faceX, fz or adult.point.faceZ
	local at = Vector3.new(x, relief:heightAt(x, z) + adult.lift, z)
	local frame = CFrame.lookAt(at, at + Vector3.new(fx, 0, fz))
	if not awake then frame = frame * CFrame.new(0, -adult.lift * 0.35, 0) * CFrame.Angles(0, 0, math.rad(70)) end
	if rearing then frame = frame * CFrame.new(0, adult.lift * 0.5, 0) * CFrame.Angles(math.rad(25), 0, 0) end
	adult.model:PivotTo(frame)
	if adult.rearing ~= (rearing == true) then
		adult.rearing = rearing == true
		for _, part in ipairs(adult.model:GetChildren()) do
			if part:IsA("BasePart") and part.Name == "Eye" then
				adult.eyeColor = adult.eyeColor or part.Color
				part.Color = rearing and ADULT_EYES_SWING or adult.eyeColor
			end
		end
		adult.model:SetAttribute("Swing", adult.rearing)
	end
	if adult.awake ~= awake then
		adult.awake = awake
		for _, part in ipairs(adult.model:GetChildren()) do
			if part:IsA("BasePart") and part.Name == "Eye" then part.Transparency = awake and 0 or 1 end
		end
		adult.model:SetAttribute("Awake", awake)
	end
end

local function readoutLevel(meter)
	if meter.state == "Alert" then return "alert" end
	return meter.value >= Island.live.STIR and "stir" or "sleep"
end

local function paintReadout(island)
	local level = readoutLevel(island.meter)
	if island.level == level then return end
	island.level = level
	for _, pip in ipairs(island.pips) do pip.Color = READOUT[level] end
	island.model:SetAttribute("Sleep", level)
end

for _, spec in ipairs(islandLayout.islands) do
	local holder = Instance.new("Model")
	holder.Name = "Island_" .. spec.id
	holder:SetAttribute("IslandId", spec.id)
	local island = { spec = spec, meter = Island.newMeter(spec), adults = {}, pips = {}, model = holder,
		wokeAt = nil, chase = nil, level = nil }
	-- One shared "Zzz" readout over the nest: three pips, pale while asleep, amber when stirring, red when awake.
	for index = 1, 3 do
		local pip = block(holder, "SleepPip", Vector3.new(0.5, 0.5, 0.5) * (0.7 + index * 0.25),
			CFrame.new(spec.x - 1.2 + index * 0.8, relief:heightAt(spec.x, spec.z) + 5 + index * 0.7, spec.z),
			READOUT.sleep, Enum.PartType.Ball)
		pip.Material = Enum.Material.Neon
		table.insert(island.pips, pip)
	end
	holder.Parent = runtime
	for index, point in ipairs(spec.adultPoints) do
		local model = visual("Creature", Vector3.new(point.x, relief:heightAt(point.x, point.z) + MARKER_LIFT, point.z),
			spec.species, 1)
		model.Name = "IslandAdult"
		model:SetAttribute("Island", spec.id)
		model:SetAttribute("Adult", index)
		local adult = { model = model, point = point, lift = model.PrimaryPart.Position.Y - relief:heightAt(point.x, point.z),
			awake = nil }
		CollectionService:AddTag(model, "WildboundIslandAdult")
		poseAdult(adult, false)
		table.insert(island.adults, adult)
	end
	paintReadout(island)
	islands[spec.id] = island
	table.insert(islandList, island)
end
telemetry:SetAttribute("IslandCount", #islandList)
telemetry:SetAttribute("IslandNestsBuilt", islandFolder ~= nil)

local spawnEncounter
-- Random world (RW2): the random spawns. spawnClock owns which graph point holds what and for how long; wildEntries
-- maps a spawn to its encounter. A random spawn pays by its spawn tier (SpawnClock.REWARD), never by an island.
local spawnClock = SpawnClock.new(spawnGraph, Species)
local wildEntries = {}
local RARITY_GLOW = { Comun = Color3.fromRGB(205, 235, 215), Rara = Color3.fromRGB(110, 175, 255),
	Epica = Color3.fromRGB(190, 120, 255), Legendaria = Color3.fromRGB(255, 205, 80) }
-- Nest Heist (NH2): the stolen egg rides in the arms, in front of the chest: welded to the root, massless, never
-- colliding, touched or hit by a ray, so walking, sprinting and jumping are unchanged. One per living character.
-- NH6: the egg in the arms reached a delivery point and was banked: Secured (only by its carrier, once), arms empty.
function Heist.secure(player)
	local egg = EggCarry.carriedBy(eggs, player.UserId)
	if not egg then return nil end
	local ok = EggCarry.secure(eggs, egg.id, player.UserId)
	if ok then
		islandLog("eggSecured", egg.meta.island or "-", player.UserId)
		Heist.syncEggArms(player)
	end
	return ok and egg or nil
end
function Heist.syncEggArms(player)
	local EGG_ARMS = "WildboundEggCarried"
	local record, character = records[player], player.Character
	local egg = EggCarry.carriedBy(eggs, player.UserId)
	local existing = character and character:FindFirstChild(EGG_ARMS)
	if not egg or not record or record.character ~= character or record.defeated then
		if existing then existing:Destroy() end
		return
	end
	if existing and existing:GetAttribute("EggId") == egg.id then return end
	if existing then existing:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local model = Instance.new("Model")
	model.Name = EGG_ARMS
	model:SetAttribute("EggId", egg.id)
	local shell = capsulePart(model, "Egg", Vector3.new(1.2, 1.6, 1.2), Enum.PartType.Ball,
		RARITY_GLOW[egg.meta.rarity] or rgb(Species.NEST_GLOW.egg), Enum.Material.SmoothPlastic)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = shell.Color, 0.6, 8, shell
	weld("EggHold", root, shell, CFrame.new(0, -0.3, -1.4))
	model.PrimaryPart, model.Parent = shell, character
end
local function ensureNests()
	local count = math.max(1, #Players:GetPlayers())
	local phase = islandPhase()
	for _, island in ipairs(islandList) do
		for index = 1, Island.nestCount(island.spec, count) do
			local id = island.spec.id .. ":" .. index
			if nestState[id] == nil then
				spawnEncounter(nestSlot(island, index, Island.rollContent(island.spec, phase, rand) or "Creature"))
			end
		end
	end
end
local function scheduleRespawn(slot)
	if slot.wild then
		-- RW2: a taken random spawn leaves the clock; its tier waits its respawn time.
		wildEntries[slot.spawnId] = nil
		SpawnClock.claim(spawnClock, slot.spawnId, workspace:GetServerTimeNow())
		return
	end
	nestState[slot.id] = "wait"
	nestGen[slot.id] = (nestGen[slot.id] or 0) + 1
	local generation = nestGen[slot.id]
	local island = islands[slot.island]
	local function refill()
		if nestGen[slot.id] ~= generation then return end
		-- Nest Heist (NH8): a nest never changes while its parents are chasing; it refills once the chase is over.
		if island and island.chase then
			task.delay(1, refill)
			return
		end
		nestState[slot.id] = nil
		ensureNests()
	end
	task.delay(island and Island.respawnSeconds(island.spec, slot.kind, #Players:GetPlayers()) or 45, refill)
end

-- EI-2: a caught thief's cria runs home. The nest takes it back at once (a scheduled respawn is cancelled).
-- Fix pass (FP5c): an egg an adult carried home goes back the same way (kind "Egg").
local function returnToNest(island, from, kind)
	kind = kind == "Egg" and "Egg" or "Creature"
	local slot = nestSlot(island, 1, kind)
	local current = nestState[slot.id]
	if current ~= nil and current ~= "wait" then return end
	nestGen[slot.id] = (nestGen[slot.id] or 0) + 1
	nestState[slot.id] = "returning"
	local model = visual(kind, from, island.spec.species, Species.CRIA_SCALE)
	model.Name = "WildboundReturning"
	local goal = Vector3.new(slot.x, relief:heightAt(slot.x, slot.z) + MARKER_LIFT, slot.z)
	local clock = Instance.new("NumberValue")
	clock.Changed:Connect(function(t)
		if model.Parent then model:PivotTo(CFrame.new(from:Lerp(goal, t) + Vector3.new(0, math.sin(t * math.pi) * 3, 0))) end
	end)
	local tween = TweenService:Create(clock, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Value = 1 })
	tween.Completed:Connect(function()
		model:Destroy()
		clock:Destroy()
		if nestState[slot.id] == "returning" then
			nestState[slot.id] = nil
			spawnEncounter(slot)
		end
	end)
	tween:Play()
end

-- RW2: a random spawn as an encounter slot on its graph point (a bough's egg sits `height` above the ground).
local function wildSlot(spawn)
	local point = spawn.point
	return { id = "W:" .. point.id, spawnId = spawn.id, wild = true, kind = spawn.kind, tier = spawn.slotTier,
		rewardTier = spawn.rewardTier, rarity = spawn.tier, species = spawn.species or "Lumipol", x = point.x,
		z = point.z, height = point.height, leash = 3, special = spawn.special }
end
-- Items IT2: set below with the Tótem de la suerte.
local stepLuck, onLuckSpawn
local function applySpawnActions(actions)
	for _, action in ipairs(actions) do
		if action.op == "spawn" and action.spawn.luck and onLuckSpawn then onLuckSpawn(action.spawn) end
		if action.op == "expire" then
			local id = wildEntries[action.spawn.id]
			wildEntries[action.spawn.id] = nil
			local entry = id and entries[id]
			if entry then removeEntry(entry) end
		else
			spawnEncounter(wildSlot(action.spawn))
		end
	end
	local live = 0
	for _ in pairs(wildEntries) do live += 1 end
	telemetry:SetAttribute("WildSpawns", live)
end
-- A random spawn someone is capturing stays past its lifetime.
local function spawnHeld(now)
	local held = {}
	for spawnId, id in pairs(wildEntries) do
		local entry = entries[id]
		-- Nest Heist (NH8): a spawn someone is capturing or holding the prompt of never moves mid-interaction.
		if capture:encounterState(id, now) ~= "Free" or (entry and EggCarry.holding(entry.holders, now)) then
			held[spawnId] = true
		end
	end
	return held
end
local nextSpawnStep = 0
local function stepSpawnClock(now)
	if now < nextSpawnStep then return end
	nextSpawnStep = now + 1
	applySpawnActions(SpawnClock.step(spawnClock, now, rng, spawnHeld(now)))
	if stepLuck then stepLuck(now) end
end

-- Random world (plan Part 6, RW3): the wave clock. The first wave starts when the server opens, with one common egg
-- near camp (the island first-steal hook is unchanged); every later wave rerolls the random spawns. WorldEvent is
-- server-to-client only: the server broadcasts what WaveClock.message builds, and a client message is refused.
local waveClock = WaveClock.new(workspace:GetServerTimeNow())
local worldEvent = Instance.new("RemoteEvent")
worldEvent.Name, worldEvent.Parent = WaveClock.REMOTE, network
worldEvent.OnServerEvent:Connect(function()
	telemetry:SetAttribute("WorldEventRejected", (telemetry:GetAttribute("WorldEventRejected") or 0) + 1)
end)
local currentWave = nil
-- Random world (RW4): 2 or 3 Refugios each wave, from the graph's candidates (never inside the territory): a glowing
-- circle with a totem pole and a "Refugio" sign. Rules.zone reports them safe, so La Silueta's chase ends there and
-- no strike lands; parents never chase into one; stamina comes back twice as fast. Camp and shelter stay.
local refugeFolder = Instance.new("Folder")
refugeFolder.Name, refugeFolder.Parent = "Refuges", runtime
local REFUGE_GLOW = Color3.fromRGB(120, 235, 205)
local TOTEM_COLORS = { Color3.fromRGB(122, 84, 52), Color3.fromRGB(196, 120, 64), Color3.fromRGB(88, 128, 96),
	Color3.fromRGB(150, 70, 60) }
local function buildRefuge(refuge)
	local model = Instance.new("Model")
	model.Name = "Refugio_" .. refuge.id
	model:SetAttribute("RefugeId", refuge.id)
	local ground = relief:heightAt(refuge.x, refuge.z)
	local circle = block(model, "Circle", Vector3.new(0.3, refuge.r * 2, refuge.r * 2),
		CFrame.new(refuge.x, ground + 0.15, refuge.z) * CFrame.Angles(0, 0, math.rad(90)), REFUGE_GLOW, Enum.PartType.Cylinder)
	circle.Material, circle.Transparency = Enum.Material.Neon, 0.65
	local top
	for index, color in ipairs(TOTEM_COLORS) do
		top = block(model, "Totem", Vector3.new(1.8, 1.7, 1.8), CFrame.new(refuge.x, ground + 0.9 + (index - 1) * 1.75, refuge.z)
			* CFrame.Angles(0, index * 0.55, 0), color)
	end
	local crown = block(model, "TotemCrown", Vector3.new(1.2, 1.2, 1.2), top.CFrame * CFrame.new(0, 1.5, 0), REFUGE_GLOW,
		Enum.PartType.Ball)
	crown.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = REFUGE_GLOW, refuge.r + 6, 1.4, crown
	local sign = Instance.new("BillboardGui")
	sign.Name, sign.Size, sign.StudsOffset = "Sign", UDim2.fromOffset(150, 36), Vector3.new(0, 2.5, 0)
	sign.MaxDistance, sign.LightInfluence, sign.AlwaysOnTop = 140, 0, false
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextScaled, label.Font = Text.REFUGE.sign, true, Enum.Font.GothamBold
	label.TextColor3, label.TextStrokeTransparency = REFUGE_GLOW, 0.2
	label.Parent = sign
	sign.Parent = crown
	model.Parent = refugeFolder
end
local function placeRefuges()
	local picked = WaveClock.pickRefuges(spawnGraph.refugeCandidates, rng, Rules.refuges())
	refugeFolder:ClearAllChildren()
	Rules.setRefuges(picked, WaveClock.live.REFUGE_RADIUS)
	for _, refuge in ipairs(Rules.refuges()) do buildRefuge(refuge) end
	telemetry:SetAttribute("Refuges", #Rules.refuges())
end
-- Items and totem (plan Part 4, IT2): the Tótem de la suerte. One standing per player, placed at the player's own
-- feet (never a client position) at least LUCK_CAMP studs from the camp centre, for LUCK_SECONDS. The spawn clock
-- raises the next spawn inside LUCK_RADIUS one tier; with LUCK_LURE it draws one in at once. It is heard like a
-- capture ring when placed and every LUCK_NOISE_EVERY seconds. Session only.
local LUCK_GLOW = Color3.fromRGB(255, 210, 90)
local luckFolder = Instance.new("Folder")
luckFolder.Name, luckFolder.Parent = "LuckTotems", runtime
local luckTotems, luckSerial = {}, 0
local function buildLuck(zone)
	local model = Instance.new("Model")
	model.Name = "TotemSuerte_" .. zone.id
	model:SetAttribute("LuckId", zone.id)
	local ground = relief:heightAt(zone.x, zone.z)
	local ring = block(model, "Reach", Vector3.new(0.2, zone.radius * 2, zone.radius * 2),
		CFrame.new(zone.x, ground + 0.12, zone.z) * CFrame.Angles(0, 0, math.rad(90)), LUCK_GLOW, Enum.PartType.Cylinder)
	ring.Material, ring.Transparency = Enum.Material.Neon, 0.88
	block(model, "Pole", Vector3.new(0.8, 4, 0.8), CFrame.new(zone.x, ground + 2, zone.z), Color3.fromRGB(110, 78, 50))
	local crown = block(model, "Crown", Vector3.new(1.4, 1.4, 1.4), CFrame.new(zone.x, ground + 4.6, zone.z), LUCK_GLOW,
		Enum.PartType.Ball)
	crown.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = LUCK_GLOW, 14, 1.6, crown
	local sign = Instance.new("BillboardGui")
	sign.Name, sign.Size, sign.StudsOffset = "Sign", UDim2.fromOffset(170, 34), Vector3.new(0, 2.2, 0)
	sign.MaxDistance, sign.LightInfluence, sign.AlwaysOnTop = 120, 0, false
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextScaled, label.Font = Text.GEAR.totemSuerte, true, Enum.Font.GothamBold
	label.TextColor3, label.TextStrokeTransparency = LUCK_GLOW, 0.2
	label.Parent = sign
	sign.Parent = crown
	model.Parent = luckFolder
	return model
end
local function removeLuck(player, notice)
	local zone = luckTotems[player]
	if not zone then return end
	luckTotems[player] = nil
	if zone.model then zone.model:Destroy() end
	if notice and player.Parent == Players then send(player, "Luck", true, notice) end
end
stepLuck = function(now)
	for player, zone in pairs(luckTotems) do
		if player.Parent ~= Players then
			removeLuck(player)
		elseif now >= zone.untilAt then
			-- It stands, and is heard, its full time whether or not it already raised a spawn (the owner was told).
			removeLuck(player, not zone.raised and Text.GEAR.luckGone or nil)
		elseif now >= zone.nextNoiseAt then
			zone.nextNoiseAt = now + Gear.live.LUCK_NOISE_EVERY
			noiseEvent:Fire("ring", "Fog", zone.x, zone.z)
		end
	end
	telemetry:SetAttribute("LuckTotems", #luckFolder:GetChildren())
end
onLuckSpawn = function(spawn)
	for player, zone in pairs(luckTotems) do
		if zone.id == spawn.luck then
			zone.raised = true
			telemetry:SetAttribute("LuckRaised", (telemetry:GetAttribute("LuckRaised") or 0) + 1)
			telemetry:SetAttribute("LuckLast", ("%s %s->%s"):format(spawn.point.id, tostring(spawn.pool), spawn.tier))
			send(player, "Luck", true, Text.GEAR.luckRaised:format(Text.RARITY[spawn.tier] or spawn.tier))
		end
	end
end
local function placeLuck(player)
	local root, alive = rootOf(player), context(player)
	if not root or alive ~= true then return reply(player, "PlaceLuck", false, "InvalidContext") end
	if luckTotems[player] then return reply(player, "PlaceLuck", false, "LuckActive") end
	local x, z = root.Position.X, root.Position.Z
	if Rules.distance(x, z, campCenter.Position.X, campCenter.Position.Z) < Gear.live.LUCK_CAMP then
		return reply(player, "PlaceLuck", false, "NearCamp")
	end
	local ok, reason = state:placeLuckTotem(player.UserId, alive)
	if not ok then return reply(player, "PlaceLuck", false, reason) end
	luckSerial += 1
	local now = workspace:GetServerTimeNow()
	local zone = { id = "luck:" .. luckSerial, x = x, z = z, radius = Gear.live.LUCK_RADIUS,
		untilAt = now + Gear.live.LUCK_SECONDS, nextNoiseAt = now }
	SpawnClock.addLuck(spawnClock, zone)
	zone.model = buildLuck(zone)
	luckTotems[player] = zone
	reply(player, "PlaceLuck", true, nil, Text.GEAR.luckPlaced)
	if Gear.live.LUCK_LURE >= 1 then applySpawnActions(SpawnClock.lure(spawnClock, now, rng, zone.id, spawnHeld(now))) end
	stepLuck(now)
end
local function broadcast(kind, data)
	local message = WaveClock.message(kind, data)
	if message then worldEvent:FireAllClients(message) end
	return message
end
local function waveData()
	if not currentWave then return nil end
	return { wave = currentWave.wave, endsAt = WaveClock.endsAt(waveClock) or currentWave.endsAt,
		variant = currentWave.variant, variantChanged = currentWave.variantChanged, board = WaveClock.top(waveClock) }
end
local function startWave(event, now)
	-- RW6: the wave's biome variant (every VARIANT_EVERY_WAVES waves, never by nights): its spawn weights apply before
	-- the reroll; the world clients read the attribute for the fog, the tint and the ambience.
	local variant = WaveClock.variantFor(event.wave)
	local variantChanged = currentWave ~= nil and currentWave.variant ~= variant
	SpawnClock.setWeights(spawnClock, WaveClock.VARIANT_WEIGHTS[variant])
	network:SetAttribute("BiomeVariant", variant)
	if event.wave == 1 then
		local egg = SpawnClock.force(spawnClock, now, rng, { tier = "Comun", kind = "Egg", x = campCenter.Position.X,
			z = campCenter.Position.Z, radius = WaveClock.live.FIRST_EGG_RADIUS })
		if egg then applySpawnActions({ { op = "spawn", spawn = egg } }) end
	else
		applySpawnActions(SpawnClock.reroll(spawnClock, now, rng, spawnHeld(now)))
	end
	placeRefuges()
	currentWave = { wave = event.wave, endsAt = event.endsAt, variant = variant, variantChanged = variantChanged }
	telemetry:SetAttribute("Wave", event.wave)
	broadcast("wave", waveData())
end
-- Random world (RW5): the biome event. One special egg of a Legendaria species at a Legendaria point within
-- EVENT_RADIUS of La Silueta's home, for EVENT_SECONDS, one claimant; every client gets a banner and a distant call.
local currentEvent, eventSpawn = nil, nil
local function startEvent(event, now)
	local spawn = SpawnClock.force(spawnClock, now, rng, { tier = "Legendaria", kind = "Egg", x = Rules.HOME_X,
		z = Rules.HOME_Z, radius = WaveClock.live.EVENT_RADIUS, lifetime = WaveClock.live.EVENT_SECONDS, special = true })
	if not spawn then return end
	eventSpawn = spawn
	applySpawnActions({ { op = "spawn", spawn = spawn } })
	currentEvent = { species = spawn.species or "Tizoncillo", endsAt = event.endsAt }
	telemetry:SetAttribute("BiomeEvent", event.index)
	broadcast("event", { phase = "start", species = currentEvent.species, endsAt = event.endsAt })
end
local function endEvent(event, now)
	if eventSpawn and SpawnClock.get(spawnClock, eventSpawn.id) then
		SpawnClock.claim(spawnClock, eventSpawn.id, now)
		applySpawnActions({ { op = "expire", spawn = eventSpawn } })
	end
	if currentEvent and not event.claimed then broadcast("event", { phase = "end", species = currentEvent.species }) end
	currentEvent, eventSpawn = nil, nil
	telemetry:SetAttribute("BiomeEvent", 0)
end
local function claimBiomeEvent(player)
	if currentEvent and WaveClock.claimEvent(waveClock, player.UserId) then
		broadcast("event", { phase = "claimed", species = currentEvent.species, by = player.DisplayName })
	end
end
local function stepWaves(now)
	for _, event in ipairs(WaveClock.step(waveClock, now)) do
		if event.type == "waveStarted" then startWave(event, now) end
		if event.type == "eventEnded" then endEvent(event, now) end
		if event.type == "eventStarted" then startEvent(event, now) end
	end
end
bankEsencia = function(player, amount)
	if WaveClock.bank(waveClock, player.UserId, player.DisplayName, amount) then
		broadcast("board", { board = WaveClock.top(waveClock) })
	end
end
-- A joining player gets the wave in progress.
local function sendWave(player)
	local message = currentWave and WaveClock.message("wave", waveData())
	if message then worldEvent:FireClient(player, message) end
	local event = currentEvent and WaveClock.message("event", { phase = "start", species = currentEvent.species,
		endsAt = currentEvent.endsAt })
	if event then worldEvent:FireClient(player, event) end
end

-- What every live player looks like to the islands this step, read here only.
local function islandReadings()
	local list = {}
	for player, record in pairs(records) do
		local root = rootOf(player)
		if root and context(player) then
			local snapshot = state:snapshot(player.UserId)
			local velocity = root.AssemblyLinearVelocity
			local look = root.CFrame.LookVector
			local flat = math.sqrt(look.X * look.X + look.Z * look.Z)
			table.insert(list, { player = player, record = record, x = root.Position.X, z = root.Position.Z,
				lookX = flat > 1e-3 and look.X / flat or 0, lookZ = flat > 1e-3 and look.Z / flat or 0,
				sprinting = record.stamina ~= nil and record.stamina.stance == "sprint"
					and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1,
				first = snapshot ~= nil and #snapshot.registered == 0 and snapshot.carrying == nil,
				farol = snapshot ~= nil and Economy.islandLightScale(EconomyConfig, snapshot.upgrades) < 1,
				-- NH3: a stolen egg's island counts like a carried cria's, so its parents chase the egg thief first.
				carrying = snapshot and snapshot.carrying and snapshot.carrying.island
					or (EggCarry.carriedBy(eggs, player.UserId) or { meta = {} }).meta.island })
		end
	end
	return list
end

local function wakeIsland(island, now)
	local spec = island.spec
	island.wokeAt = now
	-- EI-5: the scream is a guardian noise from the island, on the same hearing scale as every other noise.
	noiseEvent:Fire("scream", spec.tier, spec.x, spec.z)
	for _, adult in ipairs(island.adults) do poseAdult(adult, true) end
	local radius = Island.wakeRadius(spec, islandPhase())
	local candidates = {}
	for _, reading in ipairs(islandReadings()) do
		local distance = math.sqrt((reading.x - spec.x) ^ 2 + (reading.z - spec.z) ^ 2)
		if reading.carrying == spec.id then reading.record.criaWokeAt = now end
		if distance <= radius + 20 then send(reading.player, "IslandWoke", false, Text.ISLAND.woke) end
		-- RW4: a thief standing in a Refugio is never chased; NH3: nor anyone inside the camp's safe circle.
		if not Rules.refugeAt(reading.x, reading.z) and not select(2, Rules.zone(reading.x, reading.z)) then
			table.insert(candidates, { key = reading.player, x = reading.x, z = reading.z, carrying = reading.carrying })
		end
	end
	-- EI-2: one adult, the nearest to the thief, gives a short chase inside the island.
	local target = Island.chaseTarget(spec, candidates)
	local root = target and rootOf(target)
	if root and not island.chase then
		local best, bestD
		for _, adult in ipairs(island.adults) do
			local d = (Vector3.new(adult.point.x, 0, adult.point.z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			if not bestD or d < bestD then best, bestD = adult, d end
		end
		if best then
			island.chase = { state = Island.newChase(spec, best.point), adult = best, target = target, startedAt = now }
			send(target, "IslandChase", false, Text.ISLAND.chased)
		end
	end
	islandLog("woke", spec.id, target and target.UserId or 0)
end

-- Chase pass (CP-D5): whether this player has made a paid trip home (one registered creature, banked material or
-- Ember), the same rule La Silueta uses (WildboundFairStrike.lethal). Anything unreadable spares the player.
local islandHitDamage = 0
local probeLethal = {} -- Studio only: the IslandProbe "lethal" op, for the Play check
local probeEggs = 0 -- Studio only: the IslandProbe "egg" op (NB4)
local function lethalPlayer(player)
	if probeLethal[player.UserId] == true then return true end
	local snapshot = state:snapshot(player.UserId)
	if not snapshot then return false end
	local banked = 0
	for _, value in pairs(snapshot.banked or {}) do
		if type(value) == "number" and value > 0 then banked += value end
	end
	return FairStrike.lethal({ registered = #snapshot.registered, banked = banked, ember = snapshot.ember or 0 })
end

-- A landed adult strike (EI-2, chase pass CP-D5): the thief drops this island's cria and it runs home; the hit hurts
-- only in the private damage mode and after a paid trip. A death goes through the ordinary defeat flow (Died).
local function adultHit(island, player)
	local snapshot = state:snapshot(player.UserId)
	local carried = snapshot and snapshot.carrying
	local root = rootOf(player)
	islandLog("hit", island.spec.id, player.UserId)
	local effect = Island.hitEffect({ carrying = carried ~= nil and carried.island == island.spec.id,
		lethal = lethalPlayer(player), damageMode = damageMode })
	local dropped = false
	if effect.drop and state:releaseCarried(player.UserId) then
		dropped = true
		returnToNest(island, root and root.Position or Vector3.new(island.spec.x, 3, island.spec.z), "Creature")
	end
	-- NH5: a landed hit knocks an egg out of the arms, whoever's nest it came from (anyone may pick it up).
	local eggDropped = Heist.dropEgg(player, "Hit") ~= nil
	if effect.damage > 0 then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then humanoid:TakeDamage(effect.damage) end
		islandHitDamage += effect.damage
		telemetry:SetAttribute("IslandHitDamage", islandHitDamage)
	end
	send(player, "IslandCaught", false, dropped and Text.ISLAND.caught or eggDropped and Text.EGG.knocked or Text.ISLAND.hit)
end

-- Fix pass (FP5c): the dropped items live further down (D6); the islands read them to recover eggs.
local drops, removeDrop = {}, nil
local function stepIslands(now, dt)
	if #islandList == 0 then return end
	local clock = islandCycle().clockTime
	local phase = islandPhase()
	local readings = islandReadings()
	local lulled = {}
	for _, session in ipairs(capture:activeSessions()) do
		local entry = entries[session.encounterId]
		if entry and entry.slot.island then lulled[entry.slot.island] = true end
	end
	local C = Island.live
	for _, island in ipairs(islandList) do
		local spec, meter = island.spec, island.meter
		-- Fix pass (FP5d): the deep noon sleep scales every wake input; the clients slow the breathing.
		Island.setSleep(meter, clock)
		for _, adult in ipairs(island.adults) do
			if adult.deep ~= (meter.deep == true) then
				adult.deep = meter.deep == true
				adult.model:SetAttribute("Deep", meter.deep == true)
			end
		end
		local radius = Island.wakeRadius(spec, phase)
		local input = { inside = false, linger = false, sprint = false, light = false, farol = true,
			lulling = lulled[spec.id] == true, phase = phase, firstSteal = false }
		local insidePlayers = {}
		for _, reading in ipairs(readings) do
			local away = math.sqrt((reading.x - spec.x) ^ 2 + (reading.z - spec.z) ^ 2)
			-- K3: walking onto the island floor counts as reaching it (once per island per session).
			if away <= spec.floorRadius then analytics:islandReached(reading.player.UserId, spec.id) end
			if away <= radius then
				input.inside = true
				table.insert(insidePlayers, reading.player)
				if reading.sprinting then input.sprint = true end
				if reading.first then input.firstSteal = true end
				for _, adult in ipairs(island.adults) do
					local ax, az = adult.point.x - reading.x, adult.point.z - reading.z
					local d = math.sqrt(ax * ax + az * az)
					if d <= C.LINGER_RANGE then input.linger = true end
					-- The light on a sleeping face: the server's own forward vector, never a camera or gaze input.
					if d > 0.1 and d <= C.LIGHT_RANGE and (reading.lookX * ax + reading.lookZ * az) / d >= C.LIGHT_DOT then
						input.light = true
						if not reading.farol then input.farol = false end
					end
				end
			end
		end
		if not input.light then input.farol = false end
		local out = Island.step(meter, dt, input)
		if out.stirred then
			for _, player in ipairs(insidePlayers) do send(player, "IslandStir", false, Text.ISLAND.stir) end
		end
		if out.woke then wakeIsland(island, now) end
		if out.settled and not island.chase then
			for _, adult in ipairs(island.adults) do poseAdult(adult, false) end
		end
		paintReadout(island)
		-- Eggs have no brain: their prompt follows the nest alone.
		for _, entry in pairs(entries) do
			if entry.slot.island == spec.id and not entry.brain then
				local open = Island.nestOpen(meter)
				if entry.prompt.Enabled ~= open then entry.prompt.Enabled = open end
			end
		end
		local chase = island.chase
		if chase then
			local target = chase.target
			local root = target.Parent == Players and rootOf(target) or nil
			-- RW4: a thief who reaches a Refugio is out of reach; the adult gives up at once and walks home. NH3: the camp's
			-- safe circle ends the chase too; an egg in the arms stays there until it is delivered.
			local sheltered = root ~= nil and (Rules.refugeAt(root.Position.X, root.Position.Z) ~= nil
				or select(2, Rules.zone(root.Position.X, root.Position.Z)) == true)
			if sheltered and chase.state.mode ~= "Return" and chase.state.mode ~= "Home" then chase.state.left = 0 end
			local live = root ~= nil and context(target) == true and not sheltered
			local event = Island.chaseStep(chase.state, dt, live and root.Position.X or nil, live and root.Position.Z or nil)
			local c = chase.state
			poseAdult(chase.adult, true, c.x, c.z, c.fx, c.fz, c.mode == "Strike" or c.mode == "Pounce")
			if event == "WindUp" then send(target, "IslandStrike", false, Text.ISLAND.strike) end
			-- NH3 (was the FP5b pounce): the charge's 0.8 s tell is the same rearing pose and crack as a swing, plus a
			-- warning; the dash hits like a swing (below); a miss leaves the adult exposed for a moment.
			if event == "PounceWindUp" then send(target, "IslandPounce", false, Text.ISLAND.pounce) end
			if event == "Charge" then islandLog("charge", spec.id, target.UserId) end
			if event == "ChargeMissed" then
				islandLog("chargeMissed", spec.id, target.UserId)
				send(target, "IslandExposed", false, Text.ISLAND.exposed)
			end
			if event == "Hit" and live then adultHit(island, target) end
			if event == "Missed" then islandLog("missed", spec.id, target.UserId) end
			if event == "GaveUp" then islandLog("gaveUp", spec.id, target.UserId) end
			if c.mode == "Home" then
				island.chase = nil
				poseAdult(chase.adult, meter.state == "Alert")
				if meter.state ~= "Alert" then
					for _, adult in ipairs(island.adults) do poseAdult(adult, false) end
				end
			end
		end
		-- Fix pass (FP5c): an egg dropped inside the leash is fetched by the nearest adult and carried to the nest at
		-- return speed; its thief loses it when the adult picks it up. Never during a chase.
		if not island.chase and not island.carry then
			local eggDrops = {}
			for uid, drop in pairs(drops) do
				if drop.kind == "Egg" and not drop.claimed and drop.model.Parent then
					local at = drop.model:GetPivot().Position
					table.insert(eggDrops, { key = uid, kind = "Egg", x = at.X, z = at.Z })
				end
			end
			-- NH5: an egg knocked out of the arms lies in EggCarry (keyed "egg:<id>"); the parents fetch those too.
			for id, egg in pairs(eggs.eggs) do
				if egg.state == "Dropped" and not egg.fetching and egg.body and egg.body.Parent then
					table.insert(eggDrops, { key = "egg:" .. id, kind = "Egg", x = egg.body.Position.X, z = egg.body.Position.Z })
				end
			end
			local target = Island.recoverTarget(spec, eggDrops)
			if target then
				local best, bestD
				for _, adult in ipairs(island.adults) do
					local d = math.sqrt((adult.point.x - target.x) ^ 2 + (adult.point.z - target.z) ^ 2)
					if not bestD or d < bestD then best, bestD = adult, d end
				end
				if best then
					local loose = target.key:sub(1, 4) == "egg:" and EggCarry.get(eggs, target.key:sub(5)) or nil
					if loose then loose.fetching = true else drops[target.key].claimed = true end
					island.carry = { state = Island.newCarry(spec, best.point, target), adult = best, uid = target.key }
					islandLog("eggFetch", spec.id, 0)
				end
			end
		end
		local carry = island.carry
		if carry then
			local event = Island.carryStep(island.carry.state, dt)
			local c = carry.state
			poseAdult(carry.adult, true, c.x, c.z, c.fx, c.fz)
			local loose = carry.uid:sub(1, 4) == "egg:" and EggCarry.get(eggs, carry.uid:sub(5)) or nil
			if event == "Picked" and loose then
				-- NH5: someone may have picked it up on the way; then the adult walks home empty-handed.
				if loose.state == "Dropped" and EggCarry.recover(eggs, loose.id) then
					Heist.clearDroppedEgg(loose)
					carry.has = true
					local owner = playersByUserId[loose.lastCarrier]
					if owner then send(owner, "DropLost", false, Text.ISLAND.eggRecovered) end
				end
			elseif event == "Picked" then
				local drop = drops[carry.uid]
				if drop then
					local owner = drop.owner
					removeDrop(carry.uid)
					carry.has = true
					if state:loseDropped(owner.UserId, carry.uid) and owner.Parent == Players then
						send(owner, "DropLost", false, Text.ISLAND.eggRecovered)
					end
				end
			elseif event == "Home" or c.mode == "Home" then
				if carry.has then
					returnToNest(island, Vector3.new(c.x, relief:heightAt(c.x, c.z) + MARKER_LIFT, c.z), "Egg")
					islandLog("eggHome", spec.id, 0)
				end
				island.carry = nil
				poseAdult(carry.adult, meter.state == "Alert")
			end
		end
		telemetry:SetAttribute("Island_" .. spec.id, ("%s %.1f%s"):format(meter.state, meter.value,
			chase and (" chase " .. chase.state.mode) or ""))
	end
end


local function startCapture(player, entry)
	local record = records[player]
	if not record then return end
	local now = workspace:GetServerTimeNow()
	local alive, distance = context(player, entry.body)
	local root = rootOf(player)
	local snapshot = state:snapshot(player.UserId)
	if not alive or not root or not snapshot then
		send(player, "Capture", false, captureNotice("InvalidContext"))
		return
	end
	local island = entry.slot.island and islands[entry.slot.island]
	if island and not Island.nestOpen(island.meter) then
		send(player, "Capture", false, Text.ISLAND.guarded)
		return
	end
	local bag, collection = state:captureRoom(player.UserId)
	local skills = Economy.skillEffects(EconomyConfig, snapshot.skills)
	local position, lumipol = root.Position, entry.body.Position
	local ok, result = capture:begin({
		playerKey = player.UserId, encounterId = entry.id, dir = rng:NextInteger(0, 1) * 2 - 1,
		lumipolX = lumipol.X, lumipolZ = lumipol.Z, now = now, alive = alive, life = record.generation,
		distance = distance, x = position.X, y = position.Y, z = position.Z,
		encounterStatus = state:encounterStatus(entry.id) or "Gone",
		slotRefusal = Wild.slotRefusal(entry.slot.tier, snapshot), bagRoom = bag, collectionRoom = collection,
		-- Delivery A: a scared Lumipol refuses; the seal band is wide on Safe slots and placed by a server roll.
		wary = Wild.wary(entry.brain), tier = entry.slot.tier, sealRoll = rng:NextNumber(),
		-- H2: this player's own capture skills; the rule clamps them.
		calmRequired = skills.calmRequired, retryCooldown = skills.retryCooldown,
		-- NS7: the worn glove's Calma; the rule floors the meter (CALM_MIN). Gloves never widen the ring.
		calmRate = Gear.calmRate(snapshot.glove), ringBonus = 0,
	})
	if not ok then
		counters.rejected += 1
		send(player, "Capture", false, island and result == "FirstCaptureOnly" and Text.ISLAND.firstOnly
			or captureNotice(result))
		return
	end
	counters.started += 1
	entry.prompt.Enabled = false
	Wild.reserve(entry.brain, position.X, position.Z)
	local mode, guardianDistance = guardianReading(player, position)
	sessionMeta[result.token] = { startedAt = now, slot = entry.slot.id, tier = entry.slot.tier,
		inTerritory = Rules.inTerritory(position.X, position.Z), guardianMode = mode,
		guardianDistance = guardianDistance and math.floor(guardianDistance * 10 + 0.5) / 10 or nil,
		x = lumipol.X, z = lumipol.Z }
	captureRemote:FireClient(player, Capture.toSnapshot(result))
	noiseEvent:Fire("ring", entry.slot.tier or "Fog", lumipol.X, lumipol.Z)
end

-- Every ending passes through here: grant, spook or release, the final push, and the log.
handleEnding = function(out)
	local entry = entries[out.encounterId]
	local player = playersByUserId[out.playerKey]
	local now = workspace:GetServerTimeNow()
	local notice, granted = Text.CAPTURE_NOTICES[out.reason] or "", false
	if out.grant then
		local alive = player ~= nil and context(player) == true
		-- I5: an island cria rides with its species and island, and pays by its island's reward tier.
		local slot = entry and entry.slot
		-- Fear pass (FA2): read before the bag changes; afterwards the thief carries the cria.
		local before = slot and slot.island and state:snapshot(out.playerKey) or nil
		local firstSteal = before ~= nil and #before.registered == 0 and before.carrying == nil
		local ok, reason = state:completeCapture(out.playerKey, out.encounterId, alive,
			slot and (slot.rewardTier or slot.tier) or "Fog",
			slot and (slot.island or slot.wild) and { species = slot.species, island = slot.island } or nil)
		granted = ok
		if ok then
			counters.completed += 1
			if entry and entry.brain then Wild.capture(entry.brain) end
			-- K3: the first cria taken from a nest is the hook's first beat.
			if slot and slot.island then analytics:stole(out.playerKey) end
			-- Fear pass (FA2): lifting the cria is loud; a stirred island wakes and its parents chase the thief.
			local island = slot and slot.island and islands[slot.island]
			if island and Island.event(island.meter, "CriaTaken", { firstSteal = firstSteal }).woke then
				wakeIsland(island, now)
			end
		else
			-- The rule said finished but the bag disagreed. Nothing is granted and the Lumipol still goes.
			counters.grantRefused += 1
			notice = captureNotice(reason)
		end
		if entry then
			removeEntry(entry, now)
			scheduleRespawn(entry.slot)
		end
	elseif entry and entry.brain then
		-- I2: a capture mistake disturbs the island's sleepers.
		local island = entry.slot.island and islands[entry.slot.island]
		local mistake = out.reason == "LeftRing" and "LeftRing" or out.reason == "SealMissed" and "SealMissed"
			or (out.reason == "TimedOut" or out.reason == "TooFar") and "Failed" or nil
		if island and mistake then
			local snapshot = state:snapshot(out.playerKey)
			local result = Island.event(island.meter, mistake, { firstSteal = snapshot ~= nil
				and #snapshot.registered == 0 and snapshot.carrying == nil })
			if result.woke then wakeIsland(island, now) end
		end
		if out.spook then
			local threat = player and rootOf(player)
			Wild.spook(entry.brain, threat and threat.Position.X, threat and threat.Position.Z, rand)
		else
			Wild.release(entry.brain)
		end
	end
	if out.phase == "Failed" then counters.failed += 1 elseif out.phase == "Cancelled" then counters.cancelled += 1 end
	local meta = sessionMeta[out.token]
	sessionMeta[out.token] = nil
	if meta then
		table.insert(captureLog, { slot = meta.slot, tier = meta.tier, reason = out.reason, granted = granted,
			seconds = math.floor((now - meta.startedAt) * 100 + 0.5) / 100, calm = math.floor(out.calm * 100 + 0.5) / 100,
			inTerritory = meta.inTerritory, guardianMode = meta.guardianMode, guardianDistance = meta.guardianDistance })
		while #captureLog > 40 do table.remove(captureLog, 1) end
		analytics:capture(out.playerKey, out.reason, Analytics.ZONE_OF_TIER[meta.tier], now - meta.startedAt, granted)
	end
	if player and records[player] and player.Parent == Players then
		local snapshot = Capture.toSnapshot(out)
		if snapshot then
			snapshot.notice = notice
			captureRemote:FireClient(player, snapshot)
		end
		if notice ~= "" then send(player, "Capture", granted, notice) end
	end
	publishTelemetry()
end

spawnEncounter = function(slot)
	if not slot or runtime.Parent ~= map then return end
	serial += 1
	local id = slot.kind .. ":" .. serial
	if not state:registerEncounter(id, slot.kind) then return end
	local model, body = visual(slot.kind, Vector3.new(slot.x, groundAt(slot.x, slot.z) + (slot.height or 0), slot.z),
		slot.species, (slot.island or slot.wild) and slot.kind == "Creature" and Species.CRIA_SCALE or nil)
	model:SetAttribute("EncounterId", id)
	model:SetAttribute("Slot", slot.id)
	local isEgg = slot.kind == "Egg"
	-- A wandering creature keeps this lift over whatever ground it walks onto.
	local entry = { id = id, slot = slot, model = model, body = body, lift = body.Position.Y - relief:heightAt(slot.x, slot.z) }
	-- A creature is calmed with a tap, so its prompt has no hold. Eggs keep the short hold.
	-- I3: the take prompts; an egg has a hold and no ring. NH1: a normal egg's hold is the short steal hold.
	local speciesName = Text.CARD.species[slot.species or "Lumipol"] or slot.species or Text.PROMPTS.lumipol
	-- RW2: the rarity tier (a random spawn's own, an island nest's from its species) on the prompt and over the glow.
	local rarity = slot.rarity or Species.look(slot.species).rarity
	local rarityLabel = rarity and Text.RARITY[rarity]
	if rarityLabel then
		speciesName = (slot.special and Text.EVENT.prompt .. ": " or "") .. speciesName .. " · " .. rarityLabel
		model:SetAttribute("Rarity", rarity)
		local tag = Instance.new("BillboardGui")
		tag.Name, tag.Size, tag.StudsOffset = "RarityTag", UDim2.fromOffset(110, 26), Vector3.new(0, 3, 0)
		tag.MaxDistance, tag.LightInfluence, tag.AlwaysOnTop = 45, 0, false
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextScaled, label.Font = rarityLabel, true, Enum.Font.GothamBold
		label.TextColor3, label.TextStrokeTransparency = RARITY_GLOW[rarity] or Color3.new(1, 1, 1), 0.3
		label.Parent = tag
		tag.Parent = body
		local light = body:FindFirstChildOfClass("PointLight")
		if light and slot.wild then light.Color = RARITY_GLOW[rarity] or light.Color end
	end
	entry.prompt = prompt(body, isEgg and Text.ISLAND.takeEgg or Text.ISLAND.takeCria, speciesName, 10,
		isEgg and EggCarry.holdFor(rarity, slot.special) or 0)
	-- NS7: each client shortens its own copy of a steal hold by its glove's "Robo rápido" (WildboundGloveSteal).
	if isEgg then entry.prompt:SetAttribute("WildboundStealHold", entry.prompt.HoldDuration) end
	-- NH8: who is holding this prompt right now (the spawn clock holds the spawn meanwhile). Gone with the model.
	entry.holders = {}
	-- HB-T7: and each player's own hold as the server saw it (when it began, when it was released), for the steal check.
	entry.holdStarts = {}
	entry.prompt.PromptButtonHoldBegan:Connect(function(player)
		entry.holders[player] = workspace:GetServerTimeNow()
		entry.holdStarts[player] = { at = workspace:GetServerTimeNow() }
	end)
	entry.prompt.PromptButtonHoldEnded:Connect(function(player)
		entry.holders[player] = nil
		local hold = entry.holdStarts[player]
		if hold and hold.ended == nil then hold.ended = workspace:GetServerTimeNow() end
	end)
	if not isEgg then
		local cover = table.clone(coverCandidates)
		local island = slot.island and islands[slot.island]
		-- A failed lull sends the cria behind the nearest adult (A1 flee and hide, the adult as cover).
		if island then
			for _, adult in ipairs(island.adults) do table.insert(cover, { x = adult.point.x, z = adult.point.z, r = 1.5 }) end
		end
		entry.brain = Wild.newBrain(slot, rand, { cover = cover, leash = slot.leash })
		model:SetAttribute("Mode", entry.brain.mode)
	end
	model:SetAttribute("Island", slot.island)
	model:SetAttribute("Species", slot.species)
	entries[id] = entry
	-- NH2: every egg has an EggCarry record from the moment it lies in its nest (InNest), keyed by its encounter id.
	if isEgg then
		EggCarry.add(eggs, id, { species = slot.species, rarity = rarity, island = slot.island, tier = slot.rewardTier,
			special = slot.special == true })
	end
	if slot.wild then wildEntries[slot.spawnId] = id else nestState[slot.id] = id end
	-- NH5: one path for the prompt and the Studio-only HeistProbe.
	entry.trigger = function(player)
		if entries[id] ~= entry or model.Parent ~= runtime or not validPrompt(entry.prompt, body) then return end
		if isEgg then
			if not allowed(player, "Pickup") then return end
			-- HB-T7: the hold is measured here, never trusted from the client: this player's effective hold (the glove's
			-- Robo rápido this server wrote, never under the floor), less a small latency allowance.
			local need = Gear.stealHold(entry.prompt:GetAttribute("WildboundStealHold"),
				{ stats = { steal = player:GetAttribute("WildboundGloveSteal") or 0 } }, Gear.CONSTANTS.STEAL_FLOOR)
			if not EggCarry.holdComplete(entry.holdStarts[player], workspace:GetServerTimeNow(), need) then
				send(player, "Pickup", false, Text.EGG.holdLonger)
				return
			end
			entry.holdStarts[player] = nil
			local island = slot.island and islands[slot.island]
			if island and not Island.nestOpen(island.meter) then
				send(player, "Pickup", false, Text.ISLAND.guarded)
				return
			end
			-- NH2: one egg in the arms at a time, and only an egg still in its nest.
			local free, why = EggCarry.canSteal(eggs, id, player.UserId)
			if not free then
				if why == "AlreadyCarrying" then send(player, "Pickup", false, Text.EGG.already) end
				return
			end
			local alive, distance = context(player, body)
			local ok, reason = state:pickup(player.UserId, id, alive, distance, { species = slot.species or "Lumipol",
				tier = slot.rewardTier or "Territory", island = slot.island, arms = true })
			if ok then
				EggCarry.steal(eggs, id, player.UserId, reason)
				Heist.syncEggArms(player)
				analytics:gain(player.UserId, "pickup")
				removeEntry(entry)
				scheduleRespawn(slot)
				-- RW5: the biome event egg has one claimant.
				if slot.special then claimBiomeEvent(player) end
				-- I2: rolling an egg out of the nest is noisy.
				if island and Island.event(island.meter, "EggTaken").woke then wakeIsland(island, workspace:GetServerTimeNow()) end
			end
			reply(player, "Pickup", ok, reason, Text.EGG.stolen)
		else
			if not allowed(player, "CaptureStart") then return end
			startCapture(player, entry)
		end
	end
	entry.connection = entry.prompt.Triggered:Connect(entry.trigger)
end

-- Silueta's resolved strike ends the target's capture, whether or not damage is on (the world script fires it).
strikeEvent.Event:Connect(function(player)
	if typeof(player) == "Instance" and player:IsA("Player") and records[player] then
		capture:notifyStruck(player.UserId)
		analytics:noteStrike(player.UserId)
	end
end)

-- M5.6 bond: only the world script fires this, and only for a pulse that revealed Silueta to a player in the
-- fog. The state decides whether it counts (equipped companion, open expedition, caps).
pulseHit.Event:Connect(function(player, inFog)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not records[player] or inFog ~= true then return end
	local ok, xp = state:bondEvent(player.UserId, "pulseRevealInFog", (context(player)))
	if ok then send(player, "Bond", true, notices.bond:format(xp)) end
end)

-- Dropped items (D6, M4.6). Each lies near its owner for 30 s; only the owner can pick it up.
local DROP_SECONDS = 30
-- `drops` and `removeDrop` are declared above stepIslands (fix pass FP5c).
function removeDrop(uid)
	local drop = drops[uid]
	if not drop then return nil end
	drops[uid] = nil
	drop.prompt.Enabled = false
	drop.connection:Disconnect()
	drop.model:Destroy()
	return drop
end
-- The owner was defeated, replaced or left: the world copies go. State already moved or lost the entries.
local function removeDropsOf(player)
	for uid, drop in pairs(drops) do
		if drop.owner == player then removeDrop(uid) end
	end
end
local function itemName(entry)
	return entry.kind == "Egg" and notices.itemEgg or entry.kind == "Nightbloom" and notices.itemBundle or notices.itemCreature
end
local function spawnDrop(player, entry, towardX, towardZ)
	local root = rootOf(player)
	if not root then return end
	local from = Vector3.new(root.Position.X, 0, root.Position.Z)
	local toward = Vector3.new(towardX, 0, towardZ) - from
	local offset = toward.Magnitude > 0.01 and toward.Unit * 4 or Vector3.new(0, 0, 4)
	-- Clamped to the fog forest, where every strike happens.
	local x = math.clamp(from.X + offset.X, -45, 165)
	local z = math.clamp(from.Z + offset.Z, -165, 35)
	local model, body = visual(entry.kind, Vector3.new(x, groundAt(x, z), z))
	model.Name = "DroppedItem"
	model:SetAttribute("OwnerUserId", player.UserId)
	local drop = { owner = player, uid = entry.uid, model = model, kind = entry.kind }
	drop.prompt = prompt(body, notices.pickUp, notices.droppedObject:format(itemName(entry)), 10, 0.25)
	drop.connection = drop.prompt.Triggered:Connect(function(who)
		if drops[entry.uid] ~= drop or not validPrompt(drop.prompt, body) then return end
		if who ~= drop.owner then
			if allowed(who, "DropRefused") then send(who, "Pickup", false, notices.notYours) end
			return
		end
		if not allowed(who, "Reclaim") then return end
		local alive, distance = context(who, body)
		local ok, reason = state:reclaimDropped(who.UserId, entry.uid, alive, distance)
		if ok then removeDrop(entry.uid) end
		reply(who, "Reclaim", ok, reason, notices.reclaimed:format(itemName(entry)))
	end)
	drops[entry.uid] = drop
	task.delay(DROP_SECONDS, function()
		if drops[entry.uid] ~= drop then return end
		removeDrop(entry.uid)
		local ok = state:loseDropped(player.UserId, entry.uid)
		if ok then send(player, "DropLost", false, notices.dropLost:format(itemName(entry))) end
	end)
end

-- Server-to-server only (the Eligibility pattern): the world script calls this for a real first strike.
-- It drops one bag item once per attack id and returns what dropped, or nil. The capture ends through
-- CaptureStrike, which the world fires for the same strike.
local strikeEffect = Instance.new("BindableFunction")
strikeEffect.Name = "StrikeEffect"
strikeEffect.OnInvoke = function(player, attackId, towardX, towardZ)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not records[player] or type(attackId) ~= "string"
		or not Rules.finite(towardX) or not Rules.finite(towardZ) then return nil end
	local ok, entry = state:dropForStrike(player.UserId, attackId)
	if not ok then return nil end
	-- NH5: an egg in the arms is knocked loose for anyone; any other item lies for its owner (D6).
	if entry and entry.inArms then Heist.dropEgg(player, "Strike", entry)
	elseif entry then spawnDrop(player, entry, towardX, towardZ) end
	send(player, "Strike", true, "")
	return entry and { kind = entry.kind, species = entry.species } or nil
end
strikeEffect.Parent = network

-- Nest Heist phase 4a (NB5): a beast's landed hit, decided by the beast script (server to server only, the StrikeEffect
-- pattern). An egg in the arms falls through the one drop path, as for a parent's hit; health drops only in the private
-- damage mode and after a paid trip (the parents' rule), so a defeat runs the ordinary Died flow. Kept in a do block:
-- this script is at Luau's 200-local limit (NH-W13).
do
	local beastHit = Instance.new("BindableFunction")
	beastHit.Name = "BeastHit"
	beastHit.OnInvoke = function(player, beast, damage)
		if typeof(player) ~= "Instance" or not player:IsA("Player") or not records[player] or type(beast) ~= "string"
			or not Rules.finite(damage) or damage < 0 or damage > 100 then return nil end
		local eggDropped = Heist.dropEgg(player, "Hit") ~= nil
		local hurt = 0
		if damageMode == "private" and lethalPlayer(player) then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(damage)
				hurt = damage
			end
		end
		telemetry:SetAttribute("BeastHitDamage", (telemetry:GetAttribute("BeastHitDamage") or 0) + hurt)
		local words = Text.BEAST[beast]
		send(player, "BeastHit", false, eggDropped and Text.EGG.knocked or words and words.hit or Text.BEAST.hit)
		return { eggDropped = eggDropped, damage = hurt }
	end
	beastHit.Parent = network
end

-- Nest Heist (NH5): drop and pickup. A dropped egg lands on the ground under its carrier (a downward ray that ignores
-- characters and runtime visuals, else the relief), anchored and never colliding, so it neither falls through nor flies
-- off. After PICKUP_DELAY anyone may pick it up with a PICKUP_HOLD hold: the first valid request wins (EggCarry and
-- the state change with no yield in between) and nobody has priority. Abandoned for DROP_SECONDS it fades and is gone.
Heist.landParams = RaycastParams.new()
Heist.landParams.FilterType = Enum.RaycastFilterType.Exclude
function Heist.landingAt(x, y, z)
	local exclude = { runtime }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then table.insert(exclude, other.Character) end
	end
	Heist.landParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, y + 1, z), Vector3.new(0, -(EggCarry.live.LAND_DEPTH + 1), 0), Heist.landParams)
	return EggCarry.landingY(y, hit and hit.Position.Y, relief:heightAt(x, z))
end
function Heist.clearDroppedEgg(egg)
	if egg.connection then egg.connection:Disconnect() end
	if egg.model then egg.model:Destroy() end
	egg.model, egg.body, egg.prompt, egg.connection = nil, nil, nil, nil
end
function Heist.pickupEgg(player, egg)
	if not allowed(player, "EggPickup") or not egg.body then return end
	local now = workspace:GetServerTimeNow()
	local free, why = EggCarry.canPickup(eggs, egg.id, player.UserId, now)
	if not free then
		if why == "AlreadyCarrying" then send(player, "EggPickup", false, Text.EGG.already) end
		return
	end
	local alive, distance = context(player, egg.body)
	if distance > EggCarry.live.PICKUP_RANGE then return end
	local ok, reason = state:takeEgg(player.UserId, egg.entry, alive, distance)
	if not ok then
		reply(player, "EggPickup", false, reason)
		return
	end
	local previous = egg.lastCarrier
	EggCarry.pickup(eggs, egg.id, player.UserId, now, reason)
	Heist.clearDroppedEgg(egg)
	Heist.syncEggArms(player)
	reply(player, "EggPickup", true, nil, Text.EGG.picked)
	local before = playersByUserId[previous]
	if before and before ~= player then send(before, "EggTaken", false, Text.EGG.taken) end
	-- The egg's parents turn on the new carrier only if the chasing adult can perceive them.
	local island = egg.meta.island and islands[egg.meta.island]
	local chase = island and island.chase
	local root = rootOf(player)
	if chase and root and chase.target ~= player and Island.perceives(chase.state, root.Position.X, root.Position.Z) then
		chase.target = player
		islandLog("retarget", island.spec.id, player.UserId)
		send(player, "IslandChase", false, Text.ISLAND.chased)
	end
end
-- reason: "Death", "Hit", "Strike", "Leave" (later "Bat"). loose: the state entry when the state already let it go (a
-- strike). from: the character it falls from when it is no longer player.Character (NH7, a replaced character).
-- Returns the egg, or nil when nothing was carried or a safe zone keeps it in the arms.
function Heist.dropEgg(player, reason, loose, from)
	local egg = EggCarry.carriedBy(eggs, player.UserId)
	if not egg then return nil end
	local character = from or player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = workspace:GetServerTimeNow()
	if not root or not root:IsA("BasePart") then
		-- No body left to drop it from: the egg is lost at once (it fades on the next step).
		if EggCarry.drop(eggs, player.UserId, reason, now) then
			egg.expireAt = now
			if not loose then state:dropEgg(player.UserId) end
		end
		return nil
	end
	local at = root.Position
	local _, safe = Rules.zone(at.X, at.Z)
	if not EggCarry.drop(eggs, player.UserId, reason, now, { safe = safe }) then
		-- A safe zone keeps the egg in the arms; a strike's state change is undone.
		if loose then state:takeEgg(player.UserId, loose, true, 0) end
		return nil
	end
	local entry = loose
	if not entry then
		local ok, detached = state:dropEgg(player.UserId)
		entry = ok and detached or nil
	end
	egg.entry = entry or { uid = "loose:" .. egg.id, kind = "Egg", species = egg.meta.species or "Lumipol",
		riskTier = egg.meta.tier or "Territory", island = egg.meta.island }
	-- A little behind the carrier, so a fleeing thief leaves it in their wake.
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, 1)
	local x, z = at.X - flat.X * 2, at.Z - flat.Z * 2
	local y = Heist.landingAt(x, at.Y, z)
	-- visual() lifts an egg 2 studs over its point and the egg is 2.8 tall: its bottom rests on the ground.
	local model, body = visual("Egg", Vector3.new(x, y - 0.6, z), egg.meta.species)
	model.Name = "WildboundDroppedEgg"
	model:SetAttribute("EggId", egg.id)
	local speciesName = Text.CARD.species[egg.meta.species or "Lumipol"] or egg.meta.species or Text.PROMPTS.lumipol
	local pick = prompt(body, Text.EGG.pickUp, speciesName, EggCarry.live.PICKUP_RANGE, EggCarry.live.PICKUP_HOLD)
	pick.Enabled = false
	egg.model, egg.body, egg.prompt = model, body, pick
	egg.connection = pick.Triggered:Connect(function(who)
		if EggCarry.get(eggs, egg.id) ~= egg or egg.prompt ~= pick or not validPrompt(pick, body) then return end
		Heist.pickupEgg(who, egg)
	end)
	islandLog("eggDropped", egg.meta.island or "-", player.UserId)
	Heist.syncEggArms(player)
	applyCarry(player)
	return egg
end
function Heist.stepEggs(now)
	for _, action in ipairs(EggCarry.step(eggs, now)) do
		local egg = action.egg
		if action.op == "open" and egg.prompt then
			egg.prompt.Enabled = true
		elseif action.op == "despawn" then
			if egg.prompt then egg.prompt.Enabled = false end
			if egg.body then egg.body.Transparency = 0.6 end
			local owner = playersByUserId[egg.lastCarrier]
			if owner then send(owner, "EggGone", false, Text.EGG.gone) end
		elseif action.op == "remove" then
			Heist.clearDroppedEgg(egg)
		end
	end
	telemetry:SetAttribute("EggsCarried", EggCarry.count(eggs, "Carried"))
	telemetry:SetAttribute("EggsDropped", EggCarry.count(eggs, "Dropped"))
end

-- Gather seam (M5.3 builds the world nodes in part 2). The node script spawns, claims and retires nodes
-- through these server-only bindables; this script owns state, the seeded spawn generator and replies.
-- The seed is logged only to ServerStorage, so no client can predict a node.
local spawnSeed = Random.new():NextInteger(1, 2147483646)
telemetry:SetAttribute("SpawnSeed", spawnSeed)
local spawnRng = Random.new(spawnSeed)
local gatherNodes, gatherSerial = {}, 0
local MATERIAL_NAMES = { fogbark = "Fogbark", glowmoss = "Glowmoss", nightbloom = "Nightbloom" }
local function worldClock()
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local origin = world and world:GetAttribute("CycleStartedAt")
	local phase = Rules.cycle(Rules.finite(origin) and workspace:GetServerTimeNow() - origin or 0).phase
	return phase, world ~= nil and world:GetAttribute("NightRewardsEnabled") == true
end
local function gatherNotice(receipt)
	local name = MATERIAL_NAMES[receipt.material] or receipt.material
	if receipt.wasted > 0 then
		return notices.gatheredFull:format(receipt.taken, name, receipt.wasted)
	end
	return notices.gathered:format(receipt.taken, name)
end
local gatherSpawn = Instance.new("BindableFunction")
gatherSpawn.Name = "GatherSpawn"
gatherSpawn.OnInvoke = function(slotId)
	local slot = type(slotId) == "string" and Spawn.slot(EconomyConfig, slotId) or nil
	if not slot then return nil end
	local phase, nightRewards = worldClock()
	local node = Spawn.rollNode(EconomyConfig, slot, phase, spawnRng, { nightRewards = nightRewards })
	if not node then return nil end
	gatherSerial += 1
	local id = "Gather:" .. gatherSerial
	if not state:registerEncounter(id, "Gather") then return nil end
	gatherNodes[id] = { slot = slot, material = node.material, quantity = node.quantity }
	return { id = id, slotId = slot.id, zone = slot.zone, heart = slot.heart == true, x = slot.x, z = slot.z,
		material = node.material, quantity = node.quantity, phase = phase,
		hold = EconomyConfig.gather.holdSeconds[slot.heart and "heart" or slot.zone] }
end
gatherSpawn.Parent = network
local gatherClaim = Instance.new("BindableFunction")
gatherClaim.Name = "GatherClaim"
gatherClaim.OnInvoke = function(player, nodeId, moved)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not records[player] then return false, "InvalidPlayer" end
	local node = type(nodeId) == "string" and gatherNodes[nodeId] or nil
	if not node then return false, "InvalidEncounter" end
	if not allowed(player, "Gather") then return false, "RateLimited" end
	-- ECO-25: the node script saw the player move during the hold. Nothing is claimed.
	if moved == true then
		reply(player, "Gather", false, "MovedAway")
		return false, "MovedAway"
	end
	local alive, root = context(player), rootOf(player)
	local distance = root and Rules.distance(root.Position.X, root.Position.Z, node.slot.x, node.slot.z) or math.huge
	local ok, result = state:gather(player.UserId, nodeId, node.slot.id, node.material, node.quantity, alive, distance,
		workspace:GetServerTimeNow())
	if ok then
		gatherNodes[nodeId] = nil
		state:retireEncounter(nodeId)
		analytics:gain(player.UserId, "gather", node.slot.zone)
	end
	reply(player, "Gather", ok, result, ok and gatherNotice(result) or nil)
	return ok, ok and table.clone(result) or result
end
gatherClaim.Parent = network
-- Wilt at Dawn or expiry: only removes a node, never grants.
local gatherRetire = Instance.new("BindableFunction")
gatherRetire.Name = "GatherRetire"
gatherRetire.OnInvoke = function(nodeId)
	if type(nodeId) ~= "string" or not gatherNodes[nodeId] then return false end
	gatherNodes[nodeId] = nil
	state:retireEncounter(nodeId)
	return true
end
gatherRetire.Parent = network

-- Delivery A4: a Studio-only, server-only probe for the two-session claim check. It is never created outside Studio,
-- lives in ServerStorage (clients cannot reach it), and only drives keys that start with "probe:", which belong to no
-- player: the next sampling pass ends any such session as Disconnected, with no grant and no penalty.
if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "CaptureProbe"
	probe.OnInvoke = function(op, key, id)
		if op == "sessions" then return capture:activeSessions() end
		if type(key) ~= "string" or key:sub(1, 6) ~= "probe:" then return false, "ProbeKeysOnly" end
		local now = workspace:GetServerTimeNow()
		if op == "begin" then
			local entry = type(id) == "string" and entries[id] or nil
			if not entry or not entry.brain then return false, "InvalidEncounter" end
			local at = entry.body.Position
			local ok, result = capture:begin({ playerKey = key, encounterId = id, dir = 1, lumipolX = at.X, lumipolZ = at.Z,
				now = now, alive = true, life = key, distance = 3, x = at.X + 3, y = at.Y, z = at.Z,
				encounterStatus = state:encounterStatus(id) or "Gone", wary = Wild.wary(entry.brain), tier = entry.slot.tier,
				bagRoom = true, collectionRoom = true })
			return ok, ok and result.token or result
		elseif op == "seal" then
			local ok, out = capture:seal(id, key, { now = now, alive = true, life = key, bagRoom = true, collectionRoom = true })
			if ok and out then handleEnding(out) end
			return ok, ok and out and out.reason or out
		end
		return false, "UnknownOp"
	end
	probe.Parent = telemetry
	-- Delivery B5: the two-session ownership probe. Same rules: Studio only, ServerStorage only, probe keys only for
	-- anything that writes. "peek" reads a real player's carry slot and collection, so the probe can check that a
	-- second session never sees, registers or takes the first one's creature.
	local carryProbe = Instance.new("BindableFunction")
	carryProbe.Name = "CarryProbe"
	local probeEncounters = 0
	carryProbe.OnInvoke = function(op, key, uid)
		if op == "peek" then
			local snapshot = state:snapshot(key)
			if not snapshot then return nil end
			return { carrying = snapshot.carrying and snapshot.carrying.uid, registered = #snapshot.registered,
				equipped = snapshot.equippedUid }
		end
		if type(key) ~= "string" or key:sub(1, 6) ~= "probe:" then return false, "ProbeKeysOnly" end
		if op == "join" then return state:addPlayer(key) end
		if op == "leave" then return state:removePlayer(key) end
		if op == "carry" then
			probeEncounters += 1
			local id = "probe:creature:" .. probeEncounters
			state:registerEncounter(id, "Creature")
			return state:completeCapture(key, id, true, "Fog")
		end
		if op == "register" then return state:register(key, uid, true, 0) end
		return false, "UnknownOp"
	end
	carryProbe.Parent = telemetry
	-- Expedition islands (I6): read and drive the island meters for the Play checks. Studio only, ServerStorage
	-- only; it never grants, registers or removes anything a player owns.
	local islandProbe = Instance.new("BindableFunction")
	islandProbe.Name = "IslandProbe"
	islandProbe.OnInvoke = function(op, id, value)
		if op == "read" then
			local out = { phase = islandPhase() }
			for _, item in ipairs(islandList) do
				out[item.spec.id] = { state = item.meter.state, value = item.meter.value,
					chase = item.chase and item.chase.state.mode or nil }
			end
			return out
		end
		-- Next batch NB4: bank one Lumipol egg for a real player (its UserId in value) through the normal pickup and chest
		-- rules, so the Play check can incubate without a scripted steal. Studio only, like every op here.
		if op == "egg" and type(value) == "number" then
			probeEggs += 1
			local encounter = "probe_egg_" .. probeEggs
			state:registerEncounter(encounter, "Egg")
			local ok, uid = state:pickup(value, encounter, true, 0)
			if not ok then return false, uid end
			local banked = state:extract(value, true, 0, workspace:GetServerTimeNow())
			local player = playersByUserId[value]
			if player then send(player, "Extract", banked == true, "") end
			return banked == true, uid
		end
		-- Fix pass (FP5c): put one egg in a real player's bag (its UserId in value) and drop it at their feet, as a first
		-- strike would, so the Play check can watch an adult carry it home. Studio only, like every op here.
		if op == "eggDrop" and type(value) == "number" then
			probeEggs += 1
			local encounter = "probe_egg_" .. probeEggs
			state:registerEncounter(encounter, "Egg")
			local ok, uid = state:pickup(value, encounter, true, 0)
			if not ok then return false, uid end
			local player = playersByUserId[value]
			local dropped, entry = state:dropForStrike(value, "probe_drop_" .. probeEggs)
			if not (dropped and entry and player) then return false, "NoDrop" end
			local root = rootOf(player)
			spawnDrop(player, entry, root and root.Position.X or 0, root and root.Position.Z + 1 or 0)
			return true, entry.uid
		end
		local island = type(id) == "string" and islands[id] or nil
		if not island then return false, "UnknownIsland" end
		if op == "set" and type(value) == "number" and value == value then
			island.meter.value = math.clamp(value, 0, Island.live.WAKE - 1)
			return true
		end
		if op == "wake" then
			island.meter.value = Island.live.WAKE - 0.001
			local out = Island.event(island.meter, "Rustle")
			if out.woke then wakeIsland(island, workspace:GetServerTimeNow()) end
			return out.woke
		end
		if op == "settle" then
			island.meter.alertFor = math.huge
			return true
		end
		-- Chase pass (CP6): treat a real player as past the first paid trip, so the Play check can see an adult kill.
		if op == "lethal" and type(value) == "number" then
			probeLethal[value] = true
			return true
		end
		return false, "UnknownOp"
	end
	islandProbe.Parent = telemetry
	-- Items and totem (plan Part 4): the Play check's gear ops. Studio only, ServerStorage only. "fund" banks Esencia
	-- and materials for a real player (its UserId) so every item can be crafted; "capture" starts a real capture for that
	-- player on the nearest free creature, through the same path as the prompt (so the Guantes' wiring is what runs).
	local gearProbe = Instance.new("BindableFunction")
	gearProbe.Name = "GearProbe"
	gearProbe.OnInvoke = function(op, userId)
		local player = type(userId) == "number" and playersByUserId[userId] or nil
		if not player then return false, "UnknownPlayer" end
		if op == "fund" then
			local profile = state.players["n:" .. tostring(userId)]
			if not profile then return false, "NoProfile" end
			profile.ember += 500
			profile.banked.fogbark += 200
			profile.banked.glowmoss += 200
			profile.banked.nightbloom += 20
			send(player, "Probe", true, "")
			return true, profile.ember
		end
		if op == "capture" then
			local root = rootOf(player)
			if not root then return false, "NoRoot" end
			local best, bestId, bestDistance
			for id, entry in pairs(entries) do
				if entry.brain and entry.body and entry.body.Parent then
					local distance = (entry.body.Position - root.Position).Magnitude
					if not bestDistance or distance < bestDistance then best, bestId, bestDistance = entry, id, distance end
				end
			end
			if not best then return false, "NoCreature" end
			root.CFrame = CFrame.new(best.body.Position + Vector3.new(4, 2, 0))
			startCapture(player, best)
			return true, bestId
		end
		return false, "UnknownOp"
	end
	gearProbe.Parent = telemetry
	-- Nest Heist (NH5): the Play check's egg ops, through the real paths. Studio only, ServerStorage only. "steal" takes
	-- the nearest egg in a nest for a real player (its UserId) through the prompt's own handler; "drop" knocks the
	-- carried egg loose; "pickup" picks up the nearest dropped egg; "read" lists the eggs.
	local heistProbe = Instance.new("BindableFunction")
	heistProbe.Name = "HeistProbe"
	heistProbe.OnInvoke = function(op, userId, value)
		if op == "read" then
			local out = {}
			for id, egg in pairs(eggs.eggs) do
				out[id] = { state = egg.state, carrier = egg.carrier, last = egg.lastCarrier, island = egg.meta.island,
					y = egg.body and math.floor(egg.body.Position.Y * 100) / 100 or nil,
					open = egg.prompt and egg.prompt.Enabled or nil }
			end
			return out
		end
		local player = type(userId) == "number" and playersByUserId[userId] or nil
		local root = player and rootOf(player)
		if not root then return false, "UnknownPlayer" end
		if op == "steal" then
			local best, bestDistance
			for id, entry in pairs(entries) do
				local egg = EggCarry.get(eggs, id)
				local wanted = value == nil or entry.slot.island == value
				if egg and egg.state == "InNest" and wanted and entry.body.Parent then
					local distance = (entry.body.Position - root.Position).Magnitude
					if not bestDistance or distance < bestDistance then best, bestDistance = entry, distance end
				end
			end
			if not best then return false, "NoEgg" end
			root.CFrame = CFrame.new(best.body.Position + Vector3.new(3, 1, 0))
			-- HB-T7: the probe stands in for a completed hold (the prompt's full time), so the real path accepts it.
			best.holdStarts[player] = { at = workspace:GetServerTimeNow() - best.prompt.HoldDuration - 0.05 }
			best.trigger(player)
			local egg = EggCarry.get(eggs, best.id)
			return egg ~= nil and egg.state == "Carried", best.id
		end
		if op == "drop" then
			local egg = Heist.dropEgg(player, type(value) == "string" and value or "Hit")
			return egg ~= nil, egg and egg.id
		end
		if op == "pickup" then
			local best, bestDistance
			for _, egg in pairs(eggs.eggs) do
				if egg.state == "Dropped" and egg.body then
					local distance = (egg.body.Position - root.Position).Magnitude
					if not bestDistance or distance < bestDistance then best, bestDistance = egg, distance end
				end
			end
			if not best then return false, "NoDroppedEgg" end
			root.CFrame = CFrame.new(best.body.Position + Vector3.new(2, 1, 0))
			Heist.pickupEgg(player, best)
			return best.state == "Carried" and best.carrier == userId, best.id
		end
		-- Nest Heist phase 2 (NP6): "bat" swings through the real path; "batClear" asks the real line-of-sight ray from
		-- the player's root to a point (value = { x, y, z }) through a temporary marker that blocks nothing itself.
		if op == "bat" then
			Heist.swingBat(player, records[player], workspace:GetServerTimeNow())
			return player:GetAttribute("WildboundBatSwing"), player:GetAttribute("WildboundBatReady")
		end
		if op == "batClear" and type(value) == "table" then
			local mark = Instance.new("Part")
			mark.Anchored, mark.CanCollide, mark.CanQuery, mark.Transparency, mark.Size = true, false, false, 1, Vector3.one
			mark.Position = Vector3.new(value[1], value[2], value[3])
			mark.Parent = runtime
			local clear = Heist.batClear(root, mark)
			mark:Destroy()
			return clear
		end
		return false, "UnknownOp"
	end
	heistProbe.Parent = telemetry
end

-- I6: a sprint (DP1) or a rustle (D6) near an island disturbs its sleepers; one player's noise wakes it for everyone.
-- Fix pass (FP4d): La Silueta's chase-start scream ("siluetaScream", its reach in the tier slot) wakes every island
-- whose nest is within that reach.
noiseEvent.Event:Connect(function(kind, tier, x, z)
	if kind ~= "sprint" and kind ~= "rustle" and kind ~= "siluetaScream" then return end
	if not Rules.finite(x) or not Rules.finite(z) then return end
	local now = workspace:GetServerTimeNow()
	local phase = islandPhase()
	for _, island in ipairs(islandList) do
		local spec = island.spec
		local distance = math.sqrt((x - spec.x) ^ 2 + (z - spec.z) ^ 2)
		local result
		if kind == "sprint" and distance <= Island.live.SPRINT_NOISE_REACH then
			result = Island.event(island.meter, "SprintNoise")
		elseif kind == "rustle" and distance <= Island.wakeRadius(spec, phase) then
			result = Island.event(island.meter, "Rustle")
		elseif kind == "siluetaScream" and Rules.finite(tier) and distance <= tier then
			result = Island.event(island.meter, "SiluetaScream")
		end
		if result and result.woke then wakeIsland(island, now) end
	end
end)

-- A1: the brain hears the nearest live player's position and horizontal speed, both read here.
local function stepWildlife(now)
	local watchers = {}
	for player in pairs(records) do
		local root = rootOf(player)
		if root and context(player) then
			local velocity = root.AssemblyLinearVelocity
			table.insert(watchers, { x = root.Position.X, z = root.Position.Z,
				speed = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z) })
		end
	end
	for _, entry in pairs(entries) do
		local brain = entry.brain
		if brain then
			local near, best = nil, math.huge
			for _, watcher in ipairs(watchers) do
				local distance = math.sqrt((watcher.x - brain.x) ^ 2 + (watcher.z - brain.z) ^ 2)
				if distance < best then best, near = distance, watcher end
			end
			local fx, fz = brain.fx, brain.fz
			Wild.step(brain, Wild.CONSTANTS.STEP, near, rand)
			-- A scared Lumipol cannot be calmed, so its prompt hides until it peeks or settles.
			local island = entry.slot.island and islands[entry.slot.island]
			local nestOpen = island == nil or Island.nestOpen(island.meter)
			local prompting = nestOpen and capture:encounterState(entry.id, now) == "Free" and not Wild.wary(brain)
			if entry.prompt.Enabled ~= prompting then entry.prompt.Enabled = prompting end
			if entry.model:GetAttribute("Mode") ~= brain.mode then entry.model:SetAttribute("Mode", brain.mode) end
			if entry.model:GetAttribute("Peek") ~= brain.peek then entry.model:SetAttribute("Peek", brain.peek) end
			if brain.moved or math.abs(brain.fx - fx) > 1e-3 or math.abs(brain.fz - fz) > 1e-3 then
				local at = Vector3.new(brain.x, relief:heightAt(brain.x, brain.z) + entry.lift, brain.z)
				entry.model:PivotTo(CFrame.lookAt(at, at + Vector3.new(brain.fx, 0, brain.fz)))
			end
		end
	end
end

-- B2: each capsule's mood from the existing threat reading (Silueta's state and distance, fog, safe zone). The mood
-- and the sound hook change only on a change, so the replicated attributes stay quiet. Carrying adds nothing to
-- what Silueta senses.
local function updateCarryMoods(now)
	for player, record in pairs(records) do
		local character = player.Character
		local capsule = character and character:FindFirstChild(CAPSULE)
		local root = rootOf(player)
		if capsule and root then
			local position = root.Position
			local mode, distance = guardianReading(player, position)
			local inFog, safe = Rules.zone(position.X, position.Z)
			local mood = Carry.mood({ mode = mode, distance = distance, inFog = inFog, safe = safe,
				alive = context(player) == true })
			-- Dread pass (D-D5): a creature frightened by sprinting stays afraid until it settles.
			if record.stamina and record.stamina.warned then mood = "afraid" end
			if capsule:GetAttribute("Mood") ~= mood then paintCapsule(capsule, mood) end
			-- I5 (EI-6): a carried island cria cries while afraid and for 6 s after its island woke.
			local snapshot = state:snapshot(player.UserId)
			local carried = snapshot and snapshot.carrying
			local cria = carried ~= nil and carried.stage == "Cria"
			record.crying = cria and Carry.crying({ mood = mood, wokeAt = record.criaWokeAt }, now)
			record.cryMemory = record.cryMemory or Carry.newCryMemory()
			if cria and Carry.cry(record.cryMemory, { mood = mood, wokeAt = record.criaWokeAt }, now) then
				if not safe then
					noiseEvent:Fire("cry", Rules.inTerritory(position.X, position.Z) and "Territory" or "Fog", position.X,
						position.Z)
				end
				capsule:SetAttribute("SoundCue", "fear")
				capsule:SetAttribute("SoundCueAt", now)
				send(player, "CriaCry", false, Text.CARRY.cry)
			end
			record.sound = record.sound or Carry.newSoundMemory()
			local cue = Carry.soundCue(record.sound, mood, now)
			if cue then
				capsule:SetAttribute("SoundCue", cue)
				capsule:SetAttribute("SoundCueAt", now)
			end
		end
	end
end

-- Dread pass (D-D5): the creature that slipped free runs off into the forest and fades. Visual only; it is gone.
local function runAway(character, root)
	local capsule = character and character:FindFirstChild(CAPSULE)
	local creature = capsule and capsule:FindFirstChild("Creature")
	if not creature or not root then return end
	local body = creature:Clone()
	for _, child in ipairs(body:GetDescendants()) do
		if child:IsA("JointInstance") then child:Destroy() end
	end
	body.Name, body.Anchored, body.Massless = "WildboundRunaway", true, false
	local away = Vector3.new(-root.CFrame.LookVector.X, 0, -root.CFrame.LookVector.Z)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
	local from = root.Position - Vector3.new(0, 2.2, 0)
	body.CFrame = CFrame.lookAt(from, from + away)
	body.Parent = runtime
	local goal = from + away * 30
	TweenService:Create(body, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(goal, goal + away), Transparency = 1 }):Play()
	task.delay(2.6, function() body:Destroy() end)
end

-- Dread pass (D3, D-D5): stamina per step. The server reads the horizontal speed itself, so holding the key in
-- place costs nothing; a capture or a hiding spot blocks the sprint. Noise and fear come from the pure rule.
local STANCE_RATE = 8 -- intents per second per player; more are dropped
local function updateStamina(now, dt)
	local capturers = {}
	for _, session in ipairs(capture:activeSessions()) do capturers[session.playerKey] = true end
	for player, record in pairs(records) do
		local root = rootOf(player)
		if record.stamina and root and context(player) then
			local velocity = root.AssemblyLinearVelocity
			local x, z = root.Position.X, root.Position.Z
			local _, safe = Rules.zone(x, z)
			local snapshot = state:snapshot(player.UserId)
			local capturing = capturers[player.UserId] == true
			local hidden = type(player:GetAttribute("WildboundHidden")) == "string"
			local out = Stamina.step(record.stamina, dt, {
				speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
				blocked = capturing or hidden,
				carrying = snapshot ~= nil and snapshot.carrying ~= nil, inCamp = safe,
				regenScale = Rules.refugeAt(x, z) and WaveClock.live.REFUGE_REGEN or 1,
				-- NS7: the worn glove's "Aliento al correr" drains the sprint slower.
				drainScale = Gear.drainScale(snapshot and snapshot.glove),
			}, now)
			-- Dev tuning: a changed sprint value re-applies WalkSpeed at once, not only on the next stance change.
			if out.changed or record.tuned ~= Stamina.version then
				record.tuned = Stamina.version
				applyCarry(player)
			end
			local rounded = math.floor(record.stamina.stamina + 0.5)
			if player:GetAttribute("WildboundStamina") ~= rounded then player:SetAttribute("WildboundStamina", rounded) end
			if player:GetAttribute("WildboundStance") ~= record.stamina.stance then
				player:SetAttribute("WildboundStance", record.stamina.stance)
			end
			if out.noise then
				local tier = Rules.inTerritory(x, z) and "Territory" or "Fog"
				noiseEvent:Fire("sprint", tier, x, z)
			end
			local capsule = player.Character and player.Character:FindFirstChild(CAPSULE)
			if out.warn then
				if capsule then
					paintCapsule(capsule, "afraid")
					capsule:SetAttribute("SoundCue", "fear")
					capsule:SetAttribute("SoundCueAt", now)
				end
				send(player, "SlipWarning", true, Text.STAMINA.slipWarning)
			end
			if out.slip then
				local character = player.Character
				local ok = state:releaseCarried(player.UserId)
				if ok then
					runAway(character, root)
					send(player, "Slipped", true, Text.STAMINA.slipped)
				end
			end
		end
	end
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if dt ~= dt or dt < 0 then return end
	accumulator += math.min(dt, 0.2)
	if accumulator < Wild.CONSTANTS.STEP then return end
	local stepSeconds = accumulator
	accumulator = 0
	local now = workspace:GetServerTimeNow()
	updateStamina(now, stepSeconds)
	stepIncubators(now)
	for _, item in ipairs(capture:activeSessions()) do
		local player = playersByUserId[item.playerKey]
		if not player or not records[player] then
			local out = capture:drop(item.playerKey, now)
			if out then handleEnding(out) end
		else
			local out = capture:sample(item.token, observe(player, now))
			if out then
				if out.phase == "Active" then
					captureRemote:FireClient(player, Capture.toSnapshot(out))
				else
					handleEnding(out)
				end
			end
		end
	end
	for _, out in ipairs(capture:sweep(now)) do handleEnding(out) end
	stepWildlife(now)
	stepIslands(now, stepSeconds)
	Heist.stepEggs(now)
	stepWaves(now)
	stepSpawnClock(now)
	updateCarryMoods(now)
	-- Expedition boundaries (M5.2): leaving the camp circle opens one. Tracking only, never a grant.
	local campX, campZ = campCenter.Position.X, campCenter.Position.Z
	for player in pairs(records) do
		local root = rootOf(player)
		if root and context(player) then
			local x, z = root.Position.X, root.Position.Z
			local fromCamp = Rules.distance(x, z, campX, campZ)
			local _, safe = Rules.zone(x, z)
			local inCamp = safe and fromCamp < Rules.distance(x, z, SHELTER_X, SHELTER_Z)
			state:observeExpedition(player.UserId, fromCamp, not inCamp, now)
			-- Items IT1: a new expedition gives the Chaleco its one save back.
			syncGear(player, state:snapshot(player.UserId))
			analytics:observeCamp(player.UserId, not inCamp)
		end
	end
end)

-- Camp sinks and protections (M5.5). Arguments are looked up in server tables; unknown ones are dropped.
local ECONOMY_ACTIONS = { Craft = true, Upgrade = true, Learn = true, ArmSeal = true, SealNewest = true, ArmTotem = true,
	DisarmTotem = true, UseCapsule = true, CraftGear = true, PlaceLuck = true, EquipGlove = true }
local function economyAction(player, action, argument)
	local key = player.UserId
	if action == "CraftGear" then
		-- The id is looked up in the server's config, never trusted. NS7: a glove's rarity and stats are rolled here, on
		-- the server, from earned Esencia and materials only; the client sends nothing but the recipe id.
		local spec = type(EconomyConfig.gear) == "table" and EconomyConfig.gear[argument] or nil
		if not spec or (spec.kind ~= "gloves" and spec.kind ~= "luckTotem") then return end
		local alive, distance = context(player, campCenter)
		-- HB-T5: the owner's glove bench counts as a place to craft gloves (measured on the server, within its range).
		if spec.kind == "gloves" and Heist.hub then
			distance = math.min(distance, Heist.hub:distance(player, "WildboundGloveStation"))
		end
		local roll = spec.kind == "gloves" and Gear.roll(function() return rng:NextNumber() end) or nil
		local ok, result = state:craftGear(key, argument, alive, distance, roll)
		if ok then analytics:spent(key, "craft") end -- the analytics schema has no "gear" kind; crafting it is
		local words = Text.GEAR.crafted:format(Text.GEAR[argument] or argument)
		if ok and spec.kind == "gloves" then
			words = Text.GEAR.glovesCrafted:format(Text.GEAR.rarity[result.rarity] or result.rarity,
				table.concat(Gear.describe(result, Text), ", "))
		end
		reply(player, action, ok, result, words)
	elseif action == "EquipGlove" then
		-- NS7: one glove is worn at a time; the uid must be one of this player's gloves (State checks).
		local ok, result = state:equipGlove(key, argument, context(player))
		local glove = ok and state:snapshot(key).glove or nil
		reply(player, action, ok, result, glove and Text.GEAR.gloveWorn:format(Text.GEAR.rarity[glove.rarity] or glove.rarity,
			table.concat(Gear.describe(glove, Text), ", ")) or nil)
	elseif action == "PlaceLuck" then
		-- Items IT2: the Tótem de la suerte goes at the player's own feet; the argument names it and nothing else.
		if argument ~= Gear.LUCK then return end
		placeLuck(player)
	elseif action == "Craft" or action == "Upgrade" then
		local known = action == "Craft" and EconomyConfig.recipes or EconomyConfig.upgrades
		if not known[argument] then return end
		local alive, distance = context(player, campCenter)
		local ok, result
		if action == "Craft" then ok, result = state:craft(key, argument, alive, distance)
		else ok, result = state:upgrade(key, argument, alive, distance) end
		if ok then
			if action == "Craft" then analytics:crafted(key, argument) else analytics:spent(key, "upgrade") end
		end
		reply(player, action, ok, result, action == "Craft" and notices.crafted:format(tostring(result)) or notices.upgraded)
	elseif action == "ArmSeal" or action == "SealNewest" then
		if argument ~= "seal" then return end
		local alive = context(player)
		local ok, result
		if action == "ArmSeal" then ok, result = state:armSeal(key, alive) else ok, result = state:sealNewest(key, alive) end
		reply(player, action, ok, result, action == "ArmSeal" and notices.sealArmed or notices.sealNewest)
	elseif action == "ArmTotem" or action == "DisarmTotem" then
		if argument ~= "totem" then return end
		local alive, distance = context(player, campCenter)
		local ok, result
		if action == "ArmTotem" then ok, result = state:armTotem(key, alive, distance)
		else ok, result = state:disarmTotem(key, alive, distance) end
		reply(player, action, ok, result, action == "ArmTotem" and notices.totemSet or notices.totemAway)
	elseif action == "Learn" then
		if not EconomyConfig.skills[argument] then return end
		local alive, distance = context(player, campCenter)
		local ok, result = state:learn(key, argument, alive, distance)
		if ok then analytics:spent(key, "skill") end
		reply(player, action, ok, result, notices.learned)
	elseif action == "UseCapsule" then
		local alive, root = context(player), rootOf(player)
		local distance = root and Rules.distance(root.Position.X, root.Position.Z, SHELTER_X, SHELTER_Z) or math.huge
		local ok, result = state:useCapsule(key, argument, alive, distance)
		if ok then analytics:spent(key, "capsule") end
		reply(player, action, ok, result, ok and notices.capsule:format(result.ember) or nil)
	end
end


actionRemote.OnServerEvent:Connect(function(player, action, uid, ...)
	if type(action) ~= "string" or #action > 32 or select("#", ...) > 0 then return end
	if action ~= "RequestSnapshot" and action ~= "Equip" and action ~= "Unequip" and action ~= "Protect" and action ~= "Hatch"
		and action ~= "CaptureCancel" and action ~= "CaptureSeal" and not ECONOMY_ACTIONS[action] then return end
	if action == "RequestSnapshot" then
		if uid ~= nil or not allowed(player, action) then return end
		send(player, action, true, Heist.saves:isSaving(player.UserId) and Text.SAVE.saving or notices.sessionOnly)
		return
	end
	if type(uid) ~= "string" or #uid == 0 or #uid > 128 or not allowed(player, action) then return end
	if action == "CaptureSeal" then
		-- H1: the token is untrusted and carries no timing. The rule judges the press by this server's clock when the
		-- request arrived, with values read here. A wrong owner, a stale token or an early press is ignored silently.
		local meta = sessionMeta[uid]
		local ok, out = capture:seal(uid, player.UserId, observe(player, workspace:GetServerTimeNow()))
		-- Delivery C1: an accepted seal tap is the loud part of a capture.
		if ok and meta then noiseEvent:Fire("seal", meta.tier or "Fog", meta.x, meta.z) end
		if ok and out then handleEnding(out) end
		return
	end
	if action == "CaptureCancel" then
		-- The token is untrusted. A wrong owner, a stale or a made-up one is ignored without a reply.
		local ok, out = capture:cancel(uid, player.UserId, workspace:GetServerTimeNow())
		if ok then handleEnding(out) end
		return
	end
	if ECONOMY_ACTIONS[action] then economyAction(player, action, uid)
	elseif action == "Hatch" then hatch(player, uid)
	elseif action == "Protect" then protect(player, uid)
	elseif action == "Unequip" then
		-- NS4: only the companion that is out can be stored; the uid is checked against the server's own state.
		local snapshot = state:snapshot(player.UserId)
		if not snapshot or snapshot.equippedUid ~= uid then return end
		local species = "Lumipol"
		for _, pet in ipairs(snapshot.registered) do
			if pet.uid == uid then species = pet.species end
		end
		local ok, reason = state:unequip(player.UserId, context(player))
		if ok then
			player:SetAttribute("WildboundEquippedUid", nil)
			player:SetAttribute("WildboundHasLumipol", false)
		end
		reply(player, action, ok, reason, Text.CAMP.companionStored:format(Text.CARD.species[species] or species))
	else
		local alive = context(player)
		local ok, reason = state:equip(player.UserId, uid, alive)
		if ok then
			player:SetAttribute("WildboundEquippedUid", uid)
			player:SetAttribute("WildboundHasLumipol", true)
		end
		local species = "Lumipol"
		local snapshot = state:snapshot(player.UserId)
		for _, pet in ipairs(snapshot and snapshot.registered or {}) do
			if pet.uid == uid then species = pet.species end
		end
		reply(player, action, ok, reason, Text.CAMP.equipped:format(Text.CARD.species[species] or species))
	end
end)

-- Nest Heist (NH4): the Burst. The rule owns the cooldown; nothing burst-related is read from the client but the word.
-- The speed goes through applyCarry (WalkSpeed, so the player's own move direction steers it); no invulnerability.
-- The puff is made here, so every player sees it; every audio client plays the scuff when WildboundBurstReady changes
-- (this server makes no sounds, delivery B).
function Heist.burst(player, record, now)
	local root = rootOf(player)
	local capturing = false
	for _, session in ipairs(capture:activeSessions()) do
		if session.playerKey == player.UserId then capturing = true end
	end
	local hidden = type(player:GetAttribute("WildboundHidden")) == "string"
	-- NS7: the worn glove's "Recarga de impulso" shortens the cooldown (the rule keeps at least half of it).
	local glove = (state:snapshot(player.UserId) or {}).glove
	local ok = Stamina.burst(record.stamina, now, { blocked = root == nil or context(player) ~= true or capturing or hidden,
		cooldownScale = Gear.burstScale(glove) })
	if not ok or not root then return end
	applyCarry(player)
	player:SetAttribute("WildboundBurstReady", record.stamina.burstReadyAt)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WildboundBurst"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate, emitter.Lifetime, emitter.Speed = 0, NumberRange.new(0.3, 0.6), NumberRange.new(6, 10)
	emitter.SpreadAngle, emitter.LightEmission = Vector2.new(180, 30), 0.5
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(225, 235, 210))
	emitter.Parent = attachment
	attachment.Parent = root
	emitter:Emit(16)
	task.delay(2, function() attachment:Destroy() end)
end

-- Nest Heist phase 2 (NP4): the bat every player holds. Two parts welded to the right hand (R15) or arm (R6), built
-- like the carry capsule's parts: unanchored, massless, no collision, touch or query, so it never pushes, blocks a ray
-- or trips a prompt. Every client swings it on WildboundBatSwing; the grip's C1 puts the handle on the pivot.
function Heist.equipBat(character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") or character:FindFirstChild("WildboundBat") then return end
	local model = Instance.new("Model")
	model.Name = "WildboundBat"
	local handle = capsulePart(model, "Handle", Vector3.new(0.25, 1.2, 0.25), Enum.PartType.Block,
		Color3.fromRGB(70, 48, 32), Enum.Material.Wood)
	local barrel = capsulePart(model, "Barrel", Vector3.new(0.45, 1.8, 0.45), Enum.PartType.Block,
		Color3.fromRGB(150, 104, 62), Enum.Material.Wood)
	local grip = weld("BatGrip", hand, handle, CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-45), 0, 0))
	grip.C1 = CFrame.new(0, -0.5, 0)
	weld("BatBarrel", handle, barrel, CFrame.new(0, 1.4, 0))
	model.Parent = character
end
-- The line of sight a hit needs: chest to chest, ignoring every character, the runtime visuals and anything that does
-- not collide; a wall, a trunk core or the relief in between blocks it.
Heist.batParams = RaycastParams.new()
Heist.batParams.FilterType = Enum.RaycastFilterType.Exclude
Heist.batParams.RespectCanCollide = true
function Heist.batClear(from, to)
	local exclude = { runtime }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then table.insert(exclude, other.Character) end
	end
	Heist.batParams.FilterDescendantsInstances = exclude
	local a, b = from.Position + Vector3.new(0, 1, 0), to.Position + Vector3.new(0, 1, 0)
	return workspace:Raycast(a, b - a, Heist.batParams) == nil
end
-- A swing. The client sends only the word; the server checks the rule's cooldown, the safe zones and the attacker's
-- state, then picks the target from its own positions and facing (reach, angle, height) and a line-of-sight ray. A
-- carrier hit stumbles and drops the egg for anyone (the attacker gets nothing for it); anyone else only taps; an
-- immune target is untouched. No damage. The parents and La Silueta keep acting as before.
function Heist.swingBat(player, record, now)
	local Bat = Heist.Bat
	local root = rootOf(player)
	local capturing = false
	for _, session in ipairs(capture:activeSessions()) do
		if session.playerKey == player.UserId then capturing = true end
	end
	local hidden = type(player:GetAttribute("WildboundHidden")) == "string"
	local at = root and root.Position
	local safe = at ~= nil and select(2, Rules.zone(at.X, at.Z)) == true
	local ok, readyAt = Bat.swing(Heist.bats, player.UserId, now,
		{ alive = root ~= nil and record ~= nil and context(player) == true, safe = safe, busy = capturing or hidden })
	if not ok then
		if readyAt == "SafeZone" and allowed(player, "BatRefused") then send(player, "Bat", false, Text.BAT.safe) end
		return
	end
	player:SetAttribute("WildboundBatReady", readyAt)
	player:SetAttribute("WildboundBatSwing", now)
	local look = root.CFrame.LookVector
	local from = { key = player.UserId, x = at.X, y = at.Y, z = at.Z, lookX = look.X, lookZ = look.Z }
	local candidates = {}
	for other in pairs(records) do
		local otherRoot = other ~= player and rootOf(other) or nil
		if otherRoot and context(other) == true then
			local p = otherRoot.Position
			table.insert(candidates, { key = other.UserId, player = other, root = otherRoot, x = p.X, y = p.Y, z = p.Z,
				alive = true, safe = select(2, Rules.zone(p.X, p.Z)) == true,
				hidden = type(other:GetAttribute("WildboundHidden")) == "string" })
		end
	end
	local target = Bat.pickTarget(from, candidates, function(candidate) return Heist.batClear(root, candidate.root) end)
	if not target then return end
	local victim = target.player
	local effect = Bat.hit(Heist.bats, target.key, now, EggCarry.carriedBy(eggs, target.key) ~= nil)
	islandLog(effect.immune and "batBlocked" or "batHit", "-", target.key)
	if effect.immune then
		send(player, "Bat", false, Text.BAT.immune)
		return
	end
	local dropped = effect.drop and Heist.dropEgg(victim, "Bat") ~= nil
	victim:SetAttribute("WildboundBatHit", now)
	applyCarry(victim)
	task.delay(effect.stumble + 0.05, function()
		if records[victim] then applyCarry(victim) end
	end)
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Position = "WildboundBatHit", Vector3.new(0, 1.5, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate, emitter.Lifetime, emitter.Speed = 0, NumberRange.new(0.25, 0.45), NumberRange.new(8, 14)
	emitter.SpreadAngle, emitter.LightEmission = Vector2.new(180, 180), 0.8
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170))
	emitter.Parent = attachment
	attachment.Parent = target.root
	emitter:Emit(20)
	task.delay(2, function() attachment:Destroy() end)
	send(victim, "BatHit", false, dropped and Text.BAT.knocked or Text.BAT.hit)
	if dropped then send(player, "Bat", true, Text.BAT.loose) end
end

-- Dread pass (D3): one known word per call, at most STANCE_RATE a second; an intent not refreshed within 1.2 s
-- lapses to walk inside the rule, so a lost release never leaves anyone sprinting.
stanceRemote.OnServerEvent:Connect(function(player, intent, ...)
	if type(intent) ~= "string" or select("#", ...) > 0 then return end
	local record = records[player]
	if not record or not record.stamina then return end
	local now = workspace:GetServerTimeNow()
	if now - (record.stanceWindowAt or -math.huge) >= 1 then record.stanceWindowAt, record.stanceCalls = now, 0 end
	record.stanceCalls = (record.stanceCalls or 0) + 1
	if record.stanceCalls > STANCE_RATE then return end
	-- NH4: "burst" shares this remote and its rate limit; the rule refuses it during its cooldown.
	if intent == "burst" then
		Heist.burst(player, record, now)
		return
	end
	-- NP4: "bat" shares this remote and its rate limit too; the rule refuses it during its cooldown.
	if intent == "bat" then
		Heist.swingBat(player, record, now)
		return
	end
	Stamina.intent(record.stamina, intent, now)
end)

local function bindCharacter(player, character)
	local record = records[player]
	if not record or record.character == character then return end
	-- Character replacement/reset is also a defeat boundary, even if Died was missed.
	if record.character and not record.defeated then
		-- NH7: the egg in the arms falls where the old character was, before the defeat.
		Heist.dropEgg(player, "Death", nil, record.character)
		state:defeat(player.UserId, "life:" .. record.generation)
		removeDropsOf(player)
		analytics:death(player.UserId)
	end
	if record.deathConnection then record.deathConnection:Disconnect(); record.deathConnection = nil end
	record.generation += 1
	record.character, record.defeated = character, false
	-- Dread pass (D3): every life starts with a full pool and calm.
	record.stamina = Stamina.new(workspace:GetServerTimeNow())
	local generation = record.generation
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or records[player] ~= record
		or record.generation ~= generation or player.Character ~= character then return end
	local function defeated()
		if records[player] ~= record or record.generation ~= generation or record.defeated
			or record.character ~= character or player.Character ~= character then return end
		record.defeated = true
		-- NH7: a death drops the egg in the arms where the player fell, for anyone, for a limited time (DROP_SECONDS);
		-- banked eggs, creatures and upgrades are never touched.
		Heist.dropEgg(player, "Death")
		local _, _, lossSummary = state:defeat(player.UserId, "life:" .. generation)
		removeDropsOf(player)
		analytics:death(player.UserId)
		-- The client shows the summary full screen before respawn (M4.6).
		-- D-C5: the defeat notice in Spanish; the loss is a fifth of carried materials since D-C2.
		send(player, "Defeat", true, Text.DEFEAT.notice, lossSummary)
	end
	record.deathConnection = humanoid.Died:Connect(defeated)
	if humanoid.Health <= 0 then defeated(); return end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	-- Revalidate after the bounded wait; an old life must never move a replacement character.
	if not root or not root:IsA("BasePart") or records[player] ~= record
		or record.generation ~= generation or record.character ~= character or player.Character ~= character
		or record.defeated or humanoid.Health <= 0 or not humanoid:IsDescendantOf(character)
		or not root:IsDescendantOf(character) or not character:IsDescendantOf(workspace)
		or not campCenter:IsDescendantOf(map) or not map:IsDescendantOf(workspace) then return end
	-- Once per new character, not an ability teleport; preserve the existing SpawnLocation. HF-T3 (HB6): on a hub spawn
	-- pad facing east; the camp when the hub has none.
	local start = Heist.hub and Heist.hub:spawnFrame(player)
	character:PivotTo(start or CFrame.new(campCenter.Position + Vector3.new(0, 4, 10)))
	-- NP4: every character holds a bat from the start.
	Heist.equipBat(character)
	applyCarry(player)
	send(player, "Respawn", true, notices.respawn)
end
-- NS5: the "Entrenamiento" treadmill, built from parts beside the camp (no asset), with its own prompt. One hold buys
-- the next walk level with Esencia; the price, the step and the cap are the shared rule's, never the client's.
function Heist.speedText(value)
	return (string.gsub(string.format("%.2f", value), "%.", ","))
end
function Heist.buildTreadmill()
	local model = Instance.new("Model")
	model.Name = "WildboundTreadmill"
	-- Inside the camp circle (20 studs), east of the centre, clear of the chest, altar and protection stone.
	local center = campCenter.Position + Vector3.new(13, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { runtime }
	local hit = workspace:Raycast(center + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	local floor = hit and hit.Position.Y or (campCenter.Position.Y - campCenter.Size.Y / 2)
	local base = CFrame.new(center.X, floor, center.Z) * CFrame.Angles(0, math.rad(90), 0)
	local function part(name, size, offset, color, material, shape)
		local value = Instance.new("Part")
		value.Name, value.Size, value.CFrame = name, size, base * offset
		value.Anchored, value.CanTouch, value.CanQuery = true, false, false
		value.CanCollide = name == "Deck"
		value.Color, value.Material = color, material or Enum.Material.SmoothPlastic
		if shape then value.Shape = shape end
		value.Parent = model
		return value
	end
	local dark, steel, rubber = Color3.fromRGB(58, 62, 66), Color3.fromRGB(150, 156, 160), Color3.fromRGB(28, 28, 30)
	part("Deck", Vector3.new(4.2, 0.6, 8), CFrame.new(0, 0.3, 0), dark, Enum.Material.Metal)
	part("Belt", Vector3.new(3.4, 0.08, 7.4), CFrame.new(0, 0.64, 0), rubber, Enum.Material.Fabric)
	for _, z in ipairs({ -3.7, 3.7 }) do
		part("Roller", Vector3.new(3.6, 0.7, 0.7), CFrame.new(0, 0.45, z), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for _, x in ipairs({ -1.9, 1.9 }) do
		part("Post", Vector3.new(0.25, 3.6, 0.25), CFrame.new(x, 2.4, -3.6), steel, Enum.Material.Metal)
		part("Rail", Vector3.new(0.2, 0.2, 3.2), CFrame.new(x, 3.4, -2.1), steel, Enum.Material.Metal)
	end
	local console = part("Console", Vector3.new(3.8, 0.9, 0.6), CFrame.new(0, 4.1, -3.6) * CFrame.Angles(math.rad(-25), 0, 0),
		Color3.fromRGB(46, 96, 72), Enum.Material.SmoothPlastic)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(120, 255, 180), 0.6, 8, console
	local sign = Instance.new("BillboardGui")
	sign.Size, sign.StudsOffset, sign.MaxDistance = UDim2.fromOffset(170, 34), Vector3.new(0, 1.6, 0), 60
	sign.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, Text.TRAINING.sign
	label.TextColor3, label.TextStrokeTransparency, label.Font = Color3.fromRGB(235, 255, 240), 0.3, Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = sign
	sign.Parent = console
	model.PrimaryPart = console
	model.Parent = runtime
	local trainPrompt = prompt(console, Text.TRAINING.prompt, Text.TRAINING.object, Heist.Training.CONSTANTS.RANGE, 1,
		Keys.CAMP.train)
	trainPrompt.Triggered:Connect(function(player) Heist.train(player, console) end)
	Heist.treadmill = console
	return model
end
-- HB-T5: measured = a base treadmill's distance (its prompt already passed the rate limit and the owner check).
function Heist.train(player, console, measured)
	if not records[player] or (not measured and not allowed(player, "Train")) then return end
	local alive, distance = context(player, campCenter)
	if measured then distance = measured end
	local root = rootOf(player)
	if not alive or not root or (root.Position - console.Position).Magnitude > Heist.Training.CONSTANTS.RANGE + 4 then
		send(player, "Train", false, Text.TRAINING.farAway)
		return
	end
	local snapshot = state:snapshot(player.UserId)
	local T, C = Text.TRAINING, Heist.Training.live
	local level = Heist.Training.level(snapshot and snapshot.training, "walk")
	local price = Heist.Training.cost(level)
	local ok, result = state:train(player.UserId, "walk", alive, distance, price, C.MAX_LEVEL)
	if ok then
		local after = state:snapshot(player.UserId)
		local walk = Heist.Training.walkSpeed(EconomyConfig.carry.baseSpeed, EconomyConfig.carry.baseSpeed, after.training)
		local nextPrice = Heist.Training.cost(result)
		local text = T.trained:format(result, C.MAX_LEVEL, Heist.speedText(walk))
		if nextPrice then text ..= T.nextLevel:format(nextPrice) end
		send(player, "Train", true, text)
	elseif result == "AtLimit" then
		send(player, "Train", false, T.maxed:format(level, C.MAX_LEVEL))
	elseif result == "CannotAfford" then
		send(player, "Train", false, T.cannot:format(math.max(0, price - (snapshot and snapshot.ember or 0)), level + 1))
	else
		reply(player, "Train", false, result)
	end
end
Heist.buildTreadmill()
-- Nest Heist hub (HB-T3 to HB-T5): the personal bases' stations, bound by tag in WildboundHubStations. A prompt answers
-- only its base's owner within the station's range (measured on the server); the handlers reuse the camp's rules.
-- Everything lives in Heist.hub: this script is at Luau's local limit (NH-W13).
do
	local Stations = require(script.Parent:WaitForChild("WildboundHubStations"))
	Heist.hub = Stations.new({
		Bases = require(script.Parent:WaitForChild("WildboundBases")), Text = Text, Keys = Keys,
		prompt = prompt, rootOf = rootOf, allowed = allowed,
		alive = function(player) return (context(player)) end,
		refuse = function(player, action, reason) reply(player, action, false, reason) end,
		handlers = {
			-- HB-T3: the owner's pedestal delivers the egg in the arms like the camp chest (NH6): only an egg this player
			-- carries, banked with the bag, then Secured once by its carrier. Without an egg nothing is banked here.
			delivery = function(player, distance)
				if not EggCarry.carriedBy(eggs, player.UserId) then
					send(player, "Extract", false, Text.HUB.noEgg)
					return
				end
				local ok, count, receipt = state:extract(player.UserId, (context(player)), distance,
					workspace:GetServerTimeNow())
				if not ok then
					reply(player, "Extract", false, count)
					return
				end
				analytics:extracted(player.UserId)
				Heist.secure(player)
				send(player, "Extract", true, Text.HUB.delivered .. " " .. extractNotice(count, receipt))
			end,
			-- HB-T4: the owner's base incubator works like the camp's (NH6, NS3): an egg in the arms is delivered there
			-- and incubated at once; otherwise the first banked egg goes in. One slot, the same saved incubator state.
			incubator = function(player, distance)
				local carried = EggCarry.carriedBy(eggs, player.UserId)
				if carried then
					local uid = carried.uid
					local ok, count, receipt = state:extract(player.UserId, (context(player)), distance,
						workspace:GetServerTimeNow())
					if not ok then
						reply(player, "Extract", false, count)
						return
					end
					analytics:extracted(player.UserId)
					Heist.secure(player)
					send(player, "Extract", true, extractNotice(count, receipt))
					hatch(player, uid, distance)
					return
				end
				local snapshot = state:snapshot(player.UserId)
				local egg = snapshot and snapshot.bankedEggs[1]
				if not egg then
					send(player, "Hatch", false, Text.INCUBATOR.noEgg)
					return
				end
				hatch(player, egg.uid, distance)
			end,
			-- HB-T5: the glove bench opens the camp screen on this client (its glove rows); crafting gloves there is
			-- allowed by the bench's distance in the economy actions, and wearing one works anywhere (NS7).
			glove = function(player)
				send(player, "OpenBoard", true, Text.HUB.gloves)
			end,
			-- HB-T5: the base treadmill is the Phase 3 training (one hold buys the next walk level with Esencia).
			train = function(player, distance, station)
				Heist.train(player, station, distance)
			end,
		},
		snapshot = function(userId) return state:snapshot(userId) end,
		visual = function(species, position)
			local model = visual("Creature", position, species)
			return model, model:GetAttribute(Art.CONFIG.ATTRIBUTE) == true
		end,
	})
	Heist.hub:start()
	-- Studio only (ServerStorage, never replicated): "trigger" runs a base station's prompt path for a real player (its
	-- UserId), a kind and a base slot; the Play check uses it for another owner's station.
	if RunService:IsStudio() then
		local hubProbe = Instance.new("BindableFunction")
		hubProbe.Name = "HubProbe"
		hubProbe.OnInvoke = function(op, userId, kind, slot)
			local player = type(userId) == "number" and playersByUserId[userId] or nil
			if op ~= "trigger" or not player then return false, "UnknownOp" end
			local station = Heist.hub:find(kind, slot)
			if not station then return false, "NoStation" end
			Heist.hub:trigger(player, station)
			return true
		end
		hubProbe.Parent = telemetry
	end
end
-- NS1: what the player is told about their save after a join (or a Studio probe's rejoin), and the companion
-- attributes a loaded save needs (the Equip action sets them otherwise).
function Heist.saveNotice(userId)
	local player = playersByUserId[userId]
	if not player then return end
	local mode, outcome = Heist.saves:mode(userId)
	local text = Text.SAVE.saving
	if mode == "Off" then text = notices.sessionOnly
	elseif mode == "Saved" then text = outcome == "New" and Text.SAVE.new or Text.SAVE.loaded
	elseif outcome == "LockedElsewhere" then text = Text.SAVE.locked
	elseif outcome == "Quarantined" then text = Text.SAVE.unreadable
	elseif outcome == "TooNew" then text = Text.SAVE.tooNew
	else text = Text.SAVE.unavailable end
	if Heist.saves.label == "memory" and mode == "Saved" then text = text .. " " .. Text.SAVE.memory end
	player:SetAttribute("WildboundSaveMode", mode)
	local snapshot = state:snapshot(userId)
	if snapshot and snapshot.equippedUid then
		player:SetAttribute("WildboundEquippedUid", snapshot.equippedUid)
		player:SetAttribute("WildboundHasLumipol", true)
	end
	send(player, "Save", true, text)
end
local function addPlayer(player)
	if records[player] or Heist.joining[player] then return end
	-- NS1: claim and load the saved record (this yields), or play unsaved. A player who left meanwhile is released.
	Heist.joining[player] = true
	Heist.saves:join(player.UserId, workspace:GetServerTimeNow())
	Heist.joining[player] = nil
	if player.Parent ~= Players then
		Heist.saves:leave(player.UserId)
		state:removePlayer(player.UserId)
		return
	end
	local record = { rates = {}, lastAny = -math.huge, generation = 0, defeated = false }
	records[player] = record
	playersByUserId[player.UserId] = player
	analytics:join(player.UserId)
	record.characterConnection = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character then task.spawn(bindCharacter, player, player.Character) end
	ensureNests()
	sendWave(player)
	Heist.saveNotice(player.UserId)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if not record then return end
	if record.deathConnection then record.deathConnection:Disconnect() end
	if record.characterConnection then record.characterConnection:Disconnect() end
	-- Free any reservation first, with no grant and no penalty, before the profile goes (M3.3, CAP-32).
	local out = capture:drop(player.UserId, workspace:GetServerTimeNow())
	if out then handleEnding(out) end
	-- D10 hold is not built: a disconnected owner's drops go with the profile.
	removeDropsOf(player)
	-- NH5: an egg in the arms stays in the world for anyone.
	Heist.dropEgg(player, "Leave")
	-- NP4: the bat's cooldown and immunity go with the player.
	Heist.Bat.forget(Heist.bats, player.UserId)
	-- B4: the display spot frees for the next player; B5: the companion goes with its owner.
	clearDisplay(player)
	removeCompanion(player)
	analytics:leave(player.UserId, "left")
	records[player] = nil
	playersByUserId[player.UserId] = nil
	-- NS1: the final write and the lock release (nothing at risk is saved), then the session profile goes.
	Heist.saves:leave(player.UserId)
	state:removePlayer(player.UserId)
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
ensureNests()
publishTelemetry()
