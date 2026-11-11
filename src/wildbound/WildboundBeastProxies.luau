-- Nest Heist phase 4a (NB4): stylized Part proxies for the two global beasts, built by the server into
-- ReplicatedStorage.WildboundBeasts.Models so each target client can clone its own visual. They are placeholders, not the
-- final meshes: the uploaded models (EV-W3, Proxies.adopt) replace them when their templates are in ServerStorage.
-- A model named exactly "Viper" or "Pouncer" in that folder (the user's import) always wins over "ViperProxy" and
-- "PouncerProxy", and Proxies.ensure never replaces it. Behaviour never reads the model: hitboxes and timing live in
-- WildboundBeastEncounters, and the red lane and circle are gameplay effects drawn by the client, never part of a model.
-- Orientation: the pivot sits on the ground under the creature and the head faces the pivot's LookVector (-Z).
local Proxies = {}

Proxies.PALETTE = table.freeze({
	viperCharcoal = Color3.fromHex("3A2B46"), viperPlate = Color3.fromHex("584070"), viperPlateLight = Color3.fromHex("6A4A80"),
	viperCrest = Color3.fromHex("80509F"), viperAccent = Color3.fromHex("B8408E"), viperJaw = Color3.fromHex("CBB39C"),
	viperFang = Color3.fromHex("EFE4CC"), viperMouth = Color3.fromHex("A02A62"), viperEye = Color3.fromHex("FF7A0A"),
	pouncerCharcoal = Color3.fromHex("352A3F"), pouncerPlum = Color3.fromHex("5E4568"), pouncerPlumDark = Color3.fromHex("4A3854"),
	pouncerViolet = Color3.fromHex("7B5288"), pouncerMagenta = Color3.fromHex("A8407F"), pouncerIvory = Color3.fromHex("E6D7C0"),
	pouncerEye = Color3.fromHex("FF3FC0"),
})
local C = Proxies.PALETTE

local function part(model, name, size, cframe, color, kind)
	local value = Instance.new(kind or "Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = Enum.Material.SmoothPlastic
	value.TopSurface, value.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	-- A visual only: never collides, never answers a query, never fires contact events, never simulated.
	value.Anchored, value.CanCollide, value.CanQuery, value.CanTouch, value.Massless = true, false, false, false, true
	value.Parent = model
	return value
end

local function eye(model, name, size, cframe, color, shape)
	local value = part(model, name, size, cframe, color)
	value.Material = Enum.Material.Neon
	if shape then value.Shape = shape end
	return value
end

-- A block from a to b (Vector3), `thick` studs square.
local function segment(model, name, a, b, thick, color)
	local length = (b - a).Magnitude
	return part(model, name, Vector3.new(thick, thick, length), CFrame.lookAt((a + b) / 2, b), color)
end

local function finish(model, beast, root)
	model.PrimaryPart = root
	model:SetAttribute("Beast", beast)
	model:SetAttribute("Proxy", true)
	model:SetAttribute("ProxyNote", "Stylized Part placeholder. Import the mesh from assets/models/beasts/ as a model named "
		.. beast .. " in ReplicatedStorage.WildboundBeasts.Models to replace it.")
	return model
end

-- Viper: a thick segmented coil (purple-charcoal plates over a beige belly), a neck rising to a big wedge head with a beige
-- jaw, two ivory fangs, a violet crest and amber Neon eyes. About 10 studs long and 6 tall.
function Proxies.viper()
	local model = Instance.new("Model")
	model.Name = "ViperProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), C.viperCharcoal)
	root.Transparency = 1
	local centre, radius, count = Vector3.new(0, 0, 2.4), 3, 9
	for i = 1, count do
		-- The coil: segments around a ring, shrinking toward the tail, with alternating plate colours.
		local a = (i - 1) / count * math.pi * 2 + math.pi * 0.6
		local scale = 1 - (i - 1) * 0.06
		local at = centre + Vector3.new(math.cos(a) * radius, 0.95 * scale, math.sin(a) * radius)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local frame = CFrame.lookAt(at, at + tangent)
		part(model, "Coil" .. i, Vector3.new(2.3, 1.9, 2.4) * scale, frame, i % 2 == 0 and C.viperPlate or C.viperCharcoal)
		part(model, "Belly" .. i, Vector3.new(1.6, 0.5, 2.3) * scale, frame * CFrame.new(0, -0.75 * scale, 0), C.viperJaw)
		if i % 3 == 1 then
			part(model, "Accent" .. i, Vector3.new(0.4, 0.5, 1.4) * scale, frame * CFrame.new(0, 0.95 * scale, 0), C.viperAccent, "WedgePart")
		end
	end
	local neck = { Vector3.new(0, 1.4, -0.2), Vector3.new(0, 2.8, -0.9), Vector3.new(0, 4.0, -1.5) }
	for i = 1, #neck - 1 do
		segment(model, "Neck" .. i, neck[i], neck[i + 1], 1.9 - i * 0.15, C.viperPlate)
		local mid = (neck[i] + neck[i + 1]) / 2
		part(model, "NeckPlate" .. i, Vector3.new(1.3, 1.4, 0.4), CFrame.lookAt(mid + Vector3.new(0, 0, -0.85), mid + Vector3.new(0, 0, -3)),
			C.viperJaw)
	end
	local head = CFrame.new(0, 4.7, -2.7)
	part(model, "Head", Vector3.new(3.2, 1.5, 3.4), head, C.viperPlateLight)
	part(model, "Snout", Vector3.new(2.6, 1.1, 1.4), head * CFrame.new(0, -0.1, -2.3) * CFrame.Angles(0, math.pi, 0), C.viperPlate, "WedgePart")
	part(model, "Jaw", Vector3.new(2.7, 0.6, 3.4), head * CFrame.new(0, -1.25, -0.5), C.viperJaw)
	part(model, "Mouth", Vector3.new(2.2, 0.4, 2.8), head * CFrame.new(0, -0.85, -0.6), C.viperMouth)
	part(model, "Tongue", Vector3.new(0.25, 0.12, 1.6), head * CFrame.new(0, -0.9, -2.6), C.viperMouth)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Fang" .. (side < 0 and "L" or "R"), Vector3.new(0.3, 1.3, 0.35),
			head * CFrame.new(side * 0.85, -1.1, -2.2) * CFrame.Angles(math.pi, 0, 0), C.viperFang, "WedgePart")
		eye(model, "Eye" .. (side < 0 and "L" or "R"), Vector3.new(0.55, 0.3, 0.5), head * CFrame.new(side * 1.05, 0.45, -1.4)
			* CFrame.Angles(0, 0, side * 0.35), C.viperEye)
	end
	for i = 1, 3 do
		part(model, "Crest" .. i, Vector3.new(0.5, 0.9, 1.4), head * CFrame.new(0, 0.95, 1.2 - i * 0.9), C.viperCrest, "WedgePart")
	end
	return finish(model, "Viper", root)
end

-- Pouncer: a broad, low plum body with a darker abdomen, a charcoal head with ivory fangs, a cluster of magenta Neon
-- eyes, and eight long angular legs (a femur up to the knee, a tibia down to an ivory claw). About 9 studs across.
function Proxies.pouncer()
	local model = Instance.new("Model")
	model.Name = "PouncerProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), C.pouncerCharcoal)
	root.Transparency = 1
	part(model, "Body", Vector3.new(4, 2, 3.6), CFrame.new(0, 2.5, -0.6), C.pouncerPlum)
	part(model, "BodyRidge", Vector3.new(2.4, 0.8, 2.6), CFrame.new(0, 3.8, -0.6), C.pouncerViolet, "WedgePart")
	local abdomen = part(model, "Abdomen", Vector3.new(4.2, 3.4, 4.4), CFrame.new(0, 3.1, 2.8), C.pouncerPlumDark)
	abdomen.Shape = Enum.PartType.Ball
	part(model, "AbdomenMark", Vector3.new(1.6, 0.6, 2.4), CFrame.new(0, 4.75, 2.8), C.pouncerMagenta, "WedgePart")
	local head = CFrame.new(0, 2.3, -2.9)
	part(model, "Head", Vector3.new(2.6, 1.6, 1.6), head, C.pouncerCharcoal)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		eye(model, "Eye" .. tag, Vector3.new(0.75, 0.75, 0.75), head * CFrame.new(side * 0.55, 0.25, -0.75), C.pouncerEye, Enum.PartType.Ball)
		eye(model, "EyeSmall" .. tag, Vector3.new(0.35, 0.35, 0.35), head * CFrame.new(side * 0.4, 0.7, -0.72), C.pouncerEye, Enum.PartType.Ball)
		part(model, "Fang" .. tag, Vector3.new(0.45, 1.5, 0.45), head * CFrame.new(side * 0.6, -1.25, -0.6) * CFrame.Angles(math.pi, 0, 0),
			C.pouncerIvory, "WedgePart")
	end
	for _, side in ipairs({ -1, 1 }) do
		for i, z in ipairs({ -1.9, -0.9, 0.1, 1.1 }) do
			local tag = (side < 0 and "L" or "R") .. i
			local spread = 1 + (i - 2.5) * 0.25
			local hip = Vector3.new(side * 1.9, 2.4, z)
			local knee = Vector3.new(side * 4.0, 4.3, z * 1.5 * spread)
			local foot = Vector3.new(side * 5.2, 0.15, z * 2 * spread)
			segment(model, "Femur" .. tag, hip, knee, 0.7, C.pouncerCharcoal)
			local claw = knee:Lerp(foot, 0.75)
			segment(model, "Tibia" .. tag, knee, claw, 0.6, i % 2 == 0 and C.pouncerPlum or C.pouncerCharcoal)
			segment(model, "Claw" .. tag, claw, foot, 0.4, C.pouncerIvory)
		end
	end
	return finish(model, "Pouncer", root)
end

Proxies.BUILDERS = table.freeze({ Viper = Proxies.viper, Pouncer = Proxies.pouncer })

-- The visual a client clones: the user's imported model when present, else the proxy.
function Proxies.modelFor(models, beast)
	if typeof(models) ~= "Instance" or type(beast) ~= "string" then return nil end
	local real = models:FindFirstChild(beast)
	if real and real:IsA("Model") then return real end
	local proxy = models:FindFirstChild(beast .. "Proxy")
	return proxy and proxy:IsA("Model") and proxy or nil
end

-- EV-W3: the uploaded rigged models live as templates in ServerStorage.WildboundAssets.Beasts (the ids are recorded in
-- assets/models/beasts/uploaded-assets.json). A template is adopted only when it has a "Root" part on the ground with
-- the head along its LookVector (the proxies' convention); the copy is an inert visual: every part anchored, never
-- colliding, queried or touched. The template itself is never changed. Animations are not uploaded yet, so the model
-- moves in its rest pose.
function Proxies.adopt(template, beast)
	if typeof(template) ~= "Instance" or not template:IsA("Model") or type(beast) ~= "string" then return nil end
	local root = template:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local model = template:Clone()
	model.Name = beast
	model.PrimaryPart = model:FindFirstChild("Root")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = true, false, false, false, true
		elseif d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	model:SetAttribute("Beast", beast)
	model:SetAttribute("Proxy", false)
	return model
end

-- Builds ReplicatedStorage.WildboundBeasts.Models and the missing proxies (always kept as the fallback), and adopts the
-- Viper and Pouncer templates when given. Never touches an existing model.
function Proxies.ensure(replicated, templates)
	local root = replicated:FindFirstChild("WildboundBeasts")
	if not root then
		root = Instance.new("Folder")
		root.Name = "WildboundBeasts"
		root.Parent = replicated
	end
	local models = root:FindFirstChild("Models")
	if not models then
		models = Instance.new("Folder")
		models.Name = "Models"
		models.Parent = root
	end
	for beast, build in pairs(Proxies.BUILDERS) do
		if not models:FindFirstChild(beast .. "Proxy") then build().Parent = models end
		if typeof(templates) == "Instance" and not models:FindFirstChild(beast) then
			local real = Proxies.adopt(templates:FindFirstChild(beast), beast)
			if real then real.Parent = models end
		end
	end
	return models
end

return Proxies
