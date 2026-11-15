-- Hub roulette service (PF5, user decision 2026-11-14: "en el hub", pity Rara+). WildboundServer starts it with its
-- State, its alive and root checks and a server-side Random; it builds one roulette station in the hub plaza at
-- runtime (the place file never needs saving) with one ProximityPrompt that everyone may use (no owner gating).
-- Never trust the client: the "Roulette" remote carries one action word ("open" or "spin") and nothing else is read.
-- The server alone checks the rate (one spin per SPIN_SECONDS), that the player is alive and near the station
-- (measured from the server-side root), rolls with its own rng over WildboundRoulette.LIVE and spends and grants
-- atomically through State:spinRoulette. The odds, the price (or the free spin) and the pity counter are sent before
-- any spin ("open"); the client shows them, plays a short spin and shows the server's result. Esencia only, no Robux.
local Players = game:GetService("Players")

local Service = {}
Service.__index = Service

Service.RANGE = 12 -- studs from the server-side root to the station for a spin or the odds panel
Service.SPIN_SECONDS = 1.6 -- one spin at a time per player: the client's spin animation is shorter
Service.OPEN_SECONDS = 0.3 -- the odds panel at most this often per player
Service.PROMPT_DISTANCE = 9

function Service.new(deps)
	assert(type(deps) == "table" and deps.state and deps.Roulette and deps.Text, "the roulette service needs its deps")
	return setmetatable({
		deps = deps,
		position = deps.position, -- the station's centre (set by build)
		lastSpin = {}, -- [player] = clock of the last spin request
		lastOpen = {}, -- [player] = clock of the last odds request
		fire = deps.fire,
	}, Service)
end

local function clock(self)
	return self.deps.now and self.deps.now() or os.clock()
end

local function prizeIndex(live, id)
	for index, prize in ipairs(live.prizes) do
		if prize.id == id then return index, prize end
	end
	return nil
end

local function send(self, player, kind, payload)
	if self.fire then self.fire(player, kind, payload) end
end

-- Distance from the server-side root to the station, or nil when the player cannot use it now.
local function reach(self, player)
	local deps = self.deps
	if not deps.alive(player) then return nil, "InvalidContext" end
	local root = deps.rootOf(player)
	if not root or typeof(root.Position) ~= "Vector3" or typeof(self.position) ~= "Vector3" then
		return nil, "InvalidContext"
	end
	local distance = (root.Position - self.position).Magnitude
	if distance > Service.RANGE then return nil, "TooFar" end
	return distance
end

-- What the panel shows: every live prize with its odds, the price or the free spin, the pity counter and the balance.
function Service:view(player)
	local deps = self.deps
	local Text, live = deps.Text, deps.Roulette.LIVE
	local snapshot = deps.state:snapshot(player.UserId)
	local roulette = snapshot and snapshot.roulette or { freeSpinUsed = false, pityCount = 0, paidSpins = 0 }
	local ember = snapshot and snapshot.ember or 0
	local odds = {}
	for _, row in ipairs(deps.Roulette.oddsTable(live).prizes) do
		table.insert(odds, { id = row.id, label = Text.ROULETTE.prizes[row.id] or row.label,
			rarity = Text.RARITY[row.rarity] or row.rarity, rarityKey = row.rarity, percent = row.percent })
	end
	local free = live.freeFirstSpin == true and roulette.freeSpinUsed ~= true
	local every = live.pity.every
	return {
		odds = odds, price = live.spinCost, free = free, ember = ember, canSpin = free or ember >= live.spinCost,
		pityEnabled = live.pity.enabled == true, pityEvery = every, pityLeft = math.max(1, every - roulette.pityCount),
		pityRarity = Text.RARITY[live.pity.minRarity] or live.pity.minRarity,
	}
end

-- The prompt (or the client's "open"): sends the odds panel. Never rolls and never spends.
function Service:open(player)
	local now = clock(self)
	if now - (self.lastOpen[player] or -math.huge) < Service.OPEN_SECONDS then return false, "Busy" end
	self.lastOpen[player] = now
	local _, why = reach(self, player)
	if why then
		send(self, player, "refused", { text = why == "TooFar" and self.deps.Text.ROULETTE.tooFar
			or self.deps.Text.ROULETTE.unavailable })
		return false, why
	end
	send(self, player, "open", self:view(player))
	return true
end

local function refuse(self, player, reason)
	local Text = self.deps.Text.ROULETTE
	local text = Text.unavailable
	if reason == "Busy" then text = Text.busy
	elseif reason == "TooFar" then text = Text.tooFar
	elseif reason == "CannotAfford" then
		local snapshot = self.deps.state:snapshot(player.UserId)
		local missing = self.deps.Roulette.LIVE.spinCost - (snapshot and snapshot.ember or 0)
		text = Text.cannotAfford:format(math.max(1, missing))
	end
	local payload = { text = text, reason = reason }
	if self.deps.state:snapshot(player.UserId) then payload.view = self:view(player) end
	send(self, player, "refused", payload)
	return false, reason
end

-- One spin: rate, alive and distance first (before any roll), then the server's roll, spent and granted in State.
function Service:spin(player)
	local deps = self.deps
	local now = clock(self)
	if now - (self.lastSpin[player] or -math.huge) < Service.SPIN_SECONDS then return refuse(self, player, "Busy") end
	self.lastSpin[player] = now
	local distance, why = reach(self, player)
	if not distance then return refuse(self, player, why) end
	if not deps.state:snapshot(player.UserId) then return refuse(self, player, "InvalidPlayer") end
	local Roulette, live = deps.Roulette, deps.Roulette.LIVE
	local rng = deps.random()
	local ok, receipt = deps.state:spinRoulette(player.UserId, true, distance, Service.RANGE, function(current)
		return Roulette.draw(rng, current, live)
	end)
	if not ok then return refuse(self, player, receipt) end
	local Text = deps.Text
	local label = Text.ROULETTE.prizes[receipt.prizeId] or receipt.prizeId
	local text = receipt.free and Text.ROULETTE.wonFree:format(label)
		or receipt.pity and Text.ROULETTE.pityWon:format(label)
		or Text.ROULETTE.won:format(label)
	send(self, player, "result", {
		prizeId = receipt.prizeId, index = prizeIndex(live, receipt.prizeId), label = label,
		rarity = Text.RARITY[receipt.rarity] or receipt.rarity, rarityKey = receipt.rarity, cost = receipt.cost,
		free = receipt.free, pity = receipt.pity, text = text, view = self:view(player),
	})
	-- The server's own notice path pushes the HUD snapshot (the new Esencia and materials).
	if deps.notify then deps.notify(player, true, text) end
	return true, receipt
end

-- The remote handler: only the action word is read; any other argument from the client is ignored.
function Service:handle(player, action)
	if action == "open" then return self:open(player) end
	if action == "spin" then return (self:spin(player)) end
	return false
end

local function part(parent, name, size, cframe, color, material, shape)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	if shape then item.Shape = shape end
	item.Anchored = true
	item.CanCollide = true
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

-- The station: a pedestal, a standing wheel with coloured slices, a pointer and a sign. Built at runtime only.
function Service:build(parent, cframe)
	local Text = self.deps.Text
	local model = Instance.new("Model")
	model.Name = "WildboundRouletteStation"
	model:SetAttribute("WildboundStation", "roulette")
	local base = part(model, "Pedestal", Vector3.new(1.2, 7, 7), cframe * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(54, 66, 94), Enum.Material.Slate, Enum.PartType.Cylinder)
	local hub = cframe * CFrame.new(0, 5.2, 0)
	part(model, "Post", Vector3.new(0.8, 4, 0.8), cframe * CFrame.new(0, 2.6, 0.9), Color3.fromRGB(40, 50, 70))
	local wheel = part(model, "Wheel", Vector3.new(0.5, 6, 6), hub * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 214, 64), Enum.Material.Neon, Enum.PartType.Cylinder)
	wheel.CanCollide = false
	local tones = { Color3.fromRGB(58, 148, 245), Color3.fromRGB(150, 86, 232), Color3.fromRGB(92, 214, 64),
		Color3.fromRGB(236, 64, 72), Color3.fromRGB(255, 146, 38), Color3.fromRGB(72, 200, 250) }
	for index, tone in ipairs(tones) do
		local angle = math.rad((index - 1) * 60)
		local slice = part(model, "Slice" .. index, Vector3.new(0.3, 2.6, 0.9),
			hub * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.45, 0), tone, Enum.Material.SmoothPlastic)
		slice.CanCollide = false
	end
	local pointer = part(model, "Pointer", Vector3.new(0.6, 0.9, 0.6), hub * CFrame.new(0, 3.4, -0.4),
		Color3.fromRGB(236, 64, 72), Enum.Material.Neon)
	pointer.CanCollide = false
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(180, 44)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	sign.MaxDistance = 90
	sign.AlwaysOnTop = false
	sign.Adornee = wheel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = Text.ROULETTE.title
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Parent = sign
	sign.Parent = wheel
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildboundRoulettePrompt"
	prompt.ActionText = Text.ROULETTE.prompt
	prompt.ObjectText = Text.ROULETTE.object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Service.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = base
	prompt.Triggered:Connect(function(player) self:open(player) end)
	model.Parent = parent
	self.model, self.prompt, self.position = model, prompt, cframe.Position
	return model
end

-- Creates the remote in the network folder, builds the station and forgets players who leave.
function Service:start(network, parent, cframe)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Roulette"
	remote.Parent = network
	self.remote = remote
	if not self.fire then
		self.fire = function(player, kind, payload) remote:FireClient(player, kind, payload) end
	end
	remote.OnServerEvent:Connect(function(player, action)
		self:handle(player, action)
	end)
	self:build(parent, cframe)
	Players.PlayerRemoving:Connect(function(player)
		self.lastSpin[player] = nil
		self.lastOpen[player] = nil
	end)
	return self
end

return Service
