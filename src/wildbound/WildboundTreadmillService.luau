-- Interactive treadmill service: lets players step onto or prompt-mount their base/camp treadmill,
-- visibly run on the belt, earn free Training walk levels + Esencia per lap, and dismount via Jump or button.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Treadmill = {}
Treadmill.__index = Treadmill

Treadmill.LAP_SECONDS = 8
Treadmill.STEP_HZ = 10
Treadmill.DISMOUNT_COOLDOWN = 2.5

local function flatLook(look)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-4 then return Vector3.new(0, 0, -1) end
	return flat.Unit
end

local function standFrame(belt, humanoid, root)
	local hipOffset = humanoid.RigType == Enum.HumanoidRigType.R15
		and (humanoid.HipHeight + root.Size.Y * 0.5)
		or 3
	local pos = belt.Position + Vector3.new(0, belt.Size.Y * 0.5 + hipOffset, 0)
	local dir = flatLook(belt.CFrame.LookVector)
	return CFrame.lookAt(pos, pos + dir)
end

function Treadmill.new(deps)
	local self = setmetatable({
		deps = deps,
		belts = {}, -- [beltPart] = { isHub = bool, ownerFn = fn? }
		mounted = {}, -- [player] = { belt, progress, character, humanoid, root, jumpConn, diedConn }
		occupants = {}, -- [beltPart] = player
		cooldowns = {}, -- [player] = os.clock()
		dwell = {}, -- [player] = { belt, since }
		remote = nil,
	}, Treadmill)
	return self
end

function Treadmill:isMounted(player)
	return self.mounted[player] ~= nil
end

function Treadmill:dismount(player, nudgeBack)
	local entry = self.mounted[player]
	if not entry then return end
	self.mounted[player] = nil
	if self.occupants[entry.belt] == player then
		self.occupants[entry.belt] = nil
	end
	self.cooldowns[player] = os.clock()
	self.dwell[player] = nil
	if entry.jumpConn then entry.jumpConn:Disconnect() end
	if entry.diedConn then entry.diedConn:Disconnect() end
	if entry.belt and entry.belt.Parent then
		entry.belt:SetAttribute("WildboundRunner", nil)
	end
	player:SetAttribute("WildboundOnTreadmill", nil)
	player:SetAttribute("WildboundTreadmillProgress", nil)
	local humanoid = entry.humanoid
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = true
	end
	if nudgeBack and entry.root and entry.root.Parent and entry.belt and entry.belt.Parent then
		local back = -flatLook(entry.belt.CFrame.LookVector)
		entry.root.CFrame = entry.root.CFrame + back * 3.5 + Vector3.new(0, 0.4, 0)
		entry.root.AssemblyLinearVelocity = Vector3.zero
	end
	if self.deps.onDismount then
		self.deps.onDismount(player)
	end
end

function Treadmill:canUseBelt(player, belt, info)
	local deps = self.deps
	if not belt or not belt:IsDescendantOf(workspace) then return false, "InvalidContext" end
	if not deps.alive(player) then return false, "InvalidContext" end
	if player:GetAttribute("WildboundCapturing") == true then return false, "Busy" end
	if deps.isCarrying and deps.isCarrying(player) then return false, "Carrying" end
	if info.isHub and deps.Bases and deps.ownerOf then
		local root = deps.rootOf(player)
		if not root then return false, "InvalidContext" end
		local dist = (root.Position - belt.Position).Magnitude
		local ok, why = deps.Bases.mayUse(deps.ownerOf(belt), player.UserId, dist, 10)
		if not ok then return false, why end
	end
	return true
end

function Treadmill:mount(player, belt)
	if self.mounted[player] then return end
	local info = self.belts[belt]
	if not info then return end
	local occupant = self.occupants[belt]
	if occupant and occupant ~= player then
		if self.deps.notice then
			self.deps.notice(player, false, self.deps.Text.TRAINING.busy)
		end
		return
	end
	local ok, why = self:canUseBelt(player, belt, info)
	if not ok then
		if why == "Carrying" and self.deps.notice then
			self.deps.notice(player, false, self.deps.Text.TRAINING.noCarry)
		elseif self.deps.refuse then
			self.deps.refuse(player, "Train", why)
		end
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return end

	self.dwell[player] = nil
	self.occupants[belt] = player
	local entry = {
		belt = belt,
		isHub = info.isHub,
		progress = 0,
		character = character,
		humanoid = humanoid,
		root = root,
	}
	self.mounted[player] = entry

	player:SetAttribute("WildboundOnTreadmill", true)
	player:SetAttribute("WildboundTreadmillProgress", 0)
	belt:SetAttribute("WildboundRunner", player.UserId)

	root.CFrame = standFrame(belt, humanoid, root)
	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	entry.jumpConn = humanoid.Jumping:Connect(function(active)
		if active then self:dismount(player, false) end
	end)
	entry.diedConn = humanoid.Died:Connect(function()
		self:dismount(player, false)
	end)
end

function Treadmill:bindBelt(belt, isHub)
	if not belt or not belt:IsA("BasePart") or self.belts[belt] then return end
	if not belt:IsDescendantOf(workspace) then return end
	self.belts[belt] = { isHub = isHub == true }

	local existing = belt:FindFirstChild("WildboundTreadmillMountPrompt")
	if existing then existing:Destroy() end

	local Text = self.deps.Text
	local keySpec = self.deps.Keys.HUB.treadmill
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildboundTreadmillMountPrompt"
	prompt.ActionText = Text.TRAINING.mountPrompt
	prompt.ObjectText = Text.TRAINING.mountObject
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode[keySpec.key]
	prompt.GamepadKeyCode = Enum.KeyCode[keySpec.pad]
	prompt.UIOffset = Vector2.new(keySpec.offset[1], keySpec.offset[2])
	if isHub then
		prompt:SetAttribute("WildboundHubStation", "treadmill")
	end
	prompt.Parent = belt

	prompt.Triggered:Connect(function(player)
		if self.mounted[player] then
			self:dismount(player, true)
		else
			self:mount(player, belt)
		end
	end)
	belt.AncestryChanged:Connect(function()
		if not belt:IsDescendantOf(workspace) then
			local occ = self.occupants[belt]
			if occ then self:dismount(occ, false) end
			self.belts[belt] = nil
		end
	end)
end

function Treadmill:step(dt)
	local now = os.clock()
	for player, entry in pairs(self.mounted) do
		local belt = entry.belt
		local root = entry.root
		local humanoid = entry.humanoid
		if player.Parent ~= Players or not belt.Parent or not root.Parent or not humanoid.Parent
			or humanoid.Health <= 0 or player.Character ~= entry.character
			or (root.Position - belt.Position).Magnitude > 6.5 then
			self:dismount(player, false)
		else
			if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
			if humanoid.AutoRotate then humanoid.AutoRotate = false end
			root.CFrame = standFrame(belt, humanoid, root)
			root.AssemblyLinearVelocity = Vector3.zero
			entry.progress += dt / Treadmill.LAP_SECONDS
			if entry.progress >= 1 then
				entry.progress -= 1
				if self.deps.onLap then
					local info = self.deps.onLap(player, belt, entry.isHub)
					if info and self.remote then
						self.remote:FireClient(player, "lap", info)
					end
				end
			end
			player:SetAttribute("WildboundTreadmillProgress", math.clamp(entry.progress, 0, 1))
		end
	end

	-- Step-on auto-mount: standing on the center of your own treadmill belt for 0.35s mounts automatically.
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.mounted[player] and (not self.cooldowns[player] or now - self.cooldowns[player] >= Treadmill.DISMOUNT_COOLDOWN) then
			local root = self.deps.rootOf(player)
			local foundBelt = nil
			if root and self.deps.alive(player) then
				for belt, info in pairs(self.belts) do
					if not self.occupants[belt] and belt:IsDescendantOf(workspace) then
						local rel = belt.CFrame:PointToObjectSpace(root.Position)
						if math.abs(rel.X) <= 1.25 and math.abs(rel.Z) <= 2.7 and rel.Y >= 0.5 and rel.Y <= 4.5 then
							if self:canUseBelt(player, belt, info) then
								foundBelt = belt
								break
							end
						end
					end
				end
			end
			if foundBelt then
				local d = self.dwell[player]
				if not d or d.belt ~= foundBelt then
					self.dwell[player] = { belt = foundBelt, since = now }
				elseif now - d.since >= 0.35 then
					self:mount(player, foundBelt)
				end
			else
				self.dwell[player] = nil
			end
		end
	end
end

function Treadmill:start(networkFolder, campBelt)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Treadmill"
	remote.Parent = networkFolder
	self.remote = remote

	remote.OnServerEvent:Connect(function(player, action)
		if action == "dismount" and self.mounted[player] then
			self:dismount(player, true)
		end
	end)

	if campBelt then
		self:bindBelt(campBelt, false)
	end

	local function bindStation(station)
		local parent = station.Parent
		local belt = parent and parent:FindFirstChild("TreadmillBelt")
		if belt then self:bindBelt(belt, true) end
	end
	for _, station in ipairs(CollectionService:GetTagged("WildboundTrainingStation")) do
		bindStation(station)
	end
	CollectionService:GetInstanceAddedSignal("WildboundTrainingStation"):Connect(bindStation)

	Players.PlayerRemoving:Connect(function(player)
		self:dismount(player, false)
		self.cooldowns[player] = nil
		self.dwell[player] = nil
	end)

	task.spawn(function()
		local interval = 1 / Treadmill.STEP_HZ
		while true do
			local dt = task.wait(interval)
			self:step(dt)
		end
	end)
	return self
end

return Treadmill