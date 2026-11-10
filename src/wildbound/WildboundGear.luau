-- Gloves with rolled stats, and the luck totem (Nest Heist Phase 3, NS7; items and totem, plan Part 4). Pure and
-- shared: the server rolls, saves and applies a glove; the clients word it. User decision 2026-11-10: the four pieces
-- of equipment (Guantes de captura, Botas, Chaleco, Amuleto) became gloves with random stats.
--
-- A glove is crafted at camp with Esencia and materials (the config's `gear.guantes` row, kind "gloves"; nothing is sold,
-- never paid randomness). The server rolls its rarity (WEIGHT_*) and then 1 to 4 different stats inside the rarity's
-- share of each stat's cap. One glove is equipped at a time; the gloves are saved (record schema 3).
-- Stats (percent): move (walk speed), steal (egg steal hold), burst (Burst recovery), drain (sprint stamina drain,
-- the old Botas), calm (capture calm speed, the old Guantes de captura). No stamina or luck stats, no abilities: no
-- stealth, no hit immunity (the Chaleco is gone), no keeping the egg, no bat reach or stun, no fear relief (the
-- Amuleto is gone; the free Efectos suaves setting softens the fear screen more than it did).
-- Caps: every stat is capped (*_CAP, never above HARD_CAPS even when tuned). The walk speed from training and a glove
-- together stays under WildboundTraining.WALK_CAP (16 since HF-T4); sprint (24) and Burst (28) keep the stamina caps.
--
-- Items IT2: the Tótem de la suerte (Gear.LUCK, a "luckTotem" recipe, one held at a time) is placed at least LUCK_CAMP
-- studs from the camp centre and stands LUCK_SECONDS. The next random spawn inside LUCK_RADIUS rolls one tier up (the
-- spawn clock prefers a free point there); with LUCK_LURE 1 it draws one spawn in at once. It makes a ring-level noise
-- when placed and every LUCK_NOISE_EVERY seconds, so La Silueta can hear it.
local Gear = {}

Gear.LUCK = "totemSuerte"
Gear.GLOVES = "guantes"
Gear.RARITIES = table.freeze({ "Comun", "Rara", "Epica", "Legendaria" })
Gear.STATS = table.freeze({ "move", "steal", "burst", "drain", "calm" })
-- Per rarity: how many stats, and the share of each stat's cap a roll lands in.
Gear.RARITY = table.freeze({
	Comun = table.freeze({ stats = 1, low = 0.25, high = 0.5 }),
	Rara = table.freeze({ stats = 2, low = 0.35, high = 0.6 }),
	Epica = table.freeze({ stats = 3, low = 0.5, high = 0.8 }),
	Legendaria = table.freeze({ stats = 4, low = 0.7, high = 1 }),
})
-- No tuning may push a stat past these.
Gear.HARD_CAPS = table.freeze({ move = 3, steal = 25, burst = 30, drain = 40, calm = 40 })
local CAP_KEY = table.freeze({ move = "MOVE_CAP", steal = "STEAL_CAP", burst = "BURST_CAP", drain = "DRAIN_CAP",
	calm = "CALM_CAP" })
local WEIGHT_KEY = table.freeze({ Comun = "WEIGHT_COMUN", Rara = "WEIGHT_RARA", Epica = "WEIGHT_EPICA",
	Legendaria = "WEIGHT_LEGENDARIA" })

Gear.CONSTANTS = table.freeze({
	MOVE_CAP = 3,
	STEAL_CAP = 15,
	BURST_CAP = 20,
	DRAIN_CAP = 30,
	CALM_CAP = 30,
	WEIGHT_COMUN = 60,
	WEIGHT_RARA = 28,
	WEIGHT_EPICA = 10,
	WEIGHT_LEGENDARIA = 2,
	GLOVE_LIMIT = 12,
	STEAL_FLOOR = 0.6, -- seconds: no glove shortens a steal hold under the egg rule's own minimum
	LUCK_SECONDS = 60,
	LUCK_RADIUS = 40,
	LUCK_NOISE_EVERY = 10,
	LUCK_LURE = 1,
	LUCK_CAMP = 30,
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning: CONSTANTS stay the defaults the tests pin; the bridge (server) and the panel (client) override `live`.
local C = {}
Gear.live = C

function Gear.tunable()
	return table.clone(Gear.CONSTANTS)
end

function Gear.tune(overrides)
	for key, value in pairs(Gear.CONSTANTS) do C[key] = value end
	if type(overrides) ~= "table" then return end
	for key, value in pairs(overrides) do
		if Gear.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
	end
end
Gear.tune(nil)

-- The live cap of one stat, in percent, never above its hard cap.
function Gear.cap(stat)
	local key, hard = CAP_KEY[stat], Gear.HARD_CAPS[stat]
	if not key then return 0 end
	return math.clamp(finite(C[key]) and C[key] or 0, 0, hard)
end

local function round1(value)
	return math.floor(value * 10 + 0.5) / 10
end

-- random() returns a number in [0, 1). Weighted by WEIGHT_*.
function Gear.rollRarity(random)
	local total = 0
	for _, rarity in ipairs(Gear.RARITIES) do total += math.max(0, C[WEIGHT_KEY[rarity]] or 0) end
	if total <= 0 then return "Comun" end
	local pick = random() * total
	for _, rarity in ipairs(Gear.RARITIES) do
		pick -= math.max(0, C[WEIGHT_KEY[rarity]] or 0)
		if pick < 0 then return rarity end
	end
	return Gear.RARITIES[#Gear.RARITIES]
end

-- A new glove: { rarity, stats = { [stat] = percent } }. The rarity is rolled unless given.
function Gear.roll(random, rarity)
	rarity = Gear.RARITY[rarity] and rarity or Gear.rollRarity(random)
	local spec = Gear.RARITY[rarity]
	local pool = table.clone(Gear.STATS)
	local stats = {}
	for _ = 1, math.min(spec.stats, #pool) do
		local index = math.clamp(math.floor(random() * #pool) + 1, 1, #pool)
		local stat = table.remove(pool, index)
		local cap = Gear.cap(stat)
		stats[stat] = math.max(0.1, math.min(cap, round1(cap * (spec.low + (spec.high - spec.low) * random()))))
	end
	return { rarity = rarity, stats = stats }
end

-- A glove's shape: a known rarity and 1 to 4 known stats, each above 0 and at most its hard cap.
function Gear.valid(glove)
	if type(glove) ~= "table" or not Gear.RARITY[glove.rarity] or type(glove.stats) ~= "table" then return false end
	local count = 0
	for stat, value in pairs(glove.stats) do
		if not Gear.HARD_CAPS[stat] or not finite(value) or value <= 0 or value > Gear.HARD_CAPS[stat] then return false end
		count += 1
	end
	return count >= 1 and count <= #Gear.STATS
end

-- The percent a glove gives for one stat, capped by the live cap; 0 without a glove.
function Gear.effect(glove, stat)
	if type(glove) ~= "table" or type(glove.stats) ~= "table" then return 0 end
	local value = glove.stats[stat]
	if not finite(value) or value <= 0 then return 0 end
	return math.min(value, Gear.cap(stat))
end

function Gear.calmRate(glove) return 1 + Gear.effect(glove, "calm") / 100 end
function Gear.drainScale(glove) return 1 - Gear.effect(glove, "drain") / 100 end
function Gear.burstScale(glove) return 1 - Gear.effect(glove, "burst") / 100 end
function Gear.stealScale(glove) return 1 - Gear.effect(glove, "steal") / 100 end
-- Walk studs/s from the move stat; WildboundTraining.walkSpeed applies it under its WALK_CAP.
function Gear.moveBonus(glove, base)
	if not finite(base) then return 0 end
	return base * Gear.effect(glove, "move") / 100
end

-- A steal hold shortened by the glove, never under the floor the egg rule keeps.
function Gear.stealHold(hold, glove, floor)
	if not finite(hold) then return hold end
	return math.max(finite(floor) and floor or 0, hold * Gear.stealScale(glove))
end

-- "4,7": one decimal, a decimal comma.
function Gear.percent(value)
	return (string.gsub(string.format("%.1f", finite(value) and value or 0), "%.", ","))
end

-- The glove's stats in Spanish, in the fixed stat order: { "+4,7% Velocidad", ... }.
function Gear.describe(glove, Text)
	local lines = {}
	local names = Text and Text.GEAR and Text.GEAR.stats or {}
	for _, stat in ipairs(Gear.STATS) do
		local value = type(glove) == "table" and type(glove.stats) == "table" and glove.stats[stat]
		if finite(value) and value > 0 then
			table.insert(lines, "+" .. Gear.percent(value) .. "% " .. tostring(names[stat] or stat))
		end
	end
	return lines
end

return Gear
