-- Tortidragon, the cake-and-strawberry dragon of the Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2): the rig
-- prefab. Mesh, skin and 24-bone armature come from Blender (assets/blender/caramelo/tortidragon/build_tortidragon.py),
-- uploaded as one Model asset (ASSET_ID). The import is a grey package: a RootPart that carries the Bone tree and ten
-- skinned meshes, one per colour, each tied to the root by its Motor6D. Every vertex rides exactly one bone, so the
-- strawberries, the cream crest and the sprinkles move with their bones without any rigid piece; the importer keeps
-- every bone because each one owns skinned vertices (Root owns a small gem hidden in the torso).
-- Tortidragon.assemble turns a copy into the prefab: coloured, on a pivot at ground level facing -Z, one plain box for
-- a hitbox (never four leg colliders), root anchored (the server moves it; clips are in place and only move bones).
-- Blender to Roblox: X = -x, Y = z, Z = y, so the character's left (FrontLeg_L...) is on -X.
-- Rules: WildboundCandyTortidragon_Test.
local Tortidragon = {}
Tortidragon.ASSET_ID = 103052975067537 -- v1
Tortidragon.PREFAB_NAME = "Tortidragon"
Tortidragon.HEIGHT = 10.6
Tortidragon.COLOURS = { Body = "#F2A93B", Belly = "#D9343A", Cream = "#F7B6CF", Berry = "#E0263C", Leaf = "#4CAF50",
	Eye = "#9B3FC8", Shine = "#FFFFFF", Claw = "#5A3220", SprinkleA = "#3EC9D6", SprinkleB = "#F6C343" }
-- The only thing that collides: one box around torso and legs, standing on the ground (width, height, depth).
Tortidragon.COLLISION = Vector3.new(3.4, 5.4, 6.4)
-- Its centre along the body (Z, from the pivot): the torso sits a little behind the front legs.
Tortidragon.COLLISION_Z = 0.5

local function findBone(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then return d end
	end
	error("the import has no bone " .. name, 0)
end

-- Builds the prefab from an imported Tortidragon model and parents it under the given parent. Returns the Model.
function Tortidragon.assemble(import, parent)
	assert(typeof(import) == "Instance" and typeof(parent) == "Instance", "import and parent must be Instances")
	assert(not parent:FindFirstChild(Tortidragon.PREFAB_NAME), Tortidragon.PREFAB_NAME .. " already exists")
	local model = import:Clone()
	model.Name = Tortidragon.PREFAB_NAME
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PackageLink") then d:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	assert(root and root:IsA("BasePart"), "the import has no RootPart")
	for name, colour in pairs(Tortidragon.COLOURS) do
		local part = model:FindFirstChild(name)
		assert(part and part:IsA("MeshPart"), "the import has no mesh " .. name)
		part.Color = Color3.fromHex(colour)
		part.Material = Enum.Material.SmoothPlastic
	end
	local ground = findBone(model, "Root").WorldPosition
	local frame = CFrame.new(ground) * root.CFrame.Rotation
	local box = Instance.new("Part")
	box.Name = "Collision"
	box.Size = Tortidragon.COLLISION
	box.CFrame = frame * CFrame.new(0, Tortidragon.COLLISION.Y / 2, Tortidragon.COLLISION_Z)
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
			d.CastShadow = d.Name == "Body" or d.Name == "Cream"
		end
	end
	root.Transparency = 1
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(frame)
	model:PivotTo(CFrame.new())
	model:SetAttribute("Species", "Tortidragon")
	model:SetAttribute("AssetId", Tortidragon.ASSET_ID)
	model:SetAttribute("Height", Tortidragon.HEIGHT)
	model.Parent = parent
	return model
end

-- A detached copy of the prefab standing on the given ground CFrame (-Z is its front).
function Tortidragon.spawn(prefab, groundCFrame)
	local copy = prefab:Clone()
	copy:PivotTo(groundCFrame)
	return copy
end

return Tortidragon
