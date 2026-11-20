-- Hub roulette service (PF5, user decision 2026-11-14: "en el hub", pity Rara+). WildboundServer starts it with its
-- State, its alive and root checks and a server-side Random; it builds one roulette station in the hub plaza at
-- runtime (the place file never needs saving) with one ProximityPrompt that everyone may use (no owner gating).
-- Never trust the client: the "Roulette" remote carries one action word ("open", "spin" or "offer") and, for "offer"
-- only, one offer id; nothing else is read.
-- The server alone checks the rate (one spin per SPIN_SECONDS), that the player is alive and near the station
-- (measured from the server-side root), rolls with its own rng over WildboundRoulette.LIVE and spends and grants
-- atomically through State:spinRoulette. The odds, the price (or the free spin) and the pity counter are sent before
-- any spin ("open"); the client shows them, turns its wheel to the server's result and shows it. Spins cost Esencia.
-- RW-4 / RW-5 (owner request 2026-11-20: "que lo de la ruleta sea asi"): spin packs from WildboundOffers. "offer" with
-- a catalog id is checked for the rate (OFFER_SECONDS), alive and in range. While WildboundFlags.DESBLOQUEAR_TODO is
-- true the pack's spins are granted for free; when it is false the answer is "Próximamente". Nothing is ever charged and
-- no purchase prompt exists anywhere.
-- Where the extra spins live (RW-5): here, per player, in server memory for the session (self.extra). They are never
-- saved, so the saved record (schema 6) and its validation stay exactly as they were and an older server can always
-- read a save. A free development grant that ends with the session costs nothing; a pack that is really bought would
-- need a saved, receipt-tied store, which comes with its own approval. An extra spin is used only after the account's
-- free first spin, costs no Esencia and neither counts toward nor resets the pity (WildboundRoulette.drawExtra).
-- The HUD notice of a win waits NOTIFY_DELAY seconds, so it never tells the prize before the client's wheel stops.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Service = {}
Service.__index = Service

Service.RANGE = 12 -- studs from the server-side root to the station for a spin or the odds panel
Service.SPIN_SECONDS = 3.2 -- one spin at a time per player: the client's wheel (3 s) stops before the next one
Service.OPEN_SECONDS = 0.3 -- the odds panel at most this often per player
Service.OFFER_SECONDS = 0.5 -- one spin pack at most this often per player
Service.NOTIFY_DELAY = 3 -- the HUD notice of a win waits for the wheel to stop
Service.PROMPT_DISTANCE = 9

-- The development switch, read from the sibling WildboundFlags (ServerScriptService); missing or broken reads as locked.
local function readFlags()
	local module = script.Parent and script.Parent:FindFirstChild("WildboundFlags")
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, flags = pcall(require, module)
	if ok then return flags end
	return nil
end

-- Without the catalog (WildboundOffers not deployed yet) the packs stay shut: every offer id is unknown, and the server
-- start never waits forever.
local function noOffers(Text)
	local words = Text.ROULETTE.unavailable
	return {
		WORDS = { comingSoon = words, full = words, unknown = words, wait = words, granted = words },
		get = function() return nil end,
		unlocked = function() return false end,
		claim = function() return false, "UnknownOffer" end,
	}
end

function Service.new(deps)
	assert(type(deps) == "table" and deps.state and deps.Roulette and deps.Text, "the roulette service needs its deps")
	local offers = deps.Offers
	if offers == nil then
		local module = ReplicatedStorage:WaitForChild("WildboundOffers", 10)
		offers = module and require(module) or noOffers(deps.Text)
	end
	local unlocked = deps.unlockAll
	if unlocked == nil then unlocked = offers.unlocked(readFlags()) end
	return setmetatable({
		deps = deps,
		position = deps.position, -- the station's centre (set by build)
		lastSpin = {}, -- [player] = clock of the last spin request
		lastOpen = {}, -- [player] = clock of the last odds request
		lastOffer = {}, -- [player] = clock of the last pack request
		extra = {}, -- [player] = extra spins from packs, this session only (RW-5)
		offers = offers,
		unlocked = unlocked == true,
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

-- What the panel shows: every live prize with its odds, the price or the free spin, the pity counter, the balance, the
-- spins left (the free first spin plus the extra spins), whether the packs are open, and SPIN_SECONDS (the client keeps
-- Girar off that long after a tap, so it never offers a spin this server would refuse as busy).
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
	local extra = self.extra[player] or 0
	local every = live.pity.every
	return {
		odds = odds, price = live.spinCost, free = free, ember = ember,
		canSpin = free or extra > 0 or ember >= live.spinCost,
		pityEnabled = live.pity.enabled == true, pityEvery = every, pityLeft = math.max(1, every - roulette.pityCount),
		pityRarity = Text.RARITY[live.pity.minRarity] or live.pity.minRarity,
		extraSpins = extra, spinsLeft = (free and 1 or 0) + extra, unlocked = self.unlocked,
		spinSeconds = Service.SPIN_SECONDS,
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
	local words = self.offers.WORDS
	local text = Text.unavailable
	if reason == "Busy" then text = Text.busy
	elseif reason == "TooFar" then text = Text.tooFar
	elseif reason == "Locked" then text = words.comingSoon
	elseif reason == "Full" then text = words.full
	elseif reason == "UnknownOffer" then text = words.unknown
	elseif reason == "OfferBusy" then text = words.wait
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

-- The HUD notice, after NOTIFY_DELAY (deps.after replaces the wait in tests); never for a player who left.
local function notifyLater(self, player, text)
	local deps = self.deps
	if not deps.notify then return end
	local function tell() deps.notify(player, true, text) end
	if deps.after then
		deps.after(Service.NOTIFY_DELAY, tell)
		return
	end
	task.delay(Service.NOTIFY_DELAY, function()
		if typeof(player) == "Instance" and player.Parent == nil then return end
		tell()
	end)
end

-- One spin: rate, alive and distance first (before any roll), then the server's roll, spent and granted in State.
-- After the free first spin, an extra spin from a pack is used before any Esencia is spent.
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
	local extra = self.extra[player] or 0
	local usedExtra = false
	local ok, receipt = deps.state:spinRoulette(player.UserId, true, distance, Service.RANGE, function(current)
		local firstFree = live.freeFirstSpin == true and current.freeSpinUsed ~= true
		if extra > 0 and not firstFree then
			usedExtra = true
			return Roulette.drawExtra(rng, current, live)
		end
		return Roulette.draw(rng, current, live)
	end)
	if not ok then return refuse(self, player, receipt) end
	if usedExtra then self.extra[player] = math.max(0, extra - 1) end
	local Text = deps.Text
	local label = Text.ROULETTE.prizes[receipt.prizeId] or receipt.prizeId
	local text = receipt.free and Text.ROULETTE.wonFree:format(label)
		or receipt.pity and Text.ROULETTE.pityWon:format(label)
		or Text.ROULETTE.won:format(label)
	send(self, player, "result", {
		prizeId = receipt.prizeId, index = prizeIndex(live, receipt.prizeId), label = label,
		rarity = Text.RARITY[receipt.rarity] or receipt.rarity, rarityKey = receipt.rarity, cost = receipt.cost,
		free = receipt.free, pity = receipt.pity, extra = usedExtra, text = text, view = self:view(player),
	})
	-- The server's own notice path pushes the HUD snapshot (the new Esencia and materials) once the wheel has stopped.
	notifyLater(self, player, text)
	return true, receipt
end

-- One spin pack (RW-4): the rate, a catalog id, alive and in range, then the free grant while DESBLOQUEAR_TODO is on.
function Service:offer(player, offerId)
	local deps = self.deps
	local now = clock(self)
	if now - (self.lastOffer[player] or -math.huge) < Service.OFFER_SECONDS then return refuse(self, player, "OfferBusy") end
	self.lastOffer[player] = now
	if self.offers.get(offerId) == nil then return refuse(self, player, "UnknownOffer") end
	local _, why = reach(self, player)
	if why then return refuse(self, player, why) end
	if not deps.state:snapshot(player.UserId) then return refuse(self, player, "InvalidPlayer") end
	local ok, held, offer = self.offers.claim(offerId, self.unlocked, self.extra[player] or 0)
	if not ok then return refuse(self, player, held) end
	self.extra[player] = held
	send(self, player, "granted", {
		offerId = offer.id, spins = offer.spins, extraSpins = held,
		text = self.offers.WORDS.granted:format(offer.name, held), view = self:view(player),
	})
	return true, offer.spins
end

-- The remote handler: the action word and, for "offer" only, the offer id; any other argument is ignored.
function Service:handle(player, action, offerId)
	if action == "open" then return self:open(player) end
	if action == "spin" then return (self:spin(player)) end
	if action == "offer" then return (self:offer(player, offerId)) end
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

-- Creates the remote in the network folder, builds the station and forgets players who leave (their extra spins too).
function Service:start(network, parent, cframe)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Roulette"
	remote.Parent = network
	self.remote = remote
	if not self.fire then
		self.fire = function(player, kind, payload) remote:FireClient(player, kind, payload) end
	end
	remote.OnServerEvent:Connect(function(player, action, offerId)
		self:handle(player, action, offerId)
	end)
	self:build(parent, cframe)
	Players.PlayerRemoving:Connect(function(player)
		self.lastSpin[player] = nil
		self.lastOpen[player] = nil
		self.lastOffer[player] = nil
		self.extra[player] = nil
	end)
	return self
end

return Service
