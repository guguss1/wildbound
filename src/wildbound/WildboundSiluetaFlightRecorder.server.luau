-- TEMPORARY diagnostic (2026-11-12), Studio only: prints to the Output why La Silueta is or is not after the first
-- player, each time the reason changes, so a Play session can be read back after it stops. Delete when the aggro
-- work is done. It reads positions and attributes only and changes nothing.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local cfg = game:GetService("ReplicatedStorage"):WaitForChild("WildboundTuning", 15)
cfg = cfg and cfg:WaitForChild("Silueta", 15)
local map = workspace:WaitForChild("WildboundP0", 15)
if not cfg or not map then return end
local TAG = "[SiluetaLog] "
local totals, lastKey, started, lastTotals = {}, nil, os.clock(), os.clock()
print(TAG .. "recorder on")
while true do
	task.wait(0.25)
	local rt = map:FindFirstChild("WildboundWorldRuntime")
	local player = Players:GetPlayers()[1]
	local guardian
	if rt and player then
		for _, child in ipairs(rt:GetChildren()) do
			if child.Name == "Silueta" and child:GetAttribute("Owner") == player.UserId then guardian = child end
		end
	end
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = guardian and guardian:FindFirstChild("Body")
	if root and body then
		local pos, state = root.Position, tostring(guardian:GetAttribute("State"))
		local clock = game:GetService("Lighting").ClockTime
		local sightKey = (clock >= 6 and clock < 18) and "SIGHT_DAY"
			or ((clock >= 18 and clock < 20) or (clock >= 5 and clock < 6)) and "SIGHT_TWILIGHT" or "SIGHT_NIGHT"
		local range = cfg:GetAttribute(sightKey) or 0
		local flat = Rules.distance(pos.X, pos.Z, body.Position.X, body.Position.Z)
		local fog, safe = Rules.zone(pos.X, pos.Z)
		local home = Rules.distance(pos.X, pos.Z, Rules.HOME_X, Rules.HOME_Z)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, rt }
		local hit = workspace:Raycast(body.Position, pos - body.Position, params)
		local reason
		if state == "Alert" or state == "Hunt" or state == "Telegraph" then reason = "CHASING"
		elseif flat > 90 then reason = "far"
		elseif player:GetAttribute("WildboundHidden") then reason = "ignored:hidden"
		elseif safe then reason = "ignored:safe-zone"
		elseif not fog then reason = "ignored:outside-fog-rectangle"
		elseif home > Rules.HOME_LEASH then reason = "ignored:outside-territory-80"
		elseif Rules.distance(pos.X, pos.Z, 0, 0) <= 9 then reason = "ignored:spawn-pad"
		elseif math.abs(pos.Y - body.Position.Y) > 8 then reason = "ignored:height"
		elseif flat > range then reason = "ignored:beyond-sight-" .. tostring(range)
		elseif hit then reason = "ignored:sight-blocked-by-" .. hit.Instance.Name
		else reason = "ignored:NO-REASON" end
		totals[reason] = (totals[reason] or 0) + 0.25
		local key = reason .. "/" .. state
		if key ~= lastKey then
			lastKey = key
			print((TAG .. "%6.1fs %-36s state=%-9s dist=%5.1f player=(%.0f,%.0f) home=%.0f her=(%.0f,%.0f) health=%.0f"):format(
				os.clock() - started, reason, state, flat, pos.X, pos.Z, home, body.Position.X, body.Position.Z,
				character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health or -1))
		end
	end
	if os.clock() - lastTotals >= 20 then
		lastTotals = os.clock()
		local sums = {}
		for name, seconds in pairs(totals) do table.insert(sums, ("%s=%.0fs"):format(name, seconds)) end
		table.sort(sums)
		print(TAG .. "TOTALS " .. table.concat(sums, " | "))
	end
end
