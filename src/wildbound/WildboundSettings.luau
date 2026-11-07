-- Session-only settings for the start screen and the Settings panel (W9, M8.6). Pure: values live in a table
-- that the client keeps for the session. Nothing is saved anywhere; a rejoin starts from the defaults again.
-- D11: Reduced effects is off by default (On mutes the horror) and is offered on the first start screen.
local Settings = {}

Settings.ORDER = table.freeze({ "reducedEffects", "hints" })
Settings.DEFAULTS = table.freeze({ reducedEffects = false, hints = true })
-- Delivery D12: Spanish, the same words as WildboundText.SETTINGS (this module stays pure, so a test keeps them equal).
Settings.LABELS = table.freeze({ reducedEffects = "Efectos suaves", hints = "Consejos" })
Settings.DESCRIPTIONS = table.freeze({
	reducedEffects = "Niebla, luz y sustos más suaves. Apagado: ambiente completo.",
	hints = "Muestra consejos breves al empezar a jugar.",
})

function Settings.new()
	return { values = table.clone(Settings.DEFAULTS) }
end

function Settings.get(settings, key)
	if type(settings) ~= "table" or Settings.DEFAULTS[key] == nil then return nil end
	return settings.values[key]
end

-- Only a boolean for a known key is accepted. Returns whether anything was set.
function Settings.set(settings, key, value)
	if type(settings) ~= "table" or Settings.DEFAULTS[key] == nil or type(value) ~= "boolean" then return false end
	settings.values[key] = value
	return true
end

function Settings.toggle(settings, key)
	local current = Settings.get(settings, key)
	if current == nil then return nil end
	settings.values[key] = not current
	return settings.values[key]
end

function Settings.snapshot(settings)
	return table.clone(settings.values)
end

function Settings.stateText(value)
	return value and "Sí" or "No"
end

function Settings.buttonText(key, value)
	return Settings.LABELS[key] .. ": " .. Settings.stateText(value)
end

return Settings
