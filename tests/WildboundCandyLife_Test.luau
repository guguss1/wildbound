-- Invoke with require(freshTestClone)(require(freshCandyLifeClone), require(freshCandyAmbienceClone),
--   require(freshCandyV3LayoutClone), require(freshCandyLayoutClone), { client = <WildboundCandyLifeClient Source> }).
-- Caramelo v6 "life on the map" (odd/tasks/wildbound-caramelo-v2.md V6-D6; docs/design/wildbound-caramelo-v3-plan.md
-- V6-D50 on): gummy birds circling over the meadows, caramel butterflies at the houses and the lollipop avenue, chocolate
-- fish jumping out of the river and the lake. Client-only decoration. Pure rules (the copied layout numbers pinned to the
-- real layout, the paths, the budgets, the distance culling, Efectos suaves) and source pins. Changes nothing.
return function(Life, Ambience, V3, Layout, sources)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local client = type(sources) == "table" and sources.client or ""
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local function ids(list)
		local out = {}
		for _, item in ipairs(list) do table.insert(out, item.id) end
		return table.concat(out, ",")
	end
	-- the times every path is sampled at: two minutes in tenths of a second
	local function eachTime(run)
		for step = 0, 1200 do run(step / 10) end
	end

	case("CL1: the copied layout numbers equal the real layout", function()
		near(Life.CENTRE.x, Layout.CENTRE.x, "centre x"); near(Life.CENTRE.z, Layout.CENTRE.z, "centre z")
		near(Life.FLOOR_TOP, Layout.FLOOR_TOP, "floor top"); near(Life.HALF, Layout.HALF, "plot half side")
		near(Life.CHOCO_DEPTH, V3.LIQUID.depth, "the chocolate's depth")
		equal(Life.ROOT_NAME, Layout.ROOT_NAME, "the biome's root")
		equal(#Life.HOUSES, #V3.HOUSES, "every house")
		for i, house in ipairs(V3.HOUSES) do
			local copy = Life.HOUSES[i]
			equal(copy.id, house.id, "house " .. i)
			near(copy.x, house.x, house.id .. " x"); near(copy.z, house.z, house.id .. " z"); near(copy.r, house.r, house.id .. " r")
		end
	end)

	case("CL2: small budgets, fewer on touch, none with Efectos suaves", function()
		local desktop, touch, soft = Life.budget(false, false), Life.budget(true, false), Life.budget(false, true)
		assert(desktop.birds <= 12 and desktop.birds > 0, "desktop birds at most 12")
		assert(desktop.butterflies <= 16 and desktop.butterflies > 0, "desktop butterflies at most 16")
		assert(desktop.fish <= 6 and desktop.fish > 0, "desktop fish at most 6")
		assert(touch.birds <= desktop.birds / 2 and touch.butterflies <= desktop.butterflies / 2
			and touch.fish <= math.ceil(desktop.fish / 2), "touch: half or less")
		equal(soft.birds, 0, "soft: no birds"); equal(soft.butterflies, 0, "soft: no butterflies"); equal(soft.fish, 0, "soft: no fish")
		equal(Life.budget(true, true), soft, "Efectos suaves wins over touch")
		for _, row in ipairs({ desktop, touch }) do
			equal(row.birds % Life.FLOCK_SIZE, 0, row.name .. ": whole flocks")
			equal(row.butterflies % Life.PER_SITE, 0, row.name .. ": whole butterfly groups")
		end
		-- a few parts each, and the whole effect under 100 moving parts
		assert(Life.PARTS.bird <= 3 and Life.PARTS.butterfly <= 3 and Life.PARTS.fish <= 3, "a few parts per creature")
		local total = desktop.birds * Life.PARTS.bird + desktop.butterflies * Life.PARTS.butterfly + desktop.fish * Life.PARTS.fish
		assert(total <= 100, "at most 100 parts on desktop: " .. total)
		near(Life.PICK_SECONDS, 0.5, "re-picked at 2 Hz")
	end)

	case("CL3: the gummy birds stay in the air, inside the plot, over the meadows", function()
		assert(#Life.FLOCKS * Life.FLOCK_SIZE >= Life.budget(false, false).birds, "enough flocks for the desktop budget")
		-- MIN_ALT clears everything that stands in the open: the mountains, the pink hills, the licorice arch and the cake
		local tallest = math.max(V3.LICORICE.height, V3.CAKE.height)
		for _, m in ipairs(V3.MOUNTAINS) do tallest = math.max(tallest, m.height) end
		for _, hill in ipairs(V3.CRYSTAL_HILLS) do tallest = math.max(tallest, V3.CRYSTAL.hillHeight * hill.scale) end
		assert(Life.MIN_ALT >= tallest + 4, "the birds fly 4 studs over the tallest piece: " .. tallest)
		-- the backdrop stands outside the plot, beyond where any bird flies
		for _, piece in ipairs(V3.BACKDROP) do assert(piece.x - piece.r >= Life.HALF, piece.asset .. " inside the plot") end
		local seen = {}
		for _, flock in ipairs(Life.FLOCKS) do
			assert(not seen[flock.id], "a flock id twice: " .. flock.id)
			seen[flock.id] = true
			assert(V3.liquidDistance(flock.x, flock.z) >= 10, flock.id .. " circles over the chocolate, not a meadow")
			for _, house in ipairs(V3.HOUSES) do
				assert(flat(flock.x, flock.z, house.x, house.z) >= house.r + 5, flock.id .. " centre on house " .. house.id)
			end
			for k = 1, Life.FLOCK_SIZE do
				local lastX, lastZ
				eachTime(function(t)
					local x, y, z = Life.birdPosition(flock, k, t)
					assert(y >= Life.MIN_ALT, flock.id .. " bird " .. k .. " too low at " .. t .. ": " .. y)
					assert(y <= Life.MIN_ALT + 20, flock.id .. " flies too high")
					assert(math.abs(x) <= Life.HALF - 5 and math.abs(z) <= Life.HALF - 5, flock.id .. " leaves the plot at " .. t)
					-- the cake tower: every tier whose top reaches the bird's height is kept clear
					for _, tier in ipairs(Layout.TOWER.tiers) do
						if tier.top + 8 >= y then
							assert(flat(x, z, Layout.TORTA.x, Layout.TORTA.z) >= tier.radius + 6, flock.id .. " flies into the Gran Torta")
						end
					end
					if lastX then
						assert(flat(x, z, lastX, lastZ) <= Life.BIRD_SPEED * 0.1 * 1.6 + 0.05, flock.id .. " jumps at " .. t)
					end
					lastX, lastZ = x, z
				end)
			end
		end
		-- birds of one flock never sit on each other
		local f = Life.FLOCKS[1]
		local x1, y1, z1 = Life.birdPosition(f, 1, 3)
		local x2, y2, z2 = Life.birdPosition(f, 2, 3)
		assert(math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2 + (z1 - z2) ^ 2) >= 2, "the flock is spread")
		local bx = Life.birdPosition(f, 1, 0 / 0)
		assert(bx == bx, "a bad time still gives a point")
	end)

	case("CL4: the caramel butterflies flutter at the houses and the lollipop avenue", function()
		local sites = Life.butterflySites()
		assert(#sites * Life.PER_SITE >= Life.budget(false, false).butterflies, "enough sites for the desktop budget")
		local houses = 0
		for _, site in ipairs(sites) do
			if site.house then
				houses += 1
				local house
				for _, row in ipairs(V3.HOUSES) do if row.id == site.house then house = row end end
				assert(house, site.id .. " names a real house")
			else
				assert(V3.liquidDistance(site.x, site.z) >= 3, site.id .. " is a flower spot on dry ground")
			end
		end
		equal(houses, #V3.HOUSES, "a butterfly site at every house")
		for _, site in ipairs(sites) do
			for k = 1, Life.PER_SITE do
				eachTime(function(t)
					local x, y, z = Life.butterflyPosition(site, k, t)
					local d = flat(x, z, site.x, site.z)
					if site.house then
						-- outside the house's footprint (never inside a wall) and close to it
						assert(d >= site.r + 1 and d <= site.r + 9, site.id .. " strays at " .. t .. ": " .. d)
					else
						assert(d <= 9, site.id .. " strays from its flowers at " .. t)
					end
					assert(y >= 2 and y <= 10, site.id .. " height " .. y)
					assert(math.abs(x) <= Life.HALF and math.abs(z) <= Life.HALF, site.id .. " leaves the plot at " .. t)
				end)
			end
		end
	end)

	case("CL5: the chocolate fish jump from the chocolate back into it, clear of bridges, docks and cookies", function()
		local budget = Life.budget(false, false)
		assert(#Life.FISH_SPOTS >= budget.fish, "enough jump spots")
		local inLake, inRiver = 0, 0
		for _, spot in ipairs(Life.FISH_SPOTS) do
			local name = spot.id
			-- the whole arc's ground track lies in the chocolate, FISH_MARGIN studs from its edge
			for step = 0, 20 do
				local u = step / 20
				local x, z = spot.x + math.cos(spot.heading) * Life.FISH_JUMP.length * u, spot.z + math.sin(spot.heading) * Life.FISH_JUMP.length * u
				assert(V3.liquidDistance(x, z) <= -Life.FISH_MARGIN, name .. " leaves the chocolate at u " .. u)
				for _, B in ipairs(V3.BRIDGES) do
					local along, across = V3.bridgeFrame(B, x, z)
					assert(math.abs(across) > B.width / 2 + 3 or math.abs(along) > B.length / 2 + B.ramp + 3,
						name .. " jumps under bridge " .. B.id)
				end
				for _, p in ipairs(V3.PLATFORMS) do
					assert(flat(x, z, p.x, p.z) >= p.r + 3, name .. " jumps into a cookie platform")
				end
				for _, dock in ipairs(V3.DOCKS) do
					assert(flat(x, z, dock.tipX, dock.tipZ) >= 8, name .. " jumps at dock " .. dock.id)
				end
			end
			local lake = false
			for _, disc in ipairs(V3.LAKE) do if flat(spot.x, spot.z, disc.x, disc.z) < disc.r then lake = true end end
			if lake then inLake += 1 else inRiver += 1 end
			-- the arc starts and ends under the surface and peaks a few studs over it
			local peak, jumps, wasUp = -math.huge, 0, false
			for step = 0, 600 do
				local jump = Life.fishJump(spot, step / 10)
				if jump then
					peak = math.max(peak, jump.y)
					if not wasUp then jumps += 1 end
					assert(jump.u >= 0 and jump.u <= 1, name .. " progress")
				end
				wasUp = jump ~= nil
			end
			assert(peak > 1.5 and peak <= 6, name .. " peak " .. peak)
			assert(jumps >= 4, name .. " jumps now and then, not never: " .. jumps .. " in a minute")
			-- 0.01 s into a jump (the cycle restarts when t + phase is a whole number of periods)
			local start = Life.fishJump(spot, spot.period - spot.phase % spot.period + 0.01)
			assert(start and start.y <= 0 and start.u <= 0.05, name .. " a jump's first frame is in the chocolate")
			local arcEnd = Life.arcPoint(spot, 1)
			assert(arcEnd.y <= 0, name .. " ends under the surface")
			local arcStart = Life.arcPoint(spot, 0)
			assert(arcStart.y <= 0, name .. " starts under the surface")
			near(Life.arcPoint(spot, 0.5).y, Life.FISH_JUMP.height, name .. " peaks at the middle")
		end
		assert(inLake >= 2 and inRiver >= 2, "fish in the river and in the lake")
		-- out of the water most of the time is wrong: now and then
		local up, total = 0, 0
		for _, spot in ipairs(Life.FISH_SPOTS) do
			for step = 0, 599 do
				total += 1
				if Life.fishJump(spot, step / 10) then up += 1 end
			end
		end
		assert(up / total <= 0.3, "fish are up at most 30 % of the time: " .. up / total)
		equal(Life.fishJump(Life.FISH_SPOTS[1], 0 / 0), nil, "a bad time: no jump")
	end)

	case("CL6: distance culling: only what is near the camera, nearest first", function()
		local sites = {
			{ id = "a", x = 10, z = 0 }, { id = "b", x = 0, z = 30 }, { id = "c", x = -50, z = 0 }, { id = "d", x = 400, z = 0 },
			{ id = "e", x = 0, z = -30 },
		}
		local eye = { x = 0, z = 0 }
		equal(ids(Life.nearest(sites, eye, 3, 100)), "a,b,e", "nearest three, ties by id")
		equal(ids(Life.nearest(sites, eye, 10, 100)), "a,b,e,c", "the far one is culled")
		equal(#Life.nearest(sites, eye, 0, 100), 0, "a zero budget picks nothing")
		equal(#Life.nearest(sites, { x = 0 / 0, z = 0 }, 3, 100), 0, "a bad eye picks nothing")
		equal(#Life.nearest(sites, nil, 3, 100), 0)
		equal(sites[1].id, "a", "the input is not reordered")
		-- the plan: whole flocks and groups within the budget, nothing from far away
		local desktop = Life.budget(false, false)
		local house = Life.HOUSES[1]
		local plan = Life.plan(desktop, { x = house.x, z = house.z })
		assert(#plan.flocks * Life.FLOCK_SIZE <= desktop.birds, "birds within the budget")
		assert(#plan.sites * Life.PER_SITE <= desktop.butterflies, "butterflies within the budget")
		assert(#plan.spots <= desktop.fish, "fish within the budget")
		equal(plan.sites[1].house, house.id, "the butterflies of the house the camera is at")
		for _, site in ipairs(plan.sites) do
			assert(flat(site.x, site.z, house.x, house.z) <= Life.REACH.butterflies, "a butterfly site out of reach")
		end
		for _, spot in ipairs(plan.spots) do
			assert(flat(spot.x, spot.z, house.x, house.z) <= Life.REACH.fish, "a fish spot out of reach")
		end
		local far = Life.plan(desktop, { x = 5000, z = 0 })
		equal(#far.flocks + #far.sites + #far.spots, 0, "nothing far away")
		local soft = Life.plan(Life.budget(false, true), { x = 0, z = 0 })
		equal(#soft.flocks + #soft.sites + #soft.spots, 0, "Efectos suaves: nothing at all")
		local touch = Life.plan(Life.budget(true, false), { x = 0, z = -100 })
		assert(#touch.spots <= Life.budget(true, false).fish and #touch.spots > 0, "touch: fewer fish, still some by the lake")
		assert(Life.REACH.birds >= Life.REACH.fish and Life.REACH.fish >= Life.REACH.butterflies, "reaches")
	end)

	case("CL7: the plot's frame and the biome test come from the floor or the fallback", function()
		local frame = Life.plotFrame(700, 0, -50, 400, 1, 400)
		near(frame.x, 700); near(frame.z, -50); near(frame.top, 0.5, "the floor's top")
		local fallback = Life.plotFrame(nil)
		near(fallback.x, Layout.CENTRE.x); near(fallback.z, Layout.CENTRE.z); near(fallback.top, Layout.FLOOR_TOP)
		local bad = Life.plotFrame(0 / 0, 0, 0, 400, 1, 400)
		near(bad.x, Layout.CENTRE.x, "a bad floor: the fallback")
		-- the same enter and leave rule as the candy ambience (its hysteresis)
		local bounds = Ambience.boundsFromFloor(612, -3, 400, 400)
		equal(Ambience.inside(false, bounds, 612, -3), true, "in the plot")
		equal(Ambience.inside(false, bounds, 0, 0), false, "far away")
		near(Life.flap(0, 3, 30, 0), 0, "a flap starts level")
		assert(math.abs(Life.flap(0.37, 3, 30, 0.2)) <= math.rad(30) + 1e-9, "a flap within its angle")
		near(Life.flap(0 / 0, 3, 30, 0), 0, "a bad time rests")
	end)

	case("CL8: client wiring: local only, never collides, culls, honours Efectos suaves", function()
		has(client, "require(ReplicatedStorage:WaitForChild(\"WildboundCandyLife\"))", "the pure rules from ReplicatedStorage")
		has(client, "require(ReplicatedStorage:WaitForChild(\"WildboundCandyAmbience\"))", "the ambience's biome rule")
		has(client, "Ambience.inside(", "the same enter and leave rule as the ambience")
		has(client, "if not inCandy then\n\t\tteardown()", "gone when the player leaves the candy biome")
		has(client, "part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false",
			"parts never collide, touch or block a ray")
		has(client, "part.Anchored = true", "parts are anchored")
		has(client, ":GetAttribute(\"Reduced\")", "Efectos suaves is honoured")
		has(client, "UserInputService.TouchEnabled", "touch devices get the smaller budget")
		has(client, "Life.budget(", "the budget comes from the rules")
		has(client, "Life.plan(", "the distance culling comes from the rules")
		has(client, "Life.PICK_SECONDS", "re-picked on its timer")
		has(client, "Life.plotFrame(", "the plot frame from the live floor")
		has(client, "RunService.Heartbeat:Connect", "Heartbeat drives it")
		hasNot(client, "RenderStepped", "RenderStepped did not fire in Studio Play")
		has(client, "workspace.CurrentCamera", "the helpers live under the camera (never replicated)")
		has(client, "local function teardown()", "one cleanup")
		has(client, "script.Destroying", "cleaned up when the script goes")
		has(client, "workspace:BulkMoveTo(", "one bulk move per frame")
		for _, banned in ipairs({ "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction", "WildboundNetwork",
			"ServerStorage", "ServerScriptService", "DataStore", ":SetAttribute(", "Instance.new(\"Sound\")", "SoundId",
			"rbxassetid", "CanCollide = true", "CanQuery = true", "CanTouch = true", "Touched" }) do
			hasNot(client, banned, "decoration only")
		end
		assert(not string.find(client, "%d%d%d%d%d%d%d"), "an asset id is written in the client")
	end)

	return result
end
