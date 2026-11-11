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
	Moves = table.freeze({ name = "WildboundSiluetaMoves",
		file = "src/wildbound/WildboundSiluetaMoves.luau (Moves.CONSTANTS)" }),
	SpawnClock = table.freeze({ name = "WildboundSpawnClock",
		file = "src/wildbound/WildboundSpawnClock.luau (SpawnClock.CONSTANTS)" }),
	WaveClock = table.freeze({ name = "WildboundWaveClock",
		file = "src/wildbound/WildboundWaveClock.luau (WaveClock.CONSTANTS)" }),
	Gear = table.freeze({ name = "WildboundGear", file = "src/wildbound/WildboundGear.luau (Gear.CONSTANTS)" }),
	EggCarry = table.freeze({ name = "WildboundEggCarry",
		file = "src/wildbound/WildboundEggCarry.luau (EggCarry.CONSTANTS)" }),
	Bat = table.freeze({ name = "WildboundBat", file = "src/wildbound/WildboundBat.luau (Bat.CONSTANTS)" }),
	-- Nest Heist Phase 3 (NS5): the camp treadmill.
	Training = table.freeze({ name = "WildboundTraining",
		file = "src/wildbound/WildboundTraining.luau (Training.CONSTANTS)" }),
	-- Nest Heist Phase 3 (NS4): the companion's light.
	Refuge = table.freeze({ name = "WildboundRefuge", file = "src/wildbound/WildboundRefuge.luau (Refuge.LIGHT)" }),
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
		-- Fix pass (FP3): how long a chase may last, sized to the sprint (about 4 s of sprint at 24).
		value("CHASE_DAY", "Persecución máxima de día (s)", "Brain", "Day.chaseSeconds", 12, 4, 60, 1),
		value("CHASE_TWILIGHT", "Persecución máxima al atardecer y al alba (s)", "Brain", "Twilight.chaseSeconds", 15, 4, 60, 1),
		value("CHASE_NIGHT", "Persecución máxima de noche (s)", "Brain", "Night.chaseSeconds", 18, 4, 60, 1),
		value("GIVE_UP_DISTANCE", "Se rinde a esta distancia (studs)", "Rules", "GIVE_UP_DISTANCE", 100, 30, 200, 5),
		-- At least the territory (80): a strike still needs the target inside it, so a longer leash adds no strike place.
		value("CHASE_LEASH", "Correa de persecución desde su casa (studs)", "Rules", "CHASE_LEASH", 100, 80, 200, 5),
		-- At least the fair-strike warning lead (0.8 s), so a warning always fits before the hit.
		value("TELEGRAPH_SECONDS", "Aviso antes del golpe (s)", "Rules", "TELEGRAPH_SECONDS", 0.9, 0.8, 3, 0.05),
		value("ATTACK_COOLDOWN", "Pausa entre golpes (s)", "Rules", "ATTACK_COOLDOWN", 2.5, 1, 10, 0.1),
		-- Look pass: art only (never the body, sight or hit range). Applied live: the world server rescales the art.
		value("VISUAL_SCALE", "Altura de la figura (escala; 3,8 = 33 studs)", "Rules", "SILUETA_VISUAL_SCALE", 3.8, 2, 4.5,
			0.1),
		-- Fix pass (FP2): one Silueta per player, capped per server.
		value("MAX_HUNTERS", "Siluetas a la vez (una por jugador)", "Rules", "MAX_HUNTERS", 8, 1, 16, 1),
		-- Fix pass (FP4): her moves. A toggle is 1 (on) or 0 (off).
		value("LUNGE_ON", "Embestida (1 sí, 0 no)", "Moves", "LUNGE_ON", 1, 0, 1, 1),
		value("LUNGE_AFTER", "Embestida: tras cazar (s)", "Moves", "LUNGE_AFTER", 3, 0.5, 20, 0.5),
		value("LUNGE_TELL", "Embestida: aviso (s)", "Moves", "LUNGE_TELL", 0.5, 0.35, 2, 0.05),
		value("LUNGE_SECONDS", "Embestida: dura (s)", "Moves", "LUNGE_SECONDS", 0.8, 0.2, 3, 0.1),
		value("LUNGE_SPEED", "Embestida: velocidad (studs/s)", "Moves", "LUNGE_SPEED", 22, 10, 30, 0.5),
		value("LUNGE_COOLDOWN", "Embestida: espera (s)", "Moves", "LUNGE_COOLDOWN", 8, 1, 60, 1),
		value("FAKE_ON", "Falsa retirada (1 sí, 0 no)", "Moves", "FAKE_ON", 1, 0, 1, 1),
		value("FAKE_CHANCE", "Falsa retirada: probabilidad", "Moves", "FAKE_CHANCE", 0.25, 0, 1, 0.05),
		value("FAKE_SECONDS", "Falsa retirada: se aleja (s)", "Moves", "FAKE_SECONDS", 4, 1, 15, 0.5),
		value("GLARE_ON", "La luz la frena (1 sí, 0 no)", "Moves", "GLARE_ON", 1, 0, 1, 1),
		value("GLARE_RANGE", "Luz: alcance (studs)", "Moves", "GLARE_RANGE", 12, 4, 40, 1),
		value("GLARE_DOT", "Luz: cono (producto escalar)", "Moves", "GLARE_DOT", 0.85, 0.5, 0.99, 0.01),
		value("GLARE_HOLD", "Luz: sostener (s)", "Moves", "GLARE_HOLD", 1.5, 0.2, 5, 0.1),
		value("GLARE_STAGGER", "Luz: la frena (s)", "Moves", "GLARE_STAGGER", 1, 0.2, 5, 0.1),
		value("SCREAM_ON", "Grito que despierta nidos (1 sí, 0 no)", "Moves", "SCREAM_ON", 1, 0, 1, 1),
		value("SCREAM_REACH", "Grito: alcance (studs)", "Moves", "SCREAM_REACH", 70, 0, 200, 5),
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
		-- Nest Heist (NH4): the Burst.
		value("BURST_SECONDS", "Impulso: dura (s)", "Stamina", "BURST_SECONDS", 0.8, 0.2, 2, 0.05),
		value("BURST_MULTIPLIER", "Impulso: velocidad (x la marcha)", "Stamina", "BURST_MULTIPLIER", 1.7, 1, 2.5, 0.05),
		value("BURST_COOLDOWN", "Impulso: espera (s)", "Stamina", "BURST_COOLDOWN", 6, 1, 30, 0.5),
		value("BURST_CAP", "Impulso: velocidad máxima (studs/s)", "Stamina", "BURST_CAP", 28, 16, 40, 1),
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
		-- At least 0.8 s: the fair-strike floor (HF-T4, user decision Q1; was 0.45 with a 0.35 floor, CP-D1).
		value("STRIKE_WINDUP", "Aviso del golpe (s)", "Island", "STRIKE_WINDUP", 0.8, 0.8, 2, 0.05),
		value("HIT_RANGE", "El golpe acierta a (studs)", "Island", "HIT_RANGE", 5, 1, 12, 0.5),
		value("STRIKE_COOLDOWN", "Pausa entre golpes (s)", "Island", "STRIKE_COOLDOWN", 1.2, 0.3, 5, 0.1),
		value("DAMAGE", "Daño por golpe (100 = muerte)", "Island", "DAMAGE", 35, 0, 100, 1),
		-- Fix pass (FP5): the parents' pounce, egg recovery and noon sleep (a toggle is 1 on, 0 off).
		value("PACK_CALL_SECONDS", "Llamada de la manada: tarda (s)", "Island", "PACK_CALL_SECONDS", 0, 0, 10, 0.5),
		-- Nest Heist (NH3): the pounce became the charge (keys kept); its tell never drops under 0.8 s (fair strike).
		value("POUNCE_ON", "Embestida del adulto (1 sí, 0 no)", "Island", "POUNCE_ON", 1, 0, 1, 1),
		value("POUNCE_RANGE", "Embestida: desde (studs)", "Island", "POUNCE_RANGE", 12, 4, 20, 0.5),
		value("POUNCE_AFTER", "Embestida: tras perseguir (s)", "Island", "POUNCE_AFTER", 1, 0, 10, 0.5),
		value("POUNCE_TELL", "Embestida: aviso (s)", "Island", "POUNCE_TELL", 0.8, 0.8, 2, 0.05),
		value("POUNCE_COOLDOWN", "Embestida: espera (s)", "Island", "POUNCE_COOLDOWN", 6, 1, 30, 0.5),
		value("CHARGE_SPEED", "Embestida: velocidad (studs/s)", "Island", "CHARGE_SPEED", 40, 10, 80, 1),
		value("CHARGE_OVERSHOOT", "Embestida: se pasa (studs)", "Island", "CHARGE_OVERSHOOT", 4, 0, 12, 0.5),
		value("CHARGE_MAX", "Embestida: largo máximo (studs)", "Island", "CHARGE_MAX", 18, 4, 40, 1),
		value("CHARGE_HIT", "Embestida: acierta a (studs)", "Island", "CHARGE_HIT", 3, 1, 8, 0.5),
		value("EXPOSED_SECONDS", "Tras fallar: expuesto (s)", "Island", "EXPOSED_SECONDS", 1, 0, 5, 0.1),
		value("STEAL_WAKE", "Robar un huevo los despierta (1 sí, 0 no)", "Island", "STEAL_WAKE", 1, 0, 1, 1),
		-- Nest Heist (NH5): a chasing adult turns on a new egg carrier only within this distance of it.
		value("PERCEIVE_RANGE", "El adulto ve al nuevo portador a (studs)", "Island", "PERCEIVE_RANGE", 24, 5, 80, 1),
		value("EGG_RECOVERY_ON", "Recuperan huevos caídos (1 sí, 0 no)", "Island", "EGG_RECOVERY_ON", 1, 0, 1, 1),
		value("DEEP_SLEEP_ON", "Sueño profundo al mediodía (1 sí, 0 no)", "Island", "DEEP_SLEEP_ON", 1, 0, 1, 1),
		value("DEEP_SCALE", "Sueño profundo: ruido x", "Island", "DEEP_SCALE", 0.7, 0.1, 1, 0.05),
		value("DEEP_FROM", "Sueño profundo: desde (hora)", "Island", "DEEP_FROM", 11, 0, 24, 0.5),
		value("DEEP_TO", "Sueño profundo: hasta (hora)", "Island", "DEEP_TO", 13, 0, 24, 0.5),
		value("BREATH_AMPLITUDE", "Respiración: altura (studs)", "View", "BREATH_AMPLITUDE", 0.15, 0, 0.5, 0.01, "client"),
		value("BREATH_SECONDS", "Respiración: ritmo (s)", "View", "BREATH_SECONDS", 3, 1, 10, 0.5, "client"),
		value("BREATH_DEEP_SECONDS", "Respiración profunda: ritmo (s)", "View", "BREATH_DEEP_SECONDS", 4.5, 1, 12, 0.5,
			"client"),
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
	-- Random world (plan Part 3): the spawn clock (RW2).
	table.freeze({ id = "World", label = "Mundo aleatorio", entries = table.freeze({
		value("LIFETIME", "Un huevo o cría se muda tras (s)", "SpawnClock", "LIFETIME", 300, 10, 1800, 10),
		value("RESPAWN_COMUN", "Reaparece Común tras (s)", "SpawnClock", "RESPAWN_COMUN", 90, 0, 1800, 10),
		value("RESPAWN_RARA", "Reaparece Rara tras (s)", "SpawnClock", "RESPAWN_RARA", 150, 0, 1800, 10),
		value("RESPAWN_EPICA", "Reaparece Épica tras (s)", "SpawnClock", "RESPAWN_EPICA", 240, 0, 1800, 10),
		value("RESPAWN_LEGENDARIA", "Reaparece Legendaria tras (s)", "SpawnClock", "RESPAWN_LEGENDARIA", 360, 0, 1800, 10),
		value("MAX_COMUN", "Comunes a la vez", "SpawnClock", "MAX_COMUN", 4, 0, 12, 1),
		value("MAX_RARA", "Raras a la vez", "SpawnClock", "MAX_RARA", 3, 0, 12, 1),
		value("MAX_EPICA", "Épicas a la vez", "SpawnClock", "MAX_EPICA", 2, 0, 12, 1),
		value("MAX_LEGENDARIA", "Legendarias a la vez", "SpawnClock", "MAX_LEGENDARIA", 1, 0, 12, 1),
		value("EGG_SHARE", "Parte que son huevos (0 a 1)", "SpawnClock", "EGG_SHARE", 0.4, 0, 1, 0.05),
		-- RW3: the wave clock.
		value("WAVE_SECONDS", "Duración de una oleada (s)", "WaveClock", "WAVE_SECONDS", 300, 10, 1800, 10),
		value("FIRST_EGG_RADIUS", "Primer huevo cerca de la entrada del bosque (studs)", "WaveClock", "FIRST_EGG_RADIUS", 70, 20, 200, 5),
		-- RW4: the Refugios (never inside the territory: Rules.setRefuges refuses a circle that reaches it).
		value("REFUGE_MIN", "Refugios por oleada: mínimo", "WaveClock", "REFUGE_MIN", 2, 0, 6, 1),
		value("REFUGE_MAX", "Refugios por oleada: máximo", "WaveClock", "REFUGE_MAX", 3, 0, 6, 1),
		value("REFUGE_RADIUS", "Radio de un Refugio (studs)", "WaveClock", "REFUGE_RADIUS", 12, 4, 15, 1),
		value("REFUGE_REGEN", "Aliento en un Refugio (x)", "WaveClock", "REFUGE_REGEN", 2, 1, 4, 0.5),
		-- RW5: the biome event (one per server, one claimant).
		value("EVENT_FIRST", "Primer huevo especial a los (s)", "WaveClock", "EVENT_FIRST", 300, 0, 3600, 10),
		value("EVENT_EVERY", "Huevo especial cada (s)", "WaveClock", "EVENT_EVERY", 1200, 30, 7200, 30),
		value("EVENT_SECONDS", "Huevo especial visible (s)", "WaveClock", "EVENT_SECONDS", 300, 10, 1800, 10),
		value("EVENT_RADIUS", "Huevo especial a menos de (studs de su casa)", "WaveClock", "EVENT_RADIUS", 45, 10, 80, 5),
		-- RW6: the biome variant rotates every this many waves (never by nights).
		value("VARIANT_EVERY_WAVES", "Cambia el bosque cada (oleadas)", "WaveClock", "VARIANT_EVERY_WAVES", 1, 1, 12, 1),
	}) }),
	-- Nest Heist Phase 3 (NS5): the treadmill. HF-T4 (user decision Q9): the walk cap is 16 and stays under 17, so no
	-- walk reaches La Silueta's night hunt (17); the sprint and the Burst keep the stamina caps (24 and 28).
	table.freeze({ id = "Training", label = "Entrenamiento", entries = table.freeze({
		value("WALK_STEP", "Entrenar: velocidad por nivel (studs/s)", "Training", "WALK_STEP", 0.25, 0, 1, 0.05),
		value("MAX_LEVEL", "Entrenar: nivel máximo", "Training", "MAX_LEVEL", 4, 0, 10, 1),
		value("WALK_CAP", "Entrenar: tope al caminar (studs/s)", "Training", "WALK_CAP", 16, 16, 16.5, 0.5),
		value("BASE_COST", "Entrenar: precio del nivel 1 (Esencia)", "Training", "BASE_COST", 30, 0, 500, 5),
		value("COST_GROWTH", "Entrenar: subida del precio (x)", "Training", "COST_GROWTH", 1.6, 1, 3, 0.1),
	}) }),
	-- Nest Heist Phase 3 (NS4): the companion's light.
	table.freeze({ id = "Companion", label = "Compañero", entries = table.freeze({
		value("LIGHT_BRIGHTNESS", "Luz del compañero: brillo", "Refuge", "LIGHT_BRIGHTNESS", 1.2, 0, 5, 0.1),
		value("LIGHT_RANGE", "Luz del compañero: alcance (studs)", "Refuge", "LIGHT_RANGE", 12, 0, 30, 1),
	}) }),
	-- NS7: the gloves' caps (percent; WildboundGear.HARD_CAPS bounds them again) and the rarity weights, then IT2's
	-- luck totem.
	table.freeze({ id = "Gear", label = "Guantes y tótem", entries = table.freeze({
		value("MOVE_CAP", "Guantes: tope de Velocidad (%)", "Gear", "MOVE_CAP", 3, 0, 3, 0.5),
		value("STEAL_CAP", "Guantes: tope de Robo rápido (%)", "Gear", "STEAL_CAP", 15, 0, 25, 1),
		value("BURST_CAP", "Guantes: tope de Recarga de impulso (%)", "Gear", "BURST_CAP", 20, 0, 30, 1),
		value("DRAIN_CAP", "Guantes: tope de Aliento al correr (%)", "Gear", "DRAIN_CAP", 30, 0, 40, 1),
		value("CALM_CAP", "Guantes: tope de Calma (%)", "Gear", "CALM_CAP", 30, 0, 40, 1),
		value("WEIGHT_COMUN", "Guantes: peso de Común", "Gear", "WEIGHT_COMUN", 60, 0, 100, 1),
		value("WEIGHT_RARA", "Guantes: peso de Rara", "Gear", "WEIGHT_RARA", 28, 0, 100, 1),
		value("WEIGHT_EPICA", "Guantes: peso de Épica", "Gear", "WEIGHT_EPICA", 10, 0, 100, 1),
		value("WEIGHT_LEGENDARIA", "Guantes: peso de Legendaria", "Gear", "WEIGHT_LEGENDARIA", 2, 0, 100, 1),
		-- IT2: the Tótem de la suerte.
		value("LUCK_SECONDS", "Tótem de la suerte: dura (s)", "Gear", "LUCK_SECONDS", 60, 10, 600, 5),
		value("LUCK_RADIUS", "Tótem de la suerte: radio (studs)", "Gear", "LUCK_RADIUS", 40, 10, 120, 5),
		value("LUCK_NOISE_EVERY", "Tótem de la suerte: ruido cada (s)", "Gear", "LUCK_NOISE_EVERY", 10, 2, 60, 1),
		value("LUCK_LURE", "Tótem de la suerte atrae un hallazgo (1 sí, 0 no)", "Gear", "LUCK_LURE", 1, 0, 1, 1),
		value("LUCK_CAMP", "Tótem de la suerte: lejos del campamento (studs)", "Gear", "LUCK_CAMP", 30, 0, 120, 5),
	}) }),
	-- Nest Heist (NH1 to NH8): stealing, carrying, dropping and picking up an egg.
	table.freeze({ id = "Eggs", label = "Robo de huevos", entries = table.freeze({
		value("STEAL_HOLD", "Robar un huevo normal: mantener (s)", "EggCarry", "STEAL_HOLD", 0.8, 0.6, 1, 0.05),
		value("RARE_HOLD", "Robar un huevo raro: mantener (s)", "EggCarry", "RARE_HOLD", 1, 0.6, 3, 0.05),
		-- Hub follow-up (HF-T2): the server accepts a steal this much shorter than the hold (latency).
		value("HOLD_ALLOWANCE", "Robar: margen de latencia del mantener (s)", "EggCarry", "HOLD_ALLOWANCE", 0.35, 0.05, 0.5,
			0.05),
		-- NH5: drop and pickup.
		value("PICKUP_DELAY", "Huevo caído: se puede recoger tras (s)", "EggCarry", "PICKUP_DELAY", 0.4, 0, 2, 0.05),
		value("PICKUP_HOLD", "Recoger un huevo: mantener (s)", "EggCarry", "PICKUP_HOLD", 0.4, 0.3, 0.5, 0.05),
		-- At most 10 (NP1): State:takeEgg refuses a pickup beyond 10 studs.
		value("PICKUP_RANGE", "Recoger un huevo: alcance (studs)", "EggCarry", "PICKUP_RANGE", 10, 4, 10, 1),
		value("DROP_SECONDS", "Huevo abandonado: desaparece tras (s)", "EggCarry", "DROP_SECONDS", 30, 5, 300, 5),
	}) }),
	-- Nest Heist phase 2 (NP3): the bat every player carries. The rule keeps its floors whatever is tuned: a cooldown of
	-- at least 3 s, a reach of 3 to 8 studs, a tap never longer than the stumble, an immunity that outlasts the stumble.
	table.freeze({ id = "PvP", label = "Bate entre jugadores", entries = table.freeze({
		value("COOLDOWN", "Bate: espera entre golpes (s)", "Bat", "COOLDOWN", 12, 3, 60, 0.5),
		value("REACH", "Bate: alcance (studs)", "Bat", "REACH", 6, 3, 8, 0.5),
		value("HALF_ANGLE", "Bate: ángulo a cada lado (grados)", "Bat", "HALF_ANGLE", 60, 15, 90, 5),
		value("HEIGHT", "Bate: diferencia de altura (studs)", "Bat", "HEIGHT", 4, 1, 8, 0.5),
		value("STUMBLE_SECONDS", "Tropiezo con huevo (s)", "Bat", "STUMBLE_SECONDS", 0.45, 0.1, 1, 0.05),
		value("TAP_SECONDS", "Tropiezo sin huevo (s)", "Bat", "TAP_SECONDS", 0.2, 0, 1, 0.05),
		value("STUMBLE_SPEED", "Velocidad al tropezar (studs/s)", "Bat", "STUMBLE_SPEED", 2, 0, 16, 0.5),
		value("IMMUNITY", "Inmunidad tras un golpe (s)", "Bat", "IMMUNITY", 6, 1, 30, 0.5),
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
		-- Fix pass (FP2): how faint another player's Silueta is drawn on this client (1 = invisible).
		value("OTHER_SILUETA_FADE", "Silueta ajena: transparencia (0 a 1)", "View", "OTHER_SILUETA_FADE", 0.75, 0, 1, 0.05,
			"client"),
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
