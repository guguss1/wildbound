-- CG1 (odd/tasks/wildbound-caramelo.md, user-approved): each Caramelo egg has its own candy look, built only from
-- primitives (Parts and Sphere SpecialMeshes; no upload). Gomibu: a translucent gummy egg that squashes gently in its
-- nest. Flanfuria: a flan egg, a cream body under a caramel cap that drips down its sides. Tortidragon: a cake egg, a
-- sponge body with a cream band and a strawberry on top. A Legendaria egg of any of them also has a golden shimmer.
-- The rarity stays readable: a thin neon rim at the egg's foot and the egg's glow are in the rarity colour.
-- Shared through ReplicatedStorage: the server builds the egg in the nest, on the ground, in the carried backpack and on
-- the own base's cradle spot (WildboundServer `visual` and `Heist.syncEggArms`); the client only plays the gummy bob
-- (WildboundCandyEggBob). A species that is not a Caramelo species is never touched (uses() is false).
local CandyEggArt = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

-- The sub-model holding the candy parts, its attributes and the client tag for the bob.
CandyEggArt.MODEL = "CandyEggArt"
CandyEggArt.ATTRIBUTE = "CandyEgg" -- the species, on the egg's own model and on the CandyEggArt sub-model
CandyEggArt.RARITY_ATTRIBUTE = "CandyEggRarity"
CandyEggArt.GOLDEN_ATTRIBUTE = "CandyEggGolden"
CandyEggArt.BOB_TAG = "WildboundCandyEggBob"
-- Where an egg is drawn: only a nest egg bobs.
CandyEggArt.CONTEXTS = freeze({ nest = true, ground = true, pack = true, cradle = true })
-- Studs tall: a nest / ground / cradle egg, and the egg that peeks out of the backpack.
CandyEggArt.HEIGHT = 2.2
CandyEggArt.PACK_HEIGHT = 1.2
-- The rarity colours, equal to WildboundEggLoop.RARITY_COLOR and the server's RARITY_GLOW (pinned by a suite case).
CandyEggArt.RIM = freeze({
	Comun = { 205, 235, 215 }, Rara = { 110, 175, 255 }, Epica = { 190, 120, 255 }, Legendaria = { 255, 205, 80 },
})
CandyEggArt.GOLD = freeze({ 255, 214, 90 })
-- The parts each species' egg is made of (besides the RarityRim every egg has).
CandyEggArt.PARTS = freeze({
	Gomibu = { "GummyShell", "GummyCore", "GummyShine" },
	Flanfuria = { "FlanBody", "CaramelCap", "CaramelDrip" },
	Tortidragon = { "CakeSponge", "CreamBand", "Strawberry", "StrawberryLeaf" },
})
-- The gummy bob: a slow squash (taller and thinner, then shorter and wider), volume roughly kept.
CandyEggArt.BOB = freeze({ PERIOD = 1.6, AMOUNT = 0.06 })

function CandyEggArt.uses(species)
	return type(species) == "string" and CandyEggArt.PARTS[species] ~= nil
end

local function rgb(value) return Color3.fromRGB(value[1], value[2], value[3]) end

function CandyEggArt.rimColor(rarity)
	return rgb(CandyEggArt.RIM[rarity] or CandyEggArt.RIM.Comun)
end

-- The bob's scale at time t (seconds): horizontal, vertical. 1, 1 at t = 0 and every half period.
function CandyEggArt.bob(t)
	if type(t) ~= "number" or t ~= t then return 1, 1 end
	local wave = math.sin(t * 2 * math.pi / CandyEggArt.BOB.PERIOD) * CandyEggArt.BOB.AMOUNT
	return 1 - wave / 2, 1 + wave
end

local function part(holder, name, size, frame, color, material, shape)
	local item = Instance.new("Part")
	item.Name, item.Size, item.CFrame = name, size, frame
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
	item.CastShadow = false
	item.Material, item.Color = material or Enum.Material.SmoothPlastic, color
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape == "ellipsoid" then
		-- A Ball part is always round; a Sphere SpecialMesh follows the part's Size, so it gives an egg shape.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = item
	elseif shape then
		item.Shape = shape
	end
	item.Parent = holder
	return item
end
-- A vertical cylinder (Roblox cylinders lie along their X axis).
local function disc(holder, name, height, diameter, frame, color, material)
	return part(holder, name, Vector3.new(height, diameter, diameter), frame * CFrame.Angles(0, 0, math.pi / 2), color,
		material, Enum.PartType.Cylinder)
end

local builders = {}
function builders.Gomibu(holder, base, h, w)
	local centre = base * CFrame.new(0, h / 2, 0)
	local shell = part(holder, "GummyShell", Vector3.new(w, h, w), centre, rgb({ 255, 127, 168 }), Enum.Material.Glass,
		"ellipsoid")
	shell.Transparency, shell.Reflectance = 0.35, 0.15
	local core = part(holder, "GummyCore", Vector3.new(w * 0.55, h * 0.55, w * 0.55), centre * CFrame.new(0, -h * 0.04, 0),
		rgb({ 255, 170, 200 }), Enum.Material.Neon, "ellipsoid")
	core.Transparency = 0.45
	local shine = part(holder, "GummyShine", Vector3.new(w * 0.18, h * 0.22, w * 0.1),
		centre * CFrame.new(-w * 0.22, h * 0.2, -w * 0.4), rgb({ 255, 240, 248 }), Enum.Material.Neon, "ellipsoid")
	shine.Transparency = 0.3
end
function builders.Flanfuria(holder, base, h, w)
	local centre = base * CFrame.new(0, h / 2, 0)
	part(holder, "FlanBody", Vector3.new(w, h, w), centre, rgb({ 246, 214, 140 }), Enum.Material.SmoothPlastic, "ellipsoid")
	local caramel = rgb({ 158, 82, 24 })
	local cap = part(holder, "CaramelCap", Vector3.new(w * 0.9, h * 0.42, w * 0.9), centre * CFrame.new(0, h * 0.31, 0),
		caramel, Enum.Material.Glass, "ellipsoid")
	cap.Reflectance = 0.2
	-- Slender streaks from under the cap's rim down the body (Play: round drips read as eyes), lying on the surface.
	for index = 1, 7 do
		local angle = (index - 1) * 2 * math.pi / 7 + 0.3
		local long = index % 2 == 0 and 0.42 or 0.3
		local y = 0.15 - long / 2 -- the drip's centre, in heights over the egg's centre
		local radius = 0.5 * math.sqrt(math.max(0, 1 - (y / 0.5) ^ 2)) - 0.015
		local drip = part(holder, "CaramelDrip", Vector3.new(w * 0.09, h * long, w * 0.07),
			centre * CFrame.Angles(0, angle, 0) * CFrame.new(0, h * y, -w * radius), caramel, Enum.Material.Glass, "ellipsoid")
		drip.Reflectance = 0.2
	end
end
function builders.Tortidragon(holder, base, h, w)
	local centre = base * CFrame.new(0, h / 2, 0)
	part(holder, "CakeSponge", Vector3.new(w, h, w), centre, rgb({ 233, 186, 118 }), Enum.Material.Sand, "ellipsoid")
	disc(holder, "CreamBand", h * 0.14, w * 1.04, centre * CFrame.new(0, -h * 0.02, 0), rgb({ 255, 248, 236 }),
		Enum.Material.SmoothPlastic)
	disc(holder, "CreamBand", h * 0.08, w * 0.6, centre * CFrame.new(0, h * 0.44, 0), rgb({ 255, 248, 236 }),
		Enum.Material.SmoothPlastic)
	part(holder, "Strawberry", Vector3.new(w * 0.3, h * 0.24, w * 0.3), centre * CFrame.new(0, h * 0.56, 0),
		rgb({ 222, 38, 58 }), Enum.Material.SmoothPlastic, "ellipsoid")
	part(holder, "StrawberryLeaf", Vector3.new(w * 0.26, h * 0.04, w * 0.26), centre * CFrame.new(0, h * 0.67, 0),
		rgb({ 70, 160, 70 }), Enum.Material.SmoothPlastic, "ellipsoid")
end

-- model: the egg's Model (the candy parts go into a child Model named CandyEggArt). base: the CFrame of the egg's foot.
-- height: studs tall (CandyEggArt.HEIGHT when nil). rarity: the egg's rarity tier. context: one of CONTEXTS.
-- Returns the list of candy parts (anchored; the backpack welds them) or nil when species is not a Caramelo species.
function CandyEggArt.build(model, base, height, species, rarity, context)
	if not CandyEggArt.uses(species) or typeof(model) ~= "Instance" or typeof(base) ~= "CFrame" then return nil end
	height = type(height) == "number" and height > 0 and height or CandyEggArt.HEIGHT
	context = CandyEggArt.CONTEXTS[context] and context or "nest"
	local holder = Instance.new("Model")
	holder.Name = CandyEggArt.MODEL
	local width = height * 0.74
	builders[species](holder, base, height, width)
	local rim = disc(holder, "RarityRim", height * 0.06, width * 0.92, base * CFrame.new(0, height * 0.1, 0),
		CandyEggArt.rimColor(rarity), Enum.Material.Neon)
	rim.Transparency = 0.15
	local golden = rarity == "Legendaria"
	if golden then
		local glaze = part(holder, "GoldGlaze", Vector3.new(width * 1.05, height * 1.03, width * 1.05),
			base * CFrame.new(0, height / 2, 0), rgb(CandyEggArt.GOLD), Enum.Material.Neon, "ellipsoid")
		glaze.Transparency = 0.82
		local shimmer = Instance.new("ParticleEmitter")
		shimmer.Name = "GoldShimmer"
		shimmer.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		shimmer.Color = ColorSequence.new(rgb(CandyEggArt.GOLD))
		shimmer.LightEmission, shimmer.Rate = 1, 10
		shimmer.Size = NumberSequence.new(height * 0.16, 0)
		shimmer.Lifetime, shimmer.Speed = NumberRange.new(0.6, 1), NumberRange.new(0.3, 0.8)
		shimmer.SpreadAngle = Vector2.new(180, 180)
		shimmer.Parent = glaze
	end
	holder:SetAttribute(CandyEggArt.ATTRIBUTE, species)
	holder:SetAttribute(CandyEggArt.RARITY_ATTRIBUTE, rarity)
	holder:SetAttribute(CandyEggArt.GOLDEN_ATTRIBUTE, golden)
	holder:SetAttribute("Context", context)
	holder.WorldPivot = base
	model:SetAttribute(CandyEggArt.ATTRIBUTE, species)
	model:SetAttribute(CandyEggArt.RARITY_ATTRIBUTE, rarity)
	if species == "Gomibu" and context == "nest" then
		game:GetService("CollectionService"):AddTag(holder, CandyEggArt.BOB_TAG)
	end
	holder.Parent = model
	local parts = {}
	for _, item in ipairs(holder:GetChildren()) do
		if item:IsA("BasePart") then table.insert(parts, item) end
	end
	return parts
end

-- The backpack: the candy parts follow the shell they hide (unanchored, massless, one Weld each, offsets kept).
function CandyEggArt.weldTo(parts, shell)
	local joints = {}
	for _, item in ipairs(parts or {}) do
		item.Anchored, item.Massless = false, true
		local joint = Instance.new("Weld")
		joint.Name, joint.Part0, joint.Part1, joint.C0 = "CandyEggJoint", shell, item, shell.CFrame:ToObjectSpace(item.CFrame)
		joint.Parent = item
		table.insert(joints, joint)
	end
	return joints
end

return CandyEggArt
