-- Caramelo raft service (docs/design/wildbound-caramelo-v3-plan.md V3-D13; Caramelo v4 V4-D3, odd/tasks/
-- wildbound-caramelo-v2.md): runs WildboundCandyRaft in the place. Once the live biome carries the v3 mark (the
-- migration tool laid the river and the docks), it builds the Balsa Banana Split at runtime (the kit's CV3_BananaRaft
-- from ServerStorage.WildboundAssets.CandyKitV3, or a plain-part placeholder; the place file never needs saving) at its
-- home dock's tip, with a VehicleSeat at the kit's SeatAnchor and a ProximityPrompt to board. Server-authoritative: the
-- server decides who boards (one rider, near the docked raft, alive) and seats them; every Heartbeat it reads the
-- seated rider's ThrottleFloat and SteerFloat (W/S, A/D, the touch thumbstick) off the seat, clamps them, steps the
-- rules inside the chocolate and off the bridges (Raft.area from WildboundCandyV3Layout) and moves the anchored raft
-- (the seated character rides with it). It sets the rider down on a dock's stand when the raft docks, brings an
-- abandoned raft back to its home dock and a called one to the caller's dock. Clients only ask to leave
-- ({ action = "Leave" } on ReplicatedStorage.WildboundNetwork.CandyRaftEvent), validated and rate limited; the server
-- tells each rider what happened. Riding is free: there is no price and no product here.
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
local docks = assert(Raft.docksFrom(V3, Layout.CENTRE), "the layout's docks")
local area = Raft.area(V3, Layout.CENTRE)
local state = assert(Raft.new(docks, V3.RAFT.homeDock))
local stands = {}
for i, d in ipairs(docks) do
	-- review m6: on top of the dock deck (surface + deckOver), a root's height above it
	stands[i] = Vector3.new(d.standX, surface + V3.DOCK.deckOver + 3, d.standZ)
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
	-- V4-D3: a VehicleSeat at the kit's SeatAnchor (Roblox local of the pivot), facing -Z like the raft, so the default
	-- controls (W/S, A/D, the touch thumbstick) set its ThrottleFloat and SteerFloat; the server reads them
	local seatAt = raftSpec and raftSpec.seat and raftSpec.seat.pos or { 0, 1.2, 1.6 }
	local seat = Instance.new("VehicleSeat")
	seat.Name = "RaftSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Transparency = 1
	seat.HeadsUpDisplay = false
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0 -- no wheels: the server moves the raft
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

-- review m6 / V3-D22: the server moves the anchored raft only while it is under way, and once after each event (it
-- docked, respawned or was brought over), so a docked raft sends nothing; it bobs only under way.
local function place(t)
	local bob = Raft.moving(state) and Raft.bob(t) or 0
	model:PivotTo(CFrame.new(state.x, surface + bob, state.z) * CFrame.Angles(0, state.yaw, 0))
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

-- V3-D26 (Play 2026-11-17): the client, still welded to the seat for a moment, snapped a deferred move back onto the
-- raft; set the rider down on the dock's stand once the unseat has replicated, and again if it did not stick
local function setDownLater(player, dock)
	local _, _, character = humanoidOf(player)
	local stand = dock and stands[dock]
	if not character or not stand then return end
	local function setDown()
		if character.Parent then character:PivotTo(CFrame.new(stand)) end
	end
	task.delay(0.3, setDown)
	task.delay(0.9, function()
		local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - stand).Magnitude > 6 then setDown() end
	end)
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
local dirty = false
RunService.Heartbeat:Connect(function(dt)
	local t = now()
	local rider = state.rider and Players:GetPlayerByUserId(state.rider)
	local humanoid = rider and humanoidOf(rider)
	-- a short grace after boarding while the seat weld settles
	local seated = humanoid ~= nil and (seat.Occupant == humanoid or t - boardedAt < 0.6)
	-- V4-D3: the steering comes only from the seated rider's own seat, clamped by the rules
	local input = nil
	if humanoid ~= nil and seat.Occupant == humanoid then
		input = { throttle = seat.ThrottleFloat, steer = seat.SteerFloat }
	end
	for _, event in ipairs(Raft.step(state, dt, t, input, seated, area)) do
		dirty = true
		local player = event.rider and Players:GetPlayerByUserId(event.rider)
		if event.kind == "Arrived" and player then
			unseat((humanoidOf(player)))
			setDownLater(player, event.dock)
			tell(player, "Arrived")
		elseif event.kind == "Left" then
			unseat(nil)
			if player and event.dock then
				setDownLater(player, event.dock)
				tell(player, "Arrived")
			else
				tell(player, "Left")
			end
		end
	end
	prompt.Enabled = state.status == "Docked" and state.rider == nil
	for i, call in ipairs(callPrompts) do
		call.Enabled = state.status == "Docked" and state.rider == nil and state.dock ~= i
	end
	if dirty or Raft.moving(state) then place(t) end
	dirty = Raft.moving(state)
end)
