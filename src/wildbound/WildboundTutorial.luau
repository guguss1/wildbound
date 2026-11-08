-- First-run tutorial, pure state. Expedition islands (K1, docs/mechanics/wildbound-expedition-islands.md section 3):
-- the first minute is follow the lit lanterns to the clearing, take the sleeping cria, carry it to the refuge and
-- register it. The controller feeds it facts read from the player's own state snapshot and the character's position;
-- it never decides anything for the server. Player-facing words are neutral Spanish.
local Tutorial = {}

Tutorial.STEPS = table.freeze({
	table.freeze({ id = "claro", full = "1/3 Sigue los faroles encendidos hasta el claro de los Lumipol.",
		short = "1/3 Sigue los faroles hasta el claro." }),
	table.freeze({ id = "cria", full = "2/3 Acércate sin correr y toma la cría sin despertar a sus padres.",
		short = "2/3 Acércate sin correr y toma la cría." }),
	table.freeze({ id = "refugio", full = "3/3 Llévala al refugio del campamento y regístrala.",
		short = "3/3 Llévala al refugio y regístrala." }),
})
Tutorial.DONE_TEXT = "¡Es tuya! Más adentro duermen criaturas más raras."
-- Island 1, Claro de los Lumipol (assets/maps/forest-layout/islands-v1.json): within this radius counts as arrived.
Tutorial.CLARO = table.freeze({ x = -95, z = 75, radius = 22 })

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
	return ("Paso %d de %d"):format(math.min(t.index, #Tutorial.STEPS), #Tutorial.STEPS)
end

function Tutorial.cardText(step, compact)
	return compact and step.short or step.full
end

local function met(id, f)
	if id == "claro" then return f.reachedClaro == true or f.carrying == true or (f.registered or 0) > 0 end
	if id == "cria" then return f.carrying == true or (f.registered or 0) > 0 end
	return (f.registered or 0) > 0
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

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Facts from a state snapshot (WildboundState:snapshot) and the character's position { x, z }, tolerating any
-- missing or odd field. campOpen is kept for the caller's signature; no step needs it any more.
function Tutorial.factsFrom(snapshot, campOpen, position)
	snapshot = type(snapshot) == "table" and snapshot or {}
	local carrying = type(snapshot.carrying) == "table"
	local registered = type(snapshot.registered) == "table" and #snapshot.registered or 0
	local near = false
	if type(position) == "table" and finite(position.x) and finite(position.z) then
		local dx, dz = position.x - Tutorial.CLARO.x, position.z - Tutorial.CLARO.z
		near = math.sqrt(dx * dx + dz * dz) <= Tutorial.CLARO.radius
	end
	return { reachedClaro = near or carrying or registered > 0, carrying = carrying, registered = registered,
		campOpen = campOpen == true }
end

return Tutorial
