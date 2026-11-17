-- Caramelo v6, proposal 2: crumbling cookie bridges (odd/tasks/wildbound-caramelo-v2.md V6-D2;
-- docs/design/wildbound-caramelo-v3-plan.md V6-D20 on). The two long outer bridges (Top and Bottom in
-- WildboundCandyV3Layout.BRIDGES) are cookie: a player carrying an egg who is being hunted and stands on one's deck
-- cracks it (CRACK_SECONDS of cracks, crumbs and a sound), then the whole bridge drops into the chocolate for
-- DOWN_SECONDS and rebuilds once nobody stands in its footprint. The three junction bridges (RightLast, Main,
-- LeftLast) never break, so there is always a way across.
-- Pure rules for WildboundCandyCookieBridgeService: no services, no clock (time is passed in), no require. Plot
-- coordinates are local to Layout.CENTRE, like WildboundCandyV3Layout. Server only (ServerStorage).
-- Rules: WildboundCandyCookieBridge_Test.
local Cookie = {}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

Cookie.IDS = table.freeze({ "Top", "Bottom" })
Cookie.CRACK_SECONDS = 2
Cookie.DOWN_SECONDS = 45
-- V6-D20: "being hunted" = a candy creature or a bee swarm engaged this player within HUNT_WINDOW seconds (the
-- WildboundBeastEngagedAt stamp, written every 0.5 s while engaged, on workspace:GetServerTimeNow()), or La Silueta's
-- published threat level is one of THREAT_LEVELS (the return portal's own rule, WildboundPortal.SILUETA_LEVELS).
Cookie.HUNT_WINDOW = 3
Cookie.THREAT_LEVELS = table.freeze({ Near = true, Chase = true })
Cookie.FEET_SLACK = 1.5 -- feet this far under the deck's top still stand on it; a wader under it is 4 studs lower
Cookie.BLOCK_MARGIN = 1.5 -- a body's half width round the deck: anyone this close holds the rebuild back
Cookie.STEP = 0.1 -- seconds between two service steps (10 Hz)
-- The fall (the service's visuals): every part of the bridge sinks SINK studs in FALL_SECONDS while it fades, so the
-- deck (DeckY 4.1 over the floor) ends under the floor, out of sight in the chocolate.
Cookie.SINK = 7
Cookie.FALL_SECONDS = 1.2
Cookie.MODEL_PREFIX = "Bridge_" -- WildboundCandyV3Builder.layBridge: CaramelV3.Bridges.Bridge_<id>
Cookie.PHASE_ATTRIBUTE = "CookieBridgePhase" -- on the bridge model, for the client and for a Play check

local COOKIE = {}
for _, id in ipairs(Cookie.IDS) do COOKIE[id] = true end

function Cookie.isCookie(id)
	return type(id) == "string" and COOKIE[id] == true
end

-- hunted(info, now) -> whether the player is being hunted. info: { engagedAt, threatLevel }.
function Cookie.hunted(info, now)
	if type(info) ~= "table" then return false end
	if type(info.threatLevel) == "string" and Cookie.THREAT_LEVELS[info.threatLevel] then return true end
	if not finite(info.engagedAt) or not finite(now) then return false end
	local age = now - info.engagedAt
	return age >= -1 and age <= Cookie.HUNT_WINDOW
end

-- deckBridge(V3, x, z) -> the cookie bridge (a V3.BRIDGES row) whose deck holds the plot point, or nil. The deck
-- only: its end ramps and side ramps are not "crossing" it.
function Cookie.deckBridge(V3, x, z)
	if not finite(x) or not finite(z) then return nil end
	for _, B in ipairs(V3.BRIDGES) do
		if Cookie.isCookie(B.id) then
			local along, across = V3.bridgeFrame(B, x, z)
			if math.abs(along) <= B.length / 2 and math.abs(across) <= B.width / 2 then return B end
		end
	end
	return nil
end

-- triggers(V3, floorTop, info, now) -> the id of the cookie bridge this player cracks, or nil. info: { x, z (plot),
-- feetY (world), alive, carriesEgg, engagedAt, threatLevel }. Alive, carrying an egg, hunted, and standing on a cookie
-- deck (feet within FEET_SLACK of its top, so a wader under it does not count).
function Cookie.triggers(V3, floorTop, info, now)
	if type(info) ~= "table" or info.alive ~= true or info.carriesEgg ~= true then return nil end
	if not finite(info.feetY) or not finite(floorTop) then return nil end
	if not Cookie.hunted(info, now) then return nil end
	local B = Cookie.deckBridge(V3, info.x, info.z)
	if not B or info.feetY < floorTop + B.deck - Cookie.FEET_SLACK then return nil end
	return B.id
end

-- blocks(V3, id, x, z) -> whether a player at the plot point holds back cookie bridge id's rebuild: inside its deck's
-- footprint plus BLOCK_MARGIN, at any height (under a fallen deck is in the chocolate), so a rebuilt deck never
-- appears round anyone.
function Cookie.blocks(V3, id, x, z)
	if not Cookie.isCookie(id) or not finite(x) or not finite(z) then return false end
	for _, B in ipairs(V3.BRIDGES) do
		if B.id == id then
			local along, across = V3.bridgeFrame(B, x, z)
			return math.abs(along) <= B.length / 2 + Cookie.BLOCK_MARGIN and math.abs(across) <= B.width / 2 + Cookie.BLOCK_MARGIN
		end
	end
	return false
end

-- new(id) -> a bridge's state: Up.
function Cookie.new(id)
	return { id = id, phase = "Up", since = -math.huge }
end

-- step(st, now, triggered, blocked) -> "Crack", "Fall", "Rebuild" or nil. Up -> Cracking on a trigger (cookie bridges
-- only); Cracking -> Down after CRACK_SECONDS (whoever is on it then); Down -> Up after DOWN_SECONDS once not blocked.
-- A trigger while cracking or down changes nothing.
function Cookie.step(st, now, triggered, blocked)
	if type(st) ~= "table" or not finite(now) then return nil end
	if st.phase == "Up" then
		if triggered == true and Cookie.isCookie(st.id) then
			st.phase, st.since = "Cracking", now
			return "Crack"
		end
	elseif st.phase == "Cracking" then
		if now - st.since >= Cookie.CRACK_SECONDS - 1e-9 then
			st.phase, st.since = "Down", now
			return "Fall"
		end
	elseif st.phase == "Down" then
		if now - st.since >= Cookie.DOWN_SECONDS - 1e-9 and blocked ~= true then
			st.phase, st.since = "Up", now
			return "Rebuild"
		end
	end
	return nil
end

-- progress(st, now) -> 0..1 through the cracking (how many cracks show), 0 otherwise.
function Cookie.progress(st, now)
	if type(st) ~= "table" or st.phase ~= "Cracking" or not finite(now) then return 0 end
	return math.clamp((now - st.since) / Cookie.CRACK_SECONDS, 0, 1)
end

return table.freeze(Cookie)
