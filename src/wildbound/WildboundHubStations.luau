-- Nest Heist hub (docs/maps/wildbound-hub.md section 5, HB-T3 to HB-T5): the personal bases' station prompts, server
-- only. Every station the hub builder tagged gets one prompt; a trigger is answered only for that base's owner (the
-- OwnerUserId the hub script wrote on the base model) standing within the station's Range, measured here from the
-- server's own position of the player (WildboundBases.mayUse). The client sends nothing but the prompt trigger. The
-- inventory server passes its own rules as handlers, so the base stations reuse the camp's code paths.
local CollectionService = game:GetService("CollectionService")

local Stations = {}
Stations.__index = Stations

-- Tag -> station kind; a kind names a handler, a prompt key (Keys.HUB) and the words below.
Stations.TAGS = table.freeze({
	["WildboundDeliveryStation"] = "delivery",
})
-- text: the prompt's action (Text.HUB key); action: the reply that carries a refusal; hold: seconds (nil = default).
local PROMPTS = table.freeze({
	delivery = table.freeze({ text = "deliveryPrompt", action = "Extract" }),
})

-- deps = { Bases, Text, Keys, prompt(target, action, object, range, hold, input), rootOf(player), alive(player),
-- allowed(player, action), refuse(player, action, reason), handlers = { [kind] = function(player, distance, station) } }
function Stations.new(deps)
	return setmetatable({ deps = deps, bound = {} }, Stations)
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

function Stations:start()
	for tag in pairs(Stations.TAGS) do
		for _, station in ipairs(CollectionService:GetTagged(tag)) do self:bind(station, tag) end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(station) self:bind(station, tag) end)
	end
	return self
end

return Stations
