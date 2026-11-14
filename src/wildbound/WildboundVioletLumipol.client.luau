-- Hue-shifts the existing Lumipol texture (rbxassetid://101357790480936) into violet on the client
-- for any Lumipol marked with the LumipolViolet attribute, keeping eyes, outlines and shading intact.
local AssetService = game:GetService("AssetService")
local LUMIPOL_TEXTURE = "rbxassetid://101357790480936"

local violetImage = nil
local loadAttempted = false

local function getVioletImage()
	if loadAttempted then return violetImage end
	loadAttempted = true
	local ok, ei = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(LUMIPOL_TEXTURE))
	end)
	if not ok or not ei then return nil end

	local okShift = pcall(function()
		local size = ei.Size
		local buf = ei:ReadPixelsBuffer(Vector2.new(0, 0), size)
		for i = 0, buffer.len(buf) - 1, 4 do
			local a = buffer.readu8(buf, i + 3)
			if a > 10 then
				local r = buffer.readu8(buf, i)
				local g = buffer.readu8(buf, i + 1)
				local b = buffer.readu8(buf, i + 2)
				local h, s, v = Color3.fromRGB(r, g, b):ToHSV()
				-- Shift teal/cyan/green body hues (0.30..0.68) to rich violet (0.72..0.84) while keeping eyes/highlights untouched.
				if s >= 0.12 and h >= 0.30 and h <= 0.68 then
					local newH = (h + 0.27) % 1
					local newS = math.clamp(s * 1.25, 0, 1)
					local c = Color3.fromHSV(newH, newS, v)
					buffer.writeu8(buf, i, math.clamp(math.round(c.R * 255), 0, 255))
					buffer.writeu8(buf, i + 1, math.clamp(math.round(c.G * 255), 0, 255))
					buffer.writeu8(buf, i + 2, math.clamp(math.round(c.B * 255), 0, 255))
				end
			end
		end
		ei:WritePixelsBuffer(Vector2.new(0, 0), size, buf)
	end)
	if not okShift then
		ei:Destroy()
		return nil
	end
	violetImage = ei
	return violetImage
end

local function isVioletMarked(inst)
	if inst:GetAttribute("LumipolViolet") == true then return true end
	local parent = inst.Parent
	while parent and parent ~= workspace and parent ~= game do
		if parent:GetAttribute("LumipolViolet") == true then return true end
		parent = parent.Parent
	end
	return false
end

local function applyViolet(part)
	if not part:IsA("MeshPart") or part.TextureID ~= LUMIPOL_TEXTURE then return end
	if not isVioletMarked(part) then return end
	if part:FindFirstChild("VioletLumipolSA") then return end

	local img = getVioletImage()
	if not img then return end

	local sa = Instance.new("SurfaceAppearance")
	sa.Name = "VioletLumipolSA"
	sa.ColorMapContent = Content.fromObject(img)
	sa.Parent = part
end

task.spawn(function()
	getVioletImage()
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("MeshPart") then
			applyViolet(desc)
		end
	end
end)

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("MeshPart") then
		task.defer(applyViolet, desc)
	elseif desc:IsA("Model") then
		desc:GetAttributeChangedSignal("LumipolViolet"):Connect(function()
			for _, child in ipairs(desc:GetDescendants()) do
				if child:IsA("MeshPart") then applyViolet(child) end
			end
		end)
	end
end)
