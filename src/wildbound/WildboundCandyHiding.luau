-- Caramelo v5 (odd/tasks/wildbound-caramelo-v2.md, V5-D2): the candy creatures respect hiding. Server only and pure: no
-- services, no clock (the callers pass `now`), no random. A player hidden in a hide spot (WildboundWorld's
-- WildboundHidden attribute) is never acquired: a candy brain is stepped with a VIEW of that player instead of the real
-- one (Hiding.view), chosen by Hiding.plan:
--   none    not hidden, or not a candy creature: the real target.
--   far     a calm creature (patrolling, resting, walking home): the player stands FAR_STUDS beyond its home, out of every
--           sight, guard ring and wake radius, so it never notices them (a calm critter whose visitor "walked away" goes
--           home by its own escape rule).
--   search  a creature that hunts them (any engaged phase, also one the frenzy's call just woke): it lost them and
--           searches round the spot: the view walks a ring of points round where they hid (SEARCH), a new point every
--           holdSeconds, lifted liftStuds over the floor so no strike there ever reaches anyone. The beast server ends
--           the search after SEARCH.seconds (the creature gives up, reason "Lost").
--   under   Don Glaseon (BOSSES), who has his own Search phase: the view stands where the player is, UNDER_STUDS under the
--           floor and silent, so he loses sight of them, walks to where he last saw them, searches and goes home ("Lost").
-- A creature finds a hidden player only by standing within WildboundHide's discover radius for its dwell time
-- (Hiding.finds is WildboundHide.discover in the "Search" mode: the same numbers as La Silueta's, tuned in one place).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local ServerScriptService = DataModel:GetService("ServerScriptService")
local Hide = require(ServerScriptService:WaitForChild("WildboundHide"))
local Smarts = require(ServerScriptService:WaitForChild("WildboundCandySmarts"))
local Hiding = {}

Hiding.Hide = Hide
Hiding.SEARCH = table.freeze({
	seconds = 15, -- a hunter searches this long round the spot, then gives up
	-- the search points lie this far from the spot. V5-D6 (Play 2026-11-17): 3..11 let five frenzied hunters stand in the
	-- 4-stud discover radius within a second or two, so hiding never held; 7..14 keeps them round it, passing near now
	-- and then.
	ringMin = 7, ringMax = 14,
	holdSeconds = 2.5, -- each search point is kept this long, then the next
	liftStuds = 40, -- the search point's height over the hidden player: every strike aimed there misses
})
-- V5-D6: a candy creature needs FIND_SLOWER times WildboundHide's dwell inside the radius to find a hidden player (its
-- clock runs at 1 / FIND_SLOWER: with the Day rule, 4 s instead of 2 s), so a frenzy's crowd does not find them at once.
Hiding.FIND_SLOWER = 2
Hiding.FAR_STUDS = 4000
Hiding.UNDER_STUDS = 60
Hiding.BOSSES = table.freeze({ DonGlaseon = true })
-- The phases in which a creature is not hunting (WildboundCandySmarts' QUIET, plus Don Glaseon's Dormant).
Hiding.QUIET = table.freeze({ Spawn = true, Calm = true, Patrol = true, Return = true, GiveUp = true, Disengage = true,
	Ended = true, Dormant = true, LoseTarget = true })

-- V5-D6: each next search point turns STEP round the spot (the golden angle, 137 degrees, sent the hunters across the
-- spot on every move, through the discover radius); at 55 degrees the walk between two points stays outside it.
local STEP = math.rad(55)
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

-- Whether a WildboundHidden attribute value means hidden (WildboundWorld sets the spot id, and nil on the way out).
function Hiding.hidden(value)
	return value ~= nil and value ~= false and value ~= ""
end

-- Whether a beast is a candy creature (the brains of WildboundCandySmarts' PROFILES).
function Hiding.candy(beast)
	return type(beast) == "string" and Smarts.PROFILES[beast] ~= nil
end

-- Whether a creature is hunting (any phase but the quiet ones).
function Hiding.engaged(e)
	return type(e) == "table" and e.phase ~= nil and not Hiding.QUIET[e.phase]
end

-- "none", "far", "search" or "under" for creature e (its beast `beast`) and a target that is `hidden`.
function Hiding.plan(e, hidden, beast)
	if hidden ~= true or not Hiding.candy(beast) then return "none" end
	if Hiding.BOSSES[beast] then return "under" end
	if Hiding.engaged(e) then return "search" end
	return "far"
end

-- A search round (x, z) from `now`; `seed` (any value, e.g. the encounter id) turns where it starts, so two hunters
-- search different sides.
function Hiding.newSearch(x, z, now, seed)
	local text, turn = tostring(seed), 0
	for i = 1, #text do turn = (turn * 31 + string.byte(text, i)) % 9973 end
	return { x = x, z = z, startAt = finite(now) and now or 0, untilAt = (finite(now) and now or 0) + Hiding.SEARCH.seconds,
		turn = turn / 9973 * 2 * math.pi }
end

-- The search point now: point i = floor(time / holdSeconds), STEP further round the spot, at a radius between ringMin and
-- ringMax. Returns x, z.
function Hiding.searchPoint(s, now)
	local S = Hiding.SEARCH
	local i = math.max(0, math.floor(((finite(now) and now or s.startAt) - s.startAt) / S.holdSeconds))
	local angle = s.turn + i * STEP
	local radius = S.ringMin + (S.ringMax - S.ringMin) * (((i + 1) * 0.618034) % 1)
	return s.x + math.cos(angle) * radius, s.z + math.sin(angle) * radius
end

function Hiding.expired(s, now)
	return type(s) ~= "table" or not finite(now) or now >= s.untilAt
end

-- The target a candy brain is stepped with (a copy; the real target is never changed). plan from Hiding.plan; e the
-- creature (its home for "far"); s the search for "search".
function Hiding.view(target, plan, e, s, now)
	if plan == "none" or type(target) ~= "table" then return target end
	local v = table.clone(target)
	v.vx, v.vz, v.hidden = 0, 0, true
	if plan == "far" then
		local home = type(e) == "table" and (e.home or e.pos) or nil
		v.x = (home and home.x or target.x) + Hiding.FAR_STUDS
		v.z = home and home.z or target.z
	elseif plan == "search" and type(s) == "table" then
		v.x, v.z = Hiding.searchPoint(s, now)
		v.y = (finite(target.y) and target.y or 0) + Hiding.SEARCH.liftStuds
	elseif plan == "under" then
		v.y = (finite(target.y) and target.y or 0) - Hiding.UNDER_STUDS
	end
	return v
end

-- Discovery: a watch per creature and hidden player (WildboundHide's dwell state).
function Hiding.newWatch()
	return Hide.newDwell()
end

-- Whether a creature `distance` studs (flat) from the hidden player finds them this step (dt seconds), by WildboundHide's
-- rule in the "Search" mode for the place's `phase` (nil: Day, the candy kingdom's), its clock slowed by FIND_SLOWER.
function Hiding.finds(watch, dt, distance, phase)
	local slowed = type(dt) == "number" and dt / Hiding.FIND_SLOWER or dt
	return Hide.discover(watch, { dt = slowed, mode = "Search", distance = distance, phase = phase or "Day" }) == true
end

return Hiding
