-- Pure fair-strike rules (M4.2 to M4.7). Inputs by value, clock injected, no services.
-- See docs/mechanics/wildbound-fair-strike.md, decisions D2 and D6. The world script measures the
-- server gates (guardian, binding, geometry) and passes them in; this module owns the ledger, the gate
-- order, acknowledgement binding, the K budget, dwell, the mark and every counter.
local FairStrike = {}

-- Hypotheses from the decision record. All can change after measurement.
FairStrike.CONSTANTS = table.freeze({
	K = 2, -- free cancels per life for a missing readiness report or acknowledgement
	ACK_SECONDS = 1.0, -- an acknowledgement must arrive within this long after issue
	LIVENESS_SECONDS = 3, -- a FieldPulse this recent means the client is alive on the network
	DWELL_SECONDS = 3.0, -- time inside the dwell radius before a warning can lead to a strike
	DWELL_MAX_RADIUS = 64,
	WARNING_LEAD = 0.8, -- the warning must have been sent at least this long before impact (chase pass: was 1.2)
	STALL_SECONDS = 0.5, -- a gap between gameplay steps longer than this marks the attack stalled
	MAX_ID_BYTES = 64,
	CLOSED_MEMORY = 8, -- closed attack ids kept only to classify a stale acknowledgement
	MARKED_HEALTH = 35,
	REST_SECONDS = 5,
})
local C = FairStrike.CONSTANTS

-- Every counter the document names. "cancel.duplicate" counts a second resolution of an attack that
-- was already counted, so it stays outside the identity below.
local COUNTERS = table.freeze({
	"attack.issued", "attack.cancelledEarly", "strike.executed", "shadow.wouldStrike", "strike.unacked",
	"cancel.duplicate", "cancel.stall", "cancel.guardian", "cancel.binding", "cancel.geometry", "cancel.dwell",
	"cancel.warning", "cancel.notReady", "cancel.ackMissing", "cancel.ackLate", "cancel.noLiveness",
	"ack.forged", "ack.wrongOwner", "ack.duplicate", "ack.priorLife", "ack.late",
	"flagMisconfigured", "effect.failed", "ambush.moved", "ambush.skipped",
})
FairStrike.COUNTERS = COUNTERS
local RESOLVED_CANCELS = table.freeze({ "cancel.stall", "cancel.guardian", "cancel.binding", "cancel.geometry",
	"cancel.dwell", "cancel.warning", "cancel.notReady", "cancel.ackMissing", "cancel.ackLate", "cancel.noLiveness" })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Damage is real only when the flag says "private" and this exact place is listed. Anything else is
-- off; a "private" flag that does not apply here is reported as misconfigured. Streaming never matters.
function FairStrike.effectiveMode(flags, placeId)
	if type(flags) ~= "table" or flags.damageMode ~= "private" then
		return "off", type(flags) == "table" and flags.damageMode ~= nil and flags.damageMode ~= "off"
	end
	local list = flags.privateTestPlaceIds
	if type(list) ~= "table" or not finite(placeId) then return "off", true end
	for _, id in ipairs(list) do
		if id == placeId then return "private", false end
	end
	return "off", true
end

-- Delivery C, decision D-C3: nobody can be killed before their first paid trip home. progress = { registered,
-- banked, ember } from the inventory script: one registered creature, any banked material or any Ember makes a
-- player lethal. Anything unreadable reads as not yet lethal.
function FairStrike.lethal(progress)
	if type(progress) ~= "table" then return false end
	for _, key in ipairs({ "registered", "banked", "ember" }) do
		local value = progress[key]
		if finite(value) and value > 0 then return true end
	end
	return false
end

-- The mode one strike resolves in: a spared player only ever gets shadow strikes, with no mark and no damage.
function FairStrike.strikeMode(damageMode, lethal)
	return damageMode == "private" and lethal == true and "private" or "off"
end

-- min(StreamingMinRadius, 64). An unreadable or impossible radius returns nil, and the adapter then
-- treats every player as outside it, so the dwell gate fails closed.
function FairStrike.dwellRadius(minRadius)
	if not finite(minRadius) or minRadius <= 0 then return nil end
	return math.min(minRadius, C.DWELL_MAX_RADIUS)
end

function FairStrike.new()
	local counters = {}
	for _, key in ipairs(COUNTERS) do counters[key] = 0 end
	return { counters = counters, lives = {}, attack = nil, closed = {}, serial = 0, lastStepAt = nil }
end

function FairStrike.count(state, key)
	if type(state) == "table" and type(state.counters) == "table" and state.counters[key] ~= nil then
		state.counters[key] += 1
	end
end

-- issued == executed + shadow + every resolved cancel + early cancels.
function FairStrike.identityHolds(counters)
	local sum = counters["strike.executed"] + counters["shadow.wouldStrike"] + counters["attack.cancelledEarly"]
	for _, key in ipairs(RESOLVED_CANCELS) do sum += counters[key] end
	return sum == counters["attack.issued"]
end

-- The record for this player's current life. A different character starts a fresh record, so marks,
-- K, dwell and readiness never carry over to a new life (FS-24).
function FairStrike.lifeRecord(state, userId, life)
	local record = state.lives[userId]
	if not record or record.life ~= life then
		record = { life = life, marks = 0, kUsed = 0, nearSince = nil, lastPulseAt = -math.huge,
			clientReady = false, restSince = nil }
		state.lives[userId] = record
	end
	return record
end

function FairStrike.forgetPlayer(state, userId)
	state.lives[userId] = nil
end

-- One gameplay step for one player: inside the radius keeps or starts the timer, outside clears it.
function FairStrike.dwellStep(state, userId, life, inside, now)
	local record = FairStrike.lifeRecord(state, userId, life)
	if inside == true and finite(now) then
		if record.nearSince == nil then record.nearSince = now end
	else
		record.nearSince = nil
	end
end

function FairStrike.dwellOk(state, userId, life, now)
	local record = state.lives[userId]
	if not record or record.life ~= life or record.nearSince == nil or not finite(now) then return false end
	return now - record.nearSince >= C.DWELL_SECONDS
end

-- An ambush relocation restarts every dwell timer.
function FairStrike.clearDwell(state)
	for _, record in pairs(state.lives) do record.nearSince = nil end
end

function FairStrike.pulse(state, userId, life, now)
	if not finite(now) then return end
	FairStrike.lifeRecord(state, userId, life).lastPulseAt = now
end

-- Client-reported and bounded: both parts must be true, and readiness only moves from false to true.
function FairStrike.ready(state, userId, life, persistentLoaded, assetsLoaded)
	local record = FairStrike.lifeRecord(state, userId, life)
	if record.clientReady then return false end
	if persistentLoaded ~= true or assetsLoaded ~= true then return false end
	record.clientReady = true
	return true
end

local function close(state, attack, reason)
	attack.resolved = true
	if state.attack == attack then state.attack = nil end
	table.insert(state.closed, { attackId = attack.attackId, userId = attack.userId, reason = reason })
	while #state.closed > C.CLOSED_MEMORY do table.remove(state.closed, 1) end
end

-- Closes the open attack before any effect: chase limit, lost target, character change, guardian
-- replacement or disconnect. Returns the closed attack so the adapter can tell its target.
function FairStrike.cancelEarly(state, reason)
	local attack = state.attack
	if not attack then return nil end
	FairStrike.count(state, "attack.cancelledEarly")
	close(state, attack, reason)
	return attack
end

-- input = { userId, life, guardianGeneration, now, endsAt, dwellOk, salt? }. One attack at a time.
function FairStrike.issue(state, input)
	if state.attack then FairStrike.cancelEarly(state, "replaced") end
	state.serial += 1
	local salt = type(input.salt) == "string" and input.salt:sub(1, 24) or ""
	local attack = { attackId = ("atk:%s:%d"):format(salt, state.serial), userId = input.userId, life = input.life,
		guardianGeneration = input.guardianGeneration, issuedAt = input.now, endsAt = input.endsAt,
		ackDeadline = input.now + C.ACK_SECONDS, warnSentAt = nil, ackedAt = nil, lateAt = nil,
		dwellOkAtWarn = input.dwellOk == true, stalled = false, resolved = false }
	state.attack = attack
	FairStrike.count(state, "attack.issued")
	return attack
end

function FairStrike.warned(state, attackId, now)
	local attack = state.attack
	if attack and attack.attackId == attackId and finite(now) then attack.warnSentAt = now end
end

-- Called once per gameplay step. A gap longer than STALL_SECONDS marks the open attack stalled.
function FairStrike.noteStep(state, now)
	if not finite(now) then return end
	local attack = state.attack
	if attack and state.lastStepAt and now - state.lastStepAt > C.STALL_SECONDS then attack.stalled = true end
	state.lastStepAt = now
end

-- AttackAck from one player. extra is the number of arguments after the id. Returns the outcome name;
-- nothing here ever helps a strike land except an on-time acknowledgement of the sender's own attack.
function FairStrike.acknowledge(state, senderId, senderLife, attackId, extra, now)
	if extra ~= 0 or type(attackId) ~= "string" or #attackId == 0 or #attackId > C.MAX_ID_BYTES or not finite(now) then
		FairStrike.count(state, "ack.forged")
		return "forged"
	end
	local attack = state.attack
	if attack and attack.attackId == attackId then
		if senderId ~= attack.userId then
			FairStrike.count(state, "ack.wrongOwner")
			return "wrongOwner"
		end
		if senderLife ~= attack.life then
			FairStrike.count(state, "ack.priorLife")
			return "priorLife"
		end
		if attack.ackedAt ~= nil or attack.lateAt ~= nil then
			FairStrike.count(state, "ack.duplicate")
			return "duplicate"
		end
		if now > attack.ackDeadline then
			attack.lateAt = now
			FairStrike.count(state, "ack.late")
			return "late"
		end
		attack.ackedAt = now
		return "accepted"
	end
	for _, closed in ipairs(state.closed) do
		if closed.attackId == attackId then
			if senderId ~= closed.userId then
				FairStrike.count(state, "ack.wrongOwner")
				return "wrongOwner"
			end
			if closed.reason == "lifeChanged" then
				FairStrike.count(state, "ack.priorLife")
				return "priorLife"
			end
			if closed.reason == "guardian" then
				FairStrike.count(state, "ack.forged")
				return "forged"
			end
			FairStrike.count(state, "ack.late")
			return "late"
		end
	end
	FairStrike.count(state, "ack.forged")
	return "forged"
end

local function cancel(state, counter)
	FairStrike.count(state, counter)
	return { outcome = "cancel", counter = counter }
end

-- Gates 8 and 9 share one budget. A single attack spends at most one K, and only after every
-- server-measured gate has passed (FS-25).
local function clientGates(state, attack, record, now)
	local ready = record ~= nil and record.clientReady == true
	local acked = attack.ackedAt ~= nil and attack.ackedAt <= attack.ackDeadline
	if ready and acked then return nil, false end
	local counter = not ready and "cancel.notReady" or (attack.lateAt and "cancel.ackLate" or "cancel.ackMissing")
	if record and record.kUsed < C.K then
		record.kUsed += 1
		return counter, false
	end
	if record and now - record.lastPulseAt <= C.LIVENESS_SECONDS then
		FairStrike.count(state, "strike.unacked")
		return nil, true
	end
	return "cancel.noLiveness", false
end

-- Runs once at impact, in the document's order; the first failure stops. gates = { guardian, binding,
-- geometry } are measured by the adapter. mode is the effective damage mode. Returns { outcome =
-- "strike" | "shadow" | "cancel", counter?, effect? = "Marked" | "Defeated", unacked? }.
function FairStrike.resolve(state, attack, gates, now, mode)
	if type(attack) ~= "table" or attack.resolved then return cancel(state, "cancel.duplicate") end
	close(state, attack, "resolved")
	gates = type(gates) == "table" and gates or {}
	if attack.stalled then return cancel(state, "cancel.stall") end
	if gates.guardian ~= true then return cancel(state, "cancel.guardian") end
	if gates.binding ~= true then return cancel(state, "cancel.binding") end
	if gates.geometry ~= true then return cancel(state, "cancel.geometry") end
	if not attack.dwellOkAtWarn then return cancel(state, "cancel.dwell") end
	if not finite(now) or attack.warnSentAt == nil or now - attack.warnSentAt < C.WARNING_LEAD then
		return cancel(state, "cancel.warning")
	end
	local record = state.lives[attack.userId]
	if record and record.life ~= attack.life then record = nil end
	local failed, unacked = clientGates(state, attack, record, now)
	if failed then return cancel(state, failed) end
	if mode ~= "private" or not record then
		FairStrike.count(state, "shadow.wouldStrike")
		return { outcome = "shadow", unacked = unacked }
	end
	FairStrike.count(state, "strike.executed")
	record.marks += 1
	record.restSince = nil
	return { outcome = "strike", unacked = unacked, effect = record.marks >= 2 and "Defeated" or "Marked" }
end

-- One gameplay step for a marked player. "pin" holds health at MARKED_HEALTH; five continuous seconds
-- in a safe zone clear the mark. Unmarked players are untouched ("none").
function FairStrike.restStep(state, userId, life, safe, now)
	local record = state.lives[userId]
	if not record or record.life ~= life or record.marks <= 0 or not finite(now) then return "none" end
	if safe ~= true then
		record.restSince = nil
		return "pin"
	end
	if record.restSince == nil then record.restSince = now end
	if now - record.restSince >= C.REST_SECONDS then
		record.marks, record.restSince = 0, nil
		return "cleared"
	end
	return "pin"
end

-- Sliding-window limiter: at most limit arrivals within window seconds; excess is dropped.
function FairStrike.allow(bucket, now, limit, window)
	if type(bucket) ~= "table" or not finite(now) then return false end
	local index = 1
	while bucket[index] do
		if bucket[index] < now - window then table.remove(bucket, index) else index += 1 end
	end
	if #bucket >= limit then return false end
	table.insert(bucket, now)
	return true
end

-- The words for a landed first strike, as the full sentence and a short form for a phone panel (found in W6:
-- the long one was cut after its first sentence, so the dropped item and its 30 s never showed). D-C5: words is an
-- optional table (WildboundText.STRIKE) for Spanish; without it the English below stays, so older contracts hold.
function FairStrike.strikeNotice(effect, dropped, words)
	if type(words) == "table" then
		if effect == "Defeated" then return words.defeated, words.defeated end
		local name = type(dropped) == "table" and (dropped.kind == "Egg" and words.egg or words.creature) or nil
		local full = words.marked .. (name and words.dropped:format(name) or "") .. words.rest
		return full, name and words.shortDropped:format(name) or words.shortMarked
	end
	if effect == "Defeated" then return "Silueta defeated you.", "Silueta defeated you." end
	local name = type(dropped) == "table" and (dropped.kind == "Egg" and "Lumipol egg" or "Lumipol") or nil
	local full = "Silueta marked you! Next hit defeats you. "
		.. (name and ("Dropped: %s. Grab it within 30 s. "):format(name) or "") .. "Rest at camp or shelter to clear the mark."
	local short = name and ("Marked! Grab your dropped %s within 30 s."):format(name)
		or "Marked! Next hit defeats you. Rest at camp."
	return full, short
end

return FairStrike
