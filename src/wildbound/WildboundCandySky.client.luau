-- V7-D3 (owner request 2026-11-17, "a pink sky with clouds"; odd/tasks/wildbound-caramelo-v2.md): while this player's
-- character stands in the Caramelo biome (WildboundBiomeLight.presetAt), this client shows soft pink clouds (a local
-- Clouds under Terrain, never replicated) and gives the sky a pink decay (Lighting's Atmosphere.Decay, which the world
-- client never sets); elsewhere the clouds fade out and the decay goes back to the place's own. The pink air and fog
-- themselves are WildboundAtmosphere's candy zone (ZONE_COLOURS), applied by the world client. Visual only: no
-- gameplay, no server. StarterPlayerScripts LocalScript.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BiomeLight = require(ReplicatedStorage:WaitForChild("WildboundBiomeLight"))

local SKY = table.freeze({
	preset = "Caramelo",
	cover = 0.62, -- of the sky
	density = 0.55,
	cloudColour = Color3.fromRGB(255, 226, 240),
	decay = Color3.fromRGB(255, 140, 196),
	blendSeconds = 1.5,
})

local player = Players.LocalPlayer
local clouds = Instance.new("Clouds")
clouds.Name = "WildboundCandyClouds"
clouds.Cover, clouds.Density, clouds.Color = 0, SKY.density, SKY.cloudColour
clouds.Enabled = false
clouds.Parent = workspace.Terrain

local originalDecay = nil
local weight = 0 -- 0: the place's own sky, 1: Caramelo's

-- V7-D3 (Play 2026-11-17: the place's skybox kept the sky blue under the pink air): in Caramelo this client shows the
-- pink skybox ReplicatedStorage.WildboundCandySkybox (a Sky only: the textures of a free Creator Store sky; its scripts
-- and gui were discarded) in place of the place's own Sky, which it puts back outside. Roblox draws one Sky.
local template = ReplicatedStorage:WaitForChild("WildboundCandySkybox", 10)
local pinkSky, placeSky = nil, nil
local function useCandySky(on)
	if not template or not template:IsA("Sky") then return end
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
	local inside = root ~= nil and BiomeLight.presetAt(root.Position.X, root.Position.Z) == SKY.preset
	local goal = inside and 1 or 0
	if weight == goal then return end
	weight = math.clamp(weight + (goal == 1 and 1 or -1) * math.min(dt, 0.1) / SKY.blendSeconds, 0, 1)
	clouds.Enabled = weight > 0
	clouds.Cover = SKY.cover * weight
	useCandySky(weight >= 0.5)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		originalDecay = originalDecay or atmosphere.Decay
		atmosphere.Decay = originalDecay:Lerp(SKY.decay, weight)
	end
end)
