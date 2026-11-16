-- Kids biome (odd/tasks/wildbound-kids-beasts.md): the Pradera's sites and the presence rules of its two summoned
-- beasts, La Nube Gruñona (docs/design/wildbound-biome-pradera.md s5) and La Abeja Reina (s6). Server only and pure:
-- no services, no clock, no random. The beast script passes the sector origin (Workspace "WildboundPradera":GetPivot(),
-- read-only, or nil), the player's server state and the server's event attribute; this module only answers.
-- Sector offsets come from the Pradera planner (PROPUESTA): pond (150, 0), La Colmena (-75, 75), the gate (-186, 0),
-- the Plaza del Molino (-40, 14). Without the map the origin is the Meadow square's centre (WildboundBiomes, 612, -3).
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
local Sites = {}

local finite = Config.finite

Sites.MEADOW_CENTRE = table.freeze({ x = 612, z = -3 })
Sites.OFFSETS = table.freeze({
	pond = table.freeze({ x = 150, z = 0 }),
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
-- CA3: bossHome is the Candy builder's BossHome marker (578, -3), where Don Glaseon sleeps; bossTerritory is the centre
-- of its Boss.BossTerritory marker (612, -3, radius Config.BEASTS.DonGlaseon.tuning.TerritoryRadiusStuds = 62).
-- CC4 (odd/tasks/wildbound-candy-critters.md): the five small candy creatures' posts, open floor 13 to 15 studs from a free
-- nest on the side away from the routes: candyNestC2 (Gato Repartidor, the friendly one near the entrance), candyNestR2
-- (Mochimiau), candyNestR3 (Canelin), candyNestR4 (Flanin) and candyNestC4 (Mielita, beside La Abeja's hive).
-- candyNestR2 sits 86 studs from the boss territory centre: its leash, leap circle and push (14 + 4 + 5) stay off the
-- 62-stud boss ground, so Mochimiau never shoves a player into Don Glaseon's territory.
Sites.FIXED = table.freeze({ candyNest = table.freeze({ x = 446, z = -15 }), candyNestR1 = table.freeze({ x = 542, z = -41 }),
	candyNestC3 = table.freeze({ x = 510, z = -143 }), bossHome = table.freeze({ x = 578, z = -3 }),
	bossTerritory = table.freeze({ x = 612, z = -3 }),
	candyNestC2 = table.freeze({ x = 466, z = 34 }), candyNestR2 = table.freeze({ x = 539, z = 43 }),
	candyNestR3 = table.freeze({ x = 664, z = -101 }), candyNestR4 = table.freeze({ x = 664, z = 71 }),
	candyNestC4 = table.freeze({ x = 542, z = 139 }) })

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
function Sites.wants(name, ctx)
	if type(ctx) ~= "table" or ctx.alive ~= true or ctx.safe == true or ctx.meadow ~= true then return false end
	if not finite(ctx.x) or not finite(ctx.z) then return false end
	local key = Sites.HOME[name]
	if not key then return false end
	local site = Sites.world(ctx.origin, key)
	local distance = Config.flat(ctx.x, ctx.z, site.x, site.z)
	local T = Config.BEASTS[name].tuning
	if name == "NubeGrunona" then
		return distance <= (ctx.night == true and T.NightWakeRadiusStuds or T.WakeRadiusStuds)
	end
	-- Caramelo biome: every beast at a fixed post (the candy guardians and critters) wakes within its WakeRadiusStuds.
	if name ~= "DonGlaseon" and Sites.FIXED[key] then return distance <= T.WakeRadiusStuds end
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
