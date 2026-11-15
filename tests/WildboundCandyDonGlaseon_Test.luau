-- Invoke with require(freshTestClone)(require(freshDonGlaseonClone), ServerStorage.WildboundAssets:FindFirstChild("DonGlaseon")).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3): the Don Glaseon prefab assembled in Studio from the uploaded
-- Blender rig, against its sheet (pack 03_PERSONAJES/04_DON_GLASEON_BOSS.md): one biped boss, 26-30 bones in the
-- sheet's tree (jaw, candy crown, licorice), 22-25 studs tall, coloured, on its pivot facing -Z, one box hitbox.
-- Changes nothing.
return function(DonGlaseon, prefab)
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
	local PARENTS = { Pelvis = "Root", Spine_Lower = "Pelvis", Spine_Upper = "Spine_Lower", Neck = "Spine_Upper", Head = "Neck",
		Jaw = "Head", CandyCrown = "Head", Licorice_01 = "Forearm_R", Licorice_02 = "Licorice_01", Licorice_03 = "Licorice_02" }
	for _, s in ipairs({ "L", "R" }) do
		PARENTS["Shoulder_" .. s] = "Spine_Upper"; PARENTS["UpperArm_" .. s] = "Shoulder_" .. s
		PARENTS["Forearm_" .. s] = "UpperArm_" .. s; PARENTS["Hand_" .. s] = "Forearm_" .. s
		PARENTS["Finger_" .. s .. "1"] = "Hand_" .. s; PARENTS["Finger_" .. s .. "2"] = "Hand_" .. s
		PARENTS["Thigh_" .. s] = "Pelvis"; PARENTS["Shin_" .. s] = "Thigh_" .. s; PARENTS["Foot_" .. s] = "Shin_" .. s
	end
	local function bone(model, name)
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("Bone") and d.Name == name then return d end end
		error("no bone " .. name, 0)
	end

	case("one clean animated actor, not the import package", function()
		assert(prefab and prefab:IsA("Model"), "no DonGlaseon prefab")
		equal(prefab:GetAttribute("Species"), "DonGlaseon"); equal(prefab:GetAttribute("AssetId"), DonGlaseon.ASSET_ID)
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

	case("the sheet's biped rig: 29 bones (26-30) with jaw, candy crown and a three-link licorice whip", function()
		local count = 0
		for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") then count += 1 end end
		equal(count, 29, "bones")
		equal(bone(prefab, "Root").Parent, prefab.PrimaryPart, "Root bone on the root part")
		for child, parent in pairs(PARENTS) do equal(bone(prefab, child).Parent.Name, parent, child .. " parent") end
	end)

	case("it stands on its pivot, 22-25 studs tall, facing -Z, left on its left", function()
		local pivot = prefab:GetPivot()
		near(pivot.Position.Magnitude, 0, 0.01, "stored at the origin"); near(pivot.UpVector.Y, 1, 1e-4, "upright"); near(pivot.LookVector.Z, -1, 1e-4, "faces -Z")
		local leg = prefab.Leg
		near(leg.Position.Y - leg.Size.Y / 2, 0, 0.05, "the feet on the pivot")
		local top = -math.huge
		for _, name in ipairs({ "CandyA", "CandyB", "CandyC", "CandyD", "CandyE" }) do top = math.max(top, prefab[name].Position.Y + prefab[name].Size.Y / 2) end
		assert(top >= 22 and top <= 25, "height " .. top)
		near(top, DonGlaseon.HEIGHT, 0.15, "height in the spec")
		assert(bone(prefab, "Jaw").WorldPosition.Y > 15, "the jaw is not in the head")
		assert(bone(prefab, "Finger_L1").WorldPosition.Z < -1.5, "the claws do not point forward (-Z)")
		assert(bone(prefab, "Hand_L").WorldPosition.X < 0 and bone(prefab, "Hand_R").WorldPosition.X > 0, "left and right are swapped")
		assert(bone(prefab, "Licorice_01").WorldPosition.X > 5, "the licorice is not on the right forearm")
	end)

	case("one colour per mesh, all skinned to the root (no rigid piece)", function()
		local seen = 0
		for name, colour in pairs(DonGlaseon.COLOURS) do
			local part = prefab:FindFirstChild(name)
			assert(part and part:IsA("MeshPart"), "missing " .. name)
			equal(part.Color:ToHex():upper(), string.sub(colour, 2), name .. " colour")
			equal(part.Transparency, 0, name .. " transparency")
			assert(part:FindFirstChildOfClass("Motor6D"), name .. " lost its joint to the root")
			seen += 1
		end
		equal(seen, 14, "meshes")
		for _, d in ipairs(prefab:GetChildren()) do
			if d:IsA("MeshPart") then assert(DonGlaseon.COLOURS[d.Name], "a mesh with no colour: " .. d.Name) end
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
					equal(d.CanCollide, true); equal(d.Transparency, 1)
					near(d.Position.Y - d.Size.Y / 2, 0, 0.02, "on the ground")
				end
			end
		end
		equal(hitboxes, 1, "hitboxes")
	end)

	case("DonGlaseon.spawn places a detached copy on a ground CFrame and leaves the prefab alone", function()
		local before = #prefab:GetDescendants()
		local target = CFrame.new(578, 0.5, -3) * CFrame.Angles(0, math.rad(90), 0)
		local copy = DonGlaseon.spawn(prefab, target)
		assert(copy ~= prefab and copy.Parent == nil, "detached")
		near((copy:GetPivot().Position - target.Position).Magnitude, 0, 0.01, "position")
		copy:Destroy()
		equal(#prefab:GetDescendants(), before, "prefab size")
	end)

	return result
end
