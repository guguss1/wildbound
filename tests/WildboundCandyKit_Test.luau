-- Invoke with require(freshTestClone)(require(freshKitClone), ServerStorage.WildboundAssets:FindFirstChild("CandyKit")).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T2, S4 S8): the prefab library assembled in Studio from the uploaded
-- Blender kit (asset in WildboundCandyKit.ASSET_ID). An FBX import arrives grey, unanchored, colliding, yawed and as a
-- package; this suite holds every prefab to the kit spec instead. It changes nothing for good: the clones it places
-- and the scratch WorldModel it parks in ServerStorage for ray queries are destroyed before it returns.
return function(Kit, library)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	-- Bounding box of the visible meshes of an upright model, as min and max corners.
	local function bounds(model)
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("MeshPart") then
				local cf, s = d.CFrame, d.Size
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local half = Vector3.new(
					(math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
					(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
					(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2)
				low, high = low:Min(d.Position - half), high:Max(d.Position + half)
			end
		end
		return low, high
	end
	local names = {}
	for name in pairs(Kit.SPEC) do table.insert(names, name) end
	table.sort(names)

	case("S4: every kit asset is a prefab with all its pieces and no package link", function()
		assert(library and library:IsA("Folder"), "no CandyKit library")
		equal(#names, 22, "assets in the spec")
		equal(#library:GetChildren(), #names, "prefabs")
		for _, name in ipairs(names) do
			local prefab = library:FindFirstChild(name)
			assert(prefab and prefab:IsA("Model"), "missing prefab " .. name)
			equal(prefab:GetAttribute("AssetId"), Kit.ASSET_ID, name .. " AssetId")
			for pieceName in pairs(Kit.SPEC[name].pieces) do
				local piece = prefab:FindFirstChild(pieceName)
				assert(piece and piece:IsA("MeshPart"), name .. " lacks " .. pieceName)
			end
		end
		for _, d in ipairs(library:GetDescendants()) do
			assert(not d:IsA("PackageLink"), "package link kept in " .. d:GetFullName())
			assert(not d:IsA("LuaSourceContainer"), "script in " .. d:GetFullName())
		end
	end)

	case("S4: each piece has its one colour and is static", function()
		for _, name in ipairs(names) do
			for pieceName, piece in pairs(Kit.SPEC[name].pieces) do
				local part = library[name][pieceName]
				equal(part.Color:ToHex():upper(), string.sub(piece[2], 2), name .. "." .. pieceName .. " colour")
				near(part.Transparency, piece[4], 1e-4, name .. "." .. pieceName .. " transparency")
				equal(part.Material, Enum.Material.SmoothPlastic, name .. "." .. pieceName .. " material")
				equal(part.Anchored, true, name .. "." .. pieceName .. " Anchored")
				equal(part.CanTouch, false, name .. "." .. pieceName .. " CanTouch")
			end
		end
	end)

	case("S4: prefabs stand upright on their pivot at the size the spec gives", function()
		for _, name in ipairs(names) do
			local prefab, size = library[name], Kit.SPEC[name].size
			local pivot = prefab:GetPivot()
			near((pivot.Position - Vector3.zero).Magnitude, 0, 0.01, name .. " stored at the origin")
			near(pivot.UpVector.Y, 1, 1e-4, name .. " upright")
			near(pivot.LookVector.Z, -1, 1e-4, name .. " faces -Z")
			local low, high = bounds(prefab)
			near(low.Y, 0, 0.06, name .. " bottom on the pivot")
			near(high.Y - low.Y, size[3], 0.08, name .. " height")
			near(high.X - low.X, size[1], 0.08, name .. " width")
			near(high.Z - low.Z, size[2], 0.08, name .. " depth")
		end
	end)

	case("S4: collisions are simple: no mesh collides, every solid gets a plain proxy part", function()
		-- MeshPart.CollisionFidelity cannot be set from a script (the write is ignored and stays Default, the precise
		-- decomposition), so the meshes never collide and plain parts do: a cylinder for "hull", a block for "box".
		for _, name in ipairs(names) do
			local prefab, expected = library[name], #(Kit.PROXIES[name] or {})
			local low, high = bounds(prefab)
			for pieceName, piece in pairs(Kit.SPEC[name].pieces) do
				local part, plan = prefab[pieceName], piece[3]
				equal(part.CanCollide, false, name .. "." .. pieceName .. " mesh collides")
				equal(part.CanQuery, false, name .. "." .. pieceName .. " mesh answers queries")
				if plan == "hull" or plan == "box" then
					expected += 1
					local proxy = prefab:FindFirstChild("Collision_" .. pieceName)
					assert(proxy and proxy:IsA("Part"), name .. " has no Collision_" .. pieceName)
					equal(proxy.Shape, plan == "hull" and Enum.PartType.Cylinder or Enum.PartType.Block, proxy.Name .. " shape")
					near(proxy.Position.Y, piece[5][3], 0.06, proxy.Name .. " height centre")
					near(plan == "hull" and proxy.Size.X or proxy.Size.Y, piece[6][3], 0.06, proxy.Name .. " height")
				end
			end
			local proxies = 0
			for _, child in ipairs(prefab:GetChildren()) do
				if child:IsA("Part") then
					proxies += 1
					equal(string.sub(child.Name, 1, 10), "Collision_", name .. " proxy name")
					equal(child.Transparency, 1, child.Name .. " visible")
					equal(child.CanCollide, true, child.Name .. " CanCollide")
					equal(child.CanQuery, true, child.Name .. " CanQuery")
					equal(child.Anchored, true, child.Name .. " Anchored")
					equal(child.CanTouch, false, child.Name .. " CanTouch")
					assert(child.Position.X >= low.X - 0.5 and child.Position.X <= high.X + 0.5 and child.Position.Z >= low.Z - 0.5
						and child.Position.Z <= high.Z + 0.5 and child.Position.Y >= -0.01 and child.Position.Y <= high.Y + 0.5,
						child.Name .. " of " .. name .. " is outside its prop")
				end
			end
			equal(proxies, expected, name .. " proxy parts")
		end
	end)

	case("S4: the walk-through props stay walk-through", function()
		-- a ray along the path axis through each arch, at chest height, must meet no collision
		for _, name in ipairs({ "DonutArch", "ReturnPortal" }) do
			local clone = Kit.place(library, name, CFrame.new(0, 500, 0))
			-- a WorldModel only answers queries while it is inside the DataModel (detached, every ray met nothing)
			local scratch = Instance.new("WorldModel")
			scratch.Name = "CandyKitTestScratch"
			scratch.Parent = game:GetService("ServerStorage")
			clone.Parent = scratch
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { clone }
			local hit = scratch:Raycast(Vector3.new(0, 503, -20), Vector3.new(0, 0, 40), params)
			local post = clone:FindFirstChild("Collision_PostRight")
			local control = scratch:Raycast(Vector3.new(post.Position.X, 503, -20), Vector3.new(0, 0, 40), params)
			scratch:Destroy()
			assert(control ~= nil, name .. ": the control ray through a post met nothing, so this query proves nothing")
			assert(hit == nil, name .. " blocks the way with " .. (hit and hit.Instance.Name or ""))
		end
	end)

	case("Kit.place clones, scales and moves a prefab without touching the library", function()
		local before = #library:GetDescendants()
		local target = CFrame.new(100, 7, -40) * CFrame.Angles(0, math.rad(90), 0)
		local clone = Kit.place(library, "TreeCotton_M", target, 0.5)
		assert(clone ~= library.TreeCotton_M and clone.Parent == nil, "the clone is detached")
		near((clone:GetPivot().Position - target.Position).Magnitude, 0, 0.01, "position")
		near(clone:GetPivot().LookVector.X, target.LookVector.X, 1e-3, "yaw")
		local low, high = bounds(clone)
		near(high.Y - low.Y, Kit.SPEC.TreeCotton_M.size[3] * 0.5, 0.08, "scaled height")
		near(low.Y, 7, 0.06, "stands on the target")
		clone:Destroy()
		equal(#library:GetDescendants(), before, "library size")
		assert(not pcall(Kit.place, library, "NoSuchProp", target), "an unknown prefab was accepted")
	end)

	return result
end
