-- First-run guide, pure state. Egg loop (docs/design/wildbound-egg-loop.md section 3): the first steps are steal an
-- egg, carry it home, see it go into the incubator, wait for it to hatch, one card at a time. (It was the K1 cria
-- tutorial: lanterns, cria, refuge.) The controller feeds it facts read from the player's own state snapshot; it never
-- decides anything for the server. A player whose first facts already finish every step (a returning player with a
-- hatched creature) is a "veteran": done at once, with no card and no closing line. Player-facing words are Spanish.
local Tutorial = {}

Tutorial.STEPS = table.freeze({
	table.freeze({ id = "robar", full = "1/4 Busca un nido en el bosque y mantén E para robar el huevo.",
		short = "1/4 Busca un nido y mantén E." }),
	table.freeze({ id = "llevar", full = "2/4 Corre a tu base: sigue la flecha y la luz azul.",
		short = "2/4 Lleva el huevo a tu base." }),
	table.freeze({ id = "incubar", full = "3/4 Tu huevo entra solo en la incubadora. Mira el tiempo encima.",
		short = "3/4 Tu huevo va a la incubadora." }),
	table.freeze({ id = "nacer", full = "4/4 Espera a que nazca. Mientras, vuelve al bosque por otro.",
		short = "4/4 Espera a que nazca." }),
})
Tutorial.DONE_TEXT = "¡Nuevo compañero! Roba más huevos para tu colección."

function Tutorial.new()
	return { index = 1, status = "running", observed = false }
end

function Tutorial.state(t)
	return t.status
end

function Tutorial.step(t)
	if t.status ~= "running" then return nil end
	return Tutorial.STEPS[t.index]
end

function Tutorial.progress(t)
	return ("Paso %d de %d"):format(math.min(t.index, #Tutorial.STEPS), #Tutorial.STEPS)
end

function Tutorial.cardText(step, compact)
	return compact and step.short or step.full
end

-- A later fact completes the earlier steps too (an egg already stored means it was stolen and carried).
local function met(id, f)
	local hatched = (f.registered or 0) > 0
	local incubating = (f.incubating or 0) > 0 or hatched
	local stored = (f.stored or 0) > 0 or incubating
	if id == "robar" then return f.carryingEgg == true or stored end
	if id == "llevar" then return stored end
	if id == "incubar" then return incubating end
	return hatched
end

-- Advances as far as the facts allow, in order. Returns whether anything changed. The first observation that finishes
-- every step marks a veteran.
function Tutorial.observe(t, f)
	if t.status ~= "running" or type(f) ~= "table" then return false end
	local first = t.observed ~= true
	t.observed = true
	local changed = false
	while t.status == "running" and met(Tutorial.STEPS[t.index].id, f) do
		changed = true
		if t.index >= #Tutorial.STEPS then
			t.status = first and "veteran" or "done"
		else
			t.index += 1
		end
	end
	return changed
end

function Tutorial.skip(t)
	if t.status == "running" then t.status = "skipped" end
end

-- "Repetir tutorial": from the first step again, and shown even to a veteran (the next facts move it on).
function Tutorial.restart(t)
	t.index, t.status, t.observed = 1, "running", true
end

local function count(value)
	return type(value) == "table" and #value or 0
end

-- Facts from a state snapshot (WildboundState:snapshot), tolerating any missing or odd field. campOpen and position
-- are kept for the caller's signature; no step needs them any more.
function Tutorial.factsFrom(snapshot, campOpen, position)
	snapshot = type(snapshot) == "table" and snapshot or {}
	local carrying = false
	for _, entry in ipairs(type(snapshot.pending) == "table" and snapshot.pending or {}) do
		if type(entry) == "table" and entry.kind == "Egg" and entry.inArms == true then carrying = true end
	end
	return { carryingEgg = carrying, stored = count(snapshot.bankedEggs), incubating = count(snapshot.incubating),
		registered = count(snapshot.registered), campOpen = campOpen == true }
end

return Tutorial
