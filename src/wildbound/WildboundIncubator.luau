-- Pure incubator timer (delivery E, next batch NB4; docs/mechanics/wildbound-incubator.md). Shared through
-- ReplicatedStorage: the server uses the live hatch time, the Bag tab words the row from it. The clock is passed in
-- (the server's GetServerTimeNow), so nothing here reads a service; WildboundState owns the eggs.
local Incubator = {}

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

-- HATCH_SECONDS: from the egg going in to the creature hatching. SLOTS: eggs one player may incubate at once.
-- RANGE: studs from the incubator for the prompt and the Bag tab's button.
Incubator.CONSTANTS = freeze({ HATCH_SECONDS = 90, SLOTS = 1, RANGE = 12 })

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stays the default the tests pin; the server's tuning bridge
-- may override HATCH_SECONDS at runtime. No override, no change. An egg already incubating keeps its time.
local TUNABLE = { "HATCH_SECONDS" }
Incubator.live = {}

function Incubator.tunable()
	local defaults = {}
	for _, key in ipairs(TUNABLE) do defaults[key] = Incubator.CONSTANTS[key] end
	return defaults
end

function Incubator.tune(overrides)
	for key, value in pairs(Incubator.CONSTANTS) do Incubator.live[key] = value end
	for key in pairs(Incubator.live) do
		if Incubator.CONSTANTS[key] == nil then Incubator.live[key] = nil end
	end
	if type(overrides) ~= "table" then return end
	for _, key in ipairs(TUNABLE) do
		local value = overrides[key]
		if finite(value) and value > 0 then Incubator.live[key] = value end
	end
end
Incubator.tune(nil)

-- entry = { startedAt, readyAt } from the server snapshot; now = the server clock.
-- Returns { fraction 0..1, remaining whole seconds (rounded up), ready } or nil for anything malformed.
function Incubator.progress(entry, now)
	if type(entry) ~= "table" or not finite(entry.startedAt) or not finite(entry.readyAt) or not finite(now) then
		return nil
	end
	local span = math.max(entry.readyAt - entry.startedAt, 1e-6)
	local fraction = math.clamp((now - entry.startedAt) / span, 0, 1)
	local remaining = math.max(0, math.ceil(entry.readyAt - now - 1e-9))
	return { fraction = fraction, remaining = remaining, ready = now >= entry.readyAt }
end

-- The Bag tab's line for one incubating egg, in the words of WildboundText.INCUBATOR.
function Incubator.row(entry, now, Text)
	local state = Incubator.progress(entry, now)
	if not state or type(Text) ~= "table" or type(Text.INCUBATOR) ~= "table" then return nil end
	local words = Text.INCUBATOR
	local names = type(Text.CARD) == "table" and type(Text.CARD.species) == "table" and Text.CARD.species or {}
	local name = names[entry.species] or tostring(entry.species)
	if state.ready then return words.row:format(name, words.hatching) end
	return words.row:format(name, words.left:format(state.remaining))
end

return Incubator
