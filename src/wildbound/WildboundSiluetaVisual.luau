-- Optional server-owned art presentation. This module never decides or applies damage.
local Visual = {}
Visual.__index = Visual

local ACTIONS = { "Idle", "Locomotion", "Telegraph", "Attack" }
-- States that walk when the body moves. Delivery C adds walking to a noise and searching; suspicion stands still.
local WALKING = table.freeze({ Patrol = true, Hunt = true, Retreat = true, Investigate = true, Search = true })
local WARNING_SECONDS, STRIKE_POSE_SECONDS, ATTACK_SECONDS = 1.4, 0.23, 1
local LENGTHS = { Idle = 3, Locomotion = 2, Telegraph = WARNING_SECONDS, Attack = ATTACK_SECONDS }
local READINESS_TIMEOUT = 5
-- Dread pass (user: darker, scarier, barely seen): every art colour times `tint`, the eyes a pale Neon glow that
-- stays lit, and the unrevealed body a dark shape (alpha 0.5) the fog swallows, instead of the 0.86 ghost.
-- Look pass (user: "mucho más alto y tenebroso"): the dread look also bends the art's rest pose, a forward hunch of the
-- chest and neck (degrees about each bone's own X axis) and a longer neck and arms (each bone's offset from its parent
-- times the stretch). Animations play on top of the rest pose, so the clips keep their lengths and timing; the
-- template is never touched and a missing bone is skipped.
Visual.DREAD_LOOK = table.freeze({ tint = 0.35, eyes = Color3.fromRGB(214, 226, 200), hiddenAlpha = 0.5,
	revealedAlpha = 0.1, pose = table.freeze({
		pitch = table.freeze({ Chest = -16, Neck = -20 }),
		stretch = table.freeze({ Head = 1.35, ["Forearm.L"] = 1.3, ["Forearm.R"] = 1.3, ["Hand.L"] = 1.35,
			["Hand.R"] = 1.35 }),
	}) })
local DEFAULT_LOOK = table.freeze({ hiddenAlpha = 0.86, revealedAlpha = 0.25 })
-- Supported art scale (a ratio of the template's own scale). Look pass: the ceiling is 4.5 (was 3).
local MIN_SCALE, MAX_SCALE = 0.5, 4.5
-- Look pass: the horror grin shown while she hunts, warns and strikes (presentation only: no rule reads it).
-- Fix pass (FP1; Play finding: a camera-facing BillboardGui on a hard-coded mouth offset, pushed toward the camera, read
-- as a flat sticker floating off the face). The grin is now a SurfaceGui on the front face of a thin anchored
-- "HorrorJaw" part (no collision, query or touch) fitted to the art's own head geometry: the bounds of the art part
-- whose name carries "Head" (SiluetaV3_Head), `widthRatio` of its width, `heightRatio` of its height, its centre
-- `dropRatio` of the head's height under the head's centre, flush on the head's front face and turned with the head.
-- The jaw is locked to the Head bone (its offset is measured at the rest pose), so the hunch, the lean and every clip
-- carry it with the face; the art is a static pose, so one placement after the scale is enough, and step() refreshes
-- it from the bone's transformed frame whenever it shows. It ignores the light (LightInfluence 0) and glows faintly
-- (a dim red PointLight) in the night fog; trunks still hide it (AlwaysOnTop off). There is no camera-axis push. The
-- clients only animate its arrival (WildboundFear.client.luau, View.grinPop).
Visual.GRIN = table.freeze({ widthRatio = 1.35, heightRatio = 0.42, dropRatio = 0.2, depth = 0.02, maxDistance = 90,
	brightness = 2, glow = 0.6, pixelsPerStud = 60, upperTeeth = 22, lowerTeeth = 20, slices = 36,
	states = table.freeze({ Hunt = true, Telegraph = true, Attack = true }) })
-- Fix pass (FP1, framing): with the default third-person camera the giant's face sat above the frame at chase range.
-- While she hunts she leans toward her quarry: the chest and the neck pitch forward (shares of the lean) toward the
-- quarry's position, capped at `max` degrees, eased in and out at `ease` per second, on top of the dread pose and under
-- the clips. The player camera is never touched; the gameplay body, sight and reach never read it.
Visual.LEAN = table.freeze({ max = 25, ease = 4, shares = table.freeze({ Chest = 0.4, Neck = 0.6 }) })
local TOOTH = Color3.fromRGB(245, 240, 215)
local MOUTH = Color3.fromRGB(120, 6, 14)
local LENGTH_TOLERANCE = 1 / 30 + 0.000001 -- One authored frame, plus floating-point error.

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function validTemplate(template)
	if typeof(template) ~= "Instance" or not template:IsA("Model") then return false end
	local parts, bones = 0, 0
	for _, item in ipairs(template:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Humanoid") then return false end
		if item:IsA("BasePart") then parts += 1 end
		if item:IsA("Bone") then bones += 1 end
	end
	return parts > 0 and bones > 0
end

local function validScale(factor)
	return finite(factor) and factor >= MIN_SCALE and factor <= MAX_SCALE
end

-- Normalized grin curves (x and y from 0 to 1 across the Face): u runs -1 to 1 between the corners.
local function lipTop(u) return 0.28 + 0.22 * (1 - u * u) end
local function lipBottom(u) return 0.34 + 0.52 * (1 - u * u) end
local ASPECT = Visual.GRIN.heightRatio / Visual.GRIN.widthRatio

local function frame(parent, name, color, position, size, anchor, rotation)
	local item = Instance.new("Frame")
	item.Name, item.BackgroundColor3, item.BorderSizePixel = name, color, 0
	item.Position, item.Size, item.AnchorPoint, item.Rotation = position, size, anchor, rotation or 0
	item.Parent = parent
	return item
end

-- The jaw part and its grin. The caller sizes and places the part (fitJaw).
local function buildGrin()
	local G = Visual.GRIN
	local jaw = Instance.new("Part")
	jaw.Name, jaw.Anchored, jaw.CanCollide, jaw.CanTouch, jaw.CanQuery = "HorrorJaw", true, false, false, false
	jaw.Transparency, jaw.CastShadow, jaw.Massless = 1, false, true
	local glow = Instance.new("PointLight")
	glow.Name, glow.Color, glow.Brightness, glow.Shadows, glow.Enabled = "Glow", MOUTH, G.glow, false, false
	glow.Parent = jaw
	local grin = Instance.new("SurfaceGui")
	grin.Name, grin.Enabled, grin.LightInfluence, grin.Brightness = "HorrorGrin", false, 0, G.brightness
	grin.Face, grin.AlwaysOnTop, grin.MaxDistance, grin.ResetOnSpawn = Enum.NormalId.Front, false, G.maxDistance, false
	grin.SizingMode, grin.PixelsPerStud, grin.ClipsDescendants = Enum.SurfaceGuiSizingMode.PixelsPerStud, G.pixelsPerStud, false
	grin.Parent = jaw
	local face = Instance.new("CanvasGroup")
	face.Name, face.Size, face.BackgroundTransparency = "Face", UDim2.fromScale(1, 1), 1
	face.Parent = grin
	local pop = Instance.new("UIScale")
	pop.Name, pop.Parent = "Pop", face
	-- The mouth: thin dark-red slices between the two lips, so the corners meet in a crescent.
	for index = 1, G.slices do
		local u = (index - 0.5) / G.slices * 2 - 1
		local x = 0.04 + (u + 1) / 2 * 0.92
		frame(face, "Mouth", MOUTH, UDim2.fromScale(x, lipTop(u)),
			UDim2.fromScale(0.92 / G.slices * 1.15, lipBottom(u) - lipTop(u)), Vector2.new(0.5, 0))
	end
	-- Too many thin teeth, longest in the middle, each turned with its lip.
	local function row(count, lip, slope, anchorY, longest, shortest)
		local width = 0.84 / count * 0.72
		for index = 1, count do
			local u = ((index - 0.5) / count * 2 - 1) * 0.92
			local x = 0.04 + (u + 1) / 2 * 0.92
			local length = shortest + (longest - shortest) * (1 - u * u)
			local angle = math.deg(math.atan(slope(u) / 0.46 * ASPECT))
			local tooth = frame(face, "Tooth", TOOTH, UDim2.fromScale(x, lip(u)), UDim2.fromScale(width, length),
				Vector2.new(0.5, anchorY), angle)
			local round = Instance.new("UICorner")
			round.CornerRadius, round.Parent = UDim.new(0.5, 0), tooth
		end
	end
	row(G.upperTeeth, lipTop, function(u) return -0.44 * u end, 0, 0.2, 0.08)
	row(G.lowerTeeth, lipBottom, function(u) return -1.04 * u end, 1, 0.16, 0.06)
	return grin, jaw
end

-- The head geometry the jaw is fitted to: the largest BasePart under `root` whose name carries "Head" (the gameplay
-- head itself without art). Returns its CFrame and size, or nil.
local function headGeometry(root)
	local best, volume
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") and item.Name:find("Head", 1, true) and item.Name ~= "HorrorJaw" then
			local size = item.Size
			local v = size.X * size.Y * size.Z
			if not volume or v > volume then best, volume = item, v end
		end
	end
	if root:IsA("BasePart") and not best then best = root end
	return best
end

-- Sizes the jaw from the head's bounds and places it flush on the head's front face, turned with the head. Returns
-- the jaw's CFrame, so the caller can lock it to a bone.
local function fitJaw(jaw, head, scale)
	local G = Visual.GRIN
	local size = head.Size
	local depth = math.max(0.05, G.depth * scale)
	jaw.Size = Vector3.new(size.X * G.widthRatio, size.Y * G.heightRatio, depth)
	jaw.CFrame = head.CFrame * CFrame.new(0, -size.Y * G.dropRatio, -(size.Z / 2 + depth / 2))
	local glow = jaw:FindFirstChild("Glow")
	if glow then glow.Range = jaw.Size.X * 1.5 end
	return jaw.CFrame
end

-- Places the jaw from the head bone's transformed frame (the pose, the lean and any clip), or leaves a static fit.
function Visual:_placeJaw()
	local bone, jaw, offset = self._headBone, self._jaw, self._jawLocal
	if not jaw or not bone or not offset or not bone.Parent then return end
	jaw.CFrame = bone.TransformedWorldCFrame * offset
end

local function animationId(value)
	return type(value) == "string" and value:match("^rbxassetid://[1-9]%d*$") ~= nil
end

function Visual:_discardTracks()
	for _, track in pairs(self._tracks) do
		pcall(function() track:Stop(0) end)
		pcall(function() track:Destroy() end)
	end
	table.clear(self._tracks)
	for _, animation in ipairs(self._animations) do animation:Destroy() end
	table.clear(self._animations)
	self._readinessDeadline = nil
	self.animationReady = false
	self._active = nil
end

function Visual:_checkTrackReadiness(now)
	self._readinessDeadline = self._readinessDeadline or now + READINESS_TIMEOUT
	if now >= self._readinessDeadline then
		self:_discardTracks()
		self.reason = "StaticArtAnimationLoadTimedOut"
		return false
	end
	local allLoaded = true
	for _, name in ipairs(ACTIONS) do
		local ok, length = pcall(function() return self._tracks[name].Length end)
		if ok and length == 0 then
			allLoaded = false
		elseif not ok or not finite(length) or math.abs(length - LENGTHS[name]) > LENGTH_TOLERANCE then
			self:_discardTracks()
			self.reason = "StaticArtAnimationLengthMismatch"
			return false
		end
	end
	if allLoaded then
		self.animationReady, self.reason = true, "TracksReady"
		self._readinessDeadline = nil
	end
	return allLoaded
end

function Visual.new(options)
	local self = setmetatable({
		artReady = false, animationReady = false, reason = "MissingOrInvalidTemplate",
		_body = options.body, _head = options.head, _clock = options.clock or function()
			return workspace:GetServerTimeNow()
		end,
		_baselines = {}, _tracks = {}, _animations = {}, _state = "Alert", _moving = false,
		_bodyAlpha = options.body.Transparency, _headAlpha = options.head.Transparency,
		_look = type(options.look) == "table" and options.look or DEFAULT_LOOK, _glowing = {},
		_lean = 0, _poseFrames = {},
	}, Visual)
	local startClock = self._clock()
	self._leanAt = finite(startClock) and startClock or nil
	local template = options.template
	local function plainGrin()
		-- No art: the jaw is fitted to the plain gameplay head and rides it, still presentation only.
		self._grin, self._jaw = buildGrin()
		fitJaw(self._jaw, options.head, 1)
		self._jaw.Parent = options.head
		return self
	end
	if not validTemplate(template) then return plainGrin() end
	local ok, art = pcall(function() return template:Clone() end)
	if not ok or not art then return plainGrin() end
	-- The verified template pivot is its feet origin. Never change the gameplay PrimaryPart.
	ok = pcall(function()
		art.Name = "SiluetaVisual"
		local factor = options.visualScale
		if not validScale(factor) then factor = 1 end
		local look = self._look
		self._baseScale, self._scale = art:GetScale(), factor
		art:ScaleTo(self._baseScale * factor)
		art:PivotTo(options.body.CFrame * CFrame.new(0, -options.body.Size.Y / 2, 0))
		for _, item in ipairs(art:GetDescendants()) do
			if item:IsA("BasePart") then
				self._baselines[item] = item.Transparency
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
				if finite(look.tint) then
					if typeof(look.eyes) == "Color3" and item.Name:find("Eyes", 1, true) then
						item.Color, item.Material, self._glowing[item] = look.eyes, Enum.Material.Neon, true
					else
						local c = item.Color
						item.Color = Color3.new(c.R * look.tint, c.G * look.tint, c.B * look.tint)
					end
				end
			end
		end
		-- The jaw, fitted to the head geometry at the rest pose and locked to the head bone before the pose bends it, so
		-- the hunch, the lean and the clips carry it with the face.
		local head = headGeometry(art)
		local headBone = art:FindFirstChild("Head", true)
		if head then
			self._grin, self._jaw = buildGrin()
			local frame = fitJaw(self._jaw, head, factor)
			if headBone and headBone:IsA("Bone") then
				self._headBone, self._jawLocal = headBone, headBone.WorldCFrame:ToObjectSpace(frame)
			end
			self._jaw.Parent = art
		end
		if type(look.pose) == "table" then
			for name, degrees in pairs(look.pose.pitch or {}) do
				local bone = art:FindFirstChild(name, true)
				if bone and bone:IsA("Bone") and finite(degrees) then
					bone.CFrame = bone.CFrame * CFrame.Angles(math.rad(degrees), 0, 0)
				end
			end
			for name, stretch in pairs(look.pose.stretch or {}) do
				local bone = art:FindFirstChild(name, true)
				if bone and bone:IsA("Bone") and finite(stretch) then bone.Position = bone.Position * stretch end
			end
		end
		-- The lean bends these on top of the pose; their posed frames are the rest it eases back to.
		for name in pairs(Visual.LEAN.shares) do
			local bone = art:FindFirstChild(name, true)
			if bone and bone:IsA("Bone") then self._poseFrames[bone] = bone.CFrame end
		end
		self:_placeJaw()
		art.Parent = options.guardian
	end)
	if not ok then
		art:Destroy(); table.clear(self._baselines); table.clear(self._poseFrames)
		self._grin, self._jaw, self._headBone, self._jawLocal = nil, nil, nil, nil
		return plainGrin()
	end
	self.art, self.artReady, self.reason = art, true, "StaticArtMissingAnimationIds"
	self:setRevealed(false)
	-- Validate the entire set before loading. Model upload is not animation publication.
	for _, name in ipairs(ACTIONS) do
		if not animationId(template:GetAttribute(name .. "AnimationId")) then return self end
	end
	local controller = art:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = art
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	local load = options.loadTrack or function(target, animation) return target:LoadAnimation(animation) end
	for _, name in ipairs(ACTIONS) do
		local animation = Instance.new("Animation")
		animation.Name, animation.AnimationId = name, template:GetAttribute(name .. "AnimationId")
		table.insert(self._animations, animation)
		local loaded, track = pcall(load, animator, animation)
		if not loaded or not track then
			self:_discardTracks()
			self.reason = "StaticArtAnimationLoadFailed"
			return self
		end
		self._tracks[name] = track
		track.Looped = name == "Idle" or name == "Locomotion"
		track.Priority = (name == "Telegraph" or name == "Attack")
			and Enum.AnimationPriority.Action or Enum.AnimationPriority.Movement
	end
	-- LoadAnimation can return before the asset resolves. Poll without yielding on the server.
	self.reason = "TracksPending"
	local now = self._clock()
	if finite(now) then self:_checkTrackReadiness(now) end
	return self
end

function Visual:setRevealed(revealed)
	if self._destroyed then return end
	if self.artReady then
		local look = self._look
		local alpha = revealed and look.revealedAlpha or look.hiddenAlpha
		for part, baseline in pairs(self._baselines) do
			part.Transparency = self._glowing[part] and baseline or baseline + (1 - baseline) * alpha
		end
		self._body.Transparency, self._head.Transparency = 1, 1
	else
		self._body.Transparency = revealed and 0.3 or self._bodyAlpha
		self._head.Transparency = revealed and 0.25 or self._headAlpha
	end
end

function Visual:_play(name, position)
	if not self.animationReady then return end
	local track = self._tracks[name]
	local ok = pcall(function()
		if self._active ~= name then
			if self._active then self._tracks[self._active]:Stop(0.08) end
			self._active = name
			track:Play(0.08, 1, 1)
		end
		-- Seek late updates instead of shifting the authoritative hit deadline or replaying a swing.
		if position then track.TimePosition = position end
	end)
	if not ok then
		self:_discardTracks()
		self.reason = "StaticArtAnimationPlaybackFailed"
	end
end

-- Live art scale (dev tuning, Silueta.VISUAL_SCALE): rescales the clone about its feet. Returns false for a value
-- outside 0.5 to 4.5, without art, or after destroy. The gameplay body, head and helpers never change.
function Visual:setScale(factor)
	if self._destroyed or not self.artReady or not validScale(factor) then return false end
	local ok = pcall(function()
		self.art:ScaleTo(self._baseScale * factor)
		self.art:PivotTo(self._body.CFrame * CFrame.new(0, -self._body.Size.Y / 2, 0))
	end)
	if not ok then return false end
	-- The jaw scaled with the art; its offset from the head bone scales the same way.
	if self._jawLocal then
		local ratio = factor / self._scale
		self._jawLocal = CFrame.new(self._jawLocal.Position * ratio) * self._jawLocal.Rotation
	end
	self._scale = factor
	self:_placeJaw()
	return true
end

function Visual:setMoving(moving)
	if not self._destroyed then self._moving = moving == true end
end

-- Fix pass (FP1): the quarry's position while she hunts it (nil otherwise). Presentation only: the lean toward it.
function Visual:setQuarry(position)
	if self._destroyed then return end
	self._quarry = typeof(position) == "Vector3" and finite(position.X) and finite(position.Y) and finite(position.Z)
		and position or nil
end

-- The lean toward the quarry, eased, and the jaw's place on the head. Runs every step, art or clips or neither.
function Visual:_stepPresentation(now)
	if not self.art then return end
	local dt = self._leanAt and math.max(0, now - self._leanAt) or 0
	self._leanAt = now
	local goal = 0
	local quarry = self._quarry
	local bone = self._headBone
	if quarry and bone and bone.Parent then
		local head = bone.TransformedWorldCFrame.Position
		local flat = math.max(0.1, Vector3.new(head.X - quarry.X, 0, head.Z - quarry.Z).Magnitude)
		goal = math.clamp(math.deg(math.atan2(head.Y - quarry.Y, flat)), 0, Visual.LEAN.max)
	end
	local lean = self._lean + (goal - self._lean) * math.min(1, dt * Visual.LEAN.ease)
	if math.abs(lean - goal) < 0.01 then lean = goal end
	if math.abs(lean - self._lean) > 0.001 then
		self._lean = lean
		for part, frame in pairs(self._poseFrames) do
			local share = Visual.LEAN.shares[part.Name] or 0
			if part.Parent then part.CFrame = frame * CFrame.Angles(math.rad(-lean * share), 0, 0) end
		end
	end
	if self._grin and (self._grin.Enabled or lean ~= 0) then self:_placeJaw() end
end

function Visual:setState(state, deadline, deferStep)
	if self._destroyed then return end
	if state == self._state and (state ~= "Telegraph" or deadline == self._deadline) then return end
	if self._grin then
		local shown = Visual.GRIN.states[state] == true
		self._grin.Enabled = shown
		local glow = self._jaw and self._jaw:FindFirstChild("Glow")
		if glow then glow.Enabled = shown end
		if shown then self:_placeJaw() end
	end
	-- Chase pass: a strike on a live quarry goes straight back to Hunt; the follow-through is kept there too.
	local preserve = (state == "Retreat" or state == "Hunt") and self._state == "Telegraph" and self._completed
	self._state = state
	if state == "Telegraph" and finite(deadline) and deadline > 0 then
		if self._active == "Telegraph" or self._active == "Attack" then
			self._tracks[self._active]:Stop(0.08)
			self._active = nil
		end
		self._deadline, self._completed = deadline, false
		self._attackStart = deadline - STRIKE_POSE_SECONDS
		self._attackEnd = self._attackStart + ATTACK_SECONDS
	elseif not preserve then
		self._deadline, self._completed, self._attackStart, self._attackEnd = nil, false, nil, nil
	end
	if not deferStep then self:step() end
end

function Visual:step()
	if self._destroyed then return end
	local now = self._clock()
	if not finite(now) then return end
	self:_stepPresentation(now)
	if not self.animationReady and self.reason ~= "TracksPending" then return end
	if not self.animationReady and not self:_checkTrackReadiness(now) then return end
	if self._state == "Telegraph" and self._deadline then
		if now >= self._attackEnd then
			self:_play("Idle")
		elseif now + 0.0000001 >= self._attackStart then
			self:_play("Attack", math.max(0, now - self._attackStart))
		else
			self:_play("Telegraph", math.clamp(now - (self._deadline - WARNING_SECONDS), 0, WARNING_SECONDS))
		end
	elseif self._completed and self._attackEnd and now < self._attackEnd then
		self:_play("Attack", math.max(0, now - self._attackStart))
	else
		self._completed = false
		local moving = self._moving and WALKING[self._state] == true
		self:_play(moving and "Locomotion" or "Idle")
	end
end

function Visual:finishTelegraph(validCompletion)
	if self._destroyed then return end
	local now = self._clock()
	self._completed = validCompletion == true and self._deadline ~= nil and finite(now)
		and now >= self._deadline and now < self._attackEnd
	if self._completed then
		self:step()
	else
		self._deadline, self._attackStart, self._attackEnd = nil, nil, nil
	end
end

function Visual:destroy()
	if self._destroyed then return end
	self._destroyed = true
	self._deadline, self._attackStart, self._attackEnd, self._completed = nil, nil, nil, false
	self:_discardTracks()
	if self._jaw then self._jaw:Destroy() end
	if self.art then self.art:Destroy() end
	table.clear(self._baselines)
	table.clear(self._poseFrames)
	self._grin, self._jaw, self._headBone, self._jawLocal, self._quarry = nil, nil, nil, nil, nil
	self._body.Transparency, self._head.Transparency = self._bodyAlpha, self._headAlpha
end

return Visual
