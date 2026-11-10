-- Items and totem (plan Part 4): pure rules for the four pieces of equipment, shared by the server (gameplay) and the
-- owner's client (presentation). Each item is crafted once at camp with Esencia and materials (the recipes are in
-- WildboundEconomyConfig `gear`), lasts the session and is never saved. One of each, no stacking:
--   guantes (Guantes de captura): the calm meter fills GLOVES_CALM times faster (floored by the capture rule's
--     CALM_MIN) and the ring counts GLOVES_RING studs wider (kept under its orbit by the capture rule);
--   botas (Botas): the sprint drains BOOTS_DRAIN as fast;
--   chaleco (Chaleco): once per expedition a defeating second mark is kept as a mark (fair strike);
--   amuleto (Amuleto): La Silueta remembers you AMULET_MEMORY s less, and the heartbeat, red edge and shake on your
--     own screen are AMULET_FEAR as strong (client only).
-- The inventory server tells the world script through a server-only event and publishes ownership to the owner's
-- client as player attributes (Gear.attribute) that only it can write.
local Gear = {}

Gear.ITEMS = table.freeze({ "guantes", "botas", "chaleco", "amuleto" })
local KNOWN = table.freeze({ guantes = true, botas = true, chaleco = true, amuleto = true })
Gear.MIN_MEMORY = 0.5

Gear.CONSTANTS = table.freeze({
	GLOVES_CALM = 1.3,
	GLOVES_RING = 0.4,
	BOOTS_DRAIN = 0.7,
	AMULET_MEMORY = 1,
	AMULET_FEAR = 0.6,
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning: CONSTANTS stay the defaults the tests pin; the bridge (server) and the panel (client) override `live`.
local C = {}
Gear.live = C

function Gear.tunable()
	return table.clone(Gear.CONSTANTS)
end

function Gear.tune(overrides)
	for key, value in pairs(Gear.CONSTANTS) do C[key] = value end
	if type(overrides) ~= "table" then return end
	for key, value in pairs(overrides) do
		if Gear.CONSTANTS[key] ~= nil and finite(value) then C[key] = value end
	end
end
Gear.tune(nil)

local function owns(owned, id)
	return type(owned) == "table" and owned[id] == true
end

-- The player attribute that says this item is owned, or nil for an unknown item.
function Gear.attribute(id)
	return KNOWN[id] and "WildboundGear_" .. id or nil
end

-- Ownership read back from a player's attributes (server-written), as { [id] = true }.
function Gear.ownedFrom(getAttribute)
	local owned = {}
	if type(getAttribute) ~= "function" then return owned end
	for _, id in ipairs(Gear.ITEMS) do
		if getAttribute(Gear.attribute(id)) == true then owned[id] = true end
	end
	return owned
end

function Gear.calmRate(owned)
	return owns(owned, "guantes") and C.GLOVES_CALM or 1
end

function Gear.ringBonus(owned)
	return owns(owned, "guantes") and C.GLOVES_RING or 0
end

function Gear.drainScale(owned)
	return owns(owned, "botas") and C.BOOTS_DRAIN or 1
end

-- La Silueta's memory for this quarry, never under MIN_MEMORY.
function Gear.memory(seconds, owned)
	if not finite(seconds) then return seconds end
	if not owns(owned, "amuleto") then return seconds end
	return math.max(Gear.MIN_MEMORY, seconds - C.AMULET_MEMORY)
end

-- The fear frame on the owner's screen: the heartbeat, red edge, darkness and shake scaled down. A hit's flash and
-- the field of view stay: they tell the player what happened. Returns a copy.
function Gear.softenFear(frame, owned)
	if type(frame) ~= "table" then return frame end
	local out = table.clone(frame)
	if not owns(owned, "amuleto") then return out end
	local scale = math.clamp(finite(C.AMULET_FEAR) and C.AMULET_FEAR or 1, 0, 1)
	for _, key in ipairs({ "heart", "red", "dark", "shake" }) do
		if finite(out[key]) then out[key] *= scale end
	end
	return out
end

return Gear
