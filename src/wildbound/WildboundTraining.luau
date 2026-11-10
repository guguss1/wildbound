-- Training station rules (Nest Heist Phase 3, NS5). Pure and shared (ReplicatedStorage): the server prices and
-- applies a level, the camp screen words it. Levels are bought with Esencia (Ember internally) at the camp's
-- "Entrenamiento" treadmill and are saved (WildboundRecord schema 2, `training`).
--
-- Speed rule: each walk level adds WALK_STEP studs/s to the unencumbered walk speed, up to MAX_LEVEL, and the walk
-- speed from training plus any other bonus never passes WALK_CAP. A player slowed by an egg in the arms, a heavy
-- pouch or a carried creature gets no bonus, so the parents' chase (19) and the egg carrier's burst (18.7) keep
-- their balance. The sprint (Stamina.SPEED_CAP 24) and the Burst (Stamina.BURST_CAP 28) keep their own caps, so a
-- trained player is never much faster than a new one. The simulator (tools/simulate_economy.py) reads WALK_STEP and
-- MAX_LEVEL from this file and checks a fully trained greedy player against the 180 s expedition floor.
local Training = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

Training.CONSTANTS = table.freeze({
	WALK_STEP = 0.25, -- studs/s per level
	MAX_LEVEL = 4,
	WALK_CAP = 17.5, -- unencumbered walk speed ceiling for every bonus together (base 16)
	BASE_COST = 30, -- Esencia for level 1
	COST_GROWTH = 1.6, -- each next level costs this much more, rounded
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
-- extra: any other walk bonus (studs/s). Only an unencumbered walk gains, and never above WALK_CAP.
function Training.walkSpeed(speed, base, training, extra)
	if not finite(speed) or not finite(base) then return speed end
	if speed < base then return speed end
	local bonus = Training.walkBonus(training) + (finite(extra) and math.max(0, extra) or 0)
	if bonus <= 0 then return speed end
	return math.max(speed, math.min(speed + bonus, Training.live.WALK_CAP))
end

return Training
