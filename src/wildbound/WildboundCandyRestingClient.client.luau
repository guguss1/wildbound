-- PF3 (odd/tasks/wildbound-caramelo-playfix.md): the Caramelo creatures rest at their posts between encounters, on
-- this client. For every post WildboundCandyRestingService publishes (ReplicatedStorage.WildboundBeasts attribute
-- RestingPost_<name>), a clone of the beast's model (WildboundBeasts.Models.<name>, the same one the beast client
-- shows) stands there facing +Z, the facing an encounter starts and ends with. It lives in WildboundBeastsLocal with
-- BeastPhase "Calm", so the existing animators (WildboundCandyCritterAnim, the Gomibu, Flanfuria and Tortidragon
-- players) play its idle loop on it. While a live view of that beast exists in the folder (this player's encounter or
-- another player's, seen as a bystander) the resting copy is taken away, and it comes back when the view ends: the
-- live view appears on the post and every calm encounter walks home to it before it ends, so nothing pops in or out.
-- A fresh clone each time, so the animators never set the same model up twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon" }

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 120)
local models = root and root:WaitForChild("Models", 120)
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not root or not models or not folder then return end

local resting = {} -- [name] = the resting clone, or nil

local function liveView(name)
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == name and child:GetAttribute("WildboundResting") ~= true then return true end
	end
	return false
end

local function refresh(name)
	local post = root:GetAttribute("RestingPost_" .. name)
	local template = models:FindFirstChild(name)
	local wanted = typeof(post) == "Vector3" and template ~= nil and not liveView(name)
	local copy = resting[name]
	if copy and (not wanted or copy.Parent ~= folder) then
		resting[name] = nil
		copy:Destroy()
		copy = nil
	end
	if wanted and not copy then
		copy = template:Clone()
		copy.Name = name
		copy:SetAttribute("WildboundResting", true)
		copy:SetAttribute("BeastPhase", "Calm")
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide, d.CanTouch, d.CanQuery = false, false, false end
		end
		copy:PivotTo(CFrame.lookAt(post, post + Vector3.new(0, 0, 1)))
		copy.Parent = folder
		resting[name] = copy
	end
end

local function refreshAll()
	for _, name in ipairs(NAMES) do refresh(name) end
end

local watched = {}
for _, name in ipairs(NAMES) do
	watched[name] = true
	root:GetAttributeChangedSignal("RestingPost_" .. name):Connect(function() refresh(name) end)
end
-- a live view comes or goes (deferred: its Name is set before it is parented, and the next frame settles a swap)
folder.ChildAdded:Connect(function(child)
	if watched[child.Name] and child:GetAttribute("WildboundResting") ~= true then task.defer(refresh, child.Name) end
end)
folder.ChildRemoved:Connect(function(child)
	if watched[child.Name] and child:GetAttribute("WildboundResting") ~= true then task.defer(refresh, child.Name) end
end)
models.ChildAdded:Connect(function(child)
	if watched[child.Name] then refresh(child.Name) end
end)
refreshAll()
