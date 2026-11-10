-- Invoke with require(freshTestClone)(require(freshArtClone), freshArtClone.Source, { server = WildboundServer.Source,
-- worldClient = WildboundWorldClient.Source, species = require(freshSpeciesClone),
-- template = ServerStorage.WildboundAssets.LumipolMeshGen }) in Studio Edit.
-- MeshGen1 pass (user, 2026-11-10: "agrega el MeshGen1 como lumipol ya que es su modelo"): every Lumipol the game
-- shows wears the user's model, cloned from ServerStorage.WildboundAssets.LumipolMeshGen, fitted to a height per
-- context, feet on the given frame, art only (no collision, touch or query); the gameplay body is unchanged and a
-- missing or bad template keeps the primitive look.
return function(Art, source, sources)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-4),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	sources = type(sources) == "table" and sources or {}
	local C = type(Art) == "table" and Art.CONFIG or {}

	-- A stand-in for the user's model: two parts in sub-models, its pivot nowhere near its feet, 4 studs tall.
	local function template()
		local model = Instance.new("Model")
		model.Name = "LumipolMeshGen"
		for _, spec in ipairs({ { "head", Vector3.new(3, 2, 2), Vector3.new(10, 3, 5) },
			{ "legs", Vector3.new(2, 2, 2), Vector3.new(10, 1, 5.5) } }) do
			local group = Instance.new("Model")
			group.Name = spec[1]
			local part = Instance.new("Part")
			part.Name = spec[1] .. "_geom"
			part.Size, part.Position = spec[2], spec[3]
			part.Anchored, part.CanCollide = false, true
			part.Parent = group
			group.Parent = model
		end
		model.WorldPivot = CFrame.new(10, 2, 5)
		return model
	end
	local function holder()
		local model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name, body.Size, body.CFrame = "Body", Vector3.new(3, 2, 2.4), CFrame.new(0, 2, 0)
		body.Parent = model
		model.PrimaryPart = body
		return model, body
	end
	local function artParts(model)
		local list = {}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child:GetAttribute(C.ATTRIBUTE) == true then table.insert(list, child) end
		end
		return list
	end
	local function bounds(parts)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		-- World bounds from each part's eight corners (a turned part's Size is in its own axes).
		for _, part in ipairs(parts) do
			local half = part.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						lo, hi = lo:Min(corner), hi:Max(corner)
					end
				end
			end
		end
		return lo, hi
	end

	case("MG1: the config is frozen and names the template, the attribute and the heights", function()
		assert(type(Art) == "table" and type(C) == "table" and table.isfrozen(C), "frozen CONFIG")
		equal(C.TEMPLATE, "LumipolMeshGen")
		equal(C.ATTRIBUTE, "LumipolArt")
		assert(type(C.HEIGHT) == "number" and C.HEIGHT >= 2 and C.HEIGHT <= 4, "adult height " .. tostring(C.HEIGHT))
		assert(type(C.CARRIED_HEIGHT) == "number" and C.CARRIED_HEIGHT > 0.5 and C.CARRIED_HEIGHT < 1.8,
			"the carried art fits the 1.8-stud capsule: " .. tostring(C.CARRIED_HEIGHT))
	end)

	case("MG1: only the Lumipol look wears the art", function()
		local Species = sources.species
		assert(type(Species) == "table", "species module missing")
		equal(Art.uses(Species.look(nil)), true, "no species is the Lumipol")
		equal(Art.uses(Species.look("Lumipol")), true)
		for _, name in ipairs({ "Cortezon", "Cestillo", "Polvilla", "Tizoncillo" }) do
			equal(Art.uses(Species.look(name)), false, name)
		end
		equal(Art.uses(nil), false)
	end)

	case("MG1: a template must be a model of parts with no scripts or humanoid", function()
		equal(Art.valid(template()), true)
		equal(Art.valid(nil), false)
		equal(Art.valid(Instance.new("Part")), false)
		equal(Art.valid(Instance.new("Model")), false, "no parts")
		local scripted = template()
		Instance.new("Script").Parent = scripted.head
		equal(Art.valid(scripted), false, "a script")
		local rigged = template()
		Instance.new("Humanoid").Parent = rigged
		equal(Art.valid(rigged), false, "a humanoid")
	end)

	case("MG1: dressing fits the height, puts the feet on the frame and faces its way", function()
		local model = holder()
		local feet = CFrame.new(5, 10, -3) * CFrame.Angles(0, math.rad(90), 0)
		local parts = Art.dress(model, template(), feet, 2.6)
		assert(type(parts) == "table" and #parts == 2, "two art parts")
		local lo, hi = bounds(parts)
		near(hi.Y - lo.Y, 2.6, 1e-3, "height")
		near(lo.Y, 10 + C.FOOT_LIFT, 1e-3, "feet")
		near((lo.X + hi.X) / 2, 5, 1e-3, "centred x"); near((lo.Z + hi.Z) / 2, -3, 1e-3, "centred z")
		-- The template's head sits toward -Z of the legs; turned 90 degrees it must sit toward the frame's look.
		local head, legs
		for _, part in ipairs(parts) do
			if part.Name == "head_geom" then head = part else legs = part end
		end
		local ahead = (head.Position - legs.Position):Dot(feet.LookVector)
		assert(ahead > 0, "the head leans the way the frame looks: " .. ahead)
	end)

	case("MG1: art parts are direct children, anchored, massless and never collide, touch or block a ray", function()
		local model, body = holder()
		local parts = Art.dress(model, template(), CFrame.new(), 1.4)
		for _, part in ipairs(parts) do
			equal(part.Parent, model, part.Name)
			equal(part.Anchored, true); equal(part.CanCollide, false); equal(part.CanTouch, false)
			equal(part.CanQuery, false); equal(part.Massless, true); equal(part.CastShadow, false)
			equal(part:GetAttribute(C.ATTRIBUTE), true)
		end
		equal(#artParts(model), #parts)
		equal(model.PrimaryPart, body, "the gameplay body stays the primary part")
		equal(body.Size, Vector3.new(3, 2, 2.4), "the gameplay body keeps its size")
		for _, child in ipairs(model:GetChildren()) do equal(child:IsA("Model"), false, "no art container left") end
	end)

	case("MG1: the template itself is never changed", function()
		local source = template()
		local before = source.head.head_geom.CFrame
		Art.dress(holder(), source, CFrame.new(50, 0, 0), 2.6)
		equal(source.head.head_geom.CFrame, before)
		equal(source.head.head_geom.Size, Vector3.new(3, 2, 2))
		equal(source.WorldPivot, CFrame.new(10, 2, 5))
	end)

	case("MG1: a missing or bad template, frame or height leaves the model as it was", function()
		for label, call in pairs({
			missing = function(model) return Art.dress(model, nil, CFrame.new(), 2.6) end,
			scripted = function(model)
				local bad = template()
				Instance.new("Script").Parent = bad
				return Art.dress(model, bad, CFrame.new(), 2.6)
			end,
			frame = function(model) return Art.dress(model, template(), Vector3.zero, 2.6) end,
			zero = function(model) return Art.dress(model, template(), CFrame.new(), 0) end,
			nan = function(model) return Art.dress(model, template(), CFrame.new(), 0 / 0) end,
		}) do
			local model = holder()
			equal(call(model), nil, label)
			equal(#model:GetChildren(), 1, label .. ": only the body")
		end
		equal(Art.dress(nil, template(), CFrame.new(), 2.6), nil, "no model")
	end)

	case("MG1: the template's meshes are listed once each, and the art counts only when every one loaded", function()
		equal(#Art.meshIds(template()), 0, "parts without meshes")
		local real = sources.template
		assert(typeof(real) == "Instance", "the place's LumipolMeshGen template is missing")
		local ids = Art.meshIds(real)
		equal(#ids, 4, "head, body, legs and ears")
		for index, id in ipairs(ids) do
			assert(type(id) == "string" and id:find("^rbxassetid://%d+$"), "mesh id " .. tostring(id))
			if index > 1 then assert(ids[index - 1] < id, "sorted, no repeats") end
		end
		equal(Art.verified({ "a", "b" }, { a = true, b = true }), true)
		equal(Art.verified({ "a", "b" }, { a = true, b = false }), false, "one failed")
		equal(Art.verified({ "a", "b" }, { a = true }), false, "one never answered")
		equal(Art.verified({}, {}), true, "nothing to load")
		equal(Art.verified(nil, {}), false); equal(Art.verified({ "a" }, nil), false)
		assert(type(C.VERIFY_SECONDS) == "number" and C.VERIFY_SECONDS >= 1 and C.VERIFY_SECONDS <= 10,
			"a short, bounded start-up wait: " .. tostring(C.VERIFY_SECONDS))
	end)

	case("MG1: the server dresses every Lumipol from the template and keeps the primitive as the fallback", function()
		local server = sources.server
		assert(type(server) == "string" and #server > 1000, "server source missing")
		assert(server:find("WildboundLumipolArt", 1, true), "the server requires the art module")
		assert(server:find("Art.CONFIG.TEMPLATE", 1, true), "the template is looked up by its configured name")
		assert(server:find("Art.uses(look)", 1, true), "only the Lumipol look is dressed")
		-- Play finding: meshes the session may not load would leave an invisible Lumipol, so the server loads each one
		-- first and drops the template unless all of them loaded.
		assert(server:find("CreateMeshPartAsync", 1, true), "the server loads each mesh before using the template")
		assert(server:find("Art.verified(", 1, true), "the template is dropped unless every mesh loaded")
		local visualBody = server:match("local function visual%(.-\nend\n")
		assert(visualBody, "visual() not found")
		assert(visualBody:find("Art.dress(", 1, true), "visual() dresses the creature")
		assert(visualBody:find("Art.CONFIG.HEIGHT * scale", 1, true), "visual() fits the art to its scale")
		assert(visualBody:find("Transparency = 1", 1, true), "a dressed creature hides its gameplay ball")
		assert(visualBody:find("if not dressed", 1, true), "the primitive eyes and ears are the fallback")
		local capsule = server:match("local function buildCapsule%(.-\nend\n")
		assert(capsule, "buildCapsule() not found")
		assert(capsule:find("Art.CONFIG.CARRIED_HEIGHT", 1, true), "the carried cria wears the art too")
		assert(capsule:find("ArtJoint", 1, true), "the carried art is welded to the seat ball")
	end)

	case("MG1: the companion's camera fade moves the art, never the hidden ball", function()
		local world = sources.worldClient
		assert(type(world) == "string" and #world > 1000, "world client source missing")
		local fade = world:match("local function animateCompanions%(.-\nend\n")
		assert(fade, "animateCompanions() not found")
		assert(fade:find("LumipolArt", 1, true), "it reads the art attribute")
		assert(fade:find("LocalTransparencyModifier", 1, true), "it fades the art locally")
	end)

	case("MG1: the art module reads no service, clock or remote", function()
		assert(type(source) == "string" and #source > 300, "source missing")
		for _, banned in ipairs({ "GetService", "os.clock", "os.time", "tick%(", "workspace", "game%.", "Remote" }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end
