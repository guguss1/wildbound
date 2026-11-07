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
		for _, factor in ipairs({ false, "1.3", 0, -1, 0.49, 2.01, math.huge, -math.huge, 0 / 0 }) do
			local f = fixture(true, true)
			f.template:ScaleTo(3.571); f.options.visualScale = factor
			local visual = f:create()
			equal(visual.artReady, true); near(visual.art:GetScale(), f.template:GetScale())
			assert((visual.art:GetPivot().Position - Vector3.new(13, 0.5, -85)).Magnitude < 0.00001)
			visual:destroy()
		end
	end)
	case("omitted visual scale keeps existing behavior and supported bounds scale art only", function()
		for _, factor in ipairs({ 0.5, 1, 2 }) do
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
