-- Handheld 3D flashlight (left hand so it never overlaps the right-hand bat) with F / button toggle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local template = ReplicatedStorage:WaitForChild("WildboundFlashlightModel", 15)

local flashlightOn = false
local currentModel = nil
local currentBeam = nil
local currentGlow = nil
local currentSound = nil

local function applyLightState()
	localPlayer:SetAttribute("WildboundFlashlightActive", flashlightOn)
	if currentBeam then
		currentBeam.Enabled = flashlightOn
		currentBeam.Brightness = 6
		currentBeam.Range = 70
		currentBeam.Angle = 58
	end
	if currentGlow then
		currentGlow.Enabled = flashlightOn
	end
	if currentModel then
		local handle = currentModel.PrimaryPart
		if handle then
			handle.Transparency = 0
		end
	end
end

local function toggleFlashlight(forceState)
	if forceState ~= nil then
		if flashlightOn == forceState then return end
		flashlightOn = forceState
	else
		flashlightOn = not flashlightOn
	end
	if currentSound then
		pcall(function() currentSound:Play() end)
	end
	applyLightState()
end

local function attachToCharacter(character)
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
	end
	currentBeam, currentGlow, currentSound = nil, nil, nil
	if not template or not character then return end

	local hand = character:WaitForChild("LeftHand", 4) or character:WaitForChild("Left Arm", 4)
	if not hand or not hand:IsA("BasePart") then return end

	local model = template:Clone()
	model.Name = "WildboundEquippedFlashlight"
	local handle = model.PrimaryPart or model:FindFirstChild("Handle")
	if not handle then
		model:Destroy()
		return
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true

	-- Position in the left hand pointing forward (-Z)
	local offset = hand.Name == "LeftHand"
		and CFrame.new(0, -0.15, -0.75) * CFrame.Angles(math.rad(-8), 0, 0)
		or CFrame.new(0, -0.85, -0.75) * CFrame.Angles(math.rad(-8), 0, 0)
	handle.CFrame = hand.CFrame * offset

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.Parent = handle

	local beam = handle:FindFirstChildWhichIsA("SpotLight")
	if not beam then
		beam = Instance.new("SpotLight")
		beam.Name = "FlashlightBeam"
		beam.Face = Enum.NormalId.Front
		beam.Shadows = true
		beam.Parent = handle
	end
	beam.Color = Color3.fromRGB(255, 246, 215)

	local glow = handle:FindFirstChild("FlashlightCloseGlow")
	if not glow then
		glow = Instance.new("PointLight")
		glow.Name = "FlashlightCloseGlow"
		glow.Color = Color3.fromRGB(255, 244, 210)
		glow.Brightness = 1.1
		glow.Range = 14
		glow.Parent = handle
	end

	currentModel = model
	currentBeam = beam
	currentGlow = glow
	currentSound = handle:FindFirstChildWhichIsA("Sound")
	model.Parent = character
	applyLightState()
end

localPlayer.CharacterAdded:Connect(function(character)
	task.defer(attachToCharacter, character)
end)
if localPlayer.Character then
	task.spawn(attachToCharacter, localPlayer.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then
		toggleFlashlight()
	end
end)

-- Also hook the HUD FlashlightButton once WildboundWorldUI is created.
task.spawn(function()
	local worldUi = playerGui:WaitForChild("WildboundWorldUI", 15)
	if not worldUi then return end
	local btn = worldUi:WaitForChild("FlashlightButton", 15)
	if btn and btn:IsA("GuiButton") then
		btn.Activated:Connect(function()
			toggleFlashlight()
		end)
	end
end)
