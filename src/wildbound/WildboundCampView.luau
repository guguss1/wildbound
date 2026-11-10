-- Pure view-models for the camp screen, the HUD loss line and the explorer compass (M5.8 and M5.6, wave W7
-- part 2). Snapshot in, plain rows and rectangles out. Nothing here reads or writes an interface object,
-- the clock or a service; the controllers apply it. The tuning copy and the economy rules are passed in.
-- Every disabled row says why in words, and every line has a budget it never exceeds, so no text depends on
-- hue and none is clipped. See docs/ui/wildbound-world.md. Next batch NB3: every player word here is neutral Spanish;
-- the material names (Fogbark, Glowmoss, Nightbloom) and Ember stay as proper names.
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

-- NB5: players call the currency Esencia (internal name ember); a price reads "12 de Esencia, 8 Fogbark".
local NAMES = table.freeze({ ember = "de Esencia", fogbark = "Fogbark", glowmoss = "Glowmoss", nightbloom = "Nightbloom" })
local ORDER = table.freeze({ "ember", "fogbark", "glowmoss", "nightbloom" })
local RECIPES = table.freeze({
	{ id = "seal", title = "Sello protector", effect = "salva un objeto de la bolsa si te derrotan" },
	{ id = "totem", title = "Tótem", effect = "protege un objeto más; La Silueta te nota antes" },
	{ id = "capsule", title = "Cápsula", effect = "guarda un objeto en el refugio" },
})
-- Items and totem (plan Part 4, IT1): the equipment, in order. Names equal WildboundText.GEAR (a test checks).
local GEAR = table.freeze({
	{ id = "guantes", title = "Guantes de captura", owned = "equipados", effect = "calmas más rápido y el círculo es más ancho" },
	{ id = "botas", title = "Botas", owned = "equipadas", effect = "correr gasta menos aliento" },
	{ id = "chaleco", title = "Chaleco", owned = "equipado", effect = "aguanta un golpe que te derrotaría, una vez por salida" },
	{ id = "amuleto", title = "Amuleto", owned = "equipado", effect = "La Silueta te olvida antes y el miedo pesa menos" },
})
local SKILLS = table.freeze({
	{ id = "explorer_1", title = "Rastro", effect = "puntos de recolección a %d studs", key = "nodeHintRange" },
	{ id = "explorer_2", title = "Olfato", effect = "Nightbloom a %d studs de noche", key = "nightbloomHintRange" },
	{ id = "capturer_1", title = "Manos firmes", effect = "calmas a un Lumipol más rápido" },
	{ id = "capturer_2", title = "Paso suave", effect = "esperas menos tras fallar la calma" },
	{ id = "survivor_1", title = "Carga ligera", effect = "los huevos te frenan %d menos", key = "carrySpeedBonus" },
	{ id = "survivor_2", title = "Descanso rápido", effect = "la marca se borra antes" },
	{ id = "occultist_1", title = "Leer señales", effect = "avisos si La Silueta se mueve" },
	{ id = "occultist_2", title = "Luz larga", effect = "tu linterna revela más tiempo" },
})
local BRANCHES = table.freeze({ explorer = "Rastreo", capturer = "Captura", survivor = "Aguante", occultist = "Ocultismo" })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function amount(value)
	return finite(value) and math.max(0, math.floor(value)) or 0
end

-- "8 Fogbark, 4 Glowmoss" in a fixed order. Nothing to pay reads "Gratis".
function View.costText(cost)
	local parts = {}
	for _, key in ipairs(ORDER) do
		local value = type(cost) == "table" and cost[key] or nil
		if finite(value) and value > 0 then table.insert(parts, ("%d %s"):format(value, NAMES[key])) end
	end
	return #parts == 0 and "Gratis" or table.concat(parts, ", ")
end

-- What is missing to pay a cost from this wallet, as words, or nil when it can be paid.
function View.shortfall(wallet, cost)
	local missing = {}
	for _, key in ipairs(ORDER) do
		local need = type(cost) == "table" and cost[key] or nil
		if finite(need) and need > 0 then
			local have = key == "ember" and amount(wallet and wallet.ember) or amount(wallet and wallet.banked and wallet.banked[key])
			if have < need then table.insert(missing, ("%d %s más"):format(need - have, NAMES[key])) end
		end
	end
	if #missing == 0 then return nil end
	return "Faltan " .. table.concat(missing, " y ")
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
	if ctx.busy == true then return "Espera un momento" end
	if ctx.atCamp == false then return "Ve al campamento" end
	if extra then return extra end
	return View.shortfall(walletOf(snapshot), cost)
end

-- Each upgrade's own words. I7: "Farol tapado" is the starter upgrade, listed first.
local UPGRADE_WORDS = table.freeze({
	farolTapado = table.freeze({ order = 1, title = "Farol tapado",
		effect = "tu linterna molesta menos a las criaturas dormidas",
		owned = "Farol tapado: comprado. Tu linterna molesta menos a las criaturas dormidas." }),
	reinforcedPack = table.freeze({ order = 2, title = "Mochila reforzada",
		effect = "bolsa 4, zurrón 45, una derrota quita un décimo",
		owned = "Mochila reforzada: comprada. Bolsa 4, zurrón 45, una derrota quita un décimo." }),
})

local function line(title, effect, cost, why)
	local text = ("%s: %s. Precio: %s."):format(title, effect, View.costText(cost))
	return why and why ~= "" and (text .. " " .. why .. ".") or text
end

-- The compact wording: the name and either what is missing or the price, never both.
local function shortLine(title, cost, why)
	if why and why ~= "" then
		-- "Faltan 3 Fogbark más y 2 Glowmoss más" becomes "Faltan 3 Fogbark, 2 Glowmoss": shorter, same facts.
		local missing = why:match("^Faltan (%d.*)$")
		if missing then why = "Faltan " .. missing:gsub(" más", ""):gsub(" y ", ", ") end
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
	table.insert(rows, row("banked", "Stock", ("Guardado: %d Fogbark, %d Glowmoss, %d Nightbloom. Esencia: %d."):format(
		amount(banked.fogbark), amount(banked.glowmoss), amount(banked.nightbloom), amount(snapshot.ember))))
	local consumables = type(snapshot.consumables) == "table" and snapshot.consumables or {}
	for _, recipe in ipairs(RECIPES) do
		local spec = config.recipes[recipe.id]
		if spec then
			local held, cap = amount(consumables[recipe.id]), config.capacity.consumableCaps[recipe.id]
			local extra = held >= cap and ("Ya tienes el máximo (%d)"):format(cap) or nil
			local why = reason(ctx, snapshot, spec.cost, extra)
			local made = row("craft:" .. recipe.id, "Craft", line(("%s (tienes %d de %d)"):format(recipe.title, held, cap),
				recipe.effect, spec.cost, why), "Craft", recipe.id, "Fabricar", why == nil, why)
			made.short = shortLine(("%s %d/%d"):format(recipe.title, held, cap), spec.cost, why)
			table.insert(rows, made)
		end
	end
	if amount(consumables.seal) > 0 or snapshot.sealArmed == true then
		local armed = snapshot.sealArmed == true
		local why = armed and "Preparado" or (ctx.busy and "Espera un momento" or nil)
		table.insert(rows, row("arm:seal", "Craft", armed and "Sello preparado: tu próximo objeto nuevo queda protegido."
			or "Prepara un sello antes de salir: tu próximo objeto nuevo queda protegido.", "ArmSeal", "seal", "Preparar",
			not armed and not ctx.busy, why))
	end
	if snapshot.totemActive == true then
		local why = ctx.atCamp == false and "Ve al campamento" or (snapshot.expedition and "Ya saliste" or nil)
		table.insert(rows, row("totem:off", "Craft",
			"Tótem puesto: La Silueta te percibe antes. Guárdalo antes de salir para recuperarlo.",
			"DisarmTotem", "totem", "Guardar", why == nil and not ctx.busy, why))
	elseif amount(consumables.totem) > 0 then
		local why = ctx.atCamp == false and "Ve al campamento" or nil
		table.insert(rows, row("totem:on", "Craft", "Pon el tótem: protege un objeto más, pero La Silueta te percibe antes.",
			"ArmTotem", "totem", "Poner", why == nil and not ctx.busy, why))
	end
	-- IT1: the equipment, one of each, crafted at camp and kept for the session.
	local gear = type(snapshot.gear) == "table" and snapshot.gear or {}
	local gearSpecs = type(config.gear) == "table" and config.gear or {}
	for _, item in ipairs(GEAR) do
		local spec = gearSpecs[item.id]
		if spec then
			if gear[item.id] == true then
				table.insert(rows, row("gear:" .. item.id, "Gear", ("%s (%s): %s."):format(item.title, item.owned, item.effect),
					nil, nil, nil, false))
			else
				local why = reason(ctx, snapshot, spec.cost)
				local made = row("gear:" .. item.id, "Gear", line(item.title, item.effect, spec.cost, why), "CraftGear", item.id,
					"Fabricar", why == nil, why)
				made.short = shortLine(item.title, spec.cost, why)
				table.insert(rows, made)
			end
		end
	end
	-- IT2: the Tótem de la suerte, held up to its cap and placed away from camp.
	local luck = gearSpecs.totemSuerte
	if luck then
		local held, cap = amount(snapshot.luckTotems), luck.cap or 1
		local title = "Tótem de la suerte"
		local why = reason(ctx, snapshot, luck.cost, held >= cap and ("Ya tienes el máximo (%d)"):format(cap) or nil)
		local made = row("gear:totemSuerte", "Gear", line(("%s (tienes %d de %d)"):format(title, held, cap),
			"un hallazgo cercano sale más raro; hace ruido", luck.cost, why), "CraftGear", "totemSuerte",
			"Fabricar", why == nil, why)
		made.short = shortLine(("%s %d/%d"):format(title, held, cap), luck.cost, why)
		table.insert(rows, made)
		if held > 0 then
			local placeWhy = ctx.busy == true and "Espera un momento"
				or ctx.atCamp ~= false and "Sal del campamento para ponerlo" or nil
			table.insert(rows, row("luck:place", "Gear", placeWhy and ("Pon el tótem de la suerte lejos del campamento. %s.")
				:format(placeWhy) or "Pon el tótem de la suerte aquí: el próximo hallazgo cercano sale más raro.",
				"PlaceLuck", "totemSuerte", "Poner", placeWhy == nil, placeWhy))
		end
	end
	local upgrades = type(snapshot.upgrades) == "table" and snapshot.upgrades or {}
	local names = {}
	for name in pairs(config.upgrades) do table.insert(names, name) end
	table.sort(names, function(a, b) return (UPGRADE_WORDS[a] and UPGRADE_WORDS[a].order or 9) < (UPGRADE_WORDS[b] and UPGRADE_WORDS[b].order or 9) end)
	for _, name in ipairs(names) do
		local spec = config.upgrades[name]
		local words = UPGRADE_WORDS[name] or { title = name, effect = "", owned = name .. ": comprado." }
		if upgrades[name] == true then
			table.insert(rows, row("upgrade:" .. name, "Upgrade", words.owned, nil, nil, nil, false))
		else
			local why = reason(ctx, snapshot, spec.cost)
			local made = row("upgrade:" .. name, "Upgrade", line(words.title, words.effect, spec.cost, why), "Upgrade", name, "Comprar",
				why == nil, why)
			made.short = shortLine(words.title, spec.cost, why)
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
				table.insert(rows, row("skill:" .. skill.id, "Skills", ("%s: aprendida. %s."):format(title, effect), nil, nil, nil, false))
			else
				local extra
				for _, required in ipairs(spec.requires) do
					if not owned[required] then extra = "Requiere " .. (config.skills[required] and (BRANCHES[config.skills[required].branch] or "") .. " 1" or required) end
				end
				if not extra and spec.effectLive ~= true then extra = "Efecto aún no disponible" end
				local why = reason(ctx, snapshot, spec.cost, extra)
				local made = row("skill:" .. skill.id, "Skills", line(title, effect, spec.cost, why), "Learn", skill.id, "Aprender", why == nil, why)
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
		table.insert(rows, row("bond", "Bond", ("Vínculo del compañero: nivel %d, %d XP.%s Los pulsos que aciertan en la niebla dan XP; extraer la guarda."):format(
			level, xp, pending > 0 and (" +%d pendiente."):format(pending) or "")))
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
	local why = ctx.busy and "Espera un momento" or seals < 1 and "No tienes sello. Fabrica uno en el campamento"
		or unsealed < 1 and "Nada que proteger" or sealed and "Ya hay un objeto sellado" or nil
	local armWhy = ctx.busy and "Espera un momento" or snapshot.sealArmed == true and "Preparado"
		or seals < 1 and "No tienes sello. Fabrica uno en el campamento" or nil
	return {
		row("seal:newest", "Quick", why and ("Sella el objeto más nuevo. " .. why .. ".") or "Sella el objeto más nuevo de tu bolsa.",
			"SealNewest", "seal", "Sellar", why == nil, why),
		row("seal:arm", "Quick", snapshot.sealArmed == true and "Sello preparado: tu próximo objeto nuevo queda protegido."
			or armWhy and ("Prepara un sello para tu próximo objeto. " .. armWhy .. ".") or "Prepara un sello para tu próximo objeto.",
			"ArmSeal", "seal", "Preparar", armWhy == nil, armWhy),
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
		return { text = "Nada en riesgo.", tone = "safe", glyph = "OK", atRisk = false }
	end
	local parts = {}
	if items > 0 then table.insert(parts, plural(items, "objeto", "objetos")) end
	for _, text in ipairs(lines) do table.insert(parts, text) end
	local kept = keep > 0 and (" %d a salvo."):format(keep) or ""
	local both = items > 0 and total > 0
	local short = both and ("%s, %d mat."):format(plural(items, "obj.", "obj."), total)
		or items > 0 and plural(items, "objeto", "objetos") or plural(total, "mat.", "mat.")
	local candidates = {
		"! Si te derrotan pierdes: " .. table.concat(parts, ", ") .. "." .. kept,
		"! Si te derrotan pierdes: " .. table.concat(parts, ", ") .. ".",
		"! En riesgo: " .. table.concat(parts, ", "),
		"! Pierdes: " .. short,
		"! " .. short,
		"! Pierdes " .. (items + total),
	}
	for _, text in ipairs(candidates) do
		if #text <= budget then return { text = text, tone = "risk", glyph = "!", atRisk = true } end
	end
	return { text = ("! " .. (items + total)):sub(1, math.max(1, budget)), tone = "risk", glyph = "!", atRisk = true }
end

local DIRECTIONS = table.freeze({ "N", "NE", "E", "SE", "S", "SO", "O", "NO" })

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
	local text = ("Nodo cerca: %s, %d studs al %s"):format(NAMES[best.material], math.floor(bestDistance + 0.5), DIRECTIONS[index])
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
		if atCamp == false then
			return compact and "Ve al campamento a fabricar." or "Ve al campamento, a 20 studs, para fabricar, comprar y aprender."
		end
		return compact and "Campamento: fabrica y aprende." or "En el campamento puedes fabricar, comprar y aprender."
	end
	return compact and "Solo esta sesión: se pierde al salir." or "Solo esta sesión: el progreso se pierde al salir del servidor."
end

return View
