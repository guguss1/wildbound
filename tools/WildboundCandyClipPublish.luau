-- Publishing kit for the Caramelo clips the Assistant cannot upload (odd/tasks/wildbound-caramelo.md, CE0). The game plays
-- a clip only from an Animation asset owned by the group that owns the universe; the uploads from this machine are
-- user-owned, so the owner publishes them by hand from Studio. Clips.build turns every clip of a Clips module into a
-- KeyframeSequence; Publish.build parks them, one folder per creature, in ServerStorage.WildboundPublishClips with a README
-- (Spanish) so the owner can right-click each one, "Save to Roblox" and pick the group. Once the ids are pasted into that
-- module's Clips.IDS, the creature's service already sets Clip_<name> on its model and the client plays it.
-- Pure helpers: Publish.pending (clips still without an id), Publish.parseId (an id from what the owner copies) and
-- Publish.idsSource (the Clips.IDS line to paste). Never uploads. Rules: WildboundCandyClipPublish_Test.
local Publish = {}

Publish.FOLDER = "WildboundPublishClips"

Publish.README = table.concat({
	"COMO PUBLICAR LAS ANIMACIONES (Tortidragon y Don Glaseon)",
	"",
	"Para que sirve: el juego solo puede reproducir una animacion si pertenece al mismo dueno que la experiencia (el grupo).",
	"Sin esto, Tortidragon y Don Glaseon funcionan pero se quedan quietos (pose de reposo). Con esto, se mueven en el juego.",
	"",
	"1. Studio en modo Edit (no Play). Abre ServerStorage > WildboundPublishClips > Tortidragon.",
	"2. Clic derecho en una animacion (ej. Idle) > Save to Roblox (Guardar en Roblox).",
	"3. En la ventana: Creator / Creador = el GRUPO de la experiencia (no tu usuario). Nombre: Tortidragon_<clip>. Submit.",
	"4. Copia el id que sale al final (el numero, o el enlace entero: sirve igual).",
	"5. Repite con las 11 de Tortidragon y las 11 de DonGlaseon.",
	"6. Pasa los 22 ids al asistente (o pegalos en Clips.IDS de WildboundCandyTortidragonClips y",
	"   WildboundCandyDonGlaseonClips, ej. Clips.IDS = { Idle = 123456789012, ... }).",
	"7. Los servicios ya leen Clips.IDS: al siguiente Play las criaturas se animan solas.",
	"",
	"Si esta carpeta desaparece (Studio cerrado sin guardar), el asistente la vuelve a crear en un paso.",
}, "\n")

-- The clips of a Clips module that have no valid published id yet, in its ORDER.
function Publish.pending(Clips)
	local out = {}
	for _, name in ipairs(Clips.ORDER) do
		local id = Clips.IDS and Clips.IDS[name]
		if not (type(id) == "number" and id > 0 and id % 1 == 0) then table.insert(out, name) end
	end
	return out
end

-- An asset id from what the owner copies: a number, "123", "rbxassetid://123" or a create.roblox.com / roblox.com link.
-- Returns nil for anything else.
function Publish.parseId(value)
	if type(value) == "number" then
		return (value > 0 and value % 1 == 0) and value or nil
	end
	if type(value) ~= "string" then return nil end
	local text = string.gsub(value, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local digits = string.match(text, "^(%d+)$") or string.match(text, "^rbxassetid://(%d+)$")
	if not digits then
		-- a link: the first path segment made only of digits (store/asset/<id>/..., library/<id>/..., creations/store/<id>/...)
		local path = string.match(text, "^https?://[%w%.]*roblox%.com(/.*)$")
		if path then digits = string.match(path .. "/", "/(%d+)/") end
	end
	if not digits then return nil end
	local id = tonumber(digits)
	return (id and id > 0) and id or nil
end

-- The Lua line to paste into a Clips module, in its ORDER, from { [clip] = id-like value }. Errors on an unknown clip
-- or a value that is not an id, so a typo never reaches the game.
function Publish.idsSource(Clips, ids)
	local known = {}
	for _, name in ipairs(Clips.ORDER) do known[name] = true end
	for name, value in pairs(ids) do
		assert(known[name], "unknown clip " .. tostring(name))
		assert(Publish.parseId(value), "not an asset id for " .. tostring(name) .. ": " .. tostring(value))
	end
	local parts = {}
	for _, name in ipairs(Clips.ORDER) do
		if ids[name] ~= nil then table.insert(parts, name .. " = " .. string.format("%d", Publish.parseId(ids[name]))) end
	end
	return "Clips.IDS = { " .. table.concat(parts, ", ") .. " }"
end

-- Builds (or rebuilds) parent.WildboundPublishClips: one folder per set ({ name, Clips, prefab }) holding a
-- KeyframeSequence per clip named exactly as its clip key, plus a README StringValue. Other children of the folder are
-- left alone. Returns the folder.
function Publish.build(parent, sets)
	local folder = parent:FindFirstChild(Publish.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Publish.FOLDER
	end
	local readme = folder:FindFirstChild("README")
	if not readme then
		readme = Instance.new("StringValue")
		readme.Name = "README"
		readme.Parent = folder
	end
	readme.Value = Publish.README
	for _, set in ipairs(sets) do
		local old = folder:FindFirstChild(set.name)
		if old then old:Destroy() end
		local creature = Instance.new("Folder")
		creature.Name = set.name
		for _, name in ipairs(set.Clips.ORDER) do
			set.Clips.build(set.prefab, name).Parent = creature
		end
		creature.Parent = folder
	end
	folder.Parent = parent
	return folder
end

return Publish
