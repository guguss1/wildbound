-- First-run tutorial (W9, M8.5), pure state. It walks the first reward loop in three steps: gather a plant,
-- extract at camp, then open the Camp tab to see what it can craft. Crafting itself is not required: the first
-- recipe costs 8 Fogbark and 4 Glowmoss, more than one trip pays. The controller feeds it facts read from the
-- player's own state snapshot; it never decides anything for the server.
local Tutorial = {}

Tutorial.STEPS = table.freeze({
	table.freeze({ id = "gather", full = "1/3 Gather: hold the Gather prompt beside a glowing plant in the fog.",
		short = "1/3 Hold Gather by a glowing plant." }),
	table.freeze({ id = "extract", full = "2/3 Extract: walk back to camp and use Extract to keep what you carry.",
		short = "2/3 Return to camp and press Extract." }),
	table.freeze({ id = "camp", full = "3/3 Craft: open Inventory, then Camp, to see what you can make.",
		short = "3/3 Inventory, Camp: see what you can craft." }),
})
Tutorial.DONE_TEXT = "That is the loop: gather, extract, craft."

function Tutorial.new()
	return { index = 1, status = "running" }
end

function Tutorial.state(t)
	return t.status
end

function Tutorial.step(t)
	if t.status ~= "running" then return nil end
	return Tutorial.STEPS[t.index]
end

function Tutorial.progress(t)
	return ("Step %d of %d"):format(math.min(t.index, #Tutorial.STEPS), #Tutorial.STEPS)
end

function Tutorial.cardText(step, compact)
	return compact and step.short or step.full
end

local function met(id, f)
	if id == "gather" then return f.carried > 0 or f.pending > 0 or f.banked > 0 or f.ember > 0 end
	if id == "extract" then return f.banked > 0 or f.ember > 0 end
	return f.campOpen == true
end

-- Advances as far as the facts allow, in order. Returns whether anything changed.
function Tutorial.observe(t, f)
	if t.status ~= "running" or type(f) ~= "table" then return false end
	local changed = false
	while t.status == "running" and met(Tutorial.STEPS[t.index].id, f) do
		changed = true
		if t.index >= #Tutorial.STEPS then
			t.status = "done"
		else
			t.index += 1
		end
	end
	return changed
end

function Tutorial.skip(t)
	if t.status == "running" then t.status = "skipped" end
end

function Tutorial.restart(t)
	t.index, t.status = 1, "running"
end

local function sum(values)
	local total = 0
	if type(values) == "table" then
		for _, amount in pairs(values) do
			if type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge then total += amount end
		end
	end
	return total
end

-- Facts from a state snapshot (WildboundState:snapshot), tolerating any missing or odd field.
function Tutorial.factsFrom(snapshot, campOpen)
	snapshot = type(snapshot) == "table" and snapshot or {}
	local ember = snapshot.ember
	if type(ember) ~= "number" or ember ~= ember or ember < 0 or ember == math.huge then ember = 0 end
	return { carried = sum(snapshot.carried), pending = type(snapshot.pending) == "table" and #snapshot.pending or 0,
		banked = sum(snapshot.banked), ember = ember, campOpen = campOpen == true }
end

return Tutorial
