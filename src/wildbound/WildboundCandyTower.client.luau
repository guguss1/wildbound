-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT2): turns the Gran Torta's tier decorations on this client. The
-- server builds them (WildboundCandyBuilder.syncTower: Workspace.Candy_Bioma_v1.Tower.Spin_<k>, attributes SpinRate in
-- radians per second, CentreX, CentreZ) and never moves them; every client turns each ring about the cake's centre by
-- SpinRate x the server time, so all clients agree and the motion is smooth. The invisible Turntable_<k> discs, whose
-- angular velocity carries the players, are never moved here.
local RunService = game:GetService("RunService")

local rings = {} -- [Model] = { base = CFrame (its pivot as built), rate, centre }

local function add(model)
	if not model:IsA("Model") or string.sub(model.Name, 1, 5) ~= "Spin_" or rings[model] then return end
	local rate, cx, cz = model:GetAttribute("SpinRate"), model:GetAttribute("CentreX"), model:GetAttribute("CentreZ")
	if type(rate) ~= "number" or type(cx) ~= "number" or type(cz) ~= "number" then return end
	rings[model] = { base = model:GetPivot(), rate = rate, centre = Vector3.new(cx, 0, cz) }
end

local function watch(tower)
	for _, child in ipairs(tower:GetChildren()) do add(child) end
	tower.ChildAdded:Connect(function(child) task.defer(add, child) end)
end

task.spawn(function()
	local biome = workspace:WaitForChild("Candy_Bioma_v1", 120)
	local tower = biome and biome:WaitForChild("Tower", 120)
	if tower then watch(tower) end
end)

-- Heartbeat, not RenderStepped: it runs every frame on every client (RenderStepped stops when nothing renders).
RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	for model, ring in pairs(rings) do
		if model.Parent == nil then
			rings[model] = nil
		else
			local turn = CFrame.new(ring.centre) * CFrame.Angles(0, (ring.rate * t) % (2 * math.pi), 0) * CFrame.new(-ring.centre)
			model:PivotTo(turn * ring.base)
		end
	end
end)
