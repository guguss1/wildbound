-- Don Glaseon, the territorial boss of the Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3): the rig prefab. Mesh,
-- skin and 29-bone armature come from Blender (assets/blender/caramelo/don-glaseon/build_don_glaseon.py), uploaded as
-- one Model asset (ASSET_ID). The import is a grey package: a RootPart that carries the Bone tree and fourteen skinned
-- meshes, one per colour, each tied to the root by its Motor6D. Every vertex rides exactly one bone, so the importer
-- keeps every bone. Blender may suffix a mesh name (".001") when its open file already used it: assemble strips it.
-- DonGlaseon.assemble turns a copy into the prefab: coloured, on a pivot at ground level facing -Z, one plain box for a
-- hitbox, root anchored (the server moves it; clips are in place and only move bones).
-- Blender to Roblox: X = -x, Y = z, Z = y, so the character's left (Hand_L...) is on -X and its licorice (right
-- forearm) on +X. Rules: WildboundCandyDonGlaseon_Test.
local DonGlaseon = {}
DonGlaseon.ASSET_ID = 91765062667935 -- v1
DonGlaseon.PREFAB_NAME = "DonGlaseon"
DonGlaseon.HEIGHT = 24.74
DonGlaseon.COLOURS = { Body = "#EE8CC4", Shade = "#D9529A", Mouth = "#5A1030", Teeth = "#F3E6D3", Claw = "#EAD2C4",
	Leg = "#7B3F8C", Eye = "#FFE3F1", CandyA = "#2EC4D6", CandyB = "#F2C230", CandyC = "#F07A2A", CandyD = "#8E44AD",
	CandyE = "#E8344E", Licorice = "#E23C8A", Stripe = "#FFF4F8" }
DonGlaseon.NEON = { Eye = true }
-- The only thing that collides: one box around legs and torso, standing on the ground (width, height, depth).
DonGlaseon.COLLISION = Vector3.new(8.5, 16, 6.5)

local function findBone(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then return d end
	end
	error("the import has no bone " .. name, 0)
end

-- Builds the prefab from an imported Don Glaseon model and parents it under the given parent. Returns the Model.
function DonGlaseon.assemble(import, parent)
	assert(typeof(import) == "Instance" and typeof(parent) == "Instance", "import and parent must be Instances")
	assert(not parent:FindFirstChild(DonGlaseon.PREFAB_NAME), DonGlaseon.PREFAB_NAME .. " already exists")
	local model = import:Clone()
	model.Name = DonGlaseon.PREFAB_NAME
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PackageLink") then d:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	assert(root and root:IsA("BasePart"), "the import has no RootPart")
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("MeshPart") then part.Name = (string.gsub(part.Name, "%.%d+$", "")) end
	end
	for name, colour in pairs(DonGlaseon.COLOURS) do
		local part = model:FindFirstChild(name)
		assert(part and part:IsA("MeshPart"), "the import has no mesh " .. name)
		part.Color = Color3.fromHex(colour)
		part.Material = DonGlaseon.NEON[name] and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
	local ground = findBone(model, "Root").WorldPosition
	local frame = CFrame.new(ground) * root.CFrame.Rotation
	local box = Instance.new("Part")
	box.Name = "Collision"
	box.Size = DonGlaseon.COLLISION
	box.CFrame = frame * CFrame.new(0, DonGlaseon.COLLISION.Y / 2, 0)
	box.Transparency = 1
	box.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, box
	weld.Parent = box
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
			d.Anchored = d == root
			d.Massless = d ~= root
			d.CanCollide = d == box
			d.CanQuery = d == box
			d.CastShadow = d.Name == "Body" or d.Name == "Leg"
		end
	end
	root.Transparency = 1
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(frame)
	model:PivotTo(CFrame.new())
	model:SetAttribute("Species", "DonGlaseon")
	model:SetAttribute("AssetId", DonGlaseon.ASSET_ID)
	model:SetAttribute("Height", DonGlaseon.HEIGHT)
	model.Parent = parent
	return model
end

-- A detached copy of the prefab standing on the given ground CFrame (-Z is its front).
function DonGlaseon.spawn(prefab, groundCFrame)
	local copy = prefab:Clone()
	copy:PivotTo(groundCFrame)
	return copy
end

return DonGlaseon
