-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D13; owner request 2026-11-17: "... otra canción que tenga
-- que ver más con gatitos ..."): tells the audio controller when this player is in the kitten park. Every 0.25 s it
-- reads the character's root and sets the local WildboundWorldUI attribute GatitoAmbience: on within 16 studs of the
-- park's rectangle (x 948..1468, z -263..257), off once more than 24 studs outside it (WildboundCandyKittens.inPark,
-- ENTER_MARGIN and LEAVE_MARGIN; PG-D5 "the border is the cloud": it turns on inside the cloud band, x 932..948, and the
-- hysteresis keeps the band from flickering it). WildboundAudioClient then plays the kitten bed
-- (WildboundAudioMix.withKitten) in place of the Caramelo track, and while it is on the Caramelo ambience and life
-- clients stand down. Local only: no server traffic. StarterPlayerScripts LocalScript (Studio name
-- WildboundCandyKittenAmbienceClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kittens = require(ReplicatedStorage:WaitForChild("WildboundCandyKittens"))

local POLL_SECONDS = 0.25
local player = Players.LocalPlayer
local on, running = false, true

local function worldGui()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("WildboundWorldUI")
end

local function setFlag(value)
	local gui = worldGui()
	if gui and gui:GetAttribute(Kittens.GUI_ATTRIBUTE) ~= value then gui:SetAttribute(Kittens.GUI_ATTRIBUTE, value) end
end

script.Destroying:Connect(function()
	running, on = false, false
	setFlag(false)
end)

while running do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	on = root ~= nil and Kittens.inPark(on, root.Position.X, root.Position.Z)
	setFlag(on)
	task.wait(POLL_SECONDS)
end
