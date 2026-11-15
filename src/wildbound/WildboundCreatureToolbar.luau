-- Manages hatched creatures in the player's Roblox Toolbar (Backpack Tools) and depositing them onto the player's Base Farm floor.
-- PF3 (user decision 2026-11-14): a creature is deposited only on the player's OWN base pad; a deposited creature stops
-- following the player (deps.unequip) and taking it back to the hotbar never equips it; tools are rebuilt once per
-- respawn, never duplicated. No icon asset is uploaded: TextureId stays empty until an icon upload is approved.
-- PF4: the farm itself is State's (placeInFarm / takeFromFarm, saved by WildboundRecord schema 5, capped by the
-- snapshot's farmSlots); this module only builds its models and rebuilds a saved farm on the own pad on join.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Toolbar = {}
Toolbar.__index = Toolbar

local UID = "WildboundCreatureUid"
local DEPOSIT_REACH = 20 -- studs from the own pad when the base zone does not report the player inside

function Toolbar.new(deps)
	local self = setmetatable({
		-- { state, visual, send, isInsideBase, unequip, Art, Species, Text, tagged?, players? }
		-- unequip(player, uid): the server puts that creature back in the collection when it is the companion out.
		deps = deps,
		placed = {}, -- [userId] = { [uid] = { model = Model, species = string } }: the farm models only (PF4)
	}, Toolbar)
	local players = deps.players or Players
	players.PlayerRemoving:Connect(function(player)
		self:clearPlayer(player.UserId)
	end)
	return self
end

function Toolbar:words()
	local text = self.deps.Text
	return text and text.FARM or {}
end

function Toolbar:displayName(species)
	local text = self.deps.Text
	local names = text and text.CARD and text.CARD.species
	return names and names[species] or species
end

function Toolbar:clearPlayer(userId)
	local map = self.placed[userId]
	if map then
		for _, entry in pairs(map) do
			if entry.model then entry.model:Destroy() end
		end
		self.placed[userId] = nil
	end
end

function Toolbar:tagged(tag)
	if self.deps.tagged then return self.deps.tagged(tag) end
	return CollectionService:GetTagged(tag)
end

-- The player's own base pad only (PF3: no fallback to another base's pad).
function Toolbar:basePadOf(userId)
	for _, model in ipairs(self:tagged("WildboundBaseSlot")) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == userId then
			local pad = model:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then return pad, model end
		end
	end
	return nil, nil
end

local function creatureTools(player)
	local found = {}
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute(UID) ~= nil then table.insert(found, item) end
			end
		end
	end
	return found
end

local function registeredPet(snapshot, uid)
	for _, pet in ipairs(snapshot and snapshot.registered or {}) do
		if pet.uid == uid then return pet end
	end
	return nil
end

-- PF4: the uids State holds in the farm.
local function farmSet(snapshot)
	local set = {}
	for _, uid in ipairs(snapshot and snapshot.farm or {}) do set[uid] = true end
	return set
end

-- PF4: where a saved farm creature stands when it is rebuilt: its place in a small grid on the own pad.
local function slotSpot(pad, index)
	local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
	local halfX = math.max(2, pad.Size.X / 2 - 3.0)
	local halfZ = math.max(2, pad.Size.Z / 2 - 3.0)
	local localPos = Vector3.new(math.clamp((column - 1.5) * 4.5, -halfX, halfX), pad.Size.Y / 2,
		math.clamp((row - 0.5) * 4.5, -halfZ, halfZ))
	return pad.CFrame:PointToWorldSpace(localPos), -pad.CFrame.LookVector
end

function Toolbar:depositInFarm(player, uid, species, tool)
	local words = self:words()
	local snapshot = self.deps.state:snapshot(player.UserId)
	local pet = registeredPet(snapshot, uid)
	if not pet or farmSet(snapshot)[uid] then
		if tool and tool.Parent then tool:Destroy() end
		return false
	end
	species = pet.species or species or "Lumipol"
	local pad, baseModel = self:basePadOf(player.UserId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = self.deps.isInsideBase and self.deps.isInsideBase(player) == true
	if not pad or not root or (not inside and (root.Position - pad.Position).Magnitude > DEPOSIT_REACH) then
		self.deps.send(player, "Notice", false, words.notInBase)
		return false
	end
	-- PF4: a full farm refuses before anything changes (the companion keeps following, the tool stays).
	local slots = snapshot.farmSlots or 0
	if #(snapshot.farm or {}) >= slots then
		self.deps.send(player, "Notice", false, string.format(words.farmFull or "%d", slots))
		return false
	end

	-- Compute spot in front of the player, clamped inside the base Pad
	local targetWorld = root.Position + root.CFrame.LookVector * 4.5
	local localPos = pad.CFrame:PointToObjectSpace(targetWorld)
	local margin = 3.0
	local halfX = math.max(2, pad.Size.X / 2 - margin)
	local halfZ = math.max(2, pad.Size.Z / 2 - margin)
	local clampedLocal = Vector3.new(
		math.clamp(localPos.X, -halfX, halfX),
		pad.Size.Y / 2,
		math.clamp(localPos.Z, -halfZ, halfZ)
	)
	local spotWorld = pad.CFrame:PointToWorldSpace(clampedLocal)
	local lookDir = Vector3.new(root.Position.X - spotWorld.X, 0, root.Position.Z - spotWorld.Z)
	if lookDir.Magnitude < 0.05 then lookDir = -pad.CFrame.LookVector end
	lookDir = lookDir.Unit

	-- PF4: a creature in the farm no longer follows the player: State records the farm first (saved), then the server
	-- clears the companion. A refusal builds nothing and leaves the companion as it was.
	if not self.deps.state:placeInFarm(player.UserId, uid, true, slots) then
		self.deps.send(player, "Notice", false, string.format(words.farmFull or "%d", slots))
		return false
	end
	if self.deps.unequip then self.deps.unequip(player, uid) end
	self:spawnFarmModel(player, uid, species, spotWorld, lookDir, baseModel)
	for _, item in ipairs(creatureTools(player)) do
		if item:GetAttribute(UID) == uid then item:Destroy() end
	end
	if tool and tool.Parent then tool:Destroy() end
	self.deps.send(player, "Notice", true, string.format(words.placed or "%s", self:displayName(species)))
	return true
end

-- The farm model with its pickup prompt, parented to the own base model.
function Toolbar:spawnFarmModel(player, uid, species, spotWorld, lookDir, baseModel)
	local words = self:words()
	local creatureModel, body = self.deps.visual("Creature", spotWorld, species, 0.75)
	creatureModel.Name = "WildboundFarmCreature"
	creatureModel:SetAttribute("OwnerUserId", player.UserId)
	creatureModel:SetAttribute(UID, uid)
	creatureModel:SetAttribute("WildboundSpecies", species)
	local goalFrame = CFrame.lookAt(spotWorld, spotWorld + lookDir)
	if not creatureModel:GetAttribute(self.deps.Art.CONFIG.ATTRIBUTE) and body then
		body.CFrame = goalFrame + Vector3.new(0, body.Size.Y / 2, 0)
	else
		creatureModel:PivotTo(goalFrame)
	end
	creatureModel.Parent = baseModel

	local displayName = self:displayName(species)
	local promptTarget = body or creatureModel:FindFirstChildWhichIsA("BasePart", true)
	if promptTarget then
		local p = Instance.new("ProximityPrompt")
		p.Name = "PickupFarmCreaturePrompt"
		p.ActionText = words.pickupAction
		p.ObjectText = displayName
		p.HoldDuration = 0.2
		p.MaxActivationDistance = 7
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.G
		p.Parent = promptTarget
		p.Triggered:Connect(function(who)
			if who ~= player then return end
			self:pickUp(player, uid)
		end)
	end

	self.placed[player.UserId] = self.placed[player.UserId] or {}
	self.placed[player.UserId][uid] = { model = creatureModel, species = species }
	return creatureModel
end

-- PF3: back to the hotbar as a tool; never equipped as the companion. PF4: State takes it out of the (saved) farm.
function Toolbar:pickUp(player, uid)
	if not self.deps.state:takeFromFarm(player.UserId, uid, true) then return false end
	local userMap = self.placed[player.UserId]
	local entry = userMap and userMap[uid]
	if entry and entry.model then entry.model:Destroy() end
	if userMap then userMap[uid] = nil end
	local snapshot = self.deps.state:snapshot(player.UserId)
	self:syncPlayer(player, snapshot)
	local pet = registeredPet(snapshot, uid)
	local species = entry and entry.species or pet and pet.species or "Lumipol"
	self.deps.send(player, "Notice", true, string.format(self:words().stored or "%s", self:displayName(species)))
	return true
end

-- PF4: the farm models follow State: a saved farm creature is rebuilt on the own pad (on join, respawn or any sync)
-- once, and a model whose creature left the farm is removed.
function Toolbar:syncFarm(player, snapshot)
	local farm = farmSet(snapshot)
	local userMap = self.placed[player.UserId] or {}
	for uid, entry in pairs(userMap) do
		if not farm[uid] or not (entry.model and entry.model.Parent) then
			if entry.model then entry.model:Destroy() end
			userMap[uid] = nil
		end
	end
	local pad, baseModel = self:basePadOf(player.UserId)
	if not pad then return end
	for index, uid in ipairs(snapshot.farm or {}) do
		local pet = not userMap[uid] and registeredPet(snapshot, uid)
		if pet then
			local spot, look = slotSpot(pad, index)
			self:spawnFarmModel(player, uid, pet.species or "Lumipol", spot, look, baseModel)
		end
	end
end

-- PF3: a newborn (or any creature) that the hatch made the companion goes to the hotbar instead.
function Toolbar:stow(player, uid)
	if self.deps.unequip then return self.deps.unequip(player, uid) end
	return false
end

function Toolbar:buildTool(player, pet)
	local species = pet.species or "Lumipol"
	local tool = Instance.new("Tool")
	tool.Name = self:displayName(species)
	tool.ToolTip = self:words().toolTip or ""
	tool.TextureId = "" -- no icon asset until an upload is approved
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute(UID, pet.uid)
	tool:SetAttribute("WildboundSpecies", species)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local creatureModel = self.deps.visual("Creature", handle.Position, species, 0.52)
	local targetFrame = handle.CFrame * CFrame.new(0, -0.45, -0.6)
	creatureModel:PivotTo(targetFrame)
	for _, item in ipairs(creatureModel:GetDescendants()) do
		if item:IsA("BasePart") then
			if item.Name == "Body" and creatureModel:GetAttribute(self.deps.Art.CONFIG.ATTRIBUTE) then
				item:Destroy()
			else
				item.Anchored = false
				item.CanCollide = false
				item.CanTouch = false
				item.CanQuery = false
				item.Massless = true
				item.Parent = tool
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = item
				weld.Parent = item
			end
		end
	end
	creatureModel:Destroy()

	tool.Activated:Connect(function()
		self:depositInFarm(player, pet.uid, species, tool)
	end)
	return tool
end

-- One tool per registered creature that is not in the farm: duplicates and tools of creatures no longer owned (or now
-- in the farm) are removed, so it is safe to call on every hatch, pickup and respawn.
function Toolbar:syncPlayer(player, snapshot)
	if not player or not player.Parent then return end
	snapshot = snapshot or self.deps.state:snapshot(player.UserId)
	if not snapshot or not snapshot.registered then return end
	self:syncFarm(player, snapshot)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local farm = farmSet(snapshot)
	local wanted = {}
	for _, pet in ipairs(snapshot.registered) do
		if not farm[pet.uid] then wanted[pet.uid] = pet end
	end
	local have = {}
	for _, item in ipairs(creatureTools(player)) do
		local uid = item:GetAttribute(UID)
		if not wanted[uid] or have[uid] then
			item:Destroy()
		else
			have[uid] = item
		end
	end
	for _, pet in ipairs(snapshot.registered) do
		if wanted[pet.uid] and not have[pet.uid] then
			have[pet.uid] = true
			local tool = self:buildTool(player, pet)
			tool.Parent = backpack
		end
	end
end

-- PF3: a new character gets a new Backpack; rebuild the tools there once it exists.
function Toolbar:respawn(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack then self:syncPlayer(player) end
end

return Toolbar
