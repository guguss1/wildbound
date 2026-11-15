-- Invoke with require(freshTestClone)(require(freshCreatureToolbarClone), freshCreatureToolbarClone.Source, { server =
-- WildboundServer.Source, text = require(freshTextClone) }).
-- PF3 (user decision 2026-11-14): hatched creatures live in the hotbar; one placed in the OWN base farm stops following
-- the player and can be taken back to the hotbar, which never equips it. Tools are rebuilt on respawn without
-- duplicates. Every Instance here stays outside the DataModel; players, pads and state are fakes.
return function(Toolbar, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local Text, server = sources.text, sources.server

	local function signal()
		local s = { handlers = {} }
		function s:Connect(fn) table.insert(self.handlers, fn); return { Disconnect = function() end } end
		return s
	end

	local function fakePlayer(userId, position)
		local holder = Instance.new("Folder")
		local backpack = Instance.new("Backpack")
		backpack.Parent = holder
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.new(position or Vector3.zero)
		root.Parent = character
		character.Parent = holder
		local player = { UserId = userId, Parent = holder, Character = character, holder = holder }
		function player:FindFirstChildOfClass(className) return holder:FindFirstChildOfClass(className) end
		function player:WaitForChild(name) return holder:FindFirstChild(name) end
		return player
	end

	local function pad(ownerId, position)
		local model = Instance.new("Model")
		model:SetAttribute("OwnerUserId", ownerId)
		local part = Instance.new("Part")
		part.Name = "Pad"
		part.Anchored = true
		part.Size = Vector3.new(40, 1, 40)
		part.CFrame = CFrame.new(position)
		part.Parent = model
		return model
	end

	local function fixture(opts)
		opts = opts or {}
		local log = { sends = {}, unequips = {}, equips = 0, places = {}, takes = {} }
		local snapshot = { registered = opts.registered or { { uid = "c1", species = "Lumipol" } },
			equippedUid = opts.equippedUid, farm = opts.farm or {}, farmSlots = opts.farmSlots or 4 }
		-- PF4: a fake of State's farm rules (the real ones are pinned by WildboundState_Test PF4-S1 and PF4-S2).
		local state = {}
		function state:snapshot() return snapshot end
		function state:equip() log.equips += 1 end
		local function farmIndex(uid)
			for index, value in ipairs(snapshot.farm) do
				if value == uid then return index end
			end
			return nil
		end
		function state:placeInFarm(_, uid, alive)
			table.insert(log.places, uid)
			if alive ~= true then return false, "InvalidContext" end
			if farmIndex(uid) then return false, "AlreadyInFarm" end
			if #snapshot.farm >= snapshot.farmSlots then return false, "FarmFull" end
			table.insert(snapshot.farm, uid)
			local was = snapshot.equippedUid == uid
			if was then snapshot.equippedUid = nil end
			return true, was
		end
		function state:takeFromFarm(_, uid, alive)
			table.insert(log.takes, uid)
			if alive ~= true then return false, "InvalidContext" end
			local index = farmIndex(uid)
			if not index then return false, "NotInFarm" end
			table.remove(snapshot.farm, index)
			return true
		end
		local pads = opts.pads or {}
		-- PF6: a fake Heartbeat that counts live connections, and a seeded Random, so the wander is deterministic.
		local heartbeat = { handlers = {} }
		function heartbeat:Connect(fn)
			local handlers = self.handlers
			handlers[fn] = true
			return { Disconnect = function() handlers[fn] = nil end }
		end
		log.heartbeat = heartbeat
		local toolbar = Toolbar.new({
			state = state,
			players = { PlayerRemoving = signal() },
			heartbeat = heartbeat,
			random = Random.new(opts.seed or 6),
			tagged = function(tag)
				equal(tag, "WildboundBaseSlot")
				return pads
			end,
			visual = opts.visual or function()
				local model = Instance.new("Model")
				local body = Instance.new("Part")
				body.Name = "Body"
				body.Size = Vector3.new(1, 1, 1)
				body.Parent = model
				return model, body
			end,
			send = function(_, action, ok, notice) table.insert(log.sends, { action = action, ok = ok, notice = notice }) end,
			isInsideBase = function() return opts.inside == true end,
			unequip = function(_, uid)
				table.insert(log.unequips, uid)
				if snapshot.equippedUid == uid then snapshot.equippedUid = nil; return true end
				return false
			end,
			Art = { CONFIG = { ATTRIBUTE = "WildboundArtTest" } },
			Species = {},
			Text = Text,
		})
		return toolbar, log, snapshot
	end

	local function tools(player, uid)
		local list = {}
		for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and (uid == nil or item:GetAttribute("WildboundCreatureUid") == uid) then
					table.insert(list, item)
				end
			end
		end
		return list
	end

	case("CT-1: the farm words are Spanish and come from WildboundText", function()
		local F = Text.FARM
		assert(type(F) == "table", "Text.FARM")
		for _, key in ipairs({ "toolTip", "notInBase", "placed", "stored", "pickupAction", "farmFull" }) do
			assert(type(F[key]) == "string" and #F[key] > 0 and #F[key] <= 72, "FARM." .. key)
		end
		assert(F.placed:find("%s", 1, true) and F.stored:find("%s", 1, true), "placed and stored name the creature")
		assert(F.farmFull:find("%d", 1, true), "farmFull names the slot count")
		assert(not source:find("Entrá", 1, true), "no Rioplatense literal left in the module")
		assert(not source:find('"Guardaste la criatura', 1, true), "the pickup notice moved to WildboundText")
	end)

	case("CT-2: one tool per creature, named and tipped", function()
		local toolbar = fixture({ registered = { { uid = "c1", species = "Lumipol" }, { uid = "c2", species = "LumipolVioleta" } } })
		local player = fakePlayer(7)
		toolbar:syncPlayer(player)
		toolbar:syncPlayer(player)
		equal(#tools(player, "c1"), 1, "c1 once"); equal(#tools(player, "c2"), 1, "c2 once")
		local tool = tools(player, "c1")[1]
		equal(tool.Name, "Lumipol"); equal(tool.ToolTip, Text.FARM.toolTip)
		equal(tools(player, "c2")[1].Name, Text.CARD.species.LumipolVioleta)
	end)

	case("CT-3: sync removes duplicates and tools of creatures no longer owned", function()
		local toolbar = fixture()
		local player = fakePlayer(7)
		toolbar:syncPlayer(player)
		local copy = tools(player, "c1")[1]:Clone()
		copy.Parent = player.Character
		local stray = Instance.new("Tool")
		stray:SetAttribute("WildboundCreatureUid", "gone")
		stray.Parent = player:FindFirstChildOfClass("Backpack")
		toolbar:syncPlayer(player)
		equal(#tools(player, "c1"), 1, "the duplicate is removed")
		equal(#tools(player, "gone"), 0, "a creature no longer owned has no tool")
	end)

	case("CT-4: a respawn rebuilds the tools once in the new Backpack", function()
		local toolbar = fixture()
		local player = fakePlayer(7)
		toolbar:syncPlayer(player)
		player:FindFirstChildOfClass("Backpack"):Destroy()
		local fresh = Instance.new("Backpack")
		fresh.Parent = player.holder
		assert(type(toolbar.respawn) == "function", "Toolbar:respawn")
		toolbar:respawn(player)
		toolbar:respawn(player)
		equal(#tools(player, "c1"), 1, "one tool after respawn")
		equal(tools(player, "c1")[1].Parent, fresh, "in the new Backpack")
	end)

	case("CT-5: only the own base pad takes a creature; another base's pad never does", function()
		local other = pad(99, Vector3.new(0, 0, 0))
		local own = pad(7, Vector3.new(500, 0, 0))
		local toolbar, log = fixture({ pads = { other, own }, inside = false })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		toolbar:syncPlayer(player)
		local ok = toolbar:depositInFarm(player, "c1", "Lumipol", tools(player, "c1")[1])
		equal(ok, false, "refused next to someone else's pad")
		equal(#other:GetChildren(), 1, "nothing lands on another base")
		equal(#tools(player, "c1"), 1, "the tool stays in the hotbar")
		equal(log.sends[#log.sends].notice, Text.FARM.notInBase)
		assert(not source:find("any base pad", 1, true) and not source:find("Fallback", 1, true),
			"no any-pad fallback in the module")
	end)

	case("CT-6: a creature placed in the own farm stops following and leaves the hotbar", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log, snapshot = fixture({ pads = { own }, inside = true, equippedUid = "c1" })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		toolbar:syncPlayer(player)
		local ok = toolbar:depositInFarm(player, "c1", "Lumipol", tools(player, "c1")[1])
		equal(ok, true, "placed on the own pad")
		equal(log.unequips[1], "c1", "the server is asked to unequip it")
		equal(snapshot.equippedUid, nil, "no longer the companion")
		local farm = own:FindFirstChild("WildboundFarmCreature")
		assert(farm, "the farm creature stands in the own base")
		equal(farm:GetAttribute("WildboundCreatureUid"), "c1")
		equal(#tools(player, "c1"), 0, "no tool while it is in the farm")
		toolbar:syncPlayer(player)
		equal(#tools(player, "c1"), 0, "a sync does not bring it back")
		equal(log.sends[#log.sends].notice, Text.FARM.placed:format("Lumipol"))
		equal(toolbar:depositInFarm(player, "c1", "Lumipol", nil), false, "it cannot be placed twice")
	end)

	case("CT-7: taking it back puts it in the hotbar and never equips it", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log, snapshot = fixture({ pads = { own }, inside = true })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		toolbar:syncPlayer(player)
		toolbar:depositInFarm(player, "c1", "Lumipol", tools(player, "c1")[1])
		assert(type(toolbar.pickUp) == "function", "Toolbar:pickUp")
		equal(toolbar:pickUp(player, "c1"), true)
		equal(own:FindFirstChild("WildboundFarmCreature"), nil, "the farm model is gone")
		equal(#tools(player, "c1"), 1, "back in the hotbar")
		equal(snapshot.equippedUid, nil, "not equipped"); equal(log.equips, 0, "equip is never called")
		equal(log.sends[#log.sends].notice, Text.FARM.stored:format("Lumipol"))
		equal(toolbar:pickUp(player, "c1"), false, "nothing to pick up twice")
	end)

	case("CT-8: a creature the player does not own is never placed", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar = fixture({ pads = { own }, inside = true })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		equal(toolbar:depositInFarm(player, "stolen", "Lumipol", nil), false)
		equal(own:FindFirstChild("WildboundFarmCreature"), nil)
	end)

	case("CT-9: stow unequips the companion through the injected dep", function()
		local toolbar, log, snapshot = fixture({ equippedUid = "c1" })
		local player = fakePlayer(7)
		assert(type(toolbar.stow) == "function", "Toolbar:stow")
		equal(toolbar:stow(player, "c1"), true)
		equal(snapshot.equippedUid, nil); equal(log.unequips[1], "c1")
	end)

	case("CT-10: the server wires unequip, respawn and the newborn's hotbar home", function()
		assert(type(server) == "string", "server source")
		local block = server:match("CreatureToolbar%.new%((.-)\n%s*%}%)")
		assert(block, "the toolbar is created in the server")
		assert(block:find("unequip = function", 1, true), "an unequip dep")
		assert(block:find("state:unequip(", 1, true), "it unequips through State")
		assert(block:find("syncCompanion(player)", 1, true), "and removes the following companion")
		assert(server:find("Heist.creatureToolbar:respawn(player)", 1, true), "a new character rebuilds the tools")
		assert(server:find("if born.equipped then Heist.creatureToolbar:stow(player, born.uid) end", 1, true),
			"a newborn the hatch equipped goes to the hotbar instead")
		assert(server:find("Text.LOOP.hatchStored:format(spName)", 1, true), "the hatch notice says it is in the hotbar")
	end)

	local function farmModels(base)
		local list = {}
		for _, child in ipairs(base:GetChildren()) do
			if child.Name == "WildboundFarmCreature" then table.insert(list, child) end
		end
		return list
	end

	case("CT-11: PF4 placing and taking back go through State, so the farm is saved", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log, snapshot = fixture({ pads = { own }, inside = true, equippedUid = "c1" })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		toolbar:syncPlayer(player)
		equal(toolbar:depositInFarm(player, "c1", "Lumipol", tools(player, "c1")[1]), true)
		equal(log.places[1], "c1", "State:placeInFarm records it")
		equal(snapshot.farm[1], "c1")
		equal(log.unequips[1], "c1", "the server unequips it (companion attributes) as it is placed")
		equal(toolbar:pickUp(player, "c1"), true)
		equal(log.takes[1], "c1", "State:takeFromFarm records the pickup")
		equal(#snapshot.farm, 0)
		equal(#farmModels(own), 0); equal(#tools(player, "c1"), 1)
	end)

	case("CT-12: PF4 a full farm refuses a creature: nothing is unequipped and the tool stays", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log, snapshot = fixture({ pads = { own }, inside = true, equippedUid = "c1", farmSlots = 1,
			farm = { "c2" }, registered = { { uid = "c1", species = "Lumipol" }, { uid = "c2", species = "Lumipol" } } })
		local player = fakePlayer(7, Vector3.new(0, 3, 0))
		toolbar:syncPlayer(player)
		equal(toolbar:depositInFarm(player, "c1", "Lumipol", tools(player, "c1")[1]), false)
		equal(#log.unequips, 0, "the companion keeps following")
		equal(snapshot.equippedUid, "c1"); equal(#snapshot.farm, 1)
		equal(#tools(player, "c1"), 1, "the tool stays in the hotbar")
		equal(log.sends[#log.sends].notice, Text.FARM.farmFull:format(1))
	end)

	case("CT-13: PF4 a join rebuilds the saved farm on the own pad once, and follows State after", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local other = pad(99, Vector3.new(500, 0, 0))
		local toolbar, _, snapshot = fixture({ pads = { other, own }, inside = false, farm = { "c1" },
			registered = { { uid = "c1", species = "Lumipol" }, { uid = "c2", species = "Lumipol" } } })
		local player = fakePlayer(7, Vector3.new(900, 3, 0))
		toolbar:syncPlayer(player)
		local models = farmModels(own)
		equal(#models, 1, "the saved farm creature stands in the own base")
		equal(models[1]:GetAttribute("WildboundCreatureUid"), "c1")
		equal(models[1]:GetAttribute("OwnerUserId"), 7)
		assert(models[1]:FindFirstChild("PickupFarmCreaturePrompt", true), "it can be taken back")
		equal(#farmModels(other), 0, "never on another base")
		equal(#tools(player, "c1"), 0, "no tool while it is in the farm"); equal(#tools(player, "c2"), 1)
		toolbar:syncPlayer(player)
		toolbar:respawn(player)
		equal(#farmModels(own), 1, "never built twice")
		toolbar:clearPlayer(7)
		equal(#farmModels(own), 0, "a leave clears the models; State keeps the list")
		toolbar:syncPlayer(player)
		equal(#farmModels(own), 1, "rebuilt from State")
		snapshot.farm = {}
		toolbar:syncPlayer(player)
		equal(#farmModels(own), 0, "a creature no longer in the farm has no model")
		equal(#tools(player, "c1"), 1, "and is back in the hotbar")
	end)

	-- Playtest (user, 2026-11-14): farm Lumipols sank into the base floor. The live creature model has parts below its
	-- body (bounding box bottom 1.7 studs under the pad top), so a farm creature must stand on the pad's top surface.
	case("CT-14: a farm creature stands on the pad's top surface, never sunk into it", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local function sinkingVisual(_, spot)
			local model = Instance.new("Model")
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Anchored = true
			body.Size = Vector3.new(1, 1, 1)
			body.CFrame = CFrame.new(spot)
			body.Parent = model
			local leg = Instance.new("Part")
			leg.Name = "Leg"
			leg.Anchored = true
			leg.Size = Vector3.new(1, 2, 1)
			leg.CFrame = CFrame.new(spot - Vector3.new(0, 1.5, 0))
			leg.Parent = model
			return model, body
		end
		local toolbar = fixture({ pads = { own }, inside = false, farm = { "c1" }, visual = sinkingVisual })
		local player = fakePlayer(7, Vector3.new(900, 3, 0))
		toolbar:syncPlayer(player)
		local models = farmModels(own)
		equal(#models, 1, "the farm creature is built")
		local top = own.Pad.Position.Y + own.Pad.Size.Y / 2
		local frame, size = models[1]:GetBoundingBox()
		local bottom = frame.Position.Y - size.Y / 2
		assert(math.abs(bottom - top) < 0.05, ("its lowest point sits on the pad top (%.2f), got %.2f"):format(top, bottom))
	end)

	-- PF6 (user playtest 2026-11-15): farm creatures are too still; they walk and wander around the whole own pad.
	local function liveHandlers(log)
		local count = 0
		for _ in pairs(log.heartbeat.handlers) do count += 1 end
		return count
	end

	case("CT-15: PF6 a farm creature wanders inside the own pad, on its top, facing where it walks", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log = fixture({ pads = { own }, inside = false, farm = { "c1" } })
		local player = fakePlayer(7, Vector3.new(900, 3, 0))
		toolbar:syncPlayer(player)
		assert(type(toolbar.stepFarm) == "function", "Toolbar:stepFarm")
		assert(type(Toolbar.WANDER) == "table", "Toolbar.WANDER tunables")
		equal(liveHandlers(log), 1, "one Heartbeat connection for the farm")
		local model = farmModels(own)[1]
		local body = model:FindFirstChild("Body")
		local padPart = own.Pad
		local top = padPart.Position.Y + padPart.Size.Y / 2
		local margin = Toolbar.WANDER.margin
		local halfX, halfZ = padPart.Size.X / 2 - margin, padPart.Size.Z / 2 - margin
		local start = body.Position
		local travelled, facedSteps, walkingSteps = 0, 0, 0
		local spots = {}
		for _ = 1, 600 do -- 60 s at 0.1 s per step
			local before = body.Position
			toolbar:stepFarm(0.1)
			local after = body.Position
			local flat = Vector3.new(after.X - before.X, 0, after.Z - before.Z)
			travelled += flat.Magnitude
			if flat.Magnitude > 0.05 then
				walkingSteps += 1
				local look = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
				if look:Dot(flat.Unit) > 0.9 then facedSteps += 1 end
				local speed = flat.Magnitude / 0.1
				assert(speed <= Toolbar.WANDER.speed + 0.05, ("calm pace, got %.2f studs/s"):format(speed))
			end
			local localPos = padPart.CFrame:PointToObjectSpace(after)
			assert(math.abs(localPos.X) <= halfX + 0.01 and math.abs(localPos.Z) <= halfZ + 0.01,
				("inside the pad margin, got (%.2f, %.2f)"):format(localPos.X, localPos.Z))
			local frame, size = model:GetBoundingBox()
			local bottom = frame.Position.Y - size.Y / 2
			assert(bottom >= top - 0.05 and bottom <= top + Toolbar.WANDER.hop + 0.05,
				("its lowest point stays on the pad top (%.2f), got %.2f"):format(top, bottom))
			spots[math.floor(localPos.X / 6) .. ":" .. math.floor(localPos.Z / 6)] = true
		end
		assert(travelled > 40, ("it walks over time, travelled %.1f"):format(travelled))
		assert((body.Position - start).Magnitude > 0.5 or travelled > 40, "it left its spot")
		assert(walkingSteps > 0 and facedSteps / walkingSteps > 0.95,
			("it faces where it walks (%d of %d steps)"):format(facedSteps, walkingSteps))
		local cells = 0
		for _ in pairs(spots) do cells += 1 end
		assert(cells >= 6, ("it roams the whole pad, not one corner (%d cells)"):format(cells))
		assert(model:FindFirstChild("PickupFarmCreaturePrompt", true), "the pickup prompt rides along")
	end)

	case("CT-16: PF6 a picked-up or cleared farm creature is no longer stepped", function()
		local own = pad(7, Vector3.new(0, 0, 0))
		local toolbar, log, snapshot = fixture({ pads = { own }, inside = false, farm = { "c1", "c2" },
			registered = { { uid = "c1", species = "Lumipol" }, { uid = "c2", species = "Lumipol" } } })
		local player = fakePlayer(7, Vector3.new(900, 3, 0))
		toolbar:syncPlayer(player)
		equal(#farmModels(own), 2)
		equal(liveHandlers(log), 1, "one loop for all the farm models")
		toolbar:stepFarm(0.1)
		equal(toolbar:pickUp(player, "c1"), true)
		equal(toolbar:wanderCount(), 1, "the picked-up creature leaves the wander")
		toolbar:stepFarm(0.1)
		toolbar:clearPlayer(7)
		equal(toolbar:wanderCount(), 0, "a leave stops the wander")
		equal(liveHandlers(log), 0, "the loop disconnects when no farm model is left")
		toolbar:stepFarm(0.1)
		snapshot.farm = { "c2" }
		toolbar:syncPlayer(player)
		equal(toolbar:wanderCount(), 1, "a rebuilt farm wanders again")
		equal(liveHandlers(log), 1, "with one loop again")
	end)

	-- PF7 (icon upload approved by the user 2026-11-15): a species with an uploaded icon shows it in the hotbar.
	case("CT-17: PF7 a Lumipol tool shows its hotbar icon; a species without one keeps an empty TextureId", function()
		local toolbar = fixture({ registered = { { uid = "c1", species = "Lumipol" }, { uid = "c2", species = "Unknown" } } })
		local player = fakePlayer(7)
		toolbar:syncPlayer(player)
		assert(type(Toolbar.ICONS) == "table", "Toolbar.ICONS")
		local lumipol = tools(player, "c1")[1]
		equal(lumipol.TextureId, "rbxassetid://121561289565386", "the Lumipol icon")
		equal(lumipol.Name, "Lumipol", "the name stays (the tooltip and the backpack show it)")
		local unknown = tools(player, "c2")[1]
		equal(unknown.TextureId, "", "no icon for a species without one")
		equal(unknown.Name, "Unknown", "it keeps its name text")
	end)

	return result
end
