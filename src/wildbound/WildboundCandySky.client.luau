-- V7-D3 (owner request 2026-11-17, "a pink sky with clouds"; odd/tasks/wildbound-caramelo-v2.md): while this player's
-- character stands in the Caramelo biome (WildboundBiomeLight.presetAt), this client shows soft pink clouds (a local
-- Clouds under Terrain, never replicated) and gives the sky a pink decay (Lighting's Atmosphere.Decay, which the world
-- client never sets); elsewhere the clouds fade out and the decay goes back to the place's own. The pink air and fog
-- themselves are WildboundAtmosphere's candy zone (ZONE_COLOURS), applied by the world client. Visual only: no
-- gameplay, no server. StarterPlayerScripts LocalScript.
-- K-D14 (owner request 2026-11-17, "es como el mundo de gatito: un parque verde lindo ..."; docs/design/
-- wildbound-kitten-park-plan.md): one look per preset. Caramelo keeps its pink look exactly; Gatuno (Pueblo Gatito, the
-- kitten park) shows white clouds under the place's own blue Sky, with no skybox swap. Walking from one look to the
-- other fades the first out, then the second in.
-- OQ1 (owner request 2026-11-19, "quiero que las nubes sean mas realistas, no una foto estirada"): the sky's clouds are
-- the engine's real 3D clouds (this one local Clouds), with a look in the two bright biomes: Caramelo pinkish, Pueblo
-- Gatito white and fluffy. Each look drifts on a slow local wind (workspace.GlobalWind, which the clouds follow; set only
-- here, never replicated, put back outside). No look swaps in the pink skybox picture any more (a stretched photo of
-- painted clouds): the pink comes from the clouds, the pink decay and the candy haze (WildboundAtmosphere), which raises
-- the haze over the place's own painted skybox; the park's sky-blue decay does the same under its haze. The place's Sky
-- (its photo, sun and moon) is never changed, in any biome: where the clouds leave sky open, only the haze covers it,
-- so whether the photo still shows overhead is a Play check (look straight up), not something the suites prove.
-- The forest and the mountains get no look: their misty open/fog/camp air (density 0.55 and up) already hides the sky,
-- so clouds there would cost a phone for nothing seen, and their wind would sway the horror forest's grass; they keep
-- the place's own sky and wind.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BiomeLight = require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))

-- cover: of the sky; density: how thick and puffy; decay: the sky's tint (none keeps the place's own); skybox: show the
-- pink skybox picture (OQ1: no look does; kept as a one-flag rollback); wind: the clouds' drift (studs/s, level)
local SKY = table.freeze({
	Caramelo = table.freeze({ cover = 0.72, density = 0.6, cloudColour = Color3.fromRGB(255, 226, 240),
		decay = Color3.fromRGB(255, 140, 196), skybox = true, wind = Vector3.new(3, 0, 1) }),
	Gatuno = table.freeze({ cover = 0.58, density = 0.62, cloudColour = Color3.fromRGB(255, 255, 255),
		decay = Color3.fromRGB(120, 176, 236), skybox = false, wind = Vector3.new(3, 0, 1) }),
})
local BLEND_SECONDS = 1.5

local player = Players.LocalPlayer
local clouds = Instance.new("Clouds")
clouds.Name = "WildboundCandyClouds"
clouds.Cover, clouds.Density, clouds.Color = 0, SKY.Caramelo.density, SKY.Caramelo.cloudColour
clouds.Enabled = false
clouds.Parent = workspace.Terrain

local originalDecay = nil
local originalWind = nil
local weight = 0 -- 0: the place's own sky, 1: the active look's
local active = nil -- the preset whose look is shown or fading (it changes only at weight 0)

-- V7-D3 (Play 2026-11-17: the place's skybox kept the sky blue under the pink air): in Caramelo this client shows the
-- pink skybox ReplicatedStorage.WildboundCandySkybox (a Sky only: the textures of a free Creator Store sky; its scripts
-- and gui were discarded) in place of the place's own Sky, which it puts back outside. Roblox draws one Sky.
-- K-D14: only a look whose skybox flag is true swaps it; the park keeps the place's own blue Sky.
-- OQ1: no look's flag is true now, so this never swaps; it stays so the swap can come back with one flag.
local template = ReplicatedStorage:WaitForChild("WildboundCandySkybox", 10)
local pinkSky, placeSky = nil, nil
local function useCandySky(on)
	if not template or not template:IsA("Sky") then return end
	on = on and SKY[active] ~= nil and SKY[active].skybox == true
	if on and not pinkSky then
		placeSky = Lighting:FindFirstChildOfClass("Sky")
		if placeSky then placeSky.Parent = nil end
		pinkSky = template:Clone()
		pinkSky.Parent = Lighting
	elseif not on and pinkSky then
		pinkSky:Destroy()
		pinkSky = nil
		if placeSky then placeSky.Parent = Lighting end
		placeSky = nil
	end
end

-- Heartbeat, not RenderStepped (RenderStepped did not fire in Studio Play: V6-D6)
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local name = root ~= nil and BiomeLight.presetAt(root.Position.X, root.Position.Z) or nil
	local wanted = SKY[name] and name or nil
	if wanted ~= active and weight == 0 then
		active = wanted
		if SKY[active] then clouds.Density, clouds.Color = SKY[active].density, SKY[active].cloudColour end
	end
	local look = SKY[active]
	local goal = (look ~= nil and wanted == active) and 1 or 0
	if weight == goal then return end
	weight = math.clamp(weight + (goal == 1 and 1 or -1) * math.min(dt, 0.1) / BLEND_SECONDS, 0, 1)
	clouds.Enabled = weight > 0
	clouds.Cover = look.cover * weight
	useCandySky(weight >= 0.5)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		originalDecay = originalDecay or atmosphere.Decay
		atmosphere.Decay = originalDecay:Lerp(look.decay or originalDecay, weight)
	end
	-- OQ1: the clouds drift on the engine's wind, faded in and out with the look (weight 0 is the place's own wind)
	originalWind = originalWind or workspace.GlobalWind
	workspace.GlobalWind = originalWind:Lerp(look.wind or originalWind, weight)
end)
