"""Contracts for the hub Luau builder generator (tools/build-hub-map.py).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_build_hub_map.py

The generator turns hub-bases-v1.json into a flat list of primitive parts and renders a ModuleScript that only
interprets it. These tests read that list and the rendered text: only floors and walls collide or answer queries,
every station tag the game code binds to is present once per base at the planned spot, the part and light budgets
hold, balls and cylinders keep the shapes Roblox allows, no part shadows a marker name the current server looks up,
the Spanish copy is present, block keywords balance, and the written module is fresh. Nothing here runs Luau or
touches Studio.
"""

import importlib.util
import json
import math
import re
import unittest
from pathlib import Path

import plan_hub_bases as plan

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
SRC = REPO / "src" / "wildbound"

spec = importlib.util.spec_from_file_location("build_hub_map", TOOLS / "build-hub-map.py")
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)

PARTS_CAP, LIGHTS_CAP, SLOTS = 400, 20, 8
REQUIRED_TAGS = ("WildboundBaseSlot", "WildboundDeliveryStation", "WildboundIncubatorStation",
                 "WildboundCollectionDisplay", "WildboundGloveStation", "WildboundTrainingStation",
                 "WildboundHubSafeZone", "WildboundHubEntrance")
STATION_PARTS = {"WildboundDeliveryStation": "DeliveryPedestal", "WildboundIncubatorStation": "IncubatorBase",
                 "WildboundCollectionDisplay": "DisplayPlatform", "WildboundGloveStation": "GloveBench",
                 "WildboundTrainingStation": "TreadmillDeck"}
FLOOR_NAMES = ("Floor", "Plaza", "Promenade", "GatePath_", "Trail_", "SpawnPad", "Rim", "Pad", "Walk",
               "TreadmillDeck", "TreadmillBelt")
WALL_NAMES = ("Hedge", "PostLeft", "PostRight", "Fence_")
MATERIALS = {"SmoothPlastic", "Grass", "Pavement", "Slate", "Wood", "WoodPlanks", "Neon", "Sand", "Fabric", "Glass",
             "Metal"}
SPANISH = ("Base de <jugador>", "Bosque de la Silueta", "Pradera Arcoíris", "Al bosque: sendero norte",
           "Al bosque: sendero sur", "Camino del anillo", "Plaza segura", "Sin peleas ni bestias",
           "Entrega de huevos", "Incubadora", "Colección de Lumipols", "Guantes", "Entrenamiento")


def luau_block_balance(text):
    """Rough Luau block check: function/do/if/repeat open, end/until close. Strings and comments stripped."""
    text = re.sub(r"\[==\[.*?\]==\]", "", text, flags=re.S)
    text = re.sub(r"--.*", "", text)
    text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
    opens = len(re.findall(r"\bfunction\b|\bdo\b|\bif\b|\brepeat\b", text))
    closes = len(re.findall(r"\bend\b|\buntil\b", text))
    return opens, closes


def code_marker_names():
    """Names the current server and clients look up by name (marker helpers and FindFirstChild on the map)."""
    names = set()
    for path in SRC.glob("*.luau"):
        text = path.read_text(encoding="utf-8")
        names.update(re.findall(r"(?:marker|optionalMarker)\(\"([A-Za-z_]+)\"", text))
        names.update(re.findall(r"FindFirstChild\(\"([A-Za-z_]+Marker|CampCenter|[A-Za-z_]+Center)\"", text))
    return names


class Rendering(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads(plan.to_json(plan.generate()))
        cls.data = kit.finalize(cls.layout)
        cls.parts = cls.data["parts"]
        cls.models = cls.data["models"]
        cls.module = kit.render(cls.layout)

    def model_of(self, row):
        return self.models[row["m"] - 1]

    def test_only_floors_and_walls_collide_or_answer_queries(self):
        for row in self.parts:
            self.assertIn(row["role"], kit.ROLES)
            if row["role"] == "floor":
                self.assertTrue(row["n"].startswith(FLOOR_NAMES), row["n"])
            elif row["role"] == "wall":
                self.assertTrue(row["n"].startswith(WALL_NAMES), row["n"])
            elif row["role"] == "zone":
                self.assertEqual(row.get("t"), 1, row["n"])
        self.assertIn("local solid = row.role == 'floor' or row.role == 'wall'", self.module)
        self.assertIn("item.CanCollide = solid", self.module)
        self.assertIn("item.CanQuery = solid", self.module)
        self.assertIn("item.CanTouch = false", self.module)
        self.assertIn("item.Anchored = true", self.module)
        for banned in ("Instance.new('MeshPart')", "Instance.new('SpecialMesh')", "rbxassetid", "InsertService",
                       "Instance.new('SpawnLocation')", "Instance.new('Script')", "Instance.new('LocalScript')", "MarketplaceService",
                       "DataStoreService", ".Touched"):
            self.assertFalse(banned in self.module, banned)

    def test_every_binding_tag_is_present_once_per_base(self):
        def tagged(tag):
            return ([r for r in self.parts if tag in r.get("tags", [])], [m for m in self.models if tag in m["tags"]])

        for tag in REQUIRED_TAGS:
            self.assertIn(tag, kit.TAGS)
            self.assertIn("'%s'" % tag, self.module)
        parts, models = tagged("WildboundBaseSlot")
        self.assertEqual(len(models), SLOTS)
        self.assertEqual(sorted(m["a"]["SlotIndex"] for m in models), list(range(1, SLOTS + 1)))
        for m in models:
            self.assertEqual(m["primary"], "Pad")
            self.assertEqual(m["a"]["OwnerUserId"], 0)
            self.assertIn("BaseColor", m["ca"])
        for tag, name in STATION_PARTS.items():
            parts, _ = tagged(tag)
            self.assertEqual(len(parts), SLOTS, tag)
            self.assertEqual({p["n"] for p in parts}, {name})
            self.assertEqual(sorted(p["a"]["SlotIndex"] for p in parts), list(range(1, SLOTS + 1)))
            for p in parts:
                self.assertTrue(p["a"]["Label"])
                self.assertGreater(p["a"]["Range"], 0)
        self.assertEqual(len(tagged("WildboundHubSafeZone")[0]), 1)
        self.assertEqual(len(tagged("WildboundHubEntrance")[0]), len(self.layout["entrances"]))
        self.assertEqual(len(tagged("WildboundHubSpawnPad")[0]), len(self.layout["lobby"]["spawn_pads"]))
        self.assertEqual(len(tagged("WildboundBaseSign")[0]), SLOTS)
        self.assertIn("CollectionService:AddTag(root, 'WildboundHub')", self.module)

    def test_station_markers_stand_where_the_plan_puts_them(self):
        for base in self.layout["bases"]:
            for s in base["stations"]:
                row = next(r for r in self.parts if s["tag"] in r.get("tags", []) and r["a"]["SlotIndex"] == base["slot"])
                self.assertAlmostEqual(row["p"][0], s["world"][0], places=3)
                self.assertAlmostEqual(row["p"][2], s["world"][1], places=3)
                self.assertEqual(self.model_of(row)["path"], "Bases/Base%d" % base["slot"])
                self.assertGreaterEqual(row["p"][1] - row["z"][1] / 2, base["pad"]["top"] - 1e-6)

    def test_budgets(self):
        counts = kit.part_count(self.layout)
        self.assertEqual(counts["total"], len(self.parts))
        self.assertLessEqual(counts["total"], PARTS_CAP)
        self.assertLessEqual(counts["lights"], LIGHTS_CAP)
        self.assertEqual(counts["lights"], len(self.layout["lights"]))
        self.assertIn("Builder.EXPECTED_PARTS = %d" % counts["total"], self.module)
        self.assertIn("Builder.EXPECTED_LIGHTS = %d" % counts["lights"], self.module)
        self.assertEqual(counts["per_base"] * SLOTS, counts["by_group"]["Bases"])
        light_ids = sorted(r["a"]["LightId"] for r in self.parts if "l" in r)
        self.assertEqual(light_ids, sorted(l["id"] for l in self.layout["lights"]))
        self.assertIn("light.Shadows = false", self.module)

    def test_shapes_roblox_allows(self):
        for row in self.parts:
            sx, sy, sz = row["z"]
            self.assertTrue(all(v > 0 for v in row["z"]), row["n"])
            self.assertLessEqual(max(row["z"]), 2048, row["n"])
            if row["s"] == "S":
                self.assertEqual(sx, sy, row["n"])
                self.assertEqual(sy, sz, row["n"])
            elif row["s"] == "C":
                self.assertEqual(sx, sz, row["n"])          # diameter, height, diameter
            elif row["s"] == "X":
                self.assertEqual(sy, sz, row["n"])          # length along local X, round cross-section
            self.assertIn(row["mt"], MATERIALS, row["n"])
            self.assertTrue(row["c"] in kit.PALETTE or re.fullmatch(r"#[0-9A-F]{6}", row["c"]), row["c"])
            self.assertGreaterEqual(row["p"][1] - sy / 2, -0.6, row["n"])
            self.assertLessEqual(row["p"][1] + sy / 2, 41.0, row["n"])

    def test_no_name_shadows_a_marker_the_current_code_looks_up(self):
        names = code_marker_names()
        self.assertIn("CampCenter", names)
        self.assertIn("IncubatorMarker", names)
        used = {r["n"] for r in self.parts} | {m["path"].split("/")[-1] for m in self.models} | {kit.ROOT_NAME}
        self.assertFalse(used & names, used & names)
        self.assertFalse([n for n in used if n.endswith("Marker")])
        self.assertNotEqual(kit.ROOT_NAME, "WildboundP0")

    def test_models_are_listed_parent_first(self):
        seen = set()
        for m in self.models:
            parent = m["path"].rsplit("/", 1)[0] if "/" in m["path"] else None
            if parent:
                self.assertIn(parent, seen, m["path"])
            seen.add(m["path"])
        self.assertEqual(len(seen), len(self.models))

    def test_spanish_signs_and_english_code(self):
        for text in SPANISH:
            self.assertIn(text, self.module, text)
        signs = [r for r in self.parts if "sign" in r]
        self.assertEqual(len(signs), SLOTS + len(self.layout["entrances"]) + 1)
        for r in signs:
            self.assertEqual(r["a"]["SignKey"], r["sign"]["key"])
        self.assertIn("gui.Face = Enum.NormalId.Front", self.module)

    def test_build_is_detached_attached_once_and_refuses_a_second_build(self):
        self.assertIn("function Builder.build(parent, origin)", self.module)
        self.assertIn("assert(not existingHub(parent), ROOT_NAME .. ' already exists')", self.module)
        body = self.module.split("function Builder.build(parent, origin)", 1)[1]
        self.assertLess(body.index("root:PivotTo(origin)"), body.index("root.Parent = parent"))
        self.assertLess(body.index("existingHub(parent) then"), body.index("root.Parent = parent"))
        self.assertEqual(body.count("root.Parent = parent"), 1)
        self.assertIn("root.WorldPivot = CFrame.new(0, 0, 0)", body)
        self.assertIn("assert(created == Builder.EXPECTED_PARTS", body)
        self.assertIn("root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent", body)
        self.assertIn("root:Destroy()", body)

    def test_luau_blocks_balance(self):
        opens, closes = luau_block_balance(self.module)
        self.assertEqual(opens, closes)
        self.assertEqual(self.module.count("[==["), self.module.count("]==]"))
        self.assertTrue(self.module.rstrip().endswith("return Builder"))

    def test_data_block_round_trips(self):
        data = json.loads(self.module.split("local DATA = [==[", 1)[1].split("]==]", 1)[0])
        self.assertEqual(data, self.data)
        head = self.module.splitlines()[0]
        self.assertIn("GENERATED by tools/build-hub-map.py", head)
        self.assertIn("seed %d" % self.layout["seed"], head)
        self.assertIn("Adler-32 %d" % kit.adler32(kit.data_text(self.layout)), head)

    def test_rendering_is_deterministic(self):
        self.assertEqual(self.module, kit.render(self.layout))

    def test_validation_rejects_bad_plans(self):
        broken = json.loads(json.dumps(self.layout))
        broken["bases"] = broken["bases"][:7]
        with self.assertRaises(ValueError):
            kit.render(broken)
        broken = json.loads(json.dumps(self.layout))
        broken["bases"][0]["stations"] = broken["bases"][0]["stations"][1:]
        with self.assertRaises(ValueError):
            kit.render(broken)
        broken = json.loads(json.dumps(self.layout))
        broken["lights"].append(dict(broken["lights"][0]))
        with self.assertRaises(ValueError):
            kit.render(broken)


class WrittenFiles(unittest.TestCase):
    def test_saved_module_is_fresh(self):
        if not kit.MODULE.exists() or not kit.PLAN.exists():
            self.skipTest("module not written yet")
        layout = json.loads(kit.PLAN.read_text(encoding="utf-8"))
        self.assertEqual(kit.MODULE.read_text(encoding="utf-8"), kit.render(layout))
        self.assertEqual(kit.MODULE.read_bytes().count(b"\r\n"), 0, "LF line endings")

    def test_saved_report_matches_the_module(self):
        if not kit.REPORT.exists() or not kit.MODULE.exists():
            self.skipTest("report not written yet")
        report = json.loads(kit.REPORT.read_text(encoding="utf-8"))
        self.assertEqual(report["module_adler32"], kit.adler32(kit.MODULE.read_text(encoding="utf-8")))
        layout = json.loads(kit.PLAN.read_text(encoding="utf-8"))
        self.assertEqual(report["parts"], kit.part_count(layout))
        self.assertIn("unvalidated", report["status"])
        for tag in REQUIRED_TAGS:
            self.assertGreater(report["tags"][tag], 0, tag)


if __name__ == "__main__":
    unittest.main()
