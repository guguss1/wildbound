-- Invoke with require(freshTestClone)(worldClientSource, clientSource, startSource). Source-level contracts for
-- how the start screen, the Reduced effects value and the Menu button are wired (W9). The behaviour itself is
-- covered by the pure suites (settings, tutorial, start view, camp view) and by the Play checks in
-- docs/ui/wildbound-start-and-settings.md.
return function(worldClient, client, start)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, text, message)
		assert(source:find(text, 1, true), message or ("missing: " .. text))
	end
	local function hasNot(source, text, message)
		assert(not source:find(text, 1, true), message or ("should not contain: " .. text))
	end

	case("WIRE-1: D11 the world controller starts with Reduced effects off", function()
		has(worldClient, "local reduced = false")
		hasNot(worldClient, "local reduced = true")
	end)
	case("WIRE-2: the world controller follows the Reduced attribute set by the Settings screen", function()
		has(worldClient, 'GetAttributeChangedSignal("Reduced")')
	end)
	case("WIRE-3: the inventory header has a Menu button that opens Settings", function()
		has(client, 'menuTab.Name = "MenuTab"')
		has(client, 'WildboundStartUI')
		has(client, 'SetAttribute("Screen", "settings")')
	end)
	case("WIRE-4: the inventory publishes which tab is open for the tutorial", function()
		has(client, 'SetAttribute("PanelTab"')
	end)
	case("WIRE-5: the start controller uses the pure modules, sits above the other screens and is session only", function()
		for _, name in ipairs({ "WildboundSettings", "WildboundTutorial", "WildboundStartView", "WildboundHudLayout" }) do has(start, name) end
		has(start, "gui.DisplayOrder = 30")
		for _, bad in ipairs({ "DataStore", "FireServer", "InvokeServer", "MarketplaceService", "Players:GetUserId" }) do hasNot(start, bad) end
	end)
	case("WIRE-6: the tutorial card gives way to a capture and to the inventory panel", function()
		has(start, "WildboundCapturing")
		has(start, "InventoryPanel")
	end)
	case("WIRE-7: Play closes the start screen and Replay tutorial restarts it", function()
		has(start, 'show("closed")')
		has(start, "Tutorial.restart(tutorial)")
	end)

	case("WIRE-8: the camp list skips section titles and tightens its gap on a sideways phone", function()
		has(client, "Camp.showSectionHeaders(sideways)")
		has(client, "Camp.COMPACT_GAP")
	end)
	case("WIRE-9: the TestAction seam clears itself so an action can repeat", function()
		has(start, 'SetAttribute("TestAction", nil)')
	end)

	return result
end
