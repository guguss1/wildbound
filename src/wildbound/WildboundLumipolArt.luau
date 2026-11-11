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
	-- Studs tall inside the carry capsule (a 1.8-stud glass shell).
	CARRIED_HEIGHT = 1.1,
	-- The feet sit this far over the frame, so they never flicker into the ground.
	FOOT_LIFT = 0.05,
	-- The server loads every mesh of the template once at start, all at once, and waits at most this long.
	VERIFY_SECONDS = 5,
})
local C = Art.CONFIG
Art.SPECIES = "Lumipol"

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- look: a WildboundSpecies look. Only the Lumipol wears the art.
function Art.uses(look)
	return type(look) == "table" and look.name == Art.SPECIES
end

-- A model of at least one part, with no script or humanoid inside.
function Art.valid(template)
	if typeof(template) ~= "Instance" or not template:IsA("Model") then return false end
	local parts = 0
	for _, item in ipairs(template:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Humanoid") then return false end
		if item:IsA("BasePart") then parts += 1 end
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
-- `feet` and facing the frame's look. Returns the art parts, now direct children of `model`, or nil.
function Art.dress(model, template, feet, height)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not Art.valid(template) then return nil end
	if typeof(feet) ~= "CFrame" or not finite(height) or height <= 0 then return nil end
	local art, parts = nil, {}
	local ok = pcall(function()
		art = template:Clone()
		local frame, size = art:GetBoundingBox()
		assert(finite(size.Y) and size.Y > 1e-3, "flat template")
		art.WorldPivot = frame * CFrame.new(0, -size.Y / 2, 0)
		art:ScaleTo(art:GetScale() * height / size.Y)
		art:PivotTo(feet * CFrame.new(0, C.FOOT_LIFT, 0))
		for _, item in ipairs(art:GetDescendants()) do
			if item:IsA("BasePart") then table.insert(parts, item) end
		end
		for _, part in ipairs(parts) do
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.Massless, part.CastShadow = true, false
			part:SetAttribute(C.ATTRIBUTE, true)
			part.Parent = model
		end
	end)
	if art then art:Destroy() end
	if not ok then
		for _, part in ipairs(parts) do part:Destroy() end
		return nil
	end
	return parts
end

return Art
