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
	-- Delivery B: the creature refuge and the upgrade board. F, Q, X, G, C, I and M are taken by other controls.
	register = table.freeze({ key = "V", pad = "ButtonR1", offset = table.freeze({ 0, 56 }) }),
	board = table.freeze({ key = "B", pad = "ButtonL2", offset = table.freeze({ 0, 112 }) }),
})
-- Lumipols and dropped items keep E: they are never inside the camp's prompt range together (a contract
-- checks the spawn slots against the camp markers elsewhere in the world rules).
Keys.LUMIPOL = table.freeze({ key = "E", pad = "ButtonX", offset = table.freeze({ 0, 0 }) })
Keys.GATHER = table.freeze({ key = "G", pad = "ButtonY", offset = table.freeze({ 0, 0 }) })
-- Delivery D6: hiding spots sit off the routes, near gather nodes and Lumipols but never in camp.
Keys.HIDE = table.freeze({ key = "H", pad = "DPadUp", offset = table.freeze({ 0, 0 }) })

-- Nest Heist (NH4): the Burst is an action, not a prompt. Its key and pad are used by no prompt and by no other
-- control (E is every field prompt's, R the camp hatch prompt's; F flashlight, Q pulse, H hide, X capture seal, C and I
-- the inventory, M the menu, LeftShift and L3 sprint, R2 the seal on a gamepad, A jump).
Keys.BURST = table.freeze({ key = "Z", pad = "ButtonR3" })
-- Nest Heist phase 2 (NP5): the bat is an action too: a left click on a mouse (an interface click never swings), the
-- "Bate" button on touch and DPadRight on a gamepad, which no prompt and no other control uses.
Keys.BAT = table.freeze({ mouse = "MouseButton1", pad = "DPadRight" })
local CONTROLS = table.freeze({ keys = table.freeze({ "F", "Q", "H", "X", "C", "I", "M", "LeftShift", "F8" }),
	pads = table.freeze({ "ButtonL3", "ButtonR2", "ButtonA" }) })

-- Every pair of prompts that can be in reach at once must differ on both inputs.
function Keys.conflicts()
	local groups = {
		{ "extract", Keys.CAMP.extract }, { "hatch", Keys.CAMP.hatch }, { "protect", Keys.CAMP.protect },
		{ "register", Keys.CAMP.register }, { "board", Keys.CAMP.board }, { "gather", Keys.GATHER },
		{ "hide", Keys.HIDE },
	}
	local found = {}
	for first = 1, #groups do
		for second = first + 1, #groups do
			local a, b = groups[first], groups[second]
			if a[2].key == b[2].key or a[2].pad == b[2].pad then
				table.insert(found, a[1] .. " and " .. b[1] .. " share an input")
			elseif a[2].offset[1] == b[2].offset[1] and a[2].offset[2] == b[2].offset[2] and a[1] ~= "gather" and b[1] ~= "gather"
				and a[1] ~= "hide" and b[1] ~= "hide" then
				table.insert(found, a[1] .. " and " .. b[1] .. " share a screen offset")
			end
		end
	end
	-- A hiding spot can be in reach of a Lumipol, which keeps E (never at camp, so not in the groups above).
	if Keys.HIDE.key == Keys.LUMIPOL.key or Keys.HIDE.pad == Keys.LUMIPOL.pad then
		table.insert(found, "hide and lumipol share an input")
	end
	-- NH4: the Burst against every prompt and every other control.
	table.insert(groups, { "lumipol", Keys.LUMIPOL })
	for _, group in ipairs(groups) do
		if group[2].key == Keys.BURST.key or group[2].pad == Keys.BURST.pad then
			table.insert(found, "burst and " .. group[1] .. " share an input")
		end
	end
	for _, key in ipairs(CONTROLS.keys) do
		if key == Keys.BURST.key then table.insert(found, "burst and another control share " .. key) end
	end
	for _, pad in ipairs(CONTROLS.pads) do
		if pad == Keys.BURST.pad then table.insert(found, "burst and another control share " .. pad) end
		if pad == Keys.BAT.pad then table.insert(found, "bat and another control share " .. pad) end
	end
	-- NP5: the bat's pad against every prompt and the burst.
	for _, group in ipairs(groups) do
		if group[2].pad == Keys.BAT.pad then table.insert(found, "bat and " .. group[1] .. " share an input") end
	end
	if Keys.BAT.pad == Keys.BURST.pad then table.insert(found, "bat and burst share an input") end
	return found
end

return Keys
