-- Flanfuria, the flan with a cream kitten on top (odd/tasks/caramelo-bioma.md, T4): the rig prefab. Mesh, skin and
-- 14-bone armature come from Blender (caramelo/flanfuria/build_flanfuria.py in the local repo), uploaded as one Model
-- asset (ASSET_ID). The import is a grey package: a RootPart with the Bone tree, the skinned flan (Body) and fourteen
-- rigid meshes pinned to the root by Motor6D. Flanfuria.assemble turns a copy into the prefab: coloured, on a pivot at
-- ground level facing -Z, every rigid piece riding the bone ATTACH names (a RigidConstraint, which follows animated
-- bones), one cylinder for a hitbox, root anchored. It is ONE actor: the kitten has no root of its own.
-- Blender to Roblox: X = -x, Y = z, Z = y, so the character's left (CatEar_L...) is on -X.
-- Rules: WildboundCandyFlanfuria_Test.
local Flanfuria = {}
Flanfuria.ASSET_ID = 109182574821732 -- v3. Unused: v1 82183195819347 (lost the kitten's bones), v2 76491528957195 (meshes named like bones). Was: 76491528957195 -- v2; v1 (82183195819347) lost the kitten's bones on import and is unused
Flanfuria.PREFAB_NAME = "Flanfuria"
Flanfuria.HEIGHT = 8.76
Flanfuria.COLOURS = { Body = "#F2B24A", Puddle = "#DE963C", Caramel = "#8A4B22", FlanFace = "#3A1E12", CatBody = "#F6E7CF",
	CatSkull = "#F6E7CF", CatEarL = "#F6E7CF", CatEarR = "#F6E7CF", CatPawL = "#F6E7CF", CatPawR = "#F6E7CF", Tail1 = "#F6E7CF",
	Tail2 = "#F6E7CF", CatFace = "#3A1E12", Cream = "#FFF7EE", CherryFruit = "#E0263C" }
-- Which bone carries each rigid piece (the flan, Body, is skinned and is not here).
Flanfuria.ATTACH = { Puddle = "FlanBase", Caramel = "CaramelTop", FlanFace = "FlanJiggle", CatBody = "CatRoot", CatSkull = "CatHead",
	CatEarL = "CatEar_L", CatEarR = "CatEar_R", CatPawL = "CatPaw_L", CatPawR = "CatPaw_R", Tail1 = "CatTail_01", Tail2 = "CatTail_02",
	CatFace = "CatHead", Cream = "CreamPeak", CherryFruit = "Cherry" }
-- No mesh is named like a bone: the importer hangs a bone under the mesh that shares its name and cuts it off its parent.
-- The hitbox: a cylinder around the flan (radius, height).
Flanfuria.COLLISION = { radius = 3.2, height = 3.9 }

local function findBone(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then return d end
	end
	error("the import has no bone " .. name, 0)
end

-- Builds the prefab from an imported Flanfuria model and parents it under the given parent. Returns the Model.
function Flanfuria.assemble(import, parent)
	assert(typeof(import) == "Instance" and typeof(parent) == "Instance", "import and parent must be Instances")
	assert(not parent:FindFirstChild(Flanfuria.PREFAB_NAME), Flanfuria.PREFAB_NAME .. " already exists")
	local model = import:Clone()
	model.Name = Flanfuria.PREFAB_NAME
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PackageLink") then d:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	assert(root and root:IsA("BasePart"), "the import has no RootPart")
	for name, colour in pairs(Flanfuria.COLOURS) do
		local part = model:FindFirstChild(name)
		assert(part and part:IsA("MeshPart"), "the import has no mesh " .. name)
		part.Color = Color3.fromHex(colour)
		part.Material = Enum.Material.SmoothPlastic
		local boneName = Flanfuria.ATTACH[name]
		if boneName then
			local bone = findBone(model, boneName)
			for _, joint in ipairs(part:GetChildren()) do
				if joint:IsA("Motor6D") then joint:Destroy() end
			end
			local grip = Instance.new("Attachment")
			grip.Name = "BoneGrip"
			grip.Parent = part
			grip.WorldCFrame = bone.TransformedWorldCFrame
			local constraint = Instance.new("RigidConstraint")
			constraint.Attachment0, constraint.Attachment1 = bone, grip
			constraint.Parent = part
		end
	end
	-- Keeper: tiny skinned tetrahedra, one per kitten bone. The importer drops bones no skinned vertex uses; this piece
	-- keeps them. It is never seen.
	local keeper = model:FindFirstChild("Keeper")
	assert(keeper and keeper:IsA("MeshPart"), "the import has no Keeper mesh: the kitten's bones would be missing")
	keeper.Transparency = 1
	local ground = findBone(model, "Root").WorldPosition
	local frame = CFrame.new(ground) * root.CFrame.Rotation
	local hitbox = Instance.new("Part")
	hitbox.Name = "Collision"
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Size = Vector3.new(Flanfuria.COLLISION.height, Flanfuria.COLLISION.radius * 2, Flanfuria.COLLISION.radius * 2)
	hitbox.CFrame = frame * CFrame.new(0, Flanfuria.COLLISION.height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	hitbox.Transparency = 1
	hitbox.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, hitbox
	weld.Parent = hitbox
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
			d.Anchored = d == root
			d.Massless = d ~= root
			d.CanCollide = d == hitbox
			d.CanQuery = d == hitbox
			d.CastShadow = d.Name == "Body" or d.Name == "CatBody" or d.Name == "CatSkull"
		end
	end
	root.Transparency = 1
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(frame)
	model:PivotTo(CFrame.new())
	model:SetAttribute("Species", "Flanfuria")
	model:SetAttribute("AssetId", Flanfuria.ASSET_ID)
	model:SetAttribute("Height", Flanfuria.HEIGHT)
	model.Parent = parent
	return model
end

-- A detached copy of the prefab standing on the given ground CFrame (-Z is its front).
function Flanfuria.spawn(prefab, groundCFrame)
	local copy = prefab:Clone()
	copy:PivotTo(groundCFrame)
	return copy
end

return Flanfuria
