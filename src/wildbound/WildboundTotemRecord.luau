-- Luck totem persistence (decision Q10, docs/mechanics/wildbound-new-mechanics.md section 4): the saved-progress
-- record's schema 4 step. It stores the single-use totems a player owns (bought or earned) as a count per kind, so a
-- Tótem de la suerte survives a leave until it is placed. Pure: no service, no yield, no clock; it works on the plain
-- record tables of WildboundRecord and never names a data store. Wiring (the Studio writer): set Record.SCHEMA to
-- TotemRecord.SCHEMA, Record.MIGRATIONS to TotemRecord.ladder(old MIGRATIONS), add "totems" to Record's KNOWN fields,
-- call TotemRecord.validate inside Record.validate and the profile seam inside fromProfile and toProfile.
-- Failed loads: the step only fills a missing section and never repairs or drops a malformed one, so validation fails,
-- WildboundPersistence quarantines the value and nothing is written over the real data.
local TotemRecord = {}

TotemRecord.FROM = 3 -- the schema this step reads (WildboundRecord.SCHEMA today)
TotemRecord.SCHEMA = 4 -- the schema it produces
TotemRecord.KINDS = table.freeze({ totemSuerte = true }) -- WildboundGear.LUCK
TotemRecord.CAP = 5 -- owned totems of one kind at most
TotemRecord.SOURCES = table.freeze({ bought = true, earned = true })

local function isCount(value)
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0 and value < 2 ^ 53
end

-- MIGRATIONS[3]: schema 3 -> 4. Adds an empty totem map when there is none; anything already there is kept as it is
-- for validation to judge. No totem is invented (there was never a saved one before schema 4).
function TotemRecord.step(data)
	if data.totems == nil then data.totems = {} end
	return data
end

-- A new frozen ladder: the deployed steps unchanged plus this one.
function TotemRecord.ladder(migrations)
	local ladder = {}
	for version, step in pairs(migrations) do ladder[version] = step end
	ladder[TotemRecord.FROM] = TotemRecord.step
	return table.freeze(ladder)
end

-- Returns true, or false and the list of problems (any problem means quarantine on load and no write on save).
function TotemRecord.validate(record)
	if type(record) ~= "table" then return false, { "record is not a table" } end
	local problems = {}
	local totems = record.totems
	if type(totems) ~= "table" then return false, { "totems is not a table" } end
	for kind, quantity in pairs(totems) do
		if not TotemRecord.KINDS[kind] then table.insert(problems, "totems has an unknown kind " .. tostring(kind)) end
		if not isCount(quantity) then
			table.insert(problems, "totems." .. tostring(kind) .. " is not a count")
		elseif quantity > TotemRecord.CAP then
			table.insert(problems, "totems." .. tostring(kind) .. " is over its cap")
		end
	end
	return #problems == 0, problems
end

function TotemRecord.count(record, kind)
	local totems = type(record) == "table" and record.totems
	local quantity = type(totems) == "table" and totems[kind]
	return isCount(quantity) and quantity or 0
end

-- A totem bought (Esencia, at the shop circle) or earned (a reward). Returns true, or false and "UnknownKind",
-- "BadCount", "BadSource", "Invalid" or "Full". A refused grant changes nothing.
function TotemRecord.grant(record, kind, quantity, source)
	if type(record) ~= "table" or type(record.totems) ~= "table" then return false, "Invalid" end
	if not TotemRecord.KINDS[kind] then return false, "UnknownKind" end
	if not isCount(quantity) or quantity < 1 then return false, "BadCount" end
	if not TotemRecord.SOURCES[source] then return false, "BadSource" end
	local total = TotemRecord.count(record, kind) + quantity
	if total > TotemRecord.CAP then return false, "Full" end
	record.totems[kind] = total
	return true
end

-- Single use: placing a totem consumes one. Returns true, or false and "None" or "Invalid".
function TotemRecord.consume(record, kind)
	if type(record) ~= "table" or type(record.totems) ~= "table" or not TotemRecord.KINDS[kind] then
		return false, "Invalid"
	end
	local have = TotemRecord.count(record, kind)
	if have < 1 then return false, "None" end
	record.totems[kind] = have > 1 and have - 1 or nil
	return true
end

-- Profile -> the record's totem map. The State profile holds the luck totems as `luckTotems` (a count); anything
-- that is not a count saves nothing, and a count over the cap saves the cap.
function TotemRecord.fromProfile(profile, _base)
	local totems = {}
	local held = type(profile) == "table" and profile.luckTotems
	if isCount(held) and held > 0 then totems.totemSuerte = math.min(held, TotemRecord.CAP) end
	return totems
end

-- Record -> profile: sets `luckTotems` only when there is one, so a blank record still makes exactly the profile
-- State:addPlayer makes (RT-2).
function TotemRecord.toProfile(record, profile)
	local have = TotemRecord.count(record, "totemSuerte")
	if have > 0 and type(profile) == "table" then profile.luckTotems = have end
	return profile
end

return TotemRecord
