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

-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D1; docs/design/wildbound-caramelo-v3-plan.md V6-D10..): tall
-- licorice grass (WildboundCandyGrass lays the patches: Models tagged GRASS.tag, pivot on the floor at the patch's centre,
-- attribute GRASS.radiusAttribute = its footprint radius). A player standing in a patch who is not sprinting
-- (WildboundStance ~= "sprint"; the game has no crouch) is COVERED. A candy creature farther than GRASS.seeStuds from a
-- covered player does not see them (CONCEALED); within it, or when they sprint, it sees them as normal. Which patch a
-- player stands in is worked out on the server from positions (Hiding.inGrass), never from the client.
--   a calm creature: the v5 "far" view (it never notices them);
--   a hunter: it keeps tracking them for GRASS.memorySeconds of concealment (the usual memory), then loses them like a
--   hidden player: the v5 search round where it lost them ("search", or "under" for Don Glaseon), and gives up after
--   SEARCH.seconds. There is no discovery dwell in the grass: a searcher that comes within seeStuds simply sees them.
Hiding.GRASS = table.freeze({
	tag = "WildboundCandyGrass",
	radiusAttribute = "Radius",
	seeStuds = 10, -- V6-D1: a covered player is seen only this close
	memorySeconds = 3, -- V6-D10: a hunter loses a concealed player after this long (the "usual memory time")
	sprint = "sprint", -- the WildboundStance value that gives a player away
})

-- The patches { { x, z, r } } (world) of a list of grass instances (CollectionService:GetTagged(GRASS.tag)): each
-- Model's pivot and its radius attribute. Anything else, or a patch without a usable radius, is skipped.
function Hiding.grassPatches(list)
	local out = {}
	for _, item in ipairs(type(list) == "table" and list or {}) do
		if typeof(item) == "Instance" and item:IsA("Model") then
			local r = item:GetAttribute(Hiding.GRASS.radiusAttribute)
			local p = item:GetPivot().Position
			if finite(r) and r > 0 and finite(p.X) and finite(p.Z) then table.insert(out, { x = p.X, z = p.Z, r = r }) end
		end
	end
	return out
end

-- The patch whose footprint holds (x, z) (flat), or nil. patches = { { x, z, r } } in the same coordinates.
function Hiding.inGrass(patches, x, z)
	if type(patches) ~= "table" or not (finite(x) and finite(z)) then return nil end
	for _, patch in ipairs(patches) do
		if math.sqrt((patch.x - x) ^ 2 + (patch.z - z) ^ 2) <= patch.r then return patch end
	end
	return nil
end

-- Whether a player in the grass (`inGrass` truthy) with this WildboundStance is covered: anything but a sprint.
function Hiding.covered(inGrass, stance)
	return inGrass ~= nil and inGrass ~= false and stance ~= Hiding.GRASS.sprint
end

-- Whether a creature `distance` studs (flat) away does NOT see a player (inGrass, stance): covered and farther than
-- GRASS.seeStuds. An unknown distance counts as far.
function Hiding.concealed(distance, inGrass, stance)
	if not Hiding.covered(inGrass, stance) then return false end
	return not finite(distance) or distance > Hiding.GRASS.seeStuds
end

-- The plan for creature e (its beast `beast`) and a player who is `concealed` now (Hiding.concealed): "none" (it sees
-- them), or Hiding.plan's "far", "search" or "under". memo is a table kept per creature and player (memo.since: when a
-- hunter's concealment began); now is the caller's clock. A hunter keeps the real target for GRASS.memorySeconds.
function Hiding.grassPlan(e, concealed, beast, memo, now)
	memo = type(memo) == "table" and memo or {}
	if concealed ~= true or not Hiding.candy(beast) then
		memo.since = nil
		return "none"
	end
	if Hiding.engaged(e) then
		local t = finite(now) and now or 0
		memo.since = memo.since or t
		if t - memo.since < Hiding.GRASS.memorySeconds - 1e-9 then return "none" end
	else
		memo.since = nil
	end
	return Hiding.plan(e, true, beast)
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
