-- Invoke with require(freshTestClone)({ beasts = WildboundBeasts.Source, client = WildboundBeastsClient.Source,
-- server = WildboundServer.Source, proxies = WildboundBeastProxies.Source, text = require(freshTextClone),
-- config = require(freshBeastConfigClone), director = require(freshBeastDirectorClone) }, require(freshBeastProxiesClone)).
-- Nest Heist phase 4a (NB4 to NB6): the beast proxies (real Instances, built and destroyed here) and the source
-- contracts for how the beast script, the inventory server and the beast client wire the director and the encounters.
return function(sources, Proxies)
	local result = { passed = 0, failed = 0, messages = {} }
	local owned = {}
	local function case(name, run)
		local ok, message = pcall(run)
		for _, item in ipairs(owned) do item:Destroy() end
		table.clear(owned)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and text:find(needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function hasNot(text, needle, label)
		assert(type(text) == "string" and not text:find(needle, 1, true), (label or "source") .. " still has " .. needle)
	end
	sources = type(sources) == "table" and sources or {}
	local function keep(instance) table.insert(owned, instance); return instance end
	local function parts(model)
		local list = {}
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then table.insert(list, d) end end
		return list
	end
	local function named(model, prefix)
		local n = 0
		for _, p in ipairs(parts(model)) do if p.Name:sub(1, #prefix) == prefix then n += 1 end end
		return n
	end

	local function builders()
		assert(type(Proxies.viper) == "function" and type(Proxies.pouncer) == "function", "both proxy builders")
		return { Viper = Proxies.viper, Pouncer = Proxies.pouncer }
	end

	-- NB4 the proxies.
	case("NB4: both proxies are labelled placeholder models with a ground pivot", function()
		for beast, build in pairs(builders()) do
			local model = keep(build())
			equal(model.ClassName, "Model"); equal(model.Name, beast .. "Proxy")
			equal(model:GetAttribute("Proxy"), true, beast); equal(model:GetAttribute("Beast"), beast)
			assert(type(model:GetAttribute("ProxyNote")) == "string", "a swap note")
			assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", beast .. " pivot")
			assert(math.abs(model.PrimaryPart.Position.Y - 0.1) < 1e-3, "on the ground")
		end
	end)

	case("NB4: every proxy part is a visual only (anchored, no collision, query or touch)", function()
		for _, build in pairs(builders()) do
			local model = keep(build())
			local list = parts(model)
			assert(#list >= 20, model.Name .. " has " .. #list .. " parts")
			for _, p in ipairs(list) do
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch, p:GetFullName())
			end
		end
	end)

	case("NB4: Viper follows the reference: coil, wedge head forward, beige jaw, ivory fangs, amber Neon eyes", function()
		local model = keep(Proxies.viper())
		local C = Proxies.PALETTE
		assert(named(model, "Coil") >= 8, "a segmented coil")
		local head = model:FindFirstChild("Head")
		assert(head and head.Position.Z < -1, "the head faces the pivot's LookVector (-Z)")
		equal(model:FindFirstChild("Jaw").Color, C.viperJaw)
		equal(named(model, "Fang"), 2)
		equal(model.FangL.Color, C.viperFang)
		for _, name in ipairs({ "EyeL", "EyeR" }) do
			equal(model[name].Material, Enum.Material.Neon, name); equal(model[name].Color, C.viperEye, name)
		end
		equal(C.viperEye, Color3.fromHex("FF7A0A"))
		local _, size = model:GetBoundingBox()
		assert(math.max(size.X, size.Z) >= 8 and math.max(size.X, size.Z) <= 13, "about 10 studs long: " .. tostring(size))
	end)

	case("NB4: Pouncer follows the reference: broad plum body, 8 angular legs, ivory fangs, magenta Neon eyes", function()
		local model = keep(Proxies.pouncer())
		local C = Proxies.PALETTE
		equal(named(model, "Femur"), 8); equal(named(model, "Tibia"), 8); equal(named(model, "Claw"), 8)
		equal(model.Body.Color, C.pouncerPlum)
		equal(model.FangL.Color, C.pouncerIvory)
		local eyes = 0
		for _, p in ipairs(parts(model)) do
			if p.Name:sub(1, 3) == "Eye" then
				eyes += 1
				equal(p.Material, Enum.Material.Neon, p.Name); equal(p.Color, C.pouncerEye, p.Name)
			end
		end
		assert(eyes >= 4, "a cluster of eyes")
		assert(model.Head.Position.Z < -1, "the head faces -Z")
		local _, size = model:GetBoundingBox()
		assert(size.X >= 8 and size.X <= 12 and size.Y <= 7, "wide and low: " .. tostring(size))
	end)

	case("NB4: telegraphs are never part of a model; no asset ids, no contact events", function()
		for _, build in pairs(builders()) do
			local model = keep(build())
			for _, p in ipairs(parts(model)) do
				for _, bad in ipairs({ "Lane", "Circle", "Telegraph", "Ring" }) do
					assert(not p.Name:find(bad, 1, true), p.Name)
				end
			end
		end
		hasNot(sources.proxies, "rbxassetid", "proxies"); hasNot(sources.proxies, "Touched", "proxies")
	end)

	case("NB4: ensure builds the folder once and never replaces the user's imported model", function()
		local fake = keep(Instance.new("Folder"))
		local models = Proxies.ensure(fake)
		equal(models.Parent.Name, "WildboundBeasts"); equal(models.Name, "Models")
		assert(models:FindFirstChild("ViperProxy") and models:FindFirstChild("PouncerProxy"), "both proxies")
		Proxies.ensure(fake)
		equal(#models:GetChildren(), 2, "no duplicate on a second call")
		equal(Proxies.modelFor(models, "Viper"), models.ViperProxy, "the proxy while there is no import")
		local imported = Instance.new("Model")
		imported.Name = "Viper"
		imported.Parent = models
		equal(Proxies.modelFor(models, "Viper"), imported, "an import named Viper wins")
		Proxies.ensure(fake)
		equal(models:FindFirstChild("Viper"), imported, "kept")
		equal(Proxies.modelFor(models, "Mire"), nil)
	end)

	return result
end
