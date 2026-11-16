-- Gold service (odd/tasks/wildbound-gold.md), server only. Pays gold from the rules in WildboundGold: the creatures in
-- each player's base farm every step while the player is in the game and not idle (Gold.idle: still for IDLE_SECONDS,
-- read from the server's character position), a bonus per tamed or hatched creature, and the
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
	return setmetatable({ deps = deps, carry = {}, windows = {}, buffers = {}, tracks = {}, remote = nil }, Service)
end

-- Gold follow-up: whether the farm is paused for this player now. The position is the server's view of the
-- character's HumanoidRootPart (Gold.watch / Gold.idle); the client never reports idleness. The first step of a pause
-- sets the player attribute WildboundFarmPaused and says so once; a move clears it.
function Service:farmPaused(player, now)
	local Gold = self.deps.Gold
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		self.tracks[player] = Gold.watch(self.tracks[player], root.Position.X, root.Position.Z, now)
	end
	local paused = Gold.idle(self.tracks[player], now)
	if paused and player:GetAttribute("WildboundFarmPaused") ~= true then
		player:SetAttribute("WildboundFarmPaused", true)
		local words = self.deps.Text and self.deps.Text.GOLD
		if words and words.farmPaused and self.deps.send then self.deps.send(player, "Notice", false, words.farmPaused) end
	elseif not paused and player:GetAttribute("WildboundFarmPaused") ~= nil then
		player:SetAttribute("WildboundFarmPaused", nil)
	end
	return paused
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
			-- Gold follow-up: an idle player's farm pays nothing (its carried fraction waits).
			local rate = not self:farmPaused(player, now) and Gold.farmRate(speciesInFarm(snapshot), self.deps.rarityOf) or 0
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

-- Owner feedback 3: SellCreature. The uid is untrusted; the price comes from the server's own species rarity and bond
-- level (Gold.sellPrice), State:sellCreature checks every rule. The "+N oro" popup shows at once. Returns ok.
function Service:sell(player, uid)
	local deps = self.deps
	local Gold, T, state = deps.Gold, deps.Text.GOLD, deps.state
	local key = player.UserId
	local snapshot = state:snapshot(key)
	if not snapshot or type(uid) ~= "string" then return false end
	local species
	for _, pet in ipairs(snapshot.registered or {}) do
		if pet.uid == uid then species = pet.species end
	end
	local bond = type(snapshot.bond) == "table" and snapshot.bond[uid] or nil
	local price = Gold.sellPrice(species and deps.rarityOf(species), type(bond) == "table" and bond.level or 1)
	local ok, result = state:sellCreature(key, uid, (deps.where(player)), price)
	if not ok then
		deps.send(player, "SellCreature", false, T.sellRefused[result] or T.sellFailed)
		return false
	end
	self.buffers[player] = Gold.batch(self.buffers[player], price)
	self.buffers[player].shownAt = -math.huge
	self:sync(player)
	local shown = Gold.flush(self.buffers[player], os.clock())
	if shown and self.remote then self.remote:FireClient(player, shown) end
	local names = deps.Text.CARD and deps.Text.CARD.species or {}
	deps.send(player, "SellCreature", true, T.sold:format(names[species] or species, price))
	return true
end

function Service:start(network)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "GoldPopup"
	remote.Parent = network
	self.remote = remote
	Players.PlayerRemoving:Connect(function(player)
		self.carry[player], self.windows[player], self.buffers[player], self.tracks[player] = nil, nil, nil, nil
	end)
	-- Studio only: a probe the walked Play check uses to grant test gold for a purchase test. Never in a live server.
	if RunService:IsStudio() then
		local probe = Instance.new("BindableFunction")
		probe.Name = "WildboundGoldProbe"
		probe.OnInvoke = function(op, userId, amount)
			local player = Players:GetPlayerByUserId(userId)
			if op == "grant" and player then return self:earn(player, amount) end
			if op == "read" then return self.deps.state:snapshot(userId) and self.deps.state:snapshot(userId).gold end
			-- Owner feedback 3: one test creature of species `amount`, only to test a sale in a walked Studio check.
			if op == "creature" and type(amount) == "string" then
				local state = self.deps.state
				for key, profile in pairs(state.players) do
					if tostring(key):match("%f[%d]" .. tostring(userId) .. "$") and type(profile.registered) == "table" then
						state.nextUid += 1
						local uid = "wb:" .. state.nextUid
						table.insert(profile.registered, { uid = uid, species = amount })
						return uid
					end
				end
			end
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
