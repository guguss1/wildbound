-- Esquiva perfecta wiring (decision Q3b, docs/mechanics/wildbound-new-mechanics.md section 2). Server only: deploy in
-- ServerScriptService. One WildboundDodge state per player, shared by every server script that requires this module
-- (the inventory server for the parents' close swing, the press and the speed; the world server for La Silueta's
-- strike; the beast script may register Viper's dash and Pouncer's leap the same way). The rules stay in the pure
-- WildboundDodge; this module only keeps the states and mirrors what the owner's HUD needs as player attributes:
--   WildboundDodgeStrike: the server time the latest dodgeable attack aimed at this player lands (the "¡Esquiva!" cue);
--   WildboundDodgeReady: when the next press is accepted (the button counts down);
--   WildboundDodgeBoost: when the last perfect dodge's boost ends (the clients play the scuff when it moves on).
-- No invulnerability: only the attacks whose window held the press are cancelled, and each script asks resolve()
-- before applying its own hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Dodge = require(ReplicatedStorage:WaitForChild("WildboundDodge"))

local Service = {}
Service.Dodge = Dodge

local states = {} -- Player -> WildboundDodge state

local function valid(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

local function stateOf(player)
	local state = states[player]
	if not state then
		state = Dodge.new()
		states[player] = state
	end
	return state
end

-- A dodgeable attack aimed at `player` starts its telegraph now (startAt) and lands at strikeAt (server times).
-- source: "Parent", "Viper", "Pouncer" or "Silueta". Returns true, or false and Dodge.telegraph's reason (a telegraph
-- under 0.8 s is refused, so it simply cannot be dodged).
function Service.telegraph(player, id, source, startAt, strikeAt)
	if not valid(player) then return false, "Invalid" end
	local ok, reason = Dodge.telegraph(stateOf(player), id, source, startAt, strikeAt)
	if ok then player:SetAttribute("WildboundDodgeStrike", strikeAt) end
	return ok, reason
end

-- Asked when the attack would land: "Dodged" (skip the hit), "Hit" or "Unknown". Once per attack.
function Service.resolve(player, id, now)
	local state = states[player]
	if not state then return "Unknown" end
	return Dodge.resolve(state, id, now)
end

-- An attack that ended without a strike.
function Service.cancel(player, id)
	local state = states[player]
	return state ~= nil and Dodge.cancel(state, id)
end

-- The player's "dodge". blocked: hidden, capturing, ragdolled or dead. Returns Dodge.press's verdict and its detail.
function Service.press(player, now, blocked)
	if not valid(player) then return "Invalid" end
	local state = stateOf(player)
	local verdict, detail = Dodge.press(state, now, { blocked = blocked == true })
	if verdict == "Perfect" or verdict == "Early" or verdict == "Late" or verdict == "Whiff" then
		player:SetAttribute("WildboundDodgeReady", state.cooldownUntil)
		player:SetAttribute("WildboundDash", now)
	elseif verdict == "Spam" then
		player:SetAttribute("WildboundDodgeReady", math.max(state.cooldownUntil, state.lockedUntil))
	end
	if verdict == "Perfect" then player:SetAttribute("WildboundDodgeBoost", state.boostUntil) end
	return verdict, detail
end

function Service.boosting(player, now)
	local state = states[player]
	return state ~= nil and Dodge.boosting(state, now)
end

function Service.invulnerable(player, now)
	local state = states[player]
	return state ~= nil and Dodge.invulnerable(state, now)
end

-- The walk speed with a running boost (x1.35 of the given speed, capped at 26, never slower).
function Service.speed(player, base, now)
	local state = states[player]
	if not state then return base end
	return Dodge.speed(state, base, now)
end

-- Drops the attacks nobody resolved (Heartbeat).
function Service.prune(now)
	for player, state in pairs(states) do
		if player.Parent ~= Players then
			states[player] = nil
		else
			Dodge.prune(state, now)
		end
	end
end

function Service.forget(player)
	states[player] = nil
end

return Service