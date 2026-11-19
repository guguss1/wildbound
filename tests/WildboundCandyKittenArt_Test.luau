-- Invoke with require(freshTestClone)(require(freshCandyKittensClone), { service = WildboundCandyKittenService.Source,
-- anim = WildboundCandyKittenAnimClient.Source, ambience = WildboundCandyKittenAmbienceClient.Source,
-- audio = WildboundAudioClient.Source }).
-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D12, K-D13; owner request 2026-11-17: "es como el mundo de
-- gatito: un parque verde lindo con las criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas
-- de gatitos como que es su village, otra canción que tenga que ver más con gatitos, también tiene que haber huevos para
-- robar"): the four kitten guardians built from primitive parts after the pack's sheets 21-24, their poses, the park
-- music switch, and the three scripts and the audio hunk by source.
return function(Kittens, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "found") .. ": " .. needle)
	end
	sources = type(sources) == "table" and sources or {}

	local NAMES = { "GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" }
	local JOINTS = { Body = true, Head = true, EarL = true, EarR = true, Tail = true, PawL = true, PawR = true, Prop = true }
	local SHAPES = { Block = true, Ball = true, Cylinder = true, Wedge = true }
	-- K-D12 heights (the tallest point of any visible part above the ground pivot)
	local HEIGHTS = { GatitoLanudo = { 5.5, 6.5 }, GatitoGuerrero = { 6.5, 8.6 }, GatitaBouquet = { 5, 6 },
		GatitoActually = { 5.5, 6.5 } }
	local PHASES = { "Spawn", "Calm", "Patrol", "Notice", "Chase", "Telegraph", "Release", "Recover", "Return", "Disengage",
		"Ended", "x" }
	local TIMES = { 0, 0.37, 1.9 }

	-- an offset { x, y, z, rx, ry, rz } (degrees) read as CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
	local function restOf(entry)
		local o = entry.offset
		return CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(math.rad(o[4]), math.rad(o[5]), math.rad(o[6]))
	end
	local function top(entry)
		local f = restOf(entry)
		local hx, hy, hz = entry.size[1] / 2, entry.size[2] / 2, entry.size[3] / 2
		return f.Y + math.abs(f.RightVector.Y) * hx + math.abs(f.UpVector.Y) * hy + math.abs(f.LookVector.Y) * hz
	end
	local function find(list, name)
		for _, entry in ipairs(list) do
			if entry.name == name then return entry end
		end
		return nil
	end
	local function count(list, prefix)
		local n = 0
		for _, entry in ipairs(list) do
			if entry.name:sub(1, #prefix) == prefix then n += 1 end
		end
		return n
	end

	case("KA1: four kittens of at most 25 parts, RootPart first, known joints and shapes, the K-D12 heights, facing -Z",
		function()
		assert(type(Kittens) == "table" and type(Kittens.NAMES) == "table", "module missing")
		equal(#Kittens.NAMES, 4, "four kittens")
		equal(Kittens.MAX_PARTS, 25)
		equal(Kittens.CULL_STUDS, 200)
		for index, name in ipairs(NAMES) do
			equal(Kittens.NAMES[index], name, "name " .. index)
			assert(not name:find("_", 1, true), name .. " has an underscore (the resting client splits on it)")
			local list = Kittens.parts(name)
			assert(type(list) == "table" and #list >= 2, name .. " has no parts")
			assert(#list <= 25 and #list <= Kittens.MAX_PARTS, name .. " has " .. #list .. " parts")
			equal(list[1].name, "RootPart", name .. " RootPart first")
			equal(list[1].transparency, 1, name .. " RootPart is invisible")
			local o = list[1].offset
			assert(math.abs(o[1]) + math.abs(o[2]) + math.abs(o[3]) + math.abs(o[4]) + math.abs(o[5]) + math.abs(o[6]) < 1e-9,
				name .. " RootPart is the pivot itself")
			local pivots = Kittens.pivots(name)
			local seen, tallest, head = {}, 0, nil
			for _, entry in ipairs(list) do
				local label = name .. "." .. tostring(entry.name)
				assert(not seen[entry.name], label .. " twice")
				seen[entry.name] = true
				assert(JOINTS[entry.joint], label .. " joint " .. tostring(entry.joint))
				assert(SHAPES[entry.shape], label .. " shape " .. tostring(entry.shape))
				assert(entry.mesh == nil or entry.mesh == "Sphere", label .. " mesh " .. tostring(entry.mesh))
				assert(entry.mesh == nil or entry.shape == "Block", label .. " a Sphere mesh sits on a Block")
				for axis = 1, 3 do assert(entry.size[axis] > 0 and entry.size[axis] <= 10, label .. " size") end
				if entry.shape == "Ball" then
					assert(entry.size[1] == entry.size[2] and entry.size[2] == entry.size[3], label .. " a Ball is round")
				elseif entry.shape == "Cylinder" then
					equal(entry.size[2], entry.size[3], label .. " a Cylinder is round")
				end
				for channel = 1, 3 do assert(entry.color[channel] >= 0 and entry.color[channel] <= 255, label .. " colour") end
				assert(Enum.Material[entry.material], label .. " material")
				if entry.name ~= "RootPart" then
					assert(pivots[entry.joint], label .. " joint has no pivot")
					tallest = math.max(tallest, top(entry))
				end
				if entry.name == "Head" then head = entry end
			end
			local range = HEIGHTS[name]
			assert(tallest >= range[1] and tallest <= range[2], ("%s stands %.2f, wanted %g..%g"):format(name, tallest,
				range[1], range[2]))
			assert(head and head.joint == "Head", name .. " has a Head")
			assert(head.offset[3] < 0, name .. " faces -Z (head centre z " .. head.offset[3] .. ")")
			for joint, pivot in pairs(pivots) do
				assert(JOINTS[joint] and #pivot == 3, name .. " pivot " .. tostring(joint))
			end
			equal(Kittens.HEIGHT[name] ~= nil, true, name .. " height attribute")
		end
		equal(Kittens.parts("Mochimiau"), nil, "an unknown name has no parts")
		-- the signature props (K-D12)
		local lanudo = Kittens.parts("GatitoLanudo")
		local yarn = find(lanudo, "Yarn")
		assert(yarn and yarn.shape == "Ball" and yarn.joint == "Body" and yarn.color[1] > yarn.color[2] + 100,
			"Lanudo's body is a pink yarn ball")
		equal(count(lanudo, "Band"), 3, "three yarn bands")
		local mint = find(lanudo, "Head").color
		assert(mint[2] > mint[1] + 60 and mint[3] > mint[1] + 60, "Lanudo's head is mint")
		local guerrero = Kittens.parts("GatitoGuerrero")
		local spear = find(guerrero, "Spear")
		assert(spear and spear.shape == "Cylinder" and spear.joint == "Prop", "Guerrero holds a spear")
		near(spear.size[1], 9, "a spear 9 long")
		assert(spear.color[1] >= 200 and spear.color[2] <= 60, "a red spear")
		assert(top(spear) <= 8.5, "the spear tip stands at most 8.5 high: " .. top(spear))
		assert(find(guerrero, "Shield") and find(guerrero, "RibV") and find(guerrero, "RibH"), "a shield with a cross")
		local bouquet = Kittens.parts("GatitaBouquet")
		equal(count(bouquet, "Tulip"), 3, "three tulips")
		assert(find(bouquet, "BowKnot") and count(bouquet, "BowLoop") == 2, "a pink bow")
		assert(find(bouquet, "Wrap") and find(bouquet, "Star") and find(bouquet, "Tongue"), "the wrap, the star, the tongue")
		local actually = Kittens.parts("GatitoActually")
		local rim = find(actually, "RimR")
		assert(rim and find(actually, "RimL") and find(actually, "Bridge"), "Actually wears glasses")
		assert(rim.color[1] <= 40 and rim.color[2] <= 40 and rim.color[3] <= 40, "black glasses")
		local finger = find(actually, "Finger")
		assert(finger and finger.joint == "Prop" and finger.offset[1] > 0, "a raised finger on the right paw")
		local body = find(actually, "Body").color
		assert(body[1] > body[2] and body[2] > body[3], "Actually is orange")
	end)

	case("KA2: build gives an anchored, massless model that never collides, on a transparent RootPart at the ground",
		function()
		for _, name in ipairs(NAMES) do
			local model = Kittens.build(name)
			assert(typeof(model) == "Instance" and model:IsA("Model"), name .. " is not a Model")
			equal(model.Name, name)
			equal(model.Parent, nil, name .. " unparented")
			local root = model.PrimaryPart
			assert(root and root.Name == "RootPart", name .. " PrimaryPart is the RootPart")
			equal(root.Transparency, 1, name .. " RootPart transparency")
			assert(math.abs(root.Position.Y) <= 0.6, name .. " RootPart on the ground")
			assert(root.CFrame.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999, name .. " faces -Z")
			local parts = 0
			for _, d in ipairs(model:GetDescendants()) do
				assert(not d:IsA("MeshPart") and not d:IsA("Decal") and not d:IsA("Texture") and not d:IsA("SurfaceAppearance"),
					name .. " has a " .. d.ClassName)
				if d:IsA("SpecialMesh") then
					equal(d.MeshType, Enum.MeshType.Sphere, name .. " mesh type")
					equal(d.MeshId, "", name .. " mesh id")
					equal(d.TextureId, "", name .. " mesh texture")
				end
				if d:IsA("BasePart") then
					parts += 1
					local label = name .. "." .. d.Name
					assert(d.Anchored and d.Massless, label .. " anchored and massless")
					assert(not d.CanCollide and not d.CanQuery and not d.CanTouch, label .. " out of collisions and queries")
					assert(JOINTS[d:GetAttribute("Joint")], label .. " Joint attribute")
				end
			end
			equal(parts, #Kittens.parts(name), name .. " part count")
			assert(parts <= 25, name .. " at most 25 parts")
			for _, entry in ipairs(Kittens.parts(name)) do
				local part = model:FindFirstChild(entry.name)
				assert(part and part:IsA("BasePart"), name .. " lacks " .. entry.name)
				assert((part.Position - restOf(entry).Position).Magnitude < 1e-3, name .. "." .. entry.name .. " is off its rest")
				if entry.shape == "Wedge" then equal(part.ClassName, "WedgePart", entry.name) end
			end
			model:Destroy()
		end
		equal(Kittens.build("Nobody"), nil, "an unknown name builds nothing")
	end)

	case("KA3: poses stay small, never move the RootPart, soften with Reduced and repeat exactly", function()
		local function amount(frame)
			local _, angle = frame:ToAxisAngle()
			return frame.Position.Magnitude, math.abs(angle)
		end
		for _, name in ipairs(NAMES) do
			local pivots = Kittens.pivots(name)
			for _, phase in ipairs(PHASES) do
				for _, t in ipairs(TIMES) do
					local label = ("%s %s %g"):format(name, phase, t)
					local full = Kittens.pose(name, phase, t, false)
					local soft = Kittens.pose(name, phase, t, true)
					local again = Kittens.pose(name, phase, t, false)
					assert(type(full) == "table" and type(soft) == "table", label .. " no pose")
					equal(full.RootPart, nil, label .. " the RootPart is never posed")
					equal(soft.RootPart, nil, label .. " the RootPart is never posed (Reduced)")
					for joint, frame in pairs(full) do
						assert(JOINTS[joint] and pivots[joint], label .. " joint " .. tostring(joint))
						assert(typeof(frame) == "CFrame", label .. " " .. joint .. " is not a CFrame")
						local move, turn = amount(frame)
						assert(move <= 1 + 1e-6, ("%s %s moves %.3f"):format(label, joint, move))
						assert(turn <= math.rad(45) + 1e-6, ("%s %s turns %.1f deg"):format(label, joint, math.deg(turn)))
						local softMove, softTurn = amount(soft[joint] or CFrame.identity)
						assert(softMove <= 0.45 * move + 1e-6, ("%s %s Reduced moves %.3f of %.3f"):format(label, joint,
							softMove, move))
						assert(softTurn <= 0.45 * turn + 1e-4, ("%s %s Reduced turns %.2f of %.2f"):format(label, joint,
							math.deg(softTurn), math.deg(turn)))
						assert(again[joint] == frame, label .. " " .. joint .. " is not deterministic")
					end
					for joint in pairs(soft) do assert(full[joint] ~= nil, label .. " Reduced adds " .. joint) end
				end
			end
		end
		local function angle(frame) return math.deg(select(2, frame:ToAxisAngle())) end
		-- the signature moves at full strength
		near(angle(Kittens.pose("GatitoLanudo", "Telegraph", 1 / (4 * 1.4), false).Body), 30, "Lanudo's yarn rolls 30", 1e-3)
		near(angle(Kittens.pose("GatitoGuerrero", "Telegraph", 1, false).Prop), 35, "Guerrero's spear 35", 1e-3)
		assert(Kittens.pose("GatitoGuerrero", "Telegraph", 1, false).Prop.Position.Y > 0.4, "the spear goes up")
		near(Kittens.pose("GatitaBouquet", "Telegraph", 1, false).PawR.Position.Z, -0.6, "Bouquet's paw forward 0.6")
		near(Kittens.pose("GatitaBouquet", "Telegraph", 1, false).Prop.Position.Z, -0.6, "her flowers forward 0.6")
		near(angle(Kittens.pose("GatitoActually", "Telegraph", 1, false).PawR), 40, "Actually's paw up 40", 1e-3)
		assert(Kittens.pose("GatitoActually", "Telegraph", 1, false).Prop.Position.Y > 0.5, "his finger goes up")
		near(angle(Kittens.pose("GatitoGuerrero", "Notice", 1, false).Head), 12, "the head tilts 12", 1e-3)
		near(Kittens.pose("GatitoLanudo", "Chase", 1 / 6, false).Body.Position.Y, 0.6, "a 0.6 hop", 1e-6)
		near(Kittens.pose("GatitoLanudo", "Return", 1 / 6, false).Head.Position.Y, 0.6, "Return hops too", 1e-6)
		near(Kittens.pose("GatitoActually", "Release", 1, false).Body.Position.Z, -0.4, "a 0.4 lunge forward")
		near(Kittens.pose("GatitaBouquet", "Recover", 1, false).Head.Position.Y, -0.2, "a 0.2 crouch")
		for step = 0, 40 do
			local calm = Kittens.pose("GatitoGuerrero", "Calm", step * 0.13, false)
			assert(calm.Body.Position.Y >= -1e-9 and calm.Body.Position.Y <= 0.15 + 1e-9, "an idle bob of at most 0.15")
			assert(angle(calm.Tail) <= 20 + 1e-3, "a tail wag of at most 20")
			for _, frame in pairs(Kittens.pose("GatitoGuerrero", "Chase", step * 0.13, false)) do
				assert(frame.Position.Y <= 0.6 + 1e-9, "a hop of at most 0.6")
			end
		end
		near(Kittens.pose("GatitoLanudo", "Calm", 1 / 1.2, false).Body.Position.Y, 0.15, "the bob's top", 1e-6)
		near(Kittens.pose("GatitoLanudo", "Telegraph", 1 / (4 * 1.4), true).Body.Position.Y, 0.3 * 0.4, "Reduced x 0.4")
		local unknown = Kittens.pose("GatitoLanudo", "Whatever", 0.37, false)
		local calm = Kittens.pose("GatitoLanudo", "Calm", 0.37, false)
		for joint, frame in pairs(calm) do assert(unknown[joint] == frame, "an unknown phase idles (" .. joint .. ")") end
		assert(next(Kittens.pose("Nobody", "Calm", 1, false)) == nil, "an unknown kitten has no pose")
		assert(Kittens.pose("GatitoLanudo", "Calm", 0 / 0, false).Body, "a bad time still poses")
	end)

	-- Deliberately changed (PG-D5): "the border is the cloud": the flag starts 16 studs before the park, inside the cloud
	-- band (x 932..948), and stops 24 studs past it (was "on inside the park, off 8 studs past its edge")
	-- Deliberately changed (PGM-D4, owner request 2026-11-18 "Sí, movelo"): the park moved to the big4 south arm, so the
	-- rectangle is the park floor (WildboundGatitoArea.rect(): x 22..542, z 340..860) and the edge points are on its gate
	-- edge, z 340, coming down the road from the hub at x 282 (were on the cloud band's x 948 edge at z 0; the
	-- PG-D5 margins 16 and 24 are unchanged)
	-- Deliberately changed (GL-D1, owner request 2026-11-19 "hace el mapa bastante mas largo"): the park grew to 600 x 1200
	-- along world +z, so the rectangle's far end is z 1460 (WildboundGatitoArea.rect(), lx -260..860) and the far-end
	-- probes move with it (were z 860, 868, 884, 884.5; the gate edge z 340 and the margins are unchanged)
	case("KA4: the music switch: on 16 studs before the park, off 24 studs past its edge", function()
		equal(Kittens.PARK.minX, 22); equal(Kittens.PARK.maxX, 542) -- PGM-D4 (was 948, 1468)
		equal(Kittens.PARK.minZ, 340); equal(Kittens.PARK.maxZ, 1460) -- GL-D1 (was 860; PGM-D4: was -263, 257)
		-- Deliberately changed (PG-D5): the leave margin grows to keep the hysteresis past the new enter margin (was 8)
		equal(Kittens.LEAVE_MARGIN, 24)
		equal(Kittens.ENTER_MARGIN, 16, "PG-D5: the enter margin")
		equal(Kittens.GUI_ATTRIBUTE, "GatitoAmbience")
		equal(Kittens.inPark(false, 282, 600), true, "inside") -- PGM-D4 (was 1000, 0)
		equal(Kittens.inPark(true, 282, 336), true, "4 outside after being in: still on") -- PGM-D4 (was 944, 0)
		-- Deliberately changed (PG-D5): 9 outside is within the new leave margin of 24 (was false, "9 outside: off")
		equal(Kittens.inPark(true, 282, 331), true, "9 outside after being in: still on") -- PGM-D4 (was 939, 0)
		-- Deliberately changed (PG-D5): 4 outside is within the new enter margin of 16 (was false, "4 outside, not yet in: off")
		equal(Kittens.inPark(false, 282, 336), true, "4 outside, not yet in: on (on the apron)") -- PGM-D4 (was 944, 0)
		equal(Kittens.inPark(false, 282, 324), true, "16 outside (340 - 16), not yet in: on by the road's end") -- PGM-D4 (was 932, 0)
		equal(Kittens.inPark(false, 282, 323), false, "17 outside, not yet in: off (still the road)") -- PGM-D4 (was 931, 0)
		equal(Kittens.inPark(true, 282, 316), true, "24 outside after being in: still on") -- PGM-D4 (was 925, 0, 23 outside)
		equal(Kittens.inPark(true, 282, 315), false, "25 outside after being in: off") -- PGM-D4 (was 923, 0)
		equal(Kittens.inPark(false, 0 / 0, 0), false, "NaN")
		equal(Kittens.inPark(true, 1000, 0 / 0), false, "NaN z")
		equal(Kittens.inPark(true, nil, 0), false, "nil")
		equal(Kittens.inPark(false, 542, 1460), true, "the far corner is inside") -- GL-D1 (was 542, 860; PGM-D4: 1468, 257)
		-- PGM-D4: the far end takes the old north edge's cases (were 1200, 257 + 8 / + 24 / + 24.5)
		-- GL-D1: the far end is z 1460 (was 860)
		equal(Kittens.inPark(true, 282, 1460 + 8), true, "8 past the far end after being in")
		-- Deliberately changed (PG-D5): the leave margin is now 24 (was 257 + 8.5 off, "8.5 past the north edge")
		equal(Kittens.inPark(true, 282, 1460 + 24), true, "24 past the far end after being in")
		equal(Kittens.inPark(true, 282, 1460 + 24.5), false, "24.5 past the far end")
		-- GL-D1: the old far end is inside the grown park now, entering from no state
		equal(Kittens.inPark(false, 282, 900), true, "40 past the old far end (z 860): inside the grown park")
	end)

	case("KA5: the three scripts are plain, local and safe; the audio client plays the kitten bed", function()
		for _, key in ipairs({ "service", "anim", "ambience" }) do
			local text = sources[key]
			assert(type(text) == "string" and #text > 0, key .. " source missing")
			for _, banned in ipairs({ "rbxassetid", "MeshId", "TextureID", "FireServer", "RenderStepped", "SistemaSonriente",
				"InvokeServer", "RemoteEvent" }) do
				hasNot(text, banned, key)
			end
		end
		local anim = sources.anim
		has(anim, "Heartbeat:Connect", "the animator runs on Heartbeat")
		has(anim, "BulkMoveTo", "one bulk move per frame")
		has(anim, "Kittens.CULL_STUDS", "far kittens are skipped")
		has(anim, 'workspace:WaitForChild("WildboundBeastsLocal"', "the beast client's folder")
		has(anim, "folder.ChildAdded:Connect(setup)", "new views are set up")
		has(anim, "folder.ChildRemoved:Connect(", "removed views are dropped")
		has(anim, 'model:GetAttribute("BeastPhase")', "the phase from the beast client")
		has(anim, "Kittens.pose(model.Name, phase, now - state.since, soft)", "the pose from the module")
		has(anim, "root.CFrame:ToObjectSpace(part.CFrame)", "rest offsets cached in RootPart space")
		has(anim, "rootFrame * state.pivots[i] * p * state.inverses[i] * state.rests[i]", "posed about the pivot")
		has(anim, ':GetAttribute("Reduced") == true', "Efectos suaves softens it")
		local ambience = sources.ambience
		has(ambience, "SetAttribute(Kittens.GUI_ATTRIBUTE", "the audio controller is told through the local gui")
		has(ambience, "script.Destroying", "switched off when the script goes")
		has(ambience, "Kittens.inPark(on, root.Position.X, root.Position.Z)", "the switch's rule")
		has(ambience, "local POLL_SECONDS = 0.25", "polled every 0.25 s")
		hasNot(ambience, "player:SetAttribute", "nothing on the player (it would replicate nowhere, but stay local)")
		local service = sources.service
		has(service, "pcall(Kittens.build, name)", "built from the module")
		has(service, 'ReplicatedStorage:WaitForChild("WildboundBeasts", 60)', "waits for the beasts root")
		has(service, 'root:WaitForChild("Models", 60)', "waits for the models folder")
		has(service, 'model:SetAttribute("Species", name)', "Species")
		has(service, 'model:SetAttribute("Height", Kittens.HEIGHT[name])', "Height")
		has(service, "if old then old:Destroy() end", "an older model is replaced")
		local audio = sources.audio
		has(audio, 'local kitten = worldGui:GetAttribute("GatitoAmbience") == true', "reads the park flag")
		has(audio, 'local candy = worldGui:GetAttribute("CandyAmbience") == true and not kitten', "the kitten bed wins")
		has(audio, "Mix.withKitten(", "the mix decides the kitten bed")
		has(audio, "Catalog.SOUNDS.gatitoMusic ~= nil", "the kitten slot from the catalog")
		-- the pinned WildboundCandyAmbience_Test needles still hold
		has(audio, "Catalog.SOUNDS.carameloMusic ~= nil", "CandyAmbience_Test AM9")
		has(audio, 'worldGui:GetAttribute("CandyAmbience") == true', "CandyAmbience_Test AM11")
		has(audio, "Mix.targets(level, phase, reduced, candy, candyTrack)", "CandyAmbience_Test AM11")
		has(audio, "Mix.musicPitch(candy, candyTrack)", "CandyAmbience_Test AM11")
		has(audio, "Catalog.SOUNDS.safeMusic.pitch * musicPitch", "CandyAmbience_Test AM12")
	end)

	return result
end
