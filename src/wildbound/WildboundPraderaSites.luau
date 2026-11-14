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
Sites.HOME = table.freeze({ NubeGrunona = "pond", AbejaReina = "colmena" })

-- The sector origin: the given pivot ({x, z} or a Vector3-like with X/Z) when finite, else the Meadow centre.
function Sites.origin(pivot)
	if type(pivot) == "table" and finite(pivot.x) and finite(pivot.z) then return { x = pivot.x, z = pivot.z } end
	if typeof(pivot) == "Vector3" then return { x = pivot.X, z = pivot.Z } end
	return { x = Sites.MEADOW_CENTRE.x, z = Sites.MEADOW_CENTRE.z }
end

-- One site in world coordinates ({x, z}), or nil for an unknown key.
function Sites.world(origin, key)
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
	return ctx.eventOpen == true and distance <= T.WakeRadiusStuds
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
