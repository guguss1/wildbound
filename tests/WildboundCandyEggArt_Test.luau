-- Invoke with require(freshTestClone)(require(freshCandyEggArtClone), require(freshSpeciesClone),
-- require(freshEggLoopClone), { server = WildboundServer.Source, bob = WildboundCandyEggBob.Source }).
-- CG1 (odd/tasks/wildbound-caramelo.md): each Caramelo egg has its own candy look built from primitives, the same in the
-- nest, on the ground, in the carried backpack and on the cradle spot; the rarity colour stays readable and a
-- Legendaria egg shimmers gold. A forest egg is never touched. Every model here stays detached.
return function(CandyEggArt, Species, EggLoop, sources)
	local CollectionService = game:GetService("CollectionService")
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			("%s: expected %.3f +- %.3f, got %s"):format(label or "value", expected, tolerance, tostring(actual)))
	end
	local CANDY = { "Gomibu", "Flanfuria", "Tortidragon" }
	local BASE = CFrame.new(10, 5, -3)
	local function build(species, rarity, context, height)
		local model = Instance.new("Model")
		local parts = CandyEggArt.build(model, BASE, height or 2.2, species, rarity, context)
		return model, parts
	end
	local function named(holder, name)
		local list = {}
		for _, item in ipairs(holder:GetChildren()) do
			if item.Name == name and item:IsA("BasePart") then table.insert(list, item) end
		end
		return list
	end
	local function bounds(parts)
		local low, high = math.huge, -math.huge
		for _, item in ipairs(parts) do
			-- A vertical cylinder's height is its Size.X (its axis is turned upright).
			local half = item.Shape == Enum.PartType.Cylinder and item.Size.X / 2 or item.Size.Y / 2
			low = math.min(low, item.Position.Y - half)
			high = math.max(high, item.Position.Y + half)
		end
		return low, high
	end

	case("CG-1: only the three Caramelo species wear a candy egg", function()
		for _, name in ipairs(CANDY) do equal(CandyEggArt.uses(name), true, name) end
		for _, name in ipairs({ "Lumipol", "LumipolVioleta", "Cortezon", "Tizoncillo", "DonGlaseon" }) do
			equal(CandyEggArt.uses(name), false, name)
		end
		equal(CandyEggArt.uses(nil), false, "nil")
		equal(CandyEggArt.uses(42), false, "a number")
	end)

	case("CG-2: Gomibu is a translucent gummy egg that bobs only in its nest", function()
		local model, parts = build("Gomibu", "Comun", "nest")
		assert(parts and #parts >= 4, "candy parts returned")
		local holder = model:FindFirstChild(CandyEggArt.MODEL)
		assert(holder and holder:IsA("Model"), "CandyEggArt sub-model")
		equal(holder:GetAttribute(CandyEggArt.ATTRIBUTE), "Gomibu")
		equal(model:GetAttribute(CandyEggArt.ATTRIBUTE), "Gomibu", "the egg model says it is a candy egg")
		local shell = named(holder, "GummyShell")[1]
		assert(shell, "GummyShell")
		assert(shell.Transparency >= 0.2 and shell.Transparency <= 0.6, "translucent shell")
		equal(shell.Material, Enum.Material.Glass, "glass shell")
		local mesh = shell:FindFirstChildOfClass("SpecialMesh")
		equal(mesh and mesh.MeshType, Enum.MeshType.Sphere, "egg-shaped (sphere mesh)")
		assert(shell.Size.Y > shell.Size.X * 1.2, "taller than wide")
		local core = named(holder, "GummyCore")[1]
		assert(core and core.Material == Enum.Material.Neon and core.Size.Y < shell.Size.Y, "glowing core inside")
		equal(CollectionService:HasTag(holder, CandyEggArt.BOB_TAG), true, "nest egg bobs")
		for _, context in ipairs({ "pack", "cradle", "ground" }) do
			local other = build("Gomibu", "Comun", context)
			equal(CollectionService:HasTag(other:FindFirstChild(CandyEggArt.MODEL), CandyEggArt.BOB_TAG), false, context)
			other:Destroy()
		end
		model:Destroy()
	end)

	case("CG-3: Flanfuria is a cream flan egg under a caramel cap that drips down", function()
		local model = build("Flanfuria", "Epica", "nest")
		local holder = model:FindFirstChild(CandyEggArt.MODEL)
		local body, cap = named(holder, "FlanBody")[1], named(holder, "CaramelCap")[1]
		assert(body and cap, "FlanBody and CaramelCap")
		assert(cap.Position.Y > body.Position.Y + body.Size.Y * 0.2, "the cap sits on top")
		local drips = named(holder, "CaramelDrip")
		assert(#drips >= 3, "at least three drips, got " .. #drips)
		for _, drip in ipairs(drips) do
			assert(drip.Position.Y < cap.Position.Y, "a drip runs down from the cap")
			equal(drip.Color, cap.Color, "drips are caramel")
			-- Play (CG1): round drips read as eyes; a drip is a slender streak that starts under the cap's rim.
			assert(drip.Size.X <= body.Size.X * 0.12 and drip.Size.Y >= drip.Size.X * 2.5, "a slender drip")
			assert(drip.Position.Y + drip.Size.Y / 2 >= cap.Position.Y - cap.Size.Y / 2, "a drip starts at the cap's rim")
		end
		assert(body.Color.R > cap.Color.R and body.Color.G > cap.Color.G * 1.5, "cream body is lighter than the caramel")
		equal(CollectionService:HasTag(holder, CandyEggArt.BOB_TAG), false, "a flan does not bob")
		model:Destroy()
	end)

	case("CG-4: Tortidragon is a cake egg with a cream band and a strawberry on top", function()
		local model, parts = build("Tortidragon", "Rara", "nest")
		local holder = model:FindFirstChild(CandyEggArt.MODEL)
		local sponge = named(holder, "CakeSponge")[1]
		assert(sponge, "CakeSponge")
		equal(sponge.Material, Enum.Material.Sand, "a crumbly sponge")
		local bands = named(holder, "CreamBand")
		assert(#bands >= 1, "a cream band")
		assert(bands[1].Size.Y >= sponge.Size.X, "the band wraps the sponge")
		local berry = named(holder, "Strawberry")[1]
		assert(berry and berry.Color.R > 0.7 and berry.Color.G < 0.3, "a red strawberry")
		near(berry.Position.X, sponge.Position.X, 0.01, "strawberry centred x")
		near(berry.Position.Z, sponge.Position.Z, 0.01, "strawberry centred z")
		for _, item in ipairs(parts) do
			if item ~= berry and item.Name ~= "StrawberryLeaf" then
				assert(berry.Position.Y > item.Position.Y, "the strawberry is on top of " .. item.Name)
			end
		end
		model:Destroy()
	end)

	case("CG-5: each species builds its own distinct egg", function()
		local seen = {}
		for _, name in ipairs(CANDY) do
			local model = build(name, "Comun", "nest")
			local holder = model:FindFirstChild(CandyEggArt.MODEL)
			for _, partName in ipairs(CandyEggArt.PARTS[name]) do
				assert(#named(holder, partName) >= 1, name .. " has " .. partName)
				assert(seen[partName] == nil or seen[partName] == name, partName .. " belongs to one species only")
				seen[partName] = name
			end
			model:Destroy()
		end
	end)

	case("CG-6: the rarity stays readable: a neon rim in the rarity colour (the egg loop's colours)", function()
		for rarity, rgb in pairs(EggLoop.RARITY_COLOR) do
			equal(table.concat(CandyEggArt.RIM[rarity], ","), table.concat(rgb, ","), rarity .. " equals EggLoop")
		end
		for _, name in ipairs(CANDY) do
			for _, rarity in ipairs({ "Comun", "Rara", "Epica", "Legendaria" }) do
				local model = build(name, rarity, "nest")
				local holder = model:FindFirstChild(CandyEggArt.MODEL)
				local rim = named(holder, "RarityRim")[1]
				assert(rim, name .. " " .. rarity .. " RarityRim")
				equal(rim.Material, Enum.Material.Neon)
				equal(rim.Color, CandyEggArt.rimColor(rarity), name .. " " .. rarity .. " rim colour")
				equal(holder:GetAttribute(CandyEggArt.RARITY_ATTRIBUTE), rarity)
				model:Destroy()
			end
		end
	end)

	case("CG-7: a Legendaria egg of any species shimmers gold; no other rarity does", function()
		for _, name in ipairs(CANDY) do
			local model = build(name, "Legendaria", "pack", CandyEggArt.PACK_HEIGHT)
			local holder = model:FindFirstChild(CandyEggArt.MODEL)
			equal(holder:GetAttribute(CandyEggArt.GOLDEN_ATTRIBUTE), true, name)
			local glaze = named(holder, "GoldGlaze")[1]
			assert(glaze, name .. " GoldGlaze")
			local shimmer = glaze:FindFirstChild("GoldShimmer")
			assert(shimmer and shimmer:IsA("ParticleEmitter"), name .. " GoldShimmer")
			model:Destroy()
			local plain = build(name, "Epica", "nest")
			local plainHolder = plain:FindFirstChild(CandyEggArt.MODEL)
			equal(plainHolder:GetAttribute(CandyEggArt.GOLDEN_ATTRIBUTE), false, name .. " Epica")
			equal(#named(plainHolder, "GoldGlaze"), 0, name .. " Epica has no glaze")
			plain:Destroy()
		end
	end)

	case("CG-8: the egg stands on its foot and is about the asked height; nothing collides or is queried", function()
		for _, name in ipairs(CANDY) do
			for _, height in ipairs({ CandyEggArt.HEIGHT, CandyEggArt.PACK_HEIGHT }) do
				local model, parts = build(name, "Rara", "nest", height)
				local low, high = bounds(parts)
				near(low, BASE.Y, 0.05, name .. " foot on the base")
				assert(high - BASE.Y >= height * 0.95 and high - BASE.Y <= height * 1.25, name .. " height")
				for _, item in ipairs(parts) do
					equal(item.CanCollide or item.CanQuery or item.CanTouch, false, name .. " " .. item.Name .. " inert")
					equal(item.Anchored, true, item.Name .. " anchored until welded")
					near(item.Position.X, BASE.X, height, item.Name .. " near the base")
				end
				model:Destroy()
			end
		end
	end)

	case("CG-9: a forest egg is unchanged: nothing is built, the model is untouched", function()
		for _, name in ipairs({ "Lumipol", "LumipolVioleta", "Cortezon" }) do
			local model = Instance.new("Model")
			equal(CandyEggArt.build(model, BASE, 2.2, name, "Comun", "nest"), nil, name)
			equal(#model:GetChildren(), 0, name .. " no children")
			equal(next(model:GetAttributes()), nil, name .. " no attributes")
			model:Destroy()
		end
		-- The Lumipol eggs keep their generated art (WildboundLumipolArt), the species keep their tints.
		equal(Species.look("Lumipol").tint, nil, "Lumipol egg keeps its blue")
		assert(Species.LOOKS.Gomibu.tint, "Gomibu tint kept")
	end)

	case("CG-10: in the backpack the candy parts are welded to the hidden shell, offsets kept", function()
		local pack = Instance.new("Model")
		local shell = Instance.new("Part")
		shell.Name, shell.Size, shell.CFrame, shell.Parent = "Egg", Vector3.new(0.9, 1.2, 0.9), CFrame.new(1, 2, 3), pack
		local parts = CandyEggArt.build(pack, shell.CFrame * CFrame.new(0, -0.6, 0), CandyEggArt.PACK_HEIGHT, "Flanfuria",
			"Epica", "pack")
		local joints = CandyEggArt.weldTo(parts, shell)
		equal(#joints, #parts, "one weld per part")
		for index, item in ipairs(parts) do
			local joint = joints[index]
			equal(item.Anchored, false, item.Name .. " unanchored")
			equal(item.Massless, true, item.Name .. " massless")
			equal(joint.Part0, shell); equal(joint.Part1, item)
			local back = shell.CFrame * joint.C0
			near((back.Position - item.Position).Magnitude, 0, 1e-3, item.Name .. " offset kept")
		end
		pack:Destroy()
	end)

	case("CG-11: the gummy bob is a small squash around 1", function()
		local sx, sy = CandyEggArt.bob(0)
		near(sx, 1, 1e-6); near(sy, 1, 1e-6)
		sx, sy = CandyEggArt.bob(CandyEggArt.BOB.PERIOD / 4)
		near(sy, 1 + CandyEggArt.BOB.AMOUNT, 1e-6, "tallest"); near(sx, 1 - CandyEggArt.BOB.AMOUNT / 2, 1e-6, "thinnest")
		for t = 0, 3, 0.13 do
			sx, sy = CandyEggArt.bob(t)
			assert(math.abs(sy - 1) <= 0.1 and math.abs(sx - 1) <= 0.05, "gentle at " .. t)
		end
		sx, sy = CandyEggArt.bob(0 / 0)
		equal(sx, 1); equal(sy, 1)
	end)

	case("CG-12: every place that draws an egg routes through CandyEggArt (nest, ground, cradle, backpack)", function()
		local server = sources.server
		assert(server:find('require(ReplicatedStorage:WaitForChild("WildboundCandyEggArt"))', 1, true), "server requires it")
		assert(server:find("local function visual(kind, position, species, scale, height, rarity, context)", 1, true),
			"visual takes the egg's rarity and context")
		assert(server:find("CandyEggArt.build(model, foot, CandyEggArt.HEIGHT, species, rarity or look.rarity, context)",
			1, true), "visual builds the candy egg")
		assert(server:find('slot.species, (slot.island or slot.wild) and slot.kind == "Creature" and Species.CRIA_SCALE or nil, nil,\n\t\tslot.rarity or Species.look(slot.species).rarity, "nest")', 1, true), "nest eggs pass their rarity")
		assert(server:find('visual("Egg", Vector3.new(x, y - 0.6, z), egg.meta.species, nil, nil, egg.meta.rarity, "ground")',
			1, true), "dropped eggs")
		assert(server:find('visual("Egg", top, entry.species, nil, nil, entry.rarity, "cradle")', 1, true), "cradle eggs")
		assert(server:find("CandyEggArt.PACK_HEIGHT, egg.meta.species, egg.meta.rarity, \"pack\")", 1, true), "backpack egg")
		assert(server:find("CandyEggArt.weldTo(candy, shell)", 1, true), "backpack welds it")
		local bob = sources.bob
		assert(bob:find("CandyEggArt.BOB_TAG", 1, true) and bob:find("CandyEggArt.bob(", 1, true), "client bob")
	end)

	return result
end
