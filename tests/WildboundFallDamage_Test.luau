-- Invoke with require(freshTestClone)(require(freshFallDamageClone), require(freshFairStrikeClone),
--   require(freshFlagsClone), require(freshTextClone), { service = <WildboundFallDamageService Source>,
--   server = <WildboundServer Source> }).
-- Fall damage (owner request 2026-11-19, "que haya daño de caida desde esa torre y de otras torres altas"): the pure
-- rules of WildboundFallDamage run against simulated falls at 60 samples a second with an injected clock (heights are
-- the Gran Torta's and the other towers' from the fall damage survey); the switch is WildboundFairStrike.effectiveMode;
-- the wiring pins read the service's and the inventory server's sources. Changes nothing.
return function(Fall, FairStrike, Flags, Text, sources)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local service = type(sources) == "table" and sources.service or ""
	local server = type(sources) == "table" and sources.server or ""
	local C = Fall.CONSTANTS

	local G = 196.2
	local DT = 1 / 60
	local FLOOR = 3.5 -- a root's standing height on the plaza floor (heights below are added to it)
	local function sample(fields)
		local s = { life = "life1", x = 0, y = 0, z = 0, alive = true, held = false, gravity = G }
		for key, value in pairs(fields) do s[key] = value end
		return s
	end
	-- One fall: three samples standing at root height `top` (skipped with opts.noStand), then off the edge (opts.jump adds
	-- that many studs of rise) in free fall, or straight down at opts.speed studs/s, until the root reaches `bottom`, where
	-- the ground ray finds the floor. opts.air(s, t, elapsed) may change each sample in the air, opts.land(s, t) the
	-- landing sample; opts.x places every sample. Returns the landing and the clock after it.
	local function fall(track, top, bottom, opts)
		opts = opts or {}
		local t = opts.at or 100
		local x = opts.x or 0
		if not opts.noStand then
			for _ = 1, 3 do
				equal(Fall.step(track, sample({ x = x, y = top, groundY = top }), t), nil, "standing is no landing")
				t += DT
			end
		end
		local vy = opts.jump and math.sqrt(2 * G * opts.jump) or 0
		local elapsed = 0
		for _ = 1, 3000 do
			elapsed += DT
			t += DT
			local y = opts.speed and top - opts.speed * elapsed or top + vy * elapsed - 0.5 * G * elapsed * elapsed
			if y <= bottom then break end
			local s = sample({ x = x, y = y })
			if opts.air then opts.air(s, t, elapsed) end
			equal(Fall.step(track, s, t), nil, "no landing in the air")
		end
		local s = sample({ x = x, y = bottom, groundY = bottom })
		if opts.land then opts.land(s, t) end
		return Fall.step(track, s, t), t
	end

	case("FD1: the numbers: free up to 20 studs, 1.5 a stud over it, capped at 40 under 100 health", function()
		equal(C.SAFE_STUDS, 20, "SAFE_STUDS")
		equal(C.DAMAGE_PER_STUD, 1.5, "DAMAGE_PER_STUD")
		equal(C.MAX_DAMAGE, 40, "MAX_DAMAGE: the hardest creature hit (WildboundBeastConfig)")
		equal(C.MAX_HEALTH, 100, "WildboundServer bindCharacter's MaxHealth")
		assert(C.MAX_HEALTH - C.MAX_DAMAGE >= 60, "a fall from full health always leaves 60")
		equal(C.SHOVE_GRACE_SECONDS, 1.5, "SHOVE_GRACE_SECONDS")
		equal(C.TELEPORT_STUDS, 20, "TELEPORT_STUDS")
		assert(C.SAFE_STUDS > 12.5 + 7.2, "a full jump off a raised bridge deck stays free")
		assert(table.isfrozen(C) and table.isfrozen(Fall), "frozen")
		equal(#Fall.REASONS, 7, "seven landing reasons")
	end)

	case("FD2: damageFor on the surveyed heights", function()
		local rows = {
			{ 0, 0 }, { 7.2, 0 }, { 11.6, 0 }, { 12.5, 0 }, { 14, 0 }, { 17.5, 0 }, { 19.7, 0 }, { 20, 0 },
			{ 21, 1 }, -- the Gran Torta's first tier walked off
			{ 22, 3 }, -- Castillo Carton's tall tower
			{ 23.2, 4 }, -- the H5 balcony
			{ 26, 9 }, -- the Seta Trueno cap
			{ 28, 12 },
			{ 38.5, 27 }, -- the second tier
			{ 46.7, 40 }, { 53.7, 40 }, { 65.3, 40 }, { 1000, 40 }, -- the third tier, the summit and beyond: capped
		}
		for _, row in ipairs(rows) do equal(Fall.damageFor(row[1]), row[2], row[1] .. " studs") end
		for _, junk in ipairs({ 0 / 0, math.huge, -math.huge, -5, "x", nil }) do
			equal(Fall.damageFor(junk), 0, "junk " .. tostring(junk))
		end
		local last = 0
		for height = 0, 120, 0.25 do
			local damage = Fall.damageFor(height)
			assert(damage >= last, "never less for a higher fall at " .. height)
			assert(damage == math.floor(damage), "whole points at " .. height)
			last = damage
		end
	end)

	case("FD3: no fall kills from full health; a hurt player can still be defeated, like any hit", function()
		for height = 0, 500, 0.5 do
			assert(Fall.damageFor(height) < C.MAX_HEALTH, "a fall of " .. height .. " kills from full health")
		end
		assert(3 * Fall.damageFor(80) >= C.MAX_HEALTH, "three big falls can defeat")
		equal(Fall.damageFor(80), C.MAX_DAMAGE, "the summit's plaza drop is the cap")
	end)

	case("FD4: real falls hurt: the first tier walked off, jumped off, the summit, the Seta Trueno", function()
		local landing = fall(Fall.new(), FLOOR + 21, FLOOR)
		equal(landing and landing.reason, "Hurt", "first tier walked off")
		near(landing.drop, 21, 0.01, "measured from where the player stood")
		equal(landing.damage, 1, "first tier walked off")
		landing = fall(Fall.new(), FLOOR + 21, FLOOR, { jump = 7.2 })
		equal(landing and landing.reason, "Hurt", "first tier jumped off")
		near(landing.drop, 21, 0.01, "measured from the takeoff: the jump's rise never counts")
		near(landing.peak, FLOOR + 28.2, 0.05, "the jump's top is kept (it times the fall)")
		equal(landing.damage, 1, "first tier jumped off")
		landing = fall(Fall.new(), FLOOR + 65.3, FLOOR)
		equal(landing.reason, "Hurt", "summit")
		equal(landing.damage, 40, "summit: capped")
		landing = fall(Fall.new(), FLOOR + 26, FLOOR)
		equal(landing.damage, 9, "Seta Trueno")
		near(landing.seconds, Fall.freefallSeconds(26, G), 4 * DT, "a free fall's time")
		-- the same record measures one fall after another
		local track = Fall.new()
		equal(fall(track, FLOOR + 38.5, FLOOR).damage, 27, "second tier, first fall")
		equal(fall(track, FLOOR + 38.5, FLOOR, { at = 200 }).damage, 27, "second tier, second fall")
	end)

	case("FD5: low drops never hurt: a jump, a bridge deck jumped off, the cake's ledges, the kitten boxes", function()
		for _, row in ipairs({ { 0, 7.2, "a jump on flat ground" }, { 12.5, 7.2, "a raised bridge deck end, jumped off" },
			{ 11.6, 7.2, "a Gran Torta ledge, jumped off" }, { 17.5, 0, "the cake's biggest one-ledge drop, walked off" },
			{ 14, 0, "a Castillo Rascador ledge" }, { 10.5, 7.2, "the Torre de Cajas, jumped off" },
			{ 14.3, 7.2, "Castillo Rascador Ledge4, jumped off" }, { 14.7, 7.2, "a raised bridge's rail, jumped off" },
			{ 15.4, 7.2, "Arbol Rascador Canopy1, jumped off" }, { 17.5, 7.2, "the cake's biggest one-ledge drop, jumped off" },
			{ 20, 7.2, "anything up to SAFE_STUDS, jumped off" } }) do
			local landing = fall(Fall.new(), FLOOR + row[1], FLOOR, { jump = row[2] > 0 and row[2] or nil })
			equal(landing and landing.reason, "Low", row[3])
			equal(landing.damage, 0, row[3])
		end
		-- stairs: 67 one-stud steps down never add up to a fall
		local track, t = Fall.new(), 100
		for step = 67, 1, -1 do
			equal(Fall.step(track, sample({ x = step, y = FLOOR + step, groundY = FLOOR + step }), t), nil, "on a step")
			t += DT
			local landing = Fall.step(track, sample({ x = step - 0.5, y = FLOOR + step - 0.5 }), t)
			t += DT
			equal(landing, nil, "in the air between steps")
			landing = Fall.step(track, sample({ x = step - 1, y = FLOOR + step - 1, groundY = FLOOR + step - 1 }), t)
			equal(landing and landing.reason, "Low", "one step down")
			t += DT
		end
	end)

	case("FD6: Calm: the first landing after a respawn, a portal, a server teleport or a held time is free", function()
		-- a new character spawns in the air
		local track = Fall.new()
		local landing = fall(track, FLOOR + 40, FLOOR, { noStand = true })
		equal(landing.reason, "Calm", "a fresh record")
		equal(landing.damage, 0, "a fresh record")
		equal(fall(track, FLOOR + 40, FLOOR, { at = 150 }).reason, "Hurt", "the next fall counts")
		track = Fall.new()
		fall(track, FLOOR + 40, FLOOR)
		local function newLife(s) s.life = "life2" end
		landing = fall(track, FLOOR + 40, FLOOR, { at = 150, air = newLife, land = newLife })
		equal(landing and landing.reason, "Calm", "a respawn")
		-- a portal trip (the portal service's WildboundPortalReadyAt changes)
		track = Fall.new()
		local function travelled(s) s.portal = 777 end
		landing = fall(track, FLOOR + 40, FLOOR, { air = travelled, land = travelled })
		equal(landing and landing.reason, "Calm", "a portal trip")
		-- a server teleport: the root jumps more than TELEPORT_STUDS between two samples
		track = Fall.new()
		equal(Fall.step(track, sample({ y = FLOOR, groundY = FLOOR }), 100), nil)
		landing = fall(track, FLOOR + 50, FLOOR, { noStand = true, x = 300, at = 100 })
		equal(landing.reason, "Calm", "a teleport into the air")
		-- held by the server for a moment (anchored hide spot, the raft's seat, swimming, climbing)
		track = Fall.new()
		landing = fall(track, FLOOR + 40, FLOOR, { air = function(s, _, elapsed) if elapsed < 0.1 then s.held = true end end })
		equal(landing.reason, "Calm", "held, then let go in the air")
		-- dead: no landing; the next character starts calm
		track = Fall.new()
		landing = fall(track, FLOOR + 40, FLOOR, { air = function(s, _, elapsed) if elapsed > 0.2 then s.alive = false end end,
			land = function(s) s.alive = false end })
		equal(landing, nil, "a dead body never lands")
	end)

	case("FD7: Shoved: a push, a hit, the bat or a ragdoll before or during the fall makes it free", function()
		equal(Fall.shoved(100, nil, 101.5), true, "1.5 s after")
		equal(Fall.shoved(100, nil, 101.51), false, "an old push")
		equal(Fall.shoved(nil, 105, 101), true, "ragdolled")
		equal(Fall.shoved(nil, 100, 101), false, "the ragdoll is over")
		equal(Fall.shoved(nil, nil, 101), false, "nothing")
		equal(Fall.shoved("x", 0 / 0, 101), false, "junk")
		local landing = fall(Fall.new(), FLOOR + 65.3, FLOOR, { air = function(s) s.shovedAt = 100 end })
		equal(landing.reason, "Shoved", "pushed off the summit (La Duquesa, Frutillon)")
		equal(landing.damage, 0, "pushed off the summit")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { air = function(s) s.shovedAt = 98 end })
		equal(landing.reason, "Hurt", "a push 2 s before the takeoff is over")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { air = function(s, t) s.ragdollUntil = t + 1 end })
		equal(landing.reason, "Shoved", "the bat's ragdoll")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { air = function(s, t, elapsed) if elapsed > 0.3 then s.shovedAt = t end end })
		equal(landing.reason, "Shoved", "a hit in the air")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { land = function(s, t) s.shovedAt = t end })
		equal(landing.reason, "Shoved", "a hit at the landing")
	end)

	case("FD8: Bridge and Soft: a crumbling cookie bridge, a landing in the chocolate", function()
		local landing = fall(Fall.new(), FLOOR + 24, FLOOR, { jump = 7.2, air = function(s) s.crumbling = true end })
		equal(landing.reason, "Bridge", "a crumbling deck")
		equal(landing.damage, 0, "a crumbling deck")
		landing = fall(Fall.new(), FLOOR + 30, FLOOR, { land = function(s) s.crumbling = true end })
		equal(landing.reason, "Bridge", "landing in a crumbling bridge's footprint")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { land = function(s) s.soft = true end })
		equal(landing.reason, "Soft", "into the chocolate")
		equal(landing.damage, 0, "into the chocolate")
		landing = fall(Fall.new(), FLOOR + 40, FLOOR, { air = function(s) s.soft = true end })
		equal(landing.reason, "Hurt", "only the landing spot counts, not what was under the fall")
	end)

	case("FD9: Slow and rest: only a real fall hurts; standing on what the ray cannot see ends a fall", function()
		local landing = fall(Fall.new(), FLOOR + 30, FLOOR, { speed = 20 })
		equal(landing.reason, "Slow", "30 studs down at 20 studs/s (a ramp the ray cannot see, a climb down)")
		equal(landing.damage, 0, "slow")
		assert(1.5 > C.FALL_TIME_FACTOR * Fall.freefallSeconds(30, G) + C.FALL_TIME_SLACK, "slower than a fall")
		near(Fall.freefallSeconds(21, G), 0.4627, 0.001, "a 21-stud free fall")
		near(Fall.freefallSeconds(21, 0 / 0), 0.4627, 0.001, "junk gravity: the default")
		-- a wait on the edge (the ray under the root sees the void) is no fall time
		local track, t = Fall.new(), 100
		equal(Fall.step(track, sample({ y = FLOOR + 40, groundY = FLOOR + 40 }), t), nil)
		for _ = 1, 12 do
			t += DT
			equal(Fall.step(track, sample({ y = FLOOR + 40 }), t), nil, "waiting on the edge")
		end
		landing = fall(track, FLOOR + 40, FLOOR, { noStand = true, at = t })
		equal(landing.reason, "Hurt", "a wait on the edge, then a fall")
		equal(landing.damage, Fall.damageFor(40), "the whole drop")
		-- a 30-stud fall onto something the ray cannot see, then still for REST_SECONDS: no landing and no hit; the next
		-- fall counts from there
		track, t = Fall.new(), 100
		equal(Fall.step(track, sample({ y = FLOOR + 60, groundY = FLOOR + 60 }), t), nil)
		local elapsed = 0
		while true do
			elapsed += DT
			t += DT
			local y = FLOOR + 60 - 0.5 * G * elapsed * elapsed
			if y <= FLOOR + 30 then break end
			equal(Fall.step(track, sample({ y = y }), t), nil, "falling")
		end
		for _ = 1, 30 do
			t += DT
			equal(Fall.step(track, sample({ y = FLOOR + 30 }), t), nil, "still at 30 with no ground under the ray")
		end
		landing = fall(track, FLOOR + 30, FLOOR, { noStand = true, at = t })
		equal(landing and landing.reason, "Hurt", "the fall after the rest")
		near(landing.drop, 30, 0.01, "counted from the rest")
	end)

	case("FD10: junk and the helpers", function()
		equal(Fall.step(nil, sample({}), 1), nil, "no record")
		local track = Fall.new()
		equal(Fall.step(track, nil, 1), nil, "no character")
		equal(Fall.step(track, sample({ y = 0 / 0 }), 1), nil, "NaN height")
		equal(Fall.step(track, sample({}), 0 / 0), nil, "NaN clock")
		equal(track.calm, true, "junk makes the next landing free")
		equal(Fall.inAir(track), false, "not in the air")
		equal(Fall.inAir(nil), false, "junk")
		equal(Fall.groundHeight(10, 1, 2, false), 13, "R15: HipHeight under the root's bottom")
		equal(Fall.groundHeight(10, 1, 0, true), 13, "R6: 2-stud legs")
		near(Fall.groundHeight(10, 1, 3.1, false), 14.1, 1e-9, "a taller R15")
		equal(Fall.groundHeight(10, nil, nil, false), 13, "junk sizes: the defaults")
		equal(Fall.groundHeight(nil, 1, 2, false), nil, "no hit")
		equal(Fall.rayLength(1, 2, false), 1 + 2 + C.GROUND_SLACK, "the ground ray")
		equal(Fall.hurt(100, 97), true, "a 3-point hit")
		equal(Fall.hurt(100, 98), false, "regeneration noise")
		equal(Fall.hurt(nil, 50), false, "no reading")
	end)

	case("FD11: the switch is creature damage's: effectiveMode, private only on a listed place", function()
		local private = { damageMode = "private", privateTestPlaceIds = { 7 } }
		equal(FairStrike.effectiveMode(private, 7), "private", "the listed place")
		equal(FairStrike.effectiveMode(private, 8), "off", "any other place")
		equal(FairStrike.effectiveMode({ damageMode = "off", privateTestPlaceIds = { 7 } }, 7), "off", "the flag off")
		equal(FairStrike.effectiveMode(nil, 7), "off", "no flags")
		equal(FairStrike.effectiveMode(Flags, 0), "off", "the real flags: off on any unlisted place")
	end)

	case("FD12: the service: the same switch as creature damage, checked before anything is sampled", function()
		has(service, 'script.Parent:FindFirstChild("WildboundFlags")', "the flags module")
		has(service, "FairStrike.effectiveMode(flagsOk and flags or nil, game.PlaceId)", "the creature damage switch")
		local gate = string.find(service, 'if damageMode ~= "private" then return end', 1, true)
		local loop = string.find(service, "RunService.Heartbeat:Connect", 1, true)
		assert(gate and loop and gate < loop, "off ends the script before the sampling starts")
		hasNot(service, "DamageEnabled", "no attribute decides damage")
		hasNot(service, "TakeDamage", "damage only through BeastHit")
		hasNot(service, "Health =", "damage only through BeastHit")
		hasNot(service, "OnServerEvent", "no client request")
		hasNot(service, "FireClient", "the notice is BeastHit's")
		hasNot(service, "WalkSpeed", "no speed change")
	end)

	case("FD13: the service: one hit path, BeastHit as beast Fall with the egg kept", function()
		has(service, 'ReplicatedStorage:FindFirstChild("WildboundNetwork")', "the inventory server's network")
		has(service, 'network:FindFirstChild("BeastHit")', "the creatures' hit path")
		has(service, 'beastHit:Invoke(player, "Fall", damage, true)', "beast Fall, egg kept")
		has(service, 'landing.reason == "Hurt"', "only a Hurt landing")
		has(service, "task.spawn(hurt, player, landing.damage)", "never blocks the frame")
	end)

	case("FD13b: the service: the first landing that would hurt only warns (\"todos avisan antes\")", function()
		has(service, 'beastHit:Invoke(player, "FallWarn", 0, true)', "the warning: BeastHit with 0 damage, the egg kept")
		has(service, "if rec.warned then", "only a warned player is hurt")
		has(service, "rec.warned = true\n\t\t\ttask.spawn(warnFall, player, rec)", "the first one warns instead")
		has(service, "warned = false, conns = {", "a new player starts unwarned")
		has(service, "effect.dodged == true then\n\t\trec.warned = false", "a dodged warning is given again")
		-- the record's connections are dropped with the player
		has(service, "player.CharacterAdded:Connect(function() task.defer(refreshFilter) end),", "kept in rec.conns")
		has(service, "for _, conn in ipairs(rec.conns) do conn:Disconnect() end", "disconnected at PlayerRemoving")
	end)

	case("FD14: the service: measured on the server every frame, from what the server wrote", function()
		has(service, "Fall.step(rec.track, s, now)", "the pure rules")
		has(service, "workspace:GetServerTimeNow()", "the clock the bat and ragdoll stamps use")
		has(service, "workspace:Raycast(position, Vector3.new(0, -Fall.rayLength(", "the ground ray under the feet")
		has(service, "rayParams.RespectCanCollide = true", "only colliding parts are ground")
		has(service, "rayParams.IgnoreWater = true", "water is no ground")
		has(service, "rayParams.FilterType = Enum.RaycastFilterType.Exclude", "characters excluded")
		has(service, 'root:FindFirstChild("WildboundBeastPush")', "the creatures' push")
		has(service, 'player:GetAttribute("WildboundBatHit")', "the bat")
		has(service, 'player:GetAttribute("WildboundRagdollUntil")', "the ragdoll")
		has(service, 'player:GetAttribute("WildboundHidden")', "a hide spot")
		has(service, 'player:GetAttribute("WildboundPortalReadyAt")', "a portal trip")
		has(service, "humanoid.SeatPart ~= nil", "the raft's seat")
		has(service, "root.Anchored", "an anchored root")
		has(service, "Fall.hurt(rec.health, health)", "a hit that took health")
		has(service, "s.gravity = workspace.Gravity", "the place's gravity")
	end)

	case("FD15: the service: the chocolate and the cookie bridges with Caramelo's own rules", function()
		has(service, "m.Wade.wading(false, info)", "the wading rule decides Soft")
		has(service, "m.Wade.probe(m.V3, m.Layout.CENTRE, m.Layout.FLOOR_TOP", "the wading probe")
		has(service, "Fall.inAir(rec.track)", "the chocolate is checked only at a landing")
		has(service, "m.Cookie.blocks(m.V3, b.id", "a cookie bridge's footprint")
		has(service, "m.Cookie.PHASE_ATTRIBUTE", "its phase")
		has(service, 'phase ~= "Up"', "cracking or down")
		has(service, "root:GetAttribute(m.V3.MARK)", "only on the migrated map")
	end)

	case("FD16: the inventory server's BeastHit: fall damage rides on the creatures' own gates", function()
		has(server, "beastHit.OnInvoke = function(player, beast, damage, keepEgg)", "the signature")
		has(server, "damage < 0 or damage > 100", "damage in range (a fall is at most 40)")
		has(server, "Heist.DodgeService.invulnerable(player, workspace:GetServerTimeNow())", "the dodge window")
		has(server, 'keepEgg ~= true and Heist.dropEgg(player, "Hit")', "the egg is kept")
		has(server, 'if damageMode == "private" and lethalPlayer(player) then', "the switch and the paid-trip rule")
		has(server, "local words = Text.BEAST[beast]", "the line is Text.BEAST.Fall.hit")
		has(server, 'if not (beast == "Fall" and hurt == 0 and not eggDropped) then', "a fall that took nothing says nothing")
		has(server, "local damageMode = FairStrike.effectiveMode(flagsOk and flags or nil, game.PlaceId)", "the same switch")
	end)

	case("FD17: the words: Text.BEAST.Fall.hit, Spanish, at most 64 bytes", function()
		local words = Text.BEAST and Text.BEAST.Fall
		assert(type(words) == "table", "Text.BEAST.Fall")
		equal(words.hit, "¡Auch! Caíste de muy alto.", "Text.BEAST.Fall.hit")
		assert(#words.hit <= 64, "fits 64 bytes")
		assert(words.hit ~= Text.BEAST.hit, "not the generic beast line")
		local warning = Text.BEAST.FallWarn
		assert(type(warning) == "table", "Text.BEAST.FallWarn")
		equal(warning.hit, "¡Cuidado! Caer de tan alto duele.", "Text.BEAST.FallWarn.hit")
		assert(#warning.hit <= 64, "the warning fits 64 bytes")
	end)

	return result
end
