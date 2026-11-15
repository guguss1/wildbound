-- Base farm persistence (PF4, user decision 2026-11-14): the saved-progress record's schema 5 step. It stores the
-- creatures a player placed in their base farm as a list of durable IDs, `farm = { "u3", "u7" }`, so a placed creature
-- stays in the farm after a leave. Pure: no service, no yield, no clock; it works on the plain record tables of
-- WildboundRecord and never names a data store. No farm income is saved or paid (the no-AFK-income rule; later
-- decision). Wiring (WildboundRecord): Record.SCHEMA = FarmRecord.SCHEMA, Record.MIGRATIONS = FarmRecord.ladder(...),
-- "farm" in Record's KNOWN fields, FarmRecord.validate inside Record.validate and the profile seam inside fromProfile
-- and toProfile.
-- Failed loads: the step only fills a missing section and never repairs or drops a malformed one, so validation fails,
-- WildboundPersistence quarantines the value and nothing is written over the real data.
local FarmRecord = {}

FarmRecord.FROM = 4 -- the schema this step reads (WildboundTotemRecord.SCHEMA)
FarmRecord.SCHEMA = 5 -- the schema it produces
-- Hard ceiling of saved farm creatures: the top of the farm.maxSlots tuning range. State enforces the live slot count
-- (State.FARM_SLOTS, the 2.0 balance's farm.startSlots); a record over this ceiling is quarantined, never trimmed.
FarmRecord.CAP = 12

local function durableId(value)
	return type(value) == "string" and string.match(value, "^u[1-9]%d*$") ~= nil and #value <= 16
end

-- MIGRATIONS[4]: schema 4 -> 5. Adds an empty farm when there is none; anything already there is kept as it is for
-- validation to judge. No creature is put in the farm (there was never a saved farm before schema 5).
function FarmRecord.step(data)
	if data.farm == nil then data.farm = {} end
	return data
end

-- A new frozen ladder: the deployed steps unchanged plus this one.
function FarmRecord.ladder(migrations)
	local ladder = {}
	for version, step in pairs(migrations) do ladder[version] = step end
	ladder[FarmRecord.FROM] = FarmRecord.step
	return table.freeze(ladder)
end

-- Returns true, or false and the list of problems. `registered` is the set of registered creature IDs the record
-- holds ({ [uid] = true }); every farm entry must be one of them, once, and never the companion out.
function FarmRecord.validate(record, registered)
	if type(record) ~= "table" then return false, { "record is not a table" } end
	local farm = record.farm
	if type(farm) ~= "table" then return false, { "farm is not a table" } end
	local problems = {}
	local count = 0
	for key in pairs(farm) do
		count += 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then table.insert(problems, "farm is not a list") end
	end
	if count ~= #farm then table.insert(problems, "farm is not a list") end
	if #farm > FarmRecord.CAP then table.insert(problems, "farm is over its cap") end
	local seen = {}
	for index, uid in ipairs(farm) do
		local label = "farm[" .. index .. "]"
		if not durableId(uid) then
			table.insert(problems, label .. " is not a durable ID")
		else
			if seen[uid] then table.insert(problems, label .. " is placed twice") end
			seen[uid] = true
			if type(registered) ~= "table" or not registered[uid] then
				table.insert(problems, label .. " is not a registered creature")
			end
			if record.equippedUid == uid then table.insert(problems, label .. " is the companion out") end
		end
	end
	return #problems == 0, problems
end

-- Profile -> the record's farm list. The State profile holds it as `farm` (made on first use). A session ID makes
-- the whole save refuse (nil, "SessionId"), exactly like the other saved lists.
function FarmRecord.fromProfile(profile)
	local farm = {}
	local held = type(profile) == "table" and profile.farm
	if type(held) ~= "table" then return farm end
	for _, uid in ipairs(held) do
		if not durableId(uid) then return nil, "SessionId" end
		table.insert(farm, uid)
	end
	return farm
end

-- Record -> profile: sets `farm` only when there is one, so a blank record still makes exactly the profile
-- State:addPlayer makes (RT-2).
function FarmRecord.toProfile(record, profile)
	local farm = type(record) == "table" and record.farm
	if type(farm) == "table" and #farm > 0 and type(profile) == "table" then profile.farm = table.clone(farm) end
	return profile
end

return FarmRecord
