-- Nest Heist hub (docs/maps/wildbound-hub.md section 5, HB-T3 to HB-T5): the personal bases' station prompts, server
-- only. Every station the hub builder tagged gets one prompt; a trigger is answered only for that base's owner (the
-- OwnerUserId the hub script wrote on the base model) standing within the station's Range, measured here from the
-- server's own position of the player (WildboundBases.mayUse). The client sends nothing but the prompt trigger. The
-- inventory server passes its own rules as handlers, so the base stations reuse the camp's code paths.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Stations = {}
Stations.__index = Stations

-- Tag -> station kind; a kind names a handler, a prompt key (Keys.HUB) and the words below.
Stations.TAGS = table.freeze({
	["WildboundDeliveryStation"] = "delivery",
	["WildboundIncubatorStation"] = "incubator",
	["WildboundGloveStation"] = "glove",
	["WildboundTrainingStation"] = "train",
})
-- text: the prompt's action (Text.HUB key); action: the reply that carries a refusal; hold: seconds (nil = default).
local PROMPTS = table.freeze({
	delivery = table.freeze({ text = "deliveryPrompt", action = "Extract" }),
	incubator = table.freeze({ text = "incubatorPrompt", action = "Hatch" }),
	glove = table.freeze({ text = "glovePrompt", action = "OpenBoard" }),
	train = table.freeze({ text = "trainPrompt", action = "Train", hold = 1 }),
})

-- HB-T5: the collection display's three slots, and how far over a slot's top a Lumipol hovers (the world client adds
-- the idle bob from the Base frame).
Stations.DISPLAY_SLOTS = 3
Stations.HOVER = 0.8

-- deps = { Bases, Text, Keys, prompt(target, action, object, range, hold, input), rootOf(player), alive(player),
-- allowed(player, action), refuse(player, action, reason), handlers = { [kind] = function(player, distance, station) },
-- snapshot(userId), visual(species, position) -> model, dressed }
function Stations.new(deps)
	return setmetatable({ deps = deps, bound = {}, displays = {} }, Stations)
end

-- The base model a station belongs to and the owner the server wrote on it (0 while free).
function Stations:ownerOf(station)
	local model = station:FindFirstAncestorWhichIsA("Model")
	while model and not CollectionService:HasTag(model, "WildboundBaseSlot") do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return model and model:GetAttribute("OwnerUserId") or 0, model
end

-- ok, reason, distance: the pure owner and range check on the server's numbers.
function Stations:measure(player, station)
	local deps = self.deps
	local root = deps.rootOf(player)
	if not root or not deps.alive(player) then return false, "InvalidContext" end
	local distance = (root.Position - station.Position).Magnitude
	local ok, why = deps.Bases.mayUse(self:ownerOf(station), player.UserId, distance, station:GetAttribute("Range") or 8)
	return ok, why, distance
end

-- The distance to this player's own station with that tag when it is in reach, else math.huge (the camp's rules then
-- take the smaller of this and the camp's own distance).
function Stations:distance(player, tag)
	for station, entry in pairs(self.bound) do
		if entry.tag == tag then
			local ok, _, distance = self:measure(player, station)
			if ok then return distance end
		end
	end
	return math.huge
end

-- The bound station of that kind in that base slot (the Studio probe's lookup).
function Stations:find(kind, slot)
	for station, entry in pairs(self.bound) do
		if entry.kind == kind and station:GetAttribute("SlotIndex") == slot then return station end
	end
	return nil
end

-- The prompt's path (a Studio probe calls it too): rate limit, owner and range, then the kind's handler.
function Stations:trigger(player, station)
	local entry = self.bound[station]
	if not entry or not station:IsDescendantOf(workspace) then return end
	local spec = PROMPTS[entry.kind]
	if not self.deps.allowed(player, spec.action) then return end
	local ok, why, distance = self:measure(player, station)
	if not ok then
		self.deps.refuse(player, spec.action, why)
		return
	end
	self.deps.handlers[entry.kind](player, distance, station)
end

function Stations:bind(station, tag)
	local kind = Stations.TAGS[tag]
	if self.bound[station] or not kind or not self.deps.handlers[kind] then return end
	if not station:IsA("BasePart") or not station:IsDescendantOf(workspace) then return end
	local spec, Text = PROMPTS[kind], self.deps.Text
	local prompt = self.deps.prompt(station, Text.HUB[spec.text], station:GetAttribute("Label") or "",
		station:GetAttribute("Range") or 8, spec.hold, self.deps.Keys.HUB[kind])
	-- Each client shows only its own base's prompts (WildboundClient); the server still checks every trigger.
	prompt:SetAttribute("WildboundHubStation", kind)
	self.bound[station] = { kind = kind, tag = tag, prompt = prompt }
	prompt.Triggered:Connect(function(player) self:trigger(player, station) end)
	station.AncestryChanged:Connect(function()
		if not station:IsDescendantOf(workspace) then self.bound[station] = nil end
	end)
end

-- HB-T5: the collection display. The owner's chosen Lumipols (Bases.displayPicks) hover over DisplaySlot1..3 of the
-- base's WildboundCollectionDisplay platform, facing the lobby; the inventory server's creature look dresses them in
-- the MeshGen art when it loaded, else the primitive look. Rebuilt only when the choice or the base changes.
function Stations:platformOf(userId)
	for _, platform in ipairs(CollectionService:GetTagged("WildboundCollectionDisplay")) do
		if platform:IsDescendantOf(workspace) and self:ownerOf(platform) == userId then return platform end
	end
	return nil
end
function Stations:clearDisplay(userId)
	local shown = self.displays[userId]
	if not shown then return end
	for _, model in ipairs(shown.models) do model:Destroy() end
	self.displays[userId] = nil
end
local function topOf(part)
	local up, size = part.CFrame:VectorToObjectSpace(Vector3.yAxis), part.Size
	return part.Position.Y + 0.5 * (math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z)
end
function Stations:refreshDisplay(player)
	local deps = self.deps
	local platform = self:platformOf(player.UserId)
	local picks = platform and deps.Bases.displayPicks(deps.snapshot(player.UserId), Stations.DISPLAY_SLOTS) or {}
	local parts = { platform and platform:GetFullName() or "" }
	for _, pick in ipairs(picks) do table.insert(parts, pick.uid .. ":" .. pick.species) end
	local key = table.concat(parts, "|")
	local shown = self.displays[player.UserId]
	if shown and shown.key == key then return end
	self:clearDisplay(player.UserId)
	if not platform or #picks == 0 then return end
	local hub = platform:FindFirstAncestor("WildboundHub")
	local centre = hub and hub:GetPivot().Position or platform.Position
	local models = {}
	for index, pick in ipairs(picks) do
		local slot = platform.Parent:FindFirstChild("DisplaySlot" .. index)
		if slot and slot:IsA("BasePart") then
			local model, dressed = deps.visual(pick.species, slot.Position)
			model.Name = "DisplayLumipol"
			model:ScaleTo(0.6)
			local at = Vector3.new(slot.Position.X, topOf(slot) + (dressed and 1.2 or 0.75) + Stations.HOVER, slot.Position.Z)
			local frame = CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z))
			model:PivotTo(frame)
			model:SetAttribute("OwnerUserId", player.UserId)
			model:SetAttribute("Uid", pick.uid)
			model:SetAttribute("Spot", 10 * (platform:GetAttribute("SlotIndex") or 0) + index)
			model:SetAttribute("Base", frame)
			table.insert(models, model)
		end
	end
	self.displays[player.UserId] = { key = key, models = models }
end
function Stations:refreshAll()
	for _, player in ipairs(Players:GetPlayers()) do self:refreshDisplay(player) end
end

-- HF-T3 (HB6): where a new character starts: just above the hub spawn pad of the player's base slot
-- (Bases.spawnIndex), facing west (-X, toward the forest gate, EV-W5), or nil when the hub has no pads (the camp is the fallback).
function Stations:spawnFrame(player)
	local pads = {}
	for _, pad in ipairs(CollectionService:GetTagged("WildboundHubSpawnPad")) do
		local index = pad:GetAttribute("SpawnIndex")
		if pad:IsA("BasePart") and pad:IsDescendantOf(workspace) and type(index) == "number" then pads[index] = pad end
	end
	local pad = pads[self.deps.Bases.spawnIndex(player:GetAttribute("WildboundBaseSlot"), #pads) or 0]
	if not pad then return nil end
	local at = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0)
	return CFrame.lookAt(at, at - Vector3.xAxis)
end

function Stations:start()
	for tag in pairs(Stations.TAGS) do
		for _, station in ipairs(CollectionService:GetTagged(tag)) do self:bind(station, tag) end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(station) self:bind(station, tag) end)
	end
	-- A base that gets or loses its owner moves that owner's display (the hub script writes OwnerUserId).
	local function watch(model)
		model:GetAttributeChangedSignal("OwnerUserId"):Connect(function() self:refreshAll() end)
	end
	for _, model in ipairs(CollectionService:GetTagged("WildboundBaseSlot")) do watch(model) end
	CollectionService:GetInstanceAddedSignal("WildboundBaseSlot"):Connect(watch)
	Players.PlayerRemoving:Connect(function(player) self:clearDisplay(player.UserId) end)
	return self
end

return Stations
