"""Spec tests for the camp and landmark kit (roadmap M8.2; expansion bible 5.1 and 5.2).

Run with: python -I -B -m unittest discover -s tools -p "test_camp_kit.py"

Standard library only. Artifacts come from tools/build-camp-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-camp-kit.py
  CAMP_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-camp-kit.py

The table below is the contract, written before the builder. Sizes, shells, clearances and
placements are recomputed from the geometry dump, and the stand-in sizes and marker positions
are parsed from tools/build-wildbound-p0-map.luau so they cannot drift from the builder.
Every value is unvalidated: nothing was imported into Roblox, so scale there, the Studio axis
conversion and phone cost stay unmeasured. Kit meshes stay non-colliding.
"""

import math
import re
import unittest

from kit_spec_common import ROOT, AssetSpecMixin, bounds, asset_triangles, load_json, png_size

KIT_DIR = ROOT / "assets/blender/camp-kit"
EXPORT_DIR = ROOT / "assets/exports/camp-kit"
MAP_SOURCE = ROOT / "tools/build-wildbound-p0-map.luau"

# The Fog Forest palette of the forest kit (tools/build-forest-kit.py) and the map's marker cyan.
FOG_FOREST_PALETTE = {"2B4034", "4C3226", "6B7036", "55585D", "BE9C70", "A06A3A", "9C8152", "2C2D30", "F08C2E",
                      "66D2CA"}

# size is (x, y, z) in studs, tris the ceiling, parts map label to (hex, part ceiling).
SPECS = {
    "CP_Campfire": {
        "size": (6.0, 6.0, 3.6), "tris": 400,
        "parts": {"Stones": ("55585D", 150), "Logs": ("4C3226", 170), "Neon_Flame": ("F08C2E", 70)},
    },
    "CP_CampShelter": {
        "size": (6.0, 8.0, 5.0), "tris": 520,
        "parts": {"Canvas": ("BE9C70", 200), "Poles": ("4C3226", 200), "Rope": ("9C8152", 100)},
    },
    "CP_HatchAltar": {
        "size": (5.0, 5.0, 3.0), "tris": 340,
        "parts": {"Stone": ("55585D", 200), "Moss": ("6B7036", 60), "Neon_Rune": ("66D2CA", 80)},
    },
    "CP_ExtractionMarker": {
        "size": (3.0, 3.0, 9.0), "tris": 420,
        "parts": {"Post": ("4C3226", 150), "Iron": ("2C2D30", 90), "Stones": ("55585D", 100),
                  "Neon_Beacon": ("66D2CA", 80)},
    },
    "CP_EggNest": {
        "size": (17.0, 17.0, 4.5), "tris": 620,
        "parts": {"Stones": ("55585D", 220), "Twigs": ("4C3226", 240), "Egg": ("BE9C70", 90),
                  "Neon_Speck": ("66D2CA", 70)},
    },
    "CP_MarshShelter": {
        "size": (18.0, 12.0, 11.0), "tris": 800,
        "parts": {"Posts": ("4C3226", 260), "Roof": ("9C8152", 340), "Moss": ("6B7036", 80),
                  "Iron": ("2C2D30", 50), "Neon_Lamp": ("F08C2E", 50)},
    },
}

# Where each asset origin goes: (map marker, offset in Studio X and Z), or a fixed Studio position.
# Studio X is minus Blender X and Studio Z is Blender Y (fog-forest-visual-kit.md:63). The camp shelter
# stands beside the camp, facing +Y (+Z in Studio) toward the fire.
PLACEMENTS = {
    "CP_Campfire": ("CampCenter", (0.0, 0.0)),
    "CP_ExtractionMarker": ("ExtractionMarker", (0.0, 0.0)),
    "CP_HatchAltar": ("HatchMarker", (0.0, 0.0)),
    "CP_CampShelter": ("ProtectionMarker", (4.0, -3.0)),
    "CP_EggNest": ("EggMarker", (0.0, 0.0)),
    "CP_MarshShelter": (None, (105.0, 125.0)),
}
MIN_GAP = 0.4  # studs between two kit footprints in the camp


def shells(part):
    """Vertex-connected shells of one dumped part, each as a list of coordinate triangles."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    grouped = {}
    for triple in part["triangles"]:
        grouped.setdefault(find(triple[0]), []).append([part["vertices"][i] for i in triple])
    return list(grouped.values())


def shell_points(shell):
    return sorted({tuple(v) for triangle in shell for v in triangle})


def centroid(points):
    return tuple(sum(p[i] for p in points) / len(points) for i in range(3))


def parse_map():
    """Stand-in sizes and marker positions, read from the P0 map builder."""
    text = MAP_SOURCE.read_text(encoding="utf-8")
    markers = {name: (float(x), float(z)) for name, x, z in
               re.findall(r"addMarker\(markers, '(\w+)', (-?[\d.]+), (-?[\d.]+)\)", text)}
    roof = re.search(r"'ShelterRoof', Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\), CFrame\.new\((-?[\d.]+), "
                     r"(-?[\d.]+), (-?[\d.]+)\)", text)
    lines = text.splitlines()
    roof_line = next(i for i, line in enumerate(lines) if "'ShelterRoof'" in line)
    offsets_line = next(line for line in lines[roof_line:] if "ipairs({" in line)
    offsets = [(float(x), float(z)) for x, z in re.findall(r"Vector3\.new\((-?[\d.]+), 0, (-?[\d.]+)\)", offsets_line)]
    post = re.search(r"'ShelterPost', Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\)", text)
    base = re.search(r"'CampfireBase', Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\), CFrame\.new\((-?[\d.]+), "
                     r"(-?[\d.]+), (-?[\d.]+)\)", text)
    glow = re.search(r"'CampfireGlow', Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\), CFrame\.new\((-?[\d.]+), "
                     r"(-?[\d.]+), (-?[\d.]+)\)", text)
    ring = re.search(r"for index = 1, (\d+) do\s+local angle = index \* math\.pi / \d+\s+local x, z = (-?\d+) \+ "
                     r"math\.cos\(angle\) \* (\d+), (-?\d+) \+ math\.sin\(angle\) \* (\d+)", text)
    stone = re.search(r"'NestStone', Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\)", text)
    return {
        "markers": markers,
        "roof": {"size": tuple(map(float, roof.groups()[:3])), "pos": tuple(map(float, roof.groups()[3:]))},
        "post_offsets": offsets, "post_size": tuple(map(float, post.groups())),
        "campfire_base": {"size": tuple(map(float, base.groups()[:3])), "pos": tuple(map(float, base.groups()[3:]))},
        "campfire_glow": {"size": tuple(map(float, glow.groups()[:3])), "pos": tuple(map(float, glow.groups()[3:]))},
        "nest_ring": {"count": int(ring.group(1)), "center": (float(ring.group(2)), float(ring.group(4))),
                      "radius": float(ring.group(3))},
        "nest_stone": tuple(map(float, stone.groups())),
    }


class CampKitAssets(AssetSpecMixin, unittest.TestCase):
    """G1 to G14 from the bible, for all six assets."""

    SPECS = SPECS
    ASSET_KEY = "props"
    REPORT = KIT_DIR / "camp-kit-report.json"
    GEOMETRY = KIT_DIR / "camp-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "camp-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


class CampKitReport(unittest.TestCase):
    """Kit report format of bible 5.2, plus the rules that belong to this kit only."""

    @classmethod
    def setUpClass(cls):
        cls.report = load_json(CampKitAssets.REPORT)
        cls.geometry = load_json(CampKitAssets.GEOMETRY)
        cls.props = cls.report["props"]

    def test_report_keys_follow_the_kit_format(self):
        for key in ("generator", "blender_version", "unvalidated", "studs_per_blender_unit", "fbx_settings",
                    "roblox_scale_verified", "scale_note", "scale_block_height", "sheet_file", "lineup_file",
                    "blend", "props"):
            self.assertIn(key, self.report)
        self.assertEqual(self.report["generator"], "tools/build-camp-kit.py")
        self.assertTrue(self.report["unvalidated"])
        self.assertFalse(self.report["roblox_scale_verified"])
        self.assertEqual(self.report["studs_per_blender_unit"], 1.0)
        settings = self.report["fbx_settings"]
        self.assertEqual(settings["apply_scale_options"], "FBX_SCALE_ALL", "kits use FBX_SCALE_ALL (bible 5.1)")
        self.assertFalse(settings["add_leaf_bones"])
        self.assertEqual((settings["axis_forward"], settings["axis_up"]), ("-Z", "Y"))
        for name, spec in SPECS.items():
            entry = self.props[name]
            for key in ("status", "triangles", "size", "bbox_min", "bbox_max", "base_center", "non_manifold_edges",
                        "flat_shaded", "transforms_applied", "fit_scale", "parts", "fbx", "render"):
                self.assertIn(key, entry, f"{name} lacks {key}")
            self.assertEqual(entry["status"], "unvalidated")
            self.assertEqual(sorted(entry["fbx"]), ["model"])
            for part in entry["parts"]:
                self.assertIn("palette_name", part)

    def test_sheet_is_1500_by_1000_for_six_props_and_the_lineup_is_wide(self):
        self.assertEqual(png_size(KIT_DIR / self.report["sheet_file"]), (1500, 1000))
        self.assertGreaterEqual(png_size(KIT_DIR / self.report["lineup_file"])[0], 2000)

    def test_every_color_is_in_the_fog_forest_palette(self):
        for name, spec in SPECS.items():
            for label, (colour, _) in spec["parts"].items():
                self.assertIn(colour, FOG_FOREST_PALETTE, f"{name} {label}")

    def test_meshes_are_non_colliding_with_no_collision_boxes_listed(self):
        for name in SPECS:
            entry = self.props[name]
            self.assertEqual(entry["collision"], "none", name)
            self.assertNotIn("collision_boxes", entry)
            self.assertNotIn("occluders", entry)

    def test_only_the_light_giving_parts_are_neon(self):
        neon = {name: sorted(label for label in spec["parts"] if label.startswith("Neon_"))
                for name, spec in SPECS.items()}
        self.assertEqual(neon["CP_Campfire"], ["Neon_Flame"])
        self.assertEqual(neon["CP_CampShelter"], [])
        self.assertEqual(neon["CP_HatchAltar"], ["Neon_Rune"])
        self.assertEqual(neon["CP_ExtractionMarker"], ["Neon_Beacon"])
        self.assertEqual(neon["CP_EggNest"], ["Neon_Speck"])
        self.assertEqual(neon["CP_MarshShelter"], ["Neon_Lamp"])

    def test_each_asset_is_a_set_of_hand_cut_shells_not_a_single_primitive(self):
        for name, spec in SPECS.items():
            total = sum(len(shells(self.geometry[name]["parts"][f"{name}_{label}"])) for label in spec["parts"])
            self.assertGreaterEqual(total, 6, f"{name} has only {total} shells")

    def part(self, name, label):
        return self.geometry[name]["parts"][f"{name}_{label}"]

    def test_campfire_is_a_ring_of_stones_around_logs_and_a_flame(self):
        name = "CP_Campfire"
        stones, logs, flame = (shells(self.part(name, label)) for label in ("Stones", "Logs", "Neon_Flame"))
        self.assertEqual(len(stones), 8)
        self.assertGreaterEqual(len(logs), 5)
        self.assertGreaterEqual(len(flame), 3, "a flame of several tongues")
        for shell in stones:
            radius = math.hypot(*centroid(shell_points(shell))[:2])
            self.assertTrue(1.9 <= radius <= 2.9, f"stone at radius {radius:.2f} is off the ring")
        tops = [max(v[2] for t in shell for v in t) for shell in stones]
        self.assertLessEqual(max(tops), 1.0, "stones are low so the fire reads over them")
        flame_points = [v for shell in flame for v in shell_points(shell)]
        self.assertGreaterEqual(max(v[2] for v in flame_points), 2.8)
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in flame_points), 1.6, "the flame sits inside the ring")

    def test_camp_shelter_is_an_open_fronted_a_frame_with_lashed_poles(self):
        name = "CP_CampShelter"
        canvas = shells(self.part(name, "Canvas"))
        poles = shells(self.part(name, "Poles"))
        rope = shells(self.part(name, "Rope"))
        self.assertGreaterEqual(len(canvas), 2, "two roof panels")
        self.assertGreaterEqual(len(poles), 5)
        self.assertGreaterEqual(len(rope), 4, "lashings at the joints")
        low, high = bounds(asset_triangles(self.geometry[name]))
        ridge = max(v[2] for shell in poles for t in shell for v in t)
        self.assertGreaterEqual(ridge, 4.5)
        eaves = [centroid(shell_points(s)) for s in canvas]
        for centre in eaves:
            self.assertGreater(abs(centre[0]), 0.6, "panels slope away from the ridge on both sides")
        self.assertLess(min(c[0] for c in eaves), 0.0)
        self.assertGreater(max(c[0] for c in eaves), 0.0)
        front = [v for shell in canvas for t in shell for v in t if v[1] > high[1] - 0.3]
        self.assertTrue(front)
        self.assertLessEqual(min(v[2] for v in front), 1.5, "front edge of the panels reaches the ground")

    def test_hatch_altar_has_an_open_cradle_and_glowing_runes(self):
        name = "CP_HatchAltar"
        stone = self.part(name, "Stone")
        near = [v for t in stone["triangles"] for i in t for v in [stone["vertices"][i]]
                if math.hypot(v[0], v[1]) < 1.0]
        self.assertTrue(near)
        self.assertLessEqual(max(v[2] for v in near), 2.5, "the middle is a dish, so the egg sits in it")
        low, high = bounds(asset_triangles(self.geometry[name]))
        rim = [v for t in stone["triangles"] for i in t for v in [stone["vertices"][i]]
               if v[2] >= high[2] - 0.15]
        self.assertTrue(rim)
        self.assertGreaterEqual(max(math.hypot(v[0], v[1]) for v in rim), 1.4, "a raised rim around the dish")
        self.assertGreaterEqual(len(shells(self.part(name, "Neon_Rune"))), 4)

    def test_extraction_marker_is_tall_with_a_cyan_beacon_on_top(self):
        name = "CP_ExtractionMarker"
        beacon = [v for shell in shells(self.part(name, "Neon_Beacon")) for v in shell_points(shell)]
        self.assertGreaterEqual(min(v[2] for v in beacon), 6.0, "the beacon is the top of the marker")
        self.assertGreaterEqual(max(v[2] for v in beacon), 8.4)
        self.assertGreaterEqual(len(shells(self.part(name, "Stones"))), 3, "a small cairn at the foot")
        self.assertLessEqual(max(v[2] for shell in shells(self.part(name, "Stones")) for t in shell for v in t), 1.4)

    def test_egg_nest_holds_three_eggs_in_a_bowl_with_the_middle_left_clear(self):
        name = "CP_EggNest"
        eggs = shells(self.part(name, "Egg"))
        self.assertEqual(len(eggs), 3)
        for shell in eggs:
            points = shell_points(shell)
            c = centroid(points)
            self.assertTrue(1.6 <= math.hypot(c[0], c[1]) <= 4.2, "eggs sit around the middle, not on it")
            self.assertGreaterEqual(max(v[2] for v in points) - min(v[2] for v in points), 2.0)
        self.assertEqual(len(shells(self.part(name, "Stones"))), 8, "a ring of eight stones like the stand-in")
        twigs = self.part(name, "Twigs")
        middle = [twigs["vertices"][i] for t in twigs["triangles"] for i in t
                  if math.hypot(twigs["vertices"][i][0], twigs["vertices"][i][1]) < 1.2]
        self.assertTrue(middle, "the bowl has a floor")
        self.assertLessEqual(max(v[2] for v in middle), 1.2, "no twig stands where the egg is picked up")
        for label in ("Egg", "Stones", "Twigs", "Neon_Speck"):
            for v in self.part(name, label)["vertices"]:
                if math.hypot(v[0], v[1]) < 1.2:
                    self.assertLessEqual(v[2], 1.2, f"{label} blocks the pickup point")

    def test_marsh_shelter_stands_on_four_posts_under_a_roof_you_can_walk_beneath(self):
        name = "CP_MarshShelter"
        posts = self.part(name, "Posts")
        feet = [v for v in posts["vertices"] if v[2] < 0.6]
        for x in (-7.0, 7.0):
            for y in (-4.0, 4.0):
                near = [v for v in feet if math.hypot(v[0] - x, v[1] - y) < 1.2]
                self.assertTrue(near, f"no post foot near ({x}, {y})")
        self.assertGreaterEqual(max(v[2] for v in posts["vertices"]), 8.4)
        roof = self.part(name, "Roof")["vertices"]
        self.assertGreaterEqual(min(v[2] for v in roof), 7.5, "a 5-stud avatar walks under the eaves")
        low, high = bounds(asset_triangles(self.geometry[name]))
        self.assertGreaterEqual(max(v[2] for v in roof), high[2] - 0.05, "the roof is the top of the shelter")
        self.assertGreaterEqual(max(abs(v[0]) for v in roof), 8.5)
        self.assertGreaterEqual(max(abs(v[1]) for v in roof), 5.5)
        lamp = [v for shell in shells(self.part(name, "Neon_Lamp")) for v in shell_points(shell)]
        self.assertLessEqual(max(v[2] for v in lamp), 8.0, "the lamp hangs under the roof")
        self.assertGreaterEqual(min(v[2] for v in lamp), 5.5)


def hull_area(points):
    """Area of the convex hull of 2D points (monotone chain)."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in points))
    if len(pts) < 3:
        return 0.0

    def half(sequence):
        out = []
        for p in sequence:
            while len(out) >= 2 and ((out[-1][0] - out[-2][0]) * (p[1] - out[-2][1])
                                     - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0])) <= 0:
                out.pop()
            out.append(p)
        return out[:-1]

    ring = half(pts) + half(reversed(pts))
    return abs(sum(ring[i][0] * ring[(i + 1) % len(ring)][1] - ring[(i + 1) % len(ring)][0] * ring[i][1]
                   for i in range(len(ring)))) / 2.0


class CampKitReads(unittest.TestCase):
    """Visual reads of the W16 art pass. Each one failed on the geometry it replaced: a round cauldron, bipyramid
    gems for eggs and a flat-bottomed table top for the marsh roof."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(CampKitAssets.GEOMETRY)

    def part(self, name, label):
        return self.geometry[name]["parts"][f"{name}_{label}"]

    def test_hatch_altar_is_a_square_cut_slab_stack_not_a_round_cauldron(self):
        name = "CP_HatchAltar"
        stone = self.part(name, "Stone")
        points = [tuple(v) for v in stone["vertices"]]
        reach = max(math.hypot(p[0], p[1]) for p in points)
        fill = hull_area(points) / (math.pi * reach * reach)
        self.assertLessEqual(fill, 0.8, f"the footprint fills {fill:.2f} of its circle: that is a round pot")
        self.assertGreaterEqual(len(shells(stone)), 6, "base slab, step, plinth, top frame, rim stones, rubble")

    def test_hatch_altar_has_a_wide_capstone_over_a_narrower_plinth_and_a_shallow_dish(self):
        name = "CP_HatchAltar"
        stone = self.part(name, "Stone")
        found = []
        for shell in shells(stone):
            points = shell_points(shell)
            extent = max(max(p[i] for p in points) - min(p[i] for p in points) for i in (0, 1))
            found.append((min(p[2] for p in points), max(p[2] for p in points), extent))
        self.assertTrue(any(low >= 2.0 and extent >= 4.0 for low, _, extent in found), "a capstone frame")
        self.assertTrue(any(low >= 1.0 and high <= 2.6 and extent <= 3.6 for low, high, extent in found),
                        "a plinth narrower than the capstone")
        vertices = stone["vertices"]
        centre = [v[2] for v in vertices if math.hypot(v[0], v[1]) < 1.0]
        rim = [v[2] for v in vertices if 1.3 < math.hypot(v[0], v[1]) < 2.4 and v[2] > 2.5]
        self.assertTrue(centre and rim)
        self.assertLessEqual(max(rim) - max(centre), 1.0, "a shallow offering dish, not a deep bowl")

    def test_eggs_have_a_blunt_crown_not_the_points_of_a_gem(self):
        eggs = shells(self.part("CP_EggNest", "Egg"))
        self.assertEqual(len(eggs), 3)

        def spread(points):
            middle = centroid(points)
            return max(math.hypot(p[0] - middle[0], p[1] - middle[1]) for p in points)

        for shell in eggs:
            points = shell_points(shell)
            low, top = min(p[2] for p in points), max(p[2] for p in points)
            height = top - low
            crown = [p for p in points if p[2] >= top - 0.12 * height]
            self.assertGreaterEqual(len(crown), 4, "a flat top ring, not a single tip")
            self.assertGreaterEqual(spread(crown) / spread(points), 0.38,
                                    "an egg ends in a blunt dome; a gem ends in a point")
            width = max(max(p[i] for p in points) - min(p[i] for p in points) for i in (0, 1))
            self.assertTrue(1.15 <= height / width <= 1.8, "an egg is a good deal taller than wide")

    def test_egg_specks_are_small_and_scattered_over_every_egg(self):
        specks = shells(self.part("CP_EggNest", "Neon_Speck"))
        self.assertGreaterEqual(len(specks), 5)
        for shell in specks:
            points = shell_points(shell)
            size = max(max(p[i] for p in points) - min(p[i] for p in points) for i in range(3))
            self.assertLessEqual(size, 0.3, "subtle speckle, not cyan studs")

    def test_marsh_roof_is_a_pitched_run_of_irregular_planks_that_overhang(self):
        name = "CP_MarshShelter"
        roof = self.part(name, "Roof")
        self.assertGreaterEqual(len(shells(roof)), 14, "separate planks, ridge and cap")
        verts = roof["vertices"]

        def underside(low, high):
            return min(v[2] for v in verts if low <= abs(v[1]) <= high)

        self.assertGreaterEqual(underside(0.4, 1.5) - underside(4.8, 6.4), 1.5,
                                "the underside rises to the ridge: a flat underside reads as a table top")
        eaves = [v[2] for v in verts if abs(v[1]) > 4.8]
        self.assertGreaterEqual(max(eaves) - min(eaves), 0.9, "ragged eaves, not one straight edge")
        ends = sorted({round(v[0], 1) for v in verts if abs(v[1]) > 5.0})
        self.assertGreaterEqual(len(ends), 10, "plank ends are at many different positions")


class CampKitFitsTheMap(unittest.TestCase):
    """The kit replaces the primitive stand-ins, so it must fit their footprints and marker positions."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(CampKitAssets.GEOMETRY)
        cls.map = parse_map()

    def footprint(self, name):
        """Studio X and Z rectangle of an asset at its placement. Studio X is minus Blender X."""
        marker, (dx, dz) = PLACEMENTS[name]
        ox, oz = (self.map["markers"][marker] if marker else (0.0, 0.0))
        ox, oz = ox + dx, oz + dz
        low, high = bounds(asset_triangles(self.geometry[name]))
        return (ox - high[0], ox - low[0]), (oz + low[1], oz + high[1])

    def test_the_map_source_still_has_the_stand_ins_this_kit_replaces(self):
        self.assertEqual(self.map["roof"]["size"], (18.0, 1.0, 12.0))
        self.assertEqual(sorted(self.map["post_offsets"]), [(-7.0, -4.0), (-7.0, 4.0), (7.0, -4.0), (7.0, 4.0)])
        self.assertEqual(self.map["nest_ring"]["count"], 8)
        self.assertEqual(self.map["nest_ring"]["radius"], 9.0)
        self.assertEqual(self.map["campfire_base"]["size"][0], 5.0)
        for name in ("CampCenter", "ExtractionMarker", "HatchMarker", "ProtectionMarker", "EggMarker"):
            self.assertIn(name, self.map["markers"])

    def test_marsh_shelter_matches_the_roof_and_post_stand_ins(self):
        low, high = bounds(asset_triangles(self.geometry["CP_MarshShelter"]))
        size = [b - a for a, b in zip(low, high)]
        roof = self.map["roof"]["size"]
        self.assertAlmostEqual(size[0], roof[0], delta=0.1 * roof[0])
        self.assertAlmostEqual(size[1], roof[2], delta=0.1 * roof[2])
        stand_in_top = self.map["roof"]["pos"][1] + roof[1] / 2
        self.assertAlmostEqual(size[2], stand_in_top + 0.5, delta=1.0, msg="roof top is where the stand-in roof was")
        origin = (self.map["roof"]["pos"][0], self.map["roof"]["pos"][2])
        self.assertEqual(PLACEMENTS["CP_MarshShelter"][1], origin)

    def test_egg_nest_replaces_the_stone_ring_and_stays_inside_it_plus_its_stones(self):
        ring = self.map["nest_ring"]
        stone_reach = max(self.map["nest_stone"][0], self.map["nest_stone"][2]) / 2
        (x0, x1), (z0, z1) = self.footprint("CP_EggNest")
        width, depth = x1 - x0, z1 - z0
        self.assertLessEqual(max(width, depth), 2 * (ring["radius"] + stone_reach), "no wider than the old ring")
        self.assertGreaterEqual(min(width, depth), 1.6 * ring["radius"], "wide enough to replace the ring")
        marker = self.map["markers"]["EggMarker"]
        self.assertEqual(marker, ring["center"])
        self.assertTrue(x0 <= marker[0] <= x1 and z0 <= marker[1] <= z1, "the egg marker is in the nest")

    def test_campfire_covers_the_stand_in_base_and_stays_inside_its_glow_envelope(self):
        (x0, x1), (z0, z1) = self.footprint("CP_Campfire")
        base = self.map["campfire_base"]["size"][0]
        self.assertGreaterEqual(x1 - x0, base)
        self.assertLessEqual(x1 - x0, 1.4 * base)
        glow = self.map["campfire_glow"]
        low, high = bounds(asset_triangles(self.geometry["CP_Campfire"]))
        self.assertAlmostEqual(high[2], glow["pos"][1] + glow["size"][1] / 2, delta=0.8)
        centre = self.map["markers"]["CampCenter"]
        self.assertTrue(x0 <= centre[0] <= x1 and z0 <= centre[1] <= z1)

    def test_markers_sit_inside_or_beside_the_assets_that_replace_their_stand_ins(self):
        for name, marker in (("CP_ExtractionMarker", "ExtractionMarker"), ("CP_HatchAltar", "HatchMarker")):
            (x0, x1), (z0, z1) = self.footprint(name)
            x, z = self.map["markers"][marker]
            self.assertTrue(x0 <= x <= x1 and z0 <= z <= z1, f"{marker} is inside the {name} footprint")
        (x0, x1), (z0, z1) = self.footprint("CP_CampShelter")
        x, z = self.map["markers"]["ProtectionMarker"]
        self.assertLessEqual(math.hypot(max(x0 - x, 0, x - x1), max(z0 - z, 0, z - z1)), 4.0,
                             "the camp shelter stands next to the protection marker")

    def test_no_two_camp_footprints_overlap_and_all_stay_on_the_map(self):
        camp = ("CP_Campfire", "CP_ExtractionMarker", "CP_HatchAltar", "CP_CampShelter")
        boxes = {name: self.footprint(name) for name in SPECS}
        for index, first in enumerate(camp):
            for second in camp[index + 1:]:
                (ax0, ax1), (az0, az1) = boxes[first]
                (bx0, bx1), (bz0, bz1) = boxes[second]
                gap_x, gap_z = max(bx0 - ax1, ax0 - bx1), max(bz0 - az1, az0 - bz1)
                self.assertGreaterEqual(max(gap_x, gap_z), MIN_GAP, f"{first} and {second} touch or overlap")
        for name, ((x0, x1), (z0, z1)) in boxes.items():
            for value in (x0, x1, z0, z1):
                self.assertLessEqual(abs(value), 198.0, f"{name} leaves the 400 x 400 floor")


if __name__ == "__main__":
    unittest.main()
