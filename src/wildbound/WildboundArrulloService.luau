-- Arrullo wiring (decision Q2b, docs/mechanics/wildbound-new-mechanics.md section 1). Server only: deploy in
-- ServerScriptService. The pure WildboundArrullo owns the rules; this module owns one session per player, simulates it
-- on the server's clock every Heartbeat (Arrullo.advance: 1/30 s substeps, at most 0.5 s of catch-up), sends the view
-- to that player only at about VIEW_RATE a second, and takes only "hold" or "release" from that player's client
-- (Arrullo.input: at most 20 a second, anything else refused). The inventory server decides what a win or a loss does
-- (onEnd): a win steals the egg through the normal path, a loss works like a failed capture ring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Arrullo = require(ReplicatedStorage:WaitForChild("WildboundArrullo"))

local Service = {}
Service.Arrullo = Arrullo
Service.REMOTE = "Arrullo" -- a RemoteEvent in WildboundNetwork: views to the owner, "hold" / "release" from it
Service.VIEW_RATE = 10

-- D10 (open, pending owner confirmation): which eggs open the Arrullo instead of the steal hold. The overview's D10
-- names Épica, Legendaria and the biome event's egg ("Evento"); the rule also has a Rara row, which stays unused until
-- the owner decides. This is the only list: change it here.
Service.EGGS = table.freeze({ "Epica", "Legendaria", "Evento" })

-- AR (user, 2026-11-15; odd/tasks/wildbound-caramelo-v2.md): the minigame is off for now and returns later, improved.
-- While off no egg qualifies, so Épica, Legendaria and the event egg take the plain steal hold (EggCarry.holdFor).
-- The rule, this session code, the remote and the client stay as they are; set true to bring it back.
Service.ENABLED = false

local sessions = {} -- Player -> { session, onEnd, valid, nextViewAt }
local remote = nil

function Service.qualifies(rarity, special)
	if not Service.ENABLED then return false end
	for _, name in ipairs(Service.EGGS) do
		if name == "Evento" then
			if special == true then return true end
		elseif name == rarity then
			return true
		end
	end
	return false
end

function Service.active(player)
	return sessions[player] ~= nil
end

local function fire(player, payload)
	if remote and player.Parent == Players then remote:FireClient(player, payload) end
end

local function viewOf(item, kind)
	local view = Arrullo.view(item.session.state)
	view.kind = kind
	view.rarity = item.session.state.rarity
	return view
end

-- Ends a session once: tells the client to close and runs the owner's callback with "won", "lost" or "cancelled" and
-- the rule's reason ("Calm", "Empty", "Timeout"), "TooFar" (walked away) or the cancel's ("Gone").
local function finish(player, status, reason)
	local item = sessions[player]
	if not item then return end
	sessions[player] = nil
	local view = viewOf(item, "close")
	view.status, view.reason = status, reason
	fire(player, view)
	local ok, message = pcall(item.onEnd, status, reason)
	if not ok then warn("WildboundArrullo: the ending failed: " .. tostring(message)) end
end

-- options = { rarity, special, now, seed, valid = fn() -> true (go on), "far" (a loss: the thief walked away) or false
-- (cancelled: the egg or the thief is gone),
-- onEnd = fn(status, reason) }. The rarity row is the egg's own tier; an event egg with a tier the rule has no row for
-- uses Legendaria (the event egg is a Legendaria one). Returns true, or false and a reason.
function Service.begin(player, options)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false, "Invalid" end
	if sessions[player] then return false, "Busy" end
	if type(options) ~= "table" or type(options.onEnd) ~= "function" or type(options.valid) ~= "function" then
		return false, "Invalid"
	end
	local rarity = options.rarity
	if Arrullo.live.RARITIES[rarity] == nil and options.special == true then rarity = "Legendaria" end
	local session, reason = Arrullo.session(rarity, Random.new(options.seed), options.now)
	if not session then return false, reason end
	local item = { session = session, onEnd = options.onEnd, valid = options.valid, nextViewAt = options.now }
	sessions[player] = item
	fire(player, viewOf(item, "open"))
	return true
end

-- The player left, died or the egg is gone: no win, no penalty.
function Service.cancel(player)
	finish(player, "cancelled", "Gone")
end

function Service.step(now)
	for player, item in pairs(sessions) do
		local valid = player.Parent == Players
		local far = false
		if valid then
			local ok, result = pcall(item.valid)
			far = ok and result == "far"
			valid = ok and result == true
		end
		if far then
			-- Walking out of the egg's reach ends it as a loss (the rule's own reasons are Empty and Timeout).
			finish(player, "lost", "TooFar")
		elseif not valid then
			finish(player, "cancelled", "Gone")
		else
			local out = Arrullo.advance(item.session, now)
			if out.status == "won" or out.status == "lost" then
				finish(player, out.status, item.session.state.reason)
			elseif now >= item.nextViewAt then
				item.nextViewAt = now + 1 / Service.VIEW_RATE
				fire(player, viewOf(item, "view"))
			end
		end
	end
end

-- network: the WildboundNetwork folder. Creates the remote once and starts the step.
function Service.start(network)
	if remote then return remote end
	remote = Instance.new("RemoteEvent")
	remote.Name = Service.REMOTE
	remote.OnServerEvent:Connect(function(player, value, ...)
		if select("#", ...) > 0 then return end
		local item = sessions[player]
		if not item then return end
		Arrullo.input(item.session, value, workspace:GetServerTimeNow())
	end)
	remote.Parent = network
	RunService.Heartbeat:Connect(function()
		Service.step(workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	return remote
end

return Service