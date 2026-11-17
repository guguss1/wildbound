-- Caramelo v4 wading service (odd/tasks/wildbound-caramelo-v2.md V4-D2): once the live biome carries the v3 mark (the
-- chocolate is laid), every WildboundCandyWade.STEP seconds it probes each player's root on the server and sets the
-- server-only player attribute WildboundCandyWade.ATTRIBUTE to the wading factor while their feet are in the
-- chocolate, or clears it. WildboundServer.applyCarry, the one WalkSpeed writer, multiplies its freshly computed speed
-- by that factor and re-applies when the attribute changes, so leaving the chocolate restores the speed exactly and
-- nothing stacks. Players only: the creatures are never slowed. A new character starts dry. No client request.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Wade = require(ServerStorage:WaitForChild("WildboundCandyWade"))
local Layout = require(ServerStorage:WaitForChild("WildboundCandyLayout"))
local V3 = require(ServerStorage:WaitForChild("WildboundCandyV3Layout"))

local biome = workspace:WaitForChild(Layout.ROOT_NAME, 120)
if not biome then return end
while biome:GetAttribute(V3.MARK) == nil do
	biome:GetAttributeChangedSignal(V3.MARK):Wait()
end

local wading = {} -- [player] = true while wading

local function set(player, on)
	if (wading[player] == true) == on then return end
	wading[player] = on or nil
	player:SetAttribute(Wade.ATTRIBUTE, on and Wade.FACTOR or nil)
end

local function watch(player)
	player.CharacterAdded:Connect(function()
		wading[player] = nil
		player:SetAttribute(Wade.ATTRIBUTE, nil)
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerRemoving:Connect(function(player) wading[player] = nil end)

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
			set(player, ok and Wade.wading(wading[player] == true, info) or false)
		end
	end
end
