-- Manages hatched creatures in the player's Roblox Toolbar (Backpack Tools) and depositing them onto the player's Base Farm floor.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Toolbar = {}
Toolbar.__index = Toolbar

function Toolbar.new(deps)
	local self = setmetatable({
		deps = deps, -- { state, visual, send, isInsideBase, Art, Species, Text }
		placed = {}, -- [userId] = { [uid] = { model = Model, species = string } }
	}, Toolbar)
	Players.PlayerRemoving:Connect(function(player)
		self:clearPlayer(player.UserId)
	end)
	return self
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

function Toolbar:basePadOf(userId)
	for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == userId then
			local pad = model:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then return pad, model end
		end
	end
	return nil, nil
end

local function findToolByUid(player, uid)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("WildboundCreatureUid") == uid then
				return item
			end
		end
	end
	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("WildboundCreatureUid") == uid then
				return item
			end
		end
	end
	return nil
end

function Toolbar:depositInFarm(player, uid, species, tool)
	local pad, baseModel = self:basePadOf(player.UserId)
	local inside = self.deps.isInsideBase and self.deps.isInsideBase(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not pad and root then
		-- Fallback: nearest owned/any base pad within 20 studs
		for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do
			local p = model:FindFirstChild("Pad")
			if p and p:IsA("BasePart") and (p.Position - root.Position).Magnitude <= 20 then
				pad, baseModel = p, model
				inside = true
				break
			end
		end
	end
	if not pad or not root or (not inside and (root.Position - pad.Position).Magnitude > 20) then
		self.deps.send(player, "Notice", false, "Entrá a tu base para dejar la criatura en la granja.")
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

	local creatureModel, body = self.deps.visual("Creature", spotWorld, species, 0.75)
	creatureModel.Name = "WildboundFarmCreature"
	creatureModel:SetAttribute("OwnerUserId", player.UserId)
	creatureModel:SetAttribute("WildboundCreatureUid", uid)
	creatureModel:SetAttribute("WildboundSpecies", species)
	local goalFrame = CFrame.lookAt(spotWorld, spotWorld + lookDir)
	if not creatureModel:GetAttribute(self.deps.Art.CONFIG.ATTRIBUTE) and body then
		body.CFrame = goalFrame + Vector3.new(0, body.Size.Y / 2, 0)
	else
		creatureModel:PivotTo(goalFrame)
	end
	creatureModel.Parent = baseModel or workspace

	local promptTarget = body or creatureModel:FindFirstChildWhichIsA("BasePart", true)
	if promptTarget then
		local p = Instance.new("ProximityPrompt")
		p.Name = "PickupFarmCreaturePrompt"
		p.ActionText = "Guardar en barra"
		p.ObjectText = (species == "LumipolVioleta" and "Lumipol Violeta" or "Lumipol")
		p.HoldDuration = 0.2
		p.MaxActivationDistance = 7
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.G
		p.Parent = promptTarget
		p.Triggered:Connect(function(who)
			if who ~= player then return end
			local userMap = self.placed[player.UserId]
			if userMap and userMap[uid] then
				if userMap[uid].model then userMap[uid].model:Destroy() end
				userMap[uid] = nil
			end
			local snap = self.deps.state:snapshot(player.UserId)
			self:syncPlayer(player, snap)
			self.deps.send(player, "Notice", true, "Guardaste la criatura en tu barra de herramientas.")
		end)
	end

	self.placed[player.UserId] = self.placed[player.UserId] or {}
	self.placed[player.UserId][uid] = { model = creatureModel, species = species }

	if tool and tool.Parent then
		tool:Destroy()
	end
	local displayName = species == "LumipolVioleta" and "Lumipol Violeta" or "Lumipol"
	self.deps.send(player, "Notice", true, "¡Dejaste tu " .. displayName .. " en la base!")
	return true
end

function Toolbar:buildTool(player, pet)
	local species = pet.species or "Lumipol"
	local displayName = species == "LumipolVioleta" and "Lumipol Violeta" or "Lumipol"
	local tool = Instance.new("Tool")
	tool.Name = displayName
	tool.ToolTip = "Clic en tu base para dejarla en la granja"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WildboundCreatureUid", pet.uid)
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

function Toolbar:syncPlayer(player, snapshot)
	if not player or not player.Parent then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	snapshot = snapshot or self.deps.state:snapshot(player.UserId)
	if not snapshot or not snapshot.registered then return end

	local placedMap = self.placed[player.UserId] or {}
	for _, pet in ipairs(snapshot.registered) do
		if not placedMap[pet.uid] and not findToolByUid(player, pet.uid) then
			local tool = self:buildTool(player, pet)
			tool.Parent = backpack
		end
	end
end

return Toolbar
