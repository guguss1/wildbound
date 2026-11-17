-- Every horror audio asset id in one place (delivery D9, decision D-D3: shortlist approximations until the user
-- provides licensed uploads, so swapping a sound means editing only this table). Ids come only from
-- docs/audio/wildbound-horror-audio-shortlist.md and wildbound-dread-assets-shortlist.md;
-- tools/test_wildbound_audio_catalog.py checks that. The first id of a slot is the primary; a later one is the
-- fallback when the first fails to load. Data only.
local Catalog = {}

Catalog.GROUPS = table.freeze({ "Ambient", "Music", "Threat", "Chase", "Impact" })

local function slot(group, ids, extra)
	local entry = { group = group, ids = table.freeze(ids), loop = false, spatial = false, pitch = 1 }
	for key, value in pairs(extra or {}) do entry[key] = value end
	return table.freeze(entry)
end

Catalog.SOUNDS = table.freeze({
	wind = slot("Ambient", { 9112777807 }, { loop = true }),
	birds = slot("Ambient", { 9112806209 }, { loop = true }),
	insectsDusk = slot("Ambient", { 9112810042 }, { loop = true }),
	insectsNight = slot("Ambient", { 9117114084 }, { loop = true }),
	safeMusic = slot("Music", { 9046399990 }, { loop = true }),
	nightBed = slot("Music", { 9043359885 }, { loop = true }),
	unsettling = slot("Music", { 9043359270, 9114353534 }, { loop = true }),
	snap = slot("Threat", { 9120259118, 9114518080 }, { spatial = true }),
	dirt = slot("Threat", { 9114106242 }, { spatial = true }),
	whisper = slot("Threat", { 9125440130 }, { spatial = true }),
	breathing = slot("Threat", { 9113586909 }, { loop = true, spatial = true }),
	steps = slot("Threat", { 9114080709, 9114079718 }, { spatial = true }),
	chaseMusic = slot("Chase", { 1847568713 }, { loop = true }),
	pulse = slot("Chase", { 9114504259 }, { loop = true }),
	signature = slot("Chase", { 9125440130 }),
	hit = slot("Impact", { 9113525391 }),
	stinger = slot("Impact", { 9126006341, 9119640924 }),
	softStinger = slot("Impact", { 9043355570 }),
	hiddenBreath = slot("Impact", { 9113586909 }, { loop = true }),
	unease = slot("Threat", { 9118057295 }, { spatial = true, pitch = 1.4 }),
	fear = slot("Threat", { 9118050871 }, { spatial = true }),
	-- Dread pass: the giant's footsteps and weight, from docs/audio/wildbound-dread-assets-shortlist.md. The giant
	-- thumps loop on its body at its gait (the second id is the fallback), the longest take is the approach bed.
	giantSteps = slot("Threat", { 9125404769, 9125404774 }, { loop = true, spatial = true }),
	approach = slot("Threat", { 9125404796 }, { loop = true, spatial = true }),
	crack = slot("Threat", { 9126239755 }, { spatial = true }),
	groan = slot("Chase", { 9114628321 }, { spatial = true, pitch = 0.7 }),
	creak = slot("Threat", { 9120262025 }, { loop = true, spatial = true }),
	-- Fear pass (FA3): the player's heartbeat (docs/audio/wildbound-dread-assets-shortlist.md, fear pass), a parent's
	-- roar (the lion growl from the same shortlist, pitched down) and La Silueta's distant call (the groan, lower).
	heartbeat = slot("Threat", { 9043365842 }, { loop = true }),
	roar = slot("Impact", { 9113973128 }, { spatial = true, pitch = 0.8 }),
	call = slot("Threat", { 9114628321 }, { spatial = true, pitch = 0.55 }),
	-- Next batch NB2: the sharp sting in the player's head the moment La Silueta sees them (APM, dread shortlist 1.8).
	chaseSting = slot("Impact", { 1846887425, 1842083006 }),
	-- Egg loop (docs/design/wildbound-egg-loop.md): the bank reward (bright small bells, "seal success" in the horror
	-- shortlist, layer 7) and the hatch (the harp sting, "registration chime" in the same layer). 2D one-shots.
	eggBanked = slot("Impact", { 9114826444 }),
	eggHatched = slot("Impact", { 1841772016 }),
	-- Training treadmill (WildboundTreadmillClient), 2D: the stride thump looped fast while running, and the bank bells
	-- for each lap.
	treadmillSteps = slot("Impact", { 9114080709 }, { loop = true, pitch = 1.45 }),
	treadmillLap = slot("Impact", { 9114826444 }),
	-- Caramelo ambience (WildboundCandyAmbience): the Caramelo music bed (MU, 2026-11-17): APM "Bundles Of Joy", a
	-- cheerful track picked for the owner, who still has to listen to it (alternates in docs/audio). Removing this line
	-- brings back the sweeter calm bed (safeMusic).
	carameloMusic = slot("Music", { 1845212471 }, { loop = true }),
})

-- Ids deliberately used by more than one slot (sorted slot names). Anything else reused is a mistake.
Catalog.SHARED = table.freeze({
	[9125440130] = table.freeze({ "signature", "whisper" }),
	[9113586909] = table.freeze({ "breathing", "hiddenBreath" }),
	[9114628321] = table.freeze({ "call", "groan" }),
	[9114080709] = table.freeze({ "steps", "treadmillSteps" }),
	[9114826444] = table.freeze({ "eggBanked", "treadmillLap" }),
})

return Catalog