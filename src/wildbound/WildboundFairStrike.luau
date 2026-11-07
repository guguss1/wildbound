-- Pure fair-strike rules (M4.2 to M4.7). Inputs by value, clock injected, no services.
-- See docs/mechanics/wildbound-fair-strike.md, decisions D2 and D6.
local FairStrike = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Damage is real only when the flag says "private" and this exact place is listed. Anything else is
-- off; a "private" flag that does not apply here is reported as misconfigured. Streaming never matters.
function FairStrike.effectiveMode(flags, placeId)
	if type(flags) ~= "table" or flags.damageMode ~= "private" then
		return "off", type(flags) == "table" and flags.damageMode ~= nil and flags.damageMode ~= "off"
	end
	local list = flags.privateTestPlaceIds
	if type(list) ~= "table" or not finite(placeId) then return "off", true end
	for _, id in ipairs(list) do
		if id == placeId then return "private", false end
	end
	return "off", true
end

return FairStrike
