-- Hub roulette persistence (PF5, user decision 2026-11-14): the saved-progress record's schema 6 step. It stores the
-- roulette state WildboundRoulette.draw reads and returns, `roulette = { freeSpinUsed, pityCount, paidSpins }`, so the
-- free first spin is once per account and the Rara+ pity counter survives a leave. Pure: no service, no yield, no
-- clock; it works on the plain record tables of WildboundRecord and never names a data store. Prizes are paid at once
-- (Esencia and banked materials, saved in their own fields), so no pending claim is stored.
-- Wiring (WildboundRecord): Record.SCHEMA = RouletteRecord.SCHEMA, Record.MIGRATIONS = RouletteRecord.ladder(...),
-- "roulette" in Record's KNOWN fields, the blank state in Record.blank, RouletteRecord.validate inside Record.validate
-- and the profile seam inside fromProfile and toProfile.
-- Failed loads: the step only fills a missing section and never repairs a malformed one, so validation fails,
-- WildboundPersistence quarantines the value and nothing is written over the real data.
local RouletteRecord = {}

RouletteRecord.FROM = 5 -- the schema this step reads (WildboundFarmRecord.SCHEMA)
RouletteRecord.SCHEMA = 6 -- the schema it produces

local FIELDS = table.freeze({ freeSpinUsed = true, pityCount = true, paidSpins = true })

local function count(value)
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0 and value < 2 ^ 53
end

-- The state of an account that never spun: the free spin is still there.
function RouletteRecord.unused()
	return { freeSpinUsed = false, pityCount = 0, paidSpins = 0 }
end

local function isUnused(state)
	return state.freeSpinUsed == false and state.pityCount == 0 and state.paidSpins == 0
end

-- MIGRATIONS[5]: schema 5 -> 6. Adds the unused state when there is none (nobody could spin before schema 6); anything
-- already there is kept as it is for validation to judge.
function RouletteRecord.step(data)
	if data.roulette == nil then data.roulette = RouletteRecord.unused() end
	return data
end

-- A new frozen ladder: the deployed steps unchanged plus this one.
function RouletteRecord.ladder(migrations)
	local ladder = {}
	for version, step in pairs(migrations) do ladder[version] = step end
	ladder[RouletteRecord.FROM] = RouletteRecord.step
	return table.freeze(ladder)
end

-- Returns true, or false and the list of problems. Exactly the three fields: a boolean and two counts, and the pity
-- counter (paid spins in a row without Rara or better) never above the paid spins.
function RouletteRecord.validate(record)
	if type(record) ~= "table" then return false, { "record is not a table" } end
	local state = record.roulette
	if type(state) ~= "table" then return false, { "roulette is not a table" } end
	local problems = {}
	for key in pairs(state) do
		if not FIELDS[key] then table.insert(problems, "roulette has an unknown field " .. tostring(key)) end
	end
	if type(state.freeSpinUsed) ~= "boolean" then table.insert(problems, "roulette.freeSpinUsed is not a boolean") end
	if not count(state.pityCount) then table.insert(problems, "roulette.pityCount is not a count") end
	if not count(state.paidSpins) then table.insert(problems, "roulette.paidSpins is not a count") end
	if count(state.pityCount) and count(state.paidSpins) and state.pityCount > state.paidSpins then
		table.insert(problems, "roulette.pityCount is above roulette.paidSpins")
	end
	return #problems == 0, problems
end

-- Profile -> the record's roulette state. State keeps `roulette` only after a first spin (made on first use); a
-- malformed one makes the whole save refuse (nil, "BadRoulette"), so it is never written.
function RouletteRecord.fromProfile(profile)
	local held = type(profile) == "table" and profile.roulette or nil
	if held == nil then return RouletteRecord.unused() end
	local state = { freeSpinUsed = type(held) == "table" and held.freeSpinUsed, pityCount = type(held) == "table"
		and held.pityCount, paidSpins = type(held) == "table" and held.paidSpins }
	if not RouletteRecord.validate({ roulette = state }) then return nil, "BadRoulette" end
	return state
end

-- Record -> profile: sets `roulette` only when it was used, so a blank record still makes exactly the profile
-- State:addPlayer makes (RT-2).
function RouletteRecord.toProfile(record, profile)
	local state = type(record) == "table" and record.roulette
	if type(state) == "table" and type(profile) == "table" and not isUnused(state) then
		profile.roulette = { freeSpinUsed = state.freeSpinUsed, pityCount = state.pityCount, paidSpins = state.paidSpins }
	end
	return profile
end

return RouletteRecord
