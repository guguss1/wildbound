"""Contract for the Caramelo v3 decor kit (CV3_), built by tools/build-caramelo-v3-decor-kit.py.

Standard library only; nothing here imports Blender. Source: the owner's "Caramelo v3" reference
sheets in assets/reference/caramelo-v3/ (04 to 10). The sheets are art references, not 3D files,
so every size below is a hypothesis, unvalidated until a real Roblox import.

Axes are Blender axes (Z up, 1 unit = 1 stud). The front of every asset is -Y (Roblox -Z).
SPECS follows the biome kit format (tools/biome_kit_spec.py, tools/kit_spec_common.py):
  size (x, y, z), tris ceiling, parts {label: (hex, part budget)}, plus the optional
  walk / ramps / clear keys. This kit adds:
  sway   labels that move together as one crown (no rig; a script sways them)
  water  role -> label for the chocolate waterfall pieces (separate meshes on purpose)
  snap   cake modules only: the module family they snap into
"""

TREE_TRI_CAP = 2500
ASSET_TRI_CAP = 5000
TRUNK_DIAMETER = (2.0, 3.0)
COLLISION_PREFIX = "Collision_"

# Pastel candy palette, picked from the sheets and the existing candy kit (WildboundCandyKit.luau).
PALETTE = {
    "CottonPink": "FF96BE", "CaneWhite": "FFF7EE", "CaneBlue": "9DB8F0",
    "Mint": "9EE6C8", "TwistRed": "D7323F", "Cherry": "C8102E", "ChocChip": "5C3A2C",
    "StickWood": "C69C6D", "Glaze": "D91E36", "AppleGreen": "B9D35A",
    "MountainBrown": "B07868", "RockPink": "E9A3B5", "Fudge": "5A2E22", "SauceStrawberry": "F27BA0",
    "Cream": "FFF3E6", "Berry": "E8475F", "Stem": "7A5A2A", "River": "6B3A28",
    "LicPink": "F75C9B", "LicOrange": "F9A03F", "LicYellow": "FBE15E", "LicGreen": "7DD35A",
    "LicBlue": "5CC2F0", "LicPurple": "B57BE8", "Cloud": "FFF0F6",
    "CakeBody": "FBE0D0", "CakePink": "F2668B", "Frosting": "FFF7EE", "CookieOrange": "F7A538",
    "Sponge": "F9D776", "CandleTeal": "7FDCD0", "Flame": "FFB23F",
    "Dough": "E9A25A",
}


def parts(**labels):
    """parts(Trunk=("CaneWhite", 400)) -> {"Trunk": ("FFF7EE", 400)}."""
    return {label: (PALETTE[colour], budget) for label, (colour, budget) in labels.items()}


def mountain_parts(scale):
    return parts(Base=("MountainBrown", 800), Rocks=("RockPink", 400), Fudge=("Fudge", 420),
                 Sauce=("SauceStrawberry", 420), Scoop=("Cream", 900), Berries=("Berry", 160),
                 Cherry=("Cherry", 120), CherryStem=("Stem", 40), River=("River", 120),
                 Waterfall=("River", 160), Pool=("River", 120), PoolLip=("RockPink", 260))


MOUNTAIN_WATER = {"river": "River", "waterfall": "Waterfall", "pool": "Pool", "pool_lip": "PoolLip"}

# Order is the sheet order (6 columns x 2 rows) and the lineup order.
SPECS = {
    "CV3_TreeCotton": {
        "size": (16.8239, 16.553, 25.8), "tris": 1700,
        "parts": parts(Trunk=("CaneWhite", 200), Stripe=("CaneBlue", 500), Crown=("CottonPink", 1700)),
        "sway": ["Crown"],
    },
    "CV3_TreeIceCream": {
        "size": (18.3511, 17.6181, 26.7893), "tris": 1700,
        "parts": parts(Trunk=("TwistRed", 260), Crown=("Mint", 900), CrownChips=("ChocChip", 520),
                       CrownCherry=("Cherry", 120)),
        "sway": ["Crown", "CrownChips", "CrownCherry"],
    },
    "CV3_TreeCaramelApple": {
        "size": (15.4296, 15.8264, 23.9637), "tris": 700,
        "parts": parts(Trunk=("StickWood", 120), Crown=("Glaze", 600), CrownApple=("AppleGreen", 400)),
        "sway": ["Crown", "CrownApple"],
    },
    "CV3_IceCreamMountain_L": {
        "size": (103.4246, 99.6437, 90.431), "tris": 3600,
        "parts": mountain_parts(1.0), "water": MOUNTAIN_WATER,
    },
    "CV3_IceCreamMountain_M": {
        "size": (68.8138, 64.481, 60.3078), "tris": 3600,
        "parts": mountain_parts(1.0), "water": MOUNTAIN_WATER,
    },
    "CV3_LicoriceArch": {
        "size": (77.8259, 12.6751, 33.7498), "tris": 3800,
        "parts": parts(Pink=("LicPink", 520), Orange=("LicOrange", 520), Yellow=("LicYellow", 520),
                       Green=("LicGreen", 520), Blue=("LicBlue", 520), Purple=("LicPurple", 520),
                       Clouds=("Cloud", 800)),
        "clear": (24.0, 18.0),
    },
    "CV3_CakeBase": {
        "size": (44.2891, 45.0089, 14.75), "tris": 3000,
        "parts": parts(Body=("CakeBody", 200), Band=("CakePink", 800), Frosting=("Frosting", 1200),
                       Cookies=("CookieOrange", 560)),
        "walk": 12.0, "ramps": 0, "snap": "cake",
    },
    "CV3_CakeRamp": {
        "size": (10.4, 28.0, 12.6), "tris": 130,
        "parts": parts(Sponge=("Sponge", 40), Cream=("Frosting", 40), Icing=("CakePink", 120)),
        "walk": 12.0, "ramps": 1, "snap": "cake",
    },
    "CV3_CakeTop": {
        "size": (27.8276, 31.7358, 15.0), "tris": 2300,
        "parts": parts(Body=("CakeBody", 160), Band=("CakePink", 900), Frosting=("Frosting", 700),
                       Candles=("CandleTeal", 200), Neon_Flames=("Flame", 100)),
        "walk": 9.0, "ramps": 0, "snap": "cake",
    },
    "CV3_CookieS": {
        "size": (7.7217, 7.7918, 1.75), "tris": 270,
        "parts": parts(Dough=("Dough", 140), Chips=("ChocChip", 80)),
        "walk": 1.6, "ramps": 0,
    },
    "CV3_CookieM": {
        "size": (13.4725, 13.3282, 2.15), "tris": 400,
        "parts": parts(Dough=("Dough", 200), Chips=("ChocChip", 160)),
        "walk": 2.0, "ramps": 0,
    },
    "CV3_CookieL": {
        "size": (23.2988, 23.2976, 2.75), "tris": 620,
        "parts": parts(Dough=("Dough", 300), Chips=("ChocChip", 300)),
        "walk": 2.6, "ramps": 0,
    },
}

TREES = ("CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple")
MOUNTAINS = ("CV3_IceCreamMountain_L", "CV3_IceCreamMountain_M")
COOKIES = ("CV3_CookieS", "CV3_CookieM", "CV3_CookieL")
CAKE = ("CV3_CakeBase", "CV3_CakeRamp", "CV3_CakeTop")


def colors(name):
    """Builder colour table: label -> (palette name, hex)."""
    by_hex = {hex_value: key for key, hex_value in PALETTE.items()}
    return {label: (f"CV3_{by_hex[hex_value]}", hex_value) for label, (hex_value, _) in SPECS[name]["parts"].items()}
