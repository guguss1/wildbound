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

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inside = root ~= nil and BiomeLight.presetAt(root.Position.X, root.Position.Z) == SKY.preset
	local goal = inside and 1 or 0
	if weight == goal then return end
	weight = math.clamp(weight + (goal == 1 and 1 or -1) * math.min(dt, 0.1) / SKY.blendSeconds, 0, 1)
	clouds.Enabled = weight > 0
	clouds.Cover = SKY.cover * weight
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		originalDecay = originalDecay or atmosphere.Decay
		atmosphere.Decay = originalDecay:Lerp(SKY.decay, weight)
	end
end)
