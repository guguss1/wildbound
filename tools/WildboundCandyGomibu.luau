-- Gomibu, the gummy bear of the Caramelo biome (odd/tasks/caramelo-bioma.md, T3): the rig prefab. The mesh, skin and
-- 14-bone armature come from Blender (caramelo/gomibu/build_gomibu.py in the local repo), uploaded as one Model asset
-- (ASSET_ID). The import is a grey package: a RootPart that carries the Bone tree, the skinned Body, and the eyes,
-- highlights and nose pinned to the root by Motor6D. Gomibu.assemble turns a copy into the prefab: coloured, standing
-- on a pivot at ground level between the feet and facing -Z, face riding the Head bone, one plain collision box, root
-- anchored (the server moves the creature; animations are in place and only move bones).
-- Blender to Roblox: X = -x, Y = z, Z = y, so the character's left (Ear_L, Arm_L...) is on -X.
-- Rules: WildboundCandyGomibu_Test.
local Gomibu = {}
Gomibu.ASSET_ID = 97819093908843
Gomibu.PREFAB_NAME = "Gomibu"
Gomibu.HEIGHT = 6.65
Gomibu.COLOURS = { Body = "#FF5FAE", Eyes = "#4A0F3A", EyeShine = "#FFF7EE", Nose = "#8E1B5A" }
-- The only thing that collides: a box around torso and head, standing on the ground (width, height, depth).
Gomibu.COLLISION = Vector3.new(2.6, 6.15, 2.0)

local function findBone(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then return d end
	end
	error("the import has no bone " .. name, 0)
end

-- Builds the prefab from an imported Gomibu model and parents it under the given parent. Returns the Model.
function Gomibu.assemble(import, parent)
	assert(typeof(import) == "Instance" and typeof(parent) == "Instance", "import and parent must be Instances")
	assert(not parent:FindFirstChild(Gomibu.PREFAB_NAME), Gomibu.PREFAB_NAME .. " already exists")
	local model = import:Clone()
	model.Name = Gomibu.PREFAB_NAME
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PackageLink") then d:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	assert(root and root:IsA("BasePart"), "the import has no RootPart")
	local head = findBone(model, "Head")
	for name, colour in pairs(Gomibu.COLOURS) do
		local part = model:FindFirstChild(name)
		assert(part and part:IsA("MeshPart"), "the import has no mesh " .. name)
		part.Color = Color3.fromHex(colour)
		part.Material = Enum.Material.SmoothPlastic
		if name ~= "Body" then
			-- the import pins the face to the root; it has to ride the Head bone or it stays behind when the head moves
			for _, joint in ipairs(part:GetChildren()) do
				if joint:IsA("Motor6D") then joint:Destroy() end
			end
			local grip = Instance.new("Attachment")
			grip.Name = "HeadGrip"
			grip.Parent = part
			grip.WorldCFrame = head.TransformedWorldCFrame
			local constraint = Instance.new("RigidConstraint")
			constraint.Attachment0 = head
			constraint.Attachment1 = grip
			constraint.Parent = part
		end
	end
	local ground = findBone(model, "Root").WorldPosition
	local frame = CFrame.new(ground) * root.CFrame.Rotation
	local box = Instance.new("Part")
	box.Name = "Collision"
	box.Size = Gomibu.COLLISION
	box.CFrame = frame * CFrame.new(0, Gomibu.COLLISION.Y / 2, 0)
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
			d.CastShadow = d.Name == "Body"
		end
	end
	root.Transparency = 1
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(frame)
	model:PivotTo(CFrame.new())
	model:SetAttribute("Species", "Gomibu")
	model:SetAttribute("AssetId", Gomibu.ASSET_ID)
	model:SetAttribute("Height", Gomibu.HEIGHT)
	model.Parent = parent
	return model
end

-- A detached copy of the prefab standing on the given ground CFrame (position between the feet, -Z is its front).
function Gomibu.spawn(prefab, groundCFrame)
	local copy = prefab:Clone()
	copy:PivotTo(groundCFrame)
	return copy
end

return Gomibu
