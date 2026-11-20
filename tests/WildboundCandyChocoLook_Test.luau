-- Invoke with require(freshTestClone)(require(freshCandyChocoLookClone), require(freshCandyCurrentClone),
--   { client = <WildboundCandyChocoLookClient Source>, builder = <WildboundCandyV3Builder Source>,
--   east = <WildboundCandyEast Source> }).
-- Caramelo's chocolate look (TB-2, owner request 2026-11-20: "que el agua marron sea de la toolbox tambien"): the pure
-- rules of WildboundCandyChocoLook (which parts by name and folder, the upward face, the texture spec and tint, the scroll
-- direction and offsets, the near test, Efectos suaves, the overlap rule that leaves the joints and covered drums
-- plain) and source pins of the client, plus the part names and frames
-- WildboundCandyV3Builder and WildboundCandyEast lay (so a rename there cannot silently leave the chocolate plain).
-- Changes nothing.
return function(Look, Current, sources)
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
	local builder = type(sources) == "table" and sources.builder or ""
	local east = type(sources) == "table" and sources.east or ""

	case("CL1: the texture is the toolbox chocolate, 24 studs a tile, slightly see-through; 10 Hz at most, 700 studs, the current's speeds", function()
		assert(table.isfrozen(Look), "frozen")
		equal(Look.IMAGE, "rbxassetid://82311877461867", "the Creator Store chocolate texture")
		equal(Look.TEXTURE_NAME, "WildboundChocoLook")
		equal(Look.STUDS_PER_TILE, 24, "about 24 studs a tile")
		assert(Look.TRANSPARENCY > 0 and Look.TRANSPARENCY <= 0.5, "slightly transparent")
		assert(Look.STEP_SECONDS >= 0.1 - 1e-9, "never more than 10 Hz")
		equal(Look.NEAR_STUDS, 700, "only within 700 studs")
		near(Look.SPEED.river, Current.RIVER_SPEED, "the river's speed is the current's")
		near(Look.SPEED.lake, Current.LAKE_SPEED, "the lake's speed is the current's")
		equal(Look.ROOT_NAME, "Candy_Bioma_v1"); equal(Look.V3_FOLDER, "CaramelV3")
		equal(Look.FOLDERS[1], "River"); equal(Look.FOLDERS[2], "Lake"); equal(#Look.FOLDERS, 2)
		equal(Look.EAST_ROOT, "Candy_Este_v1"); equal(Look.EAST_FOLDER, "CloudWall"); equal(Look.MOUTH_NAME, "MouthSheet")
		equal(Look.FORBIDDEN, "SistemaSonriente")
		equal(Look.MOUTH_FLOW[1], 1); equal(Look.MOUTH_FLOW[2], 0)
	end)

	case("CL2: only the chocolate liquid parts are classified, each in its own folder", function()
		local kind, index = Look.classify("Choco_River_7")
		equal(kind, "river"); equal(index, 7)
		kind, index = Look.classify("Choco_Joint_12")
		equal(kind, "joint"); equal(index, 12)
		kind, index = Look.classify("Choco_Lake_2")
		equal(kind, "lake"); equal(index, 2)
		kind, index = Look.classify("Choco_Pool")
		equal(kind, "pool"); equal(index, nil)
		kind, index = Look.classify("MouthSheet")
		equal(kind, "mouth"); equal(index, nil)
		for _, name in ipairs({ "Sheet", "Lip", "Foam", "Bank_3_1", "Choco_River_", "Choco_River_3a", "Syrup_1",
			"choco_river_1", "Streak_2", "SistemaSonriente", "" }) do
			equal(Look.classify(name), nil, name)
		end
		equal(Look.classify(nil), nil, "nil"); equal(Look.classify(5), nil, "a number")
		for _, k in ipairs({ "river", "pool" }) do
			equal(Look.accepts("River", k), true, "River holds " .. k)
			equal(Look.accepts("Lake", k), false, "Lake never holds " .. k)
		end
		-- Deliberately changed (TB-2 review, 2026-11-20): the joints stay plain. Each Choco_Joint_<n> drum lies on the
		-- river blocks' plane under both block ends, so its texture drew a doubled, flickering circle at every river point.
		equal(Look.classify("Choco_Joint_3"), "joint", "a joint is still recognised")
		equal(Look.accepts("River", "joint"), false, "but never textured")
		equal(Look.accepts("Lake", "joint"), false)
		equal(Look.accepts("Lake", "lake"), true); equal(Look.accepts("River", "lake"), false)
		equal(Look.accepts("CloudWall", "mouth"), true); equal(Look.accepts("River", "mouth"), false)
		equal(Look.accepts("Waterfall", "river"), false, "nothing in the Waterfall model")
	end)

	case("CL3: the speeds and the legs that give each part its direction", function()
		equal(Look.speedFor("river"), Look.SPEED.river); equal(Look.speedFor("mouth"), Look.SPEED.river)
		equal(Look.speedFor("lake"), Look.SPEED.lake); equal(Look.speedFor("pool"), Look.SPEED.lake)
		equal(Look.speedFor("junk"), 0)
		-- Deliberately changed (TB-2 review, 2026-11-20): the joints are never textured, so they have no speed or leg.
		equal(Look.speedFor("joint"), 0, "a joint never scrolls")
		local function legs(list)
			local set = {}
			for _, i in ipairs(list) do set[i] = true end
			return function(i) return set[i] == true end
		end
		equal(Look.legFor("river", 5, legs({})), 5, "a river block is its own leg")
		equal(Look.legFor("joint", 3, legs({ 2, 3 })), nil, "a joint has no leg (it stays plain)")
		equal(Look.legFor("pool", nil, legs({ 1 })), 1, "the pool follows leg 1")
		equal(Look.legFor("pool", nil, legs({ 2 })), nil)
		equal(Look.legFor("lake", 1, legs({ 1, 2 })), nil, "the lake discs share one direction (the client)")
		equal(Look.legFor("mouth", nil, legs({ 1 })), nil, "the MouthSheet flows east")
	end)

	case("CL4: the upward face: Top on the river blocks and the MouthSheet, Right on the turned cylinders", function()
		local function faceOf(cf) return Look.upFace(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y) end
		equal(faceOf(CFrame.new()), "Top", "an upright block")
		equal(faceOf(CFrame.lookAt(Vector3.new(0, 2, 0), Vector3.new(30, 2, -40))), "Top", "a river block (lookAt, level)")
		equal(faceOf(CFrame.new(5, 1, 5) * CFrame.Angles(0, 0, math.rad(90))), "Right", "a V3 drum (turned 90 about Z)")
		equal(faceOf(CFrame.Angles(0, 0, math.rad(-90))), "Left")
		equal(faceOf(CFrame.Angles(math.rad(180), 0, 0)), "Bottom", "upside down")
		equal(faceOf(CFrame.Angles(math.rad(90), 0, 0)), "Front", "tipped back: the front looks up")
		equal(Look.upFace(0 / 0, 0 / 0, 0 / 0), "Top", "junk falls back to Top")
	end)

	case("CL5: the scroll runs along the flow: unit length on the up face, along V for a river block", function()
		-- a river block laid as WildboundCandyV3Builder lays it: CFrame.lookAt(centre, downstream end)
		for _, yaw in ipairs({ 0, 30, 90, 145, 200, 300 }) do
			local d = Vector3.new(math.sin(math.rad(yaw)), 0, -math.cos(math.rad(yaw)))
			local cf = CFrame.lookAt(Vector3.new(10, 2, 10), Vector3.new(10, 2, 10) + d * 20)
			local l = cf:VectorToObjectSpace(d)
			local du, dv = Look.project("Top", l.X, l.Y, l.Z)
			near(du, 0, "no sideways scroll at yaw " .. yaw, 1e-5)
			near(math.abs(dv), 1, "full speed along V at yaw " .. yaw, 1e-5)
		end
		-- a drum: any flat flow lies in its Right face, so the scroll keeps its full length
		local drum = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
		for _, d in ipairs({ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0.6, 0, -0.8) }) do
			local l = drum:VectorToObjectSpace(d)
			local du, dv = Look.project("Right", l.X, l.Y, l.Z)
			near(du * du + dv * dv, 1, "unit on the drum's face", 1e-5)
		end
		local du, dv = Look.project("Nowhere", 1, 0, 0)
		equal(du, 0); equal(dv, 0)
		du, dv = Look.project("Top", 0 / 0, 0, 0)
		equal(du, 0); equal(dv, 0)
		for face, axes in pairs(Look.UV) do
			near(axes.u[1] * axes.v[1] + axes.u[2] * axes.v[2] + axes.u[3] * axes.v[3], 0, face .. ": U and V cross")
		end
	end)

	case("CL6: the offsets come from the clock, wrap into one tile and move at the flow's speed", function()
		local tile = Look.STUDS_PER_TILE
		local u, v = Look.offsets(0, 4, 0, -1, tile)
		near(u, 0); near(v, 0)
		for _, t in ipairs({ 0.3, 1, 7.5, 123.4, 98765.4 }) do
			u, v = Look.offsets(t, 4, 0.6, -0.8, tile)
			assert(u >= 0 and u < tile and v >= 0 and v < tile, "wrapped at t " .. t)
		end
		-- one step of 0.1 s moves the texture speed * 0.1 studs along the flow (mod the tile)
		local u1, v1 = Look.offsets(10, 4, 0, 1, tile)
		local u2, v2 = Look.offsets(10.1, 4, 0, 1, tile)
		near(u2 - u1, 0, "no sideways move", 1e-6)
		near((v2 - v1) % tile, 4 * 0.1 * Look.SCROLL_SIGN % tile, "0.4 studs a step", 1e-6)
		equal(select(1, Look.offsets(1, 4, 1, 0, 0)), 0, "a zero tile is refused")
		u, v = Look.offsets(0 / 0, 4, 1, 0, tile)
		equal(u, 0); equal(v, 0)
		u, v = Look.offsets(math.huge, 4, 1, 0, tile)
		equal(u, 0); equal(v, 0)
	end)

	case("CL7: the tint is the part's own colour lifted toward white, and the spec carries it", function()
		local r, g, b = Look.tint(92 / 255, 52 / 255, 34 / 255)
		assert(r > 92 / 255 and g > 52 / 255 and b > 34 / 255, "lighter than the plain chocolate")
		assert(r > g and g > b, "still a chocolate hue")
		r, g, b = Look.tint(0, 0, 0)
		near(r, Look.TINT_LIFT); near(g, Look.TINT_LIFT); near(b, Look.TINT_LIFT)
		r, g, b = Look.tint(1, 1, 1)
		near(r, 1); near(g, 1); near(b, 1)
		r = Look.tint(0 / 0, 0, 0)
		equal(r, 1, "junk is plain white")
		local spec = Look.spec("Right", 92 / 255, 52 / 255, 34 / 255)
		equal(spec.name, Look.TEXTURE_NAME); equal(spec.image, Look.IMAGE); equal(spec.face, "Right")
		equal(spec.studsPerTile, Look.STUDS_PER_TILE); equal(spec.transparency, Look.TRANSPARENCY)
		local tr = Look.tint(92 / 255, 52 / 255, 34 / 255)
		near(spec.color[1], tr)
		equal(Look.spec("Sideways", 0, 0, 0).face, "Top", "an unknown face falls back to Top")
	end)

	case("CL8: it scrolls only within 700 studs of the chocolate and never with Efectos suaves", function()
		local box = { minX = 0, maxX = 100, minZ = -50, maxZ = 50 }
		equal(Look.near(box, 50, 0, 700), true, "inside")
		equal(Look.near(box, 800, 0, 700), true, "700 east of the edge")
		equal(Look.near(box, 801, 0, 700), false, "701 east of the edge")
		equal(Look.near(box, 100 + 500, 50 + 500, 700), false, "707 off the corner")
		equal(Look.near(nil, 0, 0, 700), false); equal(Look.near(box, 0 / 0, 0, 700), false)
		equal(Look.near({ minX = 0, maxX = 0 / 0, minZ = 0, maxZ = 1 }, 0, 0, 700), false)
		equal(Look.shouldScroll(false, true), true)
		equal(Look.shouldScroll(true, true), false, "Efectos suaves: still")
		equal(Look.shouldScroll(false, false), false, "far: still")
		equal(Look.shouldScroll(nil, true), true, "no setting yet: it scrolls")
	end)

	case("CL9: the names and frames the builders lay are the ones the look reads", function()
		has(builder, '"Choco_River_" .. i', "the river blocks"); has(builder, '"Choco_Joint_" .. i', "the joints")
		has(builder, '"Choco_Pool"', "the pool"); has(builder, '"Choco_Lake_" .. i', "the lake discs")
		has(builder, 'local river = folder(into, "River")', "the River folder")
		has(builder, 'local lake = folder(into, "Lake")', "the Lake folder")
		has(builder, '"CaramelV3"', "the V3 folder")
		has(builder, "CFrame.lookAt((a + b) / 2, b)", "a river block looks downstream")
		has(builder, "CFrame.Angles(0, 0, math.rad(90))", "a drum is turned 90 about Z (its up face is Right)")
		has(east, 'East.ROOT_NAME = "Candy_Este_v1"'); has(east, 'East.FOLDER = "CloudWall"')
		has(east, '{ name = "MouthSheet", folder = East.FOLDER', "the MouthSheet")
	end)

	case("CL10: the client: local only, textures on the parts, throttled scroll, Efectos suaves, streaming, cleanup", function()
		has(client, "if not RunService:IsClient() then return end", "never on the server")
		has(client, 'require(ReplicatedStorage:WaitForChild("WildboundCandyChocoLook"))', "the rules module")
		has(client, 'Instance.new("Texture")', "a Texture per part")
		has(client, "texture.Texture = spec.image"); has(client, "texture.Face = Enum.NormalId[spec.face]")
		has(client, "texture.StudsPerTileU = spec.studsPerTile"); has(client, "texture.StudsPerTileV = spec.studsPerTile")
		has(client, "texture.Transparency = spec.transparency"); has(client, "texture.Color3 =")
		has(client, "texture.Parent = part")
		has(client, "Look.upFace(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y)", "the up face per part")
		has(client, "entry.texture.Color3 = tintOf(color)", "re-tinted when the chocolate's colour changes")
		has(client, "stepClock >= Look.STEP_SECONDS", "the scroll is throttled")
		has(client, "Look.shouldScroll(reduced(), Look.near(box, at.X, at.Z, Look.NEAR_STUDS))", "near and not Efectos suaves")
		has(client, 'gui:GetAttribute("Reduced") == true', "Efectos suaves is the world gui's Reduced")
		has(client, "Look.offsets(now, entry.speed, entry.du, entry.dv, Look.STUDS_PER_TILE)")
		has(client, "ChildAdded:Connect(markDirty)", "streamed-in parts are picked up")
		has(client, "workspace.ChildAdded:Connect(", "a root that streams in later")
		has(client, "dirty and scanClock >= Look.DIRTY_SECONDS")
		has(client, "RunService.Heartbeat:Connect(", "driven by Heartbeat")
		has(client, "script.Destroying:Connect(", "cleans up"); has(client, "for part in pairs(entries) do dropEntry(part) end")
		has(client, "Look.FORBIDDEN", "SistemaSonriente is never touched")
		has(client, "Look.coverable(f.kind) and coveredByRiver(f.part, rivers)", "a drum under a river block stays plain")
		has(client, "Look.insideBlock(at.X, at.Z, p.X, p.Z, look.X, look.Z, size.X / 2, size.Z / 2)", "the block's footprint")
		has(client, "local lakeDirection = lakeDirectionOf(found, rivers)", "one direction for every lake disc")
		has(client, 'if f.kind == "lake" then return lakeDirection end')
		for _, banned in ipairs({ "rbxassetid", "RemoteEvent", "FireServer", "InvokeServer", ":SetAttribute(", "RenderStepped",
			"part.Color =", "part.Material", "part.Transparency", "while true do" }) do
			hasNot(client, banned)
		end
	end)

	-- TB-2 review (2026-11-20): every liquid part's top is one plane, so two see-through textures that overlap draw
	-- doubled and flicker. A pool or lake disc whose centre lies inside a river block's footprint stays plain. The
	-- numbers are the v9 layout's (WildboundCandyV3Layout RIVER, LAKE, POOL): every lake disc lies in the river band.
	case("CL11: a drum under a river block stays plain: the footprint test, the v9 lake and the pool", function()
		equal(Look.coverable("lake"), true); equal(Look.coverable("pool"), true)
		equal(Look.coverable("river"), false); equal(Look.coverable("mouth"), false); equal(Look.coverable("joint"), false)
		-- a block centred at the origin, looking +x, 20 across (half 10) and 40 along (half 20)
		equal(Look.insideBlock(0, 0, 0, 0, 1, 0, 10, 20), true, "the centre")
		equal(Look.insideBlock(20, 10, 0, 0, 1, 0, 10, 20), true, "the corner")
		equal(Look.insideBlock(20 + Look.INSIDE_MARGIN + 0.01, 0, 0, 0, 1, 0, 10, 20), false, "past the end")
		equal(Look.insideBlock(0, 10 + Look.INSIDE_MARGIN + 0.01, 0, 0, 1, 0, 10, 20), false, "past the side")
		equal(Look.insideBlock(0, 15, 0, 0, 0, 1, 10, 20), true, "turned: along is z now")
		equal(Look.insideBlock(15, 0, 0, 0, 0, 1, 10, 20), false, "turned: across is x now")
		equal(Look.insideBlock(14, 14, 0, 0, 3, 3, 10, 20), true, "a diagonal block (the look need not be unit)")
		equal(Look.insideBlock(14, -14, 0, 0, 3, 3, 10, 20), false, "beside a diagonal block")
		equal(Look.insideBlock(0, 0, 0, 0, 0, 0, 10, 20), false, "no flat direction")
		equal(Look.insideBlock(0 / 0, 0, 0, 0, 1, 0, 10, 20), false, "junk")
		equal(Look.insideBlock(0, 0, 0, 0, 1, 0, math.huge, 20), false, "junk size")
		-- a leg as WildboundCandyV3Builder lays it: centre (a + b) / 2, LookVector a -> b, Size (max width, depth, |b - a|)
		local function leg(a, b)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dz * dz)
			return function(x, z)
				return Look.insideBlock(x, z, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, dx / length, dz / length,
					math.max(a[3], b[3]) / 2, length / 2)
			end
		end
		equal(leg({ 650, 195, 120 }, { 760, 195, 120 })(670, 170), true, "lake 1 (the harbour lake) lies in leg 14")
		equal(leg({ 575, 195, 110 }, { 650, 195, 120 })(580, 172), true, "lake 2 (its west lobe) lies in leg 13")
		equal(leg({ -150, -224, 50 }, { -60, -225, 64 })(-150, -222), true, "lake 3 (basin A, on river point 2) counts")
		equal(leg({ 140, -225, 64 }, { 240, -224, 64 })(240, -222), true, "lake 4 (basin B, on river point 6) counts")
		-- the pool: 9 studs (12 kit studs at 0.75) upstream of the outlet (leg 1's start), radius 8.25 (11 at 0.75)
		equal(leg({ 0, 0, 20 }, { 32.6, 0, 50 })(-9, 0), false, "the pool's centre is upstream of leg 1: it keeps its texture")
	end)

	return result
end
