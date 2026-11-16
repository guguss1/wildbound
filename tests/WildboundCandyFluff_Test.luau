-- Invoke with require(freshTestClone)(require(freshCandyKitClone)).
-- Caramelo fuller cotton trees (odd/tasks/wildbound-caramelo-playfix.md, "Fuller cotton trees"): Kit.fluff adds a few
-- plain Ball canopy blobs around a cotton tree's two crowns, in the kit's candy pinks, visual only (no collision, no
-- queries, no touch), once per tree. It runs on unparented stand-in models, never on Workspace.
return function(Kit)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end

	-- A stand-in cotton tree at (x, 0, z): a trunk and two crowns like TreeCotton_M, scaled by s.
	local function tree(x, z, s, withCrowns)
		local model = Instance.new("Model")
		model.Name = "CottonTree_Test"
		local function piece(name, size, at)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size * s
			p.CFrame = CFrame.new(x + at.X * s, at.Y * s, z + at.Z * s)
			p.Parent = model
			return p
		end
		local trunk = piece("Trunk", Vector3.new(2.5, 7.5, 2.2), Vector3.new(0, 3.7, 0))
		if withCrowns ~= false then
			piece("CrownA", Vector3.new(6.3, 8.2, 7), Vector3.new(0, 11.9, 0.7))
			piece("CrownB", Vector3.new(6.8, 8, 7.1), Vector3.new(-1.3, 10.3, -0.9))
		end
		model.PrimaryPart = trunk
		model.WorldPivot = CFrame.new(x, 0, z)
		return model
	end
	local function blobs(model)
		local list = {}
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "Fluff_" then table.insert(list, d) end
		end
		return list
	end
	local function crownBox(model)
		local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("BasePart") and (d.Name == "CrownA" or d.Name == "CrownB" or string.sub(d.Name, 1, 6) == "Fluff_") then
				minV, maxV = minV:Min(d.Position - d.Size / 2), maxV:Max(d.Position + d.Size / 2)
			end
		end
		return minV, maxV
	end

	case("FLUFF: a cotton tree gets Kit.FLUFF_COUNT ball blobs and fluff returns that count", function()
		assert(type(Kit.fluff) == "function", "Kit.fluff exists")
		assert(type(Kit.FLUFF_COUNT) == "number" and Kit.FLUFF_COUNT >= 4 and Kit.FLUFF_COUNT <= 6, "4 to 6 blobs")
		local model = tree(100, -40, 1)
		equal(Kit.fluff(model), Kit.FLUFF_COUNT, "returned count")
		local list = blobs(model)
		equal(#list, Kit.FLUFF_COUNT, "blobs")
		for _, b in ipairs(list) do
			assert(b:IsA("Part") and b.Shape == Enum.PartType.Ball, b.Name .. " is a Ball part")
		end
	end)

	case("FLUFF: blobs are visual only, anchored, in the kit's candy pinks", function()
		local model = tree(0, 0, 1)
		Kit.fluff(model)
		local pinks = {}
		for _, hex in ipairs(Kit.FLUFF_COLORS) do pinks[Color3.fromHex(hex):ToHex()] = true end
		for _, b in ipairs(blobs(model)) do
			assert(b.Anchored and not b.CanCollide and not b.CanQuery and not b.CanTouch, b.Name .. " is visual only")
			equal(b.Material, Enum.Material.SmoothPlastic, b.Name .. " material")
			assert(pinks[b.Color:ToHex()], b.Name .. " colour " .. b.Color:ToHex() .. " is a kit pink")
		end
	end)

	case("FLUFF: the canopy grows wider and taller, and every blob sits above the trunk's lower half", function()
		local model = tree(20, 30, 1.4)
		local minA, maxA = crownBox(model)
		Kit.fluff(model)
		local minB, maxB = crownBox(model)
		local wideA, wideB = math.max(maxA.X - minA.X, maxA.Z - minA.Z), math.max(maxB.X - minB.X, maxB.Z - minB.Z)
		assert(wideB >= wideA * 1.3, ("canopy width %.1f -> %.1f, wanted +30%%"):format(wideA, wideB))
		assert(maxB.Y > maxA.Y, "canopy taller")
		local trunk = model.Trunk
		for _, b in ipairs(blobs(model)) do
			assert(b.Position.Y - b.Size.Y / 2 > trunk.Position.Y, b.Name .. " bottom above the trunk's middle")
			assert(math.abs(b.Position.X - 20) < 20 and math.abs(b.Position.Z - 30) < 20, b.Name .. " stays by its tree")
		end
	end)

	case("FLUFF: a second call adds nothing, and a model without crowns is left alone", function()
		local model = tree(0, 0, 1)
		Kit.fluff(model)
		equal(Kit.fluff(model), 0, "second call")
		equal(#blobs(model), Kit.FLUFF_COUNT, "still one set")
		local bare = tree(0, 0, 1, false)
		equal(Kit.fluff(bare), 0, "no crowns")
		equal(#blobs(bare), 0, "no blobs")
	end)

	case("FLUFF: blobs follow the tree's yaw and scale (same layout in the tree's own frame)", function()
		local a = tree(0, 0, 1)
		Kit.fluff(a)
		local b = tree(0, 0, 1)
		b:PivotTo(CFrame.new(50, 0, 50) * CFrame.Angles(0, math.rad(90), 0))
		Kit.fluff(b)
		for _, blob in ipairs(blobs(a)) do
			local other = b:FindFirstChild(blob.Name)
			assert(other, blob.Name .. " in the turned tree")
			local localA = a:GetPivot():PointToObjectSpace(blob.Position)
			local localB = b:GetPivot():PointToObjectSpace(other.Position)
			assert((localA - localB).Magnitude < 0.01, blob.Name .. " same local spot")
			assert(math.abs(blob.Size.X - other.Size.X) < 0.01, blob.Name .. " same size")
		end
	end)

	return result
end
