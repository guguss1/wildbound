-- Invoke with require(freshTestClone)(require(freshBatClone), freshBatClone.Source, { server = WildboundServer.Source,
-- worldClient = WildboundWorldClient.Source, text = require(freshTextClone), keys = require(freshKeysClone),
-- audio = WildboundAudioClient.Source, eggCarry = require(freshEggCarryClone), rules = require(freshRulesClone),
-- island = require(freshIslandClone), state = require(freshStateClone), economy = require(freshEconomyClone),
-- config = require(freshConfigClone) }).
-- Nest Heist phase 2 (docs/design/wildbound-combined-plan.md, tasks NP3 to NP6 in the feature document): the pure bat
-- rules (cooldown, server hitbox, stumble, anti-chain immunity) and the source contracts for how the inventory server
-- and the clients wire them.
return function(Bat, source, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= 1e-6,
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	local function block(text, startNeedle, endNeedle)
		local i = text:find(startNeedle, 1, true)
		assert(i, "block start missing: " .. startNeedle)
		local j = text:find(endNeedle, i + #startNeedle, true)
		assert(j, "block end missing: " .. endNeedle)
		return text:sub(i, j)
	end
	sources = type(sources) == "table" and sources or {}
	local CALM = { alive = true, safe = false, busy = false }
	-- An attacker at the origin facing +Z, and a target `ahead` studs in front, `side` studs to the right.
	local function attacker(key)
		return { key = key or 1, x = 0, y = 3, z = 0, lookX = 0, lookZ = 1 }
	end
	local function target(key, ahead, side, extra)
		local value = { key = key, x = side or 0, y = 3, z = ahead, alive = true, safe = false, hidden = false }
		for k, v in pairs(extra or {}) do value[k] = v end
		return value
	end
	local function clear() return true end

	-- NP3 the rule.
	case("NP3: the bat's numbers: 12 s cooldown, 0.45 s stumble, 6 s immunity, a short reach in front", function()
		local C = Bat.CONSTANTS
		assert(type(C) == "table", "CONSTANTS")
		equal(C.COOLDOWN, 12); equal(C.STUMBLE_SECONDS, 0.45); equal(C.IMMUNITY, 6)
		equal(C.REACH, 6, "studs from root to root: an arm and a bat on a 5-stud avatar")
		equal(C.HALF_ANGLE, 60); equal(C.HEIGHT, 4)
		equal(C.TAP_SECONDS, 0.2, "a non-carrier only gets a tiny stumble")
		equal(C.STUMBLE_SPEED, 2); equal(C.SWING_SECONDS, 0.3)
		equal(Bat.live.COOLDOWN, 12, "live starts at the defaults")
	end)

	case("NP3: one swing per cooldown, spent even on a miss; never in a safe zone, dead or busy", function()
		local reg = Bat.new()
		local ok, readyAt = Bat.swing(reg, 1, 100, CALM)
		assert(ok, "first swing"); equal(readyAt, 112)
		equal(select(2, Bat.swing(reg, 1, 111.9, CALM)), "Cooldown", "no continuous attacks")
		assert(Bat.swing(reg, 1, 112, CALM), "after 12 s")
		equal(select(2, Bat.swing(reg, 2, 0, { alive = true, safe = true })), "SafeZone", "camp, Refugio or shelter")
		equal(select(2, Bat.swing(reg, 2, 0, { alive = false })), "Dead")
		equal(select(2, Bat.swing(reg, 2, 0, { alive = true, busy = true })), "Busy", "capturing or hidden")
		assert(Bat.swing(reg, 2, 0, CALM), "a refused swing never spends the cooldown")
		equal(select(2, Bat.swing(reg, nil, 0, CALM)), "InvalidPlayer")
		equal(select(2, Bat.swing(reg, 3, 0 / 0, CALM)), "BadClock")
		equal(select(2, Bat.swing(reg, 3, 0, nil)), "Dead", "no context is never a swing")
	end)

	case("NP3: the hitbox: in reach, in front, at about the same height", function()
		local from = attacker()
		assert(Bat.inReach(from, target(2, 5)), "5 studs ahead")
		assert(Bat.inReach(from, target(2, 6)), "at the reach")
		assert(not Bat.inReach(from, target(2, 6.1)), "past the reach")
		assert(not Bat.inReach(from, target(2, -3)), "behind")
		assert(Bat.inReach(from, target(2, 2, 3)), "56 degrees off")
		assert(not Bat.inReach(from, target(2, 1, 4)), "76 degrees off")
		assert(not Bat.inReach(from, target(2, 3, 0, { y = 8 })), "5 studs above")
		assert(Bat.inReach(from, target(2, 0.2, 0, { y = 3 })), "touching counts")
		assert(not Bat.inReach(from, { x = 0 / 0, y = 3, z = 2 }), "a bad position")
		assert(not Bat.inReach({ x = 0, y = 3, z = 0, lookX = 0, lookZ = 0 }, target(2, 2)), "no facing")
	end)

	case("NP3: the target is the nearest valid player with a clear line; walls, safe zones and hiding protect", function()
		local from = attacker(1)
		local near1, far1 = target(2, 3), target(3, 5)
		equal(Bat.pickTarget(from, { far1, near1 }, clear).key, 2, "the nearest")
		local blocked = function(c) return c.key ~= 2 end
		equal(Bat.pickTarget(from, { far1, near1 }, blocked).key, 3, "a wall in front of the nearest: the next one")
		local none, why = Bat.pickTarget(from, { near1 }, function() return false end)
		equal(none, nil); equal(why, "Blocked", "no hit through a wall")
		equal(select(2, Bat.pickTarget(from, { target(2, 3, 0, { safe = true }) }, clear)), "NoTarget", "a target in camp")
		equal(select(2, Bat.pickTarget(from, { target(2, 3, 0, { hidden = true }) }, clear)), "NoTarget", "a hidden player")
		equal(select(2, Bat.pickTarget(from, { target(2, 3, 0, { alive = false }) }, clear)), "NoTarget", "a dead player")
		equal(select(2, Bat.pickTarget(from, { target(1, 3) }, clear)), "NoTarget", "never yourself")
		equal(select(2, Bat.pickTarget(from, { near1 }, nil)), "Blocked", "no line-of-sight check is never a hit")
		equal(select(2, Bat.pickTarget(from, {}, clear)), "NoTarget")
	end)

	case("NP3: a carrier stumbles 0.45 s and drops the egg; anyone else only taps; then 6 s of immunity", function()
		local reg = Bat.new()
		local effect = Bat.hit(reg, 2, 50, true)
		equal(effect.immune, false); equal(effect.drop, true); near(effect.stumble, 0.45)
		assert(Bat.stumbling(reg, 2, 50.4), "stumbling"); assert(not Bat.stumbling(reg, 2, 50.46), "over")
		equal(Bat.speed(16, reg, 2, 50.2), 2, "slowed while stumbling")
		equal(Bat.speed(16, reg, 2, 51), 16, "then free")
		equal(Bat.speed(1, reg, 2, 50.2), 1, "never faster")
		local again = Bat.hit(reg, 2, 55.9, true)
		equal(again.immune, true, "a second stun within 6 s is blocked"); equal(again.drop, false); equal(again.stumble, 0)
		assert(not Bat.stumbling(reg, 2, 56), "the blocked hit adds no stumble")
		equal(Bat.hit(reg, 2, 56, true).immune, false, "after 6 s it lands again")
		local tap = Bat.hit(reg, 3, 10, false)
		equal(tap.drop, false); near(tap.stumble, 0.2)
		equal(Bat.hit(reg, 3, 12, false).immune, true, "a tap also starts the immunity")
		equal(Bat.speed(16, reg, 9, 0), 16, "an unknown player is never slowed")
		Bat.forget(reg, 3)
		equal(Bat.hit(reg, 3, 12, false).immune, false, "a player who left is forgotten")
	end)

	case("NP3: tuning keeps the safety floors and gloves never change the bat", function()
		Bat.tune({ COOLDOWN = 0.5, REACH = 40, HALF_ANGLE = 180, IMMUNITY = 0, STUMBLE_SECONDS = 9, TAP_SECONDS = 5 })
		local L = Bat.live
		equal(L.COOLDOWN, Bat.COOLDOWN_MIN, "no continuous attacks"); equal(L.REACH, Bat.REACH_MAX)
		equal(L.HALF_ANGLE, 90); equal(L.STUMBLE_SECONDS, 1); equal(L.TAP_SECONDS, L.STUMBLE_SECONDS, "a tap never longer")
		assert(L.IMMUNITY >= L.STUMBLE_SECONDS + 1, "immunity outlasts the stumble")
		Bat.tune({ COOLDOWN = "x" })
		equal(Bat.live.COOLDOWN, 12, "a non-number is ignored")
		Bat.tune(nil)
		equal(Bat.live.REACH, 6)
		equal(Bat.COOLDOWN_MIN, 3); equal(Bat.REACH_MAX, 8)
		-- Gloves (or any gear) never add reach or stun: the rule takes no modifier and reads no gear.
		local from = attacker(); from.reach = 50; from.stun = 9
		assert(not Bat.inReach(from, target(2, 7)), "an extra reach field is ignored")
		hasNot(source, "Gear", "the rule"); hasNot(source, "glove", "the rule"); hasNot(source, "Glove", "the rule")
		local effect = Bat.hit(Bat.new(), 2, 0, true, { stun = 9 })
		near(effect.stumble, 0.45, "an extra argument is ignored")
	end)

	-- NP4 the rules together: the bat, the egg in the arms and the state, with fake player keys (1 attacker, 2 carrier,
	-- 3 and 4 bystanders). The Play check runs the real server paths with one client.
	case("NP4: a bat drops the carrier's egg for anyone; the attacker does not get it; one pickup wins the race", function()
		local EggCarry, State, Economy, Config = sources.eggCarry, sources.state, sources.economy, sources.config
		assert(EggCarry and State and Economy and Config, "the egg-carry rule and the state")
		local eggs, bats, s = EggCarry.new(), Bat.new(), State.new(Economy, Config)
		for key = 1, 4 do s:addPlayer(key) end
		EggCarry.add(eggs, "Egg:1", { species = "Lumipol", island = "I2" })
		assert(s:registerEncounter("Egg:1", "Egg"))
		local _, uid = s:pickup(2, "Egg:1", true, 0, { species = "Lumipol", tier = "Fog", arms = true })
		assert(EggCarry.steal(eggs, "Egg:1", 2, uid), "the carrier stole it")
		assert(Bat.swing(bats, 1, 100, CALM), "the attacker swings")
		local hit = Bat.pickTarget(attacker(1), { target(2, 4) }, clear)
		equal(hit and hit.key, 2, "the carrier is in front")
		local effect = Bat.hit(bats, 2, 100, EggCarry.carriedBy(eggs, 2) ~= nil)
		assert(effect.drop, "a carrier drops")
		assert(EggCarry.drop(eggs, 2, "Bat", 100, { safe = false }), "the egg leaves the arms")
		local _, entry = s:dropEgg(2)
		local egg = EggCarry.get(eggs, "Egg:1")
		equal(egg.state, "Dropped"); equal(egg.carrier, nil, "nobody's"); equal(egg.reason, "Bat")
		equal(EggCarry.carriedBy(eggs, 1), nil, "the attacker does not get it")
		equal(select(2, EggCarry.pickup(eggs, "Egg:1", 1, 100.1, "x")), "TooSoon", "not even at once")
		-- Two pickups in the same server step: the first valid one wins, the second finds it carried.
		local t = 100 + EggCarry.CONSTANTS.PICKUP_DELAY
		local okA = EggCarry.canPickup(eggs, "Egg:1", 3, t) and s:takeEgg(3, entry, true, 3)
		assert(okA and EggCarry.pickup(eggs, "Egg:1", 3, t, "u3"), "a third player picks it up")
		equal(select(2, EggCarry.canPickup(eggs, "Egg:1", 4, t)), "NotDropped", "the second request loses")
		equal(EggCarry.count(eggs, "Carried"), 1, "one carrier")
		equal(#s:snapshot(4).pending, 0, "no duplicate in the loser's bag")
		equal(#s:snapshot(3).pending, 1)
		equal(#s:snapshot(2).pending, 0, "the old carrier's arms are empty")
		-- The anti-chain immunity: the old carrier cannot be stunned again for 6 s; the new carrier can.
		equal(Bat.hit(bats, 2, 104, false).immune, true, "a second stun within 6 s")
		equal(Bat.hit(bats, 3, 104, true).immune, false, "the new carrier was never hit")
		-- No bat in the camp, and a safe zone keeps the egg in the arms.
		equal(select(2, Bat.swing(bats, 4, 200, { alive = true, safe = true })), "SafeZone")
		equal(select(2, EggCarry.drop(eggs, 3, "Bat", 200, { safe = true })), "SafeZone")
		-- No hit through a wall.
		equal(select(2, Bat.pickTarget(attacker(4), { target(3, 4) }, function() return false end)), "Blocked")
	end)

	local server = sources.server or ""
	case("NP4: the server swings over the Stance remote with the rule's cooldown and decides the hit itself", function()
		has(server, 'Heist.Bat = require(script.Parent:WaitForChild("WildboundBat"))')
		has(server, "Heist.bats = Heist.Bat.new()")
		local stance = block(server, "stanceRemote.OnServerEvent:Connect(function(player, intent, ...)", "\nend)")
		has(stance, 'if intent == "bat" then', "one known word")
		assert(stance:find("STANCE_RATE", 1, true) < stance:find('intent == "bat"', 1, true), "after the rate limit")
		assert(server:find("function Heist.swingBat(player, record, now)", 1, true)
			< server:find("stanceRemote.OnServerEvent:Connect", 1, true), "defined before the handler that calls it")
		local fn = block(server, "function Heist.swingBat(player, record, now)", "\nend\n")
		has(fn, "Bat.swing(Heist.bats, player.UserId, now,", "the rule's cooldown")
		has(fn, "Rules.zone(", "safe zones from the server's own positions")
		has(fn, "capturing or hidden", "busy")
		has(fn, "root.CFrame.LookVector", "the facing is the server's")
		has(fn, "Bat.pickTarget(from, candidates,"); has(fn, "Heist.batClear(", "line of sight")
		has(fn, "Bat.hit(Heist.bats, target.key, now,"); has(fn, 'Heist.dropEgg(victim, "Bat")', "the egg drops for anyone")
		has(fn, "WildboundBatReady"); has(fn, "WildboundBatSwing"); has(fn, "WildboundBatHit")
		has(fn, "applyCarry(victim)", "the stumble's speed"); has(fn, "Text.BAT.")
		hasNot(fn, "Gear", "gloves never change the bat"); hasNot(fn, "TakeDamage", "the bat never hurts")
		hasNot(fn, 'Instance.new("Sound")', "the inventory server makes no sounds")
		local clearFn = block(server, "function Heist.batClear(", "\nend\n")
		has(clearFn, "workspace:Raycast("); has(clearFn, "Heist.batParams")
		has(block(server, "local function applyCarry(player)", "\nend\n"), "Heist.Bat.speed(speed, Heist.bats, player.UserId,")
		local _, remotes = server:gsub('Instance.new%("RemoteEvent"%)', "")
		equal(remotes, 5, "no new remote")
		has(server, "Heist.Bat.forget(Heist.bats, player.UserId)", "a player who leaves is forgotten")
		-- NH-W13: the server script is at Luau's local limit; the bat's helpers live in the Heist table.
		for _, name in ipairs({ "swingBat", "equipBat", "batClear", "batParams", "Bat", "bats" }) do
			hasNot(server, "\nlocal function " .. name .. "(", "a top-level local function")
			hasNot(server, "\nlocal " .. name .. " ", "a top-level local")
		end
	end)

	case("NP4: every character holds a bat: unanchored, massless, no collision, touch or query, welded to the hand", function()
		local bind = block(server, "local function bindCharacter(player, character)", "\nend\n")
		has(bind, "Heist.equipBat(character)")
		local equip = block(server, "function Heist.equipBat(character)", "\nend\n")
		has(equip, 'capsulePart(model, "Handle"'); has(equip, 'capsulePart(model, "Barrel"')
		has(equip, 'weld("BatGrip", hand, handle'); has(equip, '"RightHand"'); has(equip, '"Right Arm"')
		assert(server:find("function Heist.equipBat(character)", 1, true) < server:find("local function bindCharacter(", 1, true),
			"defined before it is used")
	end)

	case("NP4: the bat's Spanish notices fit 64 bytes", function()
		local B = sources.text and sources.text.BAT
		assert(type(B) == "table", "Text.BAT")
		for _, key in ipairs({ "button", "buttonKey", "safe", "immune", "hit", "knocked", "loose" }) do
			local value = B[key]
			assert(type(value) == "string" and #value > 0 and #value <= 64, "BAT." .. key .. " " .. tostring(value))
		end
		equal(B.button, "Bate")
	end)

	-- NP5 the clients.
	case("NP5: a click, DPadRight or the Bate button asks for a swing; the button counts the cooldown down", function()
		local Keys = sources.keys
		equal(Keys.BAT and Keys.BAT.mouse, "MouseButton1"); equal(Keys.BAT.pad, "DPadRight")
		equal(#Keys.conflicts(), 0, table.concat(Keys.conflicts(), "; "))
		local client = sources.worldClient or ""
		local bat = block(client, "-- Nest Heist phase 2 (NP5): the bat.", "\nend\n")
		has(bat, '"BatButton"'); has(bat, 'stanceRemote:FireServer("bat")', "only the word")
		has(bat, "Enum.UserInputType.MouseButton1"); has(bat, "Enum.KeyCode.DPadRight")
		has(bat, "if processed or UserInputService:GetFocusedTextBox() then return end", "a click on the interface is not a swing")
		has(bat, "WildboundBatReady"); has(bat, "batWords.buttonKey"); has(bat, "batWords.button")
		hasNot(client, "\nlocal batButton", "the world client keeps its locals inside the block")
		equal(sources.text.BAT.buttonKey, "Bate (clic)")
	end)

	case("NP5: every client swings every bat on WildboundBatSwing and hears the swing and the hit", function()
		local client = sources.worldClient or ""
		local bat = block(client, "-- Nest Heist phase 2 (NP5): the bat.", "\nend\n")
		has(bat, "WildboundBatSwing"); has(bat, '"BatGrip"'); has(bat, "grip.C0 =", "the grip turns on each client")
		has(bat, "BAT_SWING_SECONDS = 0.3", "the rule's SWING_SECONDS, repeated for the client")
		equal(Bat.CONSTANTS.SWING_SECONDS, 0.3)
		local audio = sources.audio or ""
		has(audio, '{ "WildboundBatSwing", "WildboundBatHit" }')
		has(audio, 'playOnce("dirt", otherRoot', "the swing: a catalogued slot"); has(audio, 'playOnce("crack", otherRoot', "the hit")
	end)

	-- NP6 the Play check's probe (Studio only, ServerStorage only), through the real paths.
	case("NP6: the Studio-only Heist probe swings the real bat and asks the real line-of-sight ray", function()
		local studio = block(server, "if RunService:IsStudio() then\n\tlocal probe", "\nend\n")
		has(studio, 'op == "bat"'); has(studio, "Heist.swingBat(player, records[player]")
		has(studio, 'op == "batClear"'); has(studio, "Heist.batClear(root, mark)")
	end)

	return result
end
