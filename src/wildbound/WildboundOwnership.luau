-- Tags what the world script creates so a separate guard script can remove exactly that when the world script
-- is destroyed. Measured in W9 Play: when a Script is destroyed, every connection it made is dead, including its
-- own Destroying handler and its Heartbeat loop, so no cleanup written inside it can run. The guard lives in
-- another Script and sweeps by tag. `service` is CollectionService (or a fake in contracts).
local Ownership = {}

Ownership.TAG = "WildboundWorldOwned"

-- Tags one instance and returns it, so creation can stay one expression. Anything else is ignored.
function Ownership.claim(service, instance)
	if typeof(instance) == "Instance" or (type(instance) == "table" and instance.IsFakeInstance == true) then
		service:AddTag(instance, Ownership.TAG)
	end
	return instance
end

-- Destroys every tagged instance, once each. One that fails to destroy does not stop the others.
-- Returns how many destroy calls ran.
function Ownership.sweep(service)
	local count = 0
	for _, instance in ipairs(service:GetTagged(Ownership.TAG)) do
		local ok = pcall(function() instance:Destroy() end)
		if ok then count += 1 end
	end
	return count
end

return Ownership
