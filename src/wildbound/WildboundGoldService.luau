-- Gold service (odd/tasks/wildbound-gold.md), server only. Pays gold from the rules in WildboundGold: the creatures in
-- each player's base farm every step while the player is in the game, a bonus per tamed or hatched creature, and the
-- treadmill per lap under the per-minute cap. It sells the farm places and treadmill levels for gold (State checks
-- every rule; the client sends only the upgrade's name), mirrors the balance on the player attribute WildboundGold for
-- the HUD counter, and sends one batched "+N oro" popup at most every Gold.POPUP_SECONDS through the GoldPopup remote.
-- deps = { state, Gold, Training, Text, rarityOf(species), where(player) -> alive, distance, send(player, action, ok, text),
-- tracked(player) -> bool (the player has a server record) }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service

function Service.new(deps)
	return setmetatable({ deps = deps, carry = {}, windows = {}, buffers = {}, remote = nil }, Service)
end

local function speciesInFarm(snapshot)
	local byUid, list = {}, {}
	for _, pet in ipairs(snapshot.registered or {}) do byUid[pet.uid] = pet.species end
	for _, uid in ipairs(snapshot.farm or {}) do
		if byUid[uid] then table.insert(list, byUid[uid]) end
	end
	return list
end

function Service:sync(player)
	local snapshot = self.deps.state:snapshot(player.UserId)
	if snapshot and player:GetAttribute("WildboundGold") ~= snapshot.gold then player:SetAttribute("WildboundGold", snapshot.gold) end
end

-- Pays `amount` earned gold and queues it for the popup. Returns what was paid.
function Service:earn(player, amount)
	if type(amount) ~= "number" or amount < 1 then return 0 end
	local ok = self.deps.state:addGold(player.UserId, amount)
	if not ok then return 0 end
	self.buffers[player] = self.deps.Gold.batch(self.buffers[player], amount)
	self:sync(player)
	return amount
end

function Service:bonus(player)
	return self:earn(player, self.deps.Gold.TAME_BONUS)
end

-- A completed treadmill lap at `level`: the lap's gold under the anti-AFK cap.
function Service:lap(player, level)
	local Gold = self.deps.Gold
	local paid
	paid, self.windows[player] = Gold.capLap(self.windows[player], os.clock(), Gold.lapGold(level))
	return self:earn(player, paid)
end

function Service:step(dt)
	local Gold, state = self.deps.Gold, self.deps.state
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local snapshot = (not self.deps.tracked or self.deps.tracked(player)) and state:snapshot(player.UserId) or nil
		if snapshot then
			local rate = Gold.farmRate(speciesInFarm(snapshot), self.deps.rarityOf)
			local whole
			whole, self.carry[player] = Gold.accrue(self.carry[player], rate, dt)
			if whole > 0 then self:earn(player, whole) else self:sync(player) end
			local shown = Gold.flush(self.buffers[player], now)
			if shown and self.remote then self.remote:FireClient(player, shown) end
		end
	end
end

-- BuyGold: argument "train" (the next treadmill level) or a camp upgrade with a gold price.
function Service:buy(player, argument)
	local deps = self.deps
	local Gold, Training, T, state = deps.Gold, deps.Training, deps.Text.GOLD, deps.state
	local key = player.UserId
	local snapshot = state:snapshot(key)
	if not snapshot then return end
	local alive, distance = deps.where(player)
	local ok, result, price
	if argument == "train" then
		local maxLevel = Training.live.MAX_LEVEL
		price = Gold.trainPrice(Training.level(snapshot.training, "walk"), maxLevel)
		ok, result = state:trainWithGold(key, alive, distance, price, maxLevel)
	elseif Gold.upgradePrice(argument) then
		price = Gold.upgradePrice(argument)
		ok, result = state:upgradeWithGold(key, argument, alive, distance, price)
	else
		return
	end
	self:sync(player)
	local after = state:snapshot(key)
	local text
	if ok then
		text = argument == "train" and T.trained:format(result, Training.live.MAX_LEVEL, after.gold) or T.bought:format(after.gold)
	elseif result == "CannotAffordGold" then
		text = T.short:format(math.max(0, (price or 0) - (snapshot.gold or 0)))
	elseif result == "AtLimit" then
		text = T.maxed
	elseif result == "AlreadyOwned" then
		text = T.owned
	elseif result == "NeedsPrerequisite" then
		text = T.needsFirst
	else
		text = T.farAway
	end
	deps.send(player, "BuyGold", ok == true, text)
end

function Service:start(network)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "GoldPopup"
	remote.Parent = network
	self.remote = remote
	Players.PlayerRemoving:Connect(function(player)
		self.carry[player], self.windows[player], self.buffers[player] = nil, nil, nil
	end)
	-- Studio only: a probe the walked Play check uses to grant test gold for a purchase test. Never in a live server.
	if RunService:IsStudio() then
		local probe = Instance.new("BindableFunction")
		probe.Name = "WildboundGoldProbe"
		probe.OnInvoke = function(op, userId, amount)
			local player = Players:GetPlayerByUserId(userId)
			if op == "grant" and player then return self:earn(player, amount) end
			if op == "read" then return self.deps.state:snapshot(userId) and self.deps.state:snapshot(userId).gold end
			return nil
		end
		probe.Parent = game:GetService("ServerStorage")
	end
	task.spawn(function()
		while true do
			local dt = task.wait(self.deps.Gold.TICK)
			self:step(dt)
		end
	end)
	return self
end

return Service
