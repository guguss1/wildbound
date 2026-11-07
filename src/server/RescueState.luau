-- Pure session state. The server supplies alive and measured distance values.
local RescueState = {}
RescueState.__index = RescueState

local CAPACITY = 3
local CAPTURE_DISTANCE = 10
local REFUGE_DISTANCE = 12
local BASE_SPEED = 16
local SPEED_PER_RESCUE = 2
local SPEED_RESCUE_CAP = 2

local function validContext(alive, distance, limit)
	return alive == true
		and type(distance) == "number"
		and distance == distance
		and distance >= 0
		and distance <= limit
end

function RescueState.new()
	return setmetatable({
		entries = {},
		knownIds = {},
		pendingCount = 0,
		totalRescued = 0,
	}, RescueState)
end

function RescueState:capture(id, alive, distance)
	if type(id) ~= "string" or id == "" then
		return false, "InvalidCreature"
	end
	if not validContext(alive, distance, CAPTURE_DISTANCE) then
		return false, "InvalidContext"
	end
	if self.knownIds[id] then
		return false, "AlreadyCollected"
	end
	if self.pendingCount >= CAPACITY then
		return false, "BackpackFull"
	end

	self.knownIds[id] = true
	table.insert(self.entries, { id = id, status = "Pending" })
	self.pendingCount += 1
	return true
end

function RescueState:deposit(alive, distance)
	if not validContext(alive, distance, REFUGE_DISTANCE) then
		return 0, "InvalidContext"
	end
	local count = self.pendingCount
	if count == 0 then
		return 0, "Empty"
	end

	for _, entry in ipairs(self.entries) do
		if entry.status == "Pending" then
			entry.status = "Rescued"
		end
	end
	self.pendingCount = 0
	self.totalRescued += count
	return count
end

function RescueState:snapshot()
	local entries = {}
	for _, entry in ipairs(self.entries) do
		table.insert(entries, { id = entry.id, status = entry.status })
	end
	return {
		entries = entries,
		pendingCount = self.pendingCount,
		totalRescued = self.totalRescued,
		walkSpeed = BASE_SPEED + math.min(self.totalRescued, SPEED_RESCUE_CAP) * SPEED_PER_RESCUE,
	}
end

return RescueState
