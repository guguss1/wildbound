-- Fall damage service (owner request 2026-11-19, "que haya daño de caida desde esa torre y de otras torres altas").
-- The rules are WildboundFallDamage (pure); this script only measures and applies them, on the server.
--
-- The switch: damage stays off outside the private test place. This script asks WildboundFairStrike.effectiveMode with
-- WildboundFlags and game.PlaceId, exactly as WildboundServer and WildboundWorld do (no attribute is ever read back to
-- decide damage); anything but "private" ends the script before it samples anyone, so where creature damage is off a
-- fall shows nothing and costs nothing.
--
-- Measuring: every Heartbeat, for each player, the server's own root position, a short ground ray under the feet
-- (characters excluded, only colliding parts, water ignored) and what the server itself wrote: the creatures' push
-- attachment WildboundBeastPush, the bat's WildboundBatHit and WildboundRagdollUntil, WildboundHidden, the portal's
-- WildboundPortalReadyAt, a health drop (a hit), the seat, an anchored root, the humanoid's state. In Caramelo it also
-- reads whether a cookie bridge under the player is crumbling (its CookieBridgePhase) and, at a landing, whether the
-- feet are in the chocolate (WildboundCandyWade's rule). Nothing comes from the client.
--
-- Applying: a landing whose reason is "Hurt" goes to the inventory server's BeastHit (ReplicatedStorage.WildboundNetwork,
-- server to server) as beast "Fall" with the egg kept: the same path as a creature hit, so the paid-trip rule, the dodge
-- window, lastHitAt (regeneration waits), the BeastHitDamage telemetry, the notice (Text.BEAST.Fall.hit) and the hit
-- sound and damage number on the client all come from there. BeastHit says nothing for a fall that took nothing.
--
-- The warning (earlier owner decision, "Ningún golpe mata de una y todos avisan antes"): a player's first landing that
-- would hurt costs nothing and only warns, through the same BeastHit as beast "FallWarn" with 0 damage (its notice is
-- Text.BEAST.FallWarn.hit); the landings after it hurt. A warning BeastHit did not give (the dodge window, no BeastHit)
-- is given at the next one instead.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Fall = require(script.Parent:WaitForChild("WildboundFallDamage"))
local FairStrike = require(script.Parent:WaitForChild("WildboundFairStrike"))

local flagsModule = script.Parent:FindFirstChild("WildboundFlags")
local flagsOk, flags = false, nil
if flagsModule and flagsModule:IsA("ModuleScript") then flagsOk, flags = pcall(require, flagsModule) end
local damageMode = FairStrike.effectiveMode(flagsOk and flags or nil, game.PlaceId)
if damageMode ~= "private" then return end

local function count(key, amount)
	local telemetry = ServerStorage:FindFirstChild("WildboundTelemetry")
	if telemetry then telemetry:SetAttribute(key, (telemetry:GetAttribute(key) or 0) + (amount or 1)) end
end

-- Caramelo (optional): the layout, the chocolate's wading rule and the cookie bridges. A place without them simply has
-- no chocolate and no cookie bridge.
local candy = nil -- the loaded modules, or false when one is missing
local function candyModules()
	if candy ~= nil then return candy or nil end
	local loaded = {}
	local names = { Layout = "WildboundCandyLayout", V3 = "WildboundCandyV3Layout", Wade = "WildboundCandyWade",
		Cookie = "WildboundCandyCookieBridge" }
	for key, name in pairs(names) do
		local module = ServerStorage:FindFirstChild(name)
		local ok, value = false, nil
		if module and module:IsA("ModuleScript") then ok, value = pcall(require, module) end
		if not ok or type(value) ~= "table" then
			candy = false
			return nil
		end
		loaded[key] = value
	end
	candy = loaded
	return loaded
end

-- The live biome (only once it carries the v3 mark: the chocolate is laid) and its cookie bridge models, read again
-- every 5 s.
local biome, bridges, biomeAt = nil, {}, -math.huge
local function refreshBiome(now)
	if now - biomeAt < 5 and now >= biomeAt then return end
	biomeAt = now
	biome, bridges = nil, {}
	local m = candyModules()
	if not m then return end
	local root = workspace:FindFirstChild(m.Layout.ROOT_NAME)
	if not root or root:GetAttribute(m.V3.MARK) == nil then return end
	biome = root
	local caramel = root:FindFirstChild(m.V3.FOLDER)
	local folder = caramel and caramel:FindFirstChild("Bridges")
	if not folder then return end
	for _, id in ipairs(m.Cookie.IDS) do
		local model = folder:FindFirstChild(m.Cookie.MODEL_PREFIX .. id)
		if model then table.insert(bridges, { id = id, model = model }) end
	end
end

-- Decision (Bridge): inside the footprint of a cookie bridge that is cracking or down, a fall never hurts.
local function crumblingAt(position)
	if not biome or not candy then return false end
	local m = candy
	for _, b in ipairs(bridges) do
		local phase = b.model:GetAttribute(m.Cookie.PHASE_ATTRIBUTE)
		if phase ~= nil and phase ~= "Up"
			and m.Cookie.blocks(m.V3, b.id, position.X - m.Layout.CENTRE.x, position.Z - m.Layout.CENTRE.z) then
			return true
		end
	end
	return false
end

-- Soft: the standing root over this landing would wade (WildboundCandyWade.wading, the wading service's own rule).
local function softAt(x, standY, z, half, hipHeight, isR6)
	if not biome or not candy then return false end
	local m = candy
	local info = m.Wade.probe(m.V3, m.Layout.CENTRE, m.Layout.FLOOR_TOP, Vector3.new(x, standY, z), half, hipHeight, isR6)
	info.alive = true
	return m.Wade.wading(false, info)
end

-- The ground ray: characters (and what they carry) excluded, only colliding parts, water ignored.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
local function refreshFilter()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(list, player.Character) end
	end
	rayParams.FilterDescendantsInstances = list
end

-- The last landings that mattered (not "Low"), for the Studio probe below.
local recent = {}
local function note(player, landing)
	table.insert(recent, { userId = player.UserId, reason = landing.reason, drop = landing.drop, damage = landing.damage,
		seconds = landing.seconds, x = landing.x, y = landing.y, z = landing.z })
	while #recent > 12 do table.remove(recent, 1) end
end

local beastHit = nil
local function findBeastHit()
	local network = ReplicatedStorage:FindFirstChild("WildboundNetwork")
	if not (beastHit and beastHit.Parent) then beastHit = network and network:FindFirstChild("BeastHit") end
	if not beastHit or not beastHit:IsA("BindableFunction") then
		count("Fall_noBeastHit")
		return false
	end
	return true
end

local function hurt(player, damage)
	if not findBeastHit() then return end
	local ok, effect = pcall(function() return beastHit:Invoke(player, "Fall", damage, true) end)
	if not ok then
		warn("WildboundFallDamageService: BeastHit failed: " .. tostring(effect))
		return
	end
	if type(effect) == "table" and type(effect.damage) == "number" then count("Fall_damage", effect.damage) end
end

-- The first landing that would hurt only warns (0 damage, Text.BEAST.FallWarn.hit). rec.warned is already true; it
-- goes back to false when BeastHit gave no notice (dodged, refused, missing), so the next such landing warns instead.
local function warnFall(player, rec)
	if not findBeastHit() then
		rec.warned = false
		return
	end
	local ok, effect = pcall(function() return beastHit:Invoke(player, "FallWarn", 0, true) end)
	if not ok then
		rec.warned = false
		warn("WildboundFallDamageService: BeastHit failed: " .. tostring(effect))
		return
	end
	if type(effect) ~= "table" or effect.dodged == true then
		rec.warned = false
		return
	end
	count("Fall_warned")
end

local records = {} -- [player] = { track, sample, character, humanoid, root, shovedAt, health, healthWatch, warned, conns }

local function bindParts(rec, character)
	rec.character = character
	rec.humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
	local root = character and character:FindFirstChild("HumanoidRootPart") or nil
	rec.root = root and root:IsA("BasePart") and root or nil
	if rec.healthWatch then rec.healthWatch:Disconnect() end
	rec.healthWatch = nil
	local humanoid = rec.humanoid
	if humanoid then
		rec.health = humanoid.Health
		-- Shoved: a hit that took health (a creature, La Silueta, a nest parent) makes the next SHOVE_GRACE_SECONDS free.
		rec.healthWatch = humanoid.HealthChanged:Connect(function(health)
			if Fall.hurt(rec.health, health) then rec.shovedAt = workspace:GetServerTimeNow() end
			rec.health = health
		end)
	end
end

local RAGDOLL_STATES = {
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}
local HELD_STATES = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
}

local function stepPlayer(player, rec, now)
	local character = player.Character
	if character ~= rec.character or (character and (not rec.humanoid or not rec.root)) then bindParts(rec, character) end
	local humanoid, root = rec.humanoid, rec.root
	if not character or not humanoid or not root or root.Parent ~= character or character.Parent == nil then
		Fall.step(rec.track, nil, now)
		return
	end
	local position = root.Position
	local state = humanoid:GetState()
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local half = root.Size.Y / 2
	local hip = humanoid.HipHeight
	local hit = workspace:Raycast(position, Vector3.new(0, -Fall.rayLength(half, hip, isR6), 0), rayParams)
	local groundY = hit and Fall.groundHeight(hit.Position.Y, half, hip, isR6) or nil
	-- Shoved: a creature's push (it lasts at most 1 s) or a ragdoll seen on the humanoid
	if root:FindFirstChild("WildboundBeastPush") or humanoid.PlatformStand or RAGDOLL_STATES[state] then rec.shovedAt = now end
	local shovedAt = rec.shovedAt
	local bat = player:GetAttribute("WildboundBatHit")
	if type(bat) == "number" and (shovedAt == nil or bat > shovedAt) then shovedAt = bat end
	local s = rec.sample
	s.life = character
	s.x, s.y, s.z = position.X, position.Y, position.Z
	s.groundY = groundY
	s.alive = humanoid.Health > 0 and state ~= Enum.HumanoidStateType.Dead
	s.held = root.Anchored or humanoid.SeatPart ~= nil or HELD_STATES[state] == true
		or player:GetAttribute("WildboundHidden") ~= nil
	s.portal = player:GetAttribute("WildboundPortalReadyAt")
	s.shovedAt = shovedAt
	s.ragdollUntil = player:GetAttribute("WildboundRagdollUntil")
	s.crumbling = crumblingAt(position)
	s.soft = groundY ~= nil and Fall.inAir(rec.track) and softAt(position.X, groundY, position.Z, half, hip, isR6) or false
	s.gravity = workspace.Gravity
	local landing = Fall.step(rec.track, s, now)
	if not landing or landing.reason == "Low" then return end
	count("Fall_" .. landing.reason)
	note(player, landing)
	if landing.reason == "Hurt" and landing.damage > 0 then
		if rec.warned then
			task.spawn(hurt, player, landing.damage)
		else
			rec.warned = true
			task.spawn(warnFall, player, rec)
		end
	end
end

local function track(player)
	if records[player] then return end
	records[player] = { track = Fall.new(), sample = {}, character = nil, humanoid = nil, root = nil, shovedAt = nil,
		health = nil, healthWatch = nil, warned = false, conns = {
			player.CharacterAdded:Connect(function() task.defer(refreshFilter) end),
			player.CharacterRemoving:Connect(function() task.defer(refreshFilter) end),
		} }
end
Players.PlayerAdded:Connect(track)
for _, player in ipairs(Players:GetPlayers()) do track(player) end
Players.PlayerRemoving:Connect(function(player)
	local rec = records[player]
	if rec and rec.healthWatch then rec.healthWatch:Disconnect() end
	if rec then
		for _, conn in ipairs(rec.conns) do conn:Disconnect() end
	end
	records[player] = nil
	task.defer(refreshFilter)
end)
refreshFilter()

local failed = false
local heartbeat = RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	refreshBiome(now)
	for player, rec in pairs(records) do
		local ok, message = pcall(stepPlayer, player, rec, now)
		if not ok and not failed then
			failed = true -- warned once; the step goes on for the others
			warn("WildboundFallDamageService: step error: " .. tostring(message))
		end
	end
end)
script.Destroying:Connect(function() heartbeat:Disconnect() end)

-- Studio only, server only (ServerStorage, never a remote): the Play check reads the last landings that mattered.
if RunService:IsStudio() then
	local old = ServerStorage:FindFirstChild("FallDamageProbe")
	if old then old:Destroy() end
	local probe = Instance.new("BindableFunction")
	probe.Name = "FallDamageProbe"
	probe.OnInvoke = function()
		local out = {}
		for index, row in ipairs(recent) do out[index] = table.clone(row) end
		return out
	end
	probe.Parent = ServerStorage
end
