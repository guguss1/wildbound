-- Authoritative adapter. Deploy beside WildboundState in ServerScriptService.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
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
if recorder then
	-- Server-only: ServerStorage never replicates. Returns the recorded events and the counters, for tests.
	local dump = Instance.new("BindableFunction")
	dump.Name = "AnalyticsDump"
	dump.OnInvoke = function() return table.clone(recorder.events), table.clone(analytics.counters) end
	dump.Parent = telemetry
end
game:BindToClose(function() analytics:closeAll() end)

-- Server-to-server proof of registered ownership; clients cannot invoke bindables.
-- Never use a replicated Player attribute alone to authorize a companion ability.
local eligibility = Instance.new("BindableFunction")
eligibility.Name = "Eligibility"
eligibility.OnInvoke = function(player, ability)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or ability ~= "LumipolPulse" then return false end
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
local notices = {
	InvalidContext = "Move closer while alive and try again.", Empty = "Your bag is empty.",
	BackpackFull = "Bag full. Return to camp to extract.", AlreadyClaimed = "Someone collected this encounter.",
	CollectionFull = "Session collection limit reached (100 items).",
	NotOwnedEgg = "Select one of your banked eggs.", NotOwnedPet = "Only your registered pets can be equipped.",
	NotOwnedPending = "Select an item in your temporary bag.",
	NoSeal = "No seal. Craft one at camp; your first extraction also earns one.",
	AlreadyProtected = "One item is already protected.", InvalidEncounter = "This encounter is no longer available.",
	PouchFull = "Pouch full. Extract at camp to bank materials.", AlreadyGathered = "You already gathered here this trip.",
	InvalidYield = "This node is no longer available.", NotAtCamp = "Do this at camp.",
	CannotAfford = "Not enough banked materials or Ember.", AtLimit = "You cannot hold more of that.",
	AlreadyOwned = "Already owned.", NoTotem = "You have no totem.",
	AlreadyLeft = "The totem stays set once you leave camp.", NotAtShelter = "Use a capsule at the shelter.",
	NoCapsule = "You have no capsule.", MovedAway = "You moved. Hold still while you gather.",
	NeedsPrerequisite = "Learn the first skill of this branch first.",
	EffectPending = "This skill's effect is not in the build yet, so it cannot be bought.",
}
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
		Color3.fromRGB(121, 202, 160), Enum.Material.SmoothPlastic)
	weld("Seat", shell, creature, CFrame.new(0, 0.1, 0))
	-- It faces away from the carrier's back, so whoever follows sees its face.
	for _, x in ipairs({ -0.25, 0.25 }) do
		local eye = capsulePart(model, "Eye", Vector3.new(0.14, 0.16, 0.1), Enum.PartType.Block,
			Color3.fromRGB(25, 43, 48), Enum.Material.SmoothPlastic)
		weld("EyeJoint", creature, eye, CFrame.new(x, 0.12, 0.47))
		local ear = capsulePart(model, "Ear", Vector3.new(0.22, 0.5, 0.26), Enum.PartType.Block,
			Color3.fromRGB(81, 151, 117), Enum.Material.SmoothPlastic)
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
-- Set when a reply is sent and for each new character.
local function applyCarry(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local snapshot = state:snapshot(player.UserId)
	if not humanoid or not snapshot then return end
	local units = 0
	for _, quantity in pairs(snapshot.carried) do units += quantity end
	local carrySpeed = Wild.carrySpeed(Wild.eggsCarried(snapshot), snapshot.carrying ~= nil)
	local speed = Economy.carrySpeed(EconomyConfig, units, snapshot.pouchCapacity, carrySpeed, snapshot.skills)
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end
-- B4: set below, once the display spots are known. Every reply refreshes the player's display spot.
local refreshDisplay
-- card: a registration receipt for the presentation card (B3); the client words it with WildboundRefuge.card.
local function send(player, action, ok, notice, lossSummary, card)
	local record = records[player]
	if not record or player.Parent ~= Players then return end
	applyCarry(player)
	syncCapsule(player)
	if refreshDisplay then refreshDisplay(player) end
	local snapshot = state:snapshot(player.UserId)
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
	send(player, action, ok, ok and success or (notices[reason] or "That action is not available."))
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
local function hatch(player, uid)
	local alive, distance = context(player, hatchMarker)
	local ok, reason = state:hatch(player.UserId, uid, alive, distance)
	reply(player, "Hatch", ok, reason, "Lumipol hatched and registered. Hatching is free.")
end
-- B8: a seal wards a bag item anywhere while alive (M5.5). It is spent only if it saves the item.
local function protect(player, uid)
	local ok, reason = state:protect(player.UserId, uid, context(player))
	reply(player, "Protect", ok, reason, "Item warded for one defeat. A seal is spent only if it saves the item.")
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
		send(player, "Extract", true, extractNotice(count, receipt))
	elseif count == "Empty" then
		local snapshot = state:snapshot(player.UserId)
		send(player, "Extract", false, snapshot and snapshot.carrying and Text.CAMP.chestCreature or Text.CAMP.chestEmpty)
	else
		reply(player, "Extract", false, count)
	end
end)
local hatchPrompt = prompt(hatchMarker, "Hatch first egg", "Free hatch", 12, nil, Keys.CAMP.hatch)
hatchPrompt.Triggered:Connect(function(player)
	if not validPrompt(hatchPrompt, hatchMarker) or not allowed(player, "Hatch") then return end
	local snapshot = state:snapshot(player.UserId)
	local egg = snapshot and snapshot.bankedEggs[1]
	hatch(player, egg and egg.uid)
end)
local protectionPrompt = prompt(protectionMarker, "Choose protected item", "Earned protection", 12, nil, Keys.CAMP.protect)
protectionPrompt.Triggered:Connect(function(player)
	if not validPrompt(protectionPrompt, protectionMarker) or not allowed(player, "ProtectHint") then return end
	local alive, distance = context(player, protectionMarker)
	if alive and distance == distance and distance <= 12 then
		send(player, "ProtectHint", true, "Choose a bag item and press Protect, anywhere. Or arm a seal before you leave.")
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
local function visual(kind, position)
	local model = Instance.new("Model")
	local bloom = kind == "Nightbloom"
	model.Name = kind == "Egg" and "LumipolEgg" or bloom and "NightbloomBundle" or "Lumipol"
	local size = kind == "Egg" and Vector3.new(2, 2.8, 2) or bloom and Vector3.new(1.6, 1.6, 1.6) or Vector3.new(3, 2, 2.4)
	local body = block(model, "Body", size, CFrame.new(position + Vector3.new(0, 2, 0)),
		bloom and Color3.fromRGB(150, 110, 230) or Color3.fromRGB(121, 202, 160), Enum.PartType.Ball)
	if kind == "Creature" then
		for _, x in ipairs({ -0.65, 0.65 }) do
			block(model, "Eye", Vector3.new(0.35, 0.4, 0.25),
				body.CFrame * CFrame.new(x, 0.3, -1.15), Color3.fromRGB(25, 43, 48))
			block(model, "Ear", Vector3.new(0.6, 1.3, 0.7),
				body.CFrame * CFrame.new(x, 1.1, 0) * CFrame.Angles(0, 0, x * 0.3), Color3.fromRGB(81, 151, 117))
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(151, 236, 175), 0.7, 10, body
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
	local model = visual("Creature", spot.Position)
	model.Name = "DisplayLumipol"
	model:ScaleTo(0.6)
	local at = spot.Position + Vector3.new(0, 0.75, 0)
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
local function playDeposit(from)
	local nest = refugeMarker.Position + Vector3.new(0, 0.6, 0)
	local model = visual("Creature", from)
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
		playDeposit(from)
		send(player, "Register", true, Text.CAMP.registered:format(Text.CARD.species[receipt.species] or receipt.species),
			nil, { uid = receipt.uid, species = receipt.species, ember = receipt.ember, isNew = receipt.isNew,
				repeated = false })
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
local entries, slotState = {}, {}
local sessionMeta = {}
local captureLog = {}
local counters = { started = 0, completed = 0, failed = 0, cancelled = 0, grantRefused = 0, rejected = 0 }
local groundY = creatureMarker.Position.Y
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

local function guardianReading(position)
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local guardian = world and world:FindFirstChild("Silueta")
	local body = guardian and guardian:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then return nil, nil end
	return guardian:GetAttribute("State"), (body.Position - position).Magnitude
end

local function slotOf(id)
	local slot = Wild.slot(id)
	if not slot then return nil end
	-- The map's own markers stay the truth for the two slots that already had one.
	local at = id == "S0a" and creatureMarker or id == "E1" and eggMarker or nil
	if not at then return slot end
	local moved = table.clone(slot)
	moved.x, moved.z = at.Position.X, at.Position.Z
	return moved
end

local function removeEntry(entry, now)
	if entries[entry.id] ~= entry then return end
	entries[entry.id] = nil
	entry.prompt.Enabled = false
	if entry.connection then entry.connection:Disconnect() end
	entry.model:Destroy()
	state:retireEncounter(entry.id)
	local out = capture:retire(entry.id, now or workspace:GetServerTimeNow())
	if out then handleEnding(out) end
end

local spawnEncounter
local function ensureSlots()
	for _, id in ipairs(Wild.activeSlotIds(math.max(1, #Players:GetPlayers()))) do
		if slotState[id] == nil then spawnEncounter(slotOf(id)) end
	end
end
local function scheduleRespawn(slot)
	slotState[slot.id] = "wait"
	task.delay(Wild.respawnSeconds(slot, #Players:GetPlayers()), function()
		slotState[slot.id] = nil
		ensureSlots()
	end)
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
	})
	if not ok then
		counters.rejected += 1
		send(player, "Capture", false, captureNotice(result))
		return
	end
	counters.started += 1
	entry.prompt.Enabled = false
	Wild.reserve(entry.brain, position.X, position.Z)
	local mode, guardianDistance = guardianReading(position)
	sessionMeta[result.token] = { startedAt = now, slot = entry.slot.id, tier = entry.slot.tier,
		inTerritory = Rules.inTerritory(position.X, position.Z), guardianMode = mode,
		guardianDistance = guardianDistance and math.floor(guardianDistance * 10 + 0.5) / 10 or nil }
	captureRemote:FireClient(player, Capture.toSnapshot(result))
end

-- Every ending passes through here: grant, spook or release, the final push, and the log.
handleEnding = function(out)
	local entry = entries[out.encounterId]
	local player = playersByUserId[out.playerKey]
	local now = workspace:GetServerTimeNow()
	local notice, granted = Text.CAPTURE_NOTICES[out.reason] or "", false
	if out.grant then
		local alive = player ~= nil and context(player) == true
		local ok, reason = state:completeCapture(out.playerKey, out.encounterId, alive,
			entry and entry.slot.tier or "Fog")
		granted = ok
		if ok then
			counters.completed += 1
			if entry and entry.brain then Wild.capture(entry.brain) end
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
	local model, body = visual(slot.kind, Vector3.new(slot.x, groundY, slot.z))
	model:SetAttribute("EncounterId", id)
	model:SetAttribute("Slot", slot.id)
	local isEgg = slot.kind == "Egg"
	local entry = { id = id, slot = slot, model = model, body = body, bodyY = body.Position.Y }
	-- A creature is calmed with a tap, so its prompt has no hold. Eggs keep the short hold.
	entry.prompt = prompt(body, isEgg and "Collect" or Text.PROMPTS.calm, isEgg and "Lumipol egg" or Text.PROMPTS.lumipol, 10,
		isEgg and 0.25 or 0)
	if not isEgg then
		entry.brain = Wild.newBrain(slot, rand, { cover = coverCandidates })
		model:SetAttribute("Mode", entry.brain.mode)
	end
	entries[id] = entry
	slotState[slot.id] = id
	entry.connection = entry.prompt.Triggered:Connect(function(player)
		if entries[id] ~= entry or model.Parent ~= runtime or not validPrompt(entry.prompt, body) then return end
		if isEgg then
			if not allowed(player, "Pickup") then return end
			local alive, distance = context(player, body)
			local ok, reason = state:pickup(player.UserId, id, alive, distance)
			if ok then
				analytics:gain(player.UserId, "pickup")
				removeEntry(entry)
				scheduleRespawn(slot)
			end
			reply(player, "Pickup", ok, reason, "Collected temporary loot. Extract it at camp before defeat.")
		else
			if not allowed(player, "CaptureStart") then return end
			startCapture(player, entry)
		end
	end)
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
	if ok then send(player, "Bond", true, ("Bond +%d pending. Extract at camp to keep it."):format(xp)) end
end)

-- Dropped items (D6, M4.6). Each lies near its owner for 30 s; only the owner can pick it up.
local DROP_SECONDS = 30
local drops = {}
local function removeDrop(uid)
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
	return entry.kind == "Egg" and "Lumipol egg" or entry.kind == "Nightbloom" and "Nightbloom bundle" or "Lumipol"
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
	local model, body = visual(entry.kind, Vector3.new(x, groundY, z))
	model.Name = "DroppedItem"
	model:SetAttribute("OwnerUserId", player.UserId)
	local drop = { owner = player, uid = entry.uid, model = model }
	drop.prompt = prompt(body, "Pick up", "Dropped " .. itemName(entry), 10, 0.25)
	drop.connection = drop.prompt.Triggered:Connect(function(who)
		if drops[entry.uid] ~= drop or not validPrompt(drop.prompt, body) then return end
		if who ~= drop.owner then
			if allowed(who, "DropRefused") then send(who, "Pickup", false, "This belongs to another player.") end
			return
		end
		if not allowed(who, "Reclaim") then return end
		local alive, distance = context(who, body)
		local ok, reason = state:reclaimDropped(who.UserId, entry.uid, alive, distance)
		if ok then removeDrop(entry.uid) end
		reply(who, "Reclaim", ok, reason, "Picked up your dropped " .. itemName(entry) .. ".")
	end)
	drops[entry.uid] = drop
	task.delay(DROP_SECONDS, function()
		if drops[entry.uid] ~= drop then return end
		removeDrop(entry.uid)
		local ok = state:loseDropped(player.UserId, entry.uid)
		if ok then send(player, "DropLost", false, "Your dropped " .. itemName(entry) .. " was lost.") end
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
	if entry then spawnDrop(player, entry, towardX, towardZ) end
	send(player, "Strike", true, "")
	return entry and { kind = entry.kind, species = entry.species } or nil
end
strikeEffect.Parent = network

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
		return ("Gathered %d %s. Pouch full: %d left behind."):format(receipt.taken, name, receipt.wasted)
	end
	return ("Gathered %d %s."):format(receipt.taken, name)
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
end

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
			local prompting = capture:encounterState(entry.id, now) == "Free" and not Wild.wary(brain)
			if entry.prompt.Enabled ~= prompting then entry.prompt.Enabled = prompting end
			if entry.model:GetAttribute("Mode") ~= brain.mode then entry.model:SetAttribute("Mode", brain.mode) end
			if entry.model:GetAttribute("Peek") ~= brain.peek then entry.model:SetAttribute("Peek", brain.peek) end
			if brain.moved or math.abs(brain.fx - fx) > 1e-3 or math.abs(brain.fz - fz) > 1e-3 then
				local at = Vector3.new(brain.x, entry.bodyY, brain.z)
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
			local mode, distance = guardianReading(position)
			local inFog, safe = Rules.zone(position.X, position.Z)
			local mood = Carry.mood({ mode = mode, distance = distance, inFog = inFog, safe = safe,
				alive = context(player) == true })
			if capsule:GetAttribute("Mood") ~= mood then paintCapsule(capsule, mood) end
			record.sound = record.sound or Carry.newSoundMemory()
			local cue = Carry.soundCue(record.sound, mood, now)
			if cue then
				capsule:SetAttribute("SoundCue", cue)
				capsule:SetAttribute("SoundCueAt", now)
			end
		end
	end
end

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if dt ~= dt or dt < 0 then return end
	accumulator += math.min(dt, 0.2)
	if accumulator < Wild.CONSTANTS.STEP then return end
	accumulator = 0
	local now = workspace:GetServerTimeNow()
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
			analytics:observeCamp(player.UserId, not inCamp)
		end
	end
end)

-- Camp sinks and protections (M5.5). Arguments are looked up in server tables; unknown ones are dropped.
local ECONOMY_ACTIONS = { Craft = true, Upgrade = true, Learn = true, ArmSeal = true, SealNewest = true, ArmTotem = true,
	DisarmTotem = true, UseCapsule = true }
local function economyAction(player, action, argument)
	local key = player.UserId
	if action == "Craft" or action == "Upgrade" then
		local known = action == "Craft" and EconomyConfig.recipes or EconomyConfig.upgrades
		if not known[argument] then return end
		local alive, distance = context(player, campCenter)
		local ok, result
		if action == "Craft" then ok, result = state:craft(key, argument, alive, distance)
		else ok, result = state:upgrade(key, argument, alive, distance) end
		if ok then
			if action == "Craft" then analytics:crafted(key, argument) else analytics:spent(key, "upgrade") end
		end
		reply(player, action, ok, result, action == "Craft" and ("Crafted. You now hold %s."):format(tostring(result))
			or "Upgrade bought. It lasts this session.")
	elseif action == "ArmSeal" or action == "SealNewest" then
		if argument ~= "seal" then return end
		local alive = context(player)
		local ok, result
		if action == "ArmSeal" then ok, result = state:armSeal(key, alive) else ok, result = state:sealNewest(key, alive) end
		reply(player, action, ok, result, action == "ArmSeal" and "Seal armed: your next new bag item is warded."
			or "Newest item warded. A seal is spent only if it saves the item.")
	elseif action == "ArmTotem" or action == "DisarmTotem" then
		if argument ~= "totem" then return end
		local alive, distance = context(player, campCenter)
		local ok, result
		if action == "ArmTotem" then ok, result = state:armTotem(key, alive, distance)
		else ok, result = state:disarmTotem(key, alive, distance) end
		reply(player, action, ok, result, action == "ArmTotem" and "Totem: Silueta senses you from farther."
			or "Totem put away and refunded.")
	elseif action == "Learn" then
		if not EconomyConfig.skills[argument] then return end
		local alive, distance = context(player, campCenter)
		local ok, result = state:learn(key, argument, alive, distance)
		if ok then analytics:spent(key, "skill") end
		reply(player, action, ok, result, "Skill learned. It lasts this session.")
	elseif action == "UseCapsule" then
		local alive, root = context(player), rootOf(player)
		local distance = root and Rules.distance(root.Position.X, root.Position.Z, SHELTER_X, SHELTER_Z) or math.huge
		local ok, result = state:useCapsule(key, argument, alive, distance)
		if ok then analytics:spent(key, "capsule") end
		reply(player, action, ok, result, ok and ("Banked at the shelter. Earned %d Ember."):format(result.ember) or nil)
	end
end

actionRemote.OnServerEvent:Connect(function(player, action, uid, ...)
	if type(action) ~= "string" or #action > 32 or select("#", ...) > 0 then return end
	if action ~= "RequestSnapshot" and action ~= "Equip" and action ~= "Protect" and action ~= "Hatch"
		and action ~= "CaptureCancel" and action ~= "CaptureSeal" and not ECONOMY_ACTIONS[action] then return end
	if action == "RequestSnapshot" then
		if uid ~= nil or not allowed(player, action) then return end
		send(player, action, true, "Session only: collection resets when you leave this server.")
		return
	end
	if type(uid) ~= "string" or #uid == 0 or #uid > 128 or not allowed(player, action) then return end
	if action == "CaptureSeal" then
		-- H1: the token is untrusted and carries no timing. The rule judges the press by this server's clock when the
		-- request arrived, with values read here. A wrong owner, a stale token or an early press is ignored silently.
		local ok, out = capture:seal(uid, player.UserId, observe(player, workspace:GetServerTimeNow()))
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
	else
		local alive = context(player)
		local ok, reason = state:equip(player.UserId, uid, alive)
		if ok then
			player:SetAttribute("WildboundEquippedUid", uid)
			player:SetAttribute("WildboundHasLumipol", true)
		end
		reply(player, action, ok, reason, "Lumipol equipped.")
	end
end)

local function bindCharacter(player, character)
	local record = records[player]
	if not record or record.character == character then return end
	-- Character replacement/reset is also a defeat boundary, even if Died was missed.
	if record.character and not record.defeated then
		state:defeat(player.UserId, "life:" .. record.generation)
		removeDropsOf(player)
		analytics:death(player.UserId)
	end
	if record.deathConnection then record.deathConnection:Disconnect(); record.deathConnection = nil end
	record.generation += 1
	record.character, record.defeated = character, false
	local generation = record.generation
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or records[player] ~= record
		or record.generation ~= generation or player.Character ~= character then return end
	local function defeated()
		if records[player] ~= record or record.generation ~= generation or record.defeated
			or record.character ~= character or player.Character ~= character then return end
		record.defeated = true
		local _, _, lossSummary = state:defeat(player.UserId, "life:" .. generation)
		removeDropsOf(player)
		analytics:death(player.UserId)
		-- The client shows the summary full screen before respawn (M4.6).
		send(player, "Defeat", true, "Defeated: unwarded bag items and half of each carried material were lost. "
			.. "Banked materials, Ember and companions remain.", lossSummary)
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
	-- Once per new character, not an ability teleport; preserve the existing SpawnLocation.
	character:PivotTo(CFrame.new(campCenter.Position + Vector3.new(0, 4, 10)))
	applyCarry(player)
	send(player, "Respawn", true, "Return temporary loot to camp. Registered collection is session only.")
end
local function addPlayer(player)
	if records[player] then return end
	state:addPlayer(player.UserId)
	local record = { rates = {}, lastAny = -math.huge, generation = 0, defeated = false }
	records[player] = record
	playersByUserId[player.UserId] = player
	analytics:join(player.UserId)
	record.characterConnection = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character then task.spawn(bindCharacter, player, player.Character) end
	ensureSlots()
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
	-- B4: the display spot frees for the next player.
	clearDisplay(player)
	analytics:leave(player.UserId, "left")
	records[player] = nil
	playersByUserId[player.UserId] = nil
	state:removePlayer(player.UserId)
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
ensureSlots()
publishTelemetry()
