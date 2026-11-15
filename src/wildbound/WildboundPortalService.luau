-- CE3 / T08b (odd/tasks/wildbound-caramelo.md, odd/tasks/wildbound-2-0.md; pack 04_ENTORNO/03 "Portal"): the return
-- portal service. WildboundServer starts it with its alive and root checks and its notice path. It binds one server-side
-- ProximityPrompt per station in WildboundPortal.STATIONS: the Candy builder's arch (Candy_Bioma_v1.Portal, live while
-- its Enabled attribute is true) and a small arch it builds at runtime in the deep forest (the place file never needs
-- saving). Never trust the client: the prompt's server-side Triggered names only the player; the client sends nothing.
-- The server measures its own root against the station, notes threats from what the server itself wrote (La Silueta's
-- WildboundThreatLevel, the beasts' WildboundBeastEngagedAt stamp, WildboundBatHit, WildboundRagdollUntil, a health
-- drop, an awake nest parent within reach), runs the 2 s channel on its own clock at 10 Hz and moves the character onto
-- the player's own base pad (the hub spawn pad without a base). CG2 (decision 47): a player carrying an egg (the
-- server's deps.carrying) is refused, and a station switched off during the channel cuts it (F6).
-- The client (WildboundPortalClient) draws the channel bar from the "PortalEvent" remote and the wait on the prompt
-- from the WildboundPortalReadyAt attribute.
local Service = {}
Service.__index = Service

Service.PROMPT_DISTANCE = 8 -- studs; inside WildboundPortal.CONFIG.useRange so a prompt the client shows is always in range
Service.TICK = 0.1 -- seconds between two steps (threat sampling and the channel)
Service.PROMPT_TAG = "WildboundPortalPrompt"
Service.FOLDER = "WildboundPortals"

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Defaults for the live game; the suite passes every one of these as a fake.
local function liveDeps(deps)
	local CollectionService = game:GetService("CollectionService")
	deps.now = deps.now or function() return workspace:GetServerTimeNow() end
	deps.teleport = deps.teleport or function(player, frame)
		local character = player.Character
		if not character or not character:IsDescendantOf(workspace) then return false end
		character:PivotTo(frame)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.AssemblyLinearVelocity = Vector3.zero end
		return true
	end
	deps.bases = deps.bases or function()
		local list = {}
		for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do
			local pad = model:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") and model:IsDescendantOf(workspace) then
				table.insert(list, { ownerUserId = model:GetAttribute("OwnerUserId"), pad = pad })
			end
		end
		return list
	end
	deps.adults = deps.adults or function()
		local list = {}
		for _, model in ipairs(CollectionService:GetTagged("WildboundIslandAdult")) do
			if model:GetAttribute("Awake") == true and model:IsA("Model") and model:IsDescendantOf(workspace) then
				local p = model:GetPivot().Position
				table.insert(list, { x = p.X, z = p.Z })
			end
		end
		return list
	end
	-- Without the server's answer, the backpack the server welds to a carrier's character.
	deps.carrying = deps.carrying or function(player)
		local character = player.Character
		return character ~= nil and character:FindFirstChild("WildboundEggCarried") ~= nil
	end
	deps.health = deps.health or function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid and humanoid.Health or nil
	end
end

function Service.new(deps)
	assert(type(deps) == "table" and deps.Portal and deps.Text and deps.alive and deps.rootOf,
		"the portal service needs Portal, Text, alive and rootOf")
	liveDeps(deps)
	return setmetatable({
		deps = deps,
		Portal = deps.Portal,
		stations = {}, -- [id] = { id, position, enabled }
		states = {}, -- [player] = Portal.new()
		health = {}, -- [player] = the last sampled health
		fire = deps.fire,
	}, Service)
end

function Service:addStation(id, position, enabled)
	assert(type(id) == "string" and typeof(position) == "Vector3" and type(enabled) == "function", "station id, position, enabled")
	self.stations[id] = { id = id, position = position, enabled = enabled }
end

function Service:track(player)
	if player and not self.states[player] then self.states[player] = self.Portal.new() end
end

function Service:forget(player)
	self.states[player] = nil
	self.health[player] = nil
end

local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function send(self, player, payload)
	if self.fire then self.fire(player, payload) end
end

local function notify(self, player, ok, text)
	if self.deps.notify and type(text) == "string" then self.deps.notify(player, ok, text) end
end

-- The live root, or nil when the player cannot be moved now (no character, dead, defeated).
local function liveRoot(self, player)
	if not self.deps.alive(player) then return nil end
	local root = self.deps.rootOf(player)
	if root == nil or typeof(root.Position) ~= "Vector3" then return nil end
	return root
end

-- What the server knows about danger around this player (nothing here comes from the client).
function Service:signals(player, root)
	local health = self.deps.health(player)
	local last = self.health[player]
	self.health[player] = health
	local p = root.Position
	return {
		x = p.X, z = p.Z,
		siluetaLevel = player:GetAttribute("WildboundThreatLevel"),
		beastEngagedAt = player:GetAttribute("WildboundBeastEngagedAt"),
		batHitAt = player:GetAttribute("WildboundBatHit"),
		ragdollUntil = player:GetAttribute("WildboundRagdollUntil"),
		hurt = finite(health) and finite(last) and health <= last - self.Portal.CONFIG.hurtMin or false,
		adults = self.deps.adults(),
	}
end

-- Where the portal sends this player: just above the centre of their own base's Pad, facing the hub's centre; the
-- hub spawn pad when they have no base; nil when there is neither.
function Service:destination(player)
	for _, base in ipairs(self.deps.bases()) do
		local pad = base.pad
		if base.ownerUserId == player.UserId and typeof(pad) == "Instance" and pad:IsA("BasePart") then
			local top = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0)
			local hub = self.deps.hubCentre
			if typeof(hub) == "Vector3" then
				local target = Vector3.new(hub.X, top.Y, hub.Z)
				if (target - top).Magnitude > 0.1 then return CFrame.lookAt(top, target) end
			end
			return CFrame.new(top)
		end
	end
	local spawn = self.deps.spawnFrame and self.deps.spawnFrame(player) or nil
	return typeof(spawn) == "CFrame" and spawn or nil
end

local function refusalText(self, reason, st, now)
	local P, Portal = self.deps.Text.PORTAL, self.Portal
	if reason == "Cooldown" then return P.cooldown:format(math.max(1, math.ceil(Portal.cooldownLeft(st, now)))) end
	if reason == "Threat" then return P.threat:format(math.max(1, math.ceil(Portal.calmLeft(st, now)))) end
	return ({ Disabled = P.disabled, Dead = P.dead, TooFar = P.tooFar, Busy = P.busy, NoBase = P.noBase,
		Carrying = P.carrying })[reason] or P.dead
end

-- A prompt was used (the server's Triggered): the only input. Returns ok and the refusal reason.
function Service:trigger(player, id)
	local station = type(id) == "string" and self.stations[id] or nil
	if not station then return false, "Unknown" end
	local Portal, now = self.Portal, self.deps.now()
	local st = self.states[player]
	local root = st and liveRoot(self, player) or nil
	local ragdoll = player:GetAttribute("WildboundRagdollUntil")
	local ctx = { enabled = station.enabled() == true, alive = root ~= nil, station = id,
		ragdolled = finite(ragdoll) and ragdoll > now }
	if root then
		ctx.x, ctx.z = root.Position.X, root.Position.Z
		ctx.distance = flat(root.Position, station.position)
		ctx.hasDestination = self:destination(player) ~= nil
		ctx.carrying = self.deps.carrying(player) == true
	end
	local ok, reason
	if st then ok, reason = Portal.request(st, ctx, now) else ok, reason = false, ctx.enabled and "Dead" or "Disabled" end
	if ok then
		send(self, player, { kind = "Channel", station = id, seconds = Portal.CONFIG.channelSeconds,
			endsAt = st.channel.endsAt })
		notify(self, player, true, self.deps.Text.PORTAL.channel)
		return true
	end
	send(self, player, { kind = "Refused", reason = reason })
	notify(self, player, false, refusalText(self, reason, st, now))
	return false, reason
end

local CUT_TEXT = { Threat = "cutThreat", Moved = "cutMoved", Dead = "cutDead", Disabled = "cutDisabled", Carrying = "carrying" }

function Service:tick()
	local Portal, now = self.Portal, self.deps.now()
	for player, st in pairs(self.states) do
		local root = liveRoot(self, player)
		if root and Portal.threatened(self:signals(player, root), now) then Portal.noteThreat(st, now) end
		if st.channel then
			local station = self.stations[st.channel.station]
			local ctx = { alive = root ~= nil, enabled = station ~= nil and station.enabled() == true }
			if root and station then
				ctx.x, ctx.z = root.Position.X, root.Position.Z
				ctx.distance = flat(root.Position, station.position)
				ctx.carrying = self.deps.carrying(player) == true
			end
			local status, reason = Portal.step(st, ctx, now)
			if status == "Interrupted" then
				send(self, player, { kind = "Cut", reason = reason })
				notify(self, player, false, self.deps.Text.PORTAL[CUT_TEXT[reason] or "cutDead"])
			elseif status == "Ready" then
				local frame = self:destination(player)
				if frame and self.deps.teleport(player, frame) then
					Portal.complete(st, now)
					player:SetAttribute("WildboundPortalReadyAt", now + Portal.CONFIG.cooldown)
					send(self, player, { kind = "Arrived" })
					notify(self, player, true, self.deps.Text.PORTAL.arrived)
				else
					Portal.cancel(st)
					send(self, player, { kind = "Cut", reason = "NoBase" })
					notify(self, player, false, self.deps.Text.PORTAL.noBase)
				end
			end
		end
	end
end

local function prompt(parent, Text, id)
	local p = Instance.new("ProximityPrompt")
	p.Name = "PortalPrompt"
	p.ActionText = Text.PORTAL.prompt
	p.ObjectText = Text.PORTAL.names[id] or Text.PORTAL.object
	p.HoldDuration = 0
	p.MaxActivationDistance = Service.PROMPT_DISTANCE
	p.RequiresLineOfSight = false
	p:SetAttribute("PortalId", id)
	p.Parent = parent
	game:GetService("CollectionService"):AddTag(p, Service.PROMPT_TAG)
	return p
end

-- The forest station: a stone pad, two posts, a lintel and a faint violet ring with a small light; every part anchored,
-- only the posts collide. The prompt (words from Text.PORTAL) hangs from an attachment 3 studs over the pad. Returns the
-- model.
function Service.buildStation(spec, parent, Text)
	local model = Instance.new("Model")
	model.Name = "WildboundPortal_" .. spec.id
	model:SetAttribute("PortalId", spec.id)
	model:SetAttribute("Enabled", true)
	model:SetAttribute("Leads", "base")
	local base = CFrame.new(spec.x, spec.y or 1, spec.z) * CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
	local stone, glow = Color3.fromRGB(86, 82, 96), Color3.fromRGB(170, 120, 255)
	local function part(name, size, frame, color, material, collide, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = frame
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = collide
		p.CanTouch = false
		p.CastShadow = collide
		if shape then p.Shape = shape end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local pad = part("Pad", Vector3.new(0.4, 10, 10), base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), stone,
		Enum.Material.Slate, false, Enum.PartType.Cylinder)
	part("PostLeft", Vector3.new(1.6, 9, 1.6), base * CFrame.new(0, 4.5, -4.6), stone, Enum.Material.Slate, true)
	part("PostRight", Vector3.new(1.6, 9, 1.6), base * CFrame.new(0, 4.5, 4.6), stone, Enum.Material.Slate, true)
	part("Lintel", Vector3.new(1.8, 1.4, 11), base * CFrame.new(0, 9.5, 0), stone, Enum.Material.Slate, false)
	local ring = part("Ring", Vector3.new(0.3, 7.5, 7.5), base * CFrame.new(0, 4.6, 0), glow, Enum.Material.Neon, false,
		Enum.PartType.Cylinder)
	ring.Transparency = 0.55
	ring.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = glow, 12, 0.8, false
	light.Parent = ring
	model.PrimaryPart = pad
	local holder = Instance.new("Attachment")
	holder.Name = "PromptAttachment"
	holder.Parent = pad
	holder.WorldPosition = pad.Position + Vector3.new(0, 3, 0)
	prompt(holder, Text, spec.id)
	model.Parent = parent
	return model
end

-- Live wiring: the remote, both stations, players in and out, and the 10 Hz step.
function Service:start(network, root)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Text, Portal = self.deps.Text, self.Portal
	local remote = network:FindFirstChild("PortalEvent")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "PortalEvent"
		remote.Parent = network
	end
	self.fire = self.fire or function(player, payload) remote:FireClient(player, payload) end
	local folder = root:FindFirstChild(Service.FOLDER)
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = Service.FOLDER
	folder.Parent = root
	for _, spec in ipairs(Portal.STATIONS) do
		local p, position, enabled = nil, nil, nil
		if spec.source == "build" then
			local model = Service.buildStation(spec, folder, Text)
			p = model:FindFirstChildWhichIsA("ProximityPrompt", true)
			position = model.PrimaryPart.Position
			enabled = function() return model.Parent ~= nil and model:GetAttribute("Enabled") == true end
		elseif spec.source == "candy" then
			local biome = root:FindFirstChild("Candy_Bioma_v1")
			local model = biome and biome:FindFirstChild("Portal")
			if model and model:IsA("Model") then
				local pivot = model:GetPivot().Position
				if math.abs(pivot.X - spec.x) <= 2 and math.abs(pivot.Z - spec.z) <= 2 then
					local anchor = model:FindFirstChild("ReturnRing") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
					if anchor then
						local holder = anchor:FindFirstChild("PortalPromptAttachment") or Instance.new("Attachment")
						holder.Name = "PortalPromptAttachment"
						holder.Parent = anchor
						holder.WorldPosition = Vector3.new(spec.x, pivot.Y + 3, spec.z)
						local old = holder:FindFirstChild("PortalPrompt")
						if old then old:Destroy() end
						p = prompt(holder, Text, spec.id)
						position = Vector3.new(spec.x, pivot.Y, spec.z)
						enabled = function() return model.Parent ~= nil and model:GetAttribute("Enabled") == true end
					end
				else
					warn(("Wildbound portals: Candy_Bioma_v1.Portal is not at (%d, %d); no Caramelo portal."):format(spec.x, spec.z))
				end
			end
		end
		if p and position then
			self:addStation(spec.id, position, enabled)
			local id = spec.id
			p.Triggered:Connect(function(player) self:trigger(player, id) end)
		end
	end
	Players.PlayerAdded:Connect(function(player) self:track(player) end)
	Players.PlayerRemoving:Connect(function(player) self:forget(player) end)
	for _, player in ipairs(Players:GetPlayers()) do self:track(player) end
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < Service.TICK then return end
		clock = 0
		local ok, message = pcall(self.tick, self)
		if not ok then warn("Wildbound portals: step error: " .. tostring(message)) end
	end)
	-- Studio only, server only (ServerStorage, never a remote): the Play check's stand-in for a used prompt. It calls the
	-- same trigger the prompt's Triggered does, so every server check still runs.
	if RunService:IsStudio() then
		local ServerStorage = game:GetService("ServerStorage")
		local old = ServerStorage:FindFirstChild("PortalProbe")
		if old then old:Destroy() end
		local probe = Instance.new("BindableFunction")
		probe.Name = "PortalProbe"
		probe.OnInvoke = function(player, id)
			if type(player) == "number" then player = Players:GetPlayerByUserId(player) end
			if typeof(player) ~= "Instance" or not player:IsA("Player") then return false, "BadArguments" end
			return self:trigger(player, id)
		end
		probe.Parent = ServerStorage
	end
	return self
end

return Service
