-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG4): skating on Don Glaseon's glaze, on the player's own client
-- (it owns its character's physics). While the character stands on a puddle (WildboundCandyGlaze.inside) a flat
-- LinearVelocity on the root holds its slide, which turns only slowly toward where the player steers
-- (WildboundCandyGlaze.skate): no slowdown, little grip. A fast sharp turn (WildboundCandyGlaze.slips) asks the server
-- for the fall (WildboundNetwork.CandyGlazeSlip); the server checks it and ragdolls. Any other push in the beasts' slot
-- (WildboundBeastPush) wins: the skate lets go while it lasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Glaze = require(ReplicatedStorage:WaitForChild("WildboundCandyGlaze"))
local player = Players.LocalPlayer
local puddles = {}
local remote = nil
local skate = nil -- { attachment, velocity, v }
local lastSlip = -math.huge

task.spawn(function()
	local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 60)
	remote = network and network:WaitForChild("CandyGlazeSlip", 60)
	local biome = workspace:WaitForChild("Candy_Bioma_v1", 120)
	local tower = biome and biome:WaitForChild("Tower", 120)
	local folder = tower and tower:WaitForChild("Glaze", 60)
	if not folder then return end
	-- with streaming the puddles arrive (and leave) one by one: read them again on every change
	local function refresh() puddles = Glaze.read(folder) end
	folder.ChildAdded:Connect(function() task.defer(refresh) end)
	folder.ChildRemoved:Connect(refresh)
	refresh()
end)

local function release()
	if skate then skate.attachment:Destroy() end
	skate = nil
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or #puddles == 0 then release() return end
	local p = root.Position
	local onGlaze = humanoid.FloorMaterial ~= Enum.Material.Air and Glaze.inside(puddles, p.X, p.Y, p.Z) ~= nil
	if not onGlaze or root:FindFirstChild("WildboundBeastPush") or humanoid:GetState() == Enum.HumanoidStateType.Physics then
		release()
		return
	end
	if not skate or skate.attachment.Parent ~= root then
		release()
		local attachment = Instance.new("Attachment")
		attachment.Name = "WildboundCandyGlaze"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
		velocity.MaxForce = 1e5
		velocity.Parent = attachment
		local v = root.AssemblyLinearVelocity
		skate = { attachment = attachment, velocity = velocity, v = { x = v.X, z = v.Z } }
	end
	local move = humanoid.MoveDirection
	local steer = { x = move.X, z = move.Z }
	local steering = move.Magnitude > 0.1
	if steering and Glaze.slips(skate.v, steer) and os.clock() - lastSlip >= Glaze.SLIP_COOLDOWN and remote then
		lastSlip = os.clock()
		remote:FireServer()
		release()
		return
	end
	skate.v = Glaze.skate(skate.v, { x = move.X * humanoid.WalkSpeed, z = move.Z * humanoid.WalkSpeed }, dt, steering)
	skate.velocity.PlaneVelocity = Vector2.new(skate.v.x, skate.v.z)
end)
