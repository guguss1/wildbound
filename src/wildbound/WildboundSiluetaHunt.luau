-- Pure Hunt selection and last-seen policy. Inputs are server-validated observations.
local Hunt = {}
local EPSILON = 1e-7

function Hunt.new(target, now)
	return { id = target.id, life = target.life, lastPosition = target.position,
		lastVisibleAt = now, nextScanAt = now, switchedAt = -math.huge }
end

function Hunt.shouldScan(state, now)
	return now + EPSILON >= state.nextScanAt
end

-- memory: optional seconds a quarry out of sight is still hunted at its last position (chase pass: the world passes
-- the phase's memorySeconds); anything that is not a positive finite number reads as the original 1.5 s.
function Hunt.step(state, now, current, candidates, memory)
	if type(memory) ~= "number" or memory ~= memory or memory <= 0 or memory == math.huge then memory = 1.5 end
	local output = { id = state.id, life = state.life, switched = false, scanned = false,
		expired = false, canAttack = false }
	if not current or not current.valid or current.id ~= state.id or current.life ~= state.life then
		output.expired = true
		return output
	end
	if not current.visible then
		state.challengerId, state.challengerLife, state.challengerSince = nil, nil, nil
		output.expired = now - state.lastVisibleAt >= memory
		if not output.expired then output.destination = state.lastPosition end
		return output
	end
	state.lastPosition, state.lastVisibleAt = current.position, now
	output.destination, output.canAttack = current.position, true
	if not Hunt.shouldScan(state, now) then return output end
	state.nextScanAt = now + 0.4
	output.scanned = true
	local best
	for _, challenger in ipairs(candidates) do
		if challenger.valid and challenger.visible and challenger.id ~= state.id
			and current.distance - challenger.distance >= 4
			and challenger.distance <= current.distance * 0.8
			and (not best or challenger.distance < best.distance
				or (challenger.distance == best.distance and challenger.id < best.id)) then
			best = challenger
		end
	end
	if not best then
		state.challengerId, state.challengerLife, state.challengerSince = nil, nil, nil
		return output
	end
	if state.challengerId ~= best.id or state.challengerLife ~= best.life then
		state.challengerId, state.challengerLife, state.challengerSince = best.id, best.life, now
	end
	if now - state.challengerSince + EPSILON >= 0.6 and now - state.switchedAt + EPSILON >= 1 then
		state.id, state.life, state.lastPosition, state.lastVisibleAt = best.id, best.life, best.position, now
		state.switchedAt = now
		state.challengerId, state.challengerLife, state.challengerSince = nil, nil, nil
		output.id, output.life, output.destination, output.switched = best.id, best.life, best.position, true
	end
	return output
end

return Hunt
