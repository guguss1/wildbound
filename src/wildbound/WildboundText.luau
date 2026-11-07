-- Player-facing words, in neutral Spanish (decision H3, delivery A). Data only: no service, no logic.
-- Code, comments and docs stay English. Shared through ReplicatedStorage so the server and the clients agree.
-- Budgets are bytes, as the views measure them; tests/WildboundText_Test.luau checks every one.
local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

return freeze({
	-- Why a capture ended or was refused, keyed by the capture rule's reason. At most 64 bytes.
	CAPTURE_NOTICES = {
		Completed = "¡Atrapado! Llévalo al campamento para quedártelo.",
		LeftRing = "Saliste del anillo. Vuelve a entrar cuando se mueva.",
		TimedOut = "Muy inquieto. Quédate quieto dentro del anillo.",
		TooFar = "Te alejaste demasiado del Lumipol.",
		Struck = "La Silueta te golpeó. El Lumipol huyó.",
		Defeated = "Caíste. El Lumipol huyó.",
		Cancelled = "Te detuviste. El Lumipol retrocedió.",
		Disconnected = "",
		Lost = "El Lumipol ya no está.",
		LostTrack = "Se perdió el rastro. El Lumipol está libre.",
		Watchdog = "La captura se detuvo. Inténtalo de nuevo.",
		BackpackFull = "Bolsa llena. Vuelve al campamento a extraer.",
		CollectionFull = "Límite de colección de la sesión (100).",
		SealMissed = "Fallaste el sello. El Lumipol huyó asustado.",
		AlreadyCapturing = "Primero termina de calmar a este Lumipol.",
		InvalidContext = "Acércate con vida e inténtalo de nuevo.",
		InvalidEncounter = "Este encuentro ya no está disponible.",
		InvalidPlayer = "Esa acción no está disponible.",
		AlreadyClaimed = "Alguien ya se llevó este encuentro.",
		Reserved = "Otro jugador está calmando a este Lumipol.",
		RetryWait = "Sigue desconfiado. Prueba en unos segundos.",
		FirstCaptureOnly = "Es muy tímido ahora. Busca Lumipol en la niebla.",
		FirstCapturePending = "Primero extrae el Lumipol que llevas.",
		Wary = "Está asustado. Espera y acércate despacio.",
	},
	-- Capture screen headline per ending: { full, short }. Short forms fit 14 bytes for phone panels.
	CAPTURE_HEADLINES = {
		LeftRing = { "Saliste del anillo", "Te saliste" },
		TimedOut = { "Demasiado inquieto", "Muy inquieto" },
		TooFar = { "Te alejaste demasiado", "Muy lejos" },
		Struck = { "La Silueta te golpeó", "¡Golpe!" },
		Defeated = { "Caíste", "Caíste" },
		Cancelled = { "Te detuviste", "Detenido" },
		Lost = { "El Lumipol se fue", "Se fue" },
		LostTrack = { "Se perdió el rastro", "Sin rastro" },
		Watchdog = { "Captura detenida", "Se detuvo" },
		SealMissed = { "Sello fallido", "Sello fallido" },
	},
	-- Capture screen words for the running states, the seal step and the Stop button.
	CAPTURE_VIEW = {
		waiting = "Esperando al servidor...",
		waitingShort = "Esperando...",
		waitingDetail = "Sin noticias del servidor. El anillo sigue en su sitio.",
		outside = "Vuelve al anillo ",
		outsideShort = "¡Vuelve! ",
		outsideDetail = "Entra antes de que se acabe el tiempo.",
		slow = "Más despacio",
		slowDetail = "Quédate quieto para llenar la barra.",
		step = "Ven por aquí",
		stepDetail = "Da un paso hacia el centro del anillo.",
		calm = "Quieto...",
		calmDetail = "Quédate dentro del anillo brillante.",
		caught = "¡Atrapado!",
		ended = "Captura terminada",
		seal = "¡Sella en la franja!",
		sealShort = "¡Sella ya!",
		sealDetail = "Toca SELLAR cuando la marca cruce la franja.",
		sealButton = "SELLAR",
		stop = "Parar",
		move = "Muévete %s.",
	},
	-- Direction words for the arrow back to the ring, clockwise from where the camera looks.
	ARROWS = { "adelante", "adelante derecha", "a la derecha", "atrás derecha", "atrás", "atrás izquierda",
		"a la izquierda", "adelante izquierda" },
	PROMPTS = {
		calm = "Calmar",
		lumipol = "Lumipol",
	},
	-- One line under the capture panel when the nearest Lumipol reacts to the player.
	HINTS = {
		Alert = "¡Lo asustas! Quédate quieto.",
		Flee = "Huyó. Acércate despacio.",
		Hide = "Se escondió. Espera a que se asome.",
		Peek = "Se asoma. Acércate despacio.",
	},
})
