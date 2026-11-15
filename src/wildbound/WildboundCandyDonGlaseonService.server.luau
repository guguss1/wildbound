-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3): Don Glaseon's models.
-- 1. The beast client shows ReplicatedStorage.WildboundBeasts.Models.<beast> when it exists, so a copy of the rig prefab
--    is parked there with the published clip ids (Clip_<name>) and the lash's numbers (Latigo_<name>) as attributes for
--    WildboundCandyDonGlaseonAnim on each client, which cannot read ServerStorage.
-- 2. One boss per server, seen by everybody: while no Don Glaseon encounter lives (the beast script writes
--    WildboundTelemetry.Beast_bossAwake), a sleeping copy stands on its BossHome marker facing the biome's entrance;
--    it is taken away while the boss is awake (every encounter starts and ends at home, so it never jumps). It is
--    scenery: anchored, it never attacks and the server never moves it. CF3: it is taken away in the summon's own
--    server step (the beast script writes Beast_bossAwake when an encounter starts and ends), and while it sleeps it
--    is pass-through (DonGlaseon.asleep), so it never blocks the main lane that ends at the plaza.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Clips = require(ServerStorage:WaitForChild("WildboundCandyDonGlaseonClips"))
local Latigo = require(ServerStorage:WaitForChild("WildboundCandyDonGlaseonAttack"))
local DonGlaseon = require(ServerStorage:WaitForChild("WildboundCandyDonGlaseon"))
local Sites = require(ServerScriptService:WaitForChild("WildboundPraderaSites"))
local prefab = ServerStorage:WaitForChild("WildboundAssets"):WaitForChild("DonGlaseon")

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
-- only published clips: until a clip has an id the client leaves the model in its rest pose for that phase
local function dress(model)
	for _, name in ipairs(Clips.ORDER) do
		if Clips.IDS[name] then model:SetAttribute("Clip_" .. name, Clips.animationId(name)) end
	end
	model:SetAttribute("Latigo_ReleaseSeconds", Latigo.RELEASE_SECONDS)
	model:SetAttribute("Latigo_LengthStuds", Latigo.LENGTH_STUDS)
	return model
end
if models and not models:FindFirstChild("DonGlaseon") then
	local model = dress(prefab:Clone())
	model.Name = "DonGlaseon"
	model.Parent = models
elseif not models then
	warn("WildboundCandyDonGlaseonService: ReplicatedStorage.WildboundBeasts.Models never appeared, Don Glaseon has no model.")
end

-- The sleeping boss on BossHome.
local telemetry = ServerStorage:WaitForChild("WildboundTelemetry", 60)
local home = Sites.world(nil, "bossHome")
local sleeper = DonGlaseon.asleep(dress(prefab:Clone()))
sleeper.Name = "DonGlaseonDormant"
sleeper:SetAttribute("BeastPhase", "Dormant")
local params = RaycastParams.new()
local biome = workspace:FindFirstChild("Candy_Bioma_v1")
local floor = biome and biome:FindFirstChild("Ground")
-- the candy floor only (never the markers over it); without the biome, anything but itself
params.FilterType = floor and Enum.RaycastFilterType.Include or Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { floor or sleeper }
local hit = workspace:Raycast(Vector3.new(home.x, 200, home.z), Vector3.new(0, -400, 0), params)
local ground = Vector3.new(home.x, hit and hit.Position.Y or 0, home.z)
-- it faces the biome's entrance (west, -X), where players come from
sleeper:PivotTo(CFrame.lookAt(ground, ground + Vector3.new(-1, 0, 0)))

local function refresh()
	local awake = telemetry and telemetry:GetAttribute("Beast_bossAwake") == true
	sleeper.Parent = (not awake) and workspace or nil
end
if telemetry then telemetry:GetAttributeChangedSignal("Beast_bossAwake"):Connect(refresh) end
refresh()
