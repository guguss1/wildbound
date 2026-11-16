-- Oro (gold), the second currency (owner request 2026-11-16, odd/tasks/wildbound-gold.md). Pure and shared
-- (ReplicatedStorage): no services, clock or randomness; the server (WildboundGoldService) passes the time and the
-- player's numbers, the camp screen words the prices. Gold is earned while playing: creatures in the base farm produce
-- it over time (more for rarer ones), a newly tamed or hatched creature pays a small bonus, and treadmill laps pay it
-- (more at higher training levels) up to a per-minute cap. Gold buys the farm's extra places and treadmill levels, in
-- addition to their Esencia prices. It is never sold for real money (monetization stays "none").
local Gold = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Gold per minute for one creature in the farm, by its species' rarity (WildboundSpecies.LOOKS[...].rarity).
-- Owner feedback 3 (2026-11-16, "los bichos dan muy poco oro"): about x3.5 (was 2/3/5/8), tame bonus 20 (was 5), a
-- lap 2 (was 1) and the treadmill cap 10 a minute (was 6).
-- Legendaria (30/min, sale 400) is unused today: no live egg hatches a Legendaria species (kept for a later one).
Gold.FARM_PER_MINUTE = table.freeze({ Comun = 7, Rara = 10, Epica = 18, Legendaria = 30 })
Gold.DEFAULT_RARITY = "Comun" -- a species with no known rarity (the candy critters) counts as common
-- Gold follow-up (owner OK 2026-11-16, economy sim O7): 10, was 20 (with the fast base incubator the bonus alone paid up
-- to 37 gold a minute).
Gold.TAME_BONUS = 10 -- one creature registered (tamed) or hatched
Gold.LAP_BASE = 2 -- gold per completed treadmill lap at level 0..3
Gold.LAP_LEVELS_PER_EXTRA = 4 -- +1 gold per lap for every 4 training levels (level 17: 6 per lap)
Gold.TREADMILL_CAP_PER_MINUTE = 10 -- anti-AFK: the treadmill never pays more than this in one minute
-- Owner feedback 3: "Vender" a creature pays its rarity's price, +20% per bond level above 1 (capped at level 10).
Gold.SELL_PRICES = table.freeze({ Comun = 25, Rara = 60, Epica = 150, Legendaria = 400 })
Gold.SELL_LEVEL_BONUS = 0.2
Gold.SELL_MAX_LEVEL = 10
Gold.CAP_WINDOW = 60
-- Gold prices, in addition to the Esencia ones (WildboundEconomyConfig upgrades, WildboundTraining.cost).
-- Gold follow-up: farm places 7 and 8 and a steeper treadmill ladder (x1.25, was x1.15), so gold keeps something to buy
-- (every gold sink: 7521, was 2164; docs/balance/wildbound-2-0-economy-sim.md "Gold (Oro) results").
Gold.UPGRADE_PRICES = table.freeze({ farmSlot5 = 60, farmSlot6 = 150, farmSlot7 = 600, farmSlot8 = 1500 })
Gold.TRAIN_BASE = 30 -- gold for training level 1
Gold.TRAIN_GROWTH = 1.25 -- each next level costs this much more, rounded (30, 38, 47 ... the 17th level: 1066)
Gold.POPUP_SECONDS = 4 -- earned gold is shown as one "+N oro" at most this often
Gold.TICK = 1 -- seconds between the server's gold steps
-- Gold follow-up: the farm pays nothing while its owner has not moved IDLE_MOVE_STUDS across the ground for
-- IDLE_SECONDS. The server reads the character's position itself (the client never reports idleness); standing on the
-- treadmill counts as still, and the treadmill keeps its own per-minute cap.
Gold.IDLE_SECONDS = 300
Gold.IDLE_MOVE_STUDS = 6

-- Gold per minute of a farm: `species` is a list of species names, `rarityOf(name)` returns a rarity word or nil.
function Gold.farmRate(species, rarityOf)
	local total = 0
	if type(species) ~= "table" then return 0 end
	for _, name in ipairs(species) do
		local rarity = type(rarityOf) == "function" and rarityOf(name) or nil
		total += Gold.FARM_PER_MINUTE[rarity] or Gold.FARM_PER_MINUTE[Gold.DEFAULT_RARITY]
	end
	return total
end

-- Whole gold earned over `seconds` at `perMinute`, and the fraction carried to the next step (kept below 1).
function Gold.accrue(carry, perMinute, seconds)
	carry = finite(carry) and carry >= 0 and carry or 0
	if not finite(perMinute) or perMinute <= 0 or not finite(seconds) or seconds <= 0 then return 0, carry end
	local amount = carry + perMinute * math.min(seconds, 60) / 60
	local whole = math.floor(amount + 1e-9) -- 60 steps of 1/30 must make 2, not 1.999...
	return whole, math.max(0, amount - whole)
end

-- Gold for one completed treadmill lap at a training level.
function Gold.lapGold(level)
	level = finite(level) and level >= 0 and math.floor(level) or 0
	return Gold.LAP_BASE + level // Gold.LAP_LEVELS_PER_EXTRA
end

-- The anti-AFK cap. window = { startedAt, paid } (nil starts one); returns the gold actually paid and the window.
function Gold.capLap(window, now, amount)
	if type(window) ~= "table" or not finite(window.startedAt) or not finite(now) or now - window.startedAt >= Gold.CAP_WINDOW
		or now < window.startedAt then
		window = { startedAt = finite(now) and now or 0, paid = 0 }
	end
	amount = finite(amount) and amount > 0 and math.floor(amount) or 0
	local paid = math.max(0, math.min(amount, Gold.TREADMILL_CAP_PER_MINUTE - window.paid))
	window.paid += paid
	return paid, window
end

-- Idle watch. track = { x, z, movedAt } (nil starts one at the first position). A move of IDLE_MOVE_STUDS or more across
-- the ground from the last anchor resets the clock; a small shuffle or a jump in place does not. No position (no
-- character) leaves the track as it is.
function Gold.watch(track, x, z, now)
	if not finite(x) or not finite(z) or not finite(now) then return track end
	if type(track) ~= "table" or not finite(track.movedAt) then return { x = x, z = z, movedAt = now } end
	local dx, dz = x - track.x, z - track.z
	if dx * dx + dz * dz >= Gold.IDLE_MOVE_STUDS * Gold.IDLE_MOVE_STUDS then
		track.x, track.z, track.movedAt = x, z, now
	end
	return track
end

-- Whether the farm is paused: the player has stood still for IDLE_SECONDS. No track yet is never idle.
function Gold.idle(track, now)
	return type(track) == "table" and finite(track.movedAt) and finite(now) and now - track.movedAt >= Gold.IDLE_SECONDS
end

-- The gold price of a camp upgrade, or nil when it cannot be bought with gold.
function Gold.upgradePrice(name)
	return type(name) == "string" and Gold.UPGRADE_PRICES[name] or nil
end

-- The gold price of the next training level from `level`, or nil at the cap.
function Gold.trainPrice(level, maxLevel)
	if not finite(level) or level < 0 or not finite(maxLevel) or level >= maxLevel then return nil end
	return math.floor(Gold.TRAIN_BASE * Gold.TRAIN_GROWTH ^ math.floor(level) + 0.5)
end

-- The gold a creature sells for: its rarity's price (an unknown rarity sells as common) and its bond level's bonus.
function Gold.sellPrice(rarity, level)
	local base = Gold.SELL_PRICES[rarity] or Gold.SELL_PRICES[Gold.DEFAULT_RARITY]
	level = finite(level) and math.clamp(math.floor(level), 1, Gold.SELL_MAX_LEVEL) or 1
	return math.floor(base * (1 + Gold.SELL_LEVEL_BONUS * (level - 1)) + 0.5)
end

-- Popup batching: earned gold is added to the buffer and shown at most once per POPUP_SECONDS.
function Gold.batch(buffer, amount)
	buffer = type(buffer) == "table" and buffer or { pending = 0, shownAt = -math.huge }
	if finite(amount) and amount > 0 then buffer.pending += math.floor(amount) end
	return buffer
end

-- The amount to show now (and clears it), or nil when nothing is due yet.
function Gold.flush(buffer, now)
	if type(buffer) ~= "table" or buffer.pending <= 0 or not finite(now) then return nil end
	if now - buffer.shownAt < Gold.POPUP_SECONDS then return nil end
	local amount = buffer.pending
	buffer.pending, buffer.shownAt = 0, now
	return amount
end

return Gold
