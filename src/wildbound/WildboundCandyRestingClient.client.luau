-- PF3 (odd/tasks/wildbound-caramelo-playfix.md): the Caramelo creatures rest at their posts between encounters, on
-- this client. For every post WildboundCandyRestingService publishes (ReplicatedStorage.WildboundBeasts attribute
-- RestingPost_<name>), a clone of the beast's model (WildboundBeasts.Models.<name>, the same one the beast client
-- shows) stands there facing +Z, the facing an encounter starts and ends with. It lives in WildboundBeastsLocal with
-- BeastPhase "Calm", so the existing animators (WildboundCandyCritterAnim, the Gomibu, Flanfuria and Tortidragon
-- players) play its idle loop on it. While a live view of that beast exists in the folder (this player's encounter or
-- another player's, seen as a bystander) the resting copy is taken away, and it comes back when the view ends: the
-- live view appears on the post and every calm encounter walks home to it before it ends, so nothing pops in or out.
-- A fresh clone each time, so the animators never set the same model up twice.
-- CH1 (owner request "more repeated creatures"): a creature may also have extra posts (RestingPost_<name>_<post>), each
-- with its own copy. A live view belongs to the post it starts on (a post of its beast within BIND_STUDS of where the
-- view first stands: a post encounter starts exactly on its post, still calm for its alert) and hides only that copy.
-- The first look waits FIRST_SECONDS, so the beast client has moved the freshly parented model onto its spawn point; a
-- view not placed yet is looked at again a few times. A view that starts on no post (an ambush critter, a roar's
-- guardian beside the thief) hides nothing. Event driven: no per-frame work.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- K-D7 (Pueblo Gatito, owner request 2026-11-17 "un parque verde lindo con las criaturas gatitas"): the four kittens
-- (Models.<name> built by WildboundCandyKittenService; no name has an underscore, nameOf needs that)
local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor", "Gomibu", "Flanfuria", "Tortidragon",
	"GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" }
local BIND_STUDS, BIND_TRIES, BIND_SECONDS = 12, 8, 0.25
local FIRST_SECONDS = 0.1

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 120)
local models = root and root:WaitForChild("Models", 120)
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not root or not models or not folder then return end

local resting = {} -- [post attribute] = the resting clone, or nil
local bound = {} -- [live view] = the post attribute it started on

-- The beast of a post attribute, RestingPost_<name> or RestingPost_<name>_<post> (no beast name has an underscore).
local function nameOf(attribute)
	return string.match(attribute, "^RestingPost_([^_]+)")
end

-- The post attributes of one beast: its home post first, then its extra posts.
local function postsOf(name)
	local list = {}
	if typeof(root:GetAttribute("RestingPost_" .. name)) == "Vector3" then table.insert(list, "RestingPost_" .. name) end
	local prefix = "RestingPost_" .. name .. "_"
	for attribute, value in pairs(root:GetAttributes()) do
		if typeof(value) == "Vector3" and string.sub(attribute, 1, #prefix) == prefix then table.insert(list, attribute) end
	end
	return list
end

local function liveView(attribute)
	for view, post in pairs(bound) do
		if post == attribute and view.Parent == folder then return true end
	end
	return false
end

local function refresh(attribute)
	local name = nameOf(attribute)
	local post = root:GetAttribute(attribute)
	local template = name and models:FindFirstChild(name)
	local wanted = typeof(post) == "Vector3" and template ~= nil and not liveView(attribute)
	local copy = resting[attribute]
	if copy and (not wanted or copy.Parent ~= folder) then
		resting[attribute] = nil
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
		resting[attribute] = copy
	end
end

local function refreshName(name)
	for _, attribute in ipairs(postsOf(name)) do refresh(attribute) end
end

-- Ties a live view to the nearest post of its beast, then takes that post's copy away.
local function bind(view, tries)
	if view.Parent ~= folder or bound[view] or not view:IsA("Model") then return end
	local at = view:GetPivot().Position
	local best, bestD = nil, BIND_STUDS
	for _, attribute in ipairs(postsOf(view.Name)) do
		local post = root:GetAttribute(attribute)
		local d = Vector2.new(post.X - at.X, post.Z - at.Z).Magnitude
		if d < bestD then best, bestD = attribute, d end
	end
	if best then
		bound[view] = best
		refresh(best)
	elseif tries > 0 then
		task.delay(BIND_SECONDS, bind, view, tries - 1)
	end
end

local watched = {}
for _, name in ipairs(NAMES) do watched[name] = true end
root.AttributeChanged:Connect(function(attribute)
	local name = nameOf(attribute)
	if name and watched[name] then refresh(attribute) end
end)
-- a live view comes or goes (deferred: its Name is set before it is parented, and the next frame settles a swap)
folder.ChildAdded:Connect(function(child)
	if watched[child.Name] and child:GetAttribute("WildboundResting") ~= true then task.delay(FIRST_SECONDS, bind, child, BIND_TRIES) end
end)
folder.ChildRemoved:Connect(function(child)
	local post = bound[child]
	if post then
		bound[child] = nil
		task.defer(refresh, post)
	end
end)
models.ChildAdded:Connect(function(child)
	if watched[child.Name] then refreshName(child.Name) end
end)
for _, child in ipairs(folder:GetChildren()) do
	if watched[child.Name] and child:GetAttribute("WildboundResting") ~= true then bind(child, BIND_TRIES) end
end
for _, name in ipairs(NAMES) do refreshName(name) end
