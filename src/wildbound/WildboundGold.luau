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
Gold.FARM_PER_MINUTE = table.freeze({ Comun = 2, Rara = 3, Epica = 5, Legendaria = 8 })
Gold.DEFAULT_RARITY = "Comun" -- a species with no known rarity (the candy critters) counts as common
Gold.TAME_BONUS = 5 -- one creature registered (tamed) or hatched
Gold.LAP_BASE = 1 -- gold per completed treadmill lap at level 0..3
Gold.LAP_LEVELS_PER_EXTRA = 4 -- +1 gold per lap for every 4 training levels (level 17: 5 per lap)
Gold.TREADMILL_CAP_PER_MINUTE = 6 -- anti-AFK: the treadmill never pays more than this in one minute
Gold.CAP_WINDOW = 60
-- Gold prices, in addition to the Esencia ones (WildboundEconomyConfig upgrades, WildboundTraining.cost).
Gold.UPGRADE_PRICES = table.freeze({ farmSlot5 = 60, farmSlot6 = 150 })
Gold.TRAIN_BASE = 30 -- gold for training level 1
Gold.TRAIN_GROWTH = 1.15 -- each next level costs this much more, rounded (the 17th level: 281)
Gold.POPUP_SECONDS = 4 -- earned gold is shown as one "+N oro" at most this often
Gold.TICK = 1 -- seconds between the server's gold steps

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

-- The gold price of a camp upgrade, or nil when it cannot be bought with gold.
function Gold.upgradePrice(name)
	return type(name) == "string" and Gold.UPGRADE_PRICES[name] or nil
end

-- The gold price of the next training level from `level`, or nil at the cap.
function Gold.trainPrice(level, maxLevel)
	if not finite(level) or level < 0 or not finite(maxLevel) or level >= maxLevel then return nil end
	return math.floor(Gold.TRAIN_BASE * Gold.TRAIN_GROWTH ^ math.floor(level) + 0.5)
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
