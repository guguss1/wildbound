-- T1 (docs/design/wildbound-fun-build-plan.md; owner request 2026-11-20 "que se pueda jugar mas tiempo"): the thief
-- rank on the HUD. A glossy sign at the top left with the rank's emoji and name, a yellow bar under it ("1/3 huevos"
-- toward the next rank) and, when a new rank is reached, a yellow card with turning rays in the middle of the screen
-- ("¡Ladronzuelo!", "Nuevo rango de ladrón", the next goal) for a few seconds. It reads the player attribute
-- WildboundThiefSteals that WildboundGoldService keeps from the saved count (WildboundRank). View only: the client
-- never changes the count. The first value read (the save loading) only sets the sign: it never shows the card.
-- With "Efectos suaves" the card does not pop and its rays do not turn. StarterPlayerScripts LocalScript.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Rank = require(ReplicatedStorage:WaitForChild("WildboundRank"))
-- The shared look (WildboundUiStyle). An older module without the glossy kit counts as missing and the plain look
-- below is used, so nothing calls a function that is not there.
local Style = (function()
	local found = ReplicatedStorage:WaitForChild("WildboundUiStyle", 10)
	local loaded = found and require(found)
	if type(loaded) == "table" and type(loaded.kitCounter) == "function" and type(loaded.kitProgressBar) == "function"
		and type(loaded.kitCard) == "function" then
		return loaded
	end
	return nil
end)()

local SIGN_WIDTH, SIGN_HEIGHT, BAR_HEIGHT, GAP = 176, 44, 24, 6
local NARROW = 700 -- below this screen width the sign moves under the Vida bar's row (a phone)
local CARD_SECONDS = 4

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundRankUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
if Style then Style.screen(gui) end -- like every kit screen: children draw over their parent (the card's rays)
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "RankSign"
holder.BackgroundTransparency = 1
holder.Active = false
holder.AnchorPoint = Vector2.new(0, 0)
holder.Size = UDim2.fromOffset(SIGN_WIDTH, SIGN_HEIGHT + GAP + BAR_HEIGHT)
holder.Parent = gui

local function place()
	local narrow = gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.X < NARROW
	holder.Position = UDim2.fromOffset(12, narrow and 48 or 8)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
place()

local sign, signIcon, signName, bar, setBar
if Style then
	local value
	sign, value = Style.kitCounter(holder, "", "", "purple", "Sign")
	sign.Size = UDim2.fromOffset(SIGN_WIDTH, SIGN_HEIGHT)
	signIcon, signName = sign:FindFirstChild("Icon"), value
	bar = Style.kitProgressBar(holder, "", "yellow", "Bar")
	bar.Position = UDim2.fromOffset(0, SIGN_HEIGHT + GAP)
	bar.Size = UDim2.fromOffset(SIGN_WIDTH, BAR_HEIGHT)
	setBar = function(have, need, text) Style.setProgress(bar, have, need, text) end
else
	sign = Instance.new("Frame")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(SIGN_WIDTH, SIGN_HEIGHT)
	sign.BackgroundColor3 = Color3.fromRGB(156, 82, 236)
	sign.Parent = holder
	signIcon = Instance.new("TextLabel")
	signIcon.Name = "Icon"
	signIcon.BackgroundTransparency = 1
	signIcon.Size = UDim2.fromOffset(SIGN_HEIGHT, SIGN_HEIGHT)
	signIcon.TextSize = 26
	signIcon.Parent = sign
	signName = Instance.new("TextLabel")
	signName.Name = "Value"
	signName.BackgroundTransparency = 1
	signName.Position = UDim2.fromOffset(SIGN_HEIGHT, 0)
	signName.Size = UDim2.new(1, -SIGN_HEIGHT - 6, 1, 0)
	signName.Font = Enum.Font.FredokaOne
	signName.TextScaled = true
	signName.TextColor3 = Color3.new(1, 1, 1)
	signName.Parent = sign
	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(0, SIGN_HEIGHT + GAP)
	bar.Size = UDim2.fromOffset(SIGN_WIDTH, BAR_HEIGHT)
	bar.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
	bar.Parent = holder
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(255, 202, 40)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local words = Instance.new("TextLabel")
	words.Name = "Text"
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(1, 1)
	words.Font = Enum.Font.FredokaOne
	words.TextScaled = true
	words.TextColor3 = Color3.new(1, 1, 1)
	words.ZIndex = 2
	words.Parent = bar
	setBar = function(have, need, text)
		local share = need > 0 and math.clamp(have / need, 0, 1) or 0
		fill.Size = UDim2.fromScale(share, 1)
		fill.Visible = share > 0
		words.Text = text
	end
end

local function reduced()
	return Style ~= nil and Style.reduced(playerGui) == true
end

local card = nil
local function showCard(entry)
	if card then card:Destroy() end
	local title, body, hint = Rank.upLines(entry)
	local shown
	if Style then
		shown = Style.kitCard(gui, "yellow", reduced(), "RankUpCard")
		local heading = Style.kitTitle(shown, title, 36)
		heading.Position = UDim2.fromOffset(10, 10)
		heading.Size = UDim2.new(1, -20, 0, 52)
		local line = Style.kitLabel(shown, "Body", entry.icon .. " " .. body, 22)
		line.Position = UDim2.fromOffset(10, 66)
		line.Size = UDim2.new(1, -20, 0, 32)
		Style.fitText(line, 22, 12)
		local goal = Style.kitLabel(shown, "Hint", hint, 16)
		goal.Position = UDim2.fromOffset(10, 104)
		goal.Size = UDim2.new(1, -20, 0, 28)
		Style.fitText(goal, 16, 10)
	else
		shown = Instance.new("TextLabel")
		shown.Name = "RankUpCard"
		shown.BackgroundColor3 = Color3.fromRGB(255, 202, 40)
		shown.Font = Enum.Font.FredokaOne
		shown.TextScaled = true
		shown.Text = title .. "\n" .. body .. "\n" .. hint
		shown.Parent = gui
	end
	shown.Active = false
	shown.AnchorPoint = Vector2.new(0.5, 0.5)
	shown.Position = UDim2.fromScale(0.5, 0.32)
	shown.Size = UDim2.fromOffset(320, 144)
	card = shown
	if not reduced() then
		local scale = Instance.new("UIScale")
		scale.Name = "WbPop"
		scale.Scale = 0.6
		scale.Parent = shown
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(CARD_SECONDS, function()
		if card == shown then card = nil end
		if shown.Parent then shown:Destroy() end
	end)
end

local shownCount = nil -- nil until the first number arrives (the save loading), which never shows the card
local function refresh()
	local value = player:GetAttribute(Rank.ATTRIBUTE)
	local known = type(value) == "number"
	local count = Rank.count(value)
	local progress = Rank.progress(count)
	if signIcon then signIcon.Text = progress.icon end
	signName.Text = progress.name
	setBar(progress.have, progress.need, progress.text)
	if not known then return end
	local reached = Rank.reached(shownCount, count)
	if reached then showCard(reached) end
	if Style and shownCount ~= nil and count > shownCount then Style.bump(sign, reduced()) end
	shownCount = math.max(shownCount or 0, count)
end
player:GetAttributeChangedSignal(Rank.ATTRIBUTE):Connect(refresh)
refresh()
