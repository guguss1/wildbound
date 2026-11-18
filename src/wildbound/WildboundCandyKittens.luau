-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D12, K-D13; owner request 2026-11-17: "es como el mundo de
-- gatito: un parque verde lindo con las criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas
-- de gatitos como que es su village, otra canción que tenga que ver más con gatitos, también tiene que haber huevos para
-- robar"). The four kitten guardians of the park, built from primitive Parts only (Blocks, Balls, Cylinders, Wedges and
-- Sphere SpecialMeshes; nothing uploaded), after the pack's sheets 21-24: Gatito Lanudo (a mint kitten on a pink yarn
-- ball), Gatito Guerrero (a ginger kitten with a red spear and a shield), Gatita Bouquet (white and grey, a pink bow and
-- three tulips) and Gatito Actually (orange, black glasses, one finger raised). Scaled up from the sheets' 2.4-4 studs to
-- 5.5-7 so they read as guardians beside a 5-stud player.
-- Shared and pure apart from build() (and the require of ReplicatedStorage.WildboundGatitoArea for PARK, PGM-D4):
-- ReplicatedStorage. WildboundCandyKittenService parks build()'s models in
-- ReplicatedStorage.WildboundBeasts.Models; WildboundCandyKittenAnimClient poses the live clones with pose(); the
-- WildboundCandyKittenAmbienceClient switches the kitten music with inPark().
-- Conventions: every offset is in RootPart space (the RootPart is the ground pivot, front toward -Z, so the kitten's
-- right is +X); an offset is { x, y, z, rx, ry, rz } with the angles in degrees, read as
-- CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz) (Kittens.rest). A Cylinder's axis is its X; a Wedge rises toward its
-- local +Z. Joints: Body, Head, EarL, EarR, Tail, PawL, PawR, Prop (the held prop or the raised finger).
local Kittens = {}

Kittens.NAMES = table.freeze({ "GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" })
Kittens.MAX_PARTS = 25
Kittens.CULL_STUDS = 200
-- K-D13: the music switch's rectangle (the park floor) and its leave margin.
-- PG-D5 ("the border is the cloud"): it turns on ENTER_MARGIN before the park and off LEAVE_MARGIN past it (was 0 and 8).
-- PGM-D4 (docs/design/wildbound-pueblo-gatito-move-plan.md; owner request 2026-11-18, "Sí, movelo"): the park moved to
-- the big4 south arm, so the rectangle is the park frame's floor square, WildboundGatitoArea.rect(): x 22..542, z
-- 340..860 (was the second space, x 948..1468, z -263..257). The margins stay 16 and 24: coming down the road from the
-- hub the music starts at z 324, by the road's end (324.5), and stops past z 316.
local Area = require(game:GetService("ReplicatedStorage"):WaitForChild("WildboundGatitoArea"))
Kittens.PARK = Area.rect()
Kittens.ENTER_MARGIN = 16
Kittens.LEAVE_MARGIN = 24
Kittens.GUI_ATTRIBUTE = "GatitoAmbience"
Kittens.JOINTS = table.freeze({ "Body", "Head", "EarL", "EarR", "Tail", "PawL", "PawR", "Prop" })
-- K-D12 heights (Guerrero's spear tip stands higher, at most 8.5).
Kittens.HEIGHT = table.freeze({ GatitoLanudo = 6, GatitoGuerrero = 7, GatitaBouquet = 5.5, GatitoActually = 6 })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function frame(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function offsetOf(cf)
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	return table.freeze({ cf.X, cf.Y, cf.Z, math.deg(rx), math.deg(ry), math.deg(rz) })
end

local function rgb(r, g, b)
	return table.freeze({ r, g, b })
end

-- One recipe under construction: add(name, shape, mesh, size, frame, colour, joint, material?).
local function recipe()
	local list = {}
	local self = {}
	function self.add(name, shape, mesh, size, cf, color, joint, material, transparency)
		table.insert(list, table.freeze({
			name = name, shape = shape, mesh = mesh, size = table.freeze(size), offset = offsetOf(cf), color = color,
			material = material or "SmoothPlastic", joint = joint, transparency = transparency,
		}))
	end
	-- an oval: a Block with a Sphere SpecialMesh (the mesh follows the part's size)
	function self.oval(name, sx, sy, sz, cf, color, joint, material)
		self.add(name, "Block", "Sphere", { sx, sy, sz }, cf, color, joint, material)
	end
	function self.ball(name, d, cf, color, joint, material)
		self.add(name, "Ball", nil, { d, d, d }, cf, color, joint, material)
	end
	function self.rod(name, length, d, cf, color, joint, material)
		self.add(name, "Cylinder", nil, { length, d, d }, cf, color, joint, material)
	end
	function self.block(name, sx, sy, sz, cf, color, joint)
		self.add(name, "Block", nil, { sx, sy, sz }, cf, color, joint)
	end
	-- Two triangle ears seen from the front: the wedge's tall side outward, a pink inner ear on its front face.
	function self.ears(x, y, z, thick, height, width, color, inner)
		for _, side in ipairs({ 1, -1 }) do
			local suffix = side == 1 and "R" or "L"
			local ear = frame(side * x, y, z, 0, side * 90, 0)
			self.add("Ear" .. suffix, "Wedge", nil, { thick, height, width }, ear, color, "Ear" .. suffix)
			if inner then
				local h, w = height * 0.62, width * 0.56
				-- the ear's front is its local +X on the right and its local -X on the left
				local at = ear * CFrame.new(side * (thick / 2 + 0.04), -(height - h) / 2 + 0.1, (width - w) / 2 - 0.1)
				self.add("InnerEar" .. suffix, "Wedge", nil, { 0.1, h, w }, at, inner, "Ear" .. suffix)
			end
		end
	end
	function self.done()
		return table.freeze(list)
	end
	-- every kitten starts with its RootPart: the invisible ground pivot, facing -Z
	self.add("RootPart", "Block", nil, { 1, 1, 1 }, CFrame.new(), rgb(255, 255, 255), "Body", nil, 1)
	return self
end

local RECIPES, PIVOTS = {}, {}

-- Sheet 21, Gatito Lanudo: a mint kitten sitting on (wrapped in) a pink yarn ball with yellow, violet and blue strands;
-- two mint front paws peek under the ball and the tail curls out on its right. "Rebota como ovillo" (K-D4).
do
	local YARN, BAND_Y, BAND_V, BAND_B = rgb(235, 70, 140), rgb(250, 200, 60), rgb(170, 90, 220), rgb(90, 150, 240)
	local MINT, MINT_DK, EYE, WHITE, PINK = rgb(110, 220, 200), rgb(70, 185, 170), rgb(30, 25, 35), rgb(252, 252, 252),
		rgb(255, 150, 185)
	local r = recipe()
	r.ball("Yarn", 4, frame(0, 2, 0.1), YARN, "Body", "Fabric")
	-- each strand is a thin disc through the ball's centre, a hair wider than it: a band round the ball
	r.rod("BandYellow", 0.35, 4.1, frame(0, 2, 0.1, 0, 20, 55), BAND_Y, "Body", "Fabric")
	r.rod("BandViolet", 0.35, 4.1, frame(0, 2, 0.1, 0, -25, -40), BAND_V, "Body", "Fabric")
	r.rod("BandBlue", 0.35, 4.1, frame(0, 2, 0.1, 15, 0, 100), BAND_B, "Body", "Fabric")
	r.oval("Head", 3.6, 2.8, 3.1, frame(0, 4.45, -0.1), MINT, "Head")
	r.oval("Stripe", 1.2, 0.3, 0.8, frame(0, 5.74, -0.55, -15, 0, 0), MINT_DK, "Head")
	r.ball("EyeR", 0.6, frame(0.75, 4.42, -1.39), EYE, "Head")
	r.ball("EyeL", 0.6, frame(-0.75, 4.42, -1.39), EYE, "Head")
	r.ball("ShineR", 0.2, frame(0.85, 4.55, -1.62), WHITE, "Head")
	r.ball("ShineL", 0.2, frame(-0.65, 4.55, -1.62), WHITE, "Head")
	r.oval("Muzzle", 1.3, 0.75, 0.6, frame(0, 3.95, -1.45), WHITE, "Head")
	r.oval("Mouth", 0.45, 0.12, 0.12, frame(0, 3.72, -1.68), EYE, "Head")
	r.ears(1.05, 5.62, -0.1, 0.45, 1.25, 1.1, MINT, PINK)
	r.oval("PawR", 0.95, 0.7, 1.1, frame(0.8, 0.35, -1.3), MINT, "PawR")
	r.oval("PawL", 0.95, 0.7, 1.1, frame(-0.8, 0.35, -1.3), MINT, "PawL")
	r.oval("TailA", 2, 0.75, 0.75, frame(1.45, 0.5, 1.45, 0, -35, 0), MINT, "Tail")
	r.oval("TailB", 0.75, 1.5, 0.75, frame(2.3, 1.05, 2.05, 15, 0, -20), MINT, "Tail")
	RECIPES.GatitoLanudo = r.done()
	-- the yarn rolls about its own centre (K-D12 telegraph)
	PIVOTS.GatitoLanudo = table.freeze({
		Body = table.freeze({ 0, 2, 0.1 }), Head = table.freeze({ 0, 3.6, -0.1 }),
		EarL = table.freeze({ -1.05, 5.1, -0.1 }), EarR = table.freeze({ 1.05, 5.1, -0.1 }),
		Tail = table.freeze({ 0.9, 0.5, 1.1 }), PawL = table.freeze({ -0.8, 0.6, -1 }), PawR = table.freeze({ 0.8, 0.6, -1 }),
	})
end

-- Sheet 22, Gatito Guerrero: a ginger tabby standing up, cream belly, muzzle and feet, a red spear 9 long in its right
-- paw (tilted 18 degrees, tip at 8.5 at most) and a round shield with a cross on its left. "Shield charge" (K-D4).
do
	local FUR, CREAM, STRIPE, NOSE, EYE = rgb(210, 150, 90), rgb(245, 225, 200), rgb(170, 110, 60), rgb(235, 140, 150),
		rgb(35, 25, 20)
	local PINK, RED, SHIELD, RIB = rgb(240, 160, 170), rgb(220, 40, 40), rgb(225, 175, 140), rgb(205, 150, 115)
	local r = recipe()
	r.oval("LegR", 0.9, 1.5, 0.95, frame(0.55, 1, 0.1), FUR, "Body")
	r.oval("LegL", 0.9, 1.5, 0.95, frame(-0.55, 1, 0.1), FUR, "Body")
	r.oval("FootR", 1, 0.5, 1.3, frame(0.55, 0.25, -0.25), CREAM, "Body")
	r.oval("FootL", 1, 0.5, 1.3, frame(-0.55, 0.25, -0.25), CREAM, "Body")
	r.oval("Torso", 2.4, 2.8, 1.9, frame(0, 2.85, 0.05), FUR, "Body")
	r.oval("Belly", 1.5, 2, 0.6, frame(0, 2.75, -0.72), CREAM, "Body")
	r.oval("Head", 3, 2.6, 2.6, frame(0, 5.2, -0.15), FUR, "Head")
	r.ears(1, 6.35, -0.1, 0.4, 1.2, 1.05, FUR, PINK)
	r.ball("EyeR", 0.75, frame(0.6, 5.25, -1.24), EYE, "Head")
	r.ball("EyeL", 0.75, frame(-0.6, 5.25, -1.24), EYE, "Head")
	r.oval("Muzzle", 1.2, 0.75, 0.55, frame(0, 4.72, -1.26), CREAM, "Head")
	r.oval("Nose", 0.36, 0.24, 0.2, frame(0, 4.98, -1.47), NOSE, "Head")
	-- the right arm runs from the shoulder (1.15, 3.85, -0.15) down to the paw on the spear (1.4, 2.5, -0.85)
	r.oval("ArmR", 0.8, 1.75, 0.8, frame(1.275, 3.175, -0.5, 27.4, 0, 9.3), FUR, "PawR")
	r.oval("ArmL", 0.8, 1.6, 0.8, frame(-1.3, 3.275, -0.35, 23.5, 0, -13.5), FUR, "PawL")
	r.rod("Spear", 9, 0.35, frame(1.936, 4.15, -0.95, 0, 0, 72), RED, "Prop")
	-- the shield faces front-left; its cross stands just proud of its face
	local shield = frame(-1.6, 2.8, -1.05, 0, 25, 0)
	r.oval("Shield", 2.4, 3, 0.5, shield, SHIELD, "PawL")
	r.block("RibV", 0.28, 2.6, 0.18, shield * CFrame.new(0, 0, -0.26), RIB, "PawL")
	r.block("RibH", 2.2, 0.28, 0.18, shield * CFrame.new(0, 0.15, -0.26), RIB, "PawL")
	r.oval("TailA", 0.6, 0.6, 1.7, frame(0.55, 1.7, 1.5, 0, 25, 0), FUR, "Tail")
	r.oval("TailB", 0.6, 1.5, 0.6, frame(1.05, 2.35, 2.35, -15, 0, -15), STRIPE, "Tail")
	RECIPES.GatitoGuerrero = r.done()
	PIVOTS.GatitoGuerrero = table.freeze({
		Body = table.freeze({ 0, 1, 0.1 }), Head = table.freeze({ 0, 4.2, -0.1 }),
		EarL = table.freeze({ -1, 5.85, -0.1 }), EarR = table.freeze({ 1, 5.85, -0.1 }), Tail = table.freeze({ 0.2, 1.7, 0.75 }),
		PawL = table.freeze({ -1.15, 3.85, -0.1 }), PawR = table.freeze({ 1.15, 3.85, -0.15 }),
		Prop = table.freeze({ 1.4, 2.5, -0.85 }), -- the paw on the spear
	})
end

-- Sheet 23, Gatita Bouquet: a white kitten with a grey head (white muzzle and cheeks), a pink bow by her left ear, her
-- tongue out, three pink tulips in kraft paper held up in her right paw, and a pink star on her left hip. "Petal throw"
-- (K-D4): she offers the flowers.
do
	local WHITE, GREY, LIGHT, NOSE, TONGUE, EYE = rgb(250, 248, 245), rgb(130, 125, 130), rgb(222, 220, 224),
		rgb(240, 160, 170), rgb(240, 110, 140), rgb(30, 25, 30)
	local BOW, TULIP, KRAFT, STAR, PINK = rgb(255, 170, 200), rgb(245, 130, 170), rgb(205, 150, 105), rgb(250, 170, 205),
		rgb(245, 170, 190)
	local r = recipe()
	r.oval("Body", 2.5, 2.7, 2.1, frame(0, 1.75, 0.05), WHITE, "Body")
	r.oval("FootR", 0.95, 0.6, 1.15, frame(0.6, 0.3, -0.35), WHITE, "Body")
	r.oval("FootL", 0.95, 0.6, 1.15, frame(-0.6, 0.3, -0.35), WHITE, "Body")
	r.oval("Head", 3.2, 2.7, 2.7, frame(0, 3.95, -0.1), GREY, "Head")
	r.oval("Mask", 2.4, 1.5, 1.2, frame(0, 3.3, -0.95), WHITE, "Head")
	r.ears(1.05, 5.15, 0, 0.38, 1.05, 1, GREY, PINK)
	r.ball("EyeR", 0.85, frame(0.66, 4.05, -1.2), EYE, "Head")
	r.ball("EyeL", 0.85, frame(-0.66, 4.05, -1.2), EYE, "Head")
	r.oval("Nose", 0.38, 0.26, 0.22, frame(0, 3.72, -1.48), NOSE, "Head")
	r.oval("Tongue", 0.5, 0.28, 0.55, frame(0.12, 3.05, -1.5, 25, 0, 0), TONGUE, "Head")
	r.ball("BowKnot", 0.45, frame(-0.95, 5, -0.55), BOW, "Head")
	r.oval("BowLoopL", 0.95, 0.75, 0.4, frame(-1.45, 5.2, -0.5, 0, 0, 25), BOW, "Head")
	r.oval("BowLoopR", 0.95, 0.75, 0.4, frame(-0.45, 5.25, -0.6, 0, 0, -25), BOW, "Head")
	-- the right arm reaches forward from the shoulder (0.95, 2.4, -0.4) to the paw on the wrap (1.15, 2.55, -1.2)
	r.oval("ArmR", 0.72, 1.2, 0.72, frame(1.05, 2.475, -0.8, -79.4, 0, -13.8), WHITE, "PawR")
	r.oval("Wrap", 0.95, 1.5, 0.85, frame(1.2, 2.9, -1.35, 0, 0, -12), KRAFT, "Prop")
	r.oval("TulipA", 0.6, 0.8, 0.6, frame(1, 3.9, -1.45, 0, 0, 15), TULIP, "Prop")
	r.oval("TulipB", 0.6, 0.8, 0.6, frame(1.4, 4.15, -1.4, 0, 0, -5), TULIP, "Prop")
	r.oval("TulipC", 0.6, 0.8, 0.6, frame(1.75, 3.85, -1.3, 0, 0, -25), TULIP, "Prop")
	-- the star: a small diamond turned toward her front-left
	r.block("Star", 0.75, 0.75, 0.25, frame(-1.2, 1.65, -0.45, 0, 40, 45), STAR, "Body")
	r.oval("TailA", 0.55, 0.55, 1.5, frame(-0.55, 1.1, 1.35, 0, -25, 0), GREY, "Tail")
	r.oval("TailB", 0.55, 1.3, 0.55, frame(-1, 1.65, 2.05, -15, 0, 15), LIGHT, "Tail")
	RECIPES.GatitaBouquet = r.done()
	PIVOTS.GatitaBouquet = table.freeze({
		Body = table.freeze({ 0, 0.8, 0.05 }), Head = table.freeze({ 0, 2.9, -0.1 }),
		EarL = table.freeze({ -1.05, 4.75, 0 }), EarR = table.freeze({ 1.05, 4.75, 0 }), Tail = table.freeze({ -0.25, 1.1, 0.7 }),
		PawL = table.freeze({ -0.95, 2.4, -0.4 }), PawR = table.freeze({ 0.95, 2.4, -0.4 }),
		Prop = table.freeze({ 1.15, 2.55, -1.2 }), -- the paw on the wrap
	})
end

-- Sheet 24, Gatito Actually: an orange tabby with a cream belly, muzzle and feet, two head stripes, round black glasses
-- (a black rim, a pale lens and the brown eye in front of it, a bridge), a blue sweat drop, and his right paw held out
-- with one cream finger up. "¡De hecho!" (K-D4): the finger goes up (the finger is his Prop, so it stays upright while
-- the arm lifts).
do
	local ORANGE, CREAM, STRIPE, NOSE, EYE = rgb(232, 150, 70), rgb(247, 226, 190), rgb(200, 110, 40), rgb(240, 160, 170),
		rgb(90, 55, 40)
	local BLACK, LENS, DROP = rgb(30, 26, 28), rgb(226, 238, 246), rgb(150, 215, 240)
	local r = recipe()
	r.oval("FootR", 1, 0.55, 1.2, frame(0.55, 0.28, -0.2), CREAM, "Body")
	r.oval("FootL", 1, 0.55, 1.2, frame(-0.55, 0.28, -0.2), CREAM, "Body")
	r.oval("Body", 2.5, 2.9, 2, frame(0, 1.85, 0.05), ORANGE, "Body")
	r.oval("Belly", 1.6, 2.1, 0.6, frame(0, 1.85, -0.75), CREAM, "Body")
	r.oval("Head", 3.4, 3, 3, frame(0, 4.45, -0.1), ORANGE, "Head")
	r.ears(1.1, 5.75, 0.05, 0.4, 1.1, 1.15, ORANGE, nil)
	r.oval("StripeR", 0.3, 0.25, 0.9, frame(0.35, 5.87, -0.45, -20, 0, 0), STRIPE, "Head")
	r.oval("StripeL", 0.3, 0.25, 0.9, frame(-0.35, 5.87, -0.45, -20, 0, 0), STRIPE, "Head")
	r.oval("Muzzle", 1.3, 0.8, 0.55, frame(0, 3.85, -1.38), CREAM, "Head")
	r.oval("Nose", 0.35, 0.25, 0.2, frame(0, 4.15, -1.58), NOSE, "Head")
	r.ball("EyeR", 1, frame(0.8, 4.6, -1.32), EYE, "Head")
	r.ball("EyeL", 1, frame(-0.8, 4.6, -1.32), EYE, "Head")
	-- the glasses: discs on the Z axis behind the front of each eye, so each eye shows inside a black ring
	r.rod("RimR", 0.1, 1.5, frame(0.8, 4.6, -1.47, 0, 90, 0), BLACK, "Head")
	r.rod("RimL", 0.1, 1.5, frame(-0.8, 4.6, -1.47, 0, 90, 0), BLACK, "Head")
	r.rod("LensR", 0.06, 1.2, frame(0.8, 4.6, -1.555, 0, 90, 0), LENS, "Head")
	r.rod("LensL", 0.06, 1.2, frame(-0.8, 4.6, -1.555, 0, 90, 0), LENS, "Head")
	r.block("Bridge", 0.36, 0.14, 0.14, frame(0, 4.68, -1.5), BLACK, "Head")
	r.oval("Sweat", 0.32, 0.5, 0.25, frame(-1.4, 5.25, -0.5, 0, 0, -20), DROP, "Head")
	-- the right arm reaches forward from the shoulder (0.85, 2.85, -0.3) to the paw (1.44, 3.17, -1.59)
	r.oval("ArmR", 0.75, 1.55, 0.75, frame(1.125, 3, -0.9, -75.9, 0, -23.95), ORANGE, "PawR")
	r.oval("Finger", 0.32, 0.9, 0.32, frame(1.45, 3.6, -1.6), CREAM, "Prop")
	r.oval("ArmL", 0.75, 1.4, 0.75, frame(-1.05, 2.3, -0.325, 12.8, 0, -19.5), ORANGE, "PawL")
	r.oval("TailA", 0.6, 0.6, 1.6, frame(0.6, 1.25, 1.4, 0, 25, 0), ORANGE, "Tail")
	r.oval("TailB", 0.6, 1.4, 0.6, frame(1.05, 1.9, 2.05, -15, 0, -15), STRIPE, "Tail")
	RECIPES.GatitoActually = r.done()
	PIVOTS.GatitoActually = table.freeze({
		Body = table.freeze({ 0, 0.9, 0.05 }), Head = table.freeze({ 0, 3.2, -0.1 }),
		EarL = table.freeze({ -1.1, 5.3, 0.05 }), EarR = table.freeze({ 1.1, 5.3, 0.05 }), Tail = table.freeze({ 0.26, 1.25, 0.7 }),
		PawL = table.freeze({ -0.85, 2.85, -0.2 }), PawR = table.freeze({ 0.85, 2.85, -0.3 }),
		Prop = table.freeze({ 1.44, 3.17, -1.59 }), -- the finger's base, on the paw
	})
end

table.freeze(RECIPES)
table.freeze(PIVOTS)

-- parts(name) -> the kitten's parts, RootPart first (nil for an unknown name).
function Kittens.parts(name)
	return RECIPES[name]
end

-- pivots(name) -> { [joint] = { x, y, z } } in RootPart space ({} for an unknown name).
function Kittens.pivots(name)
	return PIVOTS[name] or table.freeze({})
end

-- rest(entry) -> the part's CFrame in RootPart space.
function Kittens.rest(entry)
	local o = entry.offset
	return frame(o[1], o[2], o[3], o[4], o[5], o[6])
end

-- build(name) -> an unparented Model named name, PrimaryPart RootPart at the origin facing -Z; every part anchored,
-- massless and out of collisions, queries and touches, with its Joint attribute. nil for an unknown name.
function Kittens.build(name)
	local list = RECIPES[name]
	if not list then return nil end
	local model = Instance.new("Model")
	model.Name = name
	local root
	for _, entry in ipairs(list) do
		local part
		if entry.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			part.Shape = Enum.PartType[entry.shape]
		end
		part.Name = entry.name
		part.Size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
		part.Color = Color3.fromRGB(entry.color[1], entry.color[2], entry.color[3])
		part.Material = Enum.Material[entry.material]
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Anchored, part.Massless = true, true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.Transparency = entry.transparency or 0
		part.CastShadow = entry.transparency == nil
		part.CFrame = Kittens.rest(entry)
		part:SetAttribute("Joint", entry.joint)
		if entry.mesh == "Sphere" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.Parent = model
		if entry.name == "RootPart" then root = part end
	end
	model.PrimaryPart = root
	return model
end

-- inPark(was, x, z) -> whether the kitten music is on (K-D13): it starts within ENTER_MARGIN studs of the park's
-- rectangle and, once on, stops only more than LEAVE_MARGIN studs outside it. A bad point is off. PG-D5
-- (docs/design/wildbound-pueblo-gatito-biome-plan.md; owner request 2026-11-18: "hacelo bioma aparte"): the border is
-- the cloud, so the flag starts inside the cloud band (x 932..948) and the Caramelo music stops where the HUD already
-- says Pueblo Gatito (was: only inside the rectangle). PGM-D4 ("Sí, movelo"): the rectangle is the moved park floor,
-- so the flag now starts on the apron round it (the HUD's Pueblo Gatito square is the whole arm, PGM-D3).
function Kittens.inPark(was, x, z)
	if not (finite(x) and finite(z)) then return false end
	local P = Kittens.PARK
	local dx = math.max(P.minX - x, 0, x - P.maxX)
	local dz = math.max(P.minZ - z, 0, z - P.maxZ)
	local d = math.sqrt(dx * dx + dz * dz)
	if was == true then return d <= Kittens.LEAVE_MARGIN end
	return d <= Kittens.ENTER_MARGIN
end

-- K-D12 poses. pose(name, phase, t, reduced) -> { [joint] = CFrame } in RootPart space about each joint's pivot (the
-- animator draws part = root * pivot * pose * pivot:Inverse() * rest). t: seconds since the phase began. A missing joint
-- is the identity and the RootPart is never posed. Deterministic: the same arguments give the same poses.
--   Calm, Patrol and any other phase: an idle bob of at most 0.15, a tail wag of at most 20 degrees, ear flicks (Patrol
--     also paddles the paws of a kitten whose paws hold nothing);
--   Notice: the head tilts 12 degrees;  Chase and Return: hops of at most 0.6 at 3 Hz;
--   Telegraph, the signature move: Lanudo's yarn rolls 30 degrees as it bounces, Guerrero raises his spear (it lifts
--     with his paw and levels 35 degrees toward the target, the shield comes forward), Bouquet holds her paw and flowers
--     out 0.6, Actually raises his paw 40 degrees and wags his finger;
--   Release: a forward lunge of 0.4;  Recover: a 0.2 crouch.
-- Reduced (Efectos suaves): every amplitude x 0.4.
local TAU = 2 * math.pi
local REDUCED = 0.4

local function ease(t, seconds)
	return math.clamp(t / seconds, 0, 1)
end

-- a quick ear flick: 0..1..0 over 0.2 s, once every `period` seconds
local function flick(t, period, offset)
	local p = (t + offset) % period
	if p < 0.2 then return math.sin(math.pi * p / 0.2) end
	return 0
end

local function signature(name, t, rot, move)
	local e = ease(t, 0.25)
	if name == "GatitoLanudo" then
		rot.Body = { math.rad(30) * math.sin(TAU * 1.4 * t), 0, 0 }
		return 0.3 * math.abs(math.sin(TAU * 1.4 * t))
	elseif name == "GatitoGuerrero" then
		-- the paw lifts 30 degrees about the shoulder; the spear follows the paw (0, 0.53, -0.58) and levels 35 degrees
		rot.PawR = { math.rad(30) * e, 0, 0 }
		rot.Prop = { -math.rad(35) * e, 0, 0 }
		move.Prop = { 0, 0.53 * e, -0.58 * e }
		move.PawL = { 0, 0, -0.3 * e }
	elseif name == "GatitaBouquet" then
		move.PawR = { 0, 0, -0.6 * e }
		move.Prop = { 0, 0, -0.6 * e }
		rot.Head = { 0, 0, math.rad(8) * e }
	elseif name == "GatitoActually" then
		-- the arm lifts 40 degrees about the shoulder; the finger rides up with the paw (0, 0.75, 0.5), still upright
		rot.PawR = { math.rad(40) * e, 0, 0 }
		move.Prop = { 0, 0.75 * e, 0.5 * e }
		rot.Prop = { 0, 0, math.rad(10) * e * math.sin(TAU * 2.5 * t) }
	end
	return 0
end

function Kittens.pose(name, phase, t, reduced)
	local out = {}
	local pivots = PIVOTS[name]
	if not pivots then return out end
	if not finite(t) or t < 0 then t = 0 end
	local k = reduced == true and REDUCED or 1
	local lift, forward = 0, 0
	local rot, move = {}, {}
	local holds = pivots.Prop ~= nil
	local function paddle(amplitude, hz)
		if holds then return end
		local a = amplitude * math.sin(TAU * hz * t)
		rot.PawL, rot.PawR = { a, 0, 0 }, { -a, 0, 0 }
	end
	local function idle()
		lift = 0.075 * (1 - math.cos(TAU * 0.6 * t))
		rot.Tail = { 0, math.rad(20) * math.sin(TAU * 1.1 * t), 0 }
		rot.EarL = { 0, 0, math.rad(15) * flick(t, 3.3, 0) }
		rot.EarR = { 0, 0, -math.rad(15) * flick(t, 3.3, 1.6) }
	end
	if phase == "Chase" or phase == "Return" then
		lift = 0.6 * math.abs(math.sin(math.pi * 3 * t))
		rot.Tail = { 0, math.rad(20) * math.sin(TAU * 3 * t), 0 }
		paddle(math.rad(20), 3)
	elseif phase == "Notice" then
		idle()
		rot.Head = { 0, 0, math.rad(12) * ease(t, 0.2) }
	elseif phase == "Telegraph" then
		lift = signature(name, t, rot, move)
	elseif phase == "Release" then
		forward = -0.4 * ease(t, 0.08)
	elseif phase == "Recover" then
		lift = -0.2 * ease(t, 0.1)
	else
		idle()
		if phase == "Patrol" then paddle(math.rad(12), 2) end
	end
	for joint in pairs(pivots) do
		local r, m = rot[joint], move[joint]
		local pose = CFrame.new((m and m[1] or 0) * k, (lift + (m and m[2] or 0)) * k, (forward + (m and m[3] or 0)) * k)
		if r then pose *= CFrame.Angles(r[1] * k, r[2] * k, r[3] * k) end
		out[joint] = pose
	end
	return out
end

return Kittens
