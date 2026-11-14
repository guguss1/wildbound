-- Rebuilds Workspace.WildboundBeastGallery: every creature of Wildbound side by side, each on a pedestal with a sign
-- (name, status, what it does, its mechanics). Editor preview only: WildboundHub.server.luau destroys the gallery when a
-- session starts, so nothing here runs or exists in a game.
--
-- Run in Studio (Edit, command bar or the MCP execute_luau tool). It only clears and fills the gallery folder; it reads
-- (never changes) ServerStorage.WildboundAssets and Workspace.SistemaSonriente.ElSonriente. It does not save the place.
--
-- Layout: the viewer stands at X < 383 looking +X (+Z is to the right). Signs at X = 383.5, creatures at X = 394.
-- The Pradera road crosses the row at Z = 0, so the guardians and the planned creatures sit at Z < 0 and the director
-- beasts at Z > 0, 22 studs apart (clear baseplate from Z = -140 to Z = 188).
--
-- Every display copy is inert: scripts, sounds, prompts, humanoids and package links are removed; every part is
-- anchored, never collides and never fires touch events.
--
-- Sign text is checked against src/wildbound (WildboundBeastConfig, the beast behaviour modules, WildboundIsland,
-- WildboundSiluetaStalk/Moves), the overview (docs/wildbound-game-overview.md section 5), the Scuttler plan
-- (docs/design/wildbound-scuttler-plan.md) and SistemaSonriente's own script headers (read only), on 2026-11-14.

local ServerStorage = game:GetService("ServerStorage")

-- The pedestal is 3 studs tall so even the small creatures stand above the signs' top edge.
local ROW_X, SIGN_X, PEDESTAL_TOP = 394, 383.5, 3

local STATUS = {
	play = { text = "En juego", color = Color3.fromRGB(70, 170, 90) },
	code = { text = "Solo código", color = Color3.fromRGB(205, 150, 40) },
	building = { text = "En construcción", color = Color3.fromRGB(60, 130, 200) },
	design = { text = "Solo diseño", color = Color3.fromRGB(120, 120, 130) },
}

-- source: { asset = path under ServerStorage.WildboundAssets } | { sonriente = true } | { proxy = "nube" | "abeja" }
-- | { placeholder = true }. yaw: degrees around Y so the creature faces the viewer (-X).
local ENTRIES = {
	{ key = "Silueta", z = -132, title = "La Silueta", status = "play", source = { asset = { "SiluetaV3" } }, yaw = 90,
		what = "Tu cazadora personal en la niebla del bosque (aquí, más pequeña).",
		lines = {
			"Hay una por jugador, solo te persigue a ti y vive en la niebla.",
			"Te ronda de lejos, aparece y desaparece, y luego ataca.",
			"De noche es más rápida. Avisa 0,9 s antes de golpear.",
			"1er golpe: se te cae el huevo. 2º golpe: pierdes.",
			"Escapa: corre, escóndete o apúntale con la linterna.",
		} },
	{ key = "PadreIsla", z = -110, title = "Padre de isla", status = "play", source = { asset = { "Lumipol", "Parent" } }, yaw = 90,
		what = "El adulto que cuida los huevos de su nido.",
		lines = {
			"Duerme hasta que alguien roba un huevo.",
			"Despierta, grita y persigue al ladrón sin salir de su isla.",
			"Se levanta, avisa y golpea: se te cae el huevo.",
			"Busca los huevos caídos y los lleva de vuelta al nido.",
			"Escapa: corre con sprint y sal de su isla.",
		} },
	{ key = "Sonriente", z = -88, title = "El Sonriente", status = "play", source = { sonriente = true }, yaw = 90,
		what = "Guardián del Huevo Sonriente en el bosque oscuro.",
		lines = {
			"Vigila su nido y persigue a quien lleva el huevo.",
			"Ataques: zarpazo, embestida, manos del suelo, apagón, grito.",
			"Si te atrapa, se te cae el huevo y caes al suelo.",
			"Escapa: nunca sale del bosque oscuro.",
		} },
	{ key = "NubeGrunona", z = -66, title = "Nube Gruñona", status = "building", source = { proxy = "nube" }, yaw = 90,
		what = "Cuida el estanque de la Pradera. Nunca hace daño.",
		lines = {
			"Si te ve, gruñe y te sigue. No ve bajo los techos.",
			"Aviso: círculo de rayo (1 s). Te tira el huevo y te marca.",
			"Si te da otra vez, una ráfaga te lleva al portón.",
			"Escapa: métete bajo un techo o aléjate del estanque.",
		} },
	{ key = "AbejaReina", z = -44, title = "Abeja Reina", status = "building", source = { proxy = "abeja" }, yaw = 90,
		what = "Cuida La Colmena en el evento. Nunca hace daño.",
		lines = {
			"No te ve: te oye. Si caminas despacio, no te encuentra.",
			"Aviso: línea de picada (1,2 s). Te tira el huevo.",
			"Pegajoso: 6 s más lento; otra picada te manda lejos.",
			"Escapa: muévete despacio o aléjate de La Colmena.",
		} },
	{ key = "Scuttler", z = -22, title = "Scuttler", status = "design", source = { placeholder = true }, yaw = 90,
		what = "Insecto cazador que adivina tu ruta. Todavía no existe.",
		lines = {
			"Bestia planeada para cualquier zona fuera de las seguras.",
			"Predice por dónde vas y hace cargas falsas.",
			"Pulso de pánico: un círculo que te frena.",
			"Esquiva perfecta: se cae y queda en el suelo.",
		} },
	{ key = "Viper", z = 22, title = "Viper, la víbora", status = "play", source = { asset = { "Beasts", "Viper" } }, yaw = 0,
		what = "Una serpiente que te embiste en línea recta.",
		lines = {
			"Aparece en cualquier zona fuera de las zonas seguras.",
			"Aviso: línea roja (1,15 s) que se queda fija al final.",
			"Embiste muy rápido; árboles y muros la frenan.",
			"Escapa: sal de la línea roja hacia un lado.",
		} },
	{ key = "Pouncer", z = 44, title = "Pouncer, la araña", status = "play", source = { asset = { "Beasts", "Pouncer" } }, yaw = 0,
		what = "Una araña que salta encima de ti.",
		lines = {
			"Aparece en cualquier zona fuera de las zonas seguras.",
			"Aviso: círculo rojo donde vas a estar (1,3 s).",
			"Salta 2 o 3 veces seguidas.",
			"Escapa: sal del círculo antes de que caiga.",
		} },
	{ key = "Streamer", z = 66, title = "Streamer", status = "play", source = { asset = { "Beasts", "Streamer" } }, yaw = 90,
		what = "Grita, te empuja y después embiste.",
		lines = {
			"Aparece en cualquier zona fuera de las zonas seguras.",
			"Tiembla, grita: un anillo que empuja (aviso 0,75 s).",
			"Luego embiste por un carril que se fija al final.",
			"Esquiva perfecta: se estrella y queda aturdido.",
		} },
	{ key = "Root", z = 88, title = "Root, las raíces", status = "play", source = { asset = { "Beasts", "Root" } }, yaw = 90,
		what = "Raíces que salen del suelo para atraparte.",
		lines = {
			"Aparece en cualquier zona fuera de las zonas seguras.",
			"Grietas marcan 3 líneas: las raíces salen y te frenan.",
			"Muros de raíces te encierran con una sola salida.",
			"Escapa: sal por la abertura antes del latigazo.",
		} },
	{ key = "Gaze", z = 110, title = "Gaze, la mirada", status = "play", source = { asset = { "Beasts", "Gaze" } }, yaw = 90,
		what = "Unos ojos que te atacan si los miras demasiado.",
		lines = {
			"Aparece en cualquier zona, lejos de ti.",
			"Si lo miras 3,5 s seguidos, carga un círculo violeta.",
			"El círculo explota en tu lugar a los 1,25 s.",
			"Escapa: aparta la vista, escóndete o sal del círculo.",
		} },
	{ key = "Lurker", z = 132, title = "Lurker, el acechador", status = "play", source = { asset = { "Beasts", "Lurker" } }, yaw = 90,
		what = "Se acerca cuando no lo miras.",
		lines = {
			"Aparece detrás de ti, en cualquier zona.",
			"Si lo miras, se queda quieto y retrocede.",
			"Si no lo miras, se acerca y salta (aviso 0,8 s).",
			"Esquiva perfecta: se pasa de largo y queda aturdido.",
		} },
	{ key = "Gargoyle", z = 154, title = "Gargoyle", status = "code", source = { asset = { "Beasts", "Gargoyle" } }, yaw = 0,
		what = "Una estatua del cementerio que despierta.",
		lines = {
			"Solo plantilla: todavía no aparece en el juego.",
			"Diseño: vive en el Cementerio.",
			"Modelo subido, sin animaciones ni ataques.",
		} },
	{ key = "Mire", z = 176, title = "Mire", status = "code", source = { asset = { "Beasts", "Mire" } }, yaw = 0,
		what = "Una bestia que acecha escondida en el pantano.",
		lines = {
			"Solo plantilla: todavía no aparece en el juego.",
			"Diseño: vive en el Pantano.",
			"Modelo subido, sin animaciones ni ataques.",
		} },
}

-- Part helpers ------------------------------------------------------------------------------------------------------

local function part(parent, name, size, cframe, color, material)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.TopSurface, value.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	value.Anchored, value.CanCollide, value.CanTouch, value.Massless = true, false, false, true
	value.CastShadow = false
	value.Parent = parent
	return value
end

-- La Nube Gruñona and La Abeja Reina: the shapes of WildboundBeastProxies.nube / .abeja (repo), built here directly
-- because the Studio copy of that module does not have them yet.
local NUBE = { puff = Color3.fromHex("B4A8D2"), belly = Color3.fromHex("8C7FB0"), eye = Color3.fromHex("FFFFFF"),
	pupil = Color3.fromHex("2E2840"), brow = Color3.fromHex("5E5480"), shadow = Color3.fromHex("3A3550") }
local ABEJA = { yellow = Color3.fromHex("FFD54A"), brown = Color3.fromHex("B8793A"), wing = Color3.fromHex("E8F4FF"),
	crown = Color3.fromHex("F7E3A1"), tip = Color3.fromHex("FFE27A"), eye = Color3.fromHex("2E2418") }

local function nubeModel()
	local model = Instance.new("Model")
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), NUBE.shadow)
	root.Transparency = 1
	local h = 10
	local shadow = part(model, "Shadow", Vector3.new(0.1, 16, 16), CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2),
		NUBE.shadow)
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Transparency = 0.75
	for i, spec in ipairs({ { 0, 1.2, 0, 8 }, { -4, 0, 0.4, 6 }, { 4, 0, 0.4, 6 }, { -2, 1.6, 1.4, 5.5 }, { 2.4, 1.8, 1.2, 5 } }) do
		local puff = part(model, "Puff" .. i, Vector3.new(spec[4], spec[4], spec[4]), CFrame.new(spec[1], h + spec[2], spec[3]),
			NUBE.puff)
		puff.Shape = Enum.PartType.Ball
	end
	part(model, "Belly", Vector3.new(12, 2.4, 6), CFrame.new(0, h - 2.4, 0.4), NUBE.belly)
	local head = CFrame.new(0, h + 0.6, -3.7)
	part(model, "Head", Vector3.new(4, 2.6, 0.4), head, NUBE.puff)
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		local disc = part(model, "Eye" .. tag, Vector3.new(0.2, 1.6, 1.6), head * CFrame.new(side * 1.1, 0, -0.3)
			* CFrame.Angles(0, math.pi / 2, 0), NUBE.eye, Enum.Material.Neon)
		disc.Shape = Enum.PartType.Cylinder
		local pupil = part(model, "Pupil" .. tag, Vector3.new(0.2, 0.7, 0.7), head * CFrame.new(side * 1.1, -0.2, -0.45)
			* CFrame.Angles(0, math.pi / 2, 0), NUBE.pupil)
		pupil.Shape = Enum.PartType.Cylinder
		part(model, "Brow" .. tag, Vector3.new(1.8, 0.35, 0.4), head * CFrame.new(side * 1.1, 1.1, -0.45)
			* CFrame.Angles(0, 0, math.rad(side * -18)), NUBE.brow)
	end
	model.PrimaryPart = root
	return model
end

local function abejaModel()
	local model = Instance.new("Model")
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), ABEJA.brown)
	root.Transparency = 1
	local h = 6
	for i, z in ipairs({ -1.2, -0.4, 0.4, 1.2, 2 }) do
		local size = 3.2 - math.abs(z - 0.2) * 0.5
		local band = part(model, "Band" .. i, Vector3.new(size, size, 0.8), CFrame.new(0, h, z),
			i % 2 == 1 and ABEJA.yellow or ABEJA.brown)
		band.Shape = Enum.PartType.Ball
	end
	local head = CFrame.new(0, h + 0.4, -2.2)
	part(model, "Head", Vector3.new(2, 2, 2), head, ABEJA.yellow).Shape = Enum.PartType.Ball
	for _, side in ipairs({ -1, 1 }) do
		local tag = side < 0 and "L" or "R"
		part(model, "Eye" .. tag, Vector3.new(0.6, 0.6, 0.6), head * CFrame.new(side * 0.55, 0.2, -0.8), ABEJA.eye).Shape =
			Enum.PartType.Ball
		local wing = part(model, "Wing" .. tag, Vector3.new(3, 0.15, 1.8), CFrame.new(side * 1.9, h + 1.6, 0)
			* CFrame.Angles(0, 0, math.rad(side * 20)), ABEJA.wing)
		wing.Transparency = 0.55
		local a = head.Position + Vector3.new(side * 0.4, 0.9, -0.3)
		local b = head.Position + Vector3.new(side * 0.9, 2, -0.8)
		part(model, "Antenna" .. tag, Vector3.new(0.15, 0.15, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), ABEJA.brown)
		part(model, "AntennaTip" .. tag, Vector3.new(0.45, 0.45, 0.45), CFrame.new(b), ABEJA.tip, Enum.Material.Neon).Shape =
			Enum.PartType.Ball
	end
	part(model, "Crown", Vector3.new(1.4, 0.6, 1.4), head * CFrame.new(0, 1.1, 0.1), ABEJA.crown)
	for i = 1, 3 do
		part(model, "CrownPoint" .. i, Vector3.new(0.3, 0.6, 0.3), head * CFrame.new(-0.5 + (i - 1) * 0.5, 1.6, 0.1), ABEJA.crown)
	end
	local stinger = Instance.new("WedgePart")
	stinger.Name = "Stinger"
	stinger.Size, stinger.CFrame, stinger.Color = Vector3.new(0.4, 0.4, 0.8), CFrame.new(0, h - 0.2, 2.8), ABEJA.brown
	stinger.Anchored, stinger.CanCollide, stinger.CanTouch = true, false, false
	stinger.Parent = model
	model.PrimaryPart = root
	return model
end

-- A neutral stand-in for a creature with no art yet: a dark block with a big question mark facing the viewer.
local function placeholderModel()
	local model = Instance.new("Model")
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), Color3.fromRGB(60, 60, 66))
	root.Transparency = 1
	local block = part(model, "Placeholder", Vector3.new(6, 4, 3), CFrame.new(0, 2, 0), Color3.fromRGB(70, 70, 78))
	block.Transparency = 0.25
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = block
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "?"
	mark.Font = Enum.Font.GothamBlack
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(235, 235, 240)
	mark.Parent = gui
	model.PrimaryPart = root
	return model
end

-- Display copies ----------------------------------------------------------------------------------------------------

local REMOVE = { "LuaSourceContainer", "Sound", "ProximityPrompt", "Humanoid", "PackageLink", "ClickDetector",
	"BindableEvent", "BindableFunction", "RemoteEvent", "RemoteFunction" }

local function makeInert(model)
	for _, d in ipairs(model:GetDescendants()) do
		for _, class in ipairs(REMOVE) do
			if d.Parent and d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch = true, false, false
		end
	end
	return model
end

local function creature(entry)
	local source = entry.source
	if source.asset then
		local node = ServerStorage:FindFirstChild("WildboundAssets")
		for _, name in ipairs(source.asset) do
			node = node and node:FindFirstChild(name)
		end
		if node and node:IsA("Model") then return makeInert(node:Clone()), "real" end
	elseif source.sonriente then
		local folder = workspace:FindFirstChild("SistemaSonriente")
		local original = folder and folder:FindFirstChild("ElSonriente")
		if original and original:IsA("Model") then
			local copy = original:Clone() -- read and clone only: nothing inside SistemaSonriente is changed
			if not copy.PrimaryPart then
				copy.PrimaryPart = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
			end
			return makeInert(copy), "real"
		end
	elseif source.proxy == "nube" then
		return nubeModel(), "proxy"
	elseif source.proxy == "abeja" then
		return abejaModel(), "proxy"
	end
	return placeholderModel(), "placeholder"
end

-- Signs -------------------------------------------------------------------------------------------------------------

local SIGN_WOOD = Color3.fromRGB(58, 46, 34)

local function label(parent, props)
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Top
	value.TextWrapped = true
	value.TextColor3 = Color3.fromRGB(245, 238, 225)
	for key, v in pairs(props) do
		value[key] = v
	end
	value.Parent = parent
	return value
end

local function sign(exhibit, entry, z)
	local status = STATUS[entry.status]
	-- A lectern facing -X, tilted back 20 degrees, low enough not to hide the creature behind it.
	local board = part(exhibit, "Sign", Vector3.new(14, 5.6, 0.3),
		CFrame.new(SIGN_X, 2.9, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(20), 0, 0), SIGN_WOOD,
		Enum.Material.Wood)
	board.CastShadow = true
	for _, side in ipairs({ -1, 1 }) do
		part(exhibit, "Post", Vector3.new(0.4, 2, 0.4), CFrame.new(SIGN_X + 0.6, 1, z + side * 5), SIGN_WOOD, Enum.Material.Wood)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 24), UDim.new(0, 24)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 14), UDim.new(0, 12)
	padding.Parent = frame
	label(frame, { Name = "Title", Text = entry.title, Font = Enum.Font.GothamBlack, TextSize = 46,
		Size = UDim2.new(0.66, 0, 0, 52) })
	local pill = Instance.new("Frame")
	pill.Name = "Status"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, 0, 0, 6)
	pill.Size = UDim2.new(0.32, 0, 0, 40)
	pill.BackgroundColor3 = status.color
	pill.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = pill
	label(pill, { Name = "Text", Text = status.text, Font = Enum.Font.GothamBold, TextSize = 26,
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = Color3.new(1, 1, 1) })
	label(frame, { Name = "What", Text = entry.what, Font = Enum.Font.GothamBold, TextSize = 26,
		Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(255, 214, 120) })
	local bullets = {}
	for _, line in ipairs(entry.lines) do
		table.insert(bullets, "• " .. line)
	end
	-- 28 px fits the longest five-line sign (La Silueta) on one line per bullet.
	label(frame, { Name = "Mechanics", Text = table.concat(bullets, "\n"), Font = Enum.Font.Gotham, TextSize = 28,
		Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 1, -98) })
	return board
end

-- Build -------------------------------------------------------------------------------------------------------------

local gallery = workspace:FindFirstChild("WildboundBeastGallery")
if not gallery then
	gallery = Instance.new("Folder")
	gallery.Name = "WildboundBeastGallery"
	gallery.Parent = workspace
end
for _, child in ipairs(gallery:GetChildren()) do
	child:Destroy()
end

local report = {}
for i, entry in ipairs(ENTRIES) do
	local exhibit = Instance.new("Model")
	exhibit.Name = "Exhibit_" .. entry.key
	exhibit:SetAttribute("Status", STATUS[entry.status].text)
	local pedestal = part(exhibit, "Pedestal", Vector3.new(PEDESTAL_TOP, 15, 15),
		CFrame.new(ROW_X, PEDESTAL_TOP / 2, entry.z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(52, 54, 62),
		Enum.Material.Slate)
	pedestal.Shape = Enum.PartType.Cylinder
	sign(exhibit, entry, entry.z)
	local model, kind = creature(entry)
	model.Name = entry.key
	model:SetAttribute("GallerySource", kind)
	model.Parent = exhibit
	model:PivotTo(CFrame.new(ROW_X, 0, entry.z) * CFrame.Angles(0, math.rad(entry.yaw or 0), 0))
	-- Recentre on the pedestal and stand on it.
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(ROW_X - box.Position.X, PEDESTAL_TOP - (box.Position.Y - size.Y / 2),
		entry.z - box.Position.Z))
	exhibit.PrimaryPart = pedestal
	exhibit.Parent = gallery
	table.insert(report, string.format("%s z=%d %s %s", entry.key, entry.z, kind, STATUS[entry.status].text))
	if i % 3 == 0 then task.wait() end
end

return table.concat(report, "\n")
