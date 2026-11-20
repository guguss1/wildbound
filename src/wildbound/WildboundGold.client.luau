-- Gold HUD (odd/tasks/wildbound-gold.md): the "Oro: N" counter, read from the player attribute WildboundGold that the
-- server's WildboundGoldService keeps, and the batched "+N oro" popup sent through the GoldPopup remote. View only:
-- the client never changes gold.
-- Owner request 2026-11-20 (UR-H3, docs/design/refs/store-ui-reference.png): the counter is a glossy navy pill with a
-- coin emoji, gold outlined words and the 3D bottom edge, and it pops when gold goes up (never with "Efectos suaves");
-- the popup's words carry the kit's thick outline. Same words, same remote, nothing uploaded.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Text = require(ReplicatedStorage:WaitForChild("WildboundText"))
local T = Text.GOLD
-- The shared look (WildboundUiStyle). Without the module every call is a no-op and the plain look stays. An older
-- module without the glossy kit (no Style.gloss, a partial Studio sync) counts as missing, so a gold gain never
-- calls a function that is not there.
local Style = (function()
	local found = ReplicatedStorage:WaitForChild("WildboundUiStyle", 10)
	local loaded = found and require(found)
	if type(loaded) == "table" and type(loaded.gloss) == "function" then return loaded end
	return setmetatable({}, { __index = function() return function() end end })
end)()
local kit = type(Style.HUD_SIZES) == "table"
local GOLD_INK = Color3.fromRGB(255, 214, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "WildboundGoldUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local counter = Instance.new("TextLabel")
counter.Name = "GoldCounter"
counter.AnchorPoint = Vector2.new(1, 0)
counter.Position = UDim2.new(1, -12, 0, 8)
counter.Size = UDim2.fromOffset(150, 36)
counter.BackgroundColor3 = Color3.fromRGB(54, 40, 12)
counter.BackgroundTransparency = 0.15
counter.TextColor3 = GOLD_INK
counter.Font = Enum.Font.FredokaOne
counter.TextSize = 22
counter.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = counter
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 60)
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = counter
if kit then
	-- The glossy pill keeps this label's own border stroke (now thick and dark) and its gold words, outlined.
	Style.gloss(counter, "dark")
	counter.TextColor3 = GOLD_INK
	Style.fitText(counter, 22, 12)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Active = false
	icon.AnchorPoint = Vector2.new(0, 0.5)
	-- Measured from the padded area below (40 px in), so the coin sits 10 px from the pill's left end.
	icon.Position = UDim2.new(0, -30, 0.5, 0)
	icon.Size = UDim2.fromOffset(26, 26)
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 22
	icon.Text = type(Style.ICONS) == "table" and Style.ICONS.gold or ""
	icon.Parent = counter
	-- The words start right of the coin and sit on the lit face, above the edge.
	local pad = Instance.new("UIPadding")
	pad.Name = "WbLift"
	pad.PaddingLeft = UDim.new(0, 40)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, Style.HUD_SIZES.lip)
	pad.Parent = counter
end

local shownGold = nil
local function refresh()
	local gold = player:GetAttribute("WildboundGold")
	local amount = type(gold) == "number" and gold or 0
	counter.Text = T.counter:format(amount)
	if shownGold ~= nil and amount > shownGold then Style.bump(counter, Style.reduced(playerGui)) end
	shownGold = amount
end
player:GetAttributeChangedSignal("WildboundGold"):Connect(refresh)
refresh()

local function popup(amount)
	local label = Instance.new("TextLabel")
	label.Name = "GoldPopup"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -12, 0, 48)
	label.Size = UDim2.fromOffset(130, 30)
	label.BackgroundTransparency = 1
	label.Text = T.popup:format(amount)
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	-- The kit's thick round outline on the words; it fades with them.
	Style.loudText(label, Enum.Font.FredokaOne, 2, Color3.fromRGB(255, 226, 120))
	label.Parent = gui
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(label, info,
		{ Position = UDim2.new(1, -12, 0, 80), TextTransparency = 1, TextStrokeTransparency = 1 })
	local outline = label:FindFirstChild("WbTextStroke")
	if outline and outline:IsA("UIStroke") then TweenService:Create(outline, info, { Transparency = 1 }):Play() end
	tween.Completed:Connect(function() label:Destroy() end)
	tween:Play()
end

local network = ReplicatedStorage:WaitForChild("WildboundNetwork", 30)
local remote = network and network:WaitForChild("GoldPopup", 30)
if remote then
	remote.OnClientEvent:Connect(function(amount)
		if type(amount) == "number" and amount > 0 then popup(math.floor(amount)) end
	end)
end
