-- Kids biome (odd/tasks/wildbound-kids-beasts.md): the Pradera's sites and the presence rules of its two summoned
-- beasts, La Nube Gruñona (docs/design/wildbound-biome-pradera.md s5) and La Abeja Reina (s6). Server only and pure:
-- no services, no clock, no random. The beast script passes the sector origin (Workspace "WildboundPradera":GetPivot(),
-- read-only, or nil), the player's server state and the server's event attribute; this module only answers.
-- Sector offsets come from the Pradera planner (PROPUESTA): pond (150, 0; 150, 40 since GT), La Colmena (-75, 75), the gate (-186, 0),
-- the Plaza del Molino (-40, 14). Without the map the origin is the Meadow square's centre (WildboundBiomes, 612, -3).
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
local Sites = {}

local finite = Config.finite

Sites.MEADOW_CENTRE = table.freeze({ x = 612, z = -3 })
Sites.OFFSETS = table.freeze({
	pond = table.freeze({ x = 150, z = 40 }), -- GT (cake move): was (150, 0); 40 studs north, off the bigger boss ground
	colmena = table.freeze({ x = -75, z = 75 }),
	gate = table.freeze({ x = -186, z = 0 }),
	plaza = table.freeze({ x = -40, z = 14 }),
})
-- Which site each summoned beast lives at.
Sites.HOME = table.freeze({ NubeGrunona = "pond", AbejaReina = "colmena", Gomibu = "candyNest", Flanfuria = "candyNestR1",
	Tortidragon = "candyNestC3", DonGlaseon = "bossHome", Mochimiau = "candyNestR2", Canelin = "candyNestR3", Flanin = "candyNestR4",
	Mielita = "candyNestC4", GatoRepartidor = "candyNestC2" })
-- Caramelo biome: sites given in world coordinates, which never move with the sector origin. candyNest is the open
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
Sites.FIXED = table.freeze({ candyNest = table.freeze({ x = 446, z = -15 }), candyNestR1 = table.freeze({ x = 542, z = -41 }),
	candyNestC3 = table.freeze({ x = 510, z = -143 }), bossHome = table.freeze({ x = 676, z = -3 }),
	bossTerritory = table.freeze({ x = 726, z = -3 }),
	candyNestC2 = table.freeze({ x = 466, z = 34 }), candyNestR2 = table.freeze({ x = 539, z = 43 }),
	candyNestR3 = table.freeze({ x = 579, z = -86 }), candyNestR4 = table.freeze({ x = 678, z = 163 }),
	candyNestC4 = table.freeze({ x = 542, z = 139 }),
	-- CH1 (extra posts, below): open floor 8 to 15 studs from a new candy nest, between the nest and its route
	candyPostC7 = table.freeze({ x = 624, z = 130 }), candyPostR6 = table.freeze({ x = 715, z = -120 }),
	candyPostC8 = table.freeze({ x = 667, z = -161 }), candyPostC9 = table.freeze({ x = 488, z = -61 }),
	candyPostR7 = table.freeze({ x = 486, z = 63 }), candyPostR5 = table.freeze({ x = 708, z = 119 }),
	candyPostC6 = table.freeze({ x = 612, z = -157 }), candyPostC10 = table.freeze({ x = 564, z = -157 }),
	-- GT2 (more creatures): one more extra post per candy creature, 12 studs from one of the eight GT2 nests
	candyPostE3 = table.freeze({ x = 600, z = 33 }), candyPostR8 = table.freeze({ x = 514, z = 92 }),
	candyPostR9 = table.freeze({ x = 564, z = 67 }), candyPostR10 = table.freeze({ x = 608, z = -59 }),
	candyPostC11 = table.freeze({ x = 582, z = 135 }), candyPostC12 = table.freeze({ x = 494, z = -103 }),
	candyPostC13 = table.freeze({ x = 700, z = -152 }), candyPostR11 = table.freeze({ x = 639, z = 79 }) })
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
})

-- CH4 (owner request 2026-11-16, "more creatures that appear in a random way"): ambushes. Every everySeconds a player
-- inside the Caramelo plot (half studs round the Meadow centre) wins a roll with `chance`: a random candy critter
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
	half = 200, edgeStuds = 10, entrance = table.freeze({ x = -200, z = 0 }), entranceStuds = 30, entranceSpotStuds = 80,
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
	if math.max(math.abs(lx), math.abs(lz)) > A.half then return nil end
	if Config.flat(lx, lz, A.entrance.x, A.entrance.z) < A.entranceStuds then return nil end
	local name = A.names[math.clamp(math.floor(kindRoll * #A.names) + 1, 1, #A.names)]
	local far = math.max(A.minStuds, math.min(A.maxStuds, Config.BEASTS[name].tuning.PerceptionStuds - 2))
	local distance = A.minStuds + math.clamp(distanceRoll, 0, 1) * (far - A.minStuds)
	local angle = math.clamp(angleRoll, 0, 1) * 2 * math.pi
	local sx, sz = lx + math.cos(angle) * distance, lz + math.sin(angle) * distance
	if A.half - math.max(math.abs(sx), math.abs(sz)) < A.edgeStuds then return nil end
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
function Sites.world(origin, key)
	local fixed = Sites.FIXED[key]
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
	if name ~= "DonGlaseon" and Sites.FIXED[key] then
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
