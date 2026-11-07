-- Which key (and gamepad button) each in-world prompt uses. Prompts that share a key show only the nearest one,
-- so a player standing between the extraction, hatch and protection markers at camp pressed E and got the wrong
-- action (found in W3b). Every prompt that can be in reach together gets its own key and a screen offset.
-- Names are strings; the server maps them to Enum.KeyCode. Pure data: no services, no instances.
local Keys = {}

-- offset is { x, y } in pixels, applied as ProximityPrompt.UIOffset so touch buttons do not stack.
Keys.CAMP = table.freeze({
	extract = table.freeze({ key = "E", pad = "ButtonX", offset = table.freeze({ 0, 0 }) }),
	hatch = table.freeze({ key = "R", pad = "ButtonB", offset = table.freeze({ 0, -56 }) }),
	protect = table.freeze({ key = "T", pad = "ButtonL1", offset = table.freeze({ 0, -112 }) }),
})
-- Lumipols and dropped items keep E: they are never inside the camp's prompt range together (a contract
-- checks the spawn slots against the camp markers elsewhere in the world rules).
Keys.LUMIPOL = table.freeze({ key = "E", pad = "ButtonX", offset = table.freeze({ 0, 0 }) })
Keys.GATHER = table.freeze({ key = "G", pad = "ButtonY", offset = table.freeze({ 0, 0 }) })

-- Every pair of prompts that can be in reach at once must differ on both inputs.
function Keys.conflicts()
	local groups = {
		{ "extract", Keys.CAMP.extract }, { "hatch", Keys.CAMP.hatch }, { "protect", Keys.CAMP.protect },
		{ "gather", Keys.GATHER },
	}
	local found = {}
	for first = 1, #groups do
		for second = first + 1, #groups do
			local a, b = groups[first], groups[second]
			if a[2].key == b[2].key or a[2].pad == b[2].pad then
				table.insert(found, a[1] .. " and " .. b[1] .. " share an input")
			elseif a[2].offset[1] == b[2].offset[1] and a[2].offset[2] == b[2].offset[2] and a[1] ~= "gather" and b[1] ~= "gather" then
				table.insert(found, a[1] .. " and " .. b[1] .. " share a screen offset")
			end
		end
	end
	return found
end

return Keys
