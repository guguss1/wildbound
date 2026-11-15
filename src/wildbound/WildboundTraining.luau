-- Training station rules (Nest Heist Phase 3, NS5). Pure and shared (ReplicatedStorage): the server prices and
-- applies a level, the camp screen words it. Levels are bought with Esencia (Ember internally) at the camp's
-- "Entrenamiento" treadmill and are saved (WildboundRecord schema 2, `training`).
--
-- Speed rule (PF2, user decision 2026-11-14: "como Steal an Egg, muchísimo"; replaces HF-T4 / Q9's cap of 16): each
-- walk level adds WALK_STEP studs/s to the unencumbered walk speed, up to MAX_LEVEL, and the walk speed from training
-- plus any other bonus never passes WALK_CAP (16 + 2 x 17 = 50). Laps on the treadmill grant the levels. A carrier (an
-- egg in the arms, a heavy pouch, a carried creature) keeps the same share of the trained walk that the carry leaves
-- of the base walk (one egg: 11/16 of it), so training is felt while carrying and carrying still costs speed. BP1
-- (balance pass 2026-11-15, odd/tasks/wildbound-balance-pass.md): a lap grants progress, not a level: level L+1 needs
-- LAP_STEP x (L+1) laps (153 laps of 8 s, about 20 min, to the top), only a level-up lap pays Esencia, and the console
-- is re-priced as a shortcut (BASE_COST 20, COST_GROWTH 1.1: 811 Esencia for the whole ladder, was 3178). BP2
-- (same pass): a carrier's share is taken of at most a CARRY_WALK_CAP walk (24: one egg 16.5, three or more 13.5,
-- under the parents' chase 19), so a chase stays a chase; this supersedes the uncapped PF2 share (34.4 at the top). The
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
	CARRY_WALK_CAP = 24, -- BP2: the trained walk a carrier's share is taken of, at most (a constant, not a tuning entry)
	BASE_COST = 20, -- Esencia for level 1 (BP1: was 30)
	COST_GROWTH = 1.1, -- each next level costs this much more, rounded (BP1: was 1.2; level 17 costs 92, was 555)
	LAP_STEP = 1, -- BP1: laps on the belt for level L+1 = LAP_STEP x (L+1)
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

-- BP1: the treadmill laps that take `level` to the next level, or nil at the cap.
function Training.lapsFor(level)
	local C = Training.live
	if not finite(level) or level < 0 or level >= C.MAX_LEVEL then return nil end
	return math.max(1, math.ceil(C.LAP_STEP * (math.floor(level) + 1)))
end

-- The walk bonus in studs/s a profile's training gives.
function Training.walkBonus(training)
	return levelOf(training, "walk") * Training.live.WALK_STEP
end

-- speed: the walk speed after carry costs; base: the unencumbered walk speed (EconomyConfig.carry.baseSpeed);
-- extra: any other walk bonus (studs/s). An unencumbered walk gains the bonus up to WALK_CAP; a slowed walk keeps its
-- share (speed / base) of that trained walk, taken of at most CARRY_WALK_CAP (BP2). Never slower than speed.
function Training.walkSpeed(speed, base, training, extra)
	if not finite(speed) or not finite(base) or base <= 0 then return speed end
	local bonus = Training.walkBonus(training) + (finite(extra) and math.max(0, extra) or 0)
	if bonus <= 0 then return speed end
	local cap = Training.live.WALK_CAP
	if speed < base then
		return math.max(speed, speed * math.min(base + bonus, cap, Training.live.CARRY_WALK_CAP) / base)
	end
	return math.max(speed, math.min(speed + bonus, cap))
end

return Training
