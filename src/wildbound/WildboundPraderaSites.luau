-- Kids biome (odd/tasks/wildbound-kids-beasts.md): the Pradera's sites and the presence rules of its two summoned
-- beasts, La Nube Gruñona (docs/design/wildbound-biome-pradera.md s5) and La Abeja Reina (s6). Server only and pure:
-- no services, no clock, no random. The beast script passes the sector origin (Workspace "WildboundPradera":GetPivot(),
-- read-only, or nil), the player's server state and the server's event attribute; this module only answers.
-- Sector offsets come from the Pradera planner (PROPUESTA): pond (150, 0; 150, 40 since GT), La Colmena (-75, 75), the gate (-186, 0),
-- the Plaza del Molino (-40, 14). Without the map the origin is the Meadow square's centre (WildboundBiomes, 612, -3).
-- V8-D1: the offsets are x 1.3 now and the default origin is the v8 candy plot's centre (672, -3); see below.
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
-- PGM-D1 (owner request 2026-11-18, "Sí, movelo"): the kitten park's frame (EAST_FIXED below), shared and pure
local Area = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundGatitoArea"))
local Sites = {}

local finite = Config.finite

-- Caramelo v8 (owner request 2026-11-17, "make the Reino Caramelo map a bit bigger, in width and in length, so there is
-- more space between things"; docs/design/wildbound-caramelo-v8-plan.md, V8-D1): the candy plot grows 1.3 times about
-- its centre, which moves (612, -3) -> (672, -3) with the entrance fixed. MEADOW_CENTRE is a copy of
-- WildboundCandyLayout.CENTRE (WildboundCandyNests_Test pins it).
Sites.MEADOW_CENTRE = table.freeze({ x = 672, z = -3 })
-- V8-D1: the sector offsets scale with the plot (v7 x 1.3), so with the WildboundPradera marker moved by
-- WildboundCandyLayout.fromV7World (v7 pivot (627, 107) -> (691.5, 140)) the pond and the hive land exactly on the
-- layout's KEEP_CLEAR spots again (local (214.5, 195) and (-78, 240.5)). Kept as fixed they could not both: the hive
-- would stand inside mountain M1. v7: pond (150, 40), colmena (-75, 75), gate (-186, 0), plaza (-40, 14).
Sites.OFFSETS = table.freeze({
	pond = table.freeze({ x = 195, z = 52 }), -- GT (cake move): (150, 0) -> (150, 40), off the bigger boss ground
	colmena = table.freeze({ x = -97.5, z = 97.5 }),
	gate = table.freeze({ x = -241.8, z = 0 }),
	plaza = table.freeze({ x = -52, z = 18.2 }),
})
-- Which site each summoned beast lives at.
Sites.HOME = table.freeze({ NubeGrunona = "pond", AbejaReina = "colmena", Gomibu = "candyNest", Flanfuria = "candyNestR1",
	Tortidragon = "candyNestC3", DonGlaseon = "bossHome", Mochimiau = "candyNestR2", Canelin = "candyNestR3", Flanin = "candyNestR4",
	Mielita = "candyNestC4", GatoRepartidor = "candyNestC2",
	-- K-D7 (Pueblo Gatito, docs/design/wildbound-kitten-park-plan.md; owner request 2026-11-17, "un parque verde lindo con
	-- las criaturas gatitas ... también tiene que haber huevos para robar"): the four kittens' home posts (EAST_FIXED)
	GatitoGuerrero = "kittenPostK1", GatitaBouquet = "kittenPostK2", GatitoActually = "kittenPostK3",
	GatitoLanudo = "kittenPostK4" })
-- Caramelo biome: sites given in world coordinates, which never move with the sector origin (the world numbers in this
-- paragraph are the v7 ones; V8-D1 below moves each post with its nest). candyNest is the open
-- floor beside candy nest C1 (the nest itself is at 452, -21), the first one past the biome entrance: Gomibu's post.
-- candyNestR1 is open floor 11 studs from candy nest R1 (534, -33), away from the main path: Flanfuria's post.
-- candyNestC3 is open floor about 14 studs from candy nest C3 (522, -135), the furthest point from the routes that keeps
-- the 35-stud leash on the plot and off the boss ground: Tortidragon's post.
-- CA3: bossHome is the Candy builder's BossHome marker (676, -3), where Don Glaseon sleeps; bossTerritory is the centre
-- of its Boss.BossTerritory marker (726, -3, radius Config.BEASTS.DonGlaseon.tuning.TerritoryRadiusStuds = 76). GT (cake
-- move, 2026-11-16): both moved with the Gran Torta to the east end (were 578 and 612, radius 62); candyNestR3 (was
-- 664, -101) and candyPostC8 (was 744, -83) moved beside their moved nests R3 and C8; candyNestR4 (was 664, 71, the key
-- name kept) is Flanin's post beside nest C5 now.
-- CC4 (odd/tasks/wildbound-candy-critters.md): the five small candy creatures' posts, open floor 13 to 15 studs from a free
-- nest on the side away from the routes: candyNestC2 (Gato Repartidor, the friendly one near the entrance), candyNestR2
-- (Mochimiau), candyNestR3 (Canelin), candyNestR4 (Flanin) and candyNestC4 (Mielita, beside La Abeja's hive).
-- candyNestR2 sits 86 studs from the boss territory centre: its leash, leap circle and push (14 + 4 + 5) stay off the
-- 62-stud boss ground, so Mochimiau never shoves a player into Don Glaseon's territory.
-- V8-D1: every post moves with its paired nest and keeps its v7 offset from it (the 8-16 stud spacing), so each row
-- below is beside(the nest's v7 plot spot as in WildboundCandyLayout.NESTS, the v7 offset): world = MEADOW_CENTRE +
-- 1.3 x nest + offset. One exception: candyPostR10 (see there). Don Glaseon's two are CENTRE + BOSS.home and CENTRE +
-- BOSS (the layout's Torta at 1.3 x 114 = 148.2, home 50 studs west of it): (770.2, -3) and (820.2, -3).
local V8_S = 1.3
local function beside(nestX, nestZ, dx, dz)
	return table.freeze({ x = Sites.MEADOW_CENTRE.x + nestX * V8_S + dx, z = Sites.MEADOW_CENTRE.z + nestZ * V8_S + dz })
end
-- CL-D11 (Caramelo v9, owner request 2026-11-18, "agranda mas el bioma caramelo a lo largo";
-- docs/design/wildbound-caramelo-v9-plan.md): a post beside a nest written in v9 plot-local literals (no 1.3 scaling,
-- as WildboundCandyLayout's nestAt): world = MEADOW_CENTRE + (nest + offset). The posts of the four nests the chocolate
-- channel swallowed (C6, C8, C10, C13) moved with them, and the third round of extra posts uses it.
-- CL-D9: Don Glaseon's two moved +600 with the Gran Torta: CENTRE + BOSS.home (698.2, 0) and CENTRE + BOSS (748.2, 0).
local function besideLocal(lx, lz, dx, dz)
	return table.freeze({ x = Sites.MEADOW_CENTRE.x + (lx + dx), z = Sites.MEADOW_CENTRE.z + (lz + dz) })
end
Sites.FIXED = table.freeze({ candyNest = beside(-160, -18, -6, 6) --[[C1, v7 (446, -15)]],
	candyNestR1 = beside(-78, -30, 8, -8) --[[R1, v7 (542, -41)]],
	candyNestC3 = beside(-90, -132, -12, -8) --[[C3, v7 (510, -143)]],
	bossHome = table.freeze({ x = 1370.2, z = -3 }), -- CL-D9: v8 (770.2, -3), v7 (676, -3)
	bossTerritory = table.freeze({ x = 1420.2, z = -3 }), -- CL-D9: v8 (820.2, -3), v7 (726, -3)
	candyNestC2 = beside(-140, 24, -6, 13) --[[C2, v7 (466, 34)]], candyNestR2 = beside(-78, 34, 5, 12) --[[R2, v7 (539, 43)]],
	candyNestR3 = beside(-45, -93, 12, 10) --[[R3, v7 (579, -86)]], candyNestR4 = beside(60, 152, 6, 14) --[[C5, v7 (678, 163)]],
	candyNestC4 = beside(-62, 130, -8, 12) --[[C4, v7 (542, 139)]],
	-- CH1 (extra posts, below): open floor 8 to 15 studs from a new candy nest, between the nest and its route
	candyPostC7 = beside(5, 142, 7, -9) --[[v7 (624, 130)]], candyPostR6 = beside(96, -122, 7, 5) --[[v7 (715, -120)]],
	candyPostC8 = besideLocal(105, -183, -8, 9) --[[CL-D11: (769, -177), was v8 beside(60, -170, -5, 12)]],
	candyPostC9 = beside(-135, -62, 11, 4) --[[v7 (488, -61)]],
	candyPostR7 = beside(-116, 58, -10, 8) --[[v7 (486, 63)]], candyPostR5 = beside(88, 112, 8, 10) --[[v7 (708, 119)]],
	candyPostC6 = besideLocal(55, -168, 0, 12) --[[CL-D11: (727, -159), was v8 beside(10, -162, -10, 8)]],
	candyPostC10 = besideLocal(-52, -167, 12, 8) --[[CL-D11: (632, -162), was v8 beside(-60, -162, 12, 8)]],
	-- GT2 (more creatures): one more extra post per candy creature, 12 studs from one of the eight GT2 nests
	candyPostE3 = beside(0, 36, -12, 0) --[[v7 (600, 33)]], candyPostR8 = beside(-110, 95, 12, 0) --[[v7 (514, 92)]],
	candyPostR9 = beside(-60, 70, 12, 0) --[[v7 (564, 67)]],
	-- V8-D1: the scaled nest R10 stands 47 studs from the left route's last leg, past Mochimiau's 45-stud wake radius,
	-- so its v7 offset (6, -11) is turned to 12 studs towards that leg, (9, 8): 35 studs from it, 12 off the river.
	candyPostR10 = beside(-10, -45, 9, 8) --[[v7 (608, -59)]],
	candyPostC11 = beside(-30, 150, 0, -12) --[[v7 (582, 135)]], candyPostC12 = beside(-130, -100, 12, 0) --[[v7 (494, -103)]],
	candyPostC13 = besideLocal(35, 190, 10, 8) --[[CL-D11: (717, 195), was v8 beside(100, -150, -12, 1)]],
	candyPostR11 = beside(36, 74, -9, 8) --[[v7 (639, 79)]],
	-- CL-D11: the third round of extra posts, beside v9 nests in the grown east (plot-local nest, then the offset)
	candyPostE4 = besideLocal(560, -40, 0, 12) --[[(1232, -31)]], candyPostR16 = besideLocal(600, -80, 0, -12) --[[(1272, -95)]],
	candyPostE5 = besideLocal(580, 40, 0, -12) --[[(1252, 25)]], candyPostR12 = besideLocal(280, -80, 12, 0) --[[(964, -83)]],
	candyPostC16 = besideLocal(530, -170, 0, 12) --[[(1202, -161)]], candyPostR13 = besideLocal(280, 80, 12, 0) --[[(964, 77)]],
	candyPostC18 = besideLocal(700, -215, -12, 0) --[[(1360, -218)]], candyPostR15 = besideLocal(410, 150, -12, 0) --[[(1070, 147)]] })
-- CH1 (owner request 2026-11-16: "more repeated creatures in the Caramelo kingdom ... make it harder to be in that
-- biome"): one more copy of each candy creature at an extra post, so a player crossing the biome meets twice as many
-- (8 -> 16 posts). Each extra post is its own encounter (Director post), summoned by the same wake rule as a home post
-- (Sites.wants with the post), rests on its own and leashes to it. Unlike the home posts, an extra post stands by a
-- route on purpose (off the path, inside its wake radius), never near the hub entrance, off Don Glaseon's ground. The
-- three guardians' extra posts guard the new nests C7, R6 and C8 (WildboundCandyNests.posts binds "<name>@<post>").
Sites.EXTRA_POSTS = table.freeze({
	table.freeze({ name = "Gomibu", key = "candyPostC7" }), table.freeze({ name = "Flanfuria", key = "candyPostR6" }),
	table.freeze({ name = "Tortidragon", key = "candyPostC8" }), table.freeze({ name = "Mochimiau", key = "candyPostC9" }),
	table.freeze({ name = "Canelin", key = "candyPostR7" }), table.freeze({ name = "GatoRepartidor", key = "candyPostR5" }),
	table.freeze({ name = "Mielita", key = "candyPostC6" }), table.freeze({ name = "Flanin", key = "candyPostC10" }),
	-- GT2 (owner request 2026-11-16, "more eggs and more creatures, a livelier map"): a second extra post per creature
	-- (16 -> 24 posts), the same rules; the guardians' guard the new nests E3, R8 and R9.
	table.freeze({ name = "Gomibu", key = "candyPostE3" }), table.freeze({ name = "Flanfuria", key = "candyPostR8" }),
	table.freeze({ name = "Tortidragon", key = "candyPostR9" }), table.freeze({ name = "Mochimiau", key = "candyPostR10" }),
	table.freeze({ name = "Canelin", key = "candyPostC11" }), table.freeze({ name = "GatoRepartidor", key = "candyPostR11" }),
	table.freeze({ name = "Mielita", key = "candyPostC13" }), table.freeze({ name = "Flanin", key = "candyPostC12" }),
	-- CL-D11 (Caramelo v9, owner request 2026-11-18, "agranda mas el bioma caramelo a lo largo"): a third extra post per
	-- creature for the longer kingdom (EXTRA_POSTS 16 -> 24 rows, 32 posts with the 8 home posts), the same rules; the
	-- guardians' guard the v9 nests E4, R16 and E5 (12 guarded nests).
	table.freeze({ name = "Gomibu", key = "candyPostE4" }), table.freeze({ name = "Flanfuria", key = "candyPostR16" }),
	table.freeze({ name = "Tortidragon", key = "candyPostE5" }), table.freeze({ name = "Mochimiau", key = "candyPostR12" }),
	table.freeze({ name = "Canelin", key = "candyPostC16" }), table.freeze({ name = "GatoRepartidor", key = "candyPostR13" }),
	table.freeze({ name = "Mielita", key = "candyPostC18" }), table.freeze({ name = "Flanin", key = "candyPostR15" }),
})

-- K-D7 (Pueblo Gatito, docs/design/wildbound-kitten-park-plan.md; owner request 2026-11-17, "es como el mundo de gatito:
-- un parque verde lindo con las criaturas gatitas ... también tiene que haber huevos para robar"): the eight kitten posts
-- of the park, in world coordinates (they never move with the sector origin), each 12 studs from its park nest K<n>
-- toward the nearest route, at least 85 from any other post (two wake circles of at most 42), park-local lx -170..150
-- and |lz| <= 108 (the suites allow up to lx 180, |lz| 180). PGM-D1, PGM-D4 (docs/design/wildbound-pueblo-gatito-move-plan.md; owner request 2026-11-18, "Sí,
-- movelo"): the park moved to the big4 south arm, so each post is written park-local (the K-D7 world value v converted
-- with Area.localOfV1: lx = x - 1208, lz = z + 3) and frozen at Area.world(lx, lz); they no longer face the cloud wall.
-- A hunt (zone 60 + 12) plus the attack's range and the push stays on the park floor (Area.rect(), x 22..542, z
-- 340..860): 25 studs inside its far end, 60 inside its two sides, and at most to its gate edge (K1: lx -170 - 90 = -260,
-- world z 340; Guerrero's 13-stud lane can reach 3 studs past it, onto the apron by the road to the hub, still the arm). Deliberately kept out of FIXED, which the plot's suites and
-- tools pin; Sites.world and Sites.wants read both. Keys are letters and digits only (an attribute name and a
-- "<name>@<post>" binding). Each row: local (was the K-D7 world value) -> world; the nest is 12 studs along local z.
local function parkPost(lx, lz)
	local x, z = Area.world(lx, lz)
	return table.freeze({ x = x, z = z })
end
Sites.EAST_FIXED = table.freeze({
	kittenPostK1 = parkPost(-170, -43), -- (1038, -46) -> (325, 430): GatitoGuerrero, home (nest K1 at 337, 430)
	kittenPostK2 = parkPost(-165, 107), -- (1043, 104) -> (175, 435): GatitaBouquet, home (nest K2 at 187, 435)
	kittenPostK3 = parkPost(-65, -50), -- (1143, -53) -> (332, 535): GatitoActually, home (nest K3 at 344, 535)
	kittenPostK4 = parkPost(-50, 58), -- (1158, 55) -> (224, 550): GatitoLanudo, home (nest K4 at 212, 550)
	kittenPostK5 = parkPost(20, -58), -- (1228, -61) -> (340, 620): GatitoGuerrero, extra (nest K5 at 352, 620)
	kittenPostK6 = parkPost(35, 63), -- (1243, 60) -> (219, 635): GatitaBouquet, extra (nest K6 at 207, 635)
	kittenPostK7 = parkPost(150, -108), -- (1358, -111) -> (390, 750): GatitoActually, extra (nest K7 at 402, 750)
	kittenPostK8 = parkPost(150, 108), -- (1358, 105) -> (174, 750): GatitoLanudo, extra (nest K8 at 162, 750)
})
-- K-D7, K-D11: one more copy of each kitten at an east extra post, summoned like the plot's EXTRA_POSTS (its own
-- encounter, Director post, its own rest); the beast server and the resting service walk this list after that one.
Sites.EAST_EXTRA_POSTS = table.freeze({
	table.freeze({ name = "GatitoGuerrero", key = "kittenPostK5" }), table.freeze({ name = "GatitaBouquet", key = "kittenPostK6" }),
	table.freeze({ name = "GatitoActually", key = "kittenPostK7" }), table.freeze({ name = "GatitoLanudo", key = "kittenPostK8" }),
})

-- CH4 (owner request 2026-11-16, "more creatures that appear in a random way"): ambushes. Every everySeconds a player
-- inside the Caramelo plot (CL-D11: local x -half..east, |z| <= half round the Meadow centre) wins a roll with `chance`: a random candy critter
-- (names) appears on the ground minStuds to maxStuds away (never past its own sight - 2, so it notices at once, with its
-- alert as the tell), through the director (post: one of a kind per player, its own rest), at most maxActive at once.
-- Never for a player within entranceStuds of the entrance, never at a spot within entranceSpotStuds of it (the hub
-- side), within edgeStuds of the plot edge or within bossClearStuds of Don Glaseon's territory centre (his territory,
-- plaza and tower, plus a critter's leash, attack and push). The beast server checks the ground (world.landing). Every
-- number here is the one tuning table.
Sites.AMBUSH = table.freeze({
	-- RC (relentless chases): every 20 -> 15 s, at most 2 -> 3 at once
	everySeconds = 15, chance = 0.75, maxActive = 3, tries = 4, minStuds = 25, maxStuds = 40, post = "ambush",
	names = table.freeze({ "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }),
	-- V8-D1: half and entrance are re-anchored to the bigger plot (WildboundCandyLayout.HALF 260 and ENTRANCE (-HALF, 0));
	-- every other number is a gameplay radius and stays
	half = 260, edgeStuds = 10, entrance = table.freeze({ x = -260, z = 0 }), entranceStuds = 30, entranceSpotStuds = 80,
	-- CL-D11 (Caramelo v9): the plot is the rectangle lx -half..east, |lz| <= half; east is a copy of
	-- WildboundCandyLayout.EAST (half now means the west half-length and the z half-length)
	east = 860,
	bossClearStuds = 126, -- GT (cake move): 112 -> 126, the 76-stud territory plus the same 50
})

-- V4-D9 (owner request 2026-11-17, "progressively, not all at once"): ambushes follow the chase ramp: at most
-- min(maxActive, the player's chaser cap now: WildboundCandySmarts.cap) ambush critters at once on a player (at least 1,
-- so an ambush can open the pressure). A missing or bad cap keeps maxActive.
function Sites.ambushCap(chaseCap)
	local A = Sites.AMBUSH
	if not finite(chaseCap) then return A.maxActive end
	return math.clamp(math.floor(chaseCap), 1, A.maxActive)
end

-- CH4: the kind and spot of one ambush on a player at world (x, z), from three rolls in 0..1 (the server's Random), or
-- nil when that player or that spot is not allowed. Returns name, { x, z } (world).
function Sites.ambushRoll(x, z, kindRoll, angleRoll, distanceRoll)
	local A = Sites.AMBUSH
	if not (finite(x) and finite(z) and finite(kindRoll) and finite(angleRoll) and finite(distanceRoll)) then return nil end
	local c = Sites.MEADOW_CENTRE
	local lx, lz = x - c.x, z - c.z
	if lx < -A.half or lx > A.east or math.abs(lz) > A.half then return nil end -- CL-D11: the v9 rectangle
	if Config.flat(lx, lz, A.entrance.x, A.entrance.z) < A.entranceStuds then return nil end
	local name = A.names[math.clamp(math.floor(kindRoll * #A.names) + 1, 1, #A.names)]
	local far = math.max(A.minStuds, math.min(A.maxStuds, Config.BEASTS[name].tuning.PerceptionStuds - 2))
	local distance = A.minStuds + math.clamp(distanceRoll, 0, 1) * (far - A.minStuds)
	local angle = math.clamp(angleRoll, 0, 1) * 2 * math.pi
	local sx, sz = lx + math.cos(angle) * distance, lz + math.sin(angle) * distance
	if math.min(sx + A.half, A.east - sx, A.half - math.abs(sz)) < A.edgeStuds then return nil end -- CL-D11: the rectangle
	if Config.flat(sx, sz, A.entrance.x, A.entrance.z) < A.entranceSpotStuds then return nil end
	local boss = Sites.FIXED.bossTerritory
	if Config.flat(sx + c.x, sz + c.z, boss.x, boss.z) < A.bossClearStuds then return nil end
	return name, { x = sx + c.x, z = sz + c.z }
end

-- The sector origin: the given pivot ({x, z} or a Vector3-like with X/Z) when finite, else the Meadow centre.
function Sites.origin(pivot)
	if type(pivot) == "table" and finite(pivot.x) and finite(pivot.z) then return { x = pivot.x, z = pivot.z } end
	if typeof(pivot) == "Vector3" then return { x = pivot.X, z = pivot.Z } end
	return { x = Sites.MEADOW_CENTRE.x, z = Sites.MEADOW_CENTRE.z }
end

-- One site in world coordinates ({x, z}), or nil for an unknown key.
-- K-D11: a kitten post (EAST_FIXED) is a fixed site too.
function Sites.world(origin, key)
	local fixed = Sites.FIXED[key] or Sites.EAST_FIXED[key]
	if fixed then return { x = fixed.x, z = fixed.z } end
	local offset = Sites.OFFSETS[key]
	if not offset then return nil end
	local o = Sites.origin(origin)
	return { x = o.x + offset.x, z = o.z + offset.z }
end

-- Whether the server should summon `name` for this player now. ctx = { alive, safe, meadow, night, eventOpen, x, z,
-- origin }. The director still applies every rule (budget slots, cooldowns, grace) after this.
-- CH1: post (optional) is an EXTRA_POSTS key: the same rule, measured from that post instead of the home post.
function Sites.wants(name, ctx, post)
	if type(ctx) ~= "table" or ctx.alive ~= true or ctx.safe == true or ctx.meadow ~= true then return false end
	if not finite(ctx.x) or not finite(ctx.z) then return false end
	local key = Sites.HOME[name] and (post or Sites.HOME[name])
	if not key then return false end
	local site = Sites.world(ctx.origin, key)
	local distance = Config.flat(ctx.x, ctx.z, site.x, site.z)
	local T = Config.BEASTS[name].tuning
	if name == "NubeGrunona" then
		return distance <= (ctx.night == true and T.NightWakeRadiusStuds or T.WakeRadiusStuds)
	end
	-- Caramelo biome: every beast at a fixed post (the candy guardians and critters) wakes within its WakeRadiusStuds.
	-- V4-D13: during a steal's frenzy (ctx.frenzy = { x, z, studs }: WildboundCandySmarts.frenzyAt) it also wakes when
	-- its post lies within studs of the robbed nest, so the frenzy's call reaches it.
	-- K-D11: the kittens' posts (EAST_FIXED) follow the same rule (ctx.meadow is then "in a summoning biome").
	if name ~= "DonGlaseon" and (Sites.FIXED[key] or Sites.EAST_FIXED[key]) then
		local f = ctx.frenzy
		if type(f) == "table" and finite(f.x) and finite(f.z) and finite(f.studs)
			and Config.flat(f.x, f.z, site.x, site.z) <= f.studs then
			return true
		end
		return distance <= T.WakeRadiusStuds
	end
	if name == "DonGlaseon" then
		local centre = Sites.world(ctx.origin, "bossTerritory")
		return Config.flat(ctx.x, ctx.z, centre.x, centre.z) <= T.TerritoryRadiusStuds
	end
	return ctx.eventOpen == true and distance <= T.WakeRadiusStuds
end

-- CA3: the one target Don Glaseon wakes for, among candidates { { userId, ctx } ... } (ctx as for Sites.wants, plus
-- rarity: the carried egg's tier or nil): only players it wants (inside its territory); a carrier of a Rara, Epica or
-- Legendaria egg first (the rarer the better), then the nearest to its home. Returns a userId or nil.
local RANK = { Rara = 1, Epica = 2, Legendaria = 3 }
function Sites.bossPick(candidates)
	local best, bestRank, bestDistance = nil, -1, math.huge
	for _, c in ipairs(type(candidates) == "table" and candidates or {}) do
		if type(c) == "table" and Sites.wants("DonGlaseon", c.ctx) then
			local home = Sites.world(c.ctx.origin, "bossHome")
			local rank, distance = RANK[c.ctx.rarity] or 0, Config.flat(c.ctx.x, c.ctx.z, home.x, home.z)
			if rank > bestRank or (rank == bestRank and distance < bestDistance) then
				best, bestRank, bestDistance = c.userId, rank, distance
			end
		end
	end
	return best
end

-- La Abeja's hearing: the noise radius of a player from the server's horizontal speed (studs/s) and whether the
-- humanoid is in the air (FloorMaterial Air). Still is silent; Night halves it.
function Sites.noiseRadius(speed, airborne, night)
	local T = Config.BEASTS.AbejaReina.tuning
	local radius
	if airborne == true then
		radius = T.NoiseAirStuds
	elseif not finite(speed) or speed < T.StillSpeedStuds then
		radius = 0
	elseif speed <= T.WalkSpeedLimitStuds then
		radius = T.NoiseWalkStuds
	else
		radius = T.NoiseRunStuds
	end
	return night == true and radius * T.NightNoiseScale or radius
end

-- The Abeja window: the server's BiomeEvent attribute (> 0 while the event clock's window is open), unless the
-- Studio-only override is set (true opens it, false closes it).
function Sites.eventOpen(attribute, override)
	if override == true then return true end
	if override == false then return false end
	return finite(attribute) and attribute > 0
end

return Sites
