-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D12; owner request 2026-11-17: "es como el mundo de gatito:
-- un parque verde lindo con las criaturas gatitas, ..."): poses the four part-built kittens on this client. Every model
-- in workspace.WildboundBeastsLocal named after a kitten (the beast client's live views and bystander views, and
-- WildboundCandyRestingClient's resting copies) is set up once: its parts' rest offsets in RootPart space are cached
-- with their Joint attribute and that joint's pivot (WildboundCandyKittens.pivots). Each Heartbeat it reads the model's
-- BeastPhase (the phase time is this client's os.clock() since the attribute last changed), asks
-- WildboundCandyKittens.pose and moves every part but the RootPart in one BulkMoveTo:
--   part = root * pivot * pose[joint] * pivot:Inverse() * rest.
-- The beast client moves the whole model rigidly by its RootPart (PivotTo), so the order of the two in a frame does not
-- matter. Models farther than Kittens.CULL_STUDS from the camera keep their last pose. Heartbeat drives it (V6-D6: the
-- other render step did not fire in Studio Play). Visual only: no server, no gameplay.
-- StarterPlayerScripts LocalScript (Studio name WildboundCandyKittenAnimClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kittens = require(ReplicatedStorage:WaitForChild("WildboundCandyKittens"))

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not folder then return end

local wanted = {}
for _, name in ipairs(Kittens.NAMES) do wanted[name] = true end

local states = {} -- [model] = { root, parts, rests, joints, pivots, inverses, phase, since }

local function setup(model)
	if states[model] or not model:IsA("Model") or not wanted[model.Name] then return end
	local root = model.PrimaryPart or model:FindFirstChild("RootPart")
	if not (root and root:IsA("BasePart")) then return end
	local pivots = Kittens.pivots(model.Name)
	local state = { root = root, parts = {}, rests = {}, joints = {}, pivots = {}, inverses = {}, phase = nil,
		since = os.clock() }
	for _, part in ipairs(model:GetDescendants()) do
		local joint = part:IsA("BasePart") and part ~= root and part:GetAttribute("Joint")
		local pivot = joint and pivots[joint]
		if pivot then
			local frame = CFrame.new(pivot[1], pivot[2], pivot[3])
			table.insert(state.parts, part)
			table.insert(state.rests, root.CFrame:ToObjectSpace(part.CFrame))
			table.insert(state.joints, joint)
			table.insert(state.pivots, frame)
			table.insert(state.inverses, frame:Inverse())
		end
	end
	if #state.parts > 0 then states[model] = state end
end

local function reduced()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local world = gui and gui:FindFirstChild("WildboundWorldUI")
	return world ~= nil and world:GetAttribute("Reduced") == true
end

local movedParts, movedFrames = {}, {}
local function animate(now)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	local soft = reduced()
	local count = 0
	for model, state in pairs(states) do
		if model.Parent ~= folder or state.root.Parent ~= model then
			states[model] = nil
		else
			local phase = model:GetAttribute("BeastPhase")
			if phase ~= state.phase then state.phase, state.since = phase, now end
			local rootFrame = state.root.CFrame
			if (rootFrame.Position - eye).Magnitude <= Kittens.CULL_STUDS then
				local pose = Kittens.pose(model.Name, phase, now - state.since, soft)
				for i, part in ipairs(state.parts) do
					local p = pose[state.joints[i]]
					count += 1
					movedParts[count] = part
					movedFrames[count] = p and rootFrame * state.pivots[i] * p * state.inverses[i] * state.rests[i]
						or rootFrame * state.rests[i]
				end
			end
		end
	end
	for i = #movedParts, count + 1, -1 do movedParts[i], movedFrames[i] = nil, nil end
	if count > 0 then workspace:BulkMoveTo(movedParts, movedFrames, Enum.BulkMoveMode.FireCFrameChanged) end
end

local reported = false
RunService.Heartbeat:Connect(function()
	local ok, message = pcall(animate, os.clock())
	if not ok and not reported then
		reported = true
		warn("WildboundCandyKittenAnimClient: " .. tostring(message))
		script:SetAttribute("LastError", tostring(message))
	end
end)

folder.ChildAdded:Connect(setup)
folder.ChildRemoved:Connect(function(child) states[child] = nil end)
for _, child in ipairs(folder:GetChildren()) do setup(child) end
