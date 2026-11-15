-- Invoke with require(freshTestClone)(require(freshTortidragonClone), ServerStorage.WildboundAssets:FindFirstChild("Tortidragon")).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA2): the Tortidragon prefab assembled in Studio from the uploaded
-- Blender rig, against its sheet (pack 03_PERSONAJES/03_TORTIDRAGON.md): one quadruped actor, 22-26 bones in the
-- sheet's tree, about 11 studs tall, coloured, on its pivot facing -Z, with one simple box hitbox. Changes nothing.
return function(Tortidragon, prefab)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local PARENTS = { Pelvis = "Root", Spine = "Pelvis", Neck_01 = "Spine", Neck_02 = "Neck_01", Head = "Neck_02", Jaw = "Head",
		CreamCrest = "Head", Strawberry_L = "Head", Strawberry_R = "Head", Cheek_L = "Head", Cheek_R = "Head", Strawberry_Back = "Spine",
		FrontLeg_L_Upper = "Spine", FrontLeg_L_Lower = "FrontLeg_L_Upper", FrontLeg_R_Upper = "Spine", FrontLeg_R_Lower = "FrontLeg_R_Upper",
		BackLeg_L_Upper = "Pelvis", BackLeg_L_Lower = "BackLeg_L_Upper", BackLeg_R_Upper = "Pelvis", BackLeg_R_Lower = "BackLeg_R_Upper",
		Tail_01 = "Pelvis", Tail_02 = "Tail_01", Tail_03 = "Tail_02" }
	local function bone(model, name)
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("Bone") and d.Name == name then return d end end
		error("no bone " .. name, 0)
	end

	case("one clean animated actor, not the import package", function()
		assert(prefab and prefab:IsA("Model"), "no Tortidragon prefab")
		equal(prefab:GetAttribute("Species"), "Tortidragon"); equal(prefab:GetAttribute("AssetId"), Tortidragon.ASSET_ID)
		local controllers, roots = 0, 0
		for _, d in ipairs(prefab:GetDescendants()) do
			assert(not d:IsA("PackageLink") and not d:IsA("LuaSourceContainer") and not d:IsA("Humanoid"), d.ClassName .. " kept in the prefab")
			if d:IsA("AnimationController") then controllers += 1 end
			if d:IsA("BasePart") and d.Anchored then roots += 1 end
		end
		equal(controllers, 1, "animation controllers"); equal(roots, 1, "anchored parts")
		assert(prefab:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator"), "no Animator")
		assert(prefab.PrimaryPart and prefab.PrimaryPart.Name == "RootPart" and prefab.PrimaryPart.Anchored, "PrimaryPart")
	end)

	case("the sheet's quadruped rig: 24 bones (22-26), four legs, neck, head, jaw, tail, crest and strawberries", function()
		local count = 0
		for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") then count += 1 end end
		equal(count, 24, "bones")
		assert(count >= 22 and count <= 26, "outside the sheet's 22-26")
		equal(bone(prefab, "Root").Parent, prefab.PrimaryPart, "Root bone on the root part")
		for child, parent in pairs(PARENTS) do equal(bone(prefab, child).Parent.Name, parent, child .. " parent") end
	end)

	case("it stands on its pivot, about 11 studs tall, facing -Z, left on its left, a long body", function()
		local pivot = prefab:GetPivot()
		near(pivot.Position.Magnitude, 0, 0.01, "stored at the origin"); near(pivot.UpVector.Y, 1, 1e-4, "upright"); near(pivot.LookVector.Z, -1, 1e-4, "faces -Z")
		local body = prefab.Body
		near(body.Position.Y - body.Size.Y / 2, 0, 0.05, "the feet on the pivot")
		local top = -math.huge
		for _, name in ipairs({ "Cream", "Berry" }) do top = math.max(top, prefab[name].Position.Y + prefab[name].Size.Y / 2) end
		assert(top >= 9.5 and top <= 12, "height " .. top)
		near(top, Tortidragon.HEIGHT, 0.1, "height in the spec")
		assert(bone(prefab, "Head").WorldPosition.Z < -2 and bone(prefab, "Tail_03").WorldPosition.Z > 3, "head not at -Z or tail not at +Z")
		assert(bone(prefab, "FrontLeg_L_Upper").WorldPosition.X < 0 and bone(prefab, "FrontLeg_R_Upper").WorldPosition.X > 0, "left and right are swapped")
		assert(bone(prefab, "FrontLeg_L_Lower").WorldPosition.Y < 2 and bone(prefab, "BackLeg_R_Lower").WorldPosition.Y < 2, "legs do not reach the ground")
	end)

	case("one colour per mesh, all skinned to the root (no rigid piece, no hidden keeper)", function()
		local seen = 0
		for name, colour in pairs(Tortidragon.COLOURS) do
			local part = prefab:FindFirstChild(name)
			assert(part and part:IsA("MeshPart"), "missing " .. name)
			equal(part.Color:ToHex():upper(), string.sub(colour, 2), name .. " colour")
			equal(part.Material, Enum.Material.SmoothPlastic, name .. " material"); equal(part.Transparency, 0, name .. " transparency")
			assert(part:FindFirstChildOfClass("Motor6D"), name .. " lost its joint to the root")
			assert(not part:FindFirstChildOfClass("RigidConstraint"), name .. " is a rigid piece")
			seen += 1
		end
		equal(seen, 10, "meshes")
		for _, d in ipairs(prefab:GetChildren()) do
			if d:IsA("MeshPart") then assert(Tortidragon.COLOURS[d.Name], "a mesh with no colour: " .. d.Name) end
		end
	end)

	case("a simple hitbox: one box on the ground, no mesh collides", function()
		local hitboxes = 0
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("BasePart") then
				equal(d.CanTouch, false, d.Name .. " CanTouch")
				if d:IsA("MeshPart") then equal(d.CanCollide, false, d.Name .. " collides"); equal(d.CanQuery, false, d.Name .. " queries") end
				if d ~= prefab.PrimaryPart then equal(d.Massless, true, d.Name .. " Massless") end
				if d.Name == "Collision" then
					hitboxes += 1
					equal(d.Shape, Enum.PartType.Block, "shape"); equal(d.CanCollide, true); equal(d.Transparency, 1)
					near(d.Position.Y - d.Size.Y / 2, 0, 0.02, "on the ground")
					assert(d.Size.X <= prefab.Body.Size.X, "wider than the body")
				end
			end
		end
		equal(hitboxes, 1, "hitboxes")
	end)

	case("Tortidragon.spawn places a detached copy on a ground CFrame and leaves the prefab alone", function()
		local before = #prefab:GetDescendants()
		local target = CFrame.new(40, 0.5, -12) * CFrame.Angles(0, math.rad(90), 0)
		local copy = Tortidragon.spawn(prefab, target)
		assert(copy ~= prefab and copy.Parent == nil, "detached")
		near((copy:GetPivot().Position - target.Position).Magnitude, 0, 0.01, "position"); near(copy:GetPivot().LookVector.X, target.LookVector.X, 1e-3, "yaw")
		copy:Destroy()
		equal(#prefab:GetDescendants(), before, "prefab size")
	end)

	return result
end
