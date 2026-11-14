-- Studio fresh-clone suite runner (read-only for game scripts). Paste into Studio MCP execute_luau (Edit datamodel).
-- For each ServerStorage.Wildbound*_Test (or only those matching FILTER) it clones the test and its module into one
-- temporary folder, requires the clones, runs the test and sums { passed, failed }. It never edits a Source, never
-- touches Workspace and destroys the temporary folder on every path. Returns a text report.
--
-- Invocation: SPECS names the arguments for suites whose signature is known. Every other suite gets the default
-- (require(moduleClone), moduleClone.Source, sources), where the module is the same name without "_Test" and
-- `sources` maps every Wildbound script name to its Source. A suite with a different signature may fail or error
-- under the default; the report lists those suites as "default" so their failures are not read as regressions.
-- Totals from this runner are not comparable to the old 70-suite / 1454-passed baseline (a different runner).

local FILTER = nil -- e.g. "^WildboundBalance_Test$"; nil runs every Wildbound*_Test
local TMP_NAME = "WildboundFreshRunner_Tmp"

local ServerStorage = game:GetService("ServerStorage")
local CONTAINERS = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	ServerStorage,
	game:GetService("StarterPlayer"),
}

local tmp -- the temporary folder; clones inside it are never picked as originals

local function findModule(name)
	for _, container in ipairs(CONTAINERS) do
		local direct = container:FindFirstChild(name)
		if direct and direct:IsA("ModuleScript") then return direct end
		for _, item in ipairs(container:GetDescendants()) do
			if item.Name == name and item:IsA("ModuleScript") and not (tmp and item:IsDescendantOf(tmp)) then return item end
		end
	end
	return nil
end

local sources = {}
for _, container in ipairs(CONTAINERS) do
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("LuaSourceContainer") and item.Name:match("^Wildbound") and sources[item.Name] == nil then
			sources[item.Name] = item.Source
		end
	end
end

local old = ServerStorage:FindFirstChild(TMP_NAME)
if old then old:Destroy() end
tmp = Instance.new("Folder")
tmp.Name = TMP_NAME
tmp.Parent = ServerStorage

local function fresh(name)
	local module = findModule(name)
	if not module then error("module not found: " .. name) end
	local clone = module:Clone()
	clone.Parent = tmp
	return require(clone), clone.Source
end

-- Known signatures. Each returns the argument list for its suite.
local SPECS = {
	WildboundBalance_Test = function()
		local Balance, source = fresh("WildboundBalance")
		return { Balance, source }
	end,
	WildboundWorldRules_Test = function()
		local Rules = fresh("WildboundWorldRules")
		local layout = fresh("WildboundIslandLayout")
		return { Rules, layout }
	end,
}

local totals = { suites = 0, passed = 0, failed = 0, errored = 0 }
local lines, defaults = {}, {}

local ran, problem = pcall(function()
	local tests = {}
	for _, child in ipairs(ServerStorage:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("^Wildbound.*_Test$") and (FILTER == nil or child.Name:match(FILTER)) then
			table.insert(tests, child)
		end
	end
	table.sort(tests, function(a, b) return a.Name < b.Name end)
	for _, test in ipairs(tests) do
		totals.suites += 1
		local ok, outcome = pcall(function()
			local args
			if SPECS[test.Name] then
				args = SPECS[test.Name]()
			else
				table.insert(defaults, test.Name)
				local moduleName = test.Name:gsub("_Test$", "")
				if findModule(moduleName) then
					local module, source = fresh(moduleName)
					args = { module, source, sources }
				else
					args = { sources }
				end
			end
			local clone = test:Clone()
			clone.Parent = tmp
			return require(clone)(table.unpack(args))
		end)
		if ok and type(outcome) == "table" and type(outcome.passed) == "number" and type(outcome.failed) == "number" then
			totals.passed += outcome.passed
			totals.failed += outcome.failed
			if outcome.failed > 0 then
				local first = type(outcome.messages) == "table" and outcome.messages[1] or ""
				table.insert(lines, string.format("%s: %d/%d; %s", test.Name, outcome.passed, outcome.failed, tostring(first):sub(1, 200)))
			end
		else
			totals.errored += 1
			table.insert(lines, string.format("%s: ERROR %s", test.Name, tostring(outcome):sub(1, 200)))
		end
		task.wait()
	end
end)

tmp:Destroy()

local report = string.format("suites %d, passed %d, failed %d, errored %d (not comparable to the old baseline)%s\n%s\ndefault invocation: %s",
	totals.suites, totals.passed, totals.failed, totals.errored, ran and "" or ("; runner error: " .. tostring(problem)),
	table.concat(lines, "\n"), table.concat(defaults, ", "))
return report
