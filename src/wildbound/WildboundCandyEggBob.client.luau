-- CG1 (odd/tasks/wildbound-caramelo.md): the gummy Gomibu egg squashes gently in its nest. The server builds the candy
-- egg (WildboundCandyEggArt) and tags its CandyEggArt sub-model; this client only scales those parts locally around the
-- egg's foot (nothing is sent, nothing replicates back). Eggs far from the camera are left at rest.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CandyEggArt = require(ReplicatedStorage:WaitForChild("WildboundCandyEggArt", 20))
local RANGE = 160 -- studs from the camera

local active = {} -- holder -> { foot = CFrame, parts = { { part, offset CFrame, size Vector3 } }, phase }

local function track(holder)
	if active[holder] or not holder:IsA("Model") then return end
	local foot = holder.WorldPivot
	local entry = { foot = foot, parts = {}, phase = (math.abs(foot.X) + math.abs(foot.Z)) % CandyEggArt.BOB.PERIOD }
	local function add(item)
		if item:IsA("BasePart") then
			table.insert(entry.parts, { item, foot:ToObjectSpace(item.CFrame), item.Size })
		end
	end
	for _, item in ipairs(holder:GetChildren()) do add(item) end
	-- With streaming the parts can arrive after the tagged model.
	entry.added = holder.ChildAdded:Connect(add)
	active[holder] = entry
end
local function untrack(holder)
	local entry = active[holder]
	if entry and entry.added then entry.added:Disconnect() end
	active[holder] = nil
end

CollectionService:GetInstanceAddedSignal(CandyEggArt.BOB_TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(CandyEggArt.BOB_TAG):Connect(untrack)
for _, holder in ipairs(CollectionService:GetTagged(CandyEggArt.BOB_TAG)) do track(holder) end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local now = os.clock()
	for holder, entry in pairs(active) do
		if not holder.Parent then
			untrack(holder)
		elseif not eye or (entry.foot.Position - eye).Magnitude <= RANGE then
			local sx, sy = CandyEggArt.bob(now + entry.phase)
			for _, item in ipairs(entry.parts) do
				local part, offset, size = item[1], item[2], item[3]
				if part.Parent == holder then
					local p = offset.Position
					part.Size = Vector3.new(size.X * sx, size.Y * sy, size.Z * sx)
					part.CFrame = entry.foot * CFrame.new(p.X * sx, p.Y * sy, p.Z * sx) * offset.Rotation
				end
			end
		end
	end
end)
