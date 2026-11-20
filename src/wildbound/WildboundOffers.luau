-- Wildbound offers catalog (P0.2 of docs/design/wildbound-fun-build-plan.md; RW-4, owner request 2026-11-20: "que lo de
-- la ruleta sea asi", after docs/design/refs/roulette-wheel-reference.webp). One list of the places where the game could
-- one day ask for Robux, with placeholder prices. Nothing here charges anyone and no game script asks Roblox for a
-- purchase: monetization stays "none" (WildboundEconomyConfig.monetization), checked by tests/WildboundOffers_Test.luau
-- and tools/test_no_purchase_calls.py.
-- The server switch DESBLOQUEAR_TODO (WildboundFlags) decides what a tap does. While it is true (development) the green
-- button does what the purchase would do, for free, on the server; when it is false the server answers "Próximamente".
-- The word "Robux" and its sign live only here and in the kit's price glyph (WildboundUiStyle.ROBUX_GLYPH).
-- The spin packs (the plan's "rouletteExtraSpins") are the owner's decision of 2026-11-20, although the economy document
-- forbade paid chance; it is recorded in the plan, section 2b. Where the extra spins live: WildboundRouletteService
-- (RW-5), for the server session only.
-- Pure: no Instance, service, clock or random source.
local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local Offers = {}

Offers.MONETIZATION = "none"
Offers.CURRENCY = "Robux"
Offers.KINDS = freeze({ "rouletteSpins" })
-- The most extra spins one player may hold at once; a pack that would pass it is refused, so nothing is lost.
Offers.MAX_EXTRA_SPINS = 99

-- id, kind, what it grants (spins), the placeholder price in Robux (like the reference: 9 / 29 / 89), the Spanish name
-- and caption, and the kit tone of its button.
Offers.LIST = freeze({
	{ id = "rouletteSpins1", kind = "rouletteSpins", spins = 1, robux = 9, name = "+1 Tirada", caption = "Paquete chico", tone = "green" },
	{ id = "rouletteSpins3", kind = "rouletteSpins", spins = 3, robux = 29, name = "+3 Tiradas", caption = "Popular", tone = "blue" },
	{ id = "rouletteSpins10", kind = "rouletteSpins", spins = 10, robux = 89, name = "+10 Tiradas", caption = "Mejor oferta", tone = "purple" },
})

Offers.WORDS = freeze({
	devFree = "modo desarrollo: gratis",
	comingSoon = "Próximamente",
	granted = "¡%s gratis! Tiradas extra: %d",
	full = "Ya tienes muchas tiradas extra. ¡Gíralas primero!",
	unknown = "Esa oferta no existe.",
	wait = "Un momento...",
})

local function whole(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge and value == math.floor(value)
end

local KNOWN_KIND = {}
for _, kind in ipairs(Offers.KINDS) do KNOWN_KIND[kind] = true end

function Offers.list()
	return Offers.LIST
end

-- get(id) -> the offer with that id, or nil (only a string id can match).
function Offers.get(id)
	if type(id) ~= "string" then return nil end
	for _, offer in ipairs(Offers.LIST) do
		if offer.id == id then return offer end
	end
	return nil
end

-- unlocked(flags) -> true only when the flags table says DESBLOQUEAR_TODO = true (missing or anything else: locked).
function Offers.unlocked(flags)
	return type(flags) == "table" and flags.DESBLOQUEAR_TODO == true
end

-- claim(id, unlocked, held) -> true, newHeld, offer; or false, reason ("UnknownOffer", "Locked", "Full"). held is the
-- player's extra spins now (anything that is not a whole count reads as 0). Pure: the caller stores newHeld.
function Offers.claim(id, unlocked, held)
	local offer = Offers.get(id)
	if not offer then return false, "UnknownOffer" end
	if unlocked ~= true then return false, "Locked" end
	local current = whole(held) and held or 0
	if current + offer.spins > Offers.MAX_EXTRA_SPINS then return false, "Full" end
	return true, current + offer.spins, offer
end

-- validate(list?) -> ok, errors. Unique ids, a known kind, whole spins and price above 0, a name and a caption.
function Offers.validate(list)
	list = list or Offers.LIST
	local errors, seen = {}, {}
	if type(list) ~= "table" or #list == 0 then return false, { "offers: none" } end
	for index, offer in ipairs(list) do
		local label = "offer " .. tostring(offer.id or index)
		if type(offer.id) ~= "string" or offer.id == "" then table.insert(errors, label .. ": id missing")
		elseif seen[offer.id] then table.insert(errors, label .. ": duplicate id") end
		if type(offer.id) == "string" then seen[offer.id] = true end
		if not KNOWN_KIND[offer.kind] then table.insert(errors, label .. ": unknown kind " .. tostring(offer.kind)) end
		if not whole(offer.spins) or offer.spins <= 0 then table.insert(errors, label .. ": spins must be a whole number above 0") end
		if not whole(offer.robux) or offer.robux <= 0 then table.insert(errors, label .. ": price must be a whole number above 0") end
		if type(offer.name) ~= "string" or offer.name == "" then table.insert(errors, label .. ": name missing") end
		if type(offer.caption) ~= "string" or offer.caption == "" then table.insert(errors, label .. ": caption missing") end
	end
	return #errors == 0, errors
end

return Offers
