-- Caramelo ambience (owner request 2026-11-16: "music, sparkles, lights, so it feels more alive"). Client-only
-- decoration of the Caramelo plot (Workspace.Candy_Bioma_v1, in big4 and in classic), made at runtime while the local
-- player is in or near it (WildboundCandyAmbience.inside, with hysteresis) and removed when they leave:
--   lights   soft coloured PointLights (no shadows) on the nearest lollipop heads, gumdrops, nests (warm), the Gran
--            Torta's tier rims (a slow colour cycle) and the portal, re-picked at 2 Hz from the camera;
--   sparkles ParticleEmitters with the default particle look: sugar glitter on lollipops, gumdrops, cotton and sweet
--            trees, a twinkle on nests holding a candy egg, a shimmer on the syrup lake and sugar fireflies around the
--            camera, under one particles-per-second budget;
--   motion   a gentle side-to-side sway of the nearest lollipops about the stick's foot (only their non-colliding,
--            non-queried decoration meshes, never the collision stick; set back exactly on release);
--   music    the local WildboundWorldUI attribute CandyAmbience, which WildboundAudioClient turns into the Caramelo
--            bed through WildboundAudioMix (it ducks under danger there).
-- Budgets come from WildboundCandyAmbience.budget: fewer on touch devices, and with Efectos suaves (the world gui's
-- Reduced) only a few steady lights. Props are discovered from the instances (folders may be missing or stream in
-- late), never from positions; nothing named SistemaSonriente is touched. Nothing is sent to the server and nothing
-- replicates: every helper lives in one folder under the camera. Driven by Heartbeat (the per-render step did not fire
-- in Studio Play).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Ambience = require(ReplicatedStorage:WaitForChild("WildboundCandyAmbience"))
local function optional(name, read)
	local found = ReplicatedStorage:WaitForChild(name, 10)
	local ok, value = pcall(function() return found and read(require(found)) end)
	return ok and value or nil
end
local fallbackBounds = Ambience.fallbackBounds(optional("WildboundBiomeLight", function(module) return module end))
local eggTag = optional("WildboundCandyEggArt", function(module) return module.BOB_TAG end)

local player = Players.LocalPlayer
local RIM_POINTS = 4 -- light spots around each Gran Torta tier's rim
local SWAY_PARTS = { "StickA", "StickB", "DiscA", "DiscB", "Hub" } -- decoration meshes; Collision_* never moves

local biome = nil
local floorBounds = nil
local candidates, dirty = {}, true
local watched = {} -- [container] = { connections }
local inCandy = false
local budget = Ambience.budget(false, false)
local holder, anchor, fireflies = nil, nil, nil
local lights, emitters, sways = {}, {}, {}
local connections = {}

local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local function allowed(item)
	return item.Name ~= Ambience.FORBIDDEN and item:FindFirstAncestor(Ambience.FORBIDDEN) == nil
end
local function worldGui()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end
local function setFlag(on)
	local gui = worldGui()
	if gui and gui:GetAttribute(Ambience.GUI_ATTRIBUTE) ~= on then gui:SetAttribute(Ambience.GUI_ATTRIBUTE, on) end
end

-- Discovery ---------------------------------------------------------------------------------------------------
local function markDirty() dirty = true end
local function watch(container)
	if watched[container] then return end
	watched[container] = { container.ChildAdded:Connect(markDirty), container.ChildRemoved:Connect(markDirty) }
end
local function unwatchGone()
	for container, list in pairs(watched) do
		if container.Parent == nil then
			for _, connection in ipairs(list) do connection:Disconnect() end
			watched[container] = nil
		end
	end
end

-- A descriptor per decorated spot: kind, the model (or part) it follows, the piece it sits on and a lift in studs.
local function collect(name, container, add)
	if name == "GranTorta" then
		for _, tier in ipairs(container:GetChildren()) do
			if tier:IsA("BasePart") and string.sub(tier.Name, 1, 14) == "Collision_Tier" and allowed(tier) then
				for k = 1, RIM_POINTS do add({ id = "cake:" .. tier.Name .. ":" .. k, kind = "cake", tier = tier, rim = k }) end
			end
		end
		return
	end
	if name == "Portal" then
		add({ id = "portal:" .. container.Name, kind = "portal", model = container, piece = "ReturnRing", lift = 5 })
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if allowed(child) then
			local childName = child.Name
			if name == "Lake" then
				if child:IsA("BasePart") and string.sub(childName, 1, 6) == "Syrup_" then
					add({ id = "lake:" .. childName, kind = "lake", part = child })
				end
			elseif child:IsA("Model") then
				if name == "Lollipops" or (name == "Entrance" and string.sub(childName, 1, 13) == "GiantLollipop") then
					add({ id = "lollipop:" .. childName, kind = "lollipop", model = child, piece = "Hub", lift = 0.3 })
				elseif name == "CottonTrees" then
					add({ id = "cotton:" .. childName, kind = "cotton", model = child, piece = "CrownA", lift = 0.5 })
				elseif name == "Gumdrops" then
					add({ id = "gumdrop:" .. childName, kind = "gumdrop", model = child, piece = "DropsA", lift = 0.3 })
				elseif name == "Nests" then
					add({ id = "nest:" .. childName, kind = "nest", model = child, lift = 3, nest = true })
				elseif name == "Sweets" then
					local piece = string.sub(childName, 1, 9) == "TreeCream" and "Cherry"
						or (string.sub(childName, 1, 10) == "TreeCookie" and "Crown")
						or (string.sub(childName, 1, 13) == "CreamMushroom" and "Cap") or nil
					if piece then add({ id = "sweet:" .. childName, kind = "sweet", model = child, piece = piece, lift = 0.3 }) end
				end
			end
		end
	end
end

local function rebuild()
	dirty = false
	candidates = {}
	unwatchGone()
	if not biome or biome.Parent == nil then return end
	watch(biome)
	local seen = {}
	local function add(c)
		seen[c.id] = (seen[c.id] or 0) + 1
		if seen[c.id] > 1 then c.id ..= "#" .. seen[c.id] end
		table.insert(candidates, c)
	end
	for _, name in ipairs(Ambience.FOLDERS) do
		local container = biome:FindFirstChild(name)
		if container and allowed(container) then
			watch(container)
			collect(name, container, add)
		end
	end
end

-- Where a descriptor's spot is now (props may move or grow later), or nil when it is not streamed in.
local function locate(c)
	if c.tier then
		local tier = c.tier
		if tier.Parent == nil then return nil end
		local axis = tier.CFrame.RightVector -- an upright cylinder's axis is its X
		if axis.Y < 0 then axis = -axis end
		local top = tier.Position + axis * (tier.Size.X / 2)
		local radius = math.max(math.max(tier.Size.Y, tier.Size.Z) / 2 - 1, 0)
		local angle = (c.rim - 0.5) * 2 * math.pi / RIM_POINTS
		return top + Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
	end
	if c.part then return c.part.Parent and c.part.Position + Vector3.new(0, 0.3, 0) or nil end
	local model = c.model
	if model.Parent == nil then return nil end
	local piece = c.piece and model:FindFirstChild(c.piece)
	if piece and piece:IsA("BasePart") then
		-- above the piece's top (its world half height), so sparkles never start inside an opaque crown or disc
		local cf, half = piece.CFrame, piece.Size / 2
		local top = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
		return piece.Position + Vector3.new(0, top + (c.lift or 0), 0)
	end
	-- a piece that has not streamed in yet: skip, never drop the effect to the model's foot
	if c.piece then return nil end
	local ok, pivot = pcall(model.GetPivot, model)
	return ok and pivot.Position + Vector3.new(0, c.lift or 0, 0) or nil
end

local function plotBounds()
	if not floorBounds and biome then
		local ground = biome:FindFirstChild("Ground")
		local floor = ground and ground:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			floorBounds = Ambience.boundsFromFloor(floor.Position.X, floor.Position.Z, floor.Size.X, floor.Size.Z)
		end
	end
	return floorBounds or fallbackBounds
end

-- Helpers -----------------------------------------------------------------------------------------------------
local function helperPart(name, size, cframe)
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, cframe
	part.Anchored, part.Transparency, part.Massless = true, 1, true
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	return part
end

local function ensureHolder()
	if holder and holder.Parent then return end
	if holder then holder:Destroy() end
	holder = Instance.new("Folder")
	holder.Name = "WildboundCandyAmbience"
	anchor = helperPart("Anchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new())
	anchor.Parent = holder
	holder.Parent = workspace.CurrentCamera or workspace
	lights, emitters, fireflies = {}, {}, nil
end

local function newEmitter(styleName, colorName, parent)
	local style = Ambience.STYLES[styleName]
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(Ambience.PALETTE[colorName] or Ambience.PALETTE.lemon))
	emitter.LightEmission, emitter.LightInfluence = style.emission, 0
	emitter.Lifetime = NumberRange.new(style.lifetime[1], style.lifetime[2])
	emitter.Speed = NumberRange.new(style.speed[1], style.speed[2])
	emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
	emitter.Acceleration = Vector3.new(0, style.rise, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, style.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	emitter.Rotation, emitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
	emitter.Brightness = style.brightness or 1
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function newLight(rec)
	local spec = Ambience.KINDS[rec.kind].light
	local attachment = Instance.new("Attachment")
	attachment.Name = "Light"
	attachment.Parent = anchor
	attachment.WorldPosition = rec.pos
	local light = Instance.new("PointLight")
	light.Shadows = false
	light.Range = math.min(spec.range, Ambience.MAX_RANGE)
	light.Brightness = spec.brightness
	light.Color = rgb(Ambience.color(rec.kind, rec.id))
	light.Parent = attachment
	return { kind = rec.kind, id = rec.id, spec = spec, attachment = attachment, light = light,
		phase = Ambience.phase(rec.id, Ambience.PULSE_PERIOD) }
end

local function newSparkle(rec)
	local spec = Ambience.KINDS[rec.kind].sparkle
	local node
	if Ambience.STYLES[spec.style].area and rec.c.part then
		local source = rec.c.part
		local width = math.min(math.max(source.Size.Y, source.Size.Z), 40)
		node = helperPart("Shimmer", Vector3.new(width, 0.4, width), CFrame.new(rec.pos))
		node.Parent = holder
	else
		node = Instance.new("Attachment")
		node.Name = "Sparkle"
		node.Parent = anchor
		node.WorldPosition = rec.pos
	end
	return { kind = rec.kind, node = node, emitter = newEmitter(spec.style, spec.color or Ambience.colorName(rec.kind, rec.id), node) }
end

local function moveNode(node, pos)
	if node:IsA("BasePart") then node.CFrame = CFrame.new(pos) else node.WorldPosition = pos end
end

-- A lollipop's sway: its stick and head lean side to side about the stick's foot (the model's pivot), in the plane the
-- disc faces. Only anchored pure-decoration parts (no collision, touch or ray query) ever move; the invisible
-- Collision_ stick stays where it is.
local function newSway(rec)
	local model = rec.c.model
	local disc = model and model:FindFirstChild("DiscA")
	if not (disc and disc:IsA("BasePart")) then return nil end
	local okPivot, pivot = pcall(model.GetPivot, model)
	if not okPivot then return nil end
	local parts = {}
	for _, name in ipairs(SWAY_PARTS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") and part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch then
			table.insert(parts, { part = part, base = part.CFrame })
		end
	end
	if #parts == 0 then return nil end
	local axisName = Ambience.thinAxis(disc.Size.X, disc.Size.Y, disc.Size.Z)
	local frame = disc.CFrame
	local normal = axisName == "X" and frame.RightVector or (axisName == "Y" and frame.UpVector or frame.LookVector)
	local ax, az = Ambience.swayAxis(normal.X, normal.Y, normal.Z)
	if not ax then return nil end
	return { kind = rec.kind, parts = parts, foot = pivot.Position, axis = Vector3.new(ax, 0, az),
		phase = Ambience.phase(rec.id, Ambience.SWAY_PERIOD) }
end

local function restoreSway(entry)
	for _, item in ipairs(entry.parts) do
		if item.part.Parent then item.part.CFrame = item.base end
	end
end

-- One store per effect: drop what is no longer picked (or changed kind), keep and move the rest, make the new ones.
local function reconcile(store, picks, make, keep, drop)
	local wanted = {}
	for _, rec in ipairs(picks) do wanted[rec.id] = rec end
	for id, entry in pairs(store) do
		local rec = wanted[id]
		if not rec or rec.kind ~= entry.kind then
			drop(entry)
			store[id] = nil
		end
	end
	for _, rec in ipairs(picks) do
		local entry = store[rec.id]
		if entry then keep(entry, rec) else store[rec.id] = make(rec) end
	end
end

local function teardown()
	for id, entry in pairs(sways) do
		restoreSway(entry)
		sways[id] = nil
	end
	if holder then holder:Destroy() end
	holder, anchor, fireflies = nil, nil, nil
	lights, emitters = {}, {}
end

-- The 2 Hz step: in or out, the budget, then the nearest props for each effect.
local function refresh()
	if not biome or biome.Parent == nil then
		biome, floorBounds, dirty = workspace:FindFirstChild(Ambience.ROOT_NAME), nil, true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local at = root and root.Position or (camera and camera.Focus.Position)
	inCandy = biome ~= nil and at ~= nil and Ambience.inside(inCandy, plotBounds(), at.X, at.Z)
	setFlag(inCandy)
	if not inCandy then
		teardown()
		return
	end
	local gui = worldGui()
	local soft = gui ~= nil and gui:GetAttribute("Reduced") == true
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	budget = Ambience.budget(touch, soft)
	ensureHolder()
	if dirty then rebuild() end

	local eggs = {}
	for _, egg in ipairs(eggTag and CollectionService:GetTagged(eggTag) or {}) do
		if egg:IsA("Model") then
			local pivot = egg:GetPivot().Position
			table.insert(eggs, { x = pivot.X, z = pivot.Z })
		end
	end
	local records = {}
	for _, c in ipairs(candidates) do
		local pos = locate(c)
		if pos then
			local kind = c.kind
			if c.nest then
				-- the egg tag only marks some species' nest eggs, so it is never taken as the full list: every live
				-- nest twinkles, and a tagged egg makes even a not-live nest twinkle
				kind = Ambience.nestKind(Ambience.nearEgg(pos.X, pos.Z, eggs, Ambience.EGG_RADIUS), false,
					c.model:GetAttribute("Enabled") == true)
			end
			table.insert(records, { id = c.id, kind = kind, x = pos.X, y = pos.Y, z = pos.Z, pos = pos, c = c })
		end
	end
	local eyePos = camera and camera.CFrame.Position or at
	local eye = { x = eyePos.X, y = eyePos.Y, z = eyePos.Z }

	reconcile(lights, Ambience.pick(records, eye, budget.lights, "light"), newLight, function(entry, rec)
		entry.attachment.WorldPosition = rec.pos
		if not budget.pulse then
			entry.light.Brightness = entry.spec.brightness
			entry.light.Color = rgb(Ambience.color(rec.kind, rec.id))
		end
	end, function(entry) entry.attachment:Destroy() end)

	local sparkleLimit = math.max(budget.emitters - (budget.fireflies and 1 or 0), 0)
	local sparkPicks = Ambience.pick(records, eye, sparkleLimit, "sparkle")
	reconcile(emitters, sparkPicks, newSparkle, function(entry, rec) moveNode(entry.node, rec.pos) end,
		function(entry) entry.node:Destroy() end)

	local wantedRates = {}
	for i, rec in ipairs(sparkPicks) do wantedRates[i] = { rate = Ambience.KINDS[rec.kind].sparkle.rate } end
	if budget.fireflies then table.insert(wantedRates, { rate = Ambience.FIREFLIES.rate }) end
	local rates = Ambience.rates(wantedRates, budget.rate)
	for i, rec in ipairs(sparkPicks) do
		local entry = emitters[rec.id]
		if entry then entry.emitter.Rate = rates[i] end
	end
	if budget.fireflies then
		if not fireflies then
			local size = Ambience.FIREFLIES.size
			local part = helperPart("Fireflies", Vector3.new(size[1], size[2], size[3]), CFrame.new(eyePos))
			part.Parent = holder
			fireflies = { part = part, emitter = newEmitter(Ambience.FIREFLIES.style, Ambience.FIREFLIES.color, part) }
		end
		fireflies.emitter.Rate = rates[#rates]
	elseif fireflies then
		fireflies.part:Destroy()
		fireflies = nil
	end

	reconcile(sways, Ambience.pick(records, eye, budget.sway, "sway"), newSway, function(entry, rec)
		-- parts that streamed out and back are new instances: build the entry again from them
		if entry.parts[1].part.Parent == nil then
			restoreSway(entry)
			sways[rec.id] = newSway(rec)
		end
	end, restoreSway)
end

-- Every frame while in the plot: the lights' slow breath and the cake's colour cycle (not on touch or with Efectos
-- suaves), the lollipop wobble and the fireflies following the camera.
local lastPulse = -math.huge
local function animate(t)
	local camera = workspace.CurrentCamera
	if fireflies and camera then fireflies.part.CFrame = CFrame.new(camera.CFrame.Position) end
	if budget.pulse and t - lastPulse >= Ambience.PULSE_STEP then
		lastPulse = t
		for _, entry in pairs(lights) do
			entry.light.Brightness = entry.spec.brightness * Ambience.pulse(t, entry.phase)
			if entry.spec.cycle then entry.light.Color = rgb(Ambience.cakeColor(t, entry.phase)) end
		end
	end
	for _, entry in pairs(sways) do
		local turn = CFrame.new(entry.foot) * CFrame.fromAxisAngle(entry.axis, Ambience.sway(t, entry.phase)) * CFrame.new(-entry.foot)
		for _, item in ipairs(entry.parts) do
			if item.part.Parent then item.part.CFrame = turn * item.base end
		end
	end
end

task.spawn(function()
	biome = workspace:WaitForChild(Ambience.ROOT_NAME, 120)
	dirty = true
end)

local pickClock = Ambience.PICK_SECONDS
local warned = false
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	pickClock += dt
	if pickClock >= Ambience.PICK_SECONDS then
		pickClock = 0
		local ok, message = pcall(refresh)
		if not ok and not warned then
			warned = true
			warn("Wildbound candy ambience: " .. tostring(message))
		end
	end
	if inCandy then
		local ok, message = pcall(animate, os.clock())
		if not ok then
			teardown()
			if not warned then
				warned = true
				warn("Wildbound candy ambience: " .. tostring(message))
			end
		end
	end
end))

table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, list in pairs(watched) do
		for _, connection in ipairs(list) do connection:Disconnect() end
	end
	teardown()
	setFlag(false)
end))
