-- Studio fresh-clone suite runner (read-only for game scripts). Paste into Studio MCP execute_luau (Edit datamodel).
-- For each ServerStorage.Wildbound*_Test (or only those matching FILTER) it builds that suite's exact arguments from
-- SPECS, clones the test and every module it reaches into one per-suite folder under this run's temporary ServerStorage
-- folder (RUN_PREFIX .. run id), runs the test and sums { passed, failed }. It never edits a Source, never touches
-- Workspace and destroys the temporary folder on every path. Returns (and prints) a text report.
--
-- SPECS["<suite>"] lists the suite's arguments in signature order, copied from its "Invoke with ..." header. Tokens:
--   "mod:<Name>"  a fresh clone of the ModuleScript <Name>, loaded once per suite (shared by its tokens)
--   "src:<Name>"  the Source of <Name> (the suite's clone when one exists, otherwise the original script)
--   "inst:<Path>" an existing ServerStorage instance, passed read-only (e.g. "inst:ServerStorage.WildboundAssets")
--   "tuning:modules" { [key] = fresh clone } for every module in WildboundTuningSchema.MODULES
--   { key = token, ... } a table of the same tokens
-- SKIP["<suite>"] names suites that are never run here, with the reason: every suite that parents a fixture into a real
-- service (Workspace, ServerStorage, ...) is skipped. A ServerStorage suite with neither entry is reported as
-- UNSPECIFIED and not run, so a guessed signature can never show up as a failure.
-- tools/test_studio_fresh_runner.py checks every tests/Wildbound*_Test.luau has an entry, each spec's arity, its token
-- kinds against the header, every key the suite reads (also by computed index), the sibling rule and the skip rule.
--
-- Fresh dependencies: every clone runs through a loader (loadstring + setfenv over its unchanged Source) whose game,
-- script and require point at this suite's clones. ReplicatedStorage/ServerScriptService/ServerStorage/StarterPlayer
-- :WaitForChild/FindFirstChild("Wildbound...") and script:FindFirstAncestorOfClass("DataModel") therefore reach a
-- per-suite fresh clone, never the Edit session's cached require of the original. If loadstring/setfenv are not
-- available, plain require is used and any suite whose modules use a service-path require is reported SUSPECT_CACHE,
-- kept out of the totals; run those suites in Play (or after reopening the place) instead.
-- Timeouts: a suite still yielding after SUITE_TIMEOUT is task.cancel()ed and reported TIMEOUT (out of the totals).
-- Known limits: a suite that hangs without yielding freezes Studio (nothing can preempt it), and threads a suite
-- spawns or delays itself are not cancelled.
-- Concurrency: a run sets the ServerStorage attribute WildboundFreshRunnerLock ("<run id>@<time>", refreshed per
-- suite) and refuses to start while another live run holds it; a lock older than LOCK_STALE is treated as dead.
-- Originals are looked up in ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer (first match), never
-- inside a backup folder (name containing "Backup" or ending in a date) or any runner's temporary folder.
-- A full run takes longer than one MCP request: set FILTER to a range (e.g. "^Wildbound[A-F]") or read the printed
-- report with get_console_output.
-- Totals from this runner are not comparable to the old 70-suite / 1454-passed baseline (a different runner).

local FILTER = nil -- e.g. "^WildboundBalance_Test$"; nil runs every Wildbound*_Test

local SPECS, SKIP = {}, {}

SKIP["WildboundForestDress_Test"] = "its line-of-sight cases park a copy of the forest in a Workspace folder; this runner never touches Workspace"
SKIP["WildboundSiluetaVisual_Test"] = "it parents its fixture folder straight into ServerStorage (folder.Parent = game:GetService('ServerStorage')); this runner only writes inside its temporary folder"
SKIP["WildboundP0Map_Test"] = "its R3 relief case parks a probe folder in Workspace (arena.Parent = workspace); this runner never touches Workspace"
SKIP["WildboundCandyBeastSites_Test"] = "it takes two Workspace instances (the WildboundPradera marker and Candy_Bioma_v1) as arguments; this runner never touches Workspace"
SKIP["WildboundCandyBuilder_Test"] = "it parents its scratch build folder straight into ServerStorage (scratch.Parent = game:GetService('ServerStorage')); this runner only writes inside its temporary folder"
SKIP["WildboundCandyKit_Test"] = "it parks a scratch WorldModel straight in ServerStorage for its ray queries; this runner only writes inside its temporary folder"

SPECS["WildboundAggroWiring_Test"] = { "src:WildboundWorld" }
SPECS["WildboundAmbush_Test"] = { "mod:WildboundAmbush", "mod:WildboundWorldRules", "src:WildboundAmbush" }
SPECS["WildboundAnalyticsWiring_Test"] = {
	"mod:WildboundAnalytics",
	{ server = "src:WildboundServer", flags = "src:WildboundFlags", capture = "src:WildboundCaptureSession" },
	"mod:WildboundFlags",
	"mod:WildboundEconomyConfig",
	"mod:WildboundLumipolWild",
}
SPECS["WildboundAnalytics_Test"] = { "mod:WildboundAnalytics", { analytics = "src:WildboundAnalytics" } }
SPECS["WildboundArrullo_Test"] = { "mod:WildboundArrullo", "src:WildboundArrullo" }
SPECS["WildboundAtmosphere_Test"] = { "mod:WildboundAtmosphere", "src:WildboundWorldClient" }
SPECS["WildboundAudioMix_Test"] = { "mod:WildboundAudioMix", "mod:WildboundAudioCatalog" }
SPECS["WildboundAudioWiring_Test"] = { "src:WildboundAudioClient" }
SPECS["WildboundBalance_Test"] = { "mod:WildboundBalance", "src:WildboundBalance" }
SPECS["WildboundBiomeLight_Test"] = {
	"mod:WildboundBiomeLight",
	"src:WildboundBiomeLight",
	{
		biomes = "mod:WildboundBiomes", atmosphere = "mod:WildboundAtmosphere", worldClient = "src:WildboundWorldClient",
		world = "src:WildboundWorld",
	},
}
SPECS["WildboundPlacePhase_Test"] = {
	"mod:WildboundBiomeLight",
	{
		rules = "mod:WildboundWorldRules", brain = "mod:WildboundGuardianBrain", director = "mod:WildboundBeastDirector",
		config = "mod:WildboundBeastConfig", island = "mod:WildboundIsland", layout = "mod:WildboundIslandLayout",
		ambush = "mod:WildboundAmbush",
	},
	{ world = "src:WildboundWorld", server = "src:WildboundServer", beasts = "src:WildboundBeasts" },
}
SPECS["WildboundRoulette_Test"] = { "mod:WildboundRoulette", "mod:WildboundBalance" }
SPECS["WildboundRouletteService_Test"] = {
	"mod:WildboundRouletteService", "mod:WildboundRoulette", "mod:WildboundState", "mod:WildboundEconomy",
	"mod:WildboundEconomyConfig", "mod:WildboundText",
	{ server = "src:WildboundServer", service = "src:WildboundRouletteService", client = "src:WildboundRouletteClient" },
	"mod:WildboundOffers",
}
SPECS["WildboundUiKit_Test"] = { "mod:WildboundUiStyle", "src:WildboundUiStyle" }
-- RW-1..RW-6 (owner request 2026-11-20): the roulette wheel and the offers catalog with the development switch
SPECS["WildboundRouletteWheel_Test"] = {
	"mod:WildboundRouletteWheel", "mod:WildboundUiStyle", "mod:WildboundRoulette", "src:WildboundRouletteWheel",
}
SPECS["WildboundOffers_Test"] = {
	"mod:WildboundOffers", "mod:WildboundFlags", "mod:WildboundEconomyConfig",
	{
		offers = "src:WildboundOffers", flags = "src:WildboundFlags", service = "src:WildboundRouletteService",
		client = "src:WildboundRouletteClient", wheel = "src:WildboundRouletteWheel", style = "src:WildboundUiStyle",
		server = "src:WildboundServer",
	},
}
SPECS["WildboundBaseZone_Test"] = {
	"mod:WildboundBaseZone",
	"src:WildboundBaseZone",
	{ server = "src:WildboundServer", guide = "src:WildboundBaseGuideClient", text = "mod:WildboundText" },
}
SPECS["WildboundBatKnock_Test"] = { "mod:WildboundBatKnock", "src:WildboundBatKnock" }
SPECS["WildboundBat_Test"] = {
	"mod:WildboundBat",
	"src:WildboundBat",
	{
		server = "src:WildboundServer", worldClient = "src:WildboundWorldClient", text = "mod:WildboundText",
		keys = "mod:WildboundPromptKeys", audio = "src:WildboundAudioClient", eggCarry = "mod:WildboundEggCarry",
		rules = "mod:WildboundWorldRules", island = "mod:WildboundIsland", state = "mod:WildboundState",
		economy = "mod:WildboundEconomy", config = "mod:WildboundEconomyConfig",
	},
}
SPECS["WildboundBeastAbeja_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastAbeja", "mod:WildboundBeastConfig", "src:WildboundBeastAbeja",
	"mod:WildboundPraderaSites", "src:WildboundPraderaSites",
}
SPECS["WildboundBeastAnimPlan_Test"] = {
	"mod:WildboundBeastAnimPlan",
	{
		Streamer = "mod:WildboundBeastAnimStreamer", Root = "mod:WildboundBeastAnimRoot",
		Gaze = "mod:WildboundBeastAnimGaze", Lurker = "mod:WildboundBeastAnimLurker",
		Viper = "mod:WildboundBeastAnimViper", Pouncer = "mod:WildboundBeastAnimPouncer", -- BR1/BR2
	},
	"src:WildboundBeastsClient",
	"src:WildboundBeastAnim",
}
SPECS["WildboundBeastAudience_Test"] = { "mod:WildboundBeastAudience", "mod:WildboundBeastConfig" }
SPECS["WildboundBeastAttack_Test"] = { "mod:WildboundBeastAttack", "mod:WildboundBeastConfig", "src:WildboundBeastAttack" }
SPECS["WildboundBeastChase_Test"] = { "mod:WildboundBeastChase", "src:WildboundBeastChase" }
SPECS["WildboundBeastDirector_Test"] = { "mod:WildboundBeastDirector", "src:WildboundBeastDirector", "mod:WildboundBeastConfig" }
SPECS["WildboundBeastEncounters_Test"] = {
	"mod:WildboundBeastEncounters", "src:WildboundBeastEncounters", "mod:WildboundBeastConfig", "src:WildboundBeastConfig",
}
SPECS["WildboundBeastGaze_Test"] = { "mod:WildboundBeastEncounters", "mod:WildboundBeastGaze", "mod:WildboundBeastConfig", "src:WildboundBeastGaze" }
SPECS["WildboundBeastLurker_Test"] = { "mod:WildboundBeastEncounters", "mod:WildboundBeastLurker", "mod:WildboundBeastConfig", "src:WildboundBeastLurker" }
SPECS["WildboundBeastNube_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastNube", "mod:WildboundBeastConfig", "src:WildboundBeastNube",
	"mod:WildboundPraderaSites",
}
SPECS["WildboundBeastRoot_Test"] = { "mod:WildboundBeastEncounters", "mod:WildboundBeastRoot", "mod:WildboundBeastConfig", "src:WildboundBeastRoot" }
SPECS["WildboundBeastScuttler_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastScuttler", "mod:WildboundBeastConfig", "mod:WildboundBeastAttack",
	"src:WildboundBeastScuttler",
}
SPECS["WildboundBeastGomibu_Test"] = { "mod:WildboundBeastEncounters", "mod:WildboundBeastGomibu", "mod:WildboundBeastConfig" }
SPECS["WildboundCandyLayout_Test"] = { "mod:WildboundCandyLayout", "mod:WildboundBiomes" }
SPECS["WildboundCandyFluff_Test"] = { "mod:WildboundCandyKit" }
SPECS["WildboundCandyGomibu_Test"] = { "mod:WildboundCandyGomibu", "inst:ServerStorage.WildboundAssets.Gomibu" }
SPECS["WildboundCandyGomibuClips_Test"] = { "mod:WildboundCandyGomibuClips", "inst:ServerStorage.WildboundAssets.Gomibu" }
SPECS["WildboundCandyGomibuAttack_Test"] = { "mod:WildboundCandyGomibuAttack" }
SPECS["WildboundCandyFlanfuria_Test"] = { "mod:WildboundCandyFlanfuria", "inst:ServerStorage.WildboundAssets.Flanfuria" }
SPECS["WildboundCandyFlanfuriaAttack_Test"] = { "mod:WildboundCandyFlanfuriaAttack" }
SPECS["WildboundCandyFlanfuriaClips_Test"] = { "mod:WildboundCandyFlanfuriaClips", "inst:ServerStorage.WildboundAssets.Flanfuria" }
SPECS["WildboundBeastFlanfuria_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastFlanfuria", "mod:WildboundBeastConfig", "mod:WildboundCandyFlanfuriaAttack",
}
SPECS["WildboundCandyTortidragon_Test"] = { "mod:WildboundCandyTortidragon", "inst:ServerStorage.WildboundAssets.Tortidragon" }
SPECS["WildboundCandyTortidragonAttack_Test"] = { "mod:WildboundCandyTortidragonAttack" }
SPECS["WildboundCandyTortidragonClips_Test"] = { "mod:WildboundCandyTortidragonClips", "inst:ServerStorage.WildboundAssets.Tortidragon" }
SPECS["WildboundScuttlerClips_Test"] = { "mod:WildboundScuttlerClips", "mod:WildboundBeastAnimPlan" }
SPECS["WildboundBeastTortidragon_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastTortidragon", "mod:WildboundBeastConfig", "mod:WildboundCandyTortidragonAttack",
}
SPECS["WildboundBeastCandyCritter_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastCandyCritter", "mod:WildboundBeastConfig", "mod:WildboundPortal",
	{ beasts = "src:WildboundBeasts", service = "src:WildboundCandyCritterService", client = "src:WildboundBeastsClient",
		resting = "src:WildboundCandyRestingService", restingClient = "src:WildboundCandyRestingClient",
		server = "src:WildboundServer", cake = "src:WildboundCandyCakeClient", text = "mod:WildboundText",
		spec = "mod:WildboundCandyCritterAnimSpec" },
	"mod:WildboundBeastChase",
}
SPECS["WildboundCandySmarts_Test"] = {
	"mod:WildboundCandySmarts", "mod:WildboundBeastEncounters", "mod:WildboundBeastConfig", "mod:WildboundBeastCandyCritter",
	"mod:WildboundBeastGomibu", "mod:WildboundBeastFlanfuria", "mod:WildboundBeastTortidragon", "mod:WildboundBeastDonGlaseon",
	"mod:WildboundCandyFrutillon", "mod:WildboundCandyDuquesa", "mod:WildboundCandyLayout", "mod:WildboundWorldRules",
}
SPECS["WildboundCandyDuquesa_Test"] = {
	"mod:WildboundCandyDuquesa", "mod:WildboundCandyFrutillon", "mod:WildboundCandyLayout",
	{ service = "src:WildboundCandyDuquesaService", anim = "src:WildboundCandyCritterAnim" },
	"mod:WildboundBeastChase", "mod:WildboundWorldRules",
}
SPECS["WildboundCandyDonGlaseon_Test"] = { "mod:WildboundCandyDonGlaseon", "inst:ServerStorage.WildboundAssets.DonGlaseon" }
SPECS["WildboundCandyDonGlaseonAttack_Test"] = { "mod:WildboundCandyDonGlaseonAttack" }
SPECS["WildboundCandyDonGlaseonVacuum_Test"] = { "mod:WildboundCandyDonGlaseonVacuum" }
SPECS["WildboundCandyDonGlaseonWall_Test"] = { "mod:WildboundCandyDonGlaseonWall" }
SPECS["WildboundCandyDonGlaseonAnger_Test"] = { "mod:WildboundCandyDonGlaseonAnger" }
SPECS["WildboundCandyTower_Test"] = {
	"mod:WildboundCandyLayout", "mod:WildboundCandyBuilder", "mod:WildboundCandyKit",
	{ nests = "src:WildboundCandyNests", client = "src:WildboundCandyTowerClient" },
	"mod:WildboundCandyNests", "inst:ServerStorage.WildboundAssets.CandyKit",
}
SPECS["WildboundCandyRoar_Test"] = { { beasts = "src:WildboundBeasts" } }
SPECS["WildboundCandyGlaze_Test"] = {
	"mod:WildboundCandyGlaze", "mod:WildboundCandyLayout", "mod:WildboundCandyBuilder",
	{ client = "src:WildboundCandyGlazeClient", server = "src:WildboundServer" },
}
SPECS["WildboundCandyAmbience_Test"] = {
	"mod:WildboundCandyAmbience", "mod:WildboundAudioMix", "mod:WildboundAudioCatalog", "mod:WildboundBiomeLight",
	{ client = "src:WildboundCandyAmbienceClient", audio = "src:WildboundAudioClient" },
}
-- Caramelo v3 (docs/design/wildbound-caramelo-v3-plan.md): the layout, the builder (detached scratch models only) and the raft
SPECS["WildboundCandyV3Layout_Test"] = {
	"mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout", "mod:WildboundPraderaSites", "mod:WildboundCandyTrapCake",
	"mod:WildboundCandyV3KitSpec", -- CL-D4: V3-1 pins M1_KIT to the kit spec
}
SPECS["WildboundCandyV3Builder_Test"] = {
	"mod:WildboundCandyV3Builder", "mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout", "mod:WildboundCandyBuilder",
	"mod:WildboundCandyV3KitSpec", "mod:WildboundCandyKit", "inst:ServerStorage.WildboundAssets.CandyKit",
	{ beasts = "src:WildboundBeasts" },
}
SPECS["WildboundCandyRaft_Test"] = {
	"mod:WildboundCandyRaft", "mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout", "mod:WildboundText",
	{ service = "src:WildboundCandyRaftService", client = "src:WildboundCandyRaftClient" },
}
SPECS["WildboundCandyWade_Test"] = {
	"mod:WildboundCandyWade", "mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout",
	{ service = "src:WildboundCandyWadeService", server = "src:WildboundServer" },
}
-- Caramelo v4 (odd/tasks/wildbound-caramelo-v2.md V4-D8): the house nests (detached fixtures, a fake kit)
SPECS["WildboundCandyHouseNests_Test"] = {
	"mod:WildboundCandyHouseNests", "mod:WildboundCandyNests", "mod:WildboundCandyLayout", "mod:WildboundCandyV3KitSpec",
	"mod:WildboundCandyV3Layout", { nests = "src:WildboundCandyNests" },
}
-- Caramelo v5 (odd/tasks/wildbound-caramelo-v2.md V5-D1, V5-D2): the candy hide spots (detached fixtures, no kit) and
-- the creatures' hiding rules with two real brains
SPECS["WildboundCandyHideSpots_Test"] = {
	"mod:WildboundCandyHideSpots", "mod:WildboundCandyHiding", "mod:WildboundHide", "mod:WildboundCandyLayout",
	"mod:WildboundCandyV3Layout", "mod:WildboundBeastEncounters", "mod:WildboundBeastConfig", "mod:WildboundBeastCandyCritter",
	"mod:WildboundBeastDonGlaseon",
	{ beasts = "src:WildboundBeasts", flyers = "src:WildboundCandyFlyersService", duquesa = "src:WildboundCandyDuquesaService",
		world = "src:WildboundWorld", nests = "src:WildboundCandyNests" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D1): the tall licorice grass (detached fixtures) and the grass rule
-- with a real Mochimiau brain
SPECS["WildboundCandyGrass_Test"] = {
	"mod:WildboundCandyGrass", "mod:WildboundCandyHideSpots", "mod:WildboundCandyHiding", "mod:WildboundCandyLayout",
	"mod:WildboundCandyV3Layout", "mod:WildboundBeastEncounters", "mod:WildboundBeastCandyCritter",
	{ beasts = "src:WildboundBeasts", flyers = "src:WildboundCandyFlyersService", duquesa = "src:WildboundCandyDuquesaService",
		nests = "src:WildboundCandyNests" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D5): the sticky caramel traps (detached fixtures), the slow rule
-- with a real Mochimiau brain, and the wiring
SPECS["WildboundCandyTraps_Test"] = {
	"mod:WildboundCandyTraps", "mod:WildboundCandyTrapRules", "mod:WildboundCandyHideSpots", "mod:WildboundCandyGrass",
	"mod:WildboundCandyHiding", "mod:WildboundCandyLayout", "mod:WildboundCandyV3Layout", "mod:WildboundBeastEncounters",
	"mod:WildboundBeastCandyCritter", "mod:WildboundBeastConfig", "mod:WildboundCandyNests",
	{ beasts = "src:WildboundBeasts", flyers = "src:WildboundCandyFlyersService", duquesa = "src:WildboundCandyDuquesaService",
		nests = "src:WildboundCandyNests" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D4): the island in the lake (real layout, the raft, wading and
-- the current against it, a detached biome with a fake kit, the nest pipeline and the wiring)
SPECS["WildboundCandyIsland_Test"] = {
	"mod:WildboundCandyIsland", "mod:WildboundCandyNests", "mod:WildboundCandyLayout", "mod:WildboundCandyV3Layout",
	"mod:WildboundCandyRaft", "mod:WildboundCandyWade", "mod:WildboundCandyCurrent", "mod:WildboundCandyLife",
	{ nests = "src:WildboundCandyNests", beasts = "src:WildboundBeasts" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D2): the crumbling cookie bridges (pure rules, real layout, wiring)
SPECS["WildboundCandyCookieBridge_Test"] = {
	"mod:WildboundCandyCookieBridge", "mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout",
	{ service = "src:WildboundCandyCookieBridgeService" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D6): life on the map (pure paths and culling pinned to the real
-- layout, client wiring)
SPECS["WildboundCandyLife_Test"] = {
	"mod:WildboundCandyLife", "mod:WildboundCandyAmbience", "mod:WildboundCandyV3Layout", "mod:WildboundCandyLayout",
	{ client = "src:WildboundCandyLifeClient" },
}
-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md V6-D3): the river current (pure flow field on the real layout, the
-- raft and the wader's push, wiring)
SPECS["WildboundCandyCurrent_Test"] = {
	"mod:WildboundCandyCurrent", "mod:WildboundCandyRaft", "mod:WildboundCandyWade", "mod:WildboundCandyV3Layout",
	"mod:WildboundCandyLayout",
	{ raftService = "src:WildboundCandyRaftService", wadeService = "src:WildboundCandyWadeService",
		client = "src:WildboundCandyCurrentClient" },
}
-- TB-2 (owner request 2026-11-20): the toolbox chocolate texture on the river, lake and pool (pure rules, the client's
-- wiring, and the part names the V3 builder and the cloud wall lay)
SPECS["WildboundCandyChocoLook_Test"] = {
	"mod:WildboundCandyChocoLook", "mod:WildboundCandyCurrent",
	{ client = "src:WildboundCandyChocoLookClient", builder = "src:WildboundCandyV3Builder", east = "src:WildboundCandyEast" },
}
-- Caramelo v7 (odd/tasks/wildbound-caramelo-v2.md V7-D3): the pink sky (pure targets, the client's wiring)
SPECS["WildboundCandySky_Test"] = {
	"mod:WildboundAtmosphere", "mod:WildboundBiomeLight", { client = "src:WildboundCandySkyClient" },
}
-- Caramelo v8 (docs/design/wildbound-caramelo-v8-plan.md V8-D2 to V8-D4): Caramelo Este's plan and build (detached
-- folders only), the creature clamp, the annex plan, and the cloud client, the two server clamps and the v8 migration
-- tool by source (the tool is kept in Studio as the disabled Script ServerStorage.WildboundCaramelV8Migrate)
SPECS["WildboundCandyEast_Test"] = {
	"mod:WildboundCandyEast", "mod:WildboundCandyLayout", "mod:WildboundCandySmarts",
	"mod:WildboundCandyV3Layout", -- CL-D13: the real river end, for the mouth parts
	{ client = "src:WildboundCandyCloudWallClient", beasts = "src:WildboundBeasts", duquesa = "src:WildboundCandyDuquesaService",
		migrate = "src:WildboundCaramelV8Migrate" },
}
-- Caramelo v9 (docs/design/wildbound-caramelo-v9-plan.md CL-D17): the v9 migration tool by source (the tool is kept in
-- Studio as the disabled Script ServerStorage.WildboundCaramelV9Migrate) and the module names it calls
SPECS["WildboundCandyV9Migrate_Test"] = {
	{ migrate = "src:WildboundCaramelV9Migrate" },
	"mod:WildboundCandyV3Builder", "mod:WildboundCandyBuilder", "mod:WildboundCandyEast", "mod:WildboundCandyLayout",
	"mod:WildboundCandyV3Layout",
}
-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md §4): the park's plan, recipes and build (detached models
-- only), the nest markers, the two archives on detached fixtures and the one-shot tool's source (kept in Studio as the
-- disabled Script ServerStorage.WildboundKittenParkBuild); the kittens' gameplay and wiring; the kittens' look, music and
-- light clients
SPECS["WildboundKittenPark_Test"] = {
	"mod:WildboundKittenPark", "mod:WildboundCandyEast", "mod:WildboundCandyLayout",
	{ park = "src:WildboundKittenPark", build = "src:WildboundKittenParkBuild" },
}
SPECS["WildboundCandyKittens_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastCandyCritter", "mod:WildboundBeastConfig",
	"mod:WildboundPraderaSites", "mod:WildboundCandySmarts", "mod:WildboundBeastDirector", "mod:WildboundBeastChase",
	"mod:WildboundCandyNests", "mod:WildboundKittenPark", "mod:WildboundPortal", "mod:WildboundBiomes",
	{ beasts = "src:WildboundBeasts", client = "src:WildboundBeastsClient", resting = "src:WildboundCandyRestingService",
		restingClient = "src:WildboundCandyRestingClient" },
}
SPECS["WildboundCandyKittenArt_Test"] = {
	"mod:WildboundCandyKittens",
	{ service = "src:WildboundCandyKittenService", anim = "src:WildboundCandyKittenAnimClient",
		ambience = "src:WildboundCandyKittenAmbienceClient", audio = "src:WildboundAudioClient" },
}
-- Pueblo Gatito's park frame in the big4 south arm (docs/design/wildbound-pueblo-gatito-move-plan.md PGM-D1, "Sí, movelo")
SPECS["WildboundGatitoArea_Test"] = { "mod:WildboundGatitoArea" }
-- Pueblo Gatito 600 x 1200 (docs/design/wildbound-pueblo-gatito-long-plan.md GL-D14): the grow tool by source (kept in Studio as the disabled Script ServerStorage.WildboundPuebloGatitoGrow), the move tool's frame assert and the park module's caps
SPECS["WildboundPuebloGatitoGrow_Test"] = {
	"mod:WildboundKittenPark", "mod:WildboundGatitoArea",
	{ grow = "src:WildboundPuebloGatitoGrow", move = "src:WildboundPuebloGatitoMove" },
}
SPECS["WildboundCandyFrutillon_Test"] = {
	"mod:WildboundCandyFrutillon", "mod:WildboundCandyLayout", { service = "src:WildboundCandyFrutillonService" },
}
SPECS["WildboundCandyFlyers_Test"] = {
	"mod:WildboundCandyFlyers", "mod:WildboundCandyLayout", "mod:WildboundDodge",
	{ service = "src:WildboundCandyFlyersService", client = "src:WildboundCandyFlyersClient" },
}
SPECS["WildboundCandyTrapCake_Test"] = {
	"mod:WildboundCandyTrapCake", "mod:WildboundCandyLayout",
	{ service = "src:WildboundCandyTrapCakeService", server = "src:WildboundServer", bossService = "src:WildboundCandyDonGlaseonService",
		client = "src:WildboundCandyCakeClient", text = "mod:WildboundText" },
}
SPECS["WildboundBossRobustness_Test"] = {
	"mod:WildboundBat", "mod:WildboundBatKnock", "mod:WildboundBeastConfig", "mod:WildboundCandyDonGlaseon",
	"inst:ServerStorage.WildboundAssets.DonGlaseon",
	{ beasts = "src:WildboundBeasts", service = "src:WildboundCandyDonGlaseonService", server = "src:WildboundServer",
		anim = "src:WildboundCandyDonGlaseonAnim" },
}
SPECS["WildboundCandyDonGlaseonClips_Test"] = { "mod:WildboundCandyDonGlaseonClips", "inst:ServerStorage.WildboundAssets.DonGlaseon",
	"mod:WildboundBeastConfig" }
SPECS["WildboundCandyClipPublish_Test"] = {
	"mod:WildboundCandyClipPublish", "mod:WildboundCandyTortidragonClips", "mod:WildboundCandyDonGlaseonClips",
	"inst:ServerStorage.WildboundAssets.Tortidragon", "inst:ServerStorage.WildboundAssets.DonGlaseon",
	{ tortidragonService = "src:WildboundCandyTortidragonService", donGlaseonService = "src:WildboundCandyDonGlaseonService" },
}
SPECS["WildboundCandyClipKit_Test"] = {
	"mod:WildboundCandyClipKit", "inst:ServerStorage.WildboundNewCandyImports.Canelin", "mod:WildboundCandyCritterClipsCanelin",
	"mod:WildboundCandyCritterAnimSpec",
	{
		DuquesaBurbuja = "mod:WildboundCandyCritterClipsDuquesaBurbuja", Mochimiau = "mod:WildboundCandyCritterClipsMochimiau",
		Canelin = "mod:WildboundCandyCritterClipsCanelin", Flanin = "mod:WildboundCandyCritterClipsFlanin",
		Mielita = "mod:WildboundCandyCritterClipsMielita", GatoRepartidor = "mod:WildboundCandyCritterClipsGatoRepartidor",
	},
	"src:WildboundCandyCritterAnim",
}
SPECS["WildboundCandyLiveClips_Test"] = {
	"mod:WildboundCandyClipKit", "mod:WildboundCandyCritterAnimSpec", "mod:WildboundCandyTortidragonClips",
	"mod:WildboundCandyDonGlaseonClips", "inst:ServerStorage.WildboundAssets.Tortidragon", "inst:ServerStorage.WildboundAssets.DonGlaseon",
	{ anim = "src:WildboundCandyCritterAnim", tortService = "src:WildboundCandyTortidragonService",
		donService = "src:WildboundCandyDonGlaseonService", tortAnim = "src:WildboundCandyTortidragonAnim",
		donAnim = "src:WildboundCandyDonGlaseonAnim", flanAnim = "src:WildboundCandyFlanfuriaAnim" },
}
SPECS["WildboundCandyNests_Test"] = {
	"mod:WildboundCandyNests", "mod:WildboundCandyLayout", "mod:WildboundPraderaSites", "mod:WildboundBeastConfig",
	"mod:WildboundIsland", "mod:WildboundSpecies", "mod:WildboundCandyBuilder",
	{ server = "src:WildboundServer", text = "mod:WildboundText", beasts = "src:WildboundBeasts" },
}
SPECS["WildboundCandyPets_Test"] = {
	"mod:WildboundCandyPets", "mod:WildboundSpecies", "mod:WildboundState", "mod:WildboundEconomy", "mod:WildboundEconomyConfig",
	"mod:WildboundRecord", "mod:WildboundIncubator", "mod:WildboundEggLoop", "mod:WildboundText",
	"inst:ServerStorage.WildboundAssets",
	{ Gomibu = "mod:WildboundCandyGomibuClips", Flanfuria = "mod:WildboundCandyFlanfuriaClips",
		Tortidragon = "mod:WildboundCandyTortidragonClips" },
	{ server = "src:WildboundServer" },
}
SPECS["WildboundCandyEggArt_Test"] = {
	"mod:WildboundCandyEggArt", "mod:WildboundSpecies", "mod:WildboundEggLoop",
	{ server = "src:WildboundServer", bob = "src:WildboundCandyEggBob", state = "mod:WildboundState",
		economy = "mod:WildboundEconomy", economyConfig = "mod:WildboundEconomyConfig" },
}
SPECS["WildboundPortal_Test"] = {
	"mod:WildboundPortal", "mod:WildboundBalance", "mod:WildboundWorldRules", "mod:WildboundCandyLayout", "mod:WildboundBiomes",
	{ portal = "src:WildboundPortal" },
}
SPECS["WildboundPortalService_Test"] = {
	"mod:WildboundPortalService", "mod:WildboundPortal", "mod:WildboundText",
	{ server = "src:WildboundServer", beasts = "src:WildboundBeasts", service = "src:WildboundPortalService",
		client = "src:WildboundPortalClient" },
}
SPECS["WildboundBeastDonGlaseon_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastDonGlaseon", "mod:WildboundBeastConfig", "mod:WildboundCandyDonGlaseonAttack",
	"mod:WildboundBeastDirector", "mod:WildboundPraderaSites",
}
SPECS["WildboundBeastSight_Test"] = { "mod:WildboundBeastSight", "src:WildboundBeastSight", "mod:WildboundBiomes" }
SPECS["WildboundBeastStreamer_Test"] = {
	"mod:WildboundBeastEncounters", "mod:WildboundBeastStreamer", "mod:WildboundBeastConfig", "src:WildboundBeastStreamer",
}
SPECS["WildboundBeastWiring_Test"] = {
	{
		beasts = "src:WildboundBeasts", client = "src:WildboundBeastsClient", server = "src:WildboundServer",
		proxies = "src:WildboundBeastProxies", text = "mod:WildboundText", config = "mod:WildboundBeastConfig",
		director = "mod:WildboundBeastDirector", audience = "mod:WildboundBeastAudience",
	},
	"mod:WildboundBeastProxies",
}
SPECS["WildboundCampView_Test"] = {
	"mod:WildboundCampView", "mod:WildboundEconomyConfig", "mod:WildboundEconomy", "mod:WildboundHudLayout", "src:WildboundCampView",
}
SPECS["WildboundCaptureSession_Test"] = { "mod:WildboundCaptureSession", "src:WildboundCaptureSession" }
SPECS["WildboundCaptureView_Test"] = {
	"mod:WildboundCaptureView", "mod:WildboundHudLayout", "mod:WildboundCaptureSession", "src:WildboundCaptureView", "mod:WildboundText",
}
SPECS["WildboundCarry_Test"] = {
	"mod:WildboundCarry",
	"src:WildboundCarry",
	"mod:WildboundText",
	{ server = "src:WildboundServer", world = "src:WildboundWorldClient", client = "src:WildboundClient" },
}
SPECS["WildboundCreatureToolbar_Test"] = {
	"mod:WildboundCreatureToolbar",
	"src:WildboundCreatureToolbar",
	{ server = "src:WildboundServer", text = "mod:WildboundText" },
}
SPECS["WildboundDodge_Test"] = { "mod:WildboundDodge", "src:WildboundDodge" }
SPECS["WildboundDusk_Test"] = { "mod:WildboundDusk", "src:WildboundDusk", "mod:WildboundWorldRules" }
SPECS["WildboundEconomy_Test"] = {
	"mod:WildboundEconomy", "mod:WildboundEconomyConfig", "src:WildboundEconomy", "mod:WildboundWorldRules",
	"mod:WildboundLumipolWild", "mod:WildboundAmbush", "src:WildboundServer", "src:WildboundWorld",
}
SPECS["WildboundEggCarry_Test"] = {
	"mod:WildboundEggCarry",
	"src:WildboundEggCarry",
	{
		server = "src:WildboundServer", worldClient = "src:WildboundWorldClient", text = "mod:WildboundText",
		state = "mod:WildboundState", economy = "mod:WildboundEconomy", config = "mod:WildboundEconomyConfig",
		keys = "mod:WildboundPromptKeys", stamina = "mod:WildboundStamina", island = "mod:WildboundIsland",
		audio = "src:WildboundAudioClient", schema = "mod:WildboundTuningSchema",
	},
}
SPECS["WildboundEggLoop_Test"] = {
	"mod:WildboundEggLoop",
	"src:WildboundEggLoop",
	{
		text = "mod:WildboundText", species = "mod:WildboundSpecies", state = "mod:WildboundState",
		economy = "mod:WildboundEconomy", config = "mod:WildboundEconomyConfig", server = "src:WildboundServer",
		client = "src:WildboundClient", guide = "src:WildboundBaseGuideClient", catalog = "mod:WildboundAudioCatalog",
	},
}
SPECS["WildboundFairStrike_Test"] = {
	"mod:WildboundFairStrike", "mod:WildboundFlags", "src:WildboundFairStrike", "src:WildboundWorld", "src:WildboundWorldClient",
}
SPECS["WildboundFakePlayerStore_Test"] = { "mod:WildboundFakePlayerStore", "src:WildboundFakePlayerStore" }
SPECS["WildboundFallDamage_Test"] = {
	"mod:WildboundFallDamage", "mod:WildboundFairStrike", "mod:WildboundFlags", "mod:WildboundText",
	{ service = "src:WildboundFallDamageService", server = "src:WildboundServer" },
}
SPECS["WildboundFearWiring_Test"] = {
	{ fear = "src:WildboundFearClient", world = "src:WildboundWorldClient", audio = "src:WildboundAudioClient" },
}
SPECS["WildboundFunnel_Test"] = { "mod:WildboundFunnel", "mod:WildboundAnalytics" }
SPECS["WildboundGold_Test"] = {
	"mod:WildboundGold", "src:WildboundGold",
	{ state = "mod:WildboundState", economy = "mod:WildboundEconomy", config = "mod:WildboundEconomyConfig",
		record = "mod:WildboundRecord", campView = "mod:WildboundCampView", text = "mod:WildboundText",
		service = "src:WildboundGoldService", server = "src:WildboundServer", client = "src:WildboundClient",
		goldClient = "src:WildboundGoldClient" },
}
SPECS["WildboundGatherField_Test"] = {
	"mod:WildboundGatherField", "mod:WildboundEconomyConfig", "mod:WildboundSpawn", "src:WildboundGatherField",
	"src:WildboundGather", "src:WildboundServer",
}
SPECS["WildboundGear_Test"] = {
	"mod:WildboundGear",
	"src:WildboundGear",
	{
		server = "src:WildboundServer", world = "src:WildboundWorld", client = "src:WildboundClient",
		fear = "src:WildboundFearClient", text = "mod:WildboundText", config = "mod:WildboundEconomyConfig",
		spawnClock = "mod:WildboundSpawnClock", stamina = "mod:WildboundStamina", capture = "mod:WildboundCaptureSession",
		fairStrike = "mod:WildboundFairStrike", campView = "mod:WildboundCampView", economy = "mod:WildboundEconomy",
		state = "mod:WildboundState", record = "mod:WildboundRecord", training = "mod:WildboundTraining",
	},
}
SPECS["WildboundGuardianBrain_Test"] = { "mod:WildboundGuardianBrain", "mod:WildboundWorldRules", "src:WildboundGuardianBrain" }
SPECS["WildboundGuardianPath_Test"] = { "mod:WildboundGuardianPath", "src:WildboundGuardianPath" }
SPECS["WildboundGuardianSmoothing_Test"] = { "mod:WildboundGuardianSmoothing", "src:WildboundGuardianSmoothing" }
SPECS["WildboundHideWiring_Test"] = { "src:WildboundWorld", "src:WildboundServer", "src:WildboundWorldClient" }
SPECS["WildboundHide_Test"] = { "mod:WildboundHide" }
SPECS["WildboundHub_Test"] = {
	"mod:WildboundBases",
	"src:WildboundBases",
	{
		hub = "src:WildboundHub", stations = "src:WildboundHubStations", server = "src:WildboundServer",
		client = "src:WildboundClient", rules = "mod:WildboundWorldRules", builder = "mod:WildboundHubBuilder",
		text = "mod:WildboundText", keys = "mod:WildboundPromptKeys", builderSource = "src:WildboundHubBuilder",
	},
}
SPECS["WildboundHudLayout_Test"] = { "mod:WildboundHudLayout", "mod:WildboundHudView", "src:WildboundHudLayout", "mod:WildboundText" }
SPECS["WildboundHudView_Test"] = { "mod:WildboundHudView", "src:WildboundHudView", "mod:WildboundIslandLayout", "mod:WildboundWorldRules" }
SPECS["WildboundHunterWiring_Test"] = {
	{
		world = "src:WildboundWorld", worldClient = "src:WildboundWorldClient", fear = "src:WildboundFearClient",
		audio = "src:WildboundAudioClient", server = "src:WildboundServer",
	},
}
SPECS["WildboundHunters_Test"] = { "mod:WildboundHunters", "src:WildboundHunters" }
SPECS["WildboundIncubator_Test"] = {
	"mod:WildboundIncubator",
	"src:WildboundIncubator",
	{ server = "src:WildboundServer", client = "src:WildboundClient", text = "mod:WildboundText" },
}
SPECS["WildboundIslandWiring_Test"] = { "src:WildboundServer", "src:WildboundWorld", "src:WildboundClient" }
SPECS["WildboundIsland_Test"] = { "mod:WildboundIsland", "mod:WildboundIslandLayout" }
SPECS["WildboundLumipolArt_Test"] = {
	"mod:WildboundLumipolArt",
	"src:WildboundLumipolArt",
	{
		server = "src:WildboundServer", worldClient = "src:WildboundWorldClient", species = "mod:WildboundSpecies",
		assets = "inst:ServerStorage.WildboundAssets",
	},
}
SPECS["WildboundLumipolLook_Test"] = { "mod:WildboundLumipolLook", "src:WildboundLumipolLook" }
SPECS["WildboundLumipolWild_Test"] = {
	"mod:WildboundLumipolWild", "mod:WildboundWorldRules", "src:WildboundLumipolWild", "mod:WildboundRelief",
	"mod:WildboundReliefLayout",
}
SPECS["WildboundMechanicsWiring_Test"] = {
	{
		server = "src:WildboundServer", worldServer = "src:WildboundWorld", worldClient = "src:WildboundWorldClient",
		audio = "src:WildboundAudioClient", record = "src:WildboundRecord", save = "src:WildboundSave",
		arrulloService = "src:WildboundArrulloService", arrulloClient = "src:WildboundArrulloClient",
		dodgeService = "src:WildboundDodgeService", tuning = "src:WildboundTuning", text = "mod:WildboundText",
		schema = "mod:WildboundTuningSchema",
	},
}
SPECS["WildboundNestRefill_Test"] = { "mod:WildboundIsland", "mod:WildboundEggCarry", { server = "src:WildboundServer" } }
SPECS["WildboundOwnership_Test"] = { "mod:WildboundOwnership", "src:WildboundWorld", "src:WildboundWorldGuard" }
SPECS["WildboundPatrolWiring_Test"] = { "src:WildboundWorld" }
SPECS["WildboundPersistence_Test"] = {
	"mod:WildboundPersistence", "mod:WildboundRecord", "mod:WildboundFakePlayerStore", "mod:WildboundEconomy",
	"mod:WildboundEconomyConfig",
	{ persistence = "src:WildboundPersistence", record = "src:WildboundRecord", server = "src:WildboundServer" },
}
SPECS["WildboundPromptKeys_Test"] = { "mod:WildboundPromptKeys", "src:WildboundServer", "src:WildboundGather" }
SPECS["WildboundRecord_Test"] = {
	"mod:WildboundRecord", "mod:WildboundEconomy", "mod:WildboundEconomyConfig", "mod:WildboundState", "src:WildboundRecord",
}
SPECS["WildboundRefuge_Test"] = {
	"mod:WildboundRefuge",
	"src:WildboundRefuge",
	"mod:WildboundText",
	{
		server = "src:WildboundServer", world = "src:WildboundWorldClient", client = "src:WildboundClient",
		worldServer = "src:WildboundWorld",
	},
}
SPECS["WildboundReliefWiring_Test"] = { "src:WildboundWorld", "src:WildboundServer" }
SPECS["WildboundRelief_Test"] = { "mod:WildboundRelief", "mod:WildboundReliefLayout", "src:WildboundRelief" }
SPECS["WildboundSave_Test"] = {
	{
		Save = "mod:WildboundSave", Store = "mod:WildboundStoreRoblox", Persistence = "mod:WildboundPersistence",
		Record = "mod:WildboundRecord", State = "mod:WildboundState", Economy = "mod:WildboundEconomy",
		Config = "mod:WildboundEconomyConfig", Fake = "mod:WildboundFakePlayerStore",
	},
	{
		save = "src:WildboundSave", store = "src:WildboundStoreRoblox", server = "src:WildboundServer",
		persistence = "src:WildboundPersistence", record = "src:WildboundRecord", text = "src:WildboundText",
		startView = "src:WildboundStartView", campView = "src:WildboundCampView",
	},
}
SPECS["WildboundSettings_Test"] = {
	"mod:WildboundSettings",
	"src:WildboundSettings",
	"mod:WildboundText",
	{ world = "src:WildboundWorldClient", audio = "src:WildboundAudioClient" },
}
SPECS["WildboundSiluetaAwareness_Test"] = {
	"mod:WildboundSiluetaAwareness", "mod:WildboundSiluetaHunt", "mod:WildboundWorldRules", "src:WildboundSiluetaAwareness",
}
SPECS["WildboundSiluetaHunt_Test"] = { "mod:WildboundSiluetaHunt" }
SPECS["WildboundSiluetaMovesWiring_Test"] = {
	{ world = "src:WildboundWorld", server = "src:WildboundServer", audio = "src:WildboundAudioClient", text = "mod:WildboundText" },
	"mod:WildboundIsland",
}
SPECS["WildboundSiluetaMoves_Test"] = { "mod:WildboundSiluetaMoves", "src:WildboundSiluetaMoves" }
SPECS["WildboundSiluetaReworkWiring_Test"] = { "src:WildboundWorld", "mod:WildboundWorldRules", "mod:WildboundHide" }
SPECS["WildboundSiluetaStalk_Test"] = { "mod:WildboundSiluetaStalk", "src:WildboundSiluetaStalk" }
SPECS["WildboundSpawnClock_Test"] = {
	"mod:WildboundSpawnClock",
	"mod:WildboundSpawnGraph",
	"mod:WildboundSpecies",
	"src:WildboundSpawnClock",
	{ server = "src:WildboundServer", text = "mod:WildboundText" },
}
SPECS["WildboundSpawn_Test"] = { "mod:WildboundSpawn", "mod:WildboundEconomyConfig", "src:WildboundSpawn", "mod:WildboundWorldRules" }
SPECS["WildboundSpecies_Test"] = { "mod:WildboundSpecies", "mod:WildboundIslandLayout", "src:WildboundSpecies" }
SPECS["WildboundStaminaWiring_Test"] = { "src:WildboundServer", "src:WildboundWorld", "src:WildboundWorldClient", "mod:WildboundText" }
SPECS["WildboundStamina_Test"] = { "mod:WildboundStamina" }
SPECS["WildboundStartView_Test"] = {
	"mod:WildboundStartView", "mod:WildboundHudLayout", "mod:WildboundSettings", "mod:WildboundTutorial", "src:WildboundStartView",
}
SPECS["WildboundStartWiring_Test"] = { "src:WildboundWorldClient", "src:WildboundClient", "src:WildboundStartClient" }
SPECS["WildboundState_Test"] = { "mod:WildboundState", "mod:WildboundEconomy", "mod:WildboundEconomyConfig" }
SPECS["WildboundText_Test"] = {
	"mod:WildboundText",
	"src:WildboundText",
	{
		-- The header names the first four; the NB3 cases also read the six below (see the suite's NB3 comment).
		capture = "src:WildboundCaptureSession", view = "src:WildboundCaptureView", client = "src:WildboundCaptureClient",
		server = "src:WildboundServer", inventory = "src:WildboundClient", world = "src:WildboundWorldClient",
		worldServer = "src:WildboundWorld", gather = "src:WildboundGather", hudView = "src:WildboundHudView",
		campView = "src:WildboundCampView",
	},
}
SPECS["WildboundThreatLevel_Test"] = { "mod:WildboundThreatLevel" }
SPECS["WildboundTotemRecord_Test"] = { "mod:WildboundTotemRecord", "mod:WildboundRecord", "src:WildboundTotemRecord" }
SPECS["WildboundTraining_Test"] = {
	"mod:WildboundTraining",
	"src:WildboundTraining",
	{
		state = "mod:WildboundState", economy = "mod:WildboundEconomy", config = "mod:WildboundEconomyConfig",
		stamina = "mod:WildboundStamina", schema = "mod:WildboundTuningSchema", keys = "mod:WildboundPromptKeys",
		text = "mod:WildboundText", server = "src:WildboundServer", bridge = "src:WildboundTuning",
		treadmill = "src:WildboundTreadmillService", record = "mod:WildboundRecord",
	},
}
SPECS["WildboundTuningWiring_Test"] = {
	{
		bridge = "src:WildboundTuning", panel = "src:WildboundTuningClient", server = "src:WildboundServer",
		world = "src:WildboundWorld",
	},
}
SPECS["WildboundTuning_Test"] = { "mod:WildboundTuningSchema", "tuning:modules" }
SPECS["WildboundTutorial_Test"] = { "mod:WildboundTutorial", "src:WildboundTutorial" }
SPECS["WildboundWaveClock_Test"] = {
	"mod:WildboundWaveClock",
	"src:WildboundWaveClock",
	{
		server = "src:WildboundServer", client = "src:WildboundClient", text = "mod:WildboundText",
		rules = "mod:WildboundWorldRules", stamina = "mod:WildboundStamina", world = "src:WildboundWorld",
		worldClient = "src:WildboundWorldClient", atmosphere = "mod:WildboundAtmosphere", view = "mod:WildboundHudView",
	},
}
SPECS["WildboundWorldRules_Test"] = { "mod:WildboundWorldRules", "mod:WildboundIslandLayout" }

-- Modules that require a sibling by script.Parent: the sibling is cloned into the same per-suite folder first.
-- tools/test_studio_fresh_runner.py fails when a ModuleScript in src/wildbound requires a sibling not listed here.
local SIBLINGS = {
	WildboundRecord = { "WildboundTotemRecord", "WildboundFarmRecord", "WildboundRouletteRecord" },
	WildboundCaptureView = { "WildboundText" }, -- require(script.Parent:WaitForChild("WildboundText")) would yield forever
	WildboundRouletteService = { "WildboundFlags" }, -- RW-4: the development switch DESBLOQUEAR_TODO
	-- The candy critter clip data modules require script.Parent.WildboundCandyClipKit.
	WildboundCandyCritterClipsDuquesaBurbuja = { "WildboundCandyClipKit" },
	WildboundCandyCritterClipsMochimiau = { "WildboundCandyClipKit" },
	WildboundCandyCritterClipsCanelin = { "WildboundCandyClipKit" },
	WildboundCandyCritterClipsFlanin = { "WildboundCandyClipKit" },
	WildboundCandyCritterClipsMielita = { "WildboundCandyClipKit" },
	WildboundCandyCritterClipsGatoRepartidor = { "WildboundCandyClipKit" },
}
local SUITE_TIMEOUT = 30 -- seconds; a suite still yielding after this is cancelled and reported as TIMEOUT
local RUN_PREFIX = "WildboundFreshRunner_" -- each run's temporary folder is RUN_PREFIX .. run id
local LOCK_ATTRIBUTE = "WildboundFreshRunnerLock" -- ServerStorage attribute "<run id>@<os.time()>" while a run is active
local LOCK_STALE = 900 -- seconds without a heartbeat after which a lock is treated as left by a dead run
local REDIRECTED = { ReplicatedStorage = true, ServerScriptService = true, ServerStorage = true, StarterPlayer = true }

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local CONTAINERS = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	ServerStorage,
	game:GetService("StarterPlayer"),
}
local LOADER = type(loadstring) == "function" and type(setfenv) == "function" and type(getfenv) == "function"
local BASE_ENV = getfenv(1)

-- Backup copies ("...Backup...", or a name ending in a date such as _20261107 or 2026-11-07) and any runner's temporary
-- folder are never picked as originals.
local function excluded(item)
	local node = item
	while node and node ~= game do
		local name = node.Name
		if string.find(string.lower(name), "backup", 1, true) or string.match(name, "%d%d%d%d%d%d%d%d$")
			or string.match(name, "%d%d%d%d%-%d%d%-%d%d") or string.sub(name, 1, #RUN_PREFIX) == RUN_PREFIX then
			return true
		end
		node = node.Parent
	end
	return false
end

local scriptIndex, moduleIndex = {}, {}
local function buildIndex()
	for _, container in ipairs(CONTAINERS) do
		for _, item in ipairs(container:GetDescendants()) do
			if item:IsA("LuaSourceContainer") and not excluded(item) then
				scriptIndex[item.Name] = scriptIndex[item.Name] or item
				if item:IsA("ModuleScript") then moduleIndex[item.Name] = moduleIndex[item.Name] or item end
			end
		end
	end
end

local function findScript(name, moduleOnly)
	if moduleOnly then return moduleIndex[name] end
	return scriptIndex[name]
end

-- A WaitForChild/FindFirstChild("Wildbound...") that is not on script.Parent: a service-path require. Used only when
-- the loader is unavailable, to mark those results SUSPECT_CACHE.
local function hasServicePathRequire(source)
	for start in string.gmatch(source, "():%s*[WF]%a+Child%(%s*[\"']Wildbound") do
		local before = string.sub(source, math.max(1, start - 40), start)
		if not string.find(before, "script.Parent", 1, true) then return true end
	end
	return false
end

-- A read-only stand-in for a real Instance: overrides first, then lookup(name) for children and indexed names, then
-- the real member (methods are rebound to the real Instance; proxy arguments are unwrapped).
local realOf = setmetatable({}, { __mode = "k" })
local function unwrap(...)
	local args = table.pack(...)
	for index = 1, args.n do
		if type(args[index]) == "table" and realOf[args[index]] then args[index] = realOf[args[index]] end
	end
	return table.unpack(args, 1, args.n)
end
local function wrapInstance(real, lookup, overrides)
	local proxy = {}
	realOf[proxy] = real
	setmetatable(proxy, {
		__index = function(_, key)
			if overrides and overrides[key] then return overrides[key] end
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_self, child, ...)
					local swap = lookup(child)
					if swap ~= nil then return swap end
					return real[key](real, child, unwrap(...))
				end
			end
			if type(key) == "string" then
				local swap = lookup(key)
				if swap ~= nil then return swap end
			end
			local value = real[key]
			if type(value) == "function" then
				return function(self, ...)
					if self == proxy then return value(real, unwrap(...)) end
					return value(self, unwrap(...))
				end
			end
			return value
		end,
		__newindex = function() error("the fresh runner's stand-ins are read-only", 2) end,
		__tostring = function() return tostring(real) end,
	})
	return proxy
end

local function makeSuite(folder)
	local clones, results, done, loading = {}, {}, {}, {}
	local suite = { redirected = {}, servicePath = false }

	local function cloneInto(name)
		if clones[name] then return clones[name] end
		local existing = folder:FindFirstChild(name)
		if existing then
			clones[name] = existing
			return existing
		end
		local module = findScript(name, true)
		if not module then error("module not found: " .. name, 0) end
		local clone = module:Clone()
		clone.Parent = folder
		clones[name] = clone
		return clone
	end

	-- A Wildbound ModuleScript reached through a redirected service is this suite's fresh clone.
	local function serviceChild(child)
		if type(child) == "string" and string.match(child, "^Wildbound") and findScript(child, true) then
			suite.redirected[child] = true
			return cloneInto(child)
		end
		return nil
	end
	local services = {}
	local fakeGame
	local function fakeService(name)
		services[name] = services[name] or wrapInstance(game:GetService(name), serviceChild)
		return services[name]
	end
	local function getService(_, name)
		if REDIRECTED[name] then return fakeService(name) end
		return game:GetService(name)
	end
	fakeGame = wrapInstance(game, function(name)
		if REDIRECTED[name] then return fakeService(name) end
		return nil
	end, { GetService = getService, FindService = getService })

	local function scriptProxy(clone)
		local function ancestorOf(_, class)
			if class == "DataModel" then return fakeGame end
			return clone:FindFirstAncestorOfClass(class)
		end
		local function ancestorWhichIsA(_, class)
			if class == "DataModel" or class == "ServiceProvider" then return fakeGame end
			return clone:FindFirstAncestorWhichIsA(class)
		end
		return wrapInstance(clone, function() return nil end, {
			FindFirstAncestorOfClass = ancestorOf, FindFirstAncestorWhichIsA = ancestorWhichIsA,
		})
	end

	local load
	local function customRequire(target)
		if type(target) == "table" and realOf[target] then target = realOf[target] end
		if typeof(target) == "Instance" and target:IsA("ModuleScript") then
			if target:IsDescendantOf(folder) then return load(target) end
			if string.match(target.Name, "^Wildbound") and findScript(target.Name, true) then
				suite.redirected[target.Name] = true
				return load(cloneInto(target.Name))
			end
		end
		return require(target)
	end

	-- Runs a clone's Source once per suite with game, script and require pointing at this suite's clones, so every
	-- Wildbound module it reaches (by service path, by DataModel or by script.Parent) is fresh. Source is never edited.
	load = function(clone)
		if done[clone] then return results[clone] end
		if loading[clone] then error("cyclic require of " .. clone.Name, 0) end
		loading[clone] = true
		for _, sibling in ipairs(SIBLINGS[clone.Name] or {}) do cloneInto(sibling) end
		local value
		if LOADER then
			local chunk, problem = loadstring(clone.Source, "=" .. clone.Name)
			if not chunk then error(problem, 0) end
			setfenv(chunk, setmetatable({
				game = fakeGame, Game = fakeGame, script = scriptProxy(clone), require = customRequire,
			}, { __index = BASE_ENV }))
			local returned = table.pack(chunk())
			if returned.n ~= 1 then error(clone.Name .. ": module code did not return exactly one value", 0) end
			value = returned[1]
		else
			if hasServicePathRequire(clone.Source) then suite.servicePath = true end
			value = require(clone)
		end
		loading[clone], done[clone], results[clone] = nil, true, value
		return value
	end

	local function fresh(name)
		return load(cloneInto(name))
	end

	local function source(name)
		if clones[name] then return clones[name].Source end
		local original = findScript(name, false)
		if not original then error("script not found: " .. name, 0) end
		return original.Source
	end

	local function instance(path)
		local parts = string.split(path, ".")
		local node = game:GetService(parts[1])
		for index = 2, #parts do
			node = node and node:FindFirstChild(parts[index])
		end
		if not node then error("instance not found: " .. path, 0) end
		return node
	end

	local build
	build = function(token)
		if type(token) == "table" then
			local out = {}
			for key, value in pairs(token) do out[key] = build(value) end
			return out
		end
		local kind, value = string.match(token, "^(%a+):(.+)$")
		if kind == "mod" then return fresh(value) end
		if kind == "src" then return source(value) end
		if kind == "inst" then return instance(value) end
		if kind == "tuning" and value == "modules" then
			local Schema = fresh("WildboundTuningSchema")
			local modules = {}
			for key, entry in pairs(Schema.MODULES) do modules[key] = fresh(entry.name) end
			return modules
		end
		error("unknown spec token: " .. tostring(token), 0)
	end

	suite.build, suite.load = build, load
	return suite
end

-- Run lock: one active run per place. A lock whose heartbeat is older than LOCK_STALE was left by a dead run.
local runId = string.sub(HttpService:GenerateGUID(false), 1, 8)
local held = ServerStorage:GetAttribute(LOCK_ATTRIBUTE)
local heldAt = type(held) == "string" and tonumber(string.match(held, "@(%d+)$")) or nil
if heldAt and os.time() - heldAt < LOCK_STALE then
	local refusal = string.format("[WildboundFreshRunner] LOCKED: another run holds %s = %s; nothing was run", LOCK_ATTRIBUTE, held)
	print(refusal)
	return refusal
end
local function heartbeat()
	ServerStorage:SetAttribute(LOCK_ATTRIBUTE, runId .. "@" .. os.time())
end
heartbeat()
-- No live run holds the lock, so any earlier runner folder (including the old fixed "WildboundFreshRunner_Tmp") is dead.
local cleared = {}
for _, child in ipairs(ServerStorage:GetChildren()) do
	if string.sub(child.Name, 1, #RUN_PREFIX) == RUN_PREFIX then
		table.insert(cleared, child.Name)
		child:Destroy()
	end
end
local tmp = Instance.new("Folder")
tmp.Name = RUN_PREFIX .. runId
tmp.Parent = ServerStorage

-- Suites may only build fixtures inside the temporary folder: anything new at the top of these services is reported.
local WATCHED = { workspace, ServerStorage, game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService") }
local function topLevel()
	local seen = {}
	for _, service in ipairs(WATCHED) do
		for _, child in ipairs(service:GetChildren()) do seen[child] = true end
	end
	return seen
end

local totals = { passed = 0, failed = 0 }
local groups = { PASS = {}, FAIL = {}, SUSPECT_CACHE = {}, TIMEOUT = {}, SKIPPED = {} }
local unspecified, absent, leaks = {}, {}, {}

local function summary(name, outcome)
	local line = string.format("%s: %d passed, %d failed", name, outcome.passed, outcome.failed)
	if outcome.failed > 0 and type(outcome.messages) == "table" then
		for index = 1, math.min(2, #outcome.messages) do
			line ..= "\n    " .. tostring(outcome.messages[index]):sub(1, 220)
		end
	end
	return line
end

local function counted(outcome)
	return type(outcome) == "table" and type(outcome.passed) == "number" and type(outcome.failed) == "number"
end

local ran, problem = pcall(function()
	buildIndex()
	local tests, present = {}, {}
	for _, child in ipairs(ServerStorage:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("^Wildbound.*_Test$") and (FILTER == nil or child.Name:match(FILTER)) then
			table.insert(tests, child)
			present[child.Name] = true
		end
	end
	for name in pairs(SPECS) do
		if not present[name] and (FILTER == nil or name:match(FILTER)) then table.insert(absent, name) end
	end
	table.sort(absent)
	table.sort(tests, function(a, b) return a.Name < b.Name end)
	for _, test in ipairs(tests) do
		if SKIP[test.Name] then
			table.insert(groups.SKIPPED, test.Name .. " (" .. SKIP[test.Name] .. ")")
		elseif not SPECS[test.Name] then
			table.insert(unspecified, test.Name)
		else
			heartbeat()
			local before = topLevel()
			local folder = Instance.new("Folder")
			folder.Name = test.Name
			folder.Parent = tmp
			local finished, ok, outcome, suite = false, false, nil, nil
			local thread = task.spawn(function()
				ok, outcome = pcall(function()
					suite = makeSuite(folder)
					local args = {}
					for index, token in ipairs(SPECS[test.Name]) do args[index] = suite.build(token) end
					local clone = test:Clone()
					clone.Parent = folder
					return suite.load(clone)(table.unpack(args, 1, #SPECS[test.Name]))
				end)
				finished = true
			end)
			local started = os.clock()
			while not finished and os.clock() - started < SUITE_TIMEOUT do task.wait(0.1) end
			if not finished then
				-- Cancelled while yielding; threads the suite itself spawned or delayed are not reachable from here.
				pcall(task.cancel, thread)
				table.insert(groups.TIMEOUT, string.format("%s: cancelled after %d s (it was still yielding)", test.Name, SUITE_TIMEOUT))
			elseif suite and suite.servicePath then
				table.insert(groups.SUSPECT_CACHE, ok and counted(outcome) and summary(test.Name, outcome)
					or (test.Name .. ": ERROR " .. tostring(outcome):sub(1, 300)))
			elseif ok and counted(outcome) then
				totals.passed += outcome.passed
				totals.failed += outcome.failed
				table.insert(outcome.failed == 0 and groups.PASS or groups.FAIL, summary(test.Name, outcome))
			else
				table.insert(groups.FAIL, string.format("%s: ERROR %s", test.Name, tostring(outcome):sub(1, 300)))
			end
			folder:Destroy()
			for _, service in ipairs(WATCHED) do
				for _, child in ipairs(service:GetChildren()) do
					if not before[child] and child ~= tmp then
						table.insert(leaks, test.Name .. " left " .. child:GetFullName() .. " (not removed by the runner)")
					end
				end
			end
			task.wait()
		end
	end
end)

tmp:Destroy()
local lock = ServerStorage:GetAttribute(LOCK_ATTRIBUTE)
if type(lock) == "string" and string.sub(lock, 1, #runId + 1) == runId .. "@" then
	ServerStorage:SetAttribute(LOCK_ATTRIBUTE, nil)
end

local function section(name, list, separator)
	return string.format("%s (%d):\n%s", name, #list, table.concat(list, separator or "\n"))
end
local report = table.concat({
	string.format(
		"run %s, loader %s: suites PASS %d, FAIL %d, SUSPECT_CACHE %d, TIMEOUT %d, SKIPPED %d; cases (PASS+FAIL only) passed %d, failed %d%s",
		runId, LOADER and "fresh (every Wildbound require is a per-suite clone)" or "UNAVAILABLE (service-path results are SUSPECT_CACHE)",
		#groups.PASS, #groups.FAIL, #groups.SUSPECT_CACHE, #groups.TIMEOUT, #groups.SKIPPED, totals.passed, totals.failed,
		ran and "" or ("; runner error: " .. tostring(problem))),
	section("FAIL", groups.FAIL),
	section("SUSPECT_CACHE (not in the totals; run these in Play or after reopening the place)", groups.SUSPECT_CACHE),
	section("TIMEOUT (not in the totals)", groups.TIMEOUT),
	section("PASS", groups.PASS, "; "),
	section("SKIPPED", groups.SKIPPED, "; "),
	section("LEAKS outside the temporary folder", leaks),
	"UNSPECIFIED (not run): " .. table.concat(unspecified, ", "),
	"specified but not in ServerStorage: " .. table.concat(absent, ", "),
	"dead runner folders cleared at start: " .. table.concat(cleared, ", "),
}, "\n")
-- A full run can outlast the MCP request timeout; the report is also printed so get_console_output can read it.
print("[WildboundFreshRunner]\n" .. report)
return report
