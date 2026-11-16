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
Spec.CALM = { "Spawn", "Calm", "Dormant", "Patrol", "Guard", "Wake", "Return", "Disengage", "Ended", "GiveUp", "Recover" }
-- Every phase the shared brain WildboundBeastCandyCritter emits.
Spec.BRAIN_PHASES = { "Spawn", "Patrol", "Notice", "Chase", "Telegraph", "Release", "Recover" }

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
	Mochimiau = { idle = "Idle", extras = { "Bounce" }, phase = phases("Idle", {
		Notice = "Bounce", Chase = "Trot", Telegraph = "Charge", Release = "Bounce", Strike = "Bounce", Jump = "Bounce",
	}) },
	Canelin = { idle = "Idle", extras = { "Alert" }, phase = phases("Idle", {
		Notice = "Alert", Chase = "Walk", Telegraph = "Charge", Release = "Spin", Strike = "Spin",
	}) },
	Flanin = { idle = "Idle", extras = { "Wave" }, phase = phases("Idle", {
		Notice = "Wave", Chase = "Walk", Telegraph = "Charge", Release = "Jump", Jump = "Jump", Strike = "Land",
	}) },
	Mielita = { idle = "Fly", extras = { "Pollen" }, phase = phases("Fly", {
		Notice = "Orbit", Chase = "Patrol", Telegraph = "Pollen", Release = "Dash", Strike = "Dash", Stagger = "Dizzy",
	}) },
	GatoRepartidor = { idle = "Idle", extras = { "Call" }, phase = phases("Idle", {
		Notice = "Surprised", Chase = "Run", Telegraph = "Call", Release = "Throw", Strike = "Throw",
	}) },
}

-- The critter a model is: its WildboundCritter attribute, else its name; nil when it is none of the six.
function Spec.critterName(model)
	local tagged = model:GetAttribute("WildboundCritter")
	if type(tagged) == "string" and Spec.SPEC[tagged] then return tagged end
	if Spec.SPEC[model.Name] then return model.Name end
	return nil
end

-- The clip name for a BeastPhase (nil phase = idle). Falls back to the idle loop when the phase is unknown or its clip
-- is missing from the creature's CLIPS.
function Spec.clipFor(name, phase, CLIPS)
	local spec = Spec.SPEC[name]
	local clip = phase ~= nil and spec.phase[phase] or nil
	if clip == nil or (CLIPS and CLIPS[clip] == nil) then clip = spec.idle end
	return clip
end

-- The published Animation id for a clip on this model ("Clip_<clip>", a non-empty string), or nil.
function Spec.publishedId(model, clip)
	local id = model:GetAttribute("Clip_" .. clip)
	if type(id) == "string" and id ~= "" then return id end
	return nil
end

return Spec
