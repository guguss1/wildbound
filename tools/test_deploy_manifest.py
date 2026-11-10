"""Contracts for the Luau source -> Roblox Explorer deployment manifest tool.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_deploy_manifest.py

Tests build throwaway source trees in temporary directories; the real repo is
only read by the default-mapping checks, never written.
"""

import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import deploy_manifest as dm

REPO = Path(__file__).resolve().parent.parent


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class TempTree(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def write(self, rel: str, data: bytes) -> None:
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)

    def snapshot(self):
        return sorted(str(p.relative_to(self.root)) for p in self.root.rglob("*"))


class NormalizationTests(unittest.TestCase):
    def test_crlf_and_lf_hash_the_same(self):
        self.assertEqual(
            dm.normalized_hash(b"a\r\nb\r\nc"), dm.normalized_hash(b"a\nb\nc")
        )

    def test_mixed_line_endings_hash_the_same(self):
        self.assertEqual(
            dm.normalized_hash(b"a\r\nb\nc\r\n"), dm.normalized_hash(b"a\nb\nc")
        )

    def test_trailing_newlines_do_not_change_hash(self):
        base = dm.normalized_hash(b"a\nb")
        for tail in (b"\n", b"\r\n", b"\n\n\n", b"\r\n\r\n"):
            self.assertEqual(dm.normalized_hash(b"a\nb" + tail), base)

    def test_hash_is_sha256_of_normalized_text(self):
        self.assertEqual(dm.normalized_hash(b"a\r\nb\r\n"), sha("a\nb"))

    def test_real_content_change_changes_hash(self):
        self.assertNotEqual(dm.normalized_hash(b"a\nb"), dm.normalized_hash(b"a\nc"))
        # Interior blank lines are content, only trailing newlines are stripped.
        self.assertNotEqual(dm.normalized_hash(b"a\nb"), dm.normalized_hash(b"a\n\nb"))

    def test_line_count_ignores_ending_style_and_trailing_newlines(self):
        self.assertEqual(dm.normalized_line_count(b"a\r\nb\r\nc\r\n"), 3)
        self.assertEqual(dm.normalized_line_count(b"a\nb\nc"), 3)
        self.assertEqual(dm.normalized_line_count(b"a\n\nb\n"), 3)
        self.assertEqual(dm.normalized_line_count(b""), 0)
        self.assertEqual(dm.normalized_line_count(b"\n\n"), 0)


class MappingValidationTests(unittest.TestCase):
    def test_duplicate_explorer_path_is_an_error(self):
        with self.assertRaises(ValueError) as ctx:
            dm.validate_mappings(
                [("src/a.luau", "ServerStorage.X"), ("src/b.luau", "ServerStorage.X")]
            )
        self.assertIn("ServerStorage.X", str(ctx.exception))

    def test_duplicate_local_path_is_an_error(self):
        with self.assertRaises(ValueError):
            dm.validate_mappings(
                [("src/a.luau", "ServerStorage.X"), ("src/a.luau", "ServerStorage.Y")]
            )

    def test_distinct_mappings_are_accepted(self):
        dm.validate_mappings(
            [("src/a.luau", "ServerStorage.X"), ("src/b.luau", "ServerStorage.Y")]
        )


class BuildManifestTests(TempTree):
    MAP = [
        ("src/b.luau", "ServerStorage.Zeta"),
        ("src/a.luau", "ServerScriptService.Alpha"),
        ("src/gone.luau", "ServerStorage.Gone"),
    ]

    def build(self, mappings=None):
        return dm.build_manifest(self.root, self.MAP if mappings is None else mappings)

    def test_entries_sorted_by_explorer_path_and_fields(self):
        self.write("src/b.luau", b"b1\r\nb2\r\n")
        self.write("src/a.luau", b"a1\n")
        manifest = self.build()
        paths = [e["explorer_path"] for e in manifest["entries"]]
        self.assertEqual(paths, sorted(paths))
        self.assertEqual(
            paths, ["ServerScriptService.Alpha", "ServerStorage.Gone", "ServerStorage.Zeta"]
        )
        alpha = manifest["entries"][0]
        self.assertEqual(
            alpha,
            {
                "path": "src/a.luau",
                "explorer_path": "ServerScriptService.Alpha",
                "sha256": sha("a1"),
                "line_count": 1,
                "status": "present",
            },
        )
        zeta = manifest["entries"][2]
        self.assertEqual(zeta["sha256"], sha("b1\nb2"))
        self.assertEqual(zeta["line_count"], 2)

    def test_missing_file_is_reported_not_fatal(self):
        self.write("src/a.luau", b"a\n")
        self.write("src/b.luau", b"b\n")
        manifest = self.build()
        gone = [e for e in manifest["entries"] if e["path"] == "src/gone.luau"][0]
        self.assertEqual(gone["status"], "missing")
        self.assertIsNone(gone["sha256"])
        self.assertIsNone(gone["line_count"])
        self.assertEqual(manifest["summary"], {"mapped": 3, "present": 2, "missing": 1})

    def test_crlf_checkout_matches_lf_checkout(self):
        self.write("src/a.luau", b"x\r\ny\r\n")
        self.write("src/b.luau", b"z")
        crlf = self.build()
        self.write("src/a.luau", b"x\ny")
        lf = self.build()
        self.assertEqual(crlf, lf)

    def test_duplicate_mapping_aborts_build(self):
        with self.assertRaises(ValueError):
            self.build([("src/a.luau", "ServerStorage.X"), ("src/b.luau", "ServerStorage.X")])

    def test_deterministic_json_bytes(self):
        self.write("src/a.luau", b"a\n")
        self.write("src/b.luau", b"b\n")
        first = dm.render_json(self.build())
        second = dm.render_json(self.build())
        self.assertEqual(first, second)
        self.assertTrue(first.endswith("\n"))
        self.assertNotIn("\r", first)
        self.assertEqual(json.loads(first), self.build())

    def test_unmapped_luau_files_are_listed(self):
        self.write("src/a.luau", b"a\n")
        self.write("tests/Other_Test.luau", b"t\n")
        self.write("tools/zz.luau", b"t\n")
        self.write("tools/skip.py", b"print()\n")
        manifest = self.build()
        self.assertEqual(manifest["unmapped"], ["tests/Other_Test.luau", "tools/zz.luau"])

    def test_manifest_has_no_machine_specific_data(self):
        self.write("src/a.luau", b"a\n")
        text = dm.render_json(self.build())
        self.assertNotIn(str(self.root), text)
        self.assertNotIn("\\\\", text)


class CliTests(TempTree):
    MAP = [("src/a.luau", "ServerStorage.A")]

    def run_cli(self, argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = dm.main(argv, mappings=self.MAP)
        return code, out.getvalue(), err.getvalue()

    def test_default_prints_json_to_stdout_and_writes_nothing(self):
        self.write("src/a.luau", b"a\n")
        before = self.snapshot()
        code, out, _ = self.run_cli(["--root", str(self.root)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["entries"][0]["sha256"], sha("a"))
        self.assertEqual(self.snapshot(), before)

    def test_output_flag_writes_file_and_not_stdout(self):
        self.write("src/a.luau", b"a\n")
        target = self.root / "out" / "manifest.json"
        target.parent.mkdir()
        code, out, _ = self.run_cli(["--root", str(self.root), "--output", str(target)])
        self.assertEqual(code, 0)
        self.assertEqual(out, "")
        data = target.read_bytes()
        self.assertNotIn(b"\r", data)
        self.assertEqual(data.decode("utf-8"), dm.render_json(dm.build_manifest(self.root, self.MAP)))

    def test_missing_file_still_exits_zero(self):
        code, out, _ = self.run_cli(["--root", str(self.root)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["summary"]["missing"], 1)

    def test_duplicate_mapping_exits_nonzero_without_output(self):
        out, err = io.StringIO(), io.StringIO()
        dup = [("src/a.luau", "ServerStorage.A"), ("src/b.luau", "ServerStorage.A")]
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = dm.main(["--root", str(self.root)], mappings=dup)
        self.assertNotEqual(code, 0)
        self.assertEqual(out.getvalue(), "")
        self.assertIn("ServerStorage.A", err.getvalue())


class DefaultMappingTests(unittest.TestCase):
    """Pin the documented and Studio-observed mapping independently of the module."""

    EXPECTED = {
        # docs/testing/wildbound-p0.md:9-16
        "tools/build-wildbound-p0-map.luau": "ServerStorage.WildboundP0MapBuilder",
        "src/wildbound/WildboundState.luau": "ServerScriptService.WildboundState",
        "src/wildbound/WildboundServer.server.luau": "ServerScriptService.WildboundServer",
        "src/wildbound/WildboundClient.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundClient",
        "tests/WildboundState_Test.luau": "ServerStorage.WildboundState_Test",
        "tests/WildboundP0Map_Test.luau": "ServerStorage.WildboundP0Map_Test",
        # docs/testing/wildbound-world.md:7-11
        "src/wildbound/WildboundWorldRules.luau": "ServerScriptService.WildboundWorldRules",
        "src/wildbound/WildboundWorld.server.luau": "ServerScriptService.WildboundWorld",
        "src/wildbound/WildboundWorld.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundWorldClient",
        # docs/testing/silueta-visual-adapter.md:7 and Studio observation
        "src/wildbound/WildboundSiluetaVisual.luau": "ServerScriptService.WildboundSiluetaVisual",
        "src/wildbound/WildboundSiluetaHunt.luau": "ServerScriptService.WildboundSiluetaHunt",
        # odd/tasks/wildbound-first-playable.md:111
        "tests/WildboundWorldRules_Test.luau": "ServerStorage.WildboundWorldRules_Test",
        # README.md:44 (earlier Rescue prototype)
        "src/server/RescueState.luau": "ServerScriptService.RescueState",
        "src/server/RescueServer.server.luau": "ServerScriptService.RescueServer",
        "src/client/RescueClient.client.luau": "StarterPlayer.StarterPlayerScripts.RescueClient",
        # forest dress unit (another agent; may be absent)
        "tools/dress-wildbound-forest.luau": "ServerStorage.WildboundForestDress",
        "tests/WildboundForestDress_Test.luau": "ServerStorage.WildboundForestDress_Test",
        # docs/mechanics/wildbound-awareness.md and Studio observation (M2.1)
        "src/wildbound/WildboundSiluetaAwareness.luau": "ServerScriptService.WildboundSiluetaAwareness",
        "tests/WildboundSiluetaAwareness_Test.luau": "ServerStorage.WildboundSiluetaAwareness_Test",
        # M2.6, wave W3b: client smoothing is pure and shared, so it lives in ReplicatedStorage
        "src/wildbound/WildboundGuardianSmoothing.luau": "ReplicatedStorage.WildboundGuardianSmoothing",
        "tests/WildboundGuardianSmoothing_Test.luau": "ServerStorage.WildboundGuardianSmoothing_Test",
        # M2.3 and the compact phone HUD, wave W3b: pure layout and view rules the clients require
        "src/wildbound/WildboundHudLayout.luau": "ReplicatedStorage.WildboundHudLayout",
        "tests/WildboundHudLayout_Test.luau": "ServerStorage.WildboundHudLayout_Test",
        "src/wildbound/WildboundHudView.luau": "ReplicatedStorage.WildboundHudView",
        "tests/WildboundHudView_Test.luau": "ServerStorage.WildboundHudView_Test",
        # M3.2, wave W5: pure capture rule, shared because the client draws the ring from it
        "src/wildbound/WildboundCaptureSession.luau": "ReplicatedStorage.WildboundCaptureSession",
        "tests/WildboundCaptureSession_Test.luau": "ServerStorage.WildboundCaptureSession_Test",
        # M3.3 to M3.5, wave W5: server-only wild rules, the shared capture view and the touch client
        "src/wildbound/WildboundLumipolWild.luau": "ServerScriptService.WildboundLumipolWild",
        "tests/WildboundLumipolWild_Test.luau": "ServerStorage.WildboundLumipolWild_Test",
        "src/wildbound/WildboundCaptureView.luau": "ReplicatedStorage.WildboundCaptureView",
        "tests/WildboundCaptureView_Test.luau": "ServerStorage.WildboundCaptureView_Test",
        "src/wildbound/WildboundCapture.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundCaptureClient",
        # M4.2 to M4.7, wave W6: server-only damage flag and pure fair-strike rules
        "src/wildbound/WildboundFlags.luau": "ServerScriptService.WildboundFlags",
        "src/wildbound/WildboundFairStrike.luau": "ServerScriptService.WildboundFairStrike",
        "tests/WildboundFairStrike_Test.luau": "ServerStorage.WildboundFairStrike_Test",
        # M4.7, wave W6: pure ambush relocation with no camera or gaze input
        "src/wildbound/WildboundAmbush.luau": "ServerScriptService.WildboundAmbush",
        "tests/WildboundAmbush_Test.luau": "ServerStorage.WildboundAmbush_Test",
        # M5.2, M5.4, M5.5, wave W7: generated tuning copy and pure economy rules are shared, so the
        # camp screen can show costs; the seeded spawn pipeline stays on the server
        "src/wildbound/WildboundEconomyConfig.luau": "ReplicatedStorage.WildboundEconomyConfig",
        "src/wildbound/WildboundEconomy.luau": "ReplicatedStorage.WildboundEconomy",
        "tests/WildboundEconomy_Test.luau": "ServerStorage.WildboundEconomy_Test",
        "src/wildbound/WildboundSpawn.luau": "ServerScriptService.WildboundSpawn",
        "tests/WildboundSpawn_Test.luau": "ServerStorage.WildboundSpawn_Test",
        # M5.3, wave W7 part 2: pure gather-field rules and the script that draws the world nodes
        "src/wildbound/WildboundGatherField.luau": "ServerScriptService.WildboundGatherField",
        "src/wildbound/WildboundGather.server.luau": "ServerScriptService.WildboundGather",
        "tests/WildboundGatherField_Test.luau": "ServerStorage.WildboundGatherField_Test",
        # M5.8, wave W7 part 2: pure camp screen, loss line and compass rules the inventory client requires
        "src/wildbound/WildboundCampView.luau": "ReplicatedStorage.WildboundCampView",
        "tests/WildboundCampView_Test.luau": "ServerStorage.WildboundCampView_Test",
        # M6.1 and M6.2, wave W10: server-only record and persistence sessions; the fake store is a test double
        "src/wildbound/WildboundRecord.luau": "ServerScriptService.WildboundRecord",
        "tests/WildboundRecord_Test.luau": "ServerStorage.WildboundRecord_Test",
        "src/wildbound/WildboundPersistence.luau": "ServerScriptService.WildboundPersistence",
        "tests/WildboundPersistence_Test.luau": "ServerStorage.WildboundPersistence_Test",
        "tests/WildboundFakePlayerStore.luau": "ServerStorage.WildboundFakePlayerStore",
        "tests/WildboundFakePlayerStore_Test.luau": "ServerStorage.WildboundFakePlayerStore_Test",
        # M9.5, wave W16: server-only analytics event seam
        "src/wildbound/WildboundAnalytics.luau": "ServerScriptService.WildboundAnalytics",
        "tests/WildboundAnalytics_Test.luau": "ServerStorage.WildboundAnalytics_Test",
        "src/wildbound/WildboundFunnel.luau": "ServerScriptService.WildboundFunnel",
        "tests/WildboundFunnel_Test.luau": "ServerStorage.WildboundFunnel_Test",
        "tests/WildboundAnalyticsWiring_Test.luau": "ServerStorage.WildboundAnalyticsWiring_Test",
        # Delivery A, capture redesign: the shared Spanish text module (H3)
        "src/wildbound/WildboundText.luau": "ReplicatedStorage.WildboundText",
        "tests/WildboundText_Test.luau": "ServerStorage.WildboundText_Test",
        # Delivery A3: pure smoothing and mood cues for the client's local Lumipol copy
        "src/wildbound/WildboundLumipolLook.luau": "ReplicatedStorage.WildboundLumipolLook",
        "tests/WildboundLumipolLook_Test.luau": "ServerStorage.WildboundLumipolLook_Test",
        # Delivery B2: pure carried-creature mood, movement, sound hook and HUD line rules, shared with the clients
        "src/wildbound/WildboundCarry.luau": "ReplicatedStorage.WildboundCarry",
        "tests/WildboundCarry_Test.luau": "ServerStorage.WildboundCarry_Test",
        # Delivery B3 to B5: pure camp rules (deposit, card, display spots, companion offset), shared with the clients
        "src/wildbound/WildboundRefuge.luau": "ReplicatedStorage.WildboundRefuge",
        "tests/WildboundRefuge_Test.luau": "ServerStorage.WildboundRefuge_Test",
        # Delivery C1: pure guardian brain (suspicion, noises, search, day and night profiles), server only
        "src/wildbound/WildboundGuardianBrain.luau": "ServerScriptService.WildboundGuardianBrain",
        "tests/WildboundGuardianBrain_Test.luau": "ServerStorage.WildboundGuardianBrain_Test",
        # Delivery C2: pure route following around the solid trunk cores, server only
        "src/wildbound/WildboundGuardianPath.luau": "ServerScriptService.WildboundGuardianPath",
        "tests/WildboundGuardianPath_Test.luau": "ServerStorage.WildboundGuardianPath_Test",
        # Delivery D1: pure whole-map fog and light targets, shared because the world client applies them
        "src/wildbound/WildboundAtmosphere.luau": "ReplicatedStorage.WildboundAtmosphere",
        "tests/WildboundAtmosphere_Test.luau": "ServerStorage.WildboundAtmosphere_Test",
        # Delivery D5: pure hiding rules (entry, discovery dwell, exit), server only
        "src/wildbound/WildboundHide.luau": "ServerScriptService.WildboundHide",
        "tests/WildboundHide_Test.luau": "ServerStorage.WildboundHide_Test",
        # Delivery D8: pure per-player threat bucket with held falls, server only
        "src/wildbound/WildboundThreatLevel.luau": "ServerScriptService.WildboundThreatLevel",
        "tests/WildboundThreatLevel_Test.luau": "ServerStorage.WildboundThreatLevel_Test",
        # Delivery D6 and D8: source contracts for the hiding, threat and clock wiring
        "tests/WildboundHideWiring_Test.luau": "ServerStorage.WildboundHideWiring_Test",
        # Delivery D9: the audio catalog (every id in one place) and the pure mix, shared with the audio client
        "src/wildbound/WildboundAudioCatalog.luau": "ReplicatedStorage.WildboundAudioCatalog",
        "src/wildbound/WildboundAudioMix.luau": "ReplicatedStorage.WildboundAudioMix",
        "tests/WildboundAudioMix_Test.luau": "ServerStorage.WildboundAudioMix_Test",
        # Delivery D10: the horror audio controller and its source contracts
        "src/wildbound/WildboundAudio.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundAudioClient",
        "tests/WildboundAudioWiring_Test.luau": "ServerStorage.WildboundAudioWiring_Test",
        # Dread pass, unit 1: pure stamina, sprint and its costs (server only), and its wiring contracts
        "src/wildbound/WildboundStamina.luau": "ServerScriptService.WildboundStamina",
        "tests/WildboundStamina_Test.luau": "ServerStorage.WildboundStamina_Test",
        "tests/WildboundStaminaWiring_Test.luau": "ServerStorage.WildboundStaminaWiring_Test",
        # Expedition relief, R2: the pure height rule (server only)
        "src/wildbound/WildboundRelief.luau": "ServerScriptService.WildboundRelief",
        "tests/WildboundRelief_Test.luau": "ServerStorage.WildboundRelief_Test",
        # Expedition relief, R5: source contracts for the guardian and creatures on the relief
        "tests/WildboundReliefWiring_Test.luau": "ServerStorage.WildboundReliefWiring_Test",
        # Expedition islands, I1: the generated island layout (server only)
        "src/wildbound/WildboundIslandLayout.luau": "ServerScriptService.WildboundIslandLayout",
        # Expedition islands, I2: the pure island rule (server only)
        "src/wildbound/WildboundIsland.luau": "ServerScriptService.WildboundIsland",
        "tests/WildboundIsland_Test.luau": "ServerStorage.WildboundIsland_Test",
        # Expedition islands, I8: species stand-ins in one module (shared with the clients)
        "src/wildbound/WildboundSpecies.luau": "ReplicatedStorage.WildboundSpecies",
        "tests/WildboundSpecies_Test.luau": "ServerStorage.WildboundSpecies_Test",
        # Expedition islands, I6: source contracts for the island wiring
        "tests/WildboundIslandWiring_Test.luau": "ServerStorage.WildboundIslandWiring_Test",
        # Dev tuning, DT1 to DT4: the shared schema, the server bridge, the developer panel and their suites
        "src/wildbound/WildboundTuningSchema.luau": "ReplicatedStorage.WildboundTuningSchema",
        "src/wildbound/WildboundTuning.server.luau": "ServerScriptService.WildboundTuning",
        "src/wildbound/WildboundTuning.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundTuningClient",
        "tests/WildboundTuning_Test.luau": "ServerStorage.WildboundTuning_Test",
        "tests/WildboundTuningWiring_Test.luau": "ServerStorage.WildboundTuningWiring_Test",
        "src/wildbound/WildboundFear.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundFearClient",
        "tests/WildboundFearWiring_Test.luau": "ServerStorage.WildboundFearWiring_Test",
        # Nest Heist phase 1 (NH1 to NH8): the egg-carry rule (server only) and its suite
        "src/wildbound/WildboundEggCarry.luau": "ServerScriptService.WildboundEggCarry",
        "tests/WildboundEggCarry_Test.luau": "ServerStorage.WildboundEggCarry_Test",
        # Nest Heist phase 2 (NP3): the bat rule (server only) and its suite
        "src/wildbound/WildboundBat.luau": "ServerScriptService.WildboundBat",
        "tests/WildboundBat_Test.luau": "ServerStorage.WildboundBat_Test",
        # Nest Heist phase 4a (NB1): the earlier unmapped sources, at the Explorer paths observed in Studio
        "src/wildbound/WildboundOwnership.luau": "ServerScriptService.WildboundOwnership",
        "tests/WildboundOwnership_Test.luau": "ServerStorage.WildboundOwnership_Test",
        "src/wildbound/WildboundWorldGuard.server.luau": "ServerScriptService.WildboundWorldGuard",
        "src/wildbound/WildboundPromptKeys.luau": "ServerScriptService.WildboundPromptKeys",
        "tests/WildboundPromptKeys_Test.luau": "ServerStorage.WildboundPromptKeys_Test",
        "src/wildbound/WildboundSettings.luau": "ReplicatedStorage.WildboundSettings",
        "tests/WildboundSettings_Test.luau": "ServerStorage.WildboundSettings_Test",
        "src/wildbound/WildboundStart.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundStartClient",
        "tests/WildboundStartWiring_Test.luau": "ServerStorage.WildboundStartWiring_Test",
        "src/wildbound/WildboundStartView.luau": "ReplicatedStorage.WildboundStartView",
        "tests/WildboundStartView_Test.luau": "ServerStorage.WildboundStartView_Test",
        "src/wildbound/WildboundTutorial.luau": "ReplicatedStorage.WildboundTutorial",
        "tests/WildboundTutorial_Test.luau": "ServerStorage.WildboundTutorial_Test",
        # Nest Heist phase 4a (NB2 to NB6): the beast pack
        "src/wildbound/WildboundBeastConfig.luau": "ReplicatedStorage.WildboundBeastConfig",
        "src/wildbound/WildboundBeastDirector.luau": "ServerScriptService.WildboundBeastDirector",
        "src/wildbound/WildboundBeastEncounters.luau": "ServerScriptService.WildboundBeastEncounters",
        "src/wildbound/WildboundBeastProxies.luau": "ServerScriptService.WildboundBeastProxies",
        "src/wildbound/WildboundBeasts.server.luau": "ServerScriptService.WildboundBeasts",
        "tests/WildboundBeastDirector_Test.luau": "ServerStorage.WildboundBeastDirector_Test",
        "tests/WildboundBeastEncounters_Test.luau": "ServerStorage.WildboundBeastEncounters_Test",
        "tests/WildboundBeastWiring_Test.luau": "ServerStorage.WildboundBeastWiring_Test",
        "src/wildbound/WildboundBeasts.client.luau": "StarterPlayer.StarterPlayerScripts.WildboundBeastsClient",
        # Nest Heist Phase 3 (NS1): saved progress, at the Explorer paths created in Studio
        "src/wildbound/WildboundSave.luau": "ServerScriptService.WildboundSave",
        "src/wildbound/WildboundStoreRoblox.luau": "ServerScriptService.WildboundStoreRoblox",
        "tests/WildboundSave_Test.luau": "ServerStorage.WildboundSave_Test",
        # NS5: the treadmill rule (shared) and its suite
        "src/wildbound/WildboundTraining.luau": "ReplicatedStorage.WildboundTraining",
        "tests/WildboundTraining_Test.luau": "ServerStorage.WildboundTraining_Test",
        # Nest Heist hub (HB-T1 to HB-T5): the generated hub builder, the hub script, the base rule, the stations and
        # their suite, at the Explorer paths created in Studio by this unit
        "tools/build-wildbound-hub-map.luau": "ServerStorage.WildboundHubBuilder",
        "src/wildbound/WildboundHub.server.luau": "ServerScriptService.WildboundHub",
        "src/wildbound/WildboundBases.luau": "ServerScriptService.WildboundBases",
        "src/wildbound/WildboundHubStations.luau": "ServerScriptService.WildboundHubStations",
        "tests/WildboundHub_Test.luau": "ServerStorage.WildboundHub_Test",
    }

    def test_default_mappings_contain_documented_pairs(self):
        actual = dict(dm.DEFAULT_MAPPINGS)
        for local, explorer in self.EXPECTED.items():
            self.assertEqual(actual.get(local), explorer, local)

    def test_default_mappings_are_valid(self):
        dm.validate_mappings(dm.DEFAULT_MAPPINGS)

    def test_unsupported_mappings_are_not_guessed(self):
        # Test modules under ServerStorage.WildboundTests use per-run names
        # (e.g. SiluetaVisual_Contract); the docs give no stable name.
        locals_ = {local for local, _ in dm.DEFAULT_MAPPINGS}
        for local in (
            "tests/WildboundSiluetaHunt_Test.luau",
            "tests/WildboundSiluetaVisual_Test.luau",
            "tests/RunUnitTest.luau",
            "tools/build-map.luau",
        ):
            self.assertNotIn(local, locals_)

    def test_real_repo_manifest_is_stable_and_reports_forest_dress_if_absent(self):
        manifest = dm.build_manifest(REPO)
        by_local = {e["path"]: e for e in manifest["entries"]}
        for local in (
            "tools/dress-wildbound-forest.luau",
            "tests/WildboundForestDress_Test.luau",
        ):
            self.assertIn(local, by_local)
            self.assertIn(by_local[local]["status"], ("present", "missing"))
        self.assertEqual(dm.render_json(manifest), dm.render_json(dm.build_manifest(REPO)))


if __name__ == "__main__":
    unittest.main()
