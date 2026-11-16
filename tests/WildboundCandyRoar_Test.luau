-- Invoke with require(freshTestClone)({ beasts = <WildboundBeasts Source> }).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, DG6): Rugido de guardianes, the beast server's side. Don Glaseon's
-- Summon event (WildboundBeastDonGlaseon, pinned in its own suite) wakes fresh candy guardians around the thief through
-- the director's roar reservation, each spawned on the ground on a ring round the thief. Source pins. Changes nothing.
return function(sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local beasts = sources.beasts

	case("DG6 wiring: the Summon event reaches the roar handler, which reserves through Director.roar", function()
		has(beasts, 'if event.type == "Summon" then task.defer(world.roarSummon, entry, event, at) end', "the event loop, deferred")
		has(beasts, "function world.roarSummon(entry, event, at)", "the handler")
		has(beasts, "Director.roar(director, player.UserId, name, contextFor(player, at), at)", "the director's roar reservation")
		has(beasts, "world.landing(x, z, root.Position.Y)", "on the ground round the thief")
		has(beasts, "safeStart(player, value, at)")
	end)

	case("DG6 wiring: a roar reservation spawns where the roar put it, every other beast as before", function()
		has(beasts, "local point = character and (reservation.near or spawnPoint(reservation.beast, root))")
		has(beasts, "value.near = y and { x = x, y = y, z = z } or nil", "no ground: the guardian's own post")
		local block = string.match(beasts, "function world%.roarSummon.-\nend\n") or ""
		assert(#block > 0, "the handler's block")
		assert(not string.find(block, "TakeDamage", 1, true) and not string.find(block, "BeastHit", 1, true), "no damage, no hit")
	end)

	return result
end
