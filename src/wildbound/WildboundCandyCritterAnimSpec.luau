-- Which clip each of the six Caramelo critters plays (odd/tasks/wildbound-candy-critters-anim.md). Pure data and
-- helpers, shared by WildboundCandyCritterAnim (the client player) and tests/WildboundCandyClipKit_Test.luau.
--   idle: the default loop. extras: preview one-shots. phase: BeastPhase -> clip for the live clones.
-- Spec.clipFor resolves a phase (unknown phase, or a clip the data module lacks -> the idle loop).
-- Spec.publishedId returns the "Clip_<clip>" attribute when it is a published id string, otherwise nil.
local Spec = {}

Spec.FADE = 0.15 -- seconds of cross-fade between clips
Spec.FAR = 250 -- studs from the camera beyond which a model is not animated
Spec.EXTRA_EVERY = { 5, 9 } -- seconds between preview one-shots (random in this range)
Spec.PREVIEW_FOLDER = "WildboundNewCandyPreview"
Spec.BEASTS_FOLDER = "WildboundBeastsLocal"

-- Phases that play the idle loop unless a creature maps them to something else.
-- A2: Deliver (the Gato's golden order) plays the idle loop for the others.
Spec.CALM = { "Spawn", "Calm", "Dormant", "Patrol", "Guard", "Wake", "Return", "Disengage", "Ended", "GiveUp", "Recover",
	"Deliver" }
-- Every phase the shared brain WildboundBeastCandyCritter emits (PF2: Calm while it pauses on its patrol, Return on the
-- walk home that ends an encounter; A2: Deliver while the Gato hands over its golden order).
Spec.BRAIN_PHASES = { "Spawn", "Patrol", "Calm", "Notice", "Chase", "Telegraph", "Release", "Recover", "Return", "Deliver" }

local function phases(idle, map)
	local out = {}
	for _, name in ipairs(Spec.CALM) do out[name] = idle end
	for name, clip in pairs(map) do out[name] = clip end
	return out
end

Spec.SPEC = {
	DuquesaBurbuja = { idle = "SitIdle", extras = { "Surprised" }, phase = phases("Idle", {
		Notice = "Surprised", Chase = "Glide", Telegraph = "Charge", Release = "Whip", Strike = "Whip", Attack = "Whip",
		Recover = "Recover", Stagger = "Surprised",
	}) },
	-- PF2: Patrol and Return (walking) play the walk clip; Calm (standing on the patrol) keeps the idle loop.
	Mochimiau = { idle = "Idle", extras = { "Bounce" }, phase = phases("Idle", {
		Notice = "Bounce", Chase = "Trot", Telegraph = "Charge", Release = "Bounce", Strike = "Bounce", Jump = "Bounce",
		Patrol = "Walk", Return = "Walk",
	}) },
	-- A2: it spins in place on the tell (Telegraph), then rolls (Release).
	Canelin = { idle = "Idle", extras = { "Alert" }, phase = phases("Idle", {
		Notice = "Alert", Chase = "Walk", Telegraph = "Spin", Release = "Spin", Strike = "Spin", Patrol = "Walk", Return = "Walk",
	}) },
	Flanin = { idle = "Idle", extras = { "Wave" }, phase = phases("Idle", {
		Notice = "Wave", Chase = "Walk", Telegraph = "Charge", Release = "Jump", Jump = "Jump", Strike = "Land",
		Patrol = "Walk", Return = "Walk",
	}) },
	Mielita = { idle = "Fly", extras = { "Pollen" }, phase = phases("Fly", {
		Notice = "Orbit", Chase = "Patrol", Telegraph = "Pollen", Release = "Dash", Strike = "Dash", Stagger = "Dizzy",
		Patrol = "Patrol", Return = "Patrol",
	}) },
	GatoRepartidor = { idle = "Idle", extras = { "Call" }, phase = phases("Idle", {
		Notice = "Surprised", Chase = "Run", Telegraph = "Call", Release = "Throw", Strike = "Throw", Patrol = "Walk", Return = "Walk",
		Deliver = "Deliver",
	}) },
	-- A3 (odd/tasks/wildbound-caramelo-playfix.md): the two big candy beasts, from their older { time, pose } clip modules
	-- (legacy = true: the client converts them with Kit.fromLegacy). The phase maps are their old clients' CLIP tables;
	-- Don Glaseon's Stagger (the bat bounces off him) plays HitReact_ImmuneBat.
	Tortidragon = { idle = "Idle", extras = { "Alert" }, legacy = true, phase = phases("Idle", {
		Notice = "Alert", Chase = "Run_Quadruped", GiveUp = "Walk_Quadruped", Disengage = "Walk_Quadruped",
		Telegraph = "Attack_Telegraph", Release = "Attack_Release", Recover = "Attack_Recover",
	}) },
	DonGlaseon = { idle = "Idle_Breath", extras = { "Notice" }, legacy = true, phase = phases("Idle_Breath", {
		Patrol = "Patrol_Walk", Suspicious = "Notice", Roar = "Roar_Visual", Chase = "Chase_Run", Search = "Search",
		Telegraph = "Attack_Telegraph_Licorice", Attack = "Attack_Release_Licorice", Recover = "Attack_Recover_Licorice",
		LoseTarget = "LoseTarget", Return = "Patrol_Walk", Disengage = "Patrol_Walk", Stagger = "HitReact_ImmuneBat",
	}) },
}

-- A3: server scenery models, direct children of Workspace, animated like a live clone of the named beast (they carry a
-- BeastPhase too): Don Glaseon's sleeping copy on BossHome.
Spec.SCENERY = { DonGlaseonDormant = "DonGlaseon" }

-- The creature a model is: its WildboundCritter attribute, else its name (or its scenery name); nil when it is none of
-- the spec's.
function Spec.critterName(model)
	local tagged = model:GetAttribute("WildboundCritter")
	if type(tagged) == "string" and Spec.SPEC[tagged] then return tagged end
	if Spec.SPEC[model.Name] then return model.Name end
	return Spec.SCENERY[model.Name]
end

-- The clip name for a BeastPhase (nil phase = idle). Falls back to the idle loop when the phase is unknown or its clip
-- is missing from the creature's CLIPS.
function Spec.clipFor(name, phase, CLIPS)
	local spec = Spec.SPEC[name]
	local clip = phase ~= nil and spec.phase[phase] or nil
	if clip == nil or (CLIPS and CLIPS[clip] == nil) then clip = spec.idle end
	return clip
end

-- Run in place (odd/tasks/wildbound-caramelo-playfix.md, Don Glaseon walk follow-up): in a moving phase a live clone
-- whose measured root speed (horizontal, smoothed over SPEED_SMOOTH s) is near zero plays its stand clip (spec.stand,
-- else the idle loop) instead of the walk/run, e.g. Don Glaseon holding at his 8-stud attack range in Chase. Still
-- below STILL_SPEED, moving again above MOVE_SPEED (studs/s; the band keeps it from flickering).
Spec.MOVING = { Patrol = true, Chase = true, Return = true, Search = true, Disengage = true, GiveUp = true }
Spec.STILL_SPEED = 1.5
Spec.MOVE_SPEED = 3
Spec.SPEED_SMOOTH = 0.15

function Spec.isStill(speed, wasStill)
	return speed < (wasStill and Spec.MOVE_SPEED or Spec.STILL_SPEED)
end

-- The clip to play for a phase given its resolved clip and whether the root is still; a stand clip the data lacks keeps
-- the clip.
function Spec.motionClip(name, phase, clip, CLIPS, still)
	if not still or phase == nil or not Spec.MOVING[phase] then return clip end
	local spec = Spec.SPEC[name]
	local stand = spec.stand or spec.idle
	if CLIPS and CLIPS[stand] == nil then return clip end
	return stand
end

-- The published Animation id for a clip on this model ("Clip_<clip>", a non-empty string), or nil.
function Spec.publishedId(model, clip)
	local id = model:GetAttribute("Clip_" .. clip)
	if type(id) == "string" and id ~= "" then return id end
	return nil
end

return Spec
