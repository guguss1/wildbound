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
	-- Kids biome: La Nube Gruñona and La Abeja Reina (soft, friendly colours; never a red danger colour).
	nubePuff = Color3.fromHex("B4A8D2"), nubeBelly = Color3.fromHex("8C7FB0"), nubeEye = Color3.fromHex("FFFFFF"),
	nubePupil = Color3.fromHex("2E2840"), nubeBrow = Color3.fromHex("5E5480"), nubeShadow = Color3.fromHex("3A3550"),
	abejaYellow = Color3.fromHex("FFD54A"), abejaBrown = Color3.fromHex("B8793A"), abejaWing = Color3.fromHex("E8F4FF"),
	abejaCrown = Color3.fromHex("F7E3A1"), abejaTip = Color3.fromHex("FFE27A"), abejaEye = Color3.fromHex("2E2418"),
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

-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md): Part blockouts of the four new beasts after the pack's sheets
-- (03_IMAGENES/<X>/<X>_00_FICHA_COMPLETA.png): purple-grey bodies, one danger colour each. Placeholders only: a model
-- named exactly "Streamer", "Root", "Gaze" or "Lurker" in ReplicatedStorage.WildboundBeasts.Models replaces them.
local W = table.freeze({
	plum = Color3.fromHex("4A3858"), plumLight = Color3.fromHex("6E5482"), bone = Color3.fromHex("D9C6D6"),
	moss = Color3.fromHex("8C9A3C"), bark = Color3.fromHex("5A4436"), barkDark = Color3.fromHex("3E2F26"),
	magenta = Color3.fromHex("FF2E9A"), shadow = Color3.fromHex("1E1726"), violet = Color3.fromHex("A050FF"),
	fuchsia = Color3.fromHex("FF46C8"), green = Color3.fromHex("82EB5A"),
})
Proxies.WAVE2_PALETTE = W

-- Streamer: a hunched semi-humanoid about 9 studs tall, very long arms reaching the ground, spring legs, a cavernous
-- mouth with a magenta Neon core, bone spikes and moss tufts on the back.
function Proxies.streamer()
	local model = Instance.new("Model")
	model.Name = "StreamerProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), W.plum)
	root.Transparency = 1
	part(model, "Pelvis", Vector3.new(2.6, 1.6, 2), CFrame.new(0, 4.2, 0.6), W.plum)
	part(model, "Chest", Vector3.new(3.6, 2.6, 2.8), CFrame.new(0, 6, -0.6) * CFrame.Angles(math.rad(-25), 0, 0), W.plumLight)
	local head = CFrame.new(0, 7.2, -2.6)
	part(model, "Head", Vector3.new(2.4, 1.8, 2.4), head, W.plum)
	part(model, "Jaw", Vector3.new(2.2, 0.7, 2.2), head * CFrame.new(0, -1.4, -0.3) * CFrame.Angles(math.rad(25), 0, 0), W.bone)
	eye(model, "MouthCore", Vector3.new(1.3, 1, 0.4), head * CFrame.new(0, -0.6, -1.2), W.magenta)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		eye(model, "Eye" .. tag, Vector3.new(0.35, 0.35, 0.35), head * CFrame.new(side * 0.6, 0.5, -1.2), W.magenta, Enum.PartType.Ball)
		segment(model, "UpperArm" .. tag, Vector3.new(side * 2, 6.6, -1.2), Vector3.new(side * 3.4, 4, -2.6), 0.8, W.plumLight)
		segment(model, "Forearm" .. tag, Vector3.new(side * 3.4, 4, -2.6), Vector3.new(side * 3, 0.6, -4), 0.7, W.plum)
		part(model, "Claw" .. tag, Vector3.new(1.4, 0.4, 1.6), CFrame.new(side * 3, 0.3, -4.4), W.bone, "WedgePart")
		segment(model, "Thigh" .. tag, Vector3.new(side * 1, 4, 0.8), Vector3.new(side * 1.6, 2.4, -0.6), 0.8, W.plum)
		segment(model, "Shin" .. tag, Vector3.new(side * 1.6, 2.4, -0.6), Vector3.new(side * 1.4, 0.3, 1), 0.6, W.plumLight)
		part(model, "Moss" .. tag, Vector3.new(0.8, 0.5, 1.4), CFrame.new(side * 1.2, 7.2, 0.2), W.moss)
	end
	for i = 1, 4 do
		part(model, "Spike" .. i, Vector3.new(0.4, 1.2, 0.8), CFrame.new(0, 7.4 - i * 0.5, -1 + i * 0.7), W.bone, "WedgePart")
	end
	return finish(model, "Streamer", root)
end

-- Root: a broad tree-like body of bark about 10 studs tall, branched horns with moss, two long whip arms and root feet
-- spread on the ground, with green glowing knots.
function Proxies.root()
	local model = Instance.new("Model")
	model.Name = "RootProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), W.bark)
	root.Transparency = 1
	part(model, "Trunk", Vector3.new(4.4, 5, 3.4), CFrame.new(0, 3.6, 0), W.bark)
	part(model, "Shoulders", Vector3.new(5.6, 1.8, 3.2), CFrame.new(0, 6.6, -0.2), W.barkDark)
	local head = CFrame.new(0, 7.9, -1)
	part(model, "Head", Vector3.new(2.4, 1.8, 2), head, W.bark)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		eye(model, "Eye" .. tag, Vector3.new(0.4, 0.3, 0.3), head * CFrame.new(side * 0.6, 0.2, -1.05), W.green)
		segment(model, "Horn" .. tag, Vector3.new(side * 0.8, 8.6, -1), Vector3.new(side * 2.2, 10.4, -0.6), 0.45, W.barkDark)
		segment(model, "HornTip" .. tag, Vector3.new(side * 2.2, 10.4, -0.6), Vector3.new(side * 3.2, 10.6, -1.4), 0.3, W.barkDark)
		part(model, "HornMoss" .. tag, Vector3.new(0.8, 0.4, 0.8), CFrame.new(side * 2.2, 10.5, -0.6), W.moss)
		segment(model, "WhipUpper" .. tag, Vector3.new(side * 2.8, 6.6, -0.4), Vector3.new(side * 4.6, 4.2, -1.6), 0.8, W.bark)
		segment(model, "WhipLower" .. tag, Vector3.new(side * 4.6, 4.2, -1.6), Vector3.new(side * 5.2, 0.6, -3.4), 0.5, W.barkDark)
		for i, z in ipairs({ -1.6, 0, 1.6 }) do
			segment(model, "Foot" .. tag .. i, Vector3.new(side * 1.6, 1.4, z), Vector3.new(side * 3.4, 0.2, z * 1.6), 0.6, W.barkDark)
		end
	end
	for i = 1, 3 do
		eye(model, "Knot" .. i, Vector3.new(0.5, 0.5, 0.2), CFrame.new(-1 + i * 0.6, 2.4 + i * 1.1, -1.75), W.green)
	end
	part(model, "BackMoss", Vector3.new(3.6, 0.6, 2.6), CFrame.new(0, 7.6, 0.6), W.moss)
	return finish(model, "Root", root)
end

-- Gaze: a thin, almost weightless dark silhouette about 11 studs tall with two giant magenta Neon eyes, long fingers
-- framing the face and a frayed lower body that does not touch the ground.
function Proxies.gaze()
	local model = Instance.new("Model")
	model.Name = "GazeProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), W.shadow)
	root.Transparency = 1
	part(model, "Body", Vector3.new(1.6, 5, 1.2), CFrame.new(0, 6, 0), W.shadow)
	for i = 1, 4 do
		part(model, "Tatter" .. i, Vector3.new(0.4, 2.4, 0.4), CFrame.new(-0.9 + i * 0.4, 2.6, (i % 2) * 0.3)
			* CFrame.Angles(0, 0, math.rad((i - 2.5) * 8)), W.plum)
	end
	local head = CFrame.new(0, 10, -0.2)
	part(model, "Head", Vector3.new(2.6, 2.4, 1.6), head, W.shadow)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		eye(model, "Eye" .. tag, Vector3.new(0.95, 0.95, 0.95), head * CFrame.new(side * 0.62, 0.1, -0.7), W.magenta, Enum.PartType.Ball)
		segment(model, "Arm" .. tag, Vector3.new(side * 0.9, 8.2, 0), Vector3.new(side * 1.8, 9.4, -1.2), 0.35, W.plum)
		for f = 1, 3 do
			segment(model, "Finger" .. tag .. f, Vector3.new(side * 1.8, 9.4, -1.2),
				Vector3.new(side * (1.2 + f * 0.15), 9.6 + f * 0.5, -1.4), 0.18, W.plumLight)
		end
	end
	return finish(model, "Gaze", root)
end

-- Lurker: a low, long-limbed predator about 9 studs long and 3.5 tall on four angular legs, a ridge of spines and
-- fuchsia Neon eyes.
function Proxies.lurker()
	local model = Instance.new("Model")
	model.Name = "LurkerProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), W.plum)
	root.Transparency = 1
	part(model, "Body", Vector3.new(2.4, 1.5, 5), CFrame.new(0, 2.4, 0.4), W.plum)
	local head = CFrame.new(0, 2.5, -2.8)
	part(model, "Head", Vector3.new(1.8, 1.1, 1.8), head, W.plumLight)
	part(model, "Snout", Vector3.new(1.4, 0.6, 1), head * CFrame.new(0, -0.2, -1.3) * CFrame.Angles(0, math.pi, 0), W.plum, "WedgePart")
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		eye(model, "Eye" .. tag, Vector3.new(0.35, 0.25, 0.3), head * CFrame.new(side * 0.5, 0.25, -0.9), W.fuchsia)
		for i, z in ipairs({ -1.6, 2.2 }) do
			local leg = tag .. i
			local hip = Vector3.new(side * 1.1, 2.4, z)
			local knee = Vector3.new(side * 2.4, 3.4, z - 0.6)
			local foot = Vector3.new(side * 2.6, 0.15, z - 1.2)
			segment(model, "Thigh" .. leg, hip, knee, 0.5, W.plum)
			segment(model, "Shin" .. leg, knee, foot, 0.35, W.plumLight)
			part(model, "Claw" .. leg, Vector3.new(0.6, 0.3, 0.8), CFrame.new(foot.X, 0.15, foot.Z - 0.3), W.bone, "WedgePart")
		end
	end
	for i = 1, 6 do
		part(model, "Spine" .. i, Vector3.new(0.25, 0.9 + (i % 2) * 0.3, 0.6), CFrame.new(0, 3.5, -1.6 + i * 0.7), W.bone, "WedgePart")
	end
	segment(model, "Tail", Vector3.new(0, 2.4, 2.9), Vector3.new(0, 1.6, 5.4), 0.35, W.plum)
	return finish(model, "Lurker", root)
end

-- Kids biome (odd/tasks/wildbound-kids-beasts.md): La Nube Gruñona, a grumpy storm cloud about 14 x 8 studs: five
-- lilac-grey puff balls over a darker belly, white eye discs with frowning brow bars, hovering HoverStuds over a
-- translucent shadow disc on the ground (the pivot stays on the ground, like every proxy).
function Proxies.nube()
	local model = Instance.new("Model")
	model.Name = "NubeGrunonaProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), C.nubeShadow)
	root.Transparency = 1
	local h = 10 -- Config.BEASTS.NubeGrunona.tuning.HoverStuds (the proxies never require the config)
	local shadow = part(model, "Shadow", Vector3.new(0.1, 40, 40), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2),
		C.nubeShadow)
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Transparency = 0.75
	for i, spec in ipairs({ { 0, 1.2, 0, 8 }, { -4, 0, 0.4, 6 }, { 4, 0, 0.4, 6 }, { -2, 1.6, 1.4, 5.5 }, { 2.4, 1.8, 1.2, 5 } }) do
		local puff = part(model, "Puff" .. i, Vector3.new(spec[4], spec[4], spec[4]), CFrame.new(spec[1], h + spec[2], spec[3]),
			C.nubePuff)
		puff.Shape = Enum.PartType.Ball
	end
	local belly = part(model, "Belly", Vector3.new(12, 2.4, 6), CFrame.new(0, h - 2.4, 0.4), C.nubeBelly)
	belly.Shape = Enum.PartType.Block
	local head = CFrame.new(0, h + 0.6, -3.7)
	part(model, "Head", Vector3.new(4, 2.6, 0.4), head, C.nubePuff)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		local disc = part(model, "Eye" .. tag, Vector3.new(0.2, 1.6, 1.6), head * CFrame.new(side * 1.1, 0, -0.3)
			* CFrame.Angles(0, math.pi / 2, 0), C.nubeEye, "Part")
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.Neon
		local pupil = part(model, "Pupil" .. tag, Vector3.new(0.2, 0.7, 0.7), head * CFrame.new(side * 1.1, -0.2, -0.45)
			* CFrame.Angles(0, math.pi / 2, 0), C.nubePupil)
		pupil.Shape = Enum.PartType.Cylinder
		part(model, "Brow" .. tag, Vector3.new(1.8, 0.35, 0.4), head * CFrame.new(side * 1.1, 1.1, -0.45)
			* CFrame.Angles(0, 0, math.rad(side * -18)), C.nubeBrow)
	end
	return finish(model, "NubeGrunona", root)
end

-- Kids biome: La Abeja Reina, a round queen bee hovering HoverStuds up: an ellipsoid body with alternating yellow and
-- brown bands, two translucent wings, a wax crown, antennae with Neon tips and dark eyes.
function Proxies.abeja()
	local model = Instance.new("Model")
	model.Name = "AbejaReinaProxy"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), C.abejaBrown)
	root.Transparency = 1
	local h = 6 -- Config.BEASTS.AbejaReina.tuning.HoverStuds
	for i, z in ipairs({ -1.2, -0.4, 0.4, 1.2, 2 }) do
		local size = 3.2 - math.abs(z - 0.2) * 0.5
		local band = part(model, "Band" .. i, Vector3.new(size, size, 0.8), CFrame.new(0, h, z), i % 2 == 1 and C.abejaYellow
			or C.abejaBrown)
		band.Shape = Enum.PartType.Ball
	end
	local head = CFrame.new(0, h + 0.4, -2.2)
	local headPart = part(model, "Head", Vector3.new(2, 2, 2), head, C.abejaYellow)
	headPart.Shape = Enum.PartType.Ball
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		local eyeBall = part(model, "Eye" .. tag, Vector3.new(0.6, 0.6, 0.6), head * CFrame.new(side * 0.55, 0.2, -0.8), C.abejaEye)
		eyeBall.Shape = Enum.PartType.Ball
		local wing = part(model, "Wing" .. tag, Vector3.new(3, 0.15, 1.8), CFrame.new(side * 1.9, h + 1.6, 0)
			* CFrame.Angles(0, 0, math.rad(side * 20)), C.abejaWing)
		wing.Transparency = 0.55
		segment(model, "Antenna" .. tag, head.Position + Vector3.new(side * 0.4, 0.9, -0.3),
			head.Position + Vector3.new(side * 0.9, 2, -0.8), 0.15, C.abejaBrown)
		eye(model, "AntennaTip" .. tag, Vector3.new(0.45, 0.45, 0.45), CFrame.new(head.Position + Vector3.new(side * 0.9, 2, -0.8)),
			C.abejaTip, Enum.PartType.Ball)
	end
	part(model, "Crown", Vector3.new(1.4, 0.6, 1.4), head * CFrame.new(0, 1.1, 0.1), C.abejaCrown)
	for i = 1, 3 do
		part(model, "CrownPoint" .. i, Vector3.new(0.3, 0.6, 0.3), head * CFrame.new(-0.5 + (i - 1) * 0.5, 1.6, 0.1), C.abejaCrown)
	end
	part(model, "Stinger", Vector3.new(0.4, 0.4, 0.8), CFrame.new(0, h - 0.2, 2.8), C.abejaBrown, "WedgePart")
	return finish(model, "AbejaReina", root)
end

Proxies.BUILDERS = table.freeze({ Viper = Proxies.viper, Pouncer = Proxies.pouncer, Streamer = Proxies.streamer,
	Root = Proxies.root, Gaze = Proxies.gaze, Lurker = Proxies.lurker, NubeGrunona = Proxies.nube,
	AbejaReina = Proxies.abeja })

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
