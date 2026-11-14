-- Training station rules (Nest Heist Phase 3, NS5). Pure and shared (ReplicatedStorage): the server prices and
-- applies a level, the camp screen words it. Levels are bought with Esencia (Ember internally) at the camp's
-- "Entrenamiento" treadmill and are saved (WildboundRecord schema 2, `training`).
--
-- Speed rule (PF2, user decision 2026-11-14: "como Steal an Egg, muchísimo"; replaces HF-T4 / Q9's cap of 16): each
-- walk level adds WALK_STEP studs/s to the unencumbered walk speed, up to MAX_LEVEL, and the walk speed from training
-- plus any other bonus never passes WALK_CAP (16 + 2 x 17 = 50). Laps on the treadmill grant the levels. A carrier (an
-- egg in the arms, a heavy pouch, a carried creature) keeps the same share of the trained walk that the carry leaves
-- of the base walk (one egg: 11/16 of it), so training is felt while carrying and carrying still costs speed. The
-- sprint and the Burst never slow a trained walk (Stamina.speed keeps the faster of the walk and their capped speed).
-- La Silueta and the parents were not retuned: a trained walker outruns them (an open product question). The old
-- simulator (tools/simulate_economy.py) was retired on 2026-11-14 in favour of tools/wildbound_economy_sim_v2.py.
local Training = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

Training.CONSTANTS = table.freeze({
	WALK_STEP = 2, -- studs/s per level (PF2; was 0.25)
	MAX_LEVEL = 17, -- PF2 (was 4): 17 laps of the belt from 16 to the cap
	-- Unencumbered walk speed ceiling for every bonus together. PF2: 50 (HF-T4 had 16, the base walk).
	WALK_CAP = 50,
	BASE_COST = 30, -- Esencia for level 1
	COST_GROWTH = 1.2, -- each next level costs this much more, rounded (PF2: was 1.6; level 17 costs 555)
	RANGE = 12, -- studs from the treadmill to use it
})
Training.KINDS = table.freeze({ "walk" })

local TUNABLE = { "WALK_STEP", "MAX_LEVEL", "WALK_CAP", "BASE_COST", "COST_GROWTH" }
Training.live = {}

function Training.tunable()
	local defaults = {}
	for _, key in ipairs(TUNABLE) do defaults[key] = Training.CONSTANTS[key] end
	return defaults
end

function Training.tune(overrides)
	table.clear(Training.live)
	for key, value in pairs(Training.CONSTANTS) do Training.live[key] = value end
	if type(overrides) ~= "table" then return end
	for _, key in ipairs(TUNABLE) do
		local value = overrides[key]
		if finite(value) and value >= 0 then Training.live[key] = value end
	end
	Training.live.MAX_LEVEL = math.floor(Training.live.MAX_LEVEL)
end
Training.tune(nil)

local function levelOf(training, kind)
	local level = type(training) == "table" and training[kind] or 0
	if not finite(level) or level < 0 then return 0 end
	return math.min(math.floor(level), Training.live.MAX_LEVEL)
end
Training.level = levelOf

-- Esencia for the next level of `kind` from `level`, or nil when at the cap.
function Training.cost(level)
	local C = Training.live
	if not finite(level) or level < 0 or level >= C.MAX_LEVEL then return nil end
	return math.floor(C.BASE_COST * C.COST_GROWTH ^ math.floor(level) + 0.5)
end

-- The walk bonus in studs/s a profile's training gives.
function Training.walkBonus(training)
	return levelOf(training, "walk") * Training.live.WALK_STEP
end

-- speed: the walk speed after carry costs; base: the unencumbered walk speed (EconomyConfig.carry.baseSpeed);
-- extra: any other walk bonus (studs/s). An unencumbered walk gains the bonus up to WALK_CAP; a slowed walk keeps its
-- share (speed / base) of that trained walk. Never slower than speed.
function Training.walkSpeed(speed, base, training, extra)
	if not finite(speed) or not finite(base) or base <= 0 then return speed end
	local bonus = Training.walkBonus(training) + (finite(extra) and math.max(0, extra) or 0)
	if bonus <= 0 then return speed end
	local cap = Training.live.WALK_CAP
	if speed < base then
		return math.max(speed, speed * math.min(base + bonus, cap) / base)
	end
	return math.max(speed, math.min(speed + bonus, cap))
end

return Training
