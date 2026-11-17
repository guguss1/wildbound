-- Caramelo v4 wading service (odd/tasks/wildbound-caramelo-v2.md V4-D2): once the live biome carries the v3 mark (the
-- chocolate is laid), every WildboundCandyWade.STEP seconds it probes each player's root on the server and sets the
-- server-only player attribute WildboundCandyWade.ATTRIBUTE to the wading factor while their feet are in the
-- chocolate, or clears it. WildboundServer.applyCarry, the one WalkSpeed writer, multiplies its freshly computed speed
-- by that factor and re-applies when the attribute changes, so leaving the chocolate restores the speed exactly and
-- nothing stacks. Players only: the creatures are never slowed. A new character starts dry. No client request.
-- V6-D3 (Caramelo v6, the river current): on the same probe, a wader also gets the current's push
-- (WildboundCandyCurrent.push, at most 1.5 studs/s, downstream) on the player attribute
-- WildboundCandyCurrent.PUSH_ATTRIBUTE (a Vector3, world studs/s), which WildboundCandyCurrentClient applies to its own
-- character. The server alone decides the vector; it is cleared the moment the player is not wading (out of the
-- chocolate, dead, seated, e.g. on the raft), and on a new character or leaving. The creatures are never pushed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Wade = require(ServerStorage:WaitForChild("WildboundCandyWade"))
local Current = require(ReplicatedStorage:WaitForChild("WildboundCandyCurrent"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local V3 = require(ServerStorage:WaitForChild("WildboundCandyV3Layout"))

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 120)
if not biome then return end
while biome:GetAttribute(V3.MARK) == nil do
	biome:GetAttributeChangedSignal(V3.MARK):Wait()
end

local wading = {} -- [player] = true while wading
local pushes = {} -- [player] = the push Vector3 last set

local function set(player, on)
	if (wading[player] == true) == on then return end
	wading[player] = on or nil
	player:SetAttribute(Wade.ATTRIBUTE, on and Wade.FACTOR or nil)
end

-- V6-D3: the push the server decided (nil clears it); written only when it changes
local function setPush(player, push)
	if pushes[player] == push then return end
	pushes[player] = push
	player:SetAttribute(Current.PUSH_ATTRIBUTE, push)
end

local function watch(player)
	player.CharacterAdded:Connect(function()
		wading[player] = nil
		pushes[player] = nil
		player:SetAttribute(Wade.ATTRIBUTE, nil)
		player:SetAttribute(Current.PUSH_ATTRIBUTE, nil)
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerRemoving:Connect(function(player)
	wading[player] = nil
	pushes[player] = nil
end)

local function probe(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return { alive = false } end
	local info = Wade.probe(V3, Layout.CENTRE, Layout.FLOOR_TOP, root.Position, root.Size.Y / 2, humanoid.HipHeight,
		humanoid.RigType == Enum.HumanoidRigType.R6)
	info.alive = humanoid.Health > 0
	info.seated = humanoid.SeatPart ~= nil
	info.airborne = humanoid.FloorMaterial == Enum.Material.Air
	return info
end

while true do
	task.wait(Wade.STEP)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Parent == Players then
			local ok, info = pcall(probe, player)
			local on = ok and Wade.wading(wading[player] == true, info) or false
			set(player, on)
			-- V6-D3: the push only while wading (the same rule: in the chocolate, alive, not seated)
			local push = nil
			if on then push = Current.pushVector(true, Current.push(V3, info.x, info.z)) end
			setPush(player, push)
		end
	end
end
