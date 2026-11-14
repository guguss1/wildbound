-- Invoke with require(freshTestClone)(require(freshGomibuClone), ServerStorage.WildboundAssets:FindFirstChild("Gomibu")).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3, S3 S6 S8): the Gomibu prefab assembled in Studio from the uploaded
-- Blender rig (asset in WildboundCandyGomibu.ASSET_ID), against its sheet (pack 03_PERSONAJES/01_GOMIBU.md). The import
-- is a grey package with the face pinned to the root; the prefab must be coloured, stand on its pivot facing -Z, keep
-- the ficha's 14 bones, carry its face on the Head bone and collide only through one plain box. Changes nothing.
return function(Gomibu, prefab)
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
	local PARENTS = { Pelvis = "Root", SpineGel = "Pelvis", Head = "SpineGel", Ear_L = "Head", Ear_R = "Head", Arm_L = "SpineGel",
		Arm_R = "SpineGel", Hand_L = "Arm_L", Hand_R = "Arm_R", Leg_L = "Pelvis", Leg_R = "Pelvis", Foot_L = "Leg_L", Foot_R = "Leg_R" }
	local function bone(model, name)
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("Bone") and d.Name == name then return d end end
		error("no bone " .. name, 0)
	end

	case("S6: the prefab is a clean animated model, not the import package", function()
		assert(prefab and prefab:IsA("Model"), "no Gomibu prefab")
		equal(prefab:GetAttribute("Species"), "Gomibu", "Species")
		equal(prefab:GetAttribute("AssetId"), Gomibu.ASSET_ID, "AssetId")
		for _, d in ipairs(prefab:GetDescendants()) do
			assert(not d:IsA("PackageLink") and not d:IsA("LuaSourceContainer"), d.ClassName .. " kept in the prefab")
		end
		local controller = prefab:FindFirstChildOfClass("AnimationController")
		assert(controller and controller:FindFirstChildOfClass("Animator"), "no AnimationController with an Animator")
		assert(not prefab:FindFirstChildOfClass("Humanoid"), "a Humanoid is not needed: the server moves it")
		assert(prefab.PrimaryPart and prefab.PrimaryPart.Name == "RootPart", "PrimaryPart")
	end)

	case("S6: the rig has the ficha's 14 bones in the ficha's tree", function()
		local count = 0
		for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") then count += 1 end end
		equal(count, 14, "bones")
		equal(bone(prefab, "Root").Parent, prefab.PrimaryPart, "Root bone on the root part")
		for child, parent in pairs(PARENTS) do equal(bone(prefab, child).Parent.Name, parent, child .. " parent") end
	end)

	case("S3: it stands on its pivot, 6 to 7 studs tall, facing -Z, left on its left", function()
		local pivot = prefab:GetPivot()
		near(pivot.Position.Magnitude, 0, 0.01, "stored at the origin")
		near(pivot.UpVector.Y, 1, 1e-4, "upright")
		near(pivot.LookVector.Z, -1, 1e-4, "pivot faces -Z")
		local body = prefab.Body
		near(body.Position.Y - body.Size.Y / 2, 0, 0.05, "feet on the pivot")
		assert(body.Size.Y >= 6 and body.Size.Y <= 7, "height " .. body.Size.Y)
		near(body.Size.Y, Gomibu.HEIGHT, 0.05, "height in the spec")
		near(bone(prefab, "Root").WorldPosition.Y, 0, 0.02, "Root bone at ground level")
		assert(prefab.Eyes.Position.Z < -1, "the face is not on the -Z side")
		near(prefab.Eyes.Position.X, 0, 0.05, "face centred")
		assert(bone(prefab, "Ear_L").WorldPosition.X < -1 and bone(prefab, "Ear_R").WorldPosition.X > 1, "left and right are swapped")
	end)

	case("S6: one colour per piece, and the gummy pink of the sheet", function()
		for name, colour in pairs(Gomibu.COLOURS) do
			local part = prefab:FindFirstChild(name)
			assert(part and part:IsA("MeshPart"), "missing " .. name)
			equal(part.Color:ToHex():upper(), string.sub(colour, 2), name .. " colour")
			equal(part.Material, Enum.Material.SmoothPlastic, name .. " material")
			equal(part.Transparency, 0, name .. ": layered transparency is not allowed")
		end
	end)

	case("S6: the face is rigid on the Head bone", function()
		local head = bone(prefab, "Head")
		for _, name in ipairs({ "Eyes", "EyeShine", "Nose" }) do
			local part = prefab[name]
			assert(not part:FindFirstChildOfClass("Motor6D"), name .. " is still pinned by the import's Motor6D")
			local constraint = part:FindFirstChildOfClass("RigidConstraint")
			assert(constraint, name .. " has no RigidConstraint")
			equal(constraint.Attachment0, head, name .. " Attachment0")
			assert(constraint.Attachment1 and constraint.Attachment1.Parent == part, name .. " Attachment1")
			near((constraint.Attachment1.WorldPosition - head.WorldPosition).Magnitude, 0, 0.01, name .. " attachment on the bone")
		end
	end)

	case("S6: collisions are one plain box; the root is anchored and nothing else is", function()
		local root = prefab.PrimaryPart
		equal(root.Anchored, true, "RootPart Anchored")
		equal(root.CanCollide, false, "RootPart CanCollide")
		equal(root.Transparency, 1, "RootPart visible")
		local boxes = 0
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("BasePart") then
				equal(d.CanTouch, false, d.Name .. " CanTouch")
				if d:IsA("MeshPart") then
					equal(d.CanCollide, false, d.Name .. " mesh collides")
					equal(d.CanQuery, false, d.Name .. " mesh answers queries")
				end
				if d ~= root then
					equal(d.Anchored, false, d.Name .. " Anchored")
					equal(d.Massless, true, d.Name .. " Massless")
					assert(d:FindFirstChildOfClass("Motor6D") or d:FindFirstChildOfClass("RigidConstraint") or d:FindFirstChildOfClass("WeldConstraint"),
						d.Name .. " is not held to the rig")
				end
				if d.Name == "Collision" then
					boxes += 1
					equal(d.CanCollide, true, "Collision CanCollide")
					equal(d.Transparency, 1, "Collision visible")
					near(d.Position.Y - d.Size.Y / 2, 0, 0.02, "Collision on the ground")
					assert(d.Size.X <= prefab.Body.Size.X and d.Size.Y <= prefab.Body.Size.Y, "Collision bigger than the body")
				end
			end
		end
		equal(boxes, 1, "collision boxes")
	end)

	case("Gomibu.spawn places a detached copy on a ground CFrame and leaves the prefab alone", function()
		local before = #prefab:GetDescendants()
		local target = CFrame.new(40, 0.5, -12) * CFrame.Angles(0, math.rad(90), 0)
		local copy = Gomibu.spawn(prefab, target)
		assert(copy ~= prefab and copy.Parent == nil, "the copy is detached")
		near((copy:GetPivot().Position - target.Position).Magnitude, 0, 0.01, "position")
		near(copy:GetPivot().LookVector.X, target.LookVector.X, 1e-3, "yaw")
		near(copy.Body.Position.Y - copy.Body.Size.Y / 2, 0.5, 0.05, "stands on the target")
		copy:Destroy()
		equal(#prefab:GetDescendants(), before, "prefab size")
	end)

	return result
end
