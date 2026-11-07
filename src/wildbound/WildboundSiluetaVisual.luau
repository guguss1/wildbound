-- Optional server-owned art presentation. This module never decides or applies damage.
local Visual = {}
Visual.__index = Visual

local ACTIONS = { "Idle", "Locomotion", "Telegraph", "Attack" }
-- States that walk when the body moves. Delivery C adds walking to a noise and searching; suspicion stands still.
local WALKING = table.freeze({ Patrol = true, Hunt = true, Retreat = true, Investigate = true, Search = true })
local WARNING_SECONDS, STRIKE_POSE_SECONDS, ATTACK_SECONDS = 1.4, 0.23, 1
local LENGTHS = { Idle = 3, Locomotion = 2, Telegraph = WARNING_SECONDS, Attack = ATTACK_SECONDS }
local READINESS_TIMEOUT = 5
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
	}, Visual)
	local template = options.template
	if not validTemplate(template) then return self end
	local ok, art = pcall(function() return template:Clone() end)
	if not ok or not art then return self end
	-- The verified template pivot is its feet origin. Never change the gameplay PrimaryPart.
	ok = pcall(function()
		art.Name = "SiluetaVisual"
		local factor = options.visualScale
		if not finite(factor) or factor < 0.5 or factor > 2 then factor = 1 end
		art:ScaleTo(art:GetScale() * factor)
		art:PivotTo(options.body.CFrame * CFrame.new(0, -options.body.Size.Y / 2, 0))
		for _, item in ipairs(art:GetDescendants()) do
			if item:IsA("BasePart") then
				self._baselines[item] = item.Transparency
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
			end
		end
		art.Parent = options.guardian
	end)
	if not ok then art:Destroy(); table.clear(self._baselines); return self end
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
		for part, baseline in pairs(self._baselines) do
			part.Transparency = baseline + (1 - baseline) * (revealed and 0.25 or 0.86)
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

function Visual:setMoving(moving)
	if not self._destroyed then self._moving = moving == true end
end

function Visual:setState(state, deadline, deferStep)
	if self._destroyed then return end
	if state == self._state and (state ~= "Telegraph" or deadline == self._deadline) then return end
	local preserve = state == "Retreat" and self._state == "Telegraph" and self._completed
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
	if self.art then self.art:Destroy() end
	table.clear(self._baselines)
	self._body.Transparency, self._head.Transparency = self._bodyAlpha, self._headAlpha
end

return Visual
