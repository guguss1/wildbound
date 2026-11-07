-- Pure view-models for the camp screen, the HUD loss line and the explorer compass (M5.8 and M5.6, wave W7
-- part 2). Snapshot in, plain rows and rectangles out. Nothing here reads or writes an interface object,
-- the clock or a service; the controllers apply it. The tuning copy and the economy rules are passed in.
-- Every disabled row says why in words, and every line has a budget it never exceeds, so no text depends on
-- hue and none is clipped. See docs/ui/wildbound-world.md.
local View = {}

View.MIN_TARGET = 44
View.BUTTON_W = 98
View.ROW_MIN = 56
-- A phone held sideways has little height (W9): compact rows may be this tall, a 44 pixel button plus 2 each side.
View.COMPACT_ROW_MIN = 48
-- The gap between rows on a sideways phone, and whether the section titles stay. They do not: each row already
-- names itself, and two titles took as much room as a row and a half.
View.COMPACT_GAP = 4

function View.showSectionHeaders(compact)
	return compact ~= true
end
View.HEADER_H = 44

local NAMES = table.freeze({ ember = "Ember", fogbark = "Fogbark", glowmoss = "Glowmoss", nightbloom = "Nightbloom" })
local ORDER = table.freeze({ "ember", "fogbark", "glowmoss", "nightbloom" })
local RECIPES = table.freeze({
	{ id = "seal", title = "Ward Seal", effect = "saves one bag item if you are defeated" },
	{ id = "totem", title = "Last Breath Totem", effect = "wards one more item, but Silueta senses you from farther" },
	{ id = "capsule", title = "Extraction Capsule", effect = "banks one bag item at the shelter" },
})
local SKILLS = table.freeze({
	{ id = "explorer_1", title = "Trail Sense", effect = "gather nodes within %d studs", key = "nodeHintRange" },
	{ id = "explorer_2", title = "Night Nose", effect = "Nightbloom within %d studs at Night", key = "nightbloomHintRange" },
	{ id = "capturer_1", title = "Steady Hands", effect = "calm a Lumipol faster" },
	{ id = "capturer_2", title = "Soft Approach", effect = "shorter wait after a failed calm" },
	{ id = "survivor_1", title = "Light Load", effect = "eggs slow you %d less", key = "carrySpeedBonus" },
	{ id = "survivor_2", title = "Quick Rest", effect = "clears a Silueta mark sooner" },
	{ id = "occultist_1", title = "Read the Signs", effect = "hints when Silueta moves" },
	{ id = "occultist_2", title = "Long Reveal", effect = "your flashlight reveal lasts longer" },
})
local BRANCHES = table.freeze({ explorer = "Explorer", capturer = "Capturer", survivor = "Survivor", occultist = "Occultist" })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function amount(value)
	return finite(value) and math.max(0, math.floor(value)) or 0
end

-- "8 Fogbark, 4 Glowmoss" in a fixed order. Nothing to pay reads "Free".
function View.costText(cost)
	local parts = {}
	for _, key in ipairs(ORDER) do
		local value = type(cost) == "table" and cost[key] or nil
		if finite(value) and value > 0 then table.insert(parts, ("%d %s"):format(value, NAMES[key])) end
	end
	return #parts == 0 and "Free" or table.concat(parts, ", ")
end

-- What is missing to pay a cost from this wallet, as words, or nil when it can be paid.
function View.shortfall(wallet, cost)
	local missing = {}
	for _, key in ipairs(ORDER) do
		local need = type(cost) == "table" and cost[key] or nil
		if finite(need) and need > 0 then
			local have = key == "ember" and amount(wallet and wallet.ember) or amount(wallet and wallet.banked and wallet.banked[key])
			if have < need then table.insert(missing, ("%d more %s"):format(need - have, NAMES[key])) end
		end
	end
	if #missing == 0 then return nil end
	return "Need " .. table.concat(missing, " and ")
end

local function walletOf(snapshot)
	return { ember = amount(snapshot.ember), banked = type(snapshot.banked) == "table" and snapshot.banked or {} }
end

local function row(id, section, text, action, argument, label, enabled, why)
	return { id = id, section = section, text = text, action = action, argument = argument, label = label,
		enabled = enabled == true, why = why or "" }
end

-- First reason a purchase is unavailable, in the order a player would fix them.
local function reason(ctx, snapshot, cost, extra)
	if ctx.busy == true then return "Wait a moment" end
	if ctx.atCamp == false then return "Go to camp" end
	if extra then return extra end
	return View.shortfall(walletOf(snapshot), cost)
end

local function line(title, effect, cost, why)
	local text = ("%s: %s. Cost: %s."):format(title, effect, View.costText(cost))
	return why and why ~= "" and (text .. " " .. why .. ".") or text
end

-- The compact wording: the name and either what is missing or the price, never both.
local function shortLine(title, cost, why)
	if why and why ~= "" then
		-- "Need 3 more Fogbark and 2 more Glowmoss" becomes "Short 3 Fogbark, 2 Glowmoss": shorter, same facts.
		local missing = why:match("^Need (%d.*)$")
		if missing then why = "Short " .. missing:gsub(" more ", " "):gsub(" and ", ", ") end
		return ("%s: %s."):format(title, why)
	end
	return ("%s: %s."):format(title, View.costText(cost))
end

-- Everything the Camp tab lists, in order: banked stock, crafts, arming, the upgrade, the skills and bond.
-- ctx = { atCamp = bool|nil, busy = bool|nil }; a nil atCamp is treated as at camp (the server checks anyway).
function View.campRows(config, economy, snapshot, ctx)
	snapshot = type(snapshot) == "table" and snapshot or {}
	ctx = type(ctx) == "table" and ctx or {}
	local rows = {}
	local banked = type(snapshot.banked) == "table" and snapshot.banked or {}
	table.insert(rows, row("banked", "Stock", ("Banked: %d Fogbark, %d Glowmoss, %d Nightbloom. Ember: %d."):format(
		amount(banked.fogbark), amount(banked.glowmoss), amount(banked.nightbloom), amount(snapshot.ember))))
	local consumables = type(snapshot.consumables) == "table" and snapshot.consumables or {}
	for _, recipe in ipairs(RECIPES) do
		local spec = config.recipes[recipe.id]
		if spec then
			local held, cap = amount(consumables[recipe.id]), config.capacity.consumableCaps[recipe.id]
			local extra = held >= cap and ("You hold the most (%d)"):format(cap) or nil
			local why = reason(ctx, snapshot, spec.cost, extra)
			local made = row("craft:" .. recipe.id, "Craft", line(("%s (hold %d of %d)"):format(recipe.title, held, cap),
				recipe.effect, spec.cost, why), "Craft", recipe.id, "Craft", why == nil, why)
			made.short = shortLine(("%s %d/%d"):format(recipe.title, held, cap), spec.cost, why)
			table.insert(rows, made)
		end
	end
	if amount(consumables.seal) > 0 or snapshot.sealArmed == true then
		local armed = snapshot.sealArmed == true
		local why = armed and "Armed" or (ctx.busy and "Wait a moment" or nil)
		table.insert(rows, row("arm:seal", "Craft", armed and "Seal armed: your next new bag item is warded."
			or "Arm a seal before you leave: your next new bag item is warded.", "ArmSeal", "seal", "Arm", not armed and not ctx.busy, why))
	end
	if snapshot.totemActive == true then
		local why = ctx.atCamp == false and "Go to camp" or (snapshot.expedition and "Already out" or nil)
		table.insert(rows, row("totem:off", "Craft", "Totem set: Silueta senses you from farther. Put it away before you leave to get it back.",
			"DisarmTotem", "totem", "Put away", why == nil and not ctx.busy, why))
	elseif amount(consumables.totem) > 0 then
		local why = ctx.atCamp == false and "Go to camp" or nil
		table.insert(rows, row("totem:on", "Craft", "Set the totem: it wards one more item, but Silueta senses you from farther.",
			"ArmTotem", "totem", "Set", why == nil and not ctx.busy, why))
	end
	local upgrades = type(snapshot.upgrades) == "table" and snapshot.upgrades or {}
	for name, spec in pairs(config.upgrades) do
		if upgrades[name] == true then
			table.insert(rows, row("upgrade:" .. name, "Upgrade", "Reinforced Pack: owned. Bag 4, pouch 45, a defeat takes a quarter.", nil, nil, nil, false))
		else
			local why = reason(ctx, snapshot, spec.cost)
			local made = row("upgrade:" .. name, "Upgrade", line("Reinforced Pack", "bag 4, pouch 45, a defeat takes a quarter instead of half",
				spec.cost, why), "Upgrade", name, "Buy", why == nil, why)
			made.short = shortLine("Reinforced Pack", spec.cost, why)
			table.insert(rows, made)
		end
	end
	local owned = type(snapshot.skills) == "table" and snapshot.skills or {}
	for _, skill in ipairs(SKILLS) do
		local spec = config.skills[skill.id]
		if spec then
			local effect = skill.key and skill.effect:format(spec.effects[skill.key] or 0) or skill.effect
			local title = ("%s %d %s"):format(BRANCHES[spec.branch] or spec.branch, spec.tier, skill.title)
			if owned[skill.id] == true then
				table.insert(rows, row("skill:" .. skill.id, "Skills", ("%s: learned. %s."):format(title, effect), nil, nil, nil, false))
			else
				local extra
				for _, required in ipairs(spec.requires) do
					if not owned[required] then extra = "Needs " .. (config.skills[required] and (BRANCHES[config.skills[required].branch] or "") .. " 1" or required) end
				end
				if not extra and spec.effectLive ~= true then extra = "Effect not built yet" end
				local why = reason(ctx, snapshot, spec.cost, extra)
				local made = row("skill:" .. skill.id, "Skills", line(title, effect, spec.cost, why), "Learn", skill.id, "Learn", why == nil, why)
				made.short = shortLine(title, spec.cost, why)
				table.insert(rows, made)
			end
		end
	end
	local equipped = snapshot.equippedUid
	local bond = type(snapshot.bond) == "table" and equipped and snapshot.bond[equipped] or nil
	if equipped then
		local xp, level = bond and amount(bond.xp) or 0, bond and amount(bond.level) or 1
		local pending = amount(snapshot.pendingBondXp)
		table.insert(rows, row("bond", "Bond", ("Companion bond: level %d, %d XP.%s Pulse hits in the fog earn XP; extracting banks it."):format(
			level, xp, pending > 0 and (" +%d pending."):format(pending) or "")))
	end
	if ctx.compact == true then
		for _, item in ipairs(rows) do
			if item.short then item.text = item.short end
		end
	end
	return rows
end

-- The two quick actions on the Bag tab: seal the newest item, and arm a seal before leaving.
function View.quickRows(snapshot, ctx)
	snapshot = type(snapshot) == "table" and snapshot or {}
	ctx = type(ctx) == "table" and ctx or {}
	local seals = amount(snapshot.consumables and snapshot.consumables.seal)
	local pending = type(snapshot.pending) == "table" and snapshot.pending or {}
	local sealed, unsealed = false, 0
	for _, entry in ipairs(pending) do
		if entry.protected == true and entry.wardSource == "Seal" then sealed = true end
		if entry.protected ~= true then unsealed += 1 end
	end
	local why = ctx.busy and "Wait a moment" or seals < 1 and "No seal. Craft one at camp" or unsealed < 1 and "Nothing to ward"
		or sealed and "One item is already sealed" or nil
	local armWhy = ctx.busy and "Wait a moment" or snapshot.sealArmed == true and "Armed" or seals < 1 and "No seal. Craft one at camp" or nil
	return {
		row("seal:newest", "Quick", why and ("Seal the newest item. " .. why .. ".") or "Seal the newest item in your bag.",
			"SealNewest", "seal", "Seal newest", why == nil, why),
		row("seal:arm", "Quick", snapshot.sealArmed == true and "Seal armed: your next new bag item is warded."
			or armWhy and ("Arm a seal for your next item. " .. armWhy .. ".") or "Arm a seal for your next item.",
			"ArmSeal", "seal", "Arm", armWhy == nil, armWhy),
	}
end

local function lossTotals(snapshot)
	local preview = type(snapshot) == "table" and type(snapshot.riskPreview) == "table" and snapshot.riskPreview or {}
	local items = amount(preview.loseItems)
	local lines, total = {}, 0
	local materials = type(preview.loseMaterials) == "table" and preview.loseMaterials or {}
	for _, key in ipairs({ "fogbark", "glowmoss", "nightbloom" }) do
		local value = amount(materials[key])
		if value > 0 then
			table.insert(lines, ("%d %s"):format(value, NAMES[key]))
			total += value
		end
	end
	return items, lines, total, amount(preview.keep)
end

local function plural(count, one, many)
	return ("%d %s"):format(count, count == 1 and one or many)
end

-- The one HUD line for what a defeat right now would take. `budget` is the character count the label can
-- hold; the longest wording that fits is chosen, and the result never exceeds the budget.
function View.lossLine(snapshot, budget)
	local items, lines, total, keep = lossTotals(snapshot)
	budget = finite(budget) and math.floor(budget) or 40
	if items == 0 and total == 0 then
		return { text = "Nothing at risk.", tone = "safe", glyph = "OK", atRisk = false }
	end
	local parts = {}
	if items > 0 then table.insert(parts, plural(items, "item", "items")) end
	for _, text in ipairs(lines) do table.insert(parts, text) end
	local kept = keep > 0 and (" %d kept."):format(keep) or ""
	local both = items > 0 and total > 0
	local short = both and ("%s, %d mats"):format(plural(items, "item", "items"), total)
		or items > 0 and plural(items, "item", "items") or plural(total, "mat", "mats")
	local candidates = {
		"! If defeated you lose: " .. table.concat(parts, ", ") .. "." .. kept,
		"! If defeated you lose: " .. table.concat(parts, ", ") .. ".",
		"! Lose if defeated: " .. table.concat(parts, ", "),
		"! Lose: " .. short,
		"! " .. short,
		"! Lose " .. (items + total),
	}
	for _, text in ipairs(candidates) do
		if #text <= budget then return { text = text, tone = "risk", glyph = "!", atRisk = true } end
	end
	return { text = ("! " .. (items + total)):sub(1, math.max(1, budget)), tone = "risk", glyph = "!", atRisk = true }
end

local DIRECTIONS = table.freeze({ "N", "NE", "E", "SE", "S", "SW", "W", "NW" })

-- The compass line from Trail Sense and Night Nose. Gather nodes only: no creature, egg or capture slot is
-- ever listed. `nodes` is a list of { x, z, material }; the player's position is (x, z). North is -Z.
function View.compass(effects, nodes, x, z, phase)
	effects = type(effects) == "table" and effects or {}
	local near = finite(effects.nodeHintRange) and effects.nodeHintRange or 0
	local night = phase == "Night" and finite(effects.nightbloomHintRange) and effects.nightbloomHintRange or 0
	if (near <= 0 and night <= 0) or not finite(x) or not finite(z) or type(nodes) ~= "table" then return nil end
	local best, bestDistance, count = nil, math.huge, 0
	for _, node in ipairs(nodes) do
		if type(node) == "table" and finite(node.x) and finite(node.z) and NAMES[node.material] then
			local distance = math.sqrt((node.x - x) ^ 2 + (node.z - z) ^ 2)
			local range = node.material == "nightbloom" and math.max(near, night) or near
			if node.material == "nightbloom" and night <= 0 then range = 0 end
			if distance <= range then
				count += 1
				if distance < bestDistance then best, bestDistance = node, distance end
			end
		end
	end
	if not best then return nil end
	local angle = math.atan2(best.x - x, -(best.z - z))
	local index = math.floor((angle / (math.pi / 4)) + 0.5) % 8 + 1
	local text = ("Nearest node: %s, %d studs %s"):format(NAMES[best.material], math.floor(bestDistance + 0.5), DIRECTIONS[index])
	return { text = text, count = count, material = best.material, distance = bestDistance, direction = DIRECTIONS[index] }
end

-- Height of a row whose text wraps in `textWidth` pixels at `size`. Gotham averages about 0.6 of the size per
-- character; the extra line allowance keeps a wrapped last line from touching the edge.
function View.textLines(text, textWidth, size)
	if type(text) ~= "string" or not finite(textWidth) or not finite(size) or size <= 0 then return 1 end
	local perLine = math.max(1, math.floor(textWidth / (size * 0.6)))
	return math.max(1, math.ceil((#text + 2) / perLine))
end

function View.rowHeight(row_, width, size, compact)
	local buttonRoom = row_.label and (View.BUTTON_W + 14) or 0
	local lines = View.textLines(row_.text, width - 16 - buttonRoom, size)
	return math.max(compact and View.COMPACT_ROW_MIN or View.ROW_MIN, math.ceil(lines * (size + 3) + 12))
end

-- Where the list sits inside a panel from View.panel. A phone held sideways has no room for the tab note, so the
-- list starts right under the header buttons; elsewhere the note keeps its line.
function View.listArea(panelRect, sideways)
	local headerBottom = 4 + View.HEADER_H
	local note = sideways ~= true
	local noteH = note and 24 or 0
	local top = headerBottom + 2 + noteH + (note and 2 or 0)
	return { showNote = note, noteHeight = noteH, top = top, height = panelRect.h - top - (note and 6 or 4) }
end

-- True for a phone held sideways, the layout that gets compact rows.
function View.sideways(width, height)
	return finite(width) and finite(height) and width > height and math.min(width, height) <= 500
end

-- The panel for the Bag and Camp tabs: below the awareness chip so a warning is never covered, and inside the
-- screen edge. chip = { x, y, w, h } from the HUD layout.
function View.panel(width, height, chip)
	local w = finite(width) and width > 0 and width or 1280
	local h = finite(height) and height > 0 and height or 720
	local top = (type(chip) == "table" and finite(chip.y) and finite(chip.h)) and chip.y + chip.h + 6 or 60
	-- A phone held sideways keeps the sides free for the move control and the jump button.
	local sideways = w > h and math.min(w, h) <= 500
	local panelW = sideways and math.min(560, math.floor(w * 0.58)) or math.min(560, w - 16)
	-- Held upright, Roblox puts the move control and the jump button over the lower 40 percent of the screen and
	-- draws them above this panel, so the panel stops where they begin (the same split the HUD layout uses).
	local panelH = math.max(120, (h > w and math.floor(0.6 * h) - 4 or h - 8) - top)
	return { x = math.floor((w - panelW) / 2), y = top, w = panelW, h = panelH }
end

-- The header buttons inside the panel: Bag, Camp and Close, 44 high, with the Close button at the right.
function View.header(panelWidth)
	-- Four buttons in a row (W9 added Menu). They shrink to fit a narrow panel but never below 44 wide.
	local gap, y = 6, 4
	local tabW = math.clamp(math.floor((panelWidth - 16 - 3 * gap) / 4), 44, 84)
	return {
		bag = { x = 8, y = y, w = tabW, h = View.HEADER_H },
		camp = { x = 8 + tabW + gap, y = y, w = tabW, h = View.HEADER_H },
		menu = { x = 8 + 2 * (tabW + gap), y = y, w = tabW, h = View.HEADER_H },
		close = { x = panelWidth - 8 - tabW, y = y, w = tabW, h = View.HEADER_H },
		tabWidth = tabW,
		bottom = y + View.HEADER_H,
	}
end

-- The short line under the header for each tab.
function View.note(tab, atCamp, compact)
	if tab == "camp" then
		if atCamp == false then return compact and "Walk to camp to craft and learn." or "Walk to camp, within 20 studs, to craft, buy and learn." end
		return compact and "At camp: craft, buy and learn." or "At camp: you can craft, buy and learn."
	end
	return compact and "Session only: lost when you leave." or "Session only: progress is lost when you leave or the server stops."
end

return View
