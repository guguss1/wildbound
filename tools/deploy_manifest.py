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
