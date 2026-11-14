-- Egg loop (docs/design/wildbound-egg-loop.md): the pure rules that make "steal, carry, bank, incubate, hatch, again"
-- readable. Shared through ReplicatedStorage: the server picks the egg that goes into a free cradle and writes the
-- reward on a player attribute; the clients read the same snapshot to word the objective line, the reward toast, the
-- cradle's sign, the stored-egg row and the hatch banner. No service, no clock, no world: the caller passes them.
local EggLoop = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

-- PROPUESTA (owner): presentation only, none of these changes a reward, a time or a price.
-- REWARD_TOAST_SECONDS / HATCH_BANNER_SECONDS: time on screen. SHELF_MAX: stored eggs drawn beside the cradle before
-- "+N". SPARKLES / SPARKLES_REDUCED: particles in one burst, normal and with "Efectos suaves".
EggLoop.CONFIG = freeze({
	REWARD_TOAST_SECONDS = 3.5,
	HATCH_BANNER_SECONDS = 4,
	SHELF_MAX = 6,
	SPARKLES = 40,
	SPARKLES_REDUCED = 12,
})

EggLoop.RARITIES = freeze({ "Comun", "Rara", "Epica", "Legendaria" })
local KNOWN = { Comun = true, Rara = true, Epica = true, Legendaria = true }
-- The island reward tiers (WildboundSpecies.byRarity: Safe and Fog Comun, FogFar Rara, Territory Epica, Heart
-- Legendaria), used only when the species gives no rarity.
EggLoop.RARITY_BY_TIER = freeze({ Safe = "Comun", Fog = "Comun", FogFar = "Rara", Territory = "Epica", Heart = "Legendaria" })
-- The server's RARITY_GLOW colours (WildboundServer), so the toast, the row and the nest glow agree.
EggLoop.RARITY_COLOR = freeze({
	Comun = { 205, 235, 215 }, Rara = { 110, 175, 255 }, Epica = { 190, 120, 255 }, Legendaria = { 255, 205, 80 },
})

-- An egg's rarity: its own field, else its species' (looks = WildboundSpecies.LOOKS), else its risk tier, else Comun.
function EggLoop.rarityOf(egg, looks)
	if type(egg) ~= "table" then return "Comun" end
	if KNOWN[egg.rarity] then return egg.rarity end
	local look = type(looks) == "table" and type(egg.species) == "string" and looks[egg.species] or nil
	if type(look) == "table" and KNOWN[look.rarity] then return look.rarity end
	return EggLoop.RARITY_BY_TIER[egg.riskTier] or "Comun"
end

local function slotCount(slots)
	return finite(slots) and math.max(1, math.floor(slots)) or 1
end

-- Facts from one state snapshot (WildboundState:snapshot), tolerating any missing or odd field.
-- { carryingEgg, stored, incubating, soonest (readyAt or nil), registered, slots }.
function EggLoop.facts(snapshot, slots)
	snapshot = type(snapshot) == "table" and snapshot or {}
	local carrying = false
	for _, entry in ipairs(type(snapshot.pending) == "table" and snapshot.pending or {}) do
		if type(entry) == "table" and entry.kind == "Egg" and entry.inArms == true then carrying = true end
	end
	local incubating = type(snapshot.incubating) == "table" and snapshot.incubating or {}
	local soonest = nil
	for _, entry in ipairs(incubating) do
		if type(entry) == "table" and finite(entry.readyAt) and (soonest == nil or entry.readyAt < soonest) then
			soonest = entry.readyAt
		end
	end
	return {
		carryingEgg = carrying,
		stored = type(snapshot.bankedEggs) == "table" and #snapshot.bankedEggs or 0,
		incubating = #incubating,
		soonest = soonest,
		registered = type(snapshot.registered) == "table" and #snapshot.registered or 0,
		slots = slotCount(slots),
	}
end

-- The objective line's state machine: "carry", "incubate", "again" or "steal", in that priority.
function EggLoop.objective(f)
	if type(f) ~= "table" then return "steal" end
	if f.carryingEgg == true then return "carry" end
	local stored, incubating = tonumber(f.stored) or 0, tonumber(f.incubating) or 0
	if stored > 0 and incubating < slotCount(f.slots) then return "incubate" end
	if incubating > 0 or stored > 0 or (tonumber(f.registered) or 0) > 0 then return "again" end
	return "steal"
end

-- Whole seconds as "m:ss".
function EggLoop.clock(seconds)
	local whole = finite(seconds) and math.max(0, math.ceil(seconds - 1e-9)) or 0
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

-- The objective line's words (Text.LOOP) and its id. now = the server clock.
function EggLoop.objectiveText(f, now, Text)
	local id = EggLoop.objective(f)
	local L = type(Text) == "table" and Text.LOOP or nil
	if type(L) ~= "table" then return nil, id end
	if id == "again" and (tonumber(f.incubating) or 0) > 0 and finite(f.soonest) and finite(now) then
		local left = f.soonest - now
		if left > 0 then return L.againTimer:format(EggLoop.clock(left)), id end
		return L.againReady, id
	end
	return L[id], id
end

-- The stored egg that goes into a free cradle: the oldest one (first in, first out), or nil when every cradle is busy
-- or nothing is stored.
function EggLoop.nextToIncubate(bankedEggs, incubatingCount, slots)
	if type(bankedEggs) ~= "table" then return nil end
	local busy = finite(incubatingCount) and incubatingCount or 0
	if busy >= slotCount(slots) then return nil end
	for _, egg in ipairs(bankedEggs) do
		if type(egg) == "table" and validId(egg.uid) then return egg.uid end
	end
	return nil
end

-- The reward travels on one player attribute (WildboundEggReward) as "1|species|rarity|ember|stored|incubating|nonce";
-- the nonce makes every bank a new value, so the client's change signal fires each time.
function EggLoop.encodeReward(reward)
	if type(reward) ~= "table" or type(reward.species) ~= "string" or reward.species:find("[|\n]") then return nil end
	local rarity = KNOWN[reward.rarity] and reward.rarity or "Comun"
	local ember = finite(reward.ember) and math.max(0, math.floor(reward.ember)) or 0
	local stored = finite(reward.stored) and math.max(0, math.floor(reward.stored)) or 0
	local nonce = finite(reward.nonce) and reward.nonce or 0
	return ("1|%s|%s|%d|%d|%d|%.3f"):format(reward.species, rarity, ember, stored, reward.incubating == true and 1 or 0,
		nonce)
end

function EggLoop.decodeReward(value)
	if type(value) ~= "string" then return nil end
	local species, rarity, ember, stored, incubating = value:match("^1|([^|\n]+)|(%a+)|(%d+)|(%d+)|([01])|[%d%.%-]+$")
	if not species or not KNOWN[rarity] then return nil end
	return { species = species, rarity = rarity, ember = tonumber(ember), stored = tonumber(stored),
		incubating = incubating == "1" }
end

local function speciesName(Text, species)
	local names = type(Text.CARD) == "table" and type(Text.CARD.species) == "table" and Text.CARD.species or {}
	return names[species] or tostring(species)
end

local function rarityWord(Text, rarity)
	return type(Text.RARITY) == "table" and Text.RARITY[rarity] or tostring(rarity)
end

-- The reward toast: title, the egg's line and what happened to it. An egg that pays no Esencia (the Safe tier has no
-- row in eggEmberByTier; Play check 2026-11-12) shows no "+0": just its name and rarity.
function EggLoop.rewardLines(reward, Text)
	if type(reward) ~= "table" or type(Text) ~= "table" or type(Text.LOOP) ~= "table" then return nil end
	local L = Text.LOOP
	local name, rarity = speciesName(Text, reward.species), rarityWord(Text, reward.rarity)
	local ember = finite(reward.ember) and reward.ember or 0
	local line = ember > 0 and L.bankedLine:format(name, rarity, ember) or L.eggRow:format(name, rarity)
	local sub = reward.incubating and L.bankedIncubating or L.bankedStored:format(reward.stored or 0)
	return { title = L.bankedTitle, line = line, sub = sub }
end

-- The cradle's sign over the own base's incubator. entry = the first incubating egg or nil; stored = stored eggs.
-- Returns the text and its state: "busy", "ready", "freeEggs" (glows: an egg can go in) or "free".
function EggLoop.cradleLine(entry, now, stored, Text)
	local L = type(Text) == "table" and Text.LOOP or nil
	if type(L) ~= "table" then return nil, nil end
	if type(entry) == "table" and finite(entry.readyAt) and finite(now) then
		local left = entry.readyAt - now
		if left <= 0 then return L.cradleReady, "ready" end
		return L.cradleBusy:format(speciesName(Text, entry.species), EggLoop.clock(left)), "busy"
	end
	if finite(stored) and stored > 0 then return L.cradleFreeEggs, "freeEggs" end
	return L.cradleFree, "free"
end

-- The row of stored eggs beside the cradle: at most max rarities (oldest first) and how many more there are.
function EggLoop.shelf(bankedEggs, max, looks)
	local shown, extra = {}, 0
	local limit = finite(max) and math.max(0, math.floor(max)) or EggLoop.CONFIG.SHELF_MAX
	for _, egg in ipairs(type(bankedEggs) == "table" and bankedEggs or {}) do
		if #shown < limit then table.insert(shown, EggLoop.rarityOf(egg, looks)) else extra += 1 end
	end
	return { rarities = shown, extra = extra }
end

-- The hatch banner: "¡Nuevo compañero!" and where the creature went (following you, or in the collection).
function EggLoop.hatchLines(card, equippedUid, Text)
	if type(card) ~= "table" or type(Text) ~= "table" or type(Text.LOOP) ~= "table" then return nil end
	local L = Text.LOOP
	local name = speciesName(Text, card.species)
	local follows = card.uid ~= nil and card.uid == equippedUid
	return { title = L.hatchTitle, line = (follows and L.hatchFollows or L.hatchStored):format(name) }
end

-- One stored egg's inventory row: "Huevo de Lumipol · Común".
function EggLoop.eggRow(egg, looks, Text)
	if type(egg) ~= "table" or type(Text) ~= "table" or type(Text.LOOP) ~= "table" then return nil end
	return Text.LOOP.eggRow:format(speciesName(Text, egg.species), rarityWord(Text, EggLoop.rarityOf(egg, looks)))
end

return EggLoop
