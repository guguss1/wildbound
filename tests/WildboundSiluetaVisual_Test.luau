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
	local function grinOf(root)
		local grin = root and root:FindFirstChild("HorrorGrin", true)
		assert(grin and grin:IsA("BillboardGui"), "a HorrorGrin billboard")
		return grin
	end
	case("look pass: the horror grin hides until the hunt and stays through the warning and the strike", function()
		local f = fixture(true, true)
		boneChain(f)
		f.options.look = Visual.DREAD_LOOK
		local visual = f:create()
		local grin = grinOf(visual.art)
		equal(grin.Enabled, false)
		-- Play finding (night chase): adorned on the head bone itself the grin floated above the eyes once the hunch
		-- tipped the head forward. It rides a GrinAnchor bone at the mouth, a child of the head bone, so it follows the
		-- hunch, the stretch and every clip.
		local anchor = grin.Adornee
		assert(anchor and anchor:IsA("Bone") and anchor.Name == "GrinAnchor", "a GrinAnchor bone")
		equal(anchor.Parent, visual.art:FindFirstChild("Head", true), "a child of the animated head bone")
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
	case("look pass: the grin is wider than the head and follows the art scale", function()
		local f = fixture(true, true)
		boneChain(f)
		f.options.visualScale = 1.9
		local visual = f:create()
		local grin = grinOf(visual.art)
		local small = grin.Size.X.Scale
		assert(small > 0 and grin.Size.X.Offset == 0, "sized in studs")
		-- Without a pose the anchor sits at the template's mouth, scaled with the art.
		local mouth = visual.art:GetPivot():PointToWorldSpace(Visual.GRIN.mouth * 1.9)
		assert((grin.Adornee.WorldPosition - mouth).Magnitude < 0.001, "the anchor sits at the mouth")
		-- Play finding (night chase): 0.3 studs per unit of scale toward the camera let the hunched head hide the grin.
		assert(grin.StudsOffset.Z >= 0.6 * 1.9, "in front of the face")
		visual:setScale(3.8)
		near(grin.Size.X.Scale, small * 2)
		assert(grin.Size.X.Scale > grin.Size.Y.Scale * 1.8, "a wide grin")
		assert(grin.StudsOffset.Z >= 0.6 * 3.8, "still in front of the face")
		visual:destroy()
	end)
	case("look pass: without art the grin rides the plain head and leaves with it", function()
		local f = fixture(false, false)
		local visual = f:create()
		local grin = grinOf(f.head)
		equal(grin.Adornee, f.head); equal(grin.Enabled, false)
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
