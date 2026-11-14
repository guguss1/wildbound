-- Invoke with require(freshTestClone)(require(freshFlanfuriaClone), ServerStorage.WildboundAssets:FindFirstChild("Flanfuria")).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, T4, S3 S6 S8): the Flanfuria prefab assembled in Studio from the uploaded
-- Blender rig, against its sheet (pack 03_PERSONAJES/02_FLANFURIA.md): one actor, a skinned flan and a kitten in rigid
-- parts, each riding its own bone; coloured, on its pivot facing -Z, with one simple hitbox. Changes nothing.
return function(Flanfuria, prefab)
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
	local PARENTS = { FlanBase = "Root", FlanJiggle = "FlanBase", CaramelTop = "FlanJiggle", CatRoot = "CaramelTop", CatHead = "CatRoot",
		CatEar_L = "CatHead", CatEar_R = "CatHead", CatPaw_L = "CatRoot", CatPaw_R = "CatRoot", CatTail_01 = "CatRoot", CatTail_02 = "CatTail_01",
		CreamPeak = "CatHead", Cherry = "CreamPeak" }
	local function bone(model, name)
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("Bone") and d.Name == name then return d end end
		error("no bone " .. name, 0)
	end

	case("S6: one clean animated actor, not the import package and not two NPCs", function()
		assert(prefab and prefab:IsA("Model"), "no Flanfuria prefab")
		equal(prefab:GetAttribute("Species"), "Flanfuria"); equal(prefab:GetAttribute("AssetId"), Flanfuria.ASSET_ID)
		-- Keeper is the hidden skinned piece that makes the importer keep the kitten's bones: it must never show
		assert(prefab:FindFirstChild("Keeper") and prefab.Keeper.Transparency == 1, "the bone keeper is missing or visible")
		local controllers, roots = 0, 0
		for _, d in ipairs(prefab:GetDescendants()) do
			assert(not d:IsA("PackageLink") and not d:IsA("LuaSourceContainer") and not d:IsA("Humanoid"), d.ClassName .. " kept in the prefab")
			if d:IsA("AnimationController") then controllers += 1 end
			if d:IsA("BasePart") and d.Anchored then roots += 1 end
		end
		equal(controllers, 1, "animation controllers"); equal(roots, 1, "anchored parts: the kitten is not its own root")
		assert(prefab:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator"), "no Animator")
		assert(prefab.PrimaryPart and prefab.PrimaryPart.Name == "RootPart" and prefab.PrimaryPart.Anchored, "PrimaryPart")
	end)

	case("S6: the ficha's 14 bones in the ficha's tree", function()
		local count = 0
		for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") then count += 1 end end
		equal(count, 14, "bones")
		equal(bone(prefab, "Root").Parent, prefab.PrimaryPart, "Root bone on the root part")
		for child, parent in pairs(PARENTS) do equal(bone(prefab, child).Parent.Name, parent, child .. " parent") end
	end)

	case("S3: it stands on its pivot, 7 to 9 studs tall, facing -Z, left on its left", function()
		local pivot = prefab:GetPivot()
		near(pivot.Position.Magnitude, 0, 0.01, "stored at the origin"); near(pivot.UpVector.Y, 1, 1e-4, "upright"); near(pivot.LookVector.Z, -1, 1e-4, "faces -Z")
		local body = prefab.Body
		near(body.Position.Y - body.Size.Y / 2, 0, 0.05, "the flan on the pivot")
		local topY = prefab.CherryFruit.Position.Y + prefab.CherryFruit.Size.Y / 2
		assert(topY >= 7 and topY <= 9, "height " .. topY)
		near(topY, Flanfuria.HEIGHT, 0.05, "height in the spec")
		assert(prefab.FlanFace.Position.Z < -2 and prefab.CatFace.Position.Z < prefab.CatSkull.Position.Z, "a face is not on the -Z side")
		assert(prefab.CatEarL.Position.X < 0 and prefab.CatEarR.Position.X > 0, "left and right are swapped")
		assert(prefab.CatBody.Position.Y > body.Position.Y + body.Size.Y / 2 - 0.3, "the kitten is not on top of the flan")
	end)

	case("S6: one colour per piece, the sheet's flan, caramel, cream and cherry", function()
		local seen = 0
		for name, colour in pairs(Flanfuria.COLOURS) do
			local part = prefab:FindFirstChild(name)
			assert(part and part:IsA("MeshPart"), "missing " .. name)
			equal(part.Color:ToHex():upper(), string.sub(colour, 2), name .. " colour")
			equal(part.Material, Enum.Material.SmoothPlastic, name .. " material"); equal(part.Transparency, 0, name .. " transparency")
			seen += 1
		end
		equal(seen, 15, "pieces")
	end)

	case("S6: every rigid piece rides its own bone, so the kitten can lag the flan", function()
		local riders = 0
		for name, boneName in pairs(Flanfuria.ATTACH) do
			local part, target = prefab[name], bone(prefab, boneName)
			assert(not part:FindFirstChildOfClass("Motor6D"), name .. " is still pinned to the root by the import")
			local constraint = part:FindFirstChildOfClass("RigidConstraint")
			assert(constraint, name .. " has no RigidConstraint")
			equal(constraint.Attachment0, target, name .. " bone")
			assert(constraint.Attachment1 and constraint.Attachment1.Parent == part, name .. " Attachment1")
			near((constraint.Attachment1.WorldPosition - target.WorldPosition).Magnitude, 0, 0.01, name .. " attachment on the bone")
			riders += 1
		end
		equal(riders, 14, "rigid pieces")
		assert(prefab.Body:FindFirstChildOfClass("Motor6D"), "the skinned flan lost its joint to the root")
	end)

	case("S6: a simple hitbox: one cylinder on the ground, no mesh collides", function()
		local hitboxes = 0
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("BasePart") then
				equal(d.CanTouch, false, d.Name .. " CanTouch")
				if d:IsA("MeshPart") then equal(d.CanCollide, false, d.Name .. " collides"); equal(d.CanQuery, false, d.Name .. " queries") end
				if d ~= prefab.PrimaryPart then equal(d.Massless, true, d.Name .. " Massless") end
				if d.Name == "Collision" then
					hitboxes += 1
					equal(d.Shape, Enum.PartType.Cylinder, "shape"); equal(d.CanCollide, true); equal(d.Transparency, 1)
					near(d.Position.Y - d.Size.X / 2, 0, 0.02, "on the ground")
					assert(d.Size.Y <= prefab.Body.Size.X, "wider than the flan")
				end
			end
		end
		equal(hitboxes, 1, "hitboxes")
	end)

	case("Flanfuria.spawn places a detached copy on a ground CFrame and leaves the prefab alone", function()
		local before = #prefab:GetDescendants()
		local target = CFrame.new(40, 0.5, -12) * CFrame.Angles(0, math.rad(90), 0)
		local copy = Flanfuria.spawn(prefab, target)
		assert(copy ~= prefab and copy.Parent == nil, "detached")
		near((copy:GetPivot().Position - target.Position).Magnitude, 0, 0.01, "position"); near(copy:GetPivot().LookVector.X, target.LookVector.X, 1e-3, "yaw")
		copy:Destroy()
		equal(#prefab:GetDescendants(), before, "prefab size")
	end)

	return result
end
