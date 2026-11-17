-- Caramelo v3 raft service (docs/design/wildbound-caramelo-v3-plan.md V3-D13): runs WildboundCandyRaft in the place.
-- Once the live biome carries the v3 mark (the migration tool laid the river and the docks), it builds the Balsa
-- Banana Split at runtime (the kit's CV3_BananaRaft from ServerStorage.WildboundAssets.CandyKitV3, or a plain-part
-- placeholder; the place file never needs saving) on the lane of WildboundCandyV3Layout.RAFT, with a seat at the kit's
-- SeatAnchor and a ProximityPrompt to board. Server-authoritative: the server decides who boards (one rider, near
-- the docked raft, alive), seats them, moves the anchored raft along the lane every Heartbeat (the seated character
-- rides with it), sets the rider down on the far dock, and brings an abandoned raft back to its home dock. Clients only
-- ask to leave ({ action = "Leave" } on ReplicatedStorage.WildboundNetwork.CandyRaftEvent), validated and rate
-- limited; the server tells each rider what happened. Riding is free: there is no price and no product here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Raft = require(ReplicatedStorage:WaitForChild("WildboundCandyRaft"))
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local V3 = require(ServerStorage:WaitForChild("WildboundCandyV3Layout"))
local specModule = ServerStorage:WaitForChild("WildboundCandyV3KitSpec", 10)
local okSpec, KitSpec = pcall(function() return specModule and require(specModule) end)
local raftSpec = okSpec and type(KitSpec) == "table" and KitSpec[V3.RAFT.asset] or nil

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 120)
if not biome then return end
while biome:GetAttribute(V3.MARK) == nil do
	biome:GetAttributeChangedSignal(V3.MARK):Wait()
end

local surface = V3.surfaceY(Layout.FLOOR_TOP)
local lane = V3.raftLane(Layout.CENTRE)
local state = assert(Raft.new(lane, V3.RAFT.homeDock))
local stands = {}
for i, d in ipairs(V3.DOCKS) do
	-- review m6: on top of the dock deck (surface + deckOver), a root's height above it
	stands[i] = Vector3.new(Layout.CENTRE.x + d.standX, surface + V3.DOCK.deckOver + 3, Layout.CENTRE.z + d.standZ)
end

-- The raft model --------------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "WildboundCandyRaft"
folder.Parent = workspace

local function quiet(part)
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
end

local function hexColor(hex)
	local n = tonumber(hex, 16) or 0
	return Color3.fromRGB(bit32.rshift(n, 16) % 256, bit32.rshift(n, 8) % 256, n % 256)
end

local function buildModel()
	local assets = ServerStorage:FindFirstChild("WildboundAssets")
	local kit = assets and assets:FindFirstChild(V3.KIT_FOLDER)
	local source = kit and kit:FindFirstChild(V3.RAFT.asset)
	local m
	if source and source:IsA("Model") then
		m = source:Clone()
		local colors = {}
		for _, piece in pairs(raftSpec and raftSpec.pieces or {}) do colors[piece.object] = piece.color end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d.Parent = nil
			elseif d:IsA("BasePart") then
				quiet(d)
				if colors[d.Name] then d.Color = hexColor(colors[d.Name]) end
			end
		end
		m:SetAttribute("Placeholder", false)
	else
		-- placeholder: a banana hull, three scoops and a cherry; pivot at the waterline like the kit's
		m = Instance.new("Model")
		local function piece(name, shape, size, offset, color)
			local p = Instance.new("Part")
			p.Name, p.Shape, p.Size, p.Color = name, shape, size, color
			p.Material = Enum.Material.SmoothPlastic
			p.CFrame = CFrame.new(offset)
			quiet(p)
			p.Parent = m
			return p
		end
		piece("Hull", Enum.PartType.Block, Vector3.new(7, 1.9, 12.4), Vector3.new(0, -0.3, 0), Color3.fromRGB(245, 217, 122))
		piece("ScoopPink", Enum.PartType.Ball, Vector3.new(3, 3, 3), Vector3.new(0, 1.6, -3.6), Color3.fromRGB(244, 154, 193))
		piece("ScoopVanilla", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), Vector3.new(-2, 1.4, -2.4), Color3.fromRGB(247, 227, 161))
		piece("Cherry", Enum.PartType.Ball, Vector3.new(1, 1, 1), Vector3.new(0, 3.4, -3.6), Color3.fromRGB(215, 25, 47))
		m.WorldPivot = CFrame.new()
		m:SetAttribute("Placeholder", true)
	end
	m.Name = "BalsaBananaSplit"
	-- the seat at the kit's SeatAnchor (Roblox local of the pivot), facing -Z
	local seatAt = raftSpec and raftSpec.seat and raftSpec.seat.pos or { 0, 1.2, 1.6 }
	local seat = Instance.new("Seat")
	seat.Name = "RaftSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Transparency = 1
	seat.CFrame = m:GetPivot() * CFrame.new(seatAt[1], seatAt[2], seatAt[3])
	seat.Anchored, seat.CanCollide, seat.CanTouch, seat.CanQuery = true, false, false, false
	seat.Parent = m
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 3, 0)
	anchor.Parent = seat
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = Text.CANDY_RAFT.prompt, Text.CANDY_RAFT.object
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Raft.BOARD_STUDS
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	m:SetAttribute("Free", Raft.FREE)
	m.Parent = folder
	return m, seat, prompt
end

local model, seat, prompt = buildModel()

-- review m6: a call prompt on each dock's stand brings the empty raft over from the other dock
local callPrompts = {}
for i, stand in ipairs(stands) do
	local post = Instance.new("Part")
	post.Name = "CallPoint_" .. i
	post.Size = Vector3.new(1, 1, 1)
	post.Transparency = 1
	post.CFrame = CFrame.new(stand)
	quiet(post)
	post.Parent = folder
	local call = Instance.new("ProximityPrompt")
	call.ActionText, call.ObjectText = Text.CANDY_RAFT.callPrompt, Text.CANDY_RAFT.object
	call.HoldDuration = 0.3
	call.MaxActivationDistance = Raft.BOARD_STUDS
	call.RequiresLineOfSight = false
	call.Enabled = false
	call.Parent = post
	callPrompts[i] = call
end
local yaw = select(3, Raft.pointAt(lane, state.s))

-- review m6: the server moves the anchored raft only while it is under way (and once when it docks or respawns),
-- so a docked raft sends nothing; the bob plays only while it sails.
local function place(t)
	local x, z, legYaw = Raft.pointAt(lane, state.s)
	if state.dir < 0 then legYaw += math.pi end
	if Raft.moving(state) then yaw = legYaw end
	local bob = Raft.moving(state) and Raft.bob(t) or 0
	model:PivotTo(CFrame.new(x, surface + bob, z) * CFrame.Angles(0, yaw, 0))
end
place(0)

-- Network ---------------------------------------------------------------------------------------------------------
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 60)
local remote = network and network:FindFirstChild(Raft.EVENT)
if network and not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = Raft.EVENT
	remote.Parent = network
end
local function tell(player, kind, reason)
	if remote and player and player.Parent then remote:FireClient(player, { kind = kind, reason = reason }) end
end

local function humanoidOf(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return nil end
	return humanoid, root, character
end

local boardedAt = -math.huge
local function now() return os.clock() end

local function unseat(humanoid)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	if humanoid then humanoid.Sit = false end
end

prompt.Triggered:Connect(function(player)
	local humanoid, root = humanoidOf(player)
	local pivot = model:GetPivot().Position
	local distance = root and math.sqrt((root.Position.X - pivot.X) ^ 2 + (root.Position.Z - pivot.Z) ^ 2) or math.huge
	local ok, reason = Raft.board(state, player.UserId, distance, humanoid ~= nil, now())
	if not ok then
		tell(player, "Refused", reason)
		return
	end
	if humanoid.SeatPart then
		Raft.leave(state, player.UserId, now())
		tell(player, "Refused", "Busy")
		return
	end
	-- the seat is anchored with the raft: lift the rider onto it, then sit
	root.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
	seat:Sit(humanoid)
	boardedAt = now()
	tell(player, "Boarded")
end)

for i, call in ipairs(callPrompts) do
	call.Triggered:Connect(function(player)
		local humanoid, root = humanoidOf(player)
		local stand = stands[i]
		if not humanoid or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(stand.X, 0, stand.Z)).Magnitude > Raft.BOARD_STUDS then
			tell(player, "Refused", "TooFar")
			return
		end
		local ok, reason = Raft.call(state, i, now())
		tell(player, ok and "Called" or "Refused", reason)
	end)
end

if remote then
	local lastRequest = {}
	remote.OnServerEvent:Connect(function(player, payload)
		local action = Raft.request(payload)
		if not action then return end
		local t = now()
		if not Raft.allowed(lastRequest[player], t) then return end
		lastRequest[player] = t
		if action == "Leave" and state.rider == player.UserId then
			unseat((humanoidOf(player)))
		end
	end)
	Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)
end

Players.PlayerRemoving:Connect(function(player)
	if state.rider == player.UserId then
		Raft.leave(state, player.UserId, now())
		unseat(nil)
	end
end)

-- The step --------------------------------------------------------------------------------------------------------
local wasMoving = false
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	local rider = state.rider and Players:GetPlayerByUserId(state.rider)
	local humanoid = rider and humanoidOf(rider)
	-- a short grace after boarding while the seat weld settles
	local seated = humanoid ~= nil and (seat.Occupant == humanoid or t - boardedAt < 0.6)
	for _, event in ipairs(Raft.step(state, dt, t, seated)) do
		local player = event.rider and Players:GetPlayerByUserId(event.rider)
		if event.kind == "Arrived" then
			local h, _, character = humanoidOf(player)
			unseat(h)
			local stand = stands[state.dock]
			if character and stand then
				-- V3-D26 (Play 2026-11-17): the client, still welded to the seat for a moment, snapped a deferred move
				-- back onto the raft; set the rider down once the unseat has replicated, and again if it did not stick
				local function setDown()
					if character.Parent then character:PivotTo(CFrame.new(stand)) end
				end
				task.delay(0.3, setDown)
				task.delay(0.9, function()
					local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - stand).Magnitude > 6 then setDown() end
				end)
			end
			tell(player, "Arrived")
		elseif event.kind == "Left" then
			unseat(nil)
			tell(player, "Left")
		end
	end
	prompt.Enabled = state.status == "Docked" and state.rider == nil
	for i, call in ipairs(callPrompts) do
		call.Enabled = state.status == "Docked" and state.rider == nil and state.dock ~= i
	end
	if wasMoving or Raft.moving(state) then place(t) end
	wasMoving = Raft.moving(state)
end)
