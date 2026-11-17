-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D5; V6-D40.. in docs/design/wildbound-caramelo-v3-plan.md): the
-- sticky caramel traps' rule. Server only and pure: no services, no requires, no clock (the callers pass `now`), no random.
-- WildboundCandyTraps lays the puddles: Models tagged TRAP.tag, pivot on the floor at the puddle's centre, attribute
-- TRAP.radiusAttribute = its footprint radius.
-- A candy creature on the ground (Rules.affects: a candy brain whose WildboundBeastConfig entry is `grounded`: the
-- critters but Mielita, who flies, and the ground bosses Gomibu, Flanfuria, Tortidragon and Don Glaseon) whose step
-- starts or ends inside a puddle is STUCK: it moves at TRAP.slow of its step while inside and for TRAP.afterSeconds after
-- its last step inside (Rules.stuck). The beast server applies it after each brain step (Rules.slowStep): the new spot
-- is pulled back along the step, so the creature covers TRAP.slow of the ground its brain asked for. The bees and
-- La Duquesa have their own services and never reach this rule; players are never slowed (nothing here touches a player).
-- A committed leap, roll or jump (COMMITTED phases: its path and strike are fixed by time) is not slowed, so the body
-- never falls behind its own strike; a step longer than TELEPORT_STUDS is a placement, not a walk, and is kept.
local Rules = {}

Rules.TRAP = table.freeze({
	tag = "WildboundCandyTrap",
	radiusAttribute = "Radius",
	slow = 0.4, -- V6-D5: 40 % speed
	afterSeconds = 2, -- V6-D5: and for 2 s after leaving
})
Rules.COMMITTED = table.freeze({ Release = true, Jump = true })
Rules.TELEPORT_STUDS = 12

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

-- Whether a creature is slowed by the puddles: `candy` (WildboundCandyHiding.candy(beast)) and its config `spec`
-- (WildboundBeastConfig.BEASTS[beast]) walks (grounded = true).
function Rules.affects(candy, spec)
	return candy == true and type(spec) == "table" and spec.grounded == true
end

-- The puddles { { x, z, r } } (world) of a list of trap instances (CollectionService:GetTagged(TRAP.tag)): each Model's
-- pivot and its radius attribute. Anything else, or a puddle without a usable radius, is skipped.
function Rules.trapPatches(list)
	local out = {}
	for _, item in ipairs(type(list) == "table" and list or {}) do
		if typeof(item) == "Instance" and item:IsA("Model") then
			local r = item:GetAttribute(Rules.TRAP.radiusAttribute)
			local p = item:GetPivot().Position
			if finite(r) and r > 0 and finite(p.X) and finite(p.Z) then table.insert(out, { x = p.X, z = p.Z, r = r }) end
		end
	end
	return out
end

-- The puddle whose footprint holds (x, z) (flat), or nil. patches = { { x, z, r } } in the same coordinates.
function Rules.inTrap(patches, x, z)
	if type(patches) ~= "table" or not (finite(x) and finite(z)) then return nil end
	for _, patch in ipairs(patches) do
		if math.sqrt((patch.x - x) ^ 2 + (patch.z - z) ^ 2) <= patch.r then return patch end
	end
	return nil
end

-- The sticky clock. memo is a table kept per creature (memo.untilAt: when the tail ends). `inside` this step: stuck, and
-- the tail restarts. Returns whether it is stuck now and whether it was just caught (stuck now, free the step before).
function Rules.stuck(memo, inside, now)
	if type(memo) ~= "table" then return false, false end
	local t = finite(now) and now or 0
	local active = memo.untilAt ~= nil and t < memo.untilAt
	if inside then
		memo.untilAt = t + Rules.TRAP.afterSeconds
		return true, not active
	end
	if not active then memo.untilAt = nil end
	return active, false
end

-- The beast server's post-step: e is the encounter after its brain stepped, (px, py, pz) its spot before the step,
-- phaseBefore its phase before the step. A stuck creature's new spot is pulled back to px + (new - px) * TRAP.slow (y
-- too, when both are known). Returns whether this step was slowed and whether it was just caught.
function Rules.slowStep(e, px, py, pz, patches, memo, now, phaseBefore)
	if type(e) ~= "table" or e.done or type(e.pos) ~= "table" or type(memo) ~= "table" then return false, false end
	local nx, nz = e.pos.x, e.pos.z
	if not (finite(px) and finite(pz) and finite(nx) and finite(nz)) then return false, false end
	local inside = Rules.inTrap(patches, px, pz) ~= nil or Rules.inTrap(patches, nx, nz) ~= nil
	local slowed, caught = Rules.stuck(memo, inside, now)
	if not slowed or Rules.COMMITTED[phaseBefore] or Rules.COMMITTED[e.phase] then return false, caught end
	local f = Rules.TRAP.slow
	if math.sqrt((nx - px) ^ 2 + (nz - pz) ^ 2) > Rules.TELEPORT_STUDS then return false, caught end
	e.pos.x, e.pos.z = px + (nx - px) * f, pz + (nz - pz) * f
	if finite(py) and finite(e.pos.y) then e.pos.y = py + (e.pos.y - py) * f end
	return true, caught
end

return Rules
