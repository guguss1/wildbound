-- Caramelo v6, proposal 3: the river current on a wader (odd/tasks/wildbound-caramelo-v2.md V6-D3; docs/design/
-- wildbound-caramelo-v3-plan.md V6-D33). The character is client-owned physics, so the push is applied here, but the
-- server alone decides it: WildboundCandyWadeService sets the player attribute WildboundCandyCurrent.PUSH_ATTRIBUTE (a
-- Vector3, world studs/s, at most 1.5) while the player wades and clears it the moment they do not. Every frame before
-- physics this script nudges its own root by that push (Current.applies: alive, not seated, no stronger than the
-- rule), unless a solid part stands just ahead in the push's direction. It never sends anything to the server and
-- never moves another character or a creature.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Current = require(ReplicatedStorage:WaitForChild("WildboundCandyCurrent"))

local player = Players.LocalPlayer
local LOOK_AHEAD = 1.5 -- studs: a solid part this close ahead in the push's direction stops the nudge
local MAX_DT = 0.1 -- seconds: a long frame never jumps the character

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

RunService.PreSimulation:Connect(function(dt)
	local push = player:GetAttribute(Current.PUSH_ATTRIBUTE)
	if push == nil then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or root.Anchored then return end
	if not Current.applies(push, humanoid.Health > 0, humanoid.SeatPart ~= nil) then return end
	params.FilterDescendantsInstances = { character }
	if workspace:Raycast(root.Position, push.Unit * LOOK_AHEAD, params) then return end
	root.CFrame += push * math.min(dt, MAX_DT)
end)
