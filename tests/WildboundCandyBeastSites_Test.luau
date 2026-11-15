-- Invoke with require(freshTestClone)(require(freshCandyLayoutClone), require(WildboundPraderaSites),
-- require(freshBeastConfigClone), workspace:FindFirstChild("WildboundPradera"), workspace.Candy_Bioma_v1).
-- Caramelo biome (odd/tasks/caramelo-bioma.md, S7): La Nube Grunona and La Abeja Reina are parked at one side of the
-- candy biome until the owner decides what to do with them. Nothing in their scripts changes: WildboundBeasts reads the
-- sector origin from the pivot of a Workspace instance named "WildboundPradera" (else the Meadow centre), so an empty
-- marker Model with that name moves every Pradera site at once. This suite reads the origin the way the beast script
-- does and checks where the sites land against the candy layout.
return function(Layout, Sites, Config, marker, biome)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	-- The same rule as WildboundBeasts.praderaOrigin.
	local origin = nil
	if marker and (marker:IsA("Model") or marker:IsA("BasePart")) then
		local p = marker:GetPivot().Position
		origin = { x = p.X, z = p.Z }
	end
	-- A site in candy-local coordinates.
	local function site(key)
		local w = Sites.world(origin, key)
		return { x = w.x - Layout.CENTRE.x, z = w.z - Layout.CENTRE.z }
	end
	local function nearestNest(p)
		local best = math.huge
		for _, nest in ipairs(Layout.NESTS) do best = math.min(best, Layout.flat(p.x, p.z, nest.x, nest.z)) end
		return best
	end
	local nube, abeja = Config.BEASTS.NubeGrunona.tuning, Config.BEASTS.AbejaReina.tuning
	-- How far each one can sense from her home without being provoked: La Nube drifts PondWaypointRadius and sees
	-- DetectionRadius; La Abeja only hears inside GuardRadius.
	local nubeReach = nube.PondWaypointRadiusStuds + nube.DetectionRadiusStuds
	local abejaReach = abeja.GuardRadiusStuds
	-- Players are not points on a centreline: they walk the whole width of a path and stand around a nest or on the
	-- portal pad. (Measured in Play: with nest C5 61 studs from the pond, La Nube saw a player standing beside it.)
	local HALF_PATH, STAND = Layout.PATH_WIDTH / 2, 8

	case("S7: the parking is one empty, labelled marker and no script edit", function()
		assert(marker and marker:IsA("Model"), "no WildboundPradera marker Model in Workspace")
		equal(#marker:GetDescendants(), 0, "marker descendants")
		equal(marker:GetAttribute("Temporary"), true, "Temporary")
		equal(marker:GetAttribute("Feature"), "caramelo-bioma", "Feature")
		assert(type(marker:GetAttribute("Purpose")) == "string" and #marker:GetAttribute("Purpose") > 20, "Purpose")
		-- the module keeps its own numbers: without a marker every site is where the Pradera had it
		local pond, hive, gate, plaza = Sites.world(nil, "pond"), Sites.world(nil, "colmena"), Sites.world(nil, "gate"), Sites.world(nil, "plaza")
		equal(pond.x, 762, "default pond x"); equal(pond.z, -3, "default pond z")
		equal(hive.x, 537, "default hive x"); equal(hive.z, 72, "default hive z")
		equal(gate.x, 426, "default gate x"); equal(gate.z, -3, "default gate z")
		equal(plaza.x, 572, "default plaza x"); equal(plaza.z, 11, "default plaza z")
		equal(Sites.HOME.NubeGrunona, "pond", "Nube home"); equal(Sites.HOME.AbejaReina, "colmena", "Abeja home")
	end)

	case("S7: La Nube's home leaves every candy route and the portal out of her sight", function()
		local pond = site("pond")
		assert(Layout.routeDistance(pond.x, pond.z) >= nubeReach + HALF_PATH, "a route passes " .. Layout.routeDistance(pond.x, pond.z) .. " studs from the pond")
		assert(Layout.flat(pond.x, pond.z, Layout.PORTAL.x, Layout.PORTAL.z) >= nubeReach + STAND, "the portal is under La Nube")
		assert(Layout.flat(pond.x, pond.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) > nube.WakeRadiusStuds, "she wakes at the entrance")
	end)

	case("S7: La Abeja's hive leaves every candy route outside her hearing", function()
		local hive = site("colmena")
		assert(Layout.routeDistance(hive.x, hive.z) >= abejaReach + HALF_PATH, "a route passes " .. Layout.routeDistance(hive.x, hive.z) .. " studs from the hive")
		assert(Layout.flat(hive.x, hive.z, Layout.PORTAL.x, Layout.PORTAL.z) >= abejaReach + STAND, "the portal is in her guard")
		assert(Layout.flat(hive.x, hive.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) > abeja.WakeRadiusStuds, "she wakes at the entrance")
	end)

	case("S7: both stay in the biome, off the boss ground and off the nests", function()
		for name, reach in pairs({ pond = nubeReach, colmena = abejaReach }) do
			local home = site(name)
			assert(Layout.depth(home.x, home.z) >= 15, name .. " left the plot")
			assert(Layout.flat(home.x, home.z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius + reach, name .. " reaches the boss ground")
			-- A nest is where a player stands still: it must be out of reach, not merely out of the way. (The first
			-- version of this rule used a flat 40 studs and let La Nube see nest C5 from 50.)
			assert(nearestNest(home) >= reach + STAND, name .. " senses a player at a nest " .. nearestNest(home) .. " studs away")
		end
	end)

	case("S7: the knock destinations that move with them stay on walkable candy ground", function()
		for _, name in ipairs({ "gate", "plaza" }) do
			local p = site(name)
			assert(Layout.depth(p.x, p.z) >= 5, name .. " outside the plot")
			assert(Layout.flat(p.x, p.z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius + 5, name .. " on the boss ground")
			for _, disc in ipairs(Layout.LAKE) do
				assert(Layout.flat(p.x, p.z, disc.x, disc.z) > disc.r, name .. " in the syrup")
			end
		end
	end)

	case("S7: each home is on open candy floor, where the beast script finds ground to spawn on", function()
		assert(biome and biome:FindFirstChild("Ground"), "no live candy biome given")
		for name, radius in pairs({ pond = 6, colmena = 4 }) do
			local home = site(name)
			for _, off in ipairs({ { 0, 0 }, { radius, 0 }, { -radius, 0 }, { 0, radius }, { 0, -radius } }) do
				local from = Vector3.new(Layout.CENTRE.x + home.x + off[1], 120, Layout.CENTRE.z + home.z + off[2])
				local hit = workspace:Raycast(from, Vector3.new(0, -200, 0))
				assert(hit, name .. " has no ground under it")
				assert(hit.Instance == biome.Ground.Floor, name .. " is under or inside " .. hit.Instance:GetFullName())
			end
		end
	end)

	-- T3, T4: the candy guardians live at fixed posts beside a nest (Sites.FIXED), which the marker above never moves.
	case("T4: each candy guardian is summoned only near its own fixed post, and the posts do not move with the marker", function()
		for _, name in ipairs({ "Gomibu", "Flanfuria", "Tortidragon" }) do
			local key = Sites.HOME[name]
			assert(key and Sites.FIXED[key], name .. " has no fixed post")
			local post, moved = Sites.world(nil, key), Sites.world({ x = 0, z = 0 }, key)
			equal(moved.x, post.x, name .. " post x moved with the origin"); equal(moved.z, post.z, name .. " post z moved with the origin")
			local wake = Config.BEASTS[name].tuning.WakeRadiusStuds
			local function wants(dx, extra)
				local ctx = { alive = true, safe = false, meadow = true, x = post.x + dx, z = post.z, origin = origin }
				for k, v in pairs(extra or {}) do ctx[k] = v end
				return Sites.wants(name, ctx)
			end
			equal(wants(0), true, name .. " at its post"); equal(wants(wake - 0.5), true, name .. " inside the wake radius")
			equal(wants(wake + 0.5), false, name .. " outside the wake radius")
			equal(wants(0, { safe = true }), false, name .. " for a safe player"); equal(wants(0, { meadow = false }), false, name .. " outside the biome")
			equal(wants(0, { alive = false }), false, name .. " for a dead player")
		end
		-- CA2: no two guardians share a post or can reach each other's ground
		local guardians = { "Gomibu", "Flanfuria", "Tortidragon" }
		for i = 1, #guardians do
			for j = i + 1, #guardians do
				local one, two = guardians[i], guardians[j]
				assert(Sites.HOME[one] ~= Sites.HOME[two], one .. " and " .. two .. " share a post")
				local a, b = Sites.world(nil, Sites.HOME[one]), Sites.world(nil, Sites.HOME[two])
				local leashes = Config.BEASTS[one].tuning.LeashStuds + Config.BEASTS[two].tuning.LeashStuds
				assert(Layout.flat(a.x, a.z, b.x, b.z) >= leashes, one .. " and " .. two .. " can reach each other's ground")
			end
		end
	end)

	-- T4 Flanfuria, CA2 Tortidragon: the same rules for both posts.
	for _, name in ipairs({ "Flanfuria", "Tortidragon" }) do
	case("T4: " .. name .. "'s post is open floor beside a nest, off the routes and off the boss ground even at the end of its leash", function()
		assert(biome and biome:FindFirstChild("Ground"), "no live candy biome given")
		local w = Sites.world(nil, Sites.HOME[name])
		local post = { x = w.x - Layout.CENTRE.x, z = w.z - Layout.CENTRE.z }
		local T = Config.BEASTS[name].tuning
		assert(nearestNest(post) >= 8 and nearestNest(post) <= 16, "the post is " .. nearestNest(post) .. " studs from the nearest nest")
		assert(Layout.depth(post.x, post.z) >= T.LeashStuds, "its leash leaves the plot")
		assert(Layout.flat(post.x, post.z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius + T.LeashStuds, "its leash reaches the boss ground")
		-- somebody walking a route is watched, never chased
		assert(Layout.routeDistance(post.x, post.z) >= T.PerceptionStuds + HALF_PATH, "a route passes " .. Layout.routeDistance(post.x, post.z) .. " studs from the post")
		for _, off in ipairs({ { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } }) do
			local hit = workspace:Raycast(Vector3.new(w.x + off[1], 120, w.z + off[2]), Vector3.new(0, -200, 0))
			assert(hit and hit.Instance == biome.Ground.Floor, "the post is under or inside " .. (hit and hit.Instance:GetFullName() or "nothing"))
		end
	end)
	end

	return result
end
