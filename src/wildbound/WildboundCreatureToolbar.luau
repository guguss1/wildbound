-- Manages hatched creatures in the player's Roblox Toolbar (Backpack Tools) and depositing them onto the player's Base Farm floor.
-- PF3 (user decision 2026-11-14): a creature is deposited only on the player's OWN base pad; a deposited creature stops
-- following the player (deps.unequip) and taking it back to the hotbar never equips it; tools are rebuilt once per
-- respawn, never duplicated. PF7: a species with an uploaded icon (Toolbar.ICONS, uploaded with the user's approval
-- 2026-11-15) shows it in the hotbar; any other species keeps an empty TextureId and shows its name.
-- CE2: a Caramelo pet (deps.farmModel returns a model for it) stands in the farm as its real rig, scaled down, feet on
-- its pivot; every farm model carries FarmWalking (true while it walks) so the pet's walk clip can play.
-- PF4: the farm itself is State's (placeInFarm / takeFromFarm, saved by WildboundRecord schema 5, capped by the
-- snapshot's farmSlots); this module only builds its models and rebuilds a saved farm on the own pad on join.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Toolbar = {}
Toolbar.__index = Toolbar

local UID = "WildboundCreatureUid"
local DEPOSIT_REACH = 20 -- studs from the own pad when the base zone does not report the player inside

-- PF7: hotbar icons by species (source assets/icons/lumipol-hotbar-icon-256.png). A missing species has no icon.
-- CE2 (uploaded with the user's approval 2026-11-15): the Caramelo pets, from the pack's turnarounds
-- (assets/icons/<species>-hotbar-icon-256.png).
-- IC (2026-11-16): the uploads are user-owned and the game is the group's, so a plain rbxassetid image fails
-- ("Requester does not have permission"). The thumbnail form loads (a preload test in Play), so ICONS are built from
-- ICON_IDS in that form. A new icon is one more id here.
Toolbar.ICON_IDS = {
	Lumipol = 121561289565386,
	Gomibu = 130041727906990,
	Flanfuria = 106158128076232,
	Tortidragon = 85016154045779,
}
Toolbar.ICONS = {}
for species, id in pairs(Toolbar.ICON_IDS) do
	Toolbar.ICONS[species] = "rbxthumb://type=Asset&id=" .. string.format("%d", id) .. "&w=150&h=150"
end
Toolbar.WALKING = "FarmWalking" -- CE2: farm model attribute, true while it walks

-- PF6 (user playtest 2026-11-15): farm creatures walk around the whole own pad instead of standing still.
Toolbar.WANDER = {
	speed = 5, -- studs per second, a calm walk
	margin = 2.5, -- studs kept from the pad edges
	pauseMin = 1, -- seconds standing between walks
	pauseMax = 4,
	hop = 0.25, -- studs of the hop while walking (only up: the lowest point never goes below the pad top)
	hopRate = 9, -- radians per second of the hop
}

function Toolbar.new(deps)
	local self = setmetatable({
		-- { state, visual, send, isInsideBase, unequip, Art, Species, Text, tagged?, players? }
		-- unequip(player, uid): the server puts that creature back in the collection when it is the companion out.
		-- PF6: heartbeat? (a Connect-able signal, default RunService.Heartbeat), random? (a Random, default a new one).
		-- CE2: farmModel?(species, spot, look) -> model, body or nil: a pet's own farm model, its pivot on its feet.
		deps = deps,
		placed = {}, -- [userId] = { [uid] = { model = Model, species = string, wander? } }: the farm models only (PF4, PF6)
		random = deps.random or Random.new(),
		wanderConnection = nil, -- PF6: one Heartbeat connection for every farm model, only while one exists
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
	self:refreshWander()
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
	local creatureModel, body = nil, nil
	if self.deps.farmModel then creatureModel, body = self.deps.farmModel(species, spotWorld, lookDir) end
	local pet = creatureModel ~= nil
	if not pet then creatureModel, body = self.deps.visual("Creature", spotWorld, species, 0.75) end
	creatureModel.Name = "WildboundFarmCreature"
	creatureModel:SetAttribute("OwnerUserId", player.UserId)
	creatureModel:SetAttribute(UID, uid)
	creatureModel:SetAttribute("WildboundSpecies", species)
	local goalFrame = CFrame.lookAt(spotWorld, spotWorld + lookDir)
	if pet then
		creatureModel:PivotTo(goalFrame) -- CE2: the rig's pivot is on its feet
	elseif not creatureModel:GetAttribute(self.deps.Art.CONFIG.ATTRIBUTE) and body then
		body.CFrame = goalFrame + Vector3.new(0, body.Size.Y / 2, 0)
	else
		creatureModel:PivotTo(goalFrame)
	end
	creatureModel.Parent = baseModel
	-- Playtest (2026-11-14): the creature model reaches below its body/pivot, so it sank into the base floor. Stand its
	-- lowest point on the pad's top surface (spotWorld is on that surface).
	-- CE2: a pet rig stands on its pivot (its hidden root reaches below the feet), so it is not lifted.
	if not pet then
		local boxFrame, boxSize = creatureModel:GetBoundingBox()
		local lift = spotWorld.Y - (boxFrame.Position.Y - boxSize.Y / 2)
		if math.abs(lift) > 0.01 then creatureModel:PivotTo(creatureModel:GetPivot() + Vector3.new(0, lift, 0)) end
	end
	local pad = self:basePadOf(player.UserId)

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
	self.placed[player.UserId][uid] = { model = creatureModel, species = species,
		wander = pad and self:newWander(pad, creatureModel, spotWorld, lookDir) or nil }
	self:refreshWander()
	return creatureModel
end

-- PF3: back to the hotbar as a tool; never equipped as the companion. PF4: State takes it out of the (saved) farm.
function Toolbar:pickUp(player, uid)
	if not self.deps.state:takeFromFarm(player.UserId, uid, true) then return false end
	local userMap = self.placed[player.UserId]
	local entry = userMap and userMap[uid]
	if entry and entry.model then entry.model:Destroy() end
	if userMap then userMap[uid] = nil end
	self:refreshWander()
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
	self:refreshWander()
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

-- PF6: the wander of one farm model, in the pad's own space. offset keeps the model's pivot (and so its lifted
-- bounding box) where spawnFarmModel stood it, relative to a ground frame on the pad top facing the walk.
function Toolbar:newWander(pad, model, spotWorld, lookDir)
	local ground = CFrame.lookAt(spotWorld, spotWorld + lookDir)
	local here = pad.CFrame:PointToObjectSpace(spotWorld)
	local W = Toolbar.WANDER
	local halfX = math.max(0, pad.Size.X / 2 - W.margin)
	local halfZ = math.max(0, pad.Size.Z / 2 - W.margin)
	local facing = pad.CFrame:VectorToObjectSpace(lookDir)
	facing = Vector3.new(facing.X, 0, facing.Z)
	return {
		pad = pad,
		offset = ground:ToObjectSpace(model:GetPivot()),
		x = math.clamp(here.X, -halfX, halfX),
		z = math.clamp(here.Z, -halfZ, halfZ),
		dir = facing.Magnitude > 0.01 and facing.Unit or Vector3.new(0, 0, -1),
		target = nil,
		wait = self.random:NextNumber(0, W.pauseMax),
		phase = 0,
	}
end

-- PF6: how many farm models wander now (for tests and the Heartbeat cleanup).
function Toolbar:wanderCount()
	local count = 0
	for _, map in pairs(self.placed) do
		for _, entry in pairs(map) do
			if entry.wander and entry.model and entry.model.Parent then count += 1 end
		end
	end
	return count
end

-- PF6: one Heartbeat for all the farm models, connected only while at least one exists.
function Toolbar:refreshWander()
	local needed = self:wanderCount() > 0
	if needed and not self.wanderConnection then
		local heartbeat = self.deps.heartbeat or RunService.Heartbeat
		self.wanderConnection = heartbeat:Connect(function(dt) self:stepFarm(dt) end)
	elseif not needed and self.wanderConnection then
		self.wanderConnection:Disconnect()
		self.wanderConnection = nil
	end
end

-- PF6: pause, pick a point inside the pad margin, walk there facing it at a calm pace with a small hop, repeat.
local function stepWander(wander, dt, random)
	local W = Toolbar.WANDER
	local pad = wander.pad
	local halfX = math.max(0, pad.Size.X / 2 - W.margin)
	local halfZ = math.max(0, pad.Size.Z / 2 - W.margin)
	local hop = 0
	if wander.target then
		local towards = wander.target - Vector3.new(wander.x, 0, wander.z)
		local distance = towards.Magnitude
		local stride = W.speed * dt
		if distance <= stride then
			wander.x, wander.z = wander.target.X, wander.target.Z
			wander.target = nil
			wander.wait = random:NextNumber(W.pauseMin, W.pauseMax)
		else
			local step = towards / distance * stride
			wander.x, wander.z = wander.x + step.X, wander.z + step.Z
			wander.phase += W.hopRate * dt
			hop = math.abs(math.sin(wander.phase)) * W.hop
		end
	else
		wander.wait -= dt
		if wander.wait <= 0 then
			local target = Vector3.new(random:NextNumber(-halfX, halfX), 0, random:NextNumber(-halfZ, halfZ))
			local towards = target - Vector3.new(wander.x, 0, wander.z)
			if towards.Magnitude > 0.05 then
				wander.target, wander.dir, wander.phase = target, towards.Unit, 0
			else
				wander.wait = random:NextNumber(W.pauseMin, W.pauseMax)
			end
		end
	end
	-- A pad resized while the model stands keeps it inside the new bounds.
	wander.x, wander.z = math.clamp(wander.x, -halfX, halfX), math.clamp(wander.z, -halfZ, halfZ)
	local spot = pad.CFrame:PointToWorldSpace(Vector3.new(wander.x, pad.Size.Y / 2, wander.z))
	local look = pad.CFrame:VectorToWorldSpace(wander.dir)
	return CFrame.lookAt(spot, spot + look) * CFrame.new(0, hop, 0) * wander.offset
end

-- PF6: one cheap step for every farm model (one PivotTo each); a model or pad that is gone leaves the wander.
function Toolbar:stepFarm(dt)
	local gone = false
	for _, map in pairs(self.placed) do
		for _, entry in pairs(map) do
			local wander, model = entry.wander, entry.model
			if wander and model and model.Parent and wander.pad.Parent then
				local hadTarget = wander.target ~= nil
				model:PivotTo(stepWander(wander, dt, self.random))
				-- CE2: told only when it changes (a walk starts or ends), so the pet's clip follows the walk
				local walking = hadTarget or wander.target ~= nil
				if entry.walking ~= walking then
					entry.walking = walking
					model:SetAttribute(Toolbar.WALKING, walking)
				end
			elseif wander then
				entry.wander = nil
				gone = true
			end
		end
	end
	if gone then self:refreshWander() end
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
	tool.TextureId = Toolbar.ICONS[species] or "" -- PF7: the hotbar shows the icon; the name stays for the tooltip
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
