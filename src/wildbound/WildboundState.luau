-- Pure, synchronous session state. Only the server supplies context, IDs and the clock.
-- M5.2: materials, Ember and the loss rule read the generated tuning through the pure Economy rules,
-- both passed to State.new, so docs/mechanics/wildbound-economy-p0.md stays the single source.
local State = {}
State.__index = State
local DEFEAT_HISTORY, STRIKE_HISTORY = 256, 64

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function playerKey(value)
	if validId(value) then return "s:" .. value end
	if finite(value) and value % 1 == 0 then return "n:" .. tostring(value) end
	return nil
end

local function profile(self, key)
	local normalized = playerKey(key)
	return normalized and self.players[normalized] or nil
end

local function context(alive, distance, limit)
	return alive == true and type(distance) == "number" and distance == distance
		and distance >= 0 and distance <= limit
end

local function find(entries, uid)
	if not validId(uid) then return nil end
	for index, entry in ipairs(entries) do
		if entry.uid == uid then return index, entry end
	end
	return nil
end

local function copy(entries)
	local detached = {}
	for index, entry in ipairs(entries) do detached[index] = table.clone(entry) end
	return detached
end

local function newUid(self)
	self.nextUid += 1
	return "wb:" .. self.nextUid
end

function State.new(economy, config)
	assert(type(economy) == "table" and type(config) == "table", "State.new needs the Economy rules and tuning")
	return setmetatable({ players = {}, encounters = {}, nextUid = 0, economy = economy, config = config }, State)
end

local function zeroed(names)
	local amounts = {}
	for _, name in ipairs(names) do amounts[name] = 0 end
	return amounts
end

function State:addPlayer(key)
	local normalized = playerKey(key)
	if not normalized then return false, "InvalidPlayer" end
	if not self.players[normalized] then
		local consumables = {}
		for name in pairs(self.config.capacity.consumableCaps) do consumables[name] = 0 end
		local upgrades = {}
		for name in pairs(self.config.upgrades) do upgrades[name] = false end
		self.players[normalized] = {
			pending = {}, bankedEggs = {}, registered = {}, earnedSeal = false, defeats = {}, defeatOrder = {},
			dropped = {}, strikeDrops = {}, strikeOrder = {},
			carried = zeroed(self.economy.pouchMaterials(self.config)),
			banked = zeroed(self.economy.materials(self.config)),
			ember = 0, consumables = consumables, upgrades = upgrades,
			sealArmed = false, totemActive = false, expedition = nil, skills = {}, bond = {},
		}
	end
	return true
end

function State:removePlayer(key)
	local normalized = playerKey(key)
	if not normalized then return false, "InvalidPlayer" end
	self.players[normalized] = nil
	return true
end

function State:registerEncounter(id, kind)
	if not validId(id) or (kind ~= "Creature" and kind ~= "Egg" and kind ~= "Gather") then
		return false, "InvalidEncounter"
	end
	if self.encounters[id] then return false, "AlreadyRegistered" end
	self.encounters[id] = { kind = kind, claimed = false }
	return true
end

-- Adapter-only lifecycle: disconnect/remove an expired world slot first.
-- Retired IDs must NEVER be reused; they become unknown, not available loot.
function State:retireEncounter(id)
	if not validId(id) then return false, "InvalidEncounter" end
	self.encounters[id] = nil
	return true
end

local function bagCapacity(self, player)
	return self.economy.bagCapacity(self.config, player.upgrades)
end

-- Companions toward the collection limit: bag creatures and eggs, banked eggs and registered pets.
-- A Nightbloom bundle banks as a material, so it never counts.
local function collectionSize(player)
	local total = #player.bankedEggs + #player.registered
	for _, entry in ipairs(player.pending) do
		if entry.kind ~= "Nightbloom" then total += 1 end
	end
	return total
end

local function carriedUnits(player)
	local total = 0
	for _, quantity in pairs(player.carried) do total += quantity end
	return total
end

-- The bag item warded by this source ("Seal" or "Totem"), if any. Each wards at most one item.
local function warded(player, source)
	for _, entry in ipairs(player.pending) do
		if entry.protected and entry.wardSource == source then return entry end
	end
	return nil
end

-- Every new item enters the bag here, so the expedition counts it once and an armed seal (M5.5)
-- wards it. A reclaimed drop is not new and never takes the armed seal.
local function addToBag(self, player, entry)
	table.insert(player.pending, entry)
	if player.expedition then player.expedition.newItems += 1 end
	if player.sealArmed and player.consumables.seal > 0 and not warded(player, "Seal") then
		entry.protected, entry.wardSource = true, "Seal"
		player.sealArmed = false
	end
	return entry
end

function State:pickup(key, id, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(id) then return false, "InvalidEncounter" end
	if not context(alive, distance, 10) then return false, "InvalidContext" end
	local encounter = self.encounters[id]
	if not encounter or encounter.kind == "Gather" then return false, "InvalidEncounter" end
	if encounter.claimed then return false, "AlreadyClaimed" end
	-- A creature is granted only by a finished capture session (completeCapture), never by a prompt.
	if encounter.kind == "Creature" then return false, "CaptureRequired" end
	if #player.pending >= bagCapacity(self, player) then return false, "BackpackFull" end
	if collectionSize(player) >= self.config.capacity.collectionLimit then return false, "CollectionFull" end
	local uid = newUid(self)
	-- No yield occurs between availability check, global claim and ownership grant.
	encounter.claimed = true
	-- Every nest sits in the territory, so an egg is a Territory item (economy document, Earning Ember).
	addToBag(self, player, {
		uid = uid, kind = encounter.kind, species = "Lumipol", protected = false, riskTier = "Territory",
	})
	return true, uid
end

local TIERS = table.freeze({ Safe = true, Fog = true, Territory = true })

-- Whether a capture could be granted now: bag room, then collection room. Missing players have neither.
function State:captureRoom(key)
	local player = profile(self, key)
	if not player then return false, false end
	return #player.pending < bagCapacity(self, player), collectionSize(player) < self.config.capacity.collectionLimit
end

-- "Open", "Claimed" or nil for an unknown or retired id. Lets the adapter name the encounter state.
function State:encounterStatus(id)
	if not validId(id) then return nil end
	local encounter = self.encounters[id]
	if not encounter then return nil end
	return encounter.claimed and "Claimed" or "Open"
end

-- The grant for a finished capture. The ring session already proved skill, owner and reservation, and a
-- correct finish can be farther than the 10 stud pickup range, so there is no distance here. It claims
-- and grants in one step with no yield, so the creature has exactly one owner.
function State:completeCapture(key, id, alive, tier)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(id) then return false, "InvalidEncounter" end
	local encounter = self.encounters[id]
	if not encounter or encounter.kind ~= "Creature" then return false, "InvalidEncounter" end
	if alive ~= true then return false, "InvalidContext" end
	if encounter.claimed then return false, "AlreadyClaimed" end
	if type(tier) ~= "string" or not TIERS[tier] then return false, "InvalidTier" end
	if #player.pending >= bagCapacity(self, player) then return false, "BackpackFull" end
	if collectionSize(player) >= self.config.capacity.collectionLimit then return false, "CollectionFull" end
	local uid = newUid(self)
	encounter.claimed = true
	addToBag(self, player, {
		uid = uid, kind = "Creature", species = "Lumipol", protected = false, riskTier = tier,
	})
	return true, uid
end

local function openExpedition(player, now)
	if not player.expedition then
		player.expedition = { startedAt = now, maxDistanceFromCamp = 0, paidSlots = {}, newUnits = 0, newItems = 0,
			bondXp = 0, bondEvents = {}, pendingBond = {} }
	end
	return player.expedition
end

-- The adapter reports where a player is. Leaving the camp circle opens an expedition; it then only
-- widens its farthest distance. It never grants anything: income needs a gather, a capture or a pickup.
function State:observeExpedition(key, distanceFromCamp, outsideCamp, now)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not finite(distanceFromCamp) or distanceFromCamp < 0 or type(outsideCamp) ~= "boolean" or not finite(now) then
		return false, "InvalidContext"
	end
	if outsideCamp then openExpedition(player, now) end
	local expedition = player.expedition
	if expedition and distanceFromCamp > expedition.maxDistanceFromCamp then
		expedition.maxDistanceFromCamp = distanceFromCamp
	end
	return true
end

-- One gather node (D4): the first valid claim owns it. Material and quantity were chosen by the server
-- when the node spawned. A slot pays a player once per expedition; a full pouch or bag claims nothing.
function State:gather(key, nodeId, slotId, material, quantity, alive, distance, now)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(nodeId) or not validId(slotId) then return false, "InvalidEncounter" end
	local encounter = self.encounters[nodeId]
	if not encounter or encounter.kind ~= "Gather" then return false, "InvalidEncounter" end
	if not context(alive, distance, self.config.gather.promptRange) or not finite(now) then
		return false, "InvalidContext"
	end
	if encounter.claimed then return false, "AlreadyClaimed" end
	local spec = type(material) == "string" and self.config.materials[material] or nil
	if not spec or not self.economy.isCount(quantity) or quantity < 1 then return false, "InvalidYield" end
	local expedition = player.expedition
	if expedition and expedition.paidSlots[slotId] then return false, "AlreadyGathered" end
	local receipt = { material = material, taken = quantity, wasted = 0 }
	if spec.carriedAs == "bagItem" then
		if #player.pending >= bagCapacity(self, player) then return false, "BackpackFull" end
	else
		local room = self.economy.pouchCapacity(self.config, player.upgrades) - carriedUnits(player)
		if room < 1 then return false, "PouchFull" end
		receipt.taken = math.min(quantity, room)
		receipt.wasted = quantity - receipt.taken
	end
	-- No yield from here: claim, record the slot, grant.
	encounter.claimed = true
	expedition = openExpedition(player, now)
	expedition.paidSlots[slotId] = true
	if spec.carriedAs == "bagItem" then
		receipt.uid = newUid(self)
		addToBag(self, player, { uid = receipt.uid, kind = "Nightbloom", quantity = quantity, protected = false })
	else
		player.carried[material] += receipt.taken
		expedition.newUnits += receipt.taken
	end
	return true, receipt
end

-- Bond (M5.6, D14). XP is earned only by the equipped companion, only from an event the server observed, and
-- only an extraction banks it. A defeat closes the expedition and the pending XP goes with it.
local BOND_EVENTS = table.freeze({ pulseRevealInFog = true, pulseThenDodge = true })

local function addBondXp(self, expedition, event, uid)
	local spec = self.config.bond.events[event]
	if (expedition.bondEvents[event] or 0) >= spec.maxPerExpedition then return false, "EventCap" end
	local xp = math.min(spec.xp, self.config.bond.maxXpPerExpedition - expedition.bondXp)
	if xp < 1 then return false, "XpCap" end
	expedition.bondEvents[event] = (expedition.bondEvents[event] or 0) + 1
	expedition.bondXp += xp
	expedition.pendingBond[uid] = (expedition.pendingBond[uid] or 0) + xp
	return true, xp
end

-- At extraction: the completed-trip bonus for the equipped companion, then every companion's pending XP banks.
local function bankBond(self, player, completed)
	local expedition = player.expedition
	if not expedition then return end
	if completed and player.equippedUid and find(player.registered, player.equippedUid) then
		addBondXp(self, expedition, "extractWithCompanion", player.equippedUid)
	end
	for uid, xp in pairs(expedition.pendingBond) do
		local entry = player.bond[uid] or { xp = 0, level = 1 }
		entry.xp += xp
		entry.level = self.economy.bondLevel(self.config, entry.xp)
		player.bond[uid] = entry
	end
end

-- The adapter reports a pulse that revealed Silueta to a player in the fog (or a dodge after one).
function State:bondEvent(key, event, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if type(event) ~= "string" or not BOND_EVENTS[event] then return false, "UnknownEvent" end
	if alive ~= true then return false, "InvalidContext" end
	local expedition = player.expedition
	if not expedition then return false, "NoExpedition" end
	local uid = player.equippedUid
	if not uid or not find(player.registered, uid) then return false, "NoCompanion" end
	return addBondXp(self, expedition, event, uid)
end

-- An expedition that left camp ends here, by extraction or defeat. An armed totem is spent with it,
-- whether or not it saved anything (M5.5).
local function closeExpedition(self, player)
	if player.expedition and player.totemActive then player.totemActive = false end
	player.expedition = nil
end

-- A bag item moves to the collection or the bank and pays its Ember. Shared by extraction and capsule.
local function bankItem(self, player, entry)
	if entry.kind == "Egg" then
		table.insert(player.bankedEggs, { uid = entry.uid, kind = "Egg", species = entry.species })
	elseif entry.kind == "Nightbloom" then
		player.banked.nightbloom += entry.quantity
	else
		table.insert(player.registered, { uid = entry.uid, species = entry.species })
	end
	local ember = self.economy.itemEmber(self.config, entry)
	player.ember += ember
	return ember
end

function State:extract(key, alive, distance, now)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not context(alive, distance, 12) then return false, "InvalidContext" end
	local count, units = #player.pending, carriedUnits(player)
	if count == 0 and units == 0 then return false, "Empty" end
	local economy, config = self.economy, self.config
	local receipt = { items = count, units = table.clone(player.carried), ember = 0, baseEmber = 0 }
	for _, entry in ipairs(player.pending) do receipt.ember += bankItem(self, player, entry) end
	for material, quantity in pairs(player.carried) do
		player.banked[material] += quantity
		player.carried[material] = 0
	end
	local expedition = player.expedition
	if expedition and finite(now) then
		receipt.baseEmber = economy.baseEmber(config, now - expedition.startedAt, expedition.maxDistanceFromCamp,
			expedition.newUnits + expedition.newItems)
		receipt.ember += receipt.baseEmber
		player.ember += receipt.baseEmber
	end
	bankBond(self, player, receipt.baseEmber > 0)
	player.pending = {}
	if not player.earnedSeal then
		-- Adds, never assigns, so crafted seals are kept (ECO-07). Held seals never pass their cap.
		player.earnedSeal = true
		player.consumables.seal = math.min(config.capacity.consumableCaps.seal,
			player.consumables.seal + config.earn.firstExtractionSeal)
	end
	closeExpedition(self, player)
	return true, count, receipt
end

function State:hatch(key, uid, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not context(alive, distance, 12) then return false, "InvalidContext" end
	local index, egg = find(player.bankedEggs, uid)
	if not index then return false, "NotOwnedEgg" end
	local petUid = newUid(self)
	table.remove(player.bankedEggs, index)
	table.insert(player.registered, { uid = petUid, species = egg.species })
	return true, petUid
end

function State:equip(key, uid, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	if not find(player.registered, uid) then return false, "NotOwnedPet" end
	player.equippedUid = uid
	return true, uid
end

function State:protect(key, uid, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	local _, entry = find(player.pending, uid)
	if not entry then return false, "NotOwnedPending" end
	if entry.protected then return true, uid end
	-- An active totem wards first: it is spent with the trip anyway, so the seal is kept for later.
	if player.totemActive and not warded(player, "Totem") then
		entry.protected, entry.wardSource = true, "Totem"
		return true, uid
	end
	if player.consumables.seal < 1 then return false, "NoSeal" end
	if warded(player, "Seal") then return false, "AlreadyProtected" end
	-- B8: anywhere, alive. A manual seal uses an armed one, so one seal never wards two items.
	entry.protected, entry.wardSource = true, "Seal"
	player.sealArmed = false
	return true, uid
end

-- B8 one-tap field seal: the newest unwarded bag item.
function State:sealNewest(key, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	for index = #player.pending, 1, -1 do
		local entry = player.pending[index]
		if not entry.protected then return self:protect(key, entry.uid, true) end
	end
	return false, "Empty"
end

-- B8 seal before leaving: the next new item into the bag is warded. Not spent if nothing comes.
function State:armSeal(key, alive)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	if player.consumables.seal < 1 then return false, "NoSeal" end
	if warded(player, "Seal") then return false, "AlreadyProtected" end
	player.sealArmed = true
	return true
end

local function atCamp(self, alive, distance)
	if alive ~= true then return false, "InvalidContext" end
	if not context(true, distance, self.config.sinks.campRange) then return false, "NotAtCamp" end
	return true
end

-- Check, pay, grant, with no yield. A refusal changes nothing.
local function purchase(self, player, cost)
	local purse = { ember = player.ember, banked = player.banked }
	if not self.economy.canPay(purse, cost) then return false end
	self.economy.pay(purse, cost)
	player.ember = purse.ember
	return true
end

-- Crafting at camp, repeatable up to each consumable's cap.
function State:craft(key, recipe, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local spec = type(recipe) == "string" and self.config.recipes[recipe] or nil
	if not spec then return false, "UnknownRecipe" end
	local ok, reason = atCamp(self, alive, distance)
	if not ok then return false, reason end
	if player.consumables[recipe] >= self.config.capacity.consumableCaps[recipe] then return false, "AtLimit" end
	if not purchase(self, player, spec.cost) then return false, "CannotAfford" end
	player.consumables[recipe] += 1
	return true, player.consumables[recipe]
end

-- Permanent upgrades at camp, once each.
function State:upgrade(key, name, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local spec = type(name) == "string" and self.config.upgrades[name] or nil
	if not spec then return false, "UnknownUpgrade" end
	local ok, reason = atCamp(self, alive, distance)
	if not ok then return false, reason end
	if player.upgrades[name] then return false, "AlreadyOwned" end
	if not purchase(self, player, spec.cost) then return false, "CannotAfford" end
	player.upgrades[name] = true
	return true, name
end

-- The totem is armed at camp before leaving. Its downside (detection and ambush weight) is applied by
-- the world adapter while it is active. Disarming before leaving refunds it.
function State:armTotem(key, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local ok, reason = atCamp(self, alive, distance)
	if not ok then return false, reason end
	if player.expedition then return false, "AlreadyLeft" end
	if player.totemActive then return true end
	if player.consumables.totem < 1 then return false, "NoTotem" end
	player.consumables.totem -= 1
	player.totemActive = true
	return true
end

function State:disarmTotem(key, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local ok, reason = atCamp(self, alive, distance)
	if not ok then return false, reason end
	if player.expedition then return false, "AlreadyLeft" end
	if not player.totemActive then return false, "NoTotem" end
	local entry = warded(player, "Totem")
	if entry then entry.protected, entry.wardSource = false, nil end
	player.totemActive = false
	player.consumables.totem += 1
	return true
end

-- Skills (M5.6): permanent, bought at camp with banked materials and Ember. Only skills whose effect the
-- game applies can be bought (Economy.LIVE_EFFECTS); the rest are refused before any payment.
function State:learn(key, skillId, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local spec = type(skillId) == "string" and self.config.skills[skillId] or nil
	if not spec then return false, "UnknownSkill" end
	local ok, reason = atCamp(self, alive, distance)
	if not ok then return false, reason end
	if player.skills[skillId] then return false, "AlreadyOwned" end
	for _, required in ipairs(spec.requires) do
		if not player.skills[required] then return false, "NeedsPrerequisite" end
	end
	if spec.effectLive ~= true then return false, "EffectPending" end
	if not purchase(self, player, spec.cost) then return false, "CannotAfford" end
	player.skills[skillId] = true
	return true, skillId
end

-- At the shelter, one bag item banks on the spot and pays its Ember now. No hatching.
function State:useCapsule(key, uid, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if alive ~= true then return false, "InvalidContext" end
	if not context(true, distance, self.config.capsule.range) then return false, "NotAtShelter" end
	local index, entry = find(player.pending, uid)
	if not index then return false, "NotOwnedPending" end
	if player.consumables.capsule < 1 then return false, "NoCapsule" end
	table.remove(player.pending, index)
	player.consumables.capsule -= 1
	return true, { uid = entry.uid, ember = bankItem(self, player, entry) }
end

local function described(entry)
	return { uid = entry.uid, kind = entry.kind, species = entry.species, quantity = entry.quantity }
end

-- The first real strike (D6): the newest unprotected pending item leaves the bag and lies on the ground.
-- Idempotent per attack id. Returns true and a copy of the dropped entry, or true and nil for mark only.
function State:dropForStrike(key, attackId)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(attackId) then return false, "InvalidOperation" end
	if player.strikeDrops[attackId] ~= nil then return true, nil end
	player.strikeDrops[attackId] = true
	table.insert(player.strikeOrder, attackId)
	if #player.strikeOrder > STRIKE_HISTORY then
		player.strikeDrops[table.remove(player.strikeOrder, 1)] = nil
	end
	for index = #player.pending, 1, -1 do
		local entry = player.pending[index]
		if not entry.protected then
			table.remove(player.pending, index)
			table.insert(player.dropped, entry)
			return true, table.clone(entry)
		end
	end
	return true, nil
end

-- Only the owner, alive, within 10 studs and with bag room puts a dropped item back in the bag.
function State:reclaimDropped(key, uid, alive, distance)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local index, entry = find(player.dropped, uid)
	if not index then return false, "NotOwnedDropped" end
	if not context(alive, distance, 10) then return false, "InvalidContext" end
	if #player.pending >= bagCapacity(self, player) then return false, "BackpackFull" end
	table.remove(player.dropped, index)
	table.insert(player.pending, entry)
	return true, entry.uid
end

-- A drop that expired on the ground is gone for good.
function State:loseDropped(key, uid)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	local index, entry = find(player.dropped, uid)
	if not index then return false, "NotOwnedDropped" end
	table.remove(player.dropped, index)
	return true, described(entry)
end

-- Which bag items a defeat right now would keep. The one rule for both defeat and the risk preview.
local function survivors(player)
	local kept = {}
	local seal, totem = warded(player, "Seal"), warded(player, "Totem")
	if seal and player.consumables.seal > 0 then kept[seal] = "Seal" end
	if totem and player.totemActive then kept[totem] = "Totem" end
	return kept
end

-- What each carried stack would lose, listing only stacks that lose something.
local function materialLoss(self, player)
	local basis = self.economy.lossBasisPoints(self.config, player.upgrades)
	local losses = {}
	for material, quantity in pairs(player.carried) do
		local lost = self.economy.lost(quantity, basis)
		if lost > 0 then losses[material] = lost end
	end
	return losses
end

local function bankedTotal(player)
	local total = 0
	for _, quantity in pairs(player.banked) do total += quantity end
	return total
end

-- Returns true, the number of items lost and a detached loss summary. A repeated operation id loses
-- nothing and returns no summary. Ember, banked materials, banked eggs and registered pets are never
-- touched. Order per the economy document: warded items (a seal is spent only if it saves), other bag
-- items, dropped items, half of each carried stack (a quarter with the Reinforced Pack), then the
-- expedition closes and spends an active totem.
function State:defeat(key, operationId)
	local player = profile(self, key)
	if not player then return false, "InvalidPlayer" end
	if not validId(operationId) then return false, "InvalidOperation" end
	if player.defeats[operationId] then return true, 0 end
	player.defeats[operationId] = true
	table.insert(player.defeatOrder, operationId)
	if #player.defeatOrder > DEFEAT_HISTORY then
		player.defeats[table.remove(player.defeatOrder, 1)] = nil
	end
	local kept = survivors(player)
	local lostItems, savedItems, remaining = {}, {}, {}
	for _, entry in ipairs(player.pending) do
		if kept[entry] then table.insert(remaining, entry) else table.insert(lostItems, described(entry)) end
	end
	for _, entry in ipairs(player.dropped) do table.insert(lostItems, described(entry)) end
	player.pending, player.dropped = {}, {}
	for _, entry in ipairs(remaining) do
		if kept[entry] == "Seal" then player.consumables.seal -= 1 end
		entry.protected, entry.wardSource = false, nil
		table.insert(player.pending, entry)
		table.insert(savedItems, described(entry))
	end
	local materialsLost = materialLoss(self, player)
	for material, lost in pairs(materialsLost) do player.carried[material] -= lost end
	closeExpedition(self, player)
	return true, #lostItems, {
		operationId = operationId, lostItems = lostItems, savedItem = savedItems[1], savedItems = savedItems,
		materialsLost = materialsLost,
		kept = { registered = #player.registered, bankedEggs = #player.bankedEggs, ember = player.ember,
			bankedMaterials = bankedTotal(player) },
	}
end

function State:isClaimed(id)
	if not validId(id) then return false end
	local encounter = self.encounters[id]
	return encounter ~= nil and encounter.claimed == true
end

local function bondCopy(player)
	local out = {}
	for uid, entry in pairs(player.bond) do out[uid] = { xp = entry.xp, level = entry.level } end
	return out
end

function State:snapshot(key)
	local player = profile(self, key)
	if not player then return nil end
	local kept = survivors(player)
	local keep = 0
	for _ in pairs(kept) do keep += 1 end
	local expedition = player.expedition
	return {
		sessionOnly = true, capacity = bagCapacity(self, player), collectionLimit = self.config.capacity.collectionLimit,
		pending = copy(player.pending), bankedEggs = copy(player.bankedEggs),
		registered = copy(player.registered), dropped = copy(player.dropped), equippedUid = player.equippedUid,
		sealCharges = player.consumables.seal,
		carried = table.clone(player.carried), banked = table.clone(player.banked),
		pouchCapacity = self.economy.pouchCapacity(self.config, player.upgrades), ember = player.ember,
		consumables = table.clone(player.consumables), upgrades = table.clone(player.upgrades),
		sealArmed = player.sealArmed, totemActive = player.totemActive,
		skills = table.clone(player.skills), bond = bondCopy(player),
		pendingBondXp = player.expedition and player.expedition.bondXp or 0,
		expedition = expedition and { startedAt = expedition.startedAt,
			maxDistanceFromCamp = expedition.maxDistanceFromCamp, newUnits = expedition.newUnits,
			newItems = expedition.newItems } or nil,
		-- What a defeat right now would cost, computed by the same rules defeat uses (HUD, M5.8).
		riskPreview = { loseItems = #player.pending - keep + #player.dropped, keep = keep,
			loseMaterials = materialLoss(self, player) },
	}
end

return State
