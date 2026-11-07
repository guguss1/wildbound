-- Authoritative adapter. Deploy beside WildboundState in ServerScriptService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(script.Parent:WaitForChild("WildboundState"))
local state = State.new()
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
network.Parent = ReplicatedStorage

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
local notices = {
	InvalidContext = "Move closer while alive and try again.", Empty = "Your bag is empty.",
	BackpackFull = "Bag full. Return to camp to extract.", AlreadyClaimed = "Someone collected this encounter.",
	CollectionFull = "Session collection limit reached (100 items).",
	NotOwnedEgg = "Select one of your banked eggs.", NotOwnedPet = "Only your registered pets can be equipped.",
	NotOwnedPending = "Select an item in your temporary bag.", NoSeal = "Your first extraction earns one seal.",
	AlreadyProtected = "One item is already protected.", InvalidEncounter = "This encounter is no longer available.",
}
local function send(player, action, ok, notice)
	if not records[player] or player.Parent ~= Players then return end
	stateRemote:FireClient(player, {
		snapshot = state:snapshot(player.UserId), action = action, ok = ok, notice = notice or "",
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
local function prompt(target, action, object, range)
	local value = Instance.new("ProximityPrompt")
	value.ActionText, value.ObjectText = action, object
	value.MaxActivationDistance, value.HoldDuration = range, 0.25
	value.RequiresLineOfSight, value.KeyboardKeyCode = false, Enum.KeyCode.E
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
local function protect(player, uid)
	local alive, distance = context(player, protectionMarker)
	local ok, reason
	if not alive or distance ~= distance or distance < 0 or distance > 12 then
		ok, reason = false, "InvalidContext"
	else
		ok, reason = state:protect(player.UserId, uid, alive)
	end
	reply(player, "Protect", ok, reason, "Selected item protected for one defeat. Seal is spent only if it saves the item.")
end

local extractPrompt = prompt(extraction, "Extract bag", "Camp · session only", 12)
extractPrompt.Triggered:Connect(function(player)
	if not validPrompt(extractPrompt, extraction) or not allowed(player, "Extract") then return end
	local alive, distance = context(player, extraction)
	local ok, count = state:extract(player.UserId, alive, distance)
	reply(player, "Extract", ok, count, "Extracted " .. tostring(count) .. " item(s). First extraction earns one seal.")
end)
local hatchPrompt = prompt(hatchMarker, "Hatch first egg", "Free hatch", 12)
hatchPrompt.Triggered:Connect(function(player)
	if not validPrompt(hatchPrompt, hatchMarker) or not allowed(player, "Hatch") then return end
	local snapshot = state:snapshot(player.UserId)
	local egg = snapshot and snapshot.bankedEggs[1]
	hatch(player, egg and egg.uid)
end)
local protectionPrompt = prompt(protectionMarker, "Choose protected item", "Earned protection", 12)
protectionPrompt.Triggered:Connect(function(player)
	if not validPrompt(protectionPrompt, protectionMarker) or not allowed(player, "ProtectHint") then return end
	local alive, distance = context(player, protectionMarker)
	if alive and distance == distance and distance <= 12 then
		send(player, "ProtectHint", true, "In your inventory, choose a temporary item and press Protect. One item maximum.")
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
	model.Name = kind == "Egg" and "LumipolEgg" or "Lumipol"
	local body = block(model, "Body", kind == "Egg" and Vector3.new(2, 2.8, 2) or Vector3.new(3, 2, 2.4),
		CFrame.new(position + Vector3.new(0, 2, 0)), Color3.fromRGB(121, 202, 160), Enum.PartType.Ball)
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
local spawnEncounter
spawnEncounter = function(target, kind)
	if runtime.Parent ~= map or not target:IsDescendantOf(map) then return end
	serial += 1
	local id = kind .. ":" .. serial
	if not state:registerEncounter(id, kind) then return end
	local model, body = visual(kind, target.Position)
	model:SetAttribute("EncounterId", id)
	local pickupPrompt = prompt(body, "Collect", kind == "Egg" and "Lumipol egg" or "Lumipol", 10)
	local connection
	connection = pickupPrompt.Triggered:Connect(function(player)
		if model.Parent ~= runtime or not validPrompt(pickupPrompt, body) or not allowed(player, "Pickup") then return end
		local alive, distance = context(player, body)
		local ok, reason = state:pickup(player.UserId, id, alive, distance)
		if ok then
			pickupPrompt.Enabled = false
			connection:Disconnect()
			model:Destroy()
			state:retireEncounter(id)
			task.delay(20, function() spawnEncounter(target, kind) end)
		end
		reply(player, "Pickup", ok, reason, "Collected temporary loot. Extract it at camp before defeat.")
	end)
end
spawnEncounter(creatureMarker, "Creature")
spawnEncounter(eggMarker, "Egg")

actionRemote.OnServerEvent:Connect(function(player, action, uid, ...)
	if type(action) ~= "string" or #action > 32 or select("#", ...) > 0 then return end
	if action ~= "RequestSnapshot" and action ~= "Equip" and action ~= "Protect" and action ~= "Hatch" then return end
	if action == "RequestSnapshot" then
		if uid ~= nil or not allowed(player, action) then return end
		send(player, action, true, "Session only: collection resets when you leave this server.")
		return
	end
	if type(uid) ~= "string" or #uid == 0 or #uid > 128 or not allowed(player, action) then return end
	if action == "Hatch" then hatch(player, uid)
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
		state:defeat(player.UserId, "life:" .. generation)
		send(player, "Defeat", true, "Defeated: unprotected temporary loot was lost. Banked eggs and registered pets remain.")
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
	send(player, "Respawn", true, "Return temporary loot to camp. Registered collection is session only.")
end
local function addPlayer(player)
	if records[player] then return end
	state:addPlayer(player.UserId)
	local record = { rates = {}, lastAny = -math.huge, generation = 0, defeated = false }
	records[player] = record
	record.characterConnection = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character then task.spawn(bindCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if not record then return end
	if record.deathConnection then record.deathConnection:Disconnect() end
	if record.characterConnection then record.characterConnection:Disconnect() end
	records[player] = nil
	state:removePlayer(player.UserId)
end)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
