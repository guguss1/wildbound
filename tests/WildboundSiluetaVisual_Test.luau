-- Run with a freshly cloned adapter ModuleScript in authorized Studio Edit/Server.
-- Real Instances exercise clone/reveal/pivot; injected tracks exercise deterministic scheduling.
return function(Visual)
	local result = { passed = 0, failed = 0, messages = {} }
	local owned = {}
	local durations = { Idle = 3, Locomotion = 2, Telegraph = 1.4, Attack = 1 }
	local function case(name, run)
		local ok, message = pcall(run)
		for _, item in ipairs(owned) do item:Destroy() end
		table.clear(owned)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected)
		assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected)
		assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. tostring(expected))
	end
	local function fixture(withTemplate, withIds)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "SiluetaVisualContractFixture", game:GetService("ServerStorage")
		table.insert(owned, folder)
		local guardian = Instance.new("Model")
		guardian.Name, guardian.Parent = "Silueta", folder
		local function part(parent, name, transparency)
			local item = Instance.new("Part")
			item.Name, item.Transparency, item.Anchored = name, transparency, true
			item.Parent = parent
			return item
		end
		local body = part(guardian, "Body", 0.86)
		body.Size, body.CFrame = Vector3.new(2.8, 6.4, 2.2), CFrame.new(13, 3.7, -85)
		local head = part(guardian, "Head", 0.82)
		head.CFrame = body.CFrame * CFrame.new(0, 3.5, 0)
		guardian.PrimaryPart = body
		local cue = part(guardian, "GroundCue", 0.35)
		local outline = Instance.new("Highlight")
		outline.Adornee, outline.Parent = guardian, guardian
		local template
		if withTemplate then
			template = Instance.new("Model")
			template.Name, template.Parent = "SiluetaV3", folder
			local nested = Instance.new("Folder")
			nested.Name, nested.Parent = "NestedArt", template
			for index, alpha in ipairs({ 0, 0.2, 1 }) do
				local mesh = Instance.new("MeshPart")
				mesh.Name, mesh.Transparency = "Mesh" .. index, alpha
				mesh.CFrame, mesh.Parent = CFrame.new(index, 2, 0), nested
				mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, true, true
				if index == 1 then
					local bone = Instance.new("Bone")
					bone.Name, bone.Parent = "Root", mesh
				end
			end
			template.WorldPivot = CFrame.new()
			if withIds then
				for index, name in ipairs({ "Idle", "Locomotion", "Telegraph", "Attack" }) do
					template:SetAttribute(name .. "AnimationId", "rbxassetid://" .. (1000 + index))
				end
			end
		end
		local f = { folder = folder, guardian = guardian, body = body, head = head,
			cue = cue, outline = outline, template = template, now = 100, tracks = {}, loads = 0 }
		f.options = { guardian = guardian, body = body, head = head, template = template,
			clock = function() return f.now end,
			loadTrack = function(animator, animation)
				assert(animator:IsA("Animator") and animator.Parent:IsA("AnimationController"))
				assert(animator:IsDescendantOf(guardian), "Animator must be server-parented before load")
				f.loads += 1
				local track = { plays = 0, stops = 0, destroys = 0, TimePosition = 0, Looped = false,
					Length = durations[animation.Name] }
				function track:Play(_fade, _weight, speed) self.plays += 1; self.speed = speed end
				function track:Stop() self.stops += 1 end
				function track:Destroy() self.destroys += 1 end
				f.tracks[animation.Name] = track
				return track
			end }
		function f:setTrackLength(name, length)
			local load = self.options.loadTrack
			self.options.loadTrack = function(animator, animation)
				local track = load(animator, animation)
				if animation.Name == name then track.Length = length end
				return track
			end
		end
		function f:create() self.visual = Visual.new(self.options); return self.visual end
		function f:tick(now) self.now = now; self.visual:step() end
		return f
	end

	case("missing template retains functional primitive fallback", function()
		local f = fixture(false, false)
		local visual = f:create()
		equal(visual.artReady, false); equal(visual.animationReady, false)
		visual:setRevealed(true)
		near(f.body.Transparency, 0.3); near(f.head.Transparency, 0.25)
		visual:setRevealed(false)
		near(f.body.Transparency, 0.86); near(f.head.Transparency, 0.82)
		visual:destroy()
	end)
	case("invalid template does not hide proxies", function()
		local f = fixture(true, false)
		f.template:FindFirstChild("Root", true):Destroy()
		local visual = f:create()
		equal(visual.artReady, false); equal(visual.art, nil)
		near(f.body.Transparency, 0.86); visual:destroy()
	end)
	case("unexpected executable template is refused without execution", function()
		local f = fixture(true, true)
		local executable = Instance.new("ModuleScript")
		executable.Parent = f.template
		local visual = f:create()
		equal(visual.artReady, false); equal(f.loads, 0); visual:destroy()
	end)
	case("validated art clones without modifying source template", function()
		local f = fixture(true, true)
		local count, pivot = #f.template:GetDescendants(), f.template:GetPivot()
		local visual = f:create()
		equal(visual.artReady, true); assert(visual.art ~= f.template)
		equal(visual.art.Parent, f.guardian); equal(f.template.Parent, f.folder)
		equal(#f.template:GetDescendants(), count); equal(f.template:GetPivot(), pivot)
		equal(f.template:FindFirstChild("Mesh1", true).CanCollide, true)
		near(f.template:FindFirstChild("Mesh2", true).Transparency, 0.2)
		visual:destroy()
	end)
	case("art cannot participate in physical touch query or collision", function()
		local f = fixture(true, true)
		local visual = f:create()
		for _, item in ipairs(visual.art:GetDescendants()) do
			if item:IsA("BasePart") then
				equal(item.Anchored, true); equal(item.CanCollide, false)
				equal(item.CanTouch, false); equal(item.CanQuery, false)
			end
		end
		visual:destroy()
	end)
	case("art feet alignment preserves authoritative body pivot and helpers", function()
		local f = fixture(true, true)
		local pivot, bodyFrame, cueFrame = f.guardian:GetPivot(), f.body.CFrame, f.cue.CFrame
		local visual = f:create()
		equal(f.guardian.PrimaryPart, f.body); equal(f.guardian:GetPivot(), pivot)
		equal(f.body.CFrame, bodyFrame); equal(f.cue.CFrame, cueFrame)
		assert((visual.art:GetPivot().Position - Vector3.new(13, 0.5, -85)).Magnitude < 0.00001)
		equal(f.outline.Adornee, f.guardian); near(f.cue.Transparency, 0.35)
		f.guardian:PivotTo(CFrame.new(30, 3.7, -80))
		assert((visual.art:GetPivot().Position - Vector3.new(30, 0.5, -80)).Magnitude < 0.00001)
		visual:destroy()
	end)
	case("visual scale is a ratio of the existing template scale and preserves feet and gameplay", function()
		local f = fixture(true, true)
		f.template:ScaleTo(3.571)
		local templateScale, templatePivot = f.template:GetScale(), f.template:GetPivot()
		local templateSize = f.template:FindFirstChild("Mesh1", true).Size
		local bodySize, bodyFrame, cueFrame = f.body.Size, f.body.CFrame, f.cue.CFrame
		local guardianPivot = f.guardian:GetPivot()
		f.options.visualScale = 1.30
		local visual = f:create()
		equal(visual.artReady, true); near(visual.art:GetScale(), templateScale * 1.30)
		assert((visual.art:GetPivot().Position - Vector3.new(13, 0.5, -85)).Magnitude < 0.00001)
		equal(f.template:GetScale(), templateScale); equal(f.template:GetPivot(), templatePivot)
		equal(f.template:FindFirstChild("Mesh1", true).Size, templateSize)
		equal(f.body.Size, bodySize); equal(f.body.CFrame, bodyFrame); equal(f.cue.CFrame, cueFrame)
		equal(f.guardian.PrimaryPart, f.body); equal(f.guardian:GetPivot(), guardianPivot)
		visual:destroy()
	end)
	case("invalid visual scale falls back to original clone scale", function()
		-- Chase pass (CP-D4): the supported ceiling is 3 (was 2), so 2.6 is a valid scale; 3.01 is the new invalid edge.
		-- Deliberately changed in the look pass (user: "mucho más alto"): the ceiling is 4.5, so 4.51 is the invalid edge.
		for _, factor in ipairs({ false, "1.3", 0, -1, 0.49, 4.51, math.huge, -math.huge, 0 / 0 }) do
			local f = fixture(true, true)
			f.template:ScaleTo(3.571); f.options.visualScale = factor
			local visual = f:create()
			equal(visual.artReady, true); near(visual.art:GetScale(), f.template:GetScale())
			assert((visual.art:GetPivot().Position - Vector3.new(13, 0.5, -85)).Magnitude < 0.00001)
			visual:destroy()
		end
	end)
	case("omitted visual scale keeps existing behavior and supported bounds scale art only", function()
		for _, factor in ipairs({ 0.5, 1, 2, 2.6, 3, 3.8, 4.5 }) do -- look pass: 3.8 and the 4.5 ceiling are valid
			local f = fixture(true, true)
			local originalBodySize = f.body.Size
			f.options.visualScale = factor
			local visual = f:create()
			near(visual.art:GetScale(), f.template:GetScale() * factor)
			equal(f.body.Size, originalBodySize); visual:destroy()
		end
		local f = fixture(true, true)
		local visual = f:create()
		near(visual.art:GetScale(), f.template:GetScale()); visual:destroy()
	end)
	-- Dread pass (user: darker and scarier, barely seen in the fog): an optional look darkens every art colour, lights
	-- the eyes and keeps the unrevealed body a dark shape instead of a near-invisible ghost. The template is untouched.
	case("dread look darkens the art, lights the eyes and keeps a dark readable shape", function()
		local f = fixture(true, true)
		local nested = f.template:FindFirstChild("NestedArt")
		local eyes = Instance.new("MeshPart")
		eyes.Name, eyes.Color, eyes.Parent = "SiluetaV3_Eyes", Color3.fromRGB(240, 240, 240), nested
		f.template:FindFirstChild("Mesh1", true).Color = Color3.fromRGB(100, 120, 140)
		local look = Visual.DREAD_LOOK
		assert(type(look) == "table" and look.tint > 0 and look.tint < 0.6, "a darkening tint")
		f.options.look = look
		local visual = f:create()
		local mesh = visual.art:FindFirstChild("Mesh1", true)
		near(mesh.Color.R, 100 / 255 * look.tint); near(mesh.Color.B, 140 / 255 * look.tint)
		equal(f.template:FindFirstChild("Mesh1", true).Color, Color3.fromRGB(100, 120, 140))
		local lit = visual.art:FindFirstChild("SiluetaV3_Eyes", true)
		equal(lit.Material, Enum.Material.Neon); equal(lit.Color, look.eyes)
		visual:setRevealed(false)
		near(mesh.Transparency, look.hiddenAlpha)
		assert(look.hiddenAlpha <= 0.6, "unrevealed it is a shape, not a ghost")
		near(visual.art:FindFirstChild("Mesh3", true).Transparency, 1)
		visual:setRevealed(true)
		near(mesh.Transparency, look.revealedAlpha)
		visual:destroy()
	end)
	-- Look pass (user: "mucho más alto y tenebroso"; a terrifying smile when she starts chasing). Art and presentation
	-- only: the gameplay body, head, hit range and AI never read any of it.
	local function boneChain(f)
		local root = f.template:FindFirstChild("Root", true)
		local function bone(name, parent, position)
			local item = Instance.new("Bone")
			item.Name, item.Position, item.Parent = name, position, parent
			return item
		end
		local chest = bone("Chest", root, Vector3.new(0, 4, 0))
		local neck = bone("Neck", chest, Vector3.new(0, 1, 0))
		bone("Head", neck, Vector3.new(0, 0.5, 0))
		for _, side in ipairs({ "L", "R" }) do
			local upper = bone("UpperArm." .. side, chest, Vector3.new(side == "L" and 1 or -1, 0.6, 0))
			local fore = bone("Forearm." .. side, upper, Vector3.new(0, -1.2, 0))
			bone("Hand." .. side, fore, Vector3.new(0, -2, 0))
		end
	end
	case("look pass: the dread look hunches the chest and neck and stretches the neck and arms in the rest pose", function()
		local f = fixture(true, true)
		boneChain(f)
		local look = Visual.DREAD_LOOK
		assert(type(look.pose) == "table", "the dread look carries a pose")
		f.options.look = look
		local visual = f:create()
		local function pair(name)
			return f.template:FindFirstChild(name, true), visual.art:FindFirstChild(name, true)
		end
		for name, degrees in pairs(look.pose.pitch) do
			local source, shaped = pair(name)
			assert(degrees < 0 and degrees >= -30, "a slight forward hunch " .. name)
			local delta = source.CFrame:ToObjectSpace(shaped.CFrame)
			local x = delta:ToEulerAnglesXYZ()
			near(math.deg(x), degrees)
			near((shaped.Position - source.Position).Magnitude, 0)
		end
		for name, stretch in pairs(look.pose.stretch) do
			local source, shaped = pair(name)
			assert(stretch > 1 and stretch <= 1.5, "longer, not broken " .. name)
			near(shaped.Position.Magnitude, source.Position.Magnitude * stretch)
		end
		equal(f.template:FindFirstChild("Head", true).Position, Vector3.new(0, 0.5, 0))
		visual:destroy()
	end)
	case("look pass: a pose without its bones is skipped and the plain look keeps the rest pose", function()
		local f = fixture(true, true)
		f.options.look = Visual.DREAD_LOOK
		local visual = f:create()
		equal(visual.artReady, true); visual:destroy()
		local plain = fixture(true, true)
		boneChain(plain)
		local plainVisual = plain:create()
		equal(plainVisual.art:FindFirstChild("Head", true).Position, Vector3.new(0, 0.5, 0))
		plainVisual:destroy()
	end)
	case("look pass: setScale rescales the art about its feet, refuses bad values and never moves the body", function()
		local f = fixture(true, true)
		f.template:ScaleTo(3.571)
		f.options.visualScale = 2.6
		local visual = f:create()
		local bodySize, bodyFrame = f.body.Size, f.body.CFrame
		equal(visual:setScale(3.8), true)
		near(visual.art:GetScale(), f.template:GetScale() * 3.8)
		assert((visual.art:GetPivot().Position - Vector3.new(13, 0.5, -85)).Magnitude < 0.00001)
		for _, bad in ipairs({ 4.51, 0.49, 0 / 0, "4" }) do equal(visual:setScale(bad), false) end
		near(visual.art:GetScale(), f.template:GetScale() * 3.8)
		equal(f.body.Size, bodySize); equal(f.body.CFrame, bodyFrame)
		visual:destroy()
		equal(visual:setScale(3), false)
	end)
	-- Fix pass (FP1, user: the grin read as a flat sticker floating off the face): the grin is a SurfaceGui on a thin
	-- anchored "HorrorJaw" part fitted to the head's own geometry, flush on its front face and turned with the head; no
	-- BillboardGui and no camera-axis push remain anywhere on the guardian.
	local function grinOf(root)
		local grin = root and root:FindFirstChild("HorrorGrin", true)
		assert(grin and grin:IsA("SurfaceGui"), "a HorrorGrin SurfaceGui")
		for _, item in ipairs(root:GetDescendants()) do
			assert(not item:IsA("BillboardGui"), "no BillboardGui remains: " .. item:GetFullName())
		end
		local jaw = grin.Parent
		assert(jaw and jaw:IsA("BasePart") and jaw.Name == "HorrorJaw", "the grin sits on the HorrorJaw part")
		equal(jaw.Anchored, true); equal(jaw.CanCollide, false); equal(jaw.CanQuery, false); equal(jaw.CanTouch, false)
		near(jaw.Transparency, 1)
		equal(grin.Face, Enum.NormalId.Front, "drawn on the front face")
		return grin, jaw
	end
	-- The art's head: one MeshPart whose name carries "Head" (SiluetaV3_Head in the real template), 1.11 x 1.25 x 1.0
	-- studs, just in front of the neck, looking down -Z like the template pivot.
	local HEAD_SIZE, HEAD_CFRAME = Vector3.new(1.1084, 1.2525, 1.0044), CFrame.new(0.043, 6.295, -0.792)
	local function headPart(f)
		local head = Instance.new("MeshPart")
		head.Name, head.Size, head.CFrame = "SiluetaV3_Head", HEAD_SIZE, HEAD_CFRAME
		head.Parent = f.template:FindFirstChild("NestedArt")
		return head
	end
	case("look pass: the horror grin hides until the hunt and stays through the warning and the strike", function()
		local f = fixture(true, true)
		boneChain(f)
		headPart(f)
		f.options.look = Visual.DREAD_LOOK
		local visual = f:create()
		local grin, jaw = grinOf(visual.art)
		equal(grin.Enabled, false)
		equal(jaw.Parent, visual.art, "the jaw is part of the art, so it moves and scales with it")
		equal(f.template:FindFirstChild("HorrorJaw", true), nil, "the template is untouched")
		equal(f.template:FindFirstChild("GrinAnchor", true), nil, "the template is untouched")
		equal(grin.LightInfluence, 0, "a faint glow the night fog cannot darken")
		equal(grin.AlwaysOnTop, false, "trunks still hide it")
		assert(grin.MaxDistance >= 60, "readable from the chase distance")
		local teeth = 0
		for _, item in ipairs(grin:GetDescendants()) do
			if item.Name == "Tooth" then teeth += 1 end
		end
		assert(teeth >= 30, "too many teeth: " .. teeth)
		local face = grin:FindFirstChild("Face")
		assert(face and face:IsA("CanvasGroup") and face:FindFirstChild("Pop") and face.Pop:IsA("UIScale"),
			"the client pops the Face through its UIScale")
		local shown = { Hunt = true, Telegraph = true, Attack = true }
		for _, state in ipairs({ "Patrol", "Alert", "Hunt", "Telegraph", "Attack", "Retreat", "Hunt", "Search",
			"Investigate", "Suspicious", "Hunt", "Alert" }) do
			visual:setState(state, state == "Telegraph" and 101.4 or nil)
			equal(grin.Enabled, shown[state] == true, state)
		end
		near(f.body.Transparency, 1); equal(f.body.Size, Vector3.new(2.8, 6.4, 2.2))
		visual:destroy()
		equal(grin.Parent, nil)
	end)
	-- Deliberately changed in the fix pass (FP1): the grin was a BillboardGui on a GrinAnchor bone at a hard-coded mouth
	-- offset, pushed 0.7 studs per unit of scale toward the camera. It is now fitted to the head geometry.
	local function headBounds(visual)
		local head
		for _, item in ipairs(visual.art:GetDescendants()) do
			if item:IsA("BasePart") and item.Name:find("Head", 1, true) then head = item break end
		end
		assert(head, "the cloned head part")
		return head
	end
	case("fix pass: the jaw is fitted to the head geometry, flush on its front face, at every supported scale", function()
		for _, scale in ipairs({ 2, 3.8, 4.5 }) do
			local f = fixture(true, true)
			boneChain(f)
			headPart(f)
			f.options.visualScale = scale
			local visual = f:create()
			local grin, jaw = grinOf(visual.art)
			local head = headBounds(visual)
			-- Inside the head's bounds (plus 0.3 stud of slack) so it can never float off the face.
			local inHead = head.CFrame:PointToObjectSpace(jaw.Position)
			for _, axis in ipairs({ "X", "Y", "Z" }) do
				assert(math.abs(inHead[axis]) <= head.Size[axis] / 2 + 0.3, ("scale %s: jaw %s=%.3f outside the head"):format(
					scale, axis, inHead[axis]))
			end
			-- Flush on the front face: its centre sits at the face, not behind it and not pushed toward a camera.
			assert(-inHead.Z >= head.Size.Z / 2 - 0.05 * scale and -inHead.Z <= head.Size.Z / 2 + 0.3, "flush on the front face")
			assert(inHead.Y < 0, "on the lower half, where the mouth is")
			assert(jaw.CFrame.LookVector:Dot(head.CFrame.LookVector) > 0.99, "turned with the head")
			assert(jaw.Size.X >= head.Size.X * 1.0 and jaw.Size.X <= head.Size.X * 1.7, "about the head's width: " .. jaw.Size.X)
			assert(jaw.Size.Y >= head.Size.Y * 0.25 and jaw.Size.Y <= head.Size.Y * 0.6, "a jaw, not a mask: " .. jaw.Size.Y)
			assert(jaw.Size.Z <= 0.1 * scale, "thin")
			assert(grin.MaxDistance >= 60, "readable from the chase distance")
			equal(grin.AlwaysOnTop, false, "trunks still hide it")
			if scale == 3.8 then
				-- A live rescale refits the jaw to the rescaled head.
				local width = jaw.Size.X
				equal(visual:setScale(4.5), true)
				near(jaw.Size.X / width, 4.5 / 3.8)
				local again = headBounds(visual).CFrame:PointToObjectSpace(jaw.Position)
				assert(math.abs(again.Y) <= headBounds(visual).Size.Y / 2 + 0.3, "still inside the head after a rescale")
			end
			visual:destroy()
			equal(jaw.Parent, nil)
		end
	end)
	case("fix pass: the jaw is locked to the head bone, so the hunch and a lean carry it with the face", function()
		local plain = fixture(true, true)
		boneChain(plain); headPart(plain)
		local plainVisual = plain:create()
		local _, plainJaw = grinOf(plainVisual.art)
		local plainBone = plainVisual.art:FindFirstChild("Head", true)
		local plainOffset = plainBone.WorldCFrame:ToObjectSpace(plainJaw.CFrame)
		local f = fixture(true, true)
		boneChain(f); headPart(f)
		f.options.look = Visual.DREAD_LOOK
		local visual = f:create()
		local _, jaw = grinOf(visual.art)
		local bone = visual.art:FindFirstChild("Head", true)
		local offset = bone.WorldCFrame:ToObjectSpace(jaw.CFrame)
		assert((offset.Position - plainOffset.Position).Magnitude < 0.001, "the same place on the head bone")
		assert(offset.LookVector:Dot(plainOffset.LookVector) > 0.999, "the same turn on the head bone")
		assert((jaw.Position - plainJaw.Position).Magnitude > 0.1, "the hunch moved the jaw with the head")
		plainVisual:destroy(); visual:destroy()
	end)
	-- Fix pass (FP1, framing): with the default camera the giant's face sat above the frame at chase range. While she
	-- hunts she leans toward her quarry (chest and neck pitch, capped, eased in and out), so the face drops into view at
	-- close range. The player camera is never touched; the gameplay body never moves.
	local function leanOf(f, visual)
		local total = 0
		for name, degrees in pairs(Visual.DREAD_LOOK.pose.pitch) do
			local source, shaped = f.template:FindFirstChild(name, true), visual.art:FindFirstChild(name, true)
			local x = source.CFrame:ToObjectSpace(shaped.CFrame):ToEulerAnglesXYZ()
			total += -math.deg(x) - (-degrees)
		end
		return total
	end
	case("fix pass: while hunting she leans toward a close quarry, capped and eased, and straightens afterwards", function()
		local f = fixture(true, true)
		boneChain(f); headPart(f)
		f.options.look = Visual.DREAD_LOOK
		local visual = f:create()
		local bodyFrame = f.body.CFrame
		assert(type(Visual.LEAN) == "table" and Visual.LEAN.max >= 20 and Visual.LEAN.max <= 30, "a lean cap near 25 degrees")
		near(leanOf(f, visual), 0)
		-- The body stands at (13, 3.7, -85) looking down -Z: a quarry 8 studs ahead, then one 60 studs ahead.
		visual:setState("Hunt")
		visual:setQuarry(Vector3.new(13, 0, -93))
		f:tick(100.1)
		local early = leanOf(f, visual)
		assert(early > 0.5 and early < Visual.LEAN.max - 1, "eased in, not snapped: " .. early)
		for t = 100.2, 104, 0.1 do f:tick(t) end
		local full = leanOf(f, visual)
		assert(math.abs(full - Visual.LEAN.max) < 0.5, "a close quarry reaches the cap: " .. full)
		assert(full <= Visual.LEAN.max + 0.01, "never past the cap")
		visual:setQuarry(Vector3.new(13, 0, -145))
		for t = 104.1, 108, 0.1 do f:tick(t) end
		local far = leanOf(f, visual)
		assert(far > 0.5 and far < full - 5, "a far quarry gets a smaller lean: " .. far)
		visual:setQuarry(nil)
		visual:setState("Search")
		for t = 108.1, 112, 0.1 do f:tick(t) end
		assert(leanOf(f, visual) < 0.5, "straight again after the hunt")
		equal(f.body.CFrame, bodyFrame, "the gameplay body never moves")
		visual:destroy()
	end)
	case("look pass: without art the grin rides the plain head and leaves with it", function()
		local f = fixture(false, false)
		local visual = f:create()
		local grin = grinOf(f.guardian)
		equal(grin.Parent.Parent, f.head); equal(grin.Enabled, false)
		visual:setState("Hunt"); equal(grin.Enabled, true)
		visual:setState("Retreat"); equal(grin.Enabled, false)
		visual:destroy(); visual:destroy()
		equal(grin.Parent, nil)
	end)
	case("all nested art uses baseline preserving reveal including invisible meshes", function()
		local f = fixture(true, true)
		local visual = f:create()
		for _, revealed in ipairs({ false, true, false, true }) do
			visual:setRevealed(revealed)
			for index, baseline in ipairs({ 0, 0.2, 1 }) do
				local expected = baseline + (1 - baseline) * (revealed and 0.25 or 0.86)
				near(visual.art:FindFirstChild("Mesh" .. index, true).Transparency, expected)
			end
			near(f.body.Transparency, 1); near(f.head.Transparency, 1)
		end
		visual:destroy()
	end)
	case("missing IDs presents static art honestly without loading fabricated clips", function()
		local f = fixture(true, false)
		local visual = f:create()
		equal(visual.artReady, true); equal(visual.animationReady, false); equal(f.loads, 0)
		visual:setState("Telegraph", 101.4); f:tick(101.4); visual:destroy()
	end)
	case("malformed IDs fail nonfatally before any load", function()
		local f = fixture(true, true)
		f.template:SetAttribute("AttackAnimationId", "rbxassetid://not-an-id")
		local visual = f:create()
		equal(visual.artReady, true); equal(visual.animationReady, false); equal(f.loads, 0)
		visual:destroy()
	end)
	case("track load failure retains static art and cleans partial tracks", function()
		local f = fixture(true, true)
		local load = f.options.loadTrack
		f.options.loadTrack = function(animator, animation)
			if animation.Name == "Telegraph" then error("controlled asset load denial") end
			return load(animator, animation)
		end
		local visual = f:create()
		equal(visual.artReady, true); equal(visual.animationReady, false)
		for _, track in pairs(f.tracks) do equal(track.destroys, 1) end
		visual:destroy()
	end)
	case("server Animator owns four tracks with only idle and locomotion looped", function()
		local f = fixture(true, true)
		local visual = f:create()
		equal(visual.animationReady, true); equal(f.loads, 4)
		equal(f.tracks.Idle.Looped, true); equal(f.tracks.Locomotion.Looped, true)
		equal(f.tracks.Telegraph.Looped, false); equal(f.tracks.Attack.Looped, false)
		visual:destroy()
	end)
	case("zero length stays pending and starts only the current pose after every clip loads", function()
		local f = fixture(true, true)
		f:setTrackLength("Locomotion", 0)
		f:setTrackLength("Attack", 0)
		local visual = f:create()
		equal(visual.artReady, true); equal(visual.animationReady, false); equal(f.loads, 4)
		visual:setState("Telegraph", 101.4)
		f.tracks.Locomotion.Length = durations.Locomotion
		f:tick(101.3)
		equal(visual.animationReady, false)
		for _, track in pairs(f.tracks) do equal(track.plays, 0); equal(track.destroys, 0) end
		f.tracks.Attack.Length = durations.Attack
		f:tick(101.4)
		equal(visual.animationReady, true); equal(f.tracks.Attack.plays, 1)
		near(f.tracks.Attack.TimePosition, 0.23)
		equal(f.tracks.Telegraph.plays, 0)
		visual:destroy()
	end)
	case("unresolved length times out once and retains static revealable art", function()
		local f = fixture(true, true)
		f:setTrackLength("Attack", 0)
		local visual = f:create()
		f:tick(104.9)
		equal(visual.animationReady, false); equal(f.tracks.Attack.destroys, 0)
		f:tick(105.1)
		equal(visual.artReady, true); equal(visual.animationReady, false)
		f.tracks.Attack.Length = durations.Attack
		f:tick(106)
		equal(visual.animationReady, false); equal(f.loads, 4)
		visual:setRevealed(true)
		near(visual.art:FindFirstChild("Mesh1", true).Transparency, 0.25)
		visual:destroy()
		for _, track in pairs(f.tracks) do equal(track.plays, 0); equal(track.destroys, 1) end
	end)
	case("wrong loaded duration rejects the whole set without starting any track", function()
		local f = fixture(true, true)
		f:setTrackLength("Attack", 0)
		local visual = f:create()
		f.tracks.Attack.Length = 2
		visual:setState("Telegraph", 101.4)
		f:tick(101.4)
		equal(visual.artReady, true); equal(visual.animationReady, false)
		for _, track in pairs(f.tracks) do equal(track.plays, 0); equal(track.destroys, 1) end
		f.tracks.Attack.Length = durations.Attack
		f:tick(102)
		equal(visual.animationReady, false); equal(f.loads, 4)
		visual:destroy()
	end)
	case("stationary retreat idles and actual movement selects locomotion only while moving", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Retreat"); f:tick(100.2)
		equal(f.tracks.Locomotion.plays, 0); equal(f.tracks.Idle.plays, 1)
		visual:setMoving(true); f:tick(100.4)
		visual:setMoving(true); f:tick(100.6)
		equal(f.tracks.Locomotion.plays, 1); equal(f.tracks.Idle.stops, 1)
		visual:setMoving(false); f:tick(100.8)
		equal(f.tracks.Locomotion.stops, 1); equal(f.tracks.Idle.plays, 2)
		visual:destroy()
	end)
	case("repeated states and shared locomotion do not restart tracks", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Patrol"); visual:setMoving(true); visual:setState("Patrol"); visual:setState("Hunt")
		f:tick(100.4); equal(f.tracks.Locomotion.plays, 1)
		visual:setState("Alert"); visual:setState("Alert")
		f:tick(100.6); equal(f.tracks.Idle.plays - f.tracks.Idle.stops, 1); visual:destroy()
	end)
	case("delivery C: walking to a noise or searching plays locomotion; suspicion stands still", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Investigate"); visual:setMoving(true); f:tick(100.4)
		equal(f.tracks.Locomotion.plays, 1)
		visual:setState("Search"); visual:setMoving(true); f:tick(100.6)
		equal(f.tracks.Locomotion.plays, 1, "search keeps the same walk")
		visual:setState("Suspicious"); visual:setMoving(true); f:tick(100.8)
		equal(f.tracks.Locomotion.stops, 1, "suspicion stands and faces the sound")
		visual:destroy()
	end)
	case("attack starts before unchanged damage deadline and reaches strike pose on deadline", function()
		local f = fixture(true, true)
		local visual = f:create()
		local gameplay = { deadline = 101.4, damage = 0 }
		visual:setState("Telegraph", gameplay.deadline)
		f:tick(101.169); equal(f.tracks.Attack.plays, 0)
		f:tick(101.17); equal(f.tracks.Attack.plays, 1); near(f.tracks.Attack.TimePosition, 0)
		f:tick(gameplay.deadline); near(f.tracks.Attack.TimePosition, 0.23)
		equal(gameplay.deadline, 101.4); equal(gameplay.damage, 0)
		visual:destroy()
	end)
	case("late presentation catches up without replaying an elapsed attack", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Telegraph", 101.4)
		f:tick(101.5); near(f.tracks.Attack.TimePosition, 0.33)
		f:tick(101.6); equal(f.tracks.Attack.plays, 1)
		visual:destroy()
		local late = fixture(true, true)
		local lateVisual = late:create()
		lateVisual:setState("Telegraph", 101.4); late:tick(103)
		equal(late.tracks.Attack.plays, 0); lateVisual:destroy()
	end)
	case("same telegraph deadline does not restart warning or attack", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Telegraph", 101.4); visual:setState("Telegraph", 101.4)
		equal(f.tracks.Telegraph.plays, 1)
		f:tick(101.3); visual:setState("Telegraph", 101.4); f:tick(101.4)
		equal(f.tracks.Attack.plays, 1); visual:destroy()
	end)
	case("abandoned warning cancels pending and already started attack", function()
		for _, abandonAt in ipairs({ 100.5, 101.3 }) do
			local f = fixture(true, true)
			local visual = f:create()
			visual:setState("Telegraph", 101.4); f:tick(abandonAt)
			visual:finishTelegraph(false); visual:setState("Retreat"); visual:setMoving(true); f:tick(102)
			equal(f.tracks.Attack.plays, abandonAt == 100.5 and 0 or 1)
			if abandonAt > 101.17 then assert(f.tracks.Attack.stops >= 1) end
			equal(f.tracks.Locomotion.plays, 1); visual:destroy()
		end
	end)
	case("completed valid strike preserves short followthrough then returns to retreat", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Telegraph", 101.4); f:tick(101.4)
		visual:finishTelegraph(true); visual:setState("Retreat")
		visual:setMoving(true)
		equal(f.tracks.Attack.stops, 0)
		f:tick(102.16); equal(f.tracks.Locomotion.plays, 0)
		f:tick(102.18); equal(f.tracks.Locomotion.plays, 1)
		assert(f.tracks.Attack.stops >= 1); visual:destroy()
	end)
	-- Chase pass (CP-D1): after a strike on a live quarry the guardian hunts again at once; the follow-through still
	-- plays before it walks.
	case("chase pass: a strike followed by a renewed hunt keeps the short followthrough", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Telegraph", 101.4); f:tick(101.4)
		visual:finishTelegraph(true); visual:setState("Hunt")
		visual:setMoving(true)
		equal(f.tracks.Attack.stops, 0)
		f:tick(102.16); equal(f.tracks.Locomotion.plays, 0)
		f:tick(102.18); equal(f.tracks.Locomotion.plays, 1)
		visual:destroy()
	end)
	case("new warning supersedes old deadline and invalid deadline cancels safely", function()
		local f = fixture(true, true)
		local visual = f:create()
		visual:setState("Telegraph", 101.4); f:tick(100.5)
		visual:setState("Telegraph", 103.4); f:tick(101.5)
		equal(f.tracks.Telegraph.plays, 2)
		equal(f.tracks.Attack.plays, 0)
		visual:setState("Telegraph", 0 / 0); f:tick(104)
		equal(f.tracks.Attack.plays, 0); visual:destroy()
	end)
	case("cleanup restores proxies destroys only clone and is idempotent", function()
		local f = fixture(true, true)
		local visual = f:create()
		local art = visual.art
		visual:setState("Telegraph", 101.4); visual:setRevealed(true)
		visual:destroy(); visual:destroy(); f:tick(105)
		visual:setState("Hunt"); visual:setRevealed(true)
		equal(art.Parent, nil); equal(f.template.Parent, f.folder)
		near(f.body.Transparency, 0.86); near(f.head.Transparency, 0.82)
		equal(f.cue.Parent, f.guardian); equal(f.outline.Parent, f.guardian)
		for _, track in pairs(f.tracks) do equal(track.destroys, 1) end
	end)
	return result
end
