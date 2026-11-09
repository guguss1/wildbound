-- Dev tuning schema (docs/testing/wildbound-tuning.md), shared by the server bridge and the developer panel.
-- Every value a designer may tweak live: its system, its Spanish label, its range and step, the module that reads it
-- and the module's own default. The module defaults stay the source of truth (a contract compares them with the
-- `default` here); the tuning layer only overrides them at runtime, so no folder or no attribute means no change.
-- Pure except ensureFolder, which builds the Configuration; nothing here reads a service.
local Schema = {}

Schema.FOLDER = "WildboundTuning" -- a Configuration in ReplicatedStorage, one child Configuration per system
Schema.REMOTE = "WildboundTuningRequest" -- a RemoteFunction in ReplicatedStorage, owned by the server bridge
Schema.DEV_ATTRIBUTE = "WildboundTuningDev" -- set on a Player by the server; the panel is built only when true
Schema.PRIVATE_PLACE_ID = 122652861404212
Schema.RATE = table.freeze({ burst = 20, perSecond = 10 }) -- change requests per player
Schema.ACTIONS = table.freeze({ set = true, reset = true })

-- module key -> the ModuleScript name and the file to commit a chosen value to.
Schema.MODULES = table.freeze({
	Stamina = table.freeze({ name = "WildboundStamina", file = "src/wildbound/WildboundStamina.luau (Stamina.CONSTANTS)" }),
	Island = table.freeze({ name = "WildboundIsland", file = "src/wildbound/WildboundIsland.luau (Island.CONSTANTS)" }),
	Brain = table.freeze({ name = "WildboundGuardianBrain",
		file = "src/wildbound/WildboundGuardianBrain.luau (DAY, TWILIGHT, Night profiles and Brain.NOISE)" }),
	Rules = table.freeze({ name = "WildboundWorldRules", file = "src/wildbound/WildboundWorldRules.luau (Rules.*)" }),
	Hide = table.freeze({ name = "WildboundHide", file = "src/wildbound/WildboundHide.luau (Hide.CONFIG)" }),
	Carry = table.freeze({ name = "WildboundCarry", file = "src/wildbound/WildboundCarry.luau (Carry.CONFIG)" }),
	Capture = table.freeze({ name = "WildboundCaptureSession",
		file = "src/wildbound/WildboundCaptureSession.luau (CaptureSession.CONSTANTS)" }),
	View = table.freeze({ name = "WildboundHudView", file = "src/wildbound/WildboundHudView.luau (View.CONSTANTS)" }),
	Incubator = table.freeze({ name = "WildboundIncubator",
		file = "src/wildbound/WildboundIncubator.luau (Incubator.CONSTANTS)" }),
})

-- key, label, module, target (the module's own name for it), default, min, max, step. side: where it is read.
local function value(key, label, module, target, default, min, max, step, side)
	return table.freeze({ key = key, label = label, module = module, target = target, default = default, min = min,
		max = max, step = step, side = side or "server" })
end

Schema.SYSTEMS = table.freeze({
	table.freeze({ id = "Silueta", label = "La Silueta", entries = table.freeze({
		value("PATROL_DAY", "Patrulla de día (studs/s)", "Brain", "Day.patrol", 5, 1, 20, 0.5),
		value("PATROL_TWILIGHT", "Patrulla al atardecer y al alba (studs/s)", "Brain", "Twilight.patrol", 6, 1, 20, 0.5),
		value("PATROL_NIGHT", "Patrulla de noche (studs/s)", "Brain", "Night.patrol", 7, 1, 20, 0.5),
		value("HUNT_DAY", "Persecución de día (studs/s)", "Brain", "Day.hunt", 13, 4, 30, 0.5),
		value("HUNT_TWILIGHT", "Persecución al atardecer y al alba (studs/s)", "Brain", "Twilight.hunt", 15, 4, 30, 0.5),
		value("HUNT_NIGHT", "Persecución de noche (studs/s)", "Brain", "Night.hunt", 17, 4, 30, 0.5),
		value("SIGHT_DAY", "Vista de día (studs)", "Brain", "Day.detection", 21, 5, 80, 1),
		value("SIGHT_TWILIGHT", "Vista al atardecer y al alba (studs)", "Brain", "Twilight.detection", 26, 5, 80, 1),
		value("SIGHT_NIGHT", "Vista de noche (studs)", "Brain", "Night.detection", 30, 5, 80, 1),
		value("MEMORY_DAY", "Memoria tras perderte de día (s)", "Brain", "Day.memorySeconds", 4, 0.5, 20, 0.5),
		value("MEMORY_TWILIGHT", "Memoria al atardecer y al alba (s)", "Brain", "Twilight.memorySeconds", 5, 0.5, 20, 0.5),
		value("MEMORY_NIGHT", "Memoria de noche (s)", "Brain", "Night.memorySeconds", 6, 0.5, 20, 0.5),
		value("GIVE_UP_DISTANCE", "Se rinde a esta distancia (studs)", "Rules", "GIVE_UP_DISTANCE", 100, 30, 200, 5),
		-- At least the territory (80): a strike still needs the target inside it, so a longer leash adds no strike place.
		value("CHASE_LEASH", "Correa de persecución desde su casa (studs)", "Rules", "CHASE_LEASH", 100, 80, 200, 5),
		-- At least the fair-strike warning lead (0.8 s), so a warning always fits before the hit.
		value("TELEGRAPH_SECONDS", "Aviso antes del golpe (s)", "Rules", "TELEGRAPH_SECONDS", 0.9, 0.8, 3, 0.05),
		value("ATTACK_COOLDOWN", "Pausa entre golpes (s)", "Rules", "ATTACK_COOLDOWN", 2.5, 1, 10, 0.1),
		-- Look pass: art only (never the body, sight or hit range). Applied live: the world server rescales the art.
		value("VISUAL_SCALE", "Altura de la figura (escala; 3,8 = 33 studs)", "Rules", "SILUETA_VISUAL_SCALE", 3.8, 2, 4.5,
			0.1),
	}) }),
	table.freeze({ id = "Sprint", label = "Correr y aliento", entries = table.freeze({
		value("SPRINT_MULTIPLIER", "Multiplicador al correr", "Stamina", "SPRINT_MULTIPLIER", 1.45, 1, 2, 0.05),
		value("SPEED_CAP", "Velocidad máxima al correr (studs/s)", "Stamina", "SPEED_CAP", 24, 16, 40, 1),
		value("DRAIN", "Gasto de aliento por segundo", "Stamina", "DRAIN", 25, 5, 100, 1),
		value("START", "Aliento para empezar a correr", "Stamina", "START", 10, 0, 50, 1),
		value("RECOVER", "Aliento para salir de «Sin aliento»", "Stamina", "RECOVER", 30, 0, 100, 1),
		value("REGEN_DELAY", "Espera antes de recuperar (s)", "Stamina", "REGEN_DELAY", 1.5, 0, 5, 0.1),
		value("REGEN_WALK", "Recuperación caminando (por s)", "Stamina", "REGEN_WALK", 10, 0, 50, 1),
		value("REGEN_STILL", "Recuperación quieto (por s)", "Stamina", "REGEN_STILL", 15, 0, 50, 1),
		value("NOISE_INTERVAL", "Un ruido de carrera cada (s)", "Stamina", "NOISE_INTERVAL", 1.2, 0.3, 5, 0.1),
		value("SPRINT_NOISE", "Alcance del ruido al correr (studs)", "Brain", "NOISE.sprint", 30, 0, 80, 1),
	}) }),
	table.freeze({ id = "Carry", label = "Cargar una criatura", entries = table.freeze({
		value("FEAR_RISE", "Miedo por segundo al correr", "Stamina", "FEAR_RISE", 30, 0, 100, 1),
		value("FEAR_FALL", "Calma por segundo al caminar", "Stamina", "FEAR_FALL", 12, 0, 50, 1),
		value("FEAR_WARN", "Miedo para el aviso", "Stamina", "FEAR_WARN", 45, 1, 100, 1),
		value("FEAR_SLIP", "Miedo para que se suelte", "Stamina", "FEAR_SLIP", 100, 10, 300, 5),
		value("FEAR_RADIUS", "Se asusta con La Silueta a (studs)", "Carry", "FEAR_RADIUS", 40, 0, 120, 1),
		value("UNEASY_RADIUS", "Se inquieta a (studs)", "Carry", "UNEASY_RADIUS", 80, 0, 200, 5),
		value("CRY_EVERY", "La cría llora cada (s)", "Carry", "CRY_EVERY", 6, 1, 30, 0.5),
	}) }),
	table.freeze({ id = "Islands", label = "Islas y adultos", entries = table.freeze({
		value("STIR", "Inquietud para removerse", "Island", "STIR", 40, 1, 99, 1),
		-- Above the island 1 first-steal cap (95), so the first-minute hook stays safe.
		value("WAKE", "Inquietud para despertar", "Island", "WAKE", 100, 96, 300, 1),
		value("LINGER", "Quedarse cerca (por s)", "Island", "LINGER", 6, 0, 50, 1),
		value("SPRINT", "Correr cerca (por s)", "Island", "SPRINT", 45, 0, 200, 1),
		value("LIGHT", "Luz en la cara de noche (por s)", "Island", "LIGHT", 10, 0, 50, 1),
		value("DECAY", "Se calma (por s)", "Island", "DECAY", 8, 0, 50, 1),
		value("ALERT_SECONDS", "Alerta dura (s)", "Island", "ALERT_SECONDS", 30, 5, 120, 1),
		-- Fear pass (FA2): the noise of lifting a cria or an egg.
		value("GRAB", "Ruido al robar una cría o un huevo", "Island", "GRAB", 45, 0, 100, 1),
		value("WAKE_WINDUP", "Tarda en levantarse (s)", "Island", "WAKE_WINDUP", 0.4, 0.2, 3, 0.05),
		value("CHASE_SPEED", "Velocidad del adulto (studs/s)", "Island", "CHASE_SPEED", 19, 4, 30, 0.5),
		value("CHASE_SECONDS", "Persigue durante (s)", "Island", "CHASE_SECONDS", 14, 1, 60, 1),
		value("CHASE_LEASH", "Correa desde el nido (studs)", "Island", "CHASE_LEASH", 35, 10, 80, 1),
		value("STRIKE_REACH", "Empieza el golpe a (studs)", "Island", "STRIKE_REACH", 3.5, 1, 10, 0.5),
		-- At least 0.35 s: the floor of a readable tell (CP-D1).
		value("STRIKE_WINDUP", "Aviso del golpe (s)", "Island", "STRIKE_WINDUP", 0.45, 0.35, 2, 0.05),
		value("HIT_RANGE", "El golpe acierta a (studs)", "Island", "HIT_RANGE", 5, 1, 12, 0.5),
		value("STRIKE_COOLDOWN", "Pausa entre golpes (s)", "Island", "STRIKE_COOLDOWN", 1.2, 0.3, 5, 0.1),
		value("DAMAGE", "Daño por golpe (100 = muerte)", "Island", "DAMAGE", 35, 0, 100, 1),
	}) }),
	table.freeze({ id = "Capture", label = "Captura", entries = table.freeze({
		-- At least CALM_MIN (4): the per-player skill floor.
		value("CALM_REQUIRED", "Calma necesaria (s)", "Capture", "CALM_REQUIRED", 4.5, 4, 15, 0.1),
		value("TIME_LIMIT", "Tiempo máximo (s)", "Capture", "TIME_LIMIT", 12, 5, 60, 1),
		value("RING_SPEED", "Velocidad del anillo (studs/s)", "Capture", "RING_SPEED", 1.5, 0.2, 5, 0.1),
		value("OUTSIDE_LIMIT", "Tiempo fuera del anillo (s)", "Capture", "OUTSIDE_LIMIT", 2.5, 0.5, 10, 0.1),
		value("SEAL_SWEEP", "Barrido del sello (s)", "Capture", "SEAL_SWEEP", 1.6, 0.5, 5, 0.1),
		value("SEAL_BAND", "Ancho de la franja del sello (0 a 1)", "Capture", "SEAL_BAND", 0.2, 0.05, 0.6, 0.01),
		value("SEAL_LATENCY", "Margen de latencia del sello (s)", "Capture", "SEAL_LATENCY", 0.15, 0, 0.5, 0.01),
		-- At least RETRY_MIN (3): the per-player skill floor.
		value("RETRY_COOLDOWN", "Espera para reintentar (s)", "Capture", "RETRY_COOLDOWN", 6, 3, 60, 1),
	}) }),
	table.freeze({ id = "Hide", label = "Escondites", entries = table.freeze({
		value("DAY_RADIUS", "Te descubre de día a (studs)", "Hide", "Day.radius", 4, 1, 15, 0.5),
		value("DAY_DWELL", "Tarda en descubrirte de día (s)", "Hide", "Day.dwell", 2.0, 0.2, 10, 0.1),
		value("TWILIGHT_RADIUS", "Te descubre al atardecer y al alba a (studs)", "Hide", "Twilight.radius", 5, 1, 15, 0.5),
		value("TWILIGHT_DWELL", "Tarda al atardecer y al alba (s)", "Hide", "Twilight.dwell", 1.6, 0.2, 10, 0.1),
		value("NIGHT_RADIUS", "Te descubre de noche a (studs)", "Hide", "Night.radius", 6, 1, 15, 0.5),
		value("NIGHT_DWELL", "Tarda en descubrirte de noche (s)", "Hide", "Night.dwell", 1.2, 0.2, 10, 0.1),
		value("CRY_WIDEN", "Una cría que llora suma (studs)", "Hide", "CRY_WIDEN", 2, 0, 10, 0.5),
		value("MAX_STAY", "Tiempo máximo escondido (s)", "Hide", "MAX_STAY", 45, 5, 300, 5),
		value("COOLDOWN", "Espera para volver a esconderse (s)", "Hide", "COOLDOWN", 8, 0, 60, 1),
	}) }),
	-- Next batch NB4 (delivery E): how long an egg incubates.
	table.freeze({ id = "Incubator", label = "Incubadora", entries = table.freeze({
		value("HATCH_SECONDS", "Tiempo hasta que eclosiona (s)", "Incubator", "HATCH_SECONDS", 90, 10, 900, 5),
	}) }),
	table.freeze({ id = "Camera", label = "Cámara y sensaciones (cliente)", entries = table.freeze({
		value("SPRINT_FOV_KICK", "Apertura de cámara al correr (grados)", "View", "SPRINT_FOV_KICK", 10, 0, 30, 1, "client"),
		value("DREAD_RANGE", "Temblor y viñeta desde (studs)", "View", "DREAD_RANGE", 35, 1, 100, 1, "client"),
		value("DREAD_SHAKE", "Temblor de cámara (studs)", "View", "DREAD_SHAKE", 0.35, 0, 2, 0.05, "client"),
		value("DREAD_VIGNETTE", "Oscuridad de la viñeta (0 a 1)", "View", "DREAD_VIGNETTE", 0.6, 0, 1, 0.05, "client"),
		-- Fear pass (FA3): the adrenaline burst after a grab, a hit's flash and push, the heartbeat's reach.
		value("FEAR_SECONDS", "Adrenalina tras robar (s)", "View", "FEAR_SECONDS", 3, 0.5, 10, 0.5, "client"),
		value("FEAR_SHAKE", "Temblor de la adrenalina (studs)", "View", "FEAR_SHAKE", 0.3, 0, 1, 0.05, "client"),
		value("FEAR_FOV", "Golpe de cámara de la adrenalina (grados)", "View", "FEAR_FOV", 8, 0, 20, 1, "client"),
		value("HIT_FLASH", "Destello rojo al recibir un golpe (0 a 1)", "View", "HIT_FLASH", 0.55, 0, 1, 0.05, "client"),
		value("HEART_RANGE", "Latido desde (studs)", "View", "HEART_RANGE", 45, 5, 120, 5, "client"),
		value("KNOCKBACK", "Empujón de un golpe (studs/s)", "View", "KNOCKBACK", 42, 0, 100, 2, "client"),
		-- Stalk sightings (fear pass): how often, how far and how long La Silueta is glimpsed at the edge of sight.
		value("STALK_EVERY", "Aparición: cada (s, promedio)", "View", "STALK_EVERY", 50, 10, 300, 5, "client"),
		value("STALK_COOLDOWN", "Aparición: espera mínima (s)", "View", "STALK_COOLDOWN", 30, 5, 300, 5, "client"),
		value("STALK_PER_NIGHT", "Apariciones por noche", "View", "STALK_PER_NIGHT", 3, 0, 10, 1, "client"),
		value("STALK_MIN", "Aparición: distancia mínima (studs)", "View", "STALK_MIN", 18, 10, 80, 1, "client"),
		value("STALK_MAX", "Aparición: distancia máxima (studs)", "View", "STALK_MAX", 36, 20, 120, 1, "client"),
		value("STALK_SECONDS", "Aparición: dura (s)", "View", "STALK_SECONDS", 4, 0.5, 10, 0.5, "client"),
		value("STALK_NEAR", "Aparición: se esfuma si te acercas a (studs)", "View", "STALK_NEAR", 12, 5, 40, 1, "client"),
	}) }),
})

local BY_ID = {}
for _, system in ipairs(Schema.SYSTEMS) do
	local keys = {}
	for _, entry in ipairs(system.entries) do keys[entry.key] = entry end
	BY_ID[system.id] = { system = system, keys = keys }
end

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

function Schema.find(systemId, key)
	local group = type(systemId) == "string" and BY_ID[systemId] or nil
	return group and type(key) == "string" and group.keys[key] or nil
end

function Schema.system(systemId)
	local group = type(systemId) == "string" and BY_ID[systemId] or nil
	return group and group.system or nil
end

-- A finite number clamped into the entry's range; anything else (a string, NaN, infinity, nil) is ignored: nil.
function Schema.sanitize(entry, raw)
	if type(entry) ~= "table" or not finite(raw) then return nil end
	return math.clamp(raw, entry.min, entry.max)
end

-- The effective value of one entry under `read(systemId, key)` (the attribute, or nil).
function Schema.current(entry, systemId, read)
	local raw = type(read) == "function" and read(systemId, entry.key) or nil
	local clean = Schema.sanitize(entry, raw)
	if clean == nil then return entry.default end
	return clean
end

-- Applies every value whose side matches to the given modules (module key -> required table with tune()). Each
-- module is re-tuned from its defaults, so a removed attribute goes back to the default.
function Schema.apply(modules, read, side)
	if type(modules) ~= "table" then return 0 end
	local overrides, applied = {}, 0
	for _, system in ipairs(Schema.SYSTEMS) do
		for _, entry in ipairs(system.entries) do
			if entry.side == side and modules[entry.module] then
				overrides[entry.module] = overrides[entry.module] or {}
				local clean = Schema.sanitize(entry, type(read) == "function" and read(system.id, entry.key) or nil)
				if clean ~= nil then
					overrides[entry.module][entry.target] = clean
					applied += 1
				end
			end
		end
	end
	for name, map in pairs(overrides) do
		local module = modules[name]
		if type(module) == "table" and type(module.tune) == "function" then module.tune(map) end
	end
	return applied
end

local function differs(a, b)
	return math.abs(a - b) > 1e-9
end

-- The values that differ from the defaults, as "System.KEY=value (default)" strings.
function Schema.changed(read)
	local list = {}
	for _, system in ipairs(Schema.SYSTEMS) do
		for _, entry in ipairs(system.entries) do
			local now = Schema.current(entry, system.id, read)
			if differs(now, entry.default) then
				table.insert(list, ("%s.%s=%s (%s)"):format(system.id, entry.key, Schema.format(now), Schema.format(entry.default)))
			end
		end
	end
	return list
end

function Schema.format(number)
	local text = ("%.4f"):format(number):gsub("0+$", ""):gsub("%.$", "")
	if text == "-0" then text = "0" end
	return text
end

-- The current values as a Luau table literal, grouped by system, each line naming where to commit it.
function Schema.snippet(read)
	local lines, summary, changedCount, total = {}, {}, 0, 0
	for _, system in ipairs(Schema.SYSTEMS) do
		table.insert(lines, ("\t%s = { -- %s"):format(system.id, system.label))
		local lastModule
		for _, entry in ipairs(system.entries) do
			if entry.module ~= lastModule then
				table.insert(lines, ("\t\t-- %s"):format(Schema.MODULES[entry.module].file))
				lastModule = entry.module
			end
			local now = Schema.current(entry, system.id, read)
			total += 1
			local note = ("-- %s"):format(entry.target)
			if differs(now, entry.default) then
				changedCount += 1
				note = ("-- CHANGED (default %s) %s"):format(Schema.format(entry.default), entry.target)
				table.insert(summary, ("--   %s.%s = %s (default %s) in %s"):format(system.id, entry.key, Schema.format(now),
					Schema.format(entry.default), Schema.MODULES[entry.module].file))
			end
			table.insert(lines, ("\t\t%s = %s, %s"):format(entry.key, Schema.format(now), note))
		end
		table.insert(lines, "\t},")
	end
	table.insert(lines, 1, ("-- Wildbound tuning export: %d changed of %d. Copy each CHANGED value into the file named above it."):format(
		changedCount, total))
	for index, line in ipairs(summary) do table.insert(lines, 1 + index, line) end
	table.insert(lines, 2 + #summary, "return {")
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

-- ctx = { studio, placeId, userId, creatorId, creatorType ("User" or "Group"), groupRank, allowlist = { userId } }.
-- Studio, or on the private place only: the owning user, the owning group's owner (rank 255) or an allowlisted user.
function Schema.isDeveloper(ctx)
	if type(ctx) ~= "table" then return false end
	if ctx.studio == true then return true end
	if ctx.placeId ~= Schema.PRIVATE_PLACE_ID or not finite(ctx.userId) then return false end
	if type(ctx.allowlist) == "table" and table.find(ctx.allowlist, ctx.userId) then return true end
	if ctx.creatorType == "User" then return ctx.userId == ctx.creatorId end
	if ctx.creatorType == "Group" then return ctx.groupRank == 255 end
	return false
end

-- Checks one request. Returns ok, reason, clean value. A non-developer is refused before anything else is read.
function Schema.validateRequest(ctx, action, systemId, key, raw)
	if not Schema.isDeveloper(ctx) then return false, "NotDeveloper" end
	if type(action) ~= "string" or not Schema.ACTIONS[action] then return false, "UnknownAction" end
	if action == "reset" then
		if systemId ~= nil and not Schema.system(systemId) then return false, "UnknownSystem" end
		return true, nil, nil
	end
	local entry = Schema.find(systemId, key)
	if not entry then return false, "UnknownKey" end
	if not finite(raw) then return false, "BadValue" end
	if raw < entry.min or raw > entry.max then return false, "OutOfRange" end
	return true, nil, raw
end

function Schema.newLimiter()
	return { tokens = Schema.RATE.burst, at = nil }
end

-- Token bucket: RATE.burst at once, refilled at RATE.perSecond. now is the server's clock.
function Schema.allow(limiter, now)
	if type(limiter) ~= "table" or not finite(now) then return false end
	if limiter.at ~= nil and now > limiter.at then
		limiter.tokens = math.min(Schema.RATE.burst, limiter.tokens + (now - limiter.at) * Schema.RATE.perSecond)
	end
	if limiter.at == nil or now > limiter.at then limiter.at = now end
	if limiter.tokens < 1 - 1e-9 then return false end
	limiter.tokens -= 1
	return true
end

-- Builds ReplicatedStorage.WildboundTuning (or under `parent`): one Configuration per system, every missing or
-- non-number attribute set to its default. Existing numbers are kept (a designer's Edit-mode value persists).
function Schema.ensureFolder(parent)
	local folder = parent:FindFirstChild(Schema.FOLDER)
	if not folder then
		folder = Instance.new("Configuration")
		folder.Name = Schema.FOLDER
		folder.Parent = parent
	end
	for _, system in ipairs(Schema.SYSTEMS) do
		local child = folder:FindFirstChild(system.id)
		if not child then
			child = Instance.new("Configuration")
			child.Name = system.id
			child.Parent = folder
		end
		for _, entry in ipairs(system.entries) do
			if type(child:GetAttribute(entry.key)) ~= "number" then child:SetAttribute(entry.key, entry.default) end
		end
	end
	return folder
end

-- A reader over the folder's attributes; a missing folder or system reads as nil (the default).
function Schema.reader(folder)
	return function(systemId, key)
		local child = folder and folder.Parent and folder:FindFirstChild(systemId)
		return child and child:GetAttribute(key) or nil
	end
end

return Schema
