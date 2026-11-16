"""Deployment manifest: repository Luau source -> Roblox Explorer path + SHA-256.

Deployment to Studio is manual, so local source can drift from what is really
in the place. This tool records, for every mapped source file, its Explorer
destination and a content hash, so a later session can compare a Studio
`Script.Source` hash against it. It never talks to Studio.

Hash rule: read bytes, normalize CRLF to LF, strip trailing newlines, SHA-256.
Studio normalizes line endings, so checkout line endings must not matter.

Usage (from the project root; prints JSON to stdout, writes nothing):

    python -I -B tools/deploy_manifest.py
    python -I -B tools/deploy_manifest.py --output manifest.json   # explicit only
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("src", "tests", "tools")

# Local source -> Explorer path. Every row is backed by a document or a
# Studio observation; nothing here is guessed.
DEFAULT_MAPPINGS = [
    # docs/testing/wildbound-p0.md (Source-to-Explorer mapping)
    ("tools/build-wildbound-p0-map.luau", "ServerStorage.WildboundP0MapBuilder"),
    ("src/wildbound/WildboundState.luau", "ServerScriptService.WildboundState"),
    ("src/wildbound/WildboundServer.server.luau", "ServerScriptService.WildboundServer"),
    (
        "src/wildbound/WildboundClient.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundClient",
    ),
    ("tests/WildboundState_Test.luau", "ServerStorage.WildboundState_Test"),
    ("tests/WildboundP0Map_Test.luau", "ServerStorage.WildboundP0Map_Test"),
    # docs/testing/wildbound-world.md (Source-to-Explorer mapping)
    ("src/wildbound/WildboundWorldRules.luau", "ServerScriptService.WildboundWorldRules"),
    ("src/wildbound/WildboundWorld.server.luau", "ServerScriptService.WildboundWorld"),
    (
        "src/wildbound/WildboundWorld.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundWorldClient",
    ),
    # docs/testing/silueta-visual-adapter.md (Visual); Hunt is Studio-observed only
    ("src/wildbound/WildboundSiluetaVisual.luau", "ServerScriptService.WildboundSiluetaVisual"),
    ("src/wildbound/WildboundSiluetaHunt.luau", "ServerScriptService.WildboundSiluetaHunt"),
    # odd/tasks/wildbound-first-playable.md (World rules test destination)
    ("tests/WildboundWorldRules_Test.luau", "ServerStorage.WildboundWorldRules_Test"),
    # README.md (earlier Rescue prototype install steps)
    ("src/server/RescueState.luau", "ServerScriptService.RescueState"),
    ("src/server/RescueServer.server.luau", "ServerScriptService.RescueServer"),
    (
        "src/client/RescueClient.client.luau",
        "StarterPlayer.StarterPlayerScripts.RescueClient",
    ),
    # Forest dress unit; the files may not exist yet and are then reported missing
    ("tools/dress-wildbound-forest.luau", "ServerStorage.WildboundForestDress"),
    ("tests/WildboundForestDress_Test.luau", "ServerStorage.WildboundForestDress_Test"),
    # docs/mechanics/wildbound-awareness.md and Studio observation (M2.1)
    ("src/wildbound/WildboundSiluetaAwareness.luau", "ServerScriptService.WildboundSiluetaAwareness"),
    ("tests/WildboundSiluetaAwareness_Test.luau", "ServerStorage.WildboundSiluetaAwareness_Test"),
    # M2.6, wave W3b: pure client smoothing, shared so the client script can require it
    ("src/wildbound/WildboundGuardianSmoothing.luau", "ReplicatedStorage.WildboundGuardianSmoothing"),
    ("tests/WildboundGuardianSmoothing_Test.luau", "ServerStorage.WildboundGuardianSmoothing_Test"),
    # M2.3 and the compact phone HUD, wave W3b: pure layout and view rules the clients require
    ("src/wildbound/WildboundHudLayout.luau", "ReplicatedStorage.WildboundHudLayout"),
    ("tests/WildboundHudLayout_Test.luau", "ServerStorage.WildboundHudLayout_Test"),
    ("src/wildbound/WildboundHudView.luau", "ReplicatedStorage.WildboundHudView"),
    ("tests/WildboundHudView_Test.luau", "ServerStorage.WildboundHudView_Test"),
    # M3.2, wave W5: pure capture rule, shared because the client draws the ring from it
    ("src/wildbound/WildboundCaptureSession.luau", "ReplicatedStorage.WildboundCaptureSession"),
    ("tests/WildboundCaptureSession_Test.luau", "ServerStorage.WildboundCaptureSession_Test"),
    # M3.3 to M3.5, wave W5: server-only wild rules, the shared capture view and the touch client
    ("src/wildbound/WildboundLumipolWild.luau", "ServerScriptService.WildboundLumipolWild"),
    ("tests/WildboundLumipolWild_Test.luau", "ServerStorage.WildboundLumipolWild_Test"),
    ("src/wildbound/WildboundCaptureView.luau", "ReplicatedStorage.WildboundCaptureView"),
    ("tests/WildboundCaptureView_Test.luau", "ServerStorage.WildboundCaptureView_Test"),
    (
        "src/wildbound/WildboundCapture.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundCaptureClient",
    ),
    # M4.2 to M4.7, wave W6: server-only damage flag and pure fair-strike rules
    ("src/wildbound/WildboundFlags.luau", "ServerScriptService.WildboundFlags"),
    ("src/wildbound/WildboundFairStrike.luau", "ServerScriptService.WildboundFairStrike"),
    ("tests/WildboundFairStrike_Test.luau", "ServerStorage.WildboundFairStrike_Test"),
    # M4.7, wave W6: pure ambush relocation with no camera or gaze input
    ("src/wildbound/WildboundAmbush.luau", "ServerScriptService.WildboundAmbush"),
    ("tests/WildboundAmbush_Test.luau", "ServerStorage.WildboundAmbush_Test"),
    # M5.2, M5.4, M5.5, wave W7: generated tuning copy and pure economy rules are shared, so the
    # camp screen can show costs; the seeded spawn pipeline stays on the server
    ("src/wildbound/WildboundEconomyConfig.luau", "ReplicatedStorage.WildboundEconomyConfig"),
    ("src/wildbound/WildboundEconomy.luau", "ReplicatedStorage.WildboundEconomy"),
    ("tests/WildboundEconomy_Test.luau", "ServerStorage.WildboundEconomy_Test"),
    ("src/wildbound/WildboundSpawn.luau", "ServerScriptService.WildboundSpawn"),
    ("tests/WildboundSpawn_Test.luau", "ServerStorage.WildboundSpawn_Test"),
    # M5.3, wave W7 part 2: pure gather-field rules (server only) and the script that draws the world nodes
    ("src/wildbound/WildboundGatherField.luau", "ServerScriptService.WildboundGatherField"),
    ("src/wildbound/WildboundGather.server.luau", "ServerScriptService.WildboundGather"),
    ("tests/WildboundGatherField_Test.luau", "ServerStorage.WildboundGatherField_Test"),
    # M5.8, wave W7 part 2: pure camp screen, loss line and compass rules the inventory client requires
    ("src/wildbound/WildboundCampView.luau", "ReplicatedStorage.WildboundCampView"),
    ("tests/WildboundCampView_Test.luau", "ServerStorage.WildboundCampView_Test"),
    # M6.1 and M6.2, wave W10: server-only record and persistence sessions; the fake store is a test double
    ("src/wildbound/WildboundRecord.luau", "ServerScriptService.WildboundRecord"),
    ("tests/WildboundRecord_Test.luau", "ServerStorage.WildboundRecord_Test"),
    ("src/wildbound/WildboundPersistence.luau", "ServerScriptService.WildboundPersistence"),
    ("tests/WildboundPersistence_Test.luau", "ServerStorage.WildboundPersistence_Test"),
    ("tests/WildboundFakePlayerStore.luau", "ServerStorage.WildboundFakePlayerStore"),
    ("tests/WildboundFakePlayerStore_Test.luau", "ServerStorage.WildboundFakePlayerStore_Test"),
    # M9.5, wave W16: server-only analytics event seam
    ("src/wildbound/WildboundAnalytics.luau", "ServerScriptService.WildboundAnalytics"),
    ("tests/WildboundAnalytics_Test.luau", "ServerStorage.WildboundAnalytics_Test"),
    ("src/wildbound/WildboundFunnel.luau", "ServerScriptService.WildboundFunnel"),
    ("tests/WildboundFunnel_Test.luau", "ServerStorage.WildboundFunnel_Test"),
    ("tests/WildboundAnalyticsWiring_Test.luau", "ServerStorage.WildboundAnalyticsWiring_Test"),
    # Delivery A, capture redesign: the shared Spanish text module (H3)
    ("src/wildbound/WildboundText.luau", "ReplicatedStorage.WildboundText"),
    ("tests/WildboundText_Test.luau", "ServerStorage.WildboundText_Test"),
    # Delivery A3: pure smoothing and mood cues for the client's local Lumipol copy
    ("src/wildbound/WildboundLumipolLook.luau", "ReplicatedStorage.WildboundLumipolLook"),
    ("tests/WildboundLumipolLook_Test.luau", "ServerStorage.WildboundLumipolLook_Test"),
    # Delivery B2: pure carried-creature mood, movement, sound hook and HUD line rules, shared with the clients
    ("src/wildbound/WildboundCarry.luau", "ReplicatedStorage.WildboundCarry"),
    ("tests/WildboundCarry_Test.luau", "ServerStorage.WildboundCarry_Test"),
    # Delivery B3 to B5: pure camp rules (deposit, card, display spots, companion offset), shared with the clients
    ("src/wildbound/WildboundRefuge.luau", "ReplicatedStorage.WildboundRefuge"),
    ("tests/WildboundRefuge_Test.luau", "ServerStorage.WildboundRefuge_Test"),
    # Delivery C1: pure guardian brain (suspicion, noises, search, day and night profiles), server only
    ("src/wildbound/WildboundGuardianBrain.luau", "ServerScriptService.WildboundGuardianBrain"),
    ("tests/WildboundGuardianBrain_Test.luau", "ServerStorage.WildboundGuardianBrain_Test"),
    # Delivery C2: pure route following around the solid trunk cores, server only
    ("src/wildbound/WildboundGuardianPath.luau", "ServerScriptService.WildboundGuardianPath"),
    ("tests/WildboundGuardianPath_Test.luau", "ServerStorage.WildboundGuardianPath_Test"),
    # Delivery D1: pure whole-map fog and light targets, shared because the world client applies them
    ("src/wildbound/WildboundAtmosphere.luau", "ReplicatedStorage.WildboundAtmosphere"),
    ("tests/WildboundAtmosphere_Test.luau", "ServerStorage.WildboundAtmosphere_Test"),
    # odd/tasks/wildbound-caramelo.md CA4: fixed light per biome (no global day/night cycle)
    ("src/wildbound/WildboundBiomeLight.luau", "ReplicatedStorage.WildboundBiomeLight"),
    ("tests/WildboundBiomeLight_Test.luau", "ServerStorage.WildboundBiomeLight_Test"),
    # CF1 (odd/tasks/wildbound-caramelo.md): the per-place gameplay phase.
    ("tests/WildboundPlacePhase_Test.luau", "ServerStorage.WildboundPlacePhase_Test"),
    # Delivery D5: pure hiding rules (entry, discovery dwell, exit), server only
    ("src/wildbound/WildboundHide.luau", "ServerScriptService.WildboundHide"),
    ("tests/WildboundHide_Test.luau", "ServerStorage.WildboundHide_Test"),
    # Delivery D8: pure per-player threat bucket with held falls, server only
    ("src/wildbound/WildboundThreatLevel.luau", "ServerScriptService.WildboundThreatLevel"),
    ("tests/WildboundThreatLevel_Test.luau", "ServerStorage.WildboundThreatLevel_Test"),
    # Delivery D6 and D8: source contracts for the hiding, threat and clock wiring
    ("tests/WildboundHideWiring_Test.luau", "ServerStorage.WildboundHideWiring_Test"),
    # Delivery D9: the audio catalog (every id in one place) and the pure mix, shared with the audio client
    ("src/wildbound/WildboundAudioCatalog.luau", "ReplicatedStorage.WildboundAudioCatalog"),
    ("src/wildbound/WildboundAudioMix.luau", "ReplicatedStorage.WildboundAudioMix"),
    ("tests/WildboundAudioMix_Test.luau", "ServerStorage.WildboundAudioMix_Test"),
    # Delivery D10: the horror audio controller and its source contracts
    (
        "src/wildbound/WildboundAudio.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundAudioClient",
    ),
    ("tests/WildboundAudioWiring_Test.luau", "ServerStorage.WildboundAudioWiring_Test"),
    # Dread pass, unit 1: pure stamina, sprint and its costs (server only), and its wiring contracts
    ("src/wildbound/WildboundStamina.luau", "ServerScriptService.WildboundStamina"),
    ("tests/WildboundStamina_Test.luau", "ServerStorage.WildboundStamina_Test"),
    ("tests/WildboundStaminaWiring_Test.luau", "ServerStorage.WildboundStaminaWiring_Test"),
    # Expedition relief, R2: the pure height rule (server only)
    ("src/wildbound/WildboundRelief.luau", "ServerScriptService.WildboundRelief"),
    ("tests/WildboundRelief_Test.luau", "ServerStorage.WildboundRelief_Test"),
    # Expedition relief, R5: source contracts for the guardian and creatures on the relief
    ("tests/WildboundReliefWiring_Test.luau", "ServerStorage.WildboundReliefWiring_Test"),
    # Expedition islands, I1: the island layout generated by tools/plan_islands.py (server only)
    ("src/wildbound/WildboundIslandLayout.luau", "ServerScriptService.WildboundIslandLayout"),
    # Expedition islands, I2: the pure island rule (server only)
    ("src/wildbound/WildboundIsland.luau", "ServerScriptService.WildboundIsland"),
    ("tests/WildboundIsland_Test.luau", "ServerStorage.WildboundIsland_Test"),
    # Expedition islands, I8: species stand-ins in one module (shared with the clients)
    ("src/wildbound/WildboundSpecies.luau", "ReplicatedStorage.WildboundSpecies"),
    ("tests/WildboundSpecies_Test.luau", "ServerStorage.WildboundSpecies_Test"),
    # Expedition islands, I6: source contracts for the island wiring
    ("tests/WildboundIslandWiring_Test.luau", "ServerStorage.WildboundIslandWiring_Test"),
    # Dev tuning, DT1 to DT4: the shared schema, the server bridge, the developer panel and their suites
    ("src/wildbound/WildboundTuningSchema.luau", "ReplicatedStorage.WildboundTuningSchema"),
    ("src/wildbound/WildboundTuning.server.luau", "ServerScriptService.WildboundTuning"),
    (
        "src/wildbound/WildboundTuning.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundTuningClient",
    ),
    ("tests/WildboundTuning_Test.luau", "ServerStorage.WildboundTuning_Test"),
    ("tests/WildboundTuningWiring_Test.luau", "ServerStorage.WildboundTuningWiring_Test"),
    # Fear pass, FA3: the adrenaline burst and hit feedback client and its source contracts
    ("src/wildbound/WildboundFear.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundFearClient"),
    ("tests/WildboundFearWiring_Test.luau", "ServerStorage.WildboundFearWiring_Test"),
    # Next batch NB4 (delivery E): the pure incubator timer, shared with the Bag tab, and its suite
    ("src/wildbound/WildboundIncubator.luau", "ReplicatedStorage.WildboundIncubator"),
    ("tests/WildboundIncubator_Test.luau", "ServerStorage.WildboundIncubator_Test"),
    # Fix pass FP2: the pure roster of per-player hunters (server only) and the wiring contracts
    ("src/wildbound/WildboundHunters.luau", "ServerScriptService.WildboundHunters"),
    ("tests/WildboundHunters_Test.luau", "ServerStorage.WildboundHunters_Test"),
    ("tests/WildboundHunterWiring_Test.luau", "ServerStorage.WildboundHunterWiring_Test"),
    # Fix pass FP4: La Silueta's moves (lunge, fake retreat, glare, scream), pure and server only, and their suites
    ("src/wildbound/WildboundSiluetaMoves.luau", "ServerScriptService.WildboundSiluetaMoves"),
    ("tests/WildboundSiluetaMoves_Test.luau", "ServerStorage.WildboundSiluetaMoves_Test"),
    ("tests/WildboundSiluetaMovesWiring_Test.luau", "ServerStorage.WildboundSiluetaMovesWiring_Test"),
    # Random world RW1: the spawn graph generated by tools/plan_spawn_graph.py (server only)
    ("src/wildbound/WildboundSpawnGraph.luau", "ServerScriptService.WildboundSpawnGraph"),
    # Random world RW2: the pure spawn clock (server only) and its suite
    ("src/wildbound/WildboundSpawnClock.luau", "ServerScriptService.WildboundSpawnClock"),
    ("tests/WildboundSpawnClock_Test.luau", "ServerStorage.WildboundSpawnClock_Test"),
    # Random world RW3 to RW6: the pure wave clock (shared, the client reads WorldEvent through it) and its suite
    ("src/wildbound/WildboundWaveClock.luau", "ReplicatedStorage.WildboundWaveClock"),
    ("tests/WildboundWaveClock_Test.luau", "ServerStorage.WildboundWaveClock_Test"),
    # Items and totem (plan Part 4): the pure gear rules (shared, the fear client softens with them) and their suite
    ("src/wildbound/WildboundGear.luau", "ReplicatedStorage.WildboundGear"),
    ("tests/WildboundGear_Test.luau", "ServerStorage.WildboundGear_Test"),
    # MeshGen1 pass: dresses every Lumipol with the user's model (server only) and its suite
    ("src/wildbound/WildboundLumipolArt.luau", "ServerScriptService.WildboundLumipolArt"),
    ("tests/WildboundLumipolArt_Test.luau", "ServerStorage.WildboundLumipolArt_Test"),
    # Nest Heist phase 1 (NH1 to NH8): the egg-carry rule (server only) and its suite
    ("src/wildbound/WildboundEggCarry.luau", "ServerScriptService.WildboundEggCarry"),
    ("tests/WildboundEggCarry_Test.luau", "ServerStorage.WildboundEggCarry_Test"),
    # CF2 (odd/tasks/wildbound-caramelo.md): the wave-start nest refill core.
    ("tests/WildboundNestRefill_Test.luau", "ServerStorage.WildboundNestRefill_Test"),
    # Nest Heist phase 2 (NP3): the bat rule (server only) and its suite
    ("src/wildbound/WildboundBat.luau", "ServerScriptService.WildboundBat"),
    ("tests/WildboundBat_Test.luau", "ServerStorage.WildboundBat_Test"),
    # Nest Heist phase 4a (NB1): sources that were in the place but unmapped, at the Explorer paths observed in Studio
    ("src/wildbound/WildboundOwnership.luau", "ServerScriptService.WildboundOwnership"),
    ("tests/WildboundOwnership_Test.luau", "ServerStorage.WildboundOwnership_Test"),
    ("src/wildbound/WildboundWorldGuard.server.luau", "ServerScriptService.WildboundWorldGuard"),
    ("src/wildbound/WildboundPromptKeys.luau", "ServerScriptService.WildboundPromptKeys"),
    ("tests/WildboundPromptKeys_Test.luau", "ServerStorage.WildboundPromptKeys_Test"),
    ("src/wildbound/WildboundSettings.luau", "ReplicatedStorage.WildboundSettings"),
    ("tests/WildboundSettings_Test.luau", "ServerStorage.WildboundSettings_Test"),
    ("src/wildbound/WildboundStart.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundStartClient"),
    ("tests/WildboundStartWiring_Test.luau", "ServerStorage.WildboundStartWiring_Test"),
    ("src/wildbound/WildboundStartView.luau", "ReplicatedStorage.WildboundStartView"),
    ("tests/WildboundStartView_Test.luau", "ServerStorage.WildboundStartView_Test"),
    ("src/wildbound/WildboundTutorial.luau", "ReplicatedStorage.WildboundTutorial"),
    ("tests/WildboundTutorial_Test.luau", "ServerStorage.WildboundTutorial_Test"),
    # Nest Heist phase 4a (NB2 to NB6): the shared beast config, the director, the encounters, the proxies, the beast
    # script and their suites
    ("src/wildbound/WildboundBeastConfig.luau", "ReplicatedStorage.WildboundBeastConfig"),
    ("src/wildbound/WildboundBeastDirector.luau", "ServerScriptService.WildboundBeastDirector"),
    ("src/wildbound/WildboundBeastEncounters.luau", "ServerScriptService.WildboundBeastEncounters"),
    ("src/wildbound/WildboundBeastProxies.luau", "ServerScriptService.WildboundBeastProxies"),
    ("src/wildbound/WildboundBeasts.server.luau", "ServerScriptService.WildboundBeasts"),
    ("tests/WildboundBeastDirector_Test.luau", "ServerStorage.WildboundBeastDirector_Test"),
    ("tests/WildboundBeastEncounters_Test.luau", "ServerStorage.WildboundBeastEncounters_Test"),
    ("tests/WildboundBeastWiring_Test.luau", "ServerStorage.WildboundBeastWiring_Test"),
    (
        "src/wildbound/WildboundBeasts.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundBeastsClient",
    ),
    # Nest Heist Phase 3 (NS1): saved progress; the Explorer paths were created in Studio by this unit
    ("src/wildbound/WildboundSave.luau", "ServerScriptService.WildboundSave"),
    ("src/wildbound/WildboundStoreRoblox.luau", "ServerScriptService.WildboundStoreRoblox"),
    ("tests/WildboundSave_Test.luau", "ServerStorage.WildboundSave_Test"),
    # Nest Heist Phase 3 (NS5): the treadmill rule, shared with the clients, and its suite
    ("src/wildbound/WildboundTraining.luau", "ReplicatedStorage.WildboundTraining"),
    ("tests/WildboundTraining_Test.luau", "ServerStorage.WildboundTraining_Test"),
    # Nest Heist hub (HB-T1 to HB-T5): the generated hub builder, the hub script, the base rule, the stations and their
    # suite; the Explorer paths were created in Studio by this unit. The builder is the v2-r90 expansion: every v2
    # feature inside the radius-90 disc that fits the place at (282, -3) (radius 100 overlaps the forest floor)
    ("tools/build-wildbound-hub-map-v2-r90.luau", "ServerStorage.WildboundHubBuilder"),
    ("src/wildbound/WildboundHub.server.luau", "ServerScriptService.WildboundHub"),
    ("src/wildbound/WildboundBases.luau", "ServerScriptService.WildboundBases"),
    ("src/wildbound/WildboundHubStations.luau", "ServerScriptService.WildboundHubStations"),
    ("tests/WildboundHub_Test.luau", "ServerStorage.WildboundHub_Test"),
    # New mechanics (docs/mechanics/wildbound-new-mechanics.md): pure rules prepared offline; the Explorer paths are
    # planned and created by the Studio writer that wires them. Arrullo, the dodge and dusk are shared (the clients
    # draw them); the knockback and the totem record step stay on the server.
    ("src/wildbound/WildboundArrullo.luau", "ReplicatedStorage.WildboundArrullo"),
    ("tests/WildboundArrullo_Test.luau", "ServerStorage.WildboundArrullo_Test"),
    ("src/wildbound/WildboundDodge.luau", "ReplicatedStorage.WildboundDodge"),
    ("tests/WildboundDodge_Test.luau", "ServerStorage.WildboundDodge_Test"),
    ("src/wildbound/WildboundBatKnock.luau", "ServerScriptService.WildboundBatKnock"),
    ("tests/WildboundBatKnock_Test.luau", "ServerStorage.WildboundBatKnock_Test"),
    ("src/wildbound/WildboundTotemRecord.luau", "ServerScriptService.WildboundTotemRecord"),
    ("tests/WildboundTotemRecord_Test.luau", "ServerStorage.WildboundTotemRecord_Test"),
    # PF4: the schema 5 farm step, a sibling WildboundRecord requires (its cases are in WildboundRecord_Test).
    ("src/wildbound/WildboundFarmRecord.luau", "ServerScriptService.WildboundFarmRecord"),
    ("src/wildbound/WildboundDusk.luau", "ReplicatedStorage.WildboundDusk"),
    ("tests/WildboundDusk_Test.luau", "ServerStorage.WildboundDusk_Test"),
    # Studio-to-repo sync: server modules and scripts that were in the place but unmapped, at the Explorer paths
    # observed in Studio
    ("src/wildbound/WildboundDodgeService.luau", "ServerScriptService.WildboundDodgeService"),
    ("src/wildbound/WildboundArrulloService.luau", "ServerScriptService.WildboundArrulloService"),
    ("src/wildbound/WildboundBaseZone.luau", "ServerScriptService.WildboundBaseZone"),
    ("src/wildbound/WildboundBiomes.luau", "ServerScriptService.WildboundBiomes"),
    ("src/wildbound/WildboundBeastAttack.luau", "ServerScriptService.WildboundBeastAttack"),
    ("src/wildbound/WildboundBeastStreamer.luau", "ServerScriptService.WildboundBeastStreamer"),
    ("src/wildbound/WildboundBeastRoot.luau", "ServerScriptService.WildboundBeastRoot"),
    ("src/wildbound/WildboundBeastGaze.luau", "ServerScriptService.WildboundBeastGaze"),
    ("src/wildbound/WildboundBeastLurker.luau", "ServerScriptService.WildboundBeastLurker"),
    ("src/wildbound/WildboundSiluetaFlightRecorder.server.luau", "ServerScriptService.WildboundSiluetaFlightRecorder"),
    ("src/wildbound/WildboundSiluetaStalk.luau", "ServerScriptService.WildboundSiluetaStalk"),
    ("src/wildbound/WildboundTreadmillService.luau", "ServerScriptService.WildboundTreadmillService"),
    ("src/wildbound/WildboundCreatureToolbar.luau", "ServerScriptService.WildboundCreatureToolbar"),
    # PF0 (odd/tasks/wildbound-playtest-fixes.md): the new-mechanics wiring suite, pulled from Studio
    ("tests/WildboundMechanicsWiring_Test.luau", "ServerStorage.WildboundMechanicsWiring_Test"),
    # PF3: the creature hotbar and base farm suite (fakes only)
    ("tests/WildboundCreatureToolbar_Test.luau", "ServerStorage.WildboundCreatureToolbar_Test"),
    # Studio-to-repo sync: shared modules observed in ReplicatedStorage
    ("src/wildbound/WildboundLumipolAnimData.luau", "ReplicatedStorage.WildboundLumipolAnimData"),
    ("src/wildbound/WildboundLumipolRig.luau", "ReplicatedStorage.WildboundLumipolRig"),
    ("src/wildbound/WildboundBeastSight.luau", "ReplicatedStorage.WildboundBeastSight"),
    ("src/wildbound/WildboundBeastAnimPlan.luau", "ReplicatedStorage.WildboundBeastAnimPlan"),
    ("src/wildbound/WildboundBeastAnimRoot.luau", "ReplicatedStorage.WildboundBeastAnimRoot"),
    ("src/wildbound/WildboundBeastAnimStreamer.luau", "ReplicatedStorage.WildboundBeastAnimStreamer"),
    ("src/wildbound/WildboundBeastAnimGaze.luau", "ReplicatedStorage.WildboundBeastAnimGaze"),
    ("src/wildbound/WildboundBeastAnimLurker.luau", "ReplicatedStorage.WildboundBeastAnimLurker"),
    ("src/wildbound/WildboundEggLoop.luau", "ReplicatedStorage.WildboundEggLoop"),
    ("src/wildbound/WildboundUiStyle.luau", "ReplicatedStorage.WildboundUiStyle"),
    ("src/wildbound/WildboundBalance.luau", "ReplicatedStorage.WildboundBalance"),
    # Studio-to-repo sync: client scripts observed in StarterPlayerScripts
    ("src/wildbound/WildboundLumipolAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundLumipolAnim"),
    ("src/wildbound/WildboundArrullo.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundArrulloClient"),
    ("src/wildbound/WildboundBaseGuide.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundBaseGuideClient"),
    ("src/wildbound/WildboundBeastAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundBeastAnim"),
    (
        "src/wildbound/WildboundVioletLumipol.client.luau",
        "StarterPlayer.StarterPlayerScripts.WildboundVioletLumipolClient",
    ),
    ("src/wildbound/WildboundTreadmill.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundTreadmillClient"),
    ("src/wildbound/WildboundFlashlight.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundFlashlightClient"),
    # Studio-to-repo sync: layout modules observed in ServerStorage
    ("tools/WildboundForestLayout.luau", "ServerStorage.WildboundForestLayout"),
    ("tools/WildboundReliefLayout.luau", "ServerStorage.WildboundReliefLayout"),
    # Studio-to-repo sync: suites observed in ServerStorage
    ("tests/WildboundBaseZone_Test.luau", "ServerStorage.WildboundBaseZone_Test"),
    ("tests/WildboundBeastAttack_Test.luau", "ServerStorage.WildboundBeastAttack_Test"),
    ("tests/WildboundBeastSight_Test.luau", "ServerStorage.WildboundBeastSight_Test"),
    ("tests/WildboundBeastGaze_Test.luau", "ServerStorage.WildboundBeastGaze_Test"),
    ("tests/WildboundBeastLurker_Test.luau", "ServerStorage.WildboundBeastLurker_Test"),
    ("tests/WildboundBeastAnimPlan_Test.luau", "ServerStorage.WildboundBeastAnimPlan_Test"),
    ("tests/WildboundBeastStreamer_Test.luau", "ServerStorage.WildboundBeastStreamer_Test"),
    ("tests/WildboundBeastRoot_Test.luau", "ServerStorage.WildboundBeastRoot_Test"),
    ("tests/WildboundEggLoop_Test.luau", "ServerStorage.WildboundEggLoop_Test"),
    ("tests/WildboundPatrolWiring_Test.luau", "ServerStorage.WildboundPatrolWiring_Test"),
    ("tests/WildboundAggroWiring_Test.luau", "ServerStorage.WildboundAggroWiring_Test"),
    ("tests/WildboundSiluetaReworkWiring_Test.luau", "ServerStorage.WildboundSiluetaReworkWiring_Test"),
    ("tests/WildboundSiluetaStalk_Test.luau", "ServerStorage.WildboundSiluetaStalk_Test"),
    ("tests/WildboundBalance_Test.luau", "ServerStorage.WildboundBalance_Test"),
    # Kids biome (odd/tasks/wildbound-kids-beasts.md): the Pradera's summoned beasts
    ("src/wildbound/WildboundPraderaSites.luau", "ServerScriptService.WildboundPraderaSites"),
    ("src/wildbound/WildboundBeastNube.luau", "ServerScriptService.WildboundBeastNube"),
    ("src/wildbound/WildboundBeastAbeja.luau", "ServerScriptService.WildboundBeastAbeja"),
    ("tests/WildboundBeastNube_Test.luau", "ServerStorage.WildboundBeastNube_Test"),
    ("tests/WildboundBeastAbeja_Test.luau", "ServerStorage.WildboundBeastAbeja_Test"),
    # SC0 shared beast visibility (odd/tasks/wildbound-scuttler.md)
    ("src/wildbound/WildboundBeastAudience.luau", "ServerScriptService.WildboundBeastAudience"),
    ("tests/WildboundBeastAudience_Test.luau", "ServerStorage.WildboundBeastAudience_Test"),
    # SC3 Scuttler brain (odd/tasks/wildbound-scuttler.md)
    ("src/wildbound/WildboundBeastScuttler.luau", "ServerScriptService.WildboundBeastScuttler"),
    ("tests/WildboundBeastScuttler_Test.luau", "ServerStorage.WildboundBeastScuttler_Test"),
    # T09a 2.0 roulette prize table, unwired (odd/tasks/wildbound-2-0.md)
    ("src/wildbound/WildboundRoulette.luau", "ReplicatedStorage.WildboundRoulette"),
    ("tests/WildboundRoulette_Test.luau", "ServerStorage.WildboundRoulette_Test"),
    # PF5 (odd/tasks/wildbound-playtest-fixes.md): the hub roulette, wired. The schema 6 step is a sibling WildboundRecord
    # requires (its cases are in WildboundRecord_Test); the service is started by WildboundServer.
    ("src/wildbound/WildboundRouletteRecord.luau", "ServerScriptService.WildboundRouletteRecord"),
    ("src/wildbound/WildboundRouletteService.luau", "ServerScriptService.WildboundRouletteService"),
    ("tests/WildboundRouletteService_Test.luau", "ServerStorage.WildboundRouletteService_Test"),
    ("src/wildbound/WildboundRoulette.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundRouletteClient"),
    # Caramelo biome (odd/tasks/caramelo-bioma.md): Gomibu and the candy blockout, built in Studio and pulled into the
    # repo at the Explorer paths observed there
    ("src/wildbound/WildboundBeastGomibu.luau", "ServerScriptService.WildboundBeastGomibu"),
    ("tests/WildboundBeastGomibu_Test.luau", "ServerStorage.WildboundBeastGomibu_Test"),
    ("src/wildbound/WildboundCandyGomibuService.server.luau", "ServerScriptService.WildboundCandyGomibuService"),
    ("src/wildbound/WildboundCandyGomibuAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundCandyGomibuAnim"),
    ("tools/WildboundCandyLayout.luau", "ServerStorage.WildboundCandyLayout"),
    ("tests/WildboundCandyLayout_Test.luau", "ServerStorage.WildboundCandyLayout_Test"),
    ("tools/WildboundCandyBuilder.luau", "ServerStorage.WildboundCandyBuilder"),
    ("tests/WildboundCandyBuilder_Test.luau", "ServerStorage.WildboundCandyBuilder_Test"),
    ("tests/WildboundCandyBeastSites_Test.luau", "ServerStorage.WildboundCandyBeastSites_Test"),
    ("tools/WildboundCandyKit.luau", "ServerStorage.WildboundCandyKit"),
    ("tests/WildboundCandyKit_Test.luau", "ServerStorage.WildboundCandyKit_Test"),
    ("tools/WildboundCandyGomibu.luau", "ServerStorage.WildboundCandyGomibu"),
    ("tests/WildboundCandyGomibu_Test.luau", "ServerStorage.WildboundCandyGomibu_Test"),
    ("tools/WildboundCandyGomibuClips.luau", "ServerStorage.WildboundCandyGomibuClips"),
    ("tests/WildboundCandyGomibuClips_Test.luau", "ServerStorage.WildboundCandyGomibuClips_Test"),
    ("tools/WildboundCandyGomibuAttack.luau", "ServerStorage.WildboundCandyGomibuAttack"),
    ("tests/WildboundCandyGomibuAttack_Test.luau", "ServerStorage.WildboundCandyGomibuAttack_Test"),
    ("tools/WildboundCandyFlanfuria.luau", "ServerStorage.WildboundCandyFlanfuria"),
    ("tests/WildboundCandyFlanfuria_Test.luau", "ServerStorage.WildboundCandyFlanfuria_Test"),
    # CA1 (odd/tasks/wildbound-caramelo.md): Flanfuria's attack, clips, brain, model service and client anim
    ("tools/WildboundCandyFlanfuriaAttack.luau", "ServerStorage.WildboundCandyFlanfuriaAttack"),
    ("tests/WildboundCandyFlanfuriaAttack_Test.luau", "ServerStorage.WildboundCandyFlanfuriaAttack_Test"),
    ("tools/WildboundCandyFlanfuriaClips.luau", "ServerStorage.WildboundCandyFlanfuriaClips"),
    ("tests/WildboundCandyFlanfuriaClips_Test.luau", "ServerStorage.WildboundCandyFlanfuriaClips_Test"),
    ("src/wildbound/WildboundBeastFlanfuria.luau", "ServerScriptService.WildboundBeastFlanfuria"),
    ("tests/WildboundBeastFlanfuria_Test.luau", "ServerStorage.WildboundBeastFlanfuria_Test"),
    ("src/wildbound/WildboundCandyFlanfuriaService.server.luau", "ServerScriptService.WildboundCandyFlanfuriaService"),
    ("src/wildbound/WildboundCandyFlanfuriaAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundCandyFlanfuriaAnim"),
    # CA2 (odd/tasks/wildbound-caramelo.md): Tortidragon's prefab, attack, clips, brain, model service and client anim
    ("tools/WildboundCandyTortidragon.luau", "ServerStorage.WildboundCandyTortidragon"),
    ("tests/WildboundCandyTortidragon_Test.luau", "ServerStorage.WildboundCandyTortidragon_Test"),
    ("tools/WildboundCandyTortidragonAttack.luau", "ServerStorage.WildboundCandyTortidragonAttack"),
    ("tests/WildboundCandyTortidragonAttack_Test.luau", "ServerStorage.WildboundCandyTortidragonAttack_Test"),
    ("tools/WildboundCandyTortidragonClips.luau", "ServerStorage.WildboundCandyTortidragonClips"),
    ("tests/WildboundCandyTortidragonClips_Test.luau", "ServerStorage.WildboundCandyTortidragonClips_Test"),
    ("tools/WildboundScuttlerClips.luau", "ServerStorage.WildboundScuttlerClips"),
    ("tests/WildboundScuttlerClips_Test.luau", "ServerStorage.WildboundScuttlerClips_Test"),
    ("src/wildbound/WildboundBeastTortidragon.luau", "ServerScriptService.WildboundBeastTortidragon"),
    ("tests/WildboundBeastTortidragon_Test.luau", "ServerStorage.WildboundBeastTortidragon_Test"),
    ("src/wildbound/WildboundCandyTortidragonService.server.luau", "ServerScriptService.WildboundCandyTortidragonService"),
    ("src/wildbound/WildboundCandyTortidragonAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundCandyTortidragonAnim"),
    # CA3 (odd/tasks/wildbound-caramelo.md): Don Glaseon's prefab, attack, clips, brain, model service and client anim
    ("tools/WildboundCandyDonGlaseon.luau", "ServerStorage.WildboundCandyDonGlaseon"),
    ("tests/WildboundCandyDonGlaseon_Test.luau", "ServerStorage.WildboundCandyDonGlaseon_Test"),
    ("tools/WildboundCandyDonGlaseonAttack.luau", "ServerStorage.WildboundCandyDonGlaseonAttack"),
    ("tests/WildboundCandyDonGlaseonAttack_Test.luau", "ServerStorage.WildboundCandyDonGlaseonAttack_Test"),
    # DG2 Boca aspiradora (odd/tasks/wildbound-caramelo-v2.md)
    ("tools/WildboundCandyDonGlaseonVacuum.luau", "ServerStorage.WildboundCandyDonGlaseonVacuum"),
    ("tests/WildboundCandyDonGlaseonVacuum_Test.luau", "ServerStorage.WildboundCandyDonGlaseonVacuum_Test"),
    ("tools/WildboundCandyDonGlaseonClips.luau", "ServerStorage.WildboundCandyDonGlaseonClips"),
    ("tests/WildboundCandyDonGlaseonClips_Test.luau", "ServerStorage.WildboundCandyDonGlaseonClips_Test"),
    ("src/wildbound/WildboundBeastDonGlaseon.luau", "ServerScriptService.WildboundBeastDonGlaseon"),
    ("tests/WildboundBeastDonGlaseon_Test.luau", "ServerStorage.WildboundBeastDonGlaseon_Test"),
    # CF3: the boss's robustness (bat immunity, the sleeping copy)
    ("tests/WildboundBossRobustness_Test.luau", "ServerStorage.WildboundBossRobustness_Test"),
    ("src/wildbound/WildboundCandyDonGlaseonService.server.luau", "ServerScriptService.WildboundCandyDonGlaseonService"),
    ("src/wildbound/WildboundCandyDonGlaseonAnim.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundCandyDonGlaseonAnim"),
    # CE0: the kit the owner uses to publish Tortidragon's and Don Glaseon's clips to the group
    ("tools/WildboundCandyClipPublish.luau", "ServerStorage.WildboundCandyClipPublish"),
    ("tests/WildboundCandyClipPublish_Test.luau", "ServerStorage.WildboundCandyClipPublish_Test"),
    # CE1: the Caramelo nests join the island nests (one egg each, the guardian beside it)
    ("src/wildbound/WildboundCandyNests.luau", "ServerScriptService.WildboundCandyNests"),
    ("tests/WildboundCandyNests_Test.luau", "ServerStorage.WildboundCandyNests_Test"),
    # CE2: the hatched Caramelo creatures as passive farm pets (their real rig, scaled down)
    ("src/wildbound/WildboundCandyPets.luau", "ServerScriptService.WildboundCandyPets"),
    ("tests/WildboundCandyPets_Test.luau", "ServerStorage.WildboundCandyPets_Test"),
    # CE3 / T08b: the return portals (pure rules, the server service, the client's prompt and channel bar)
    ("src/wildbound/WildboundPortal.luau", "ServerScriptService.WildboundPortal"),
    ("tests/WildboundPortal_Test.luau", "ServerStorage.WildboundPortal_Test"),
    ("src/wildbound/WildboundPortalService.luau", "ServerScriptService.WildboundPortalService"),
    ("tests/WildboundPortalService_Test.luau", "ServerStorage.WildboundPortalService_Test"),
    ("src/wildbound/WildboundPortal.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundPortalClient"),
    # CG1: the candy egg looks of the Caramelo species (nest, ground, backpack, cradle) and the gummy egg's bob
    ("src/wildbound/WildboundCandyEggArt.luau", "ReplicatedStorage.WildboundCandyEggArt"),
    ("tests/WildboundCandyEggArt_Test.luau", "ServerStorage.WildboundCandyEggArt_Test"),
    ("src/wildbound/WildboundCandyEggBob.client.luau", "StarterPlayer.StarterPlayerScripts.WildboundCandyEggBob"),
]


def _normalize(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").rstrip(b"\n")


def normalized_hash(data: bytes) -> str:
    return hashlib.sha256(_normalize(data)).hexdigest()


def normalized_line_count(data: bytes) -> int:
    text = _normalize(data)
    return 0 if not text else text.count(b"\n") + 1


def validate_mappings(mappings) -> None:
    """Raise ValueError when a local path or an Explorer path appears twice."""
    seen_local, seen_explorer = set(), set()
    for local, explorer in mappings:
        if local in seen_local:
            raise ValueError(f"local path mapped twice: {local}")
        if explorer in seen_explorer:
            raise ValueError(f"Explorer path mapped twice: {explorer}")
        seen_local.add(local)
        seen_explorer.add(explorer)


def _find_unmapped(root: Path, mapped_locals) -> list:
    found = []
    for scan in SCAN_DIRS:
        base = root / scan
        if not base.is_dir():
            continue
        for p in base.rglob("*.luau"):
            rel = p.relative_to(root).as_posix()
            if rel not in mapped_locals:
                found.append(rel)
    return sorted(found)


def build_manifest(root, mappings=None) -> dict:
    mappings = DEFAULT_MAPPINGS if mappings is None else mappings
    validate_mappings(mappings)
    root = Path(root)
    entries = []
    for local, explorer in mappings:
        path = root / local
        if path.is_file():
            data = path.read_bytes()
            entry = {
                "path": local,
                "explorer_path": explorer,
                "sha256": normalized_hash(data),
                "line_count": normalized_line_count(data),
                "status": "present",
            }
        else:
            entry = {
                "path": local,
                "explorer_path": explorer,
                "sha256": None,
                "line_count": None,
                "status": "missing",
            }
        entries.append(entry)
    entries.sort(key=lambda e: e["explorer_path"])
    present = sum(1 for e in entries if e["status"] == "present")
    return {
        "schema": 1,
        "hash": "sha256 of source with CRLF normalized to LF and trailing newlines stripped",
        "entries": entries,
        "unmapped": _find_unmapped(root, {local for local, _ in mappings}),
        "summary": {
            "mapped": len(entries),
            "present": present,
            "missing": len(entries) - present,
        },
    }


def render_json(manifest: dict) -> str:
    return json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def main(argv=None, mappings=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--root", default=str(REPO), help="repository root (default: this repo)")
    parser.add_argument("--output", help="write JSON to this file instead of stdout")
    args = parser.parse_args(argv)
    try:
        text = render_json(build_manifest(args.root, mappings))
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if args.output:
        with open(args.output, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
