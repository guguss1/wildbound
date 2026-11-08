-- Dev tuning bridge (docs/testing/wildbound-tuning.md). Deploy in ServerScriptService beside the gameplay modules.
-- ReplicatedStorage.WildboundTuning holds every tunable value as an attribute, one Configuration per system. This
-- script applies them to the server's modules whenever one changes (a Properties edit during Play, or the developer
-- panel), and owns the panel's remote, which checks everything on the server. Module defaults stay the source of
-- truth: with no folder or no attribute the modules keep their defaults.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Schema = require(ReplicatedStorage:WaitForChild("WildboundTuningSchema"))

-- Extra developers on the private place, by user id. The place owner is always one; Studio is always allowed.
local ALLOWLIST = {}

if ReplicatedStorage:FindFirstChild(Schema.REMOTE) then
	warn("WildboundTuning: the remote already exists; duplicate startup refused.")
	return
end

-- The same module instances the gameplay scripts require, so a tune reaches them. A missing module is skipped.
local modules = {}
for key, name in pairs({ Stamina = "WildboundStamina", Island = "WildboundIsland", Brain = "WildboundGuardianBrain",
	Rules = "WildboundWorldRules", Hide = "WildboundHide" }) do
	local module = ServerScriptService:WaitForChild(name, 10)
	if module and module:IsA("ModuleScript") then modules[key] = require(module) end
end
for key, name in pairs({ Carry = "WildboundCarry", Capture = "WildboundCaptureSession" }) do
	local module = ReplicatedStorage:WaitForChild(name, 10)
	if module and module:IsA("ModuleScript") then modules[key] = require(module) end
end

local folder = Schema.ensureFolder(ReplicatedStorage)
local read = Schema.reader(folder)

-- Server-only counters (ServerStorage never replicates). The world server creates the folder, maybe after this script.
local function telemetry()
	return ServerStorage:FindFirstChild("WildboundTelemetry")
end
local function count(name)
	local holder = telemetry()
	if holder then holder:SetAttribute(name, (holder:GetAttribute(name) or 0) + 1) end
end

local function applyAll()
	Schema.apply(modules, read, "server")
	count("Tuning_applied")
end

-- One attribute changed: clamp it into range (written back, so Properties shows what applies), ignore a wrong type,
-- then re-tune every server module from its defaults plus the current values.
local function watch(child)
	local system = Schema.system(child.Name)
	if not system then return end
	child.AttributeChanged:Connect(function(name)
		local entry = Schema.find(child.Name, name)
		if not entry then return end
		local raw = child:GetAttribute(name)
		local clean = Schema.sanitize(entry, raw)
		if clean == nil then
			if raw ~= nil then warn(("WildboundTuning: %s.%s is not a number; the default applies."):format(child.Name, name)) end
		elseif clean ~= raw then
			child:SetAttribute(name, clean)
			return -- the write-back fires this handler again with the clamped value
		end
		applyAll()
	end)
end
for _, child in ipairs(folder:GetChildren()) do watch(child) end
applyAll()

local changed = Schema.changed(read)
if #changed > 0 then
	print(("WildboundTuning: %d value(s) differ from the repo defaults: %s"):format(#changed, table.concat(changed, ", ")))
end

-- Who is a developer is decided here only. In Studio a NumberValue or BoolValue named TuningSimulateNonDev in
-- ServerStorage.WildboundTelemetry (no client can reach it) makes every request act as a stranger's, for checks.
local groupRanks = {}
local function contextFor(player)
	local holder = telemetry()
	local simulate = RunService:IsStudio() and holder ~= nil and holder:FindFirstChild("TuningSimulateNonDev") ~= nil
	return {
		studio = RunService:IsStudio() and not simulate,
		placeId = simulate and 0 or game.PlaceId,
		userId = player.UserId,
		creatorId = game.CreatorId,
		creatorType = game.CreatorType.Name,
		groupRank = groupRanks[player],
		allowlist = ALLOWLIST,
	}
end

local function mark(player)
	if game.CreatorType == Enum.CreatorType.Group and game.PlaceId == Schema.PRIVATE_PLACE_ID then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		groupRanks[player] = ok and rank or 0
	end
	player:SetAttribute(Schema.DEV_ATTRIBUTE, Schema.isDeveloper(contextFor(player)))
end
Players.PlayerAdded:Connect(mark)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(mark, player) end

local limiters, lastLog = {}, {}
Players.PlayerRemoving:Connect(function(player)
	limiters[player], lastLog[player], groupRanks[player] = nil, nil, nil
end)

local function reject(player, reason)
	count("Tuning_rejected")
	local now = os.clock()
	if not lastLog[player] or now - lastLog[player] >= 1 then
		lastLog[player] = now
		warn(("WildboundTuning: rejected %s from %s (%d)"):format(reason, player.Name, player.UserId))
	end
	return false, reason
end

local function resetSystem(system)
	local child = folder:FindFirstChild(system.id)
	if child then
		for _, entry in ipairs(system.entries) do child:SetAttribute(entry.key, entry.default) end
	end
end

local remote = Instance.new("RemoteFunction")
remote.Name = Schema.REMOTE
remote.OnServerInvoke = function(player, action, systemId, key, value, ...)
	if select("#", ...) > 0 then return reject(player, "ExtraArguments") end
	local limiter = limiters[player]
	if not limiter then
		limiter = Schema.newLimiter()
		limiters[player] = limiter
	end
	if not Schema.allow(limiter, os.clock()) then return reject(player, "RateLimited") end
	local ok, reason, clean = Schema.validateRequest(contextFor(player), action, systemId, key, value)
	if not ok then return reject(player, reason) end
	-- A request never builds a new folder: if a developer deleted it, the defaults apply until the next server.
	if folder.Parent == nil then return reject(player, "NoFolder") end
	if action == "set" then
		local child = folder:FindFirstChild(systemId)
		if not child then return reject(player, "NoFolder") end
		child:SetAttribute(key, clean)
	else
		for _, system in ipairs(Schema.SYSTEMS) do
			if systemId == nil or system.id == systemId then resetSystem(system) end
		end
	end
	count("Tuning_accepted")
	return true, clean
end
remote.Parent = ReplicatedStorage
