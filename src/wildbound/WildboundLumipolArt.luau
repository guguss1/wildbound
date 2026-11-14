-- MeshGen1 pass (user, 2026-11-10: "agrega el MeshGen1 como lumipol ya que es su modelo"). Every Lumipol the game
-- shows wears the user's model: ServerStorage.WildboundAssets.LumipolMeshGen, a copy of Workspace.MeshGen1 with its
-- pivot at its feet (record: assets/exports/lumipol-meshgen1-spec.json). The server builds every creature through
-- one function, so this module only dresses a model it is handed: it clones the template, fits it to a height, stands
-- its feet on a frame, and moves its parts in as anchored, massless art that never collides, touches or blocks a ray.
-- The gameplay body is the caller's and is never changed here. A missing or bad template, frame or height dresses
-- nothing, so the caller keeps its primitive look. The template is never changed. Reads no service.
-- Lumipol generated model pass (user, 2026-11-10): MeshGen1's meshes are refused to the place, so the templates are now
-- the generated parent and egg in ServerStorage.WildboundAssets.Lumipol (Parent, Egg; record
-- assets/exports/lumipol-generated-assets.json). The guardian adults wear the parent at PARENT_HEIGHT; every Lumipol egg
-- wears the egg (EGG_HEIGHT in a nest or on the ground, ARMS_EGG_HEIGHT in the arms).
local Art = {}

Art.CONFIG = table.freeze({
	-- The templates: ServerStorage.WildboundAssets[FOLDER][PARENT] and [EGG].
	FOLDER = "Lumipol",
	PARENT = "Parent",
	EGG = "Egg",
	-- Set true on every art part, so clients can tell the art from the gameplay ball.
	ATTRIBUTE = "LumipolArt",
	-- Studs tall at scale 1 (a tutorial or island adult); a wild or nest cria is Species.CRIA_SCALE of it, and the
	-- camp display, the companion and the deposit scale the whole model as before.
	HEIGHT = 2.6,
	-- Studs tall for an island's guardian adult (the user's 4 to 5 studs).
	PARENT_HEIGHT = 4.5,
	-- Studs tall for an egg in a nest or on the ground, and for the egg carried in the arms.
	EGG_HEIGHT = 1.8,
	ARMS_EGG_HEIGHT = 1.5,
	-- User, 2026-11-11: the stolen egg rides in a backpack; this much of it stands in the pack.
	PACK_EGG_HEIGHT = 1.2,
	-- Studs tall inside the carry capsule (a 1.8-stud glass shell).
	CARRIED_HEIGHT = 1.1,
	-- The feet sit this far over the frame, so they never flicker into the ground.
	FOOT_LIFT = 0.05,
	-- The server loads every mesh of the template once at start, all at once, and waits at most this long.
	VERIFY_SECONDS = 5,
	-- Lumipol rig pass: a model dressed with a rigged template carries this attribute and tag.
	RIG_ATTRIBUTE = "LumipolRig",
	RIG_TAG = "WildboundLumipolRig",
})
local C = Art.CONFIG
Art.SPECIES = "Lumipol"
Art.SPECIES_SET = table.freeze({ Lumipol = true, LumipolVioleta = true })

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- look: a WildboundSpecies look. Only Lumipol variants wear the art.
function Art.uses(look)
	return type(look) == "table" and Art.SPECIES_SET[look.name] == true
end

-- A model of at least one part, with no script or humanoid inside.
function Art.valid(template)
	if typeof(template) ~= "Instance" or not template:IsA("Model") then return false end
	local parts = 0
	for _, item in ipairs(template:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Humanoid") then return false end
		if item:IsA("BasePart") then parts += 1 end
	end
	if typeof(tint) == "Color3" then
		local hl = model:FindFirstChild("RarityTintHighlight")
		if not hl then
			hl = Instance.new("Highlight")
			hl.Name = "RarityTintHighlight"
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = model
		end
		hl.FillColor = tint
		hl.FillTransparency = 0.62
		hl.OutlineColor = tint:Lerp(Color3.new(1, 1, 1), 0.35)
		hl.OutlineTransparency = 0.2
	end
	return parts > 0
end

-- assets: the WildboundAssets folder. Returns { Parent = model or nil, Egg = model or nil }, each only when valid.
function Art.templates(assets)
	local found = {}
	local folder = typeof(assets) == "Instance" and assets:FindFirstChild(C.FOLDER) or nil
	if not folder then return found end
	for _, name in ipairs({ C.PARENT, C.EGG }) do
		local template = folder:FindFirstChild(name)
		if Art.valid(template) then found[name] = template end
	end
	return found
end

-- The template's mesh ids, each once, sorted. The server loads each before it trusts the template (Play finding: a
-- session refused the generated meshes, and a mesh that never loads draws nothing).
function Art.meshIds(template)
	local seen, ids = {}, {}
	if typeof(template) ~= "Instance" then return ids end
	for _, item in ipairs(template:GetDescendants()) do
		if item:IsA("MeshPart") then
			local id = item.MeshId
			if type(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

-- True only when every id in `ids` loaded (results[id] == true); an id that never answered counts as failed.
function Art.verified(ids, results)
	if type(ids) ~= "table" or type(results) ~= "table" then return false end
	for _, id in ipairs(ids) do
		if results[id] ~= true then return false end
	end
	return true
end

-- Dresses `model` with a copy of `template`, `height` studs tall, its feet (the bottom centre of its bounds) on
-- `feet` and facing the frame's look. Optional `tint` (Color3) tints parts and SurfaceAppearances for rarity variants.
-- Returns the art parts, now direct children of `model`, or nil.
function Art.dress(model, template, feet, height, tint)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not Art.valid(template) then return nil end
	if typeof(feet) ~= "CFrame" or not finite(height) or height <= 0 then return nil end
	local art, parts = nil, {}
	local ok = pcall(function()
		art = template:Clone()
		local frame, size = art:GetBoundingBox()
		-- Lumipol rig pass: GetBoundingBox misreads a skinned MeshPart (2.2 instead of 3.8 studs tall for the v2 rig),
		-- so a rigged template is measured from its parts' own boxes, upright in the template's pivot frame.
		if Art.rigged(art) then frame, size = Art.partBounds(art) end
		assert(finite(size.Y) and size.Y > 1e-3, "flat template")
		-- Studio run 2026-11-11: a template with a PrimaryPart (the blue egg's Egg_Mesh) ignores WorldPivot, so the
		-- egg landed with its centre on the frame (half under the ground). Pivot from the bounds, not the part.
		art.PrimaryPart = nil
		art.WorldPivot = frame * CFrame.new(0, -size.Y / 2, 0)
		art:ScaleTo(art:GetScale() * height / size.Y)
		art:PivotTo(feet * CFrame.new(0, C.FOOT_LIFT, 0))
		for _, item in ipairs(art:GetDescendants()) do
			if item:IsA("BasePart") then table.insert(parts, item) end
		end
		for _, part in ipairs(parts) do
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.Massless, part.CastShadow = true, false
			if typeof(tint) == "Color3" then
				part:SetAttribute("LumipolViolet", true)
				for _, child in ipairs(part:GetDescendants()) do
					if child:IsA("SurfaceAppearance") then
						pcall(function() child.Color = tint end)
					end
				end
			end
			part:SetAttribute(C.ATTRIBUTE, true)
			part.Parent = model
		end
	end)
	if art then art:Destroy() end
	if not ok then
		for _, part in ipairs(parts) do part:Destroy() end
		return nil
	end
	-- Lumipol rig pass (2026-11-11): a rigged template's skinned MeshPart keeps its Bones (they are its children), and
	-- the model gets an AnimationController with an Animator plus the RIG_TAG / RIG_ATTRIBUTE, so the client
	-- (WildboundLumipolAnim) moves the bones. A flat template gets none of this.
	if Art.rigged(parts) then
		if not model:FindFirstChildWhichIsA("AnimationController") then
			local controller = Instance.new("AnimationController")
			controller.Name = "LumipolAnimation"
			Instance.new("Animator").Parent = controller
			controller.Parent = model
		end
		model:SetAttribute(C.RIG_ATTRIBUTE, true)
		model:AddTag(C.RIG_TAG)
	end
	if typeof(tint) == "Color3" then
		model:SetAttribute("LumipolViolet", true)
	end
	return parts
end

-- The bounds of `model`'s BaseParts (from each part's CFrame and Size), in the frame of the model's pivot rotation.
-- Returns the centre frame and the size, like GetBoundingBox.
function Art.partBounds(model)
	local turn = model:GetPivot().Rotation
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local h = part.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local p = turn:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
						low, high = low:Min(p), high:Max(p)
					end
				end
			end
		end
	end
	return turn * CFrame.new((low + high) / 2), high - low
end

-- True when any of `parts` (or a template model) holds Bones: the rigged Lumipol.
function Art.rigged(parts)
	if typeof(parts) == "Instance" then parts = parts:GetDescendants() end
	if type(parts) ~= "table" then return false end
	for _, part in ipairs(parts) do
		if typeof(part) == "Instance" and (part:IsA("Bone") or part:FindFirstChildWhichIsA("Bone", true)) then
			return true
		end
	end
	return false
end

return Art
