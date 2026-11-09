-- World gather nodes (M5.3, wave W7 part 2). Draws the nodes the inventory script's gather seam rolls, claims
-- through that seam when a prompt hold finishes, and retires night-only nodes at Dawn. It keeps no player
-- state and grants nothing: the claim, the yield and the pouch are decided in WildboundServer and State.
-- Deploy beside WildboundServer in ServerScriptService. docs/mechanics/wildbound-economy-p0.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(script.Parent:WaitForChild("WildboundWorldRules"))
local Field = require(script.Parent:WaitForChild("WildboundGatherField"))
local Spawn = require(script.Parent:WaitForChild("WildboundSpawn"))
local Config = require(ReplicatedStorage:WaitForChild("WildboundEconomyConfig"))
-- Next batch NB3: the gather prompt's words in Spanish.
local Words = require(ReplicatedStorage:WaitForChild("WildboundText")).NOTICES
local map = workspace:WaitForChild("WildboundP0", 15)
local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 15)
if not map or not network then
	warn("Wildbound gather: the map and the inventory network are required.")
	return
end
local gatherSpawn = network:WaitForChild("GatherSpawn", 15)
local gatherClaim = network:WaitForChild("GatherClaim", 15)
local gatherRetire = network:WaitForChild("GatherRetire", 15)
if not (gatherSpawn and gatherSpawn:IsA("BindableFunction") and gatherClaim and gatherClaim:IsA("BindableFunction")
	and gatherRetire and gatherRetire:IsA("BindableFunction")) then
	warn("Wildbound gather: the gather seam is missing.")
	return
end
if map:FindFirstChild("WildboundGather") then
	warn("Wildbound gather: duplicate startup refused.")
	return
end
local folder = Instance.new("Folder")
folder.Name = "WildboundGather"
folder.Parent = map
-- The floor is flat but its parts differ by a few tenths (floor, paths, pools). A short ray just above the
-- Lumipol marker finds the real surface under a node; trees and canopies sit higher and are never hit.
local floorMarker = map:FindFirstChild("LumipolMarker", true)
local markerY = floorMarker and floorMarker:IsA("BasePart") and floorMarker.Position.Y or 1
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.FilterDescendantsInstances = { folder }
local function floorAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, markerY + 3, z), Vector3.new(0, -10, 0), floorParams)
	return hit and hit.Position.Y or markerY - 1
end

local field = Field.new(Config, Spawn)
local rng = Random.new()
local views = {}
-- Where each player's hold began, so a node can tell that the player walked off before it finished.
local holds = setmetatable({}, { __mode = "k" })

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- Nodes never collide, are never hit by a ray and stay under 3 studs, so they cannot block a route.
local function part(model, name, shape, size, cframe, color)
	local value = Instance.new("Part")
	value.Name, value.Shape, value.Size, value.CFrame = name, shape, size, cframe
	value.Anchored = true
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Material, value.Color = Enum.Material.SmoothPlastic, color
	value.Parent = model
	return value
end

local function remove(id, reason)
	local view = views[id]
	if not view then return end
	views[id] = nil
	view.prompt.Enabled = false
	view.model:Destroy()
	field:release(id, workspace:GetServerTimeNow(), reason)
end

local function build(node)
	local look = Field.look(node.material, node.heart)
	if not look then return nil end
	local model = Instance.new("Model")
	model.Name = "GatherNode_" .. look.name
	model:SetAttribute("GatherId", node.id)
	model:SetAttribute("Material", node.material)
	model:SetAttribute("Zone", node.zone)
	model:SetAttribute("Slot", node.slotId)
	local size = Vector3.new(look.size[1], look.size[2], look.size[3])
	local color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	local groundY = floorAt(node.x, node.z)
	local tilt = look.shape == "Diamond" and CFrame.Angles(math.rad(45), math.rad(45), 0) or CFrame.Angles(0, math.rad(20), 0)
	local body = part(model, "Body", look.shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Block, size,
		CFrame.new(node.x, groundY + size.Y / 2 + 0.2, node.z) * tilt, color)
	if look.ring then
		-- A heart slot has the longest hold, so it wears a flat ring: a shape cue, not only a colour.
		local ring = part(model, "Ring", Enum.PartType.Cylinder, Vector3.new(0.12, look.ringDiameter, look.ringDiameter),
			CFrame.new(node.x, groundY + 0.12, node.z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 183, 92))
		ring.Transparency = 0.25
	end
	if look.glow then
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = color, 0.8, 9, false
		light.Parent = body
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Words.gather
	prompt.ObjectText = ("%s x%d%s"):format(look.name, node.quantity or 1, node.material == "nightbloom" and Words.wilts or "")
	prompt.MaxActivationDistance, prompt.HoldDuration = Config.gather.promptRange, node.hold
	prompt.RequiresLineOfSight = false
	-- Its own keys, so a wild Lumipol standing on a node (it roams near T1) cannot take the button: prompts on the
	-- same keys show only the nearest one, and the Lumipol and the camp prompts keep E and ButtonX.
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.G, Enum.KeyCode.ButtonY
	prompt.Parent = body
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local root = rootOf(player)
		if root then holds[player] = { id = node.id, x = root.Position.X, z = root.Position.Z } end
	end)
	prompt.Triggered:Connect(function(player)
		if views[node.id] == nil or not prompt.Enabled then return end
		local hold = holds[player]
		holds[player] = nil
		local root = rootOf(player)
		-- ECO-25: walking off during the hold cancels the claim. No record means nothing to compare.
		local moved = hold ~= nil and hold.id == node.id and root ~= nil
			and Field.holdBroken(hold.x, hold.z, root.Position.X, root.Position.Z)
		local ok = gatherClaim:Invoke(player, node.id, moved)
		-- Kept on PouchFull, BackpackFull, AlreadyGathered and a broken hold; gone only after a real claim.
		if ok == true then remove(node.id, "claimed") end
	end)
	model.Parent = folder
	views[node.id] = { model = model, prompt = prompt }
	return model
end

local function currentPhase()
	local world = map:FindFirstChild("WildboundWorldRuntime")
	local origin = world and world:GetAttribute("CycleStartedAt")
	if not Rules.finite(origin) then return nil end
	return Rules.cycle(workspace:GetServerTimeNow() - origin).phase
end

local function roll()
	return rng:NextNumber()
end

script.Destroying:Connect(function()
	folder:Destroy()
end)

-- Keeps the field full and wilts Nightbloom at Dawn. Only nodes appear or go here; it grants nothing.
task.spawn(function()
	while folder.Parent == map do
		local phase = currentPhase()
		if phase then
			for _, id in ipairs(field:wilting(phase)) do
				gatherRetire:Invoke(id)
				remove(id, "wilted")
			end
			for _, slotId in ipairs(field:plan(#Players:GetPlayers(), workspace:GetServerTimeNow(), roll)) do
				local node = gatherSpawn:Invoke(slotId)
				if type(node) == "table" and field:track(node) then
					build(node)
				elseif type(node) == "table" then
					gatherRetire:Invoke(node.id)
				end
			end
		end
		task.wait(1)
	end
end)
