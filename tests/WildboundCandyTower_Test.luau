-- Invoke with require(freshTestClone)(require(freshCandyLayoutClone), require(freshCandyBuilderClone),
--   require(freshCandyKitClone), { nests = <WildboundCandyNests Source>, client = <WildboundCandyTowerClient Source> },
--   require(freshCandyNestsClone), ServerStorage.WildboundAssets.CandyKit (read only)).
-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT1-CT3): the Gran Torta as a tower. CT1 a spiral stair round the
-- tiers; CT2 three lower tiers that turn slowly, alternating, carrying whoever stands on them; the top stays still;
-- CT3 the best egg of the biome in a nest on the summit. Builds only into detached models (never parented to a
-- service). Changes nothing.
return function(Layout, Builder, Kit, sources, Nests, library)
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
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local T = Layout.TOWER
	local function fakeBiome()
		local root = Instance.new("Model")
		root.Name = Layout.ROOT_NAME
		local torta = Instance.new("Model")
		torta.Name = "GranTorta"
		torta.Parent = root
		local nests = Instance.new("Folder")
		nests.Name = "Nests"
		nests.Parent = root
		return root
	end

	case("CT: the tiers are the kit cake's collision cylinders at the builder's scale", function()
		local scale = Layout.TORTA.radius * 2 / Kit.PROXIES.CakeTower[1].size.Y
		equal(#T.tiers, #Kit.PROXIES.CakeTower, "four tiers")
		for i, proxy in ipairs(Kit.PROXIES.CakeTower) do
			near(T.tiers[i].radius, proxy.size.Y / 2 * scale, "radius " .. i)
			near(T.tiers[i].bottom, (proxy.at.Y - proxy.size.X / 2) * scale, "bottom " .. i)
			near(T.tiers[i].top, (proxy.at.Y + proxy.size.X / 2) * scale, "top " .. i)
		end
	end)

	case("CT1: one flight per tier, each from the floor below to its tier's top, steps of at most 1 stud", function()
		local steps, flights = Layout.stairSteps(), {}
		for _, s in ipairs(steps) do
			flights[s.flight] = flights[s.flight] or {}
			table.insert(flights[s.flight], s)
		end
		equal(#flights, 4, "four flights")
		for k, list in ipairs(flights) do
			local base = k == 1 and 0 or T.tiers[k - 1].top
			near(list[1].bottom, base, "flight " .. k .. " stands on the floor below")
			near(list[#list].top, T.tiers[k].top, "flight " .. k .. " ends level with its tier")
			local last = base
			for i, s in ipairs(list) do
				assert(s.top - last <= T.stair.maxRise + 1e-6 and s.top > last, ("flight %d step %d rise %.2f"):format(k, i, s.top - last))
				last = s.top
				local r = Layout.flat(s.x, s.z, Layout.TORTA.x, Layout.TORTA.z)
				local inner, outer = r - T.stair.width / 2, r + T.stair.width / 2
				assert(inner >= T.tiers[k].radius + 0.4, ("flight %d step %d stands outside its tier (%.2f)"):format(k, i, inner))
				if k > 1 then
					assert(outer <= T.tiers[k - 1].radius - 1.45, ("flight %d step %d stays on the ledge, inside the dollops (%.2f)"):format(k, i, outer))
				end
				if i > 1 then
					local p = list[i - 1]
					assert(Layout.flat(s.x, s.z, p.x, p.z) <= T.stair.tread + 0.01, "steps touch")
				end
			end
		end
	end)

	case("CT1: the stair starts by the south decoy and never steps on a nest", function()
		local steps = Layout.stairSteps()
		near(math.deg(steps[1].angle - T.stair.tread / 2 / steps[1].radius), T.stair.startDegrees, "it starts at startDegrees", 0.01)
		for _, s in ipairs(steps) do
			for _, nest in ipairs(Layout.NESTS) do
				assert(Layout.flat(s.x, s.z, nest.x, nest.z) >= 6, "a step on nest " .. nest.id)
			end
		end
		-- Deliberately changed (GT): the DG7 stair decoy moved to the riverside (PF6), so its old spot (6, -33) beside a
		-- Torta at (0, 0) was a stale literal; the stair starts on the Torta's south side, wherever the Torta stands.
		local first = steps[1]
		assert(first.z - Layout.TORTA.z < -Layout.TORTA.radius, "the stair starts on the south side")
	end)

	case("CT1: syncTower builds the stair once: solid anchored columns from their floor to their top", function()
		local root = fakeBiome()
		local added = Builder.syncTower(root, Layout)
		local tower = root:FindFirstChild("Tower")
		assert(tower, "no Tower model")
		local stair = tower:FindFirstChild("Stair")
		local steps = Layout.stairSteps()
		equal(#stair:GetChildren(), #steps, "one column per step")
		for _, s in ipairs(steps) do
			local p = stair:FindFirstChild(("Step_%d_%d"):format(s.flight, s.index))
			assert(p and p.Anchored and p.CanCollide and p.CanQuery, "a solid step " .. s.flight .. "/" .. s.index)
			equal(p:GetAttribute("Role"), "solid")
			near(p.Position.Y + p.Size.Y / 2, Layout.FLOOR_TOP + s.top, "its top")
			near(p.Position.Y - p.Size.Y / 2, Layout.FLOOR_TOP + s.bottom, "its foot")
			near(p.Position.X, Layout.CENTRE.x + s.x, "x"); near(p.Position.Z, Layout.CENTRE.z + s.z, "z")
		end
		assert(added >= #steps, "it reports the parts it added")
		equal(Builder.syncTower(root, Layout), 0, "a second sync adds nothing")
		assert(not pcall(Builder.syncTower, Instance.new("Model"), Layout), "no Gran Torta: an error")
		root:Destroy()
	end)

	-- Deliberately changed (GT): one turn in 140 s (was 90), so the 1.6 times wider bottom rim stays under 2 studs/s.
	case("CT2: three turning tiers, alternating, one turn in 140 s (the rim under 2 studs/s); the top stays still", function()
		equal(T.spinPeriodSeconds, 140)
		equal(T.spinDirections[1], 1); equal(T.spinDirections[2], -1); equal(T.spinDirections[3], 1); equal(T.spinDirections[4], 0)
		local rate = 2 * math.pi / T.spinPeriodSeconds
		assert(rate * T.tiers[1].radius <= 2, "slow at the widest rim")
		local root = fakeBiome()
		Builder.syncTower(root, Layout)
		local tower = root.Tower
		for k, tier in ipairs(T.tiers) do
			local disc, spin = tower:FindFirstChild("Turntable_" .. k), tower:FindFirstChild("Spin_" .. k)
			if T.spinDirections[k] == 0 then
				assert(not disc and not spin, "the top tier never turns")
			else
				assert(disc and disc.Anchored and disc.CanCollide and disc.Transparency == 1, "an invisible floor disc on tier " .. k)
				equal(disc:GetAttribute("Role"), "floor")
				near(disc.AssemblyAngularVelocity.Y, rate * T.spinDirections[k], "its spin carries the players")
				near(disc.AssemblyAngularVelocity.X, 0); near(disc.AssemblyAngularVelocity.Z, 0)
				near(disc.Position.X, Layout.CENTRE.x + Layout.TORTA.x); near(disc.Position.Z, Layout.CENTRE.z + Layout.TORTA.z)
				near(disc.Position.Y - disc.Size.X / 2, Layout.FLOOR_TOP + tier.top, "on the tier's top")
				near(disc.Size.Y, tier.radius * 2, "the tier's width")
				assert(spin, "a ring of dollops on tier " .. k)
				near(spin:GetAttribute("SpinRate"), rate * T.spinDirections[k], "the ring turns with its disc")
				near(spin:GetAttribute("CentreX"), Layout.CENTRE.x); near(spin:GetAttribute("CentreZ"), Layout.CENTRE.z)
				for _, d in ipairs(spin:GetChildren()) do
					assert(d:IsA("BasePart") and not d.CanCollide and not d.CanQuery, "decor never collides")
				end
			end
		end
		root:Destroy()
	end)

	case("CT2 wiring: the client turns the rings by SpinRate x server time, never the discs; the server adds the tower at start", function()
		local client = sources.client
		has(client, 'string.sub(model.Name, 1, 5) ~= "Spin_"', "only the Spin_ rings")
		has(client, "ring.rate * t", "rate x time"); has(client, "workspace:GetServerTimeNow()", "the server's clock")
		assert(not string.find(client, "Turntable_", 1, true) or string.find(client, "never moved here", 1, true), "the discs stay")
		has(sources.nests, "pcall(Builder.syncTower, root, Layout)", "applyFlags adds the tower before the nests are read")
	end)

	-- CT3: the best egg of the biome on the summit.
	case("CT3: the summit nest: a Legendaria (not event-only) on the still top tier, clear of La Duquesa's seat", function()
		local S = T.summit
		assert(S, "Layout.TOWER.summit")
		equal(S.id, "T1"); equal(S.rarity, "Legendaria")
		local top = T.tiers[#T.tiers]
		equal(T.spinDirections[#T.tiers], 0, "the summit never turns")
		local half = 7.4 * S.scale / 2
		local r = Layout.flat(S.x, S.z, Layout.TORTA.x, Layout.TORTA.z)
		assert(r + half <= top.radius - 0.2, "the bowl stays on the summit: " .. r + half)
		assert(r - half >= 3, "clear of La Duquesa, who sits on the centre (3 studs around it): " .. r - half)
		local arrival = Layout.stairSteps()
		arrival = arrival[#arrival]
		assert(Layout.flat(S.x, S.z, arrival.x, arrival.z) >= 12, "across the summit from where the stair arrives")
		for _, nest in ipairs(Layout.NESTS) do assert(nest.id ~= S.id, "a new id") end
	end)

	case("CT3: syncTower lays the summit nest as a live marker; the island system reads it as a Heart Legendaria", function()
		local root = fakeBiome()
		Builder.syncTower(root, Layout, Kit, library)
		local nest = root.Nests:FindFirstChild("Nest_T1")
		assert(nest and nest:IsA("Model"), "Nest_T1 in the Nests folder")
		equal(nest:GetAttribute("NestId"), "T1"); equal(nest:GetAttribute("Rarity"), "Legendaria")
		equal(nest:GetAttribute("EventOnly"), false, "not event-only"); equal(nest:GetAttribute("Enabled"), Layout.NESTS_ENABLED == true)
		equal(nest:GetAttribute("Summit"), true)
		assert(nest.PrimaryPart and nest.PrimaryPart.Name == "Collision_Bowl", "its bowl")
		local markers = Nests.read(root)
		equal(#markers, 1, "one marker")
		local m = markers[1]
		near(m.x, Layout.CENTRE.x + T.summit.x, "x", 0.05); near(m.z, Layout.CENTRE.z + T.summit.z, "z", 0.05)
		local summitTop = Layout.FLOOR_TOP + T.tiers[#T.tiers].top
		assert(m.top > summitTop and m.top < summitTop + 2.5, "the bowl's top stands on the summit: " .. m.top)
		local island = Nests.islands(markers, {})[1]
		assert(island, "an island entry")
		equal(island.id, "CandyT1"); equal(island.rarity, "Legendaria"); equal(island.rewardTier, "Heart")
		equal(island.eggs, 1); equal(island.guard, nil, "no guardian post up there")
		root:Destroy()
	end)

	-- GT (cake move): the bigger Torta's climb: one step per stud of rise at most, 67 steps in all for radius 42, and the
	-- summit holds La Duquesa's seat, the full-size nest and Frutillon's ring.
	case("GT7: the bigger stair is walkable (rises <= 1, 67 steps for radius 42) and the summit fits its guests", function()
		local steps, expected, base = Layout.stairSteps(), 0, 0
		for _, tier in ipairs(T.tiers) do
			expected += math.ceil((tier.top - base) / T.stair.maxRise - 1e-9)
			base = tier.top
		end
		equal(#steps, expected, "one step per stud of rise")
		if Layout.TORTA.radius == 42 then equal(#steps, 67, "67 steps") end
		near(steps[#steps].top, T.tiers[#T.tiers].top, "the last step is level with the summit")
		for i = 2, #steps do
			local a, b = steps[i - 1], steps[i]
			if a.flight == b.flight then assert(b.top - a.top <= T.stair.maxRise + 1e-6, "a rise over 1 stud at step " .. i) end
		end
		local top = T.tiers[#T.tiers]
		local S = T.summit
		local r = Layout.flat(S.x, S.z, Layout.TORTA.x, Layout.TORTA.z)
		assert(r - 7.4 * S.scale / 2 >= 3 and r + 7.4 * S.scale / 2 <= top.radius - 0.2, "the nest beside the seat, on the summit")
		assert(top.radius >= 12, "a summit of radius " .. top.radius)
	end)

	return result
end
