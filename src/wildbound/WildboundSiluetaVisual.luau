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
-- Look pass: the horror grin shown while she hunts, warns and strikes (presentation only: no rule reads it). Sizes are
-- studs at art scale 1 and grow with the art: wider than the head, a little under the eyes, pushed toward the camera so
-- the head never hides it. It ignores the light (LightInfluence 0) to glow faintly in the night fog; trunks still hide
-- it (AlwaysOnTop off). The clients only animate its arrival (WildboundFear.client.luau, View.grinPop).
Visual.GRIN = table.freeze({ width = 1.7, height = 0.74, drop = -0.18, forward = 0.7, maxDistance = 90,
	brightness = 1.5, upperTeeth = 22, lowerTeeth = 20, slices = 36,
	states = table.freeze({ Hunt = true, Telegraph = true, Attack = true }) })
local TOOTH = Color3.fromRGB(232, 226, 196)
local MOUTH = Color3.fromRGB(58, 0, 8)
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
local ASPECT = Visual.GRIN.height / Visual.GRIN.width

local function frame(parent, name, color, position, size, anchor, rotation)
	local item = Instance.new("Frame")
	item.Name, item.BackgroundColor3, item.BorderSizePixel = name, color, 0
	item.Position, item.Size, item.AnchorPoint, item.Rotation = position, size, anchor, rotation or 0
	item.Parent = parent
	return item
end

local function buildGrin()
	local G = Visual.GRIN
	local grin = Instance.new("BillboardGui")
	grin.Name, grin.Enabled, grin.LightInfluence, grin.Brightness = "HorrorGrin", false, 0, G.brightness
	grin.AlwaysOnTop, grin.MaxDistance, grin.ClipsDescendants, grin.ResetOnSpawn = false, G.maxDistance, false, false
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
	return grin
end

function Visual:_sizeGrin(factor)
	local G = Visual.GRIN
	if not self._grin then return end
	self._grin.Size = UDim2.new(G.width * factor, 0, G.height * factor, 0)
	self._grin.StudsOffset = Vector3.new(0, G.drop * factor, G.forward * factor)
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
	}, Visual)
	local template = options.template
	local function plainGrin()
		-- No art: the grin rides the plain gameplay head, still presentation only.
		self._grin = buildGrin()
		self._grin.Adornee = options.head
		self:_sizeGrin(1)
		self._grin.Parent = options.head
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
		art.Parent = options.guardian
	end)
	if not ok then art:Destroy(); table.clear(self._baselines); return plainGrin() end
	self.art, self.artReady, self.reason = art, true, "StaticArtMissingAnimationIds"
	self:setRevealed(false)
	-- The grin rides the animated head bone (or the head mesh when a rig has no such bone).
	local head = art:FindFirstChild("Head", true)
	if not (head and head:IsA("Bone")) then
		head = nil
		for _, item in ipairs(art:GetDescendants()) do
			if item:IsA("BasePart") and item.Name:find("Head", 1, true) then head = item break end
		end
	end
	if head then
		self._grin = buildGrin()
		self._grin.Adornee = head
		self:_sizeGrin(self._scale)
		self._grin.Parent = art
	end
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
	self._scale = factor
	self:_sizeGrin(factor)
	return true
end

function Visual:setMoving(moving)
	if not self._destroyed then self._moving = moving == true end
end

function Visual:setState(state, deadline, deferStep)
	if self._destroyed then return end
	if state == self._state and (state ~= "Telegraph" or deadline == self._deadline) then return end
	if self._grin then self._grin.Enabled = Visual.GRIN.states[state] == true end
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
	if self._destroyed or (not self.animationReady and self.reason ~= "TracksPending") then return end
	local now = self._clock()
	if not finite(now) then return end
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
	if self._grin then self._grin:Destroy() end
	if self.art then self.art:Destroy() end
	table.clear(self._baselines)
	self._body.Transparency, self._head.Transparency = self._bodyAlpha, self._headAlpha
end

return Visual
