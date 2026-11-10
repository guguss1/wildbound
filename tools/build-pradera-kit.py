#!/usr/bin/env python3
"""Emit the parts-only Luau builder for the Pradera Arcoiris sector from its layout plan.

The plan JSON (tools/plan_pradera_layout.py) stays the single source of truth. This tool renders
it into `tools/build-wildbound-pradera-map.luau`: a self-contained ModuleScript that builds the
whole east biome from primitive Parts (no MeshParts, no uploads, no toolbox ids), in the style of
`tools/build-wildbound-p0-map.luau`. Nothing here touches Studio; the parent decides when and
where the module is pasted and run. Python standard library only.

    python -I -B tools/build-pradera-kit.py            # writes the module and the kit report
    python -I -B tools/build-pradera-kit.py --check    # exit 1 when the written module is stale
    python -I -B tools/build-pradera-kit.py --stdout   # prints the module instead of writing it

Everything the module builds is anchored and never touched. Only the floor, hills, path, pond and
mushroom stems collide; only stems, hills and the invisible `Roof` boxes answer queries (the roof
boxes are what a sky ray from a player's head hits, bible section 5.2 tag `roof`). Every value is
a hypothesis; the module was never run in Studio by this tool.
"""

import argparse
import json
import sys
import zlib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
PLAN = REPO / "assets" / "maps" / "pradera-layout" / "pradera-layout-v1.json"
MODULE = TOOLS / "build-wildbound-pradera-map.luau"
REPORT = REPO / "assets" / "maps" / "pradera-layout" / "pradera-kit-report.json"

ROW_FIELDS = ("id", "name", "x", "y", "z", "rotation_y_deg", "scale", "zone")
DATA_KEYS = ("world", "terrain", "zones", "beast", "nests", "sun_circles", "route")
PROP_NAMES = ("PA_GiantMushroom", "PA_PuffTree", "PA_MushroomRing", "PA_PuffFlower", "PA_SunflowerPost",
              "PA_HillBoulder", "PA_RainbowGate", "PA_Pinwheel", "PA_SetaTrueno")

# One colour per role, hex like the kit tables (docs/design/wildbound-biome-pradera.md section 2).
PALETTE = {
    "grass": "A8E6B0", "lavender": "D9C8F0", "path": "F5E6C8", "stem": "FFF4E0",
    "capCoral": "F28B9B", "capSky": "8FD3F4", "capButter": "F9E27A", "spot": "FFFFFF",
    "pond": "B9B3CF", "wood": "C98F5A", "neonSun": "FFD23F", "cloudGrey": "B4A8D2", "cloudBelly": "8C7FB0",
    "shadow": "6B5E94", "face": "5A4634", "ink": "3A2E22", "bed": "C98F5A", "straw": "F5E6C8", "marker": "66D2CA",
}

# Exact parts the module emits per prop instance, nest, circle, hill, the beast and the fixed pieces.
PARTS = {"PA_GiantMushroom": 8, "PA_PuffTree": 5, "PA_MushroomRing": 12, "PA_PuffFlower": 4, "PA_SunflowerPost": 4,
         "PA_HillBoulder": 1, "PA_RainbowGate": 23, "PA_Pinwheel": 6, "PA_SetaTrueno": 17}
NEST_PARTS, ADULT_PARTS, SUN_PARTS, HILL_PARTS, BEAST_PARTS = 4, 5, 2, 2, 18
SIGNS = (
    # (key, text, x, z, yaw degrees, width) in the sector frame; the server may override by SignKey.
    # A board's text is on its local -Z face; with yaw r that face points to (-sin r, -cos r) in (x, z):
    # 90 faces west (the hub), 0 faces north, 180 faces south.
    ("praderaGate", "Pradera Arcoíris", -178.0, -12.0, 90.0, 6.0),
    ("praderaRules", "Nube gris: bajo una seta\n¡Anillo amarillo: sal del círculo!\nGirasoles: a salvo", -172.0, 12.0, 90.0, 7.5),
    ("praderaPlaza", "Plaza del Molino", -40.0, 28.0, 0.0, 5.0),
    ("praderaPond", "Charca de la Nube Gruñona", 118.0, -16.0, 180.0, 6.5),
)
SIGN_PARTS = 2
FIXED_PARTS = 1 + 1 + 5  # floor, pond, markers (gate, plaza, beast home, event nest, seta top)


def hex_to_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def part_count(layout):
    counts = {}
    for inst in layout["instances"]:
        counts[inst["name"]] = counts.get(inst["name"], 0) + 1
    props = sum(PARTS[name] * n for name, n in counts.items())
    nests = sum(NEST_PARTS + ADULT_PARTS * nest["adults"] for nest in layout["nests"])
    circles = SUN_PARTS * len(layout["sun_circles"])
    hills = HILL_PARTS * len(layout["terrain"]["hills"])
    path = len(layout["terrain"]["path"]["nodes"]) - 1
    signs = SIGN_PARTS * len(SIGNS)
    total = props + nests + circles + hills + path + signs + BEAST_PARTS + FIXED_PARTS
    return {"props": props, "nests": nests, "sun_circles": circles, "hills": hills, "path": path, "signs": signs,
            "beast": BEAST_PARTS, "fixed": FIXED_PARTS, "total": total, "by_prop": counts}


def validate(layout):
    for key in ("name", "seed", "instances", "totals") + DATA_KEYS:
        if key not in layout:
            raise ValueError(f"layout lacks {key}")
    ids = set()
    for inst in layout["instances"]:
        if inst["name"] not in PROP_NAMES:
            raise ValueError(f"unknown prop {inst['name']}")
        if inst["id"] in ids:
            raise ValueError(f"duplicate id {inst['id']}")
        ids.add(inst["id"])
        for field in ROW_FIELDS:
            if field not in inst:
                raise ValueError(f"{inst.get('id')} lacks {field}")
        if "|" in inst["id"] or "|" in inst["name"] or "|" in inst["zone"]:
            raise ValueError("a row field holds the separator")
    if len(layout["nests"]) != 5:
        raise ValueError("the plan needs five nests")


def adler32(text):
    return zlib.adler32(text.encode("utf-8")) & 0xFFFFFFFF


def rows_text(layout):
    lines = []
    for inst in layout["instances"]:
        variant = inst.get("cap") or inst.get("puff") or inst.get("sun_circle") or "-"
        lines.append("|".join([str(inst[f]) for f in ROW_FIELDS] + [variant]))
    return "\n".join(lines)


def data_text(layout):
    return json.dumps({key: layout[key] for key in DATA_KEYS}, separators=(",", ":"), sort_keys=True,
                      ensure_ascii=False)


def palette_text():
    return "\n".join("    %s = Color3.fromRGB(%d, %d, %d)," % ((name,) + hex_to_rgb(value))
                     for name, value in PALETTE.items())


def signs_text():
    out = []
    for key, text, x, z, yaw, width in SIGNS:
        safe = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
        out.append("    { key = '%s', text = '%s', x = %s, z = %s, yaw = %s, width = %s }," % (key, safe, x, z, yaw, width))
    return "\n".join(out)


TEMPLATE = r"""-- GENERATED by tools/build-pradera-kit.py from @@PLAN@@ (seed @@SEED@@, data Adler-32 @@ADLER@@).
-- Do not edit by hand: change the planner or the design, regenerate, and compare the Adler-32 after pasting.
-- Pradera Arcoíris (docs/design/wildbound-biome-pradera.md): the bright east biome for kids, as a parts-only
-- primitive blockout. No MeshParts, no uploads, no toolbox ids. Everything is anchored and never touched; the
-- floor, hills, path, pond and mushroom stems collide; stems, hills and the invisible Roof boxes answer queries
-- (a sky ray from a player's head that hits a Roof reads as "covered" for La Nube Gruñona). Player-facing words
-- are neutral Spanish and live in SIGNS; code and comments are English. About @@PARTS@@ parts in total.
-- Builds detached and attaches the root once complete; refuses a second WildboundPradera under the same parent.
local Builder = {}

local HttpService = game:GetService('HttpService')
local CollectionService = game:GetService('CollectionService')

local FLOOR_TOP = 0.5
local MAP_SIZE = 400
local YIELD_EVERY = 150

local palette = {
@@PALETTE@@
}

local CAPS = { Coral = palette.capCoral, Sky = palette.capSky, Butter = palette.capButter }
local CAP_ORDER = { 'Coral', 'Sky', 'Butter' }

-- Spanish sign copy. The server may replace a label through its SignKey attribute, as the camp signs do.
local SIGNS = {
@@SIGNS@@
}

local ROWS = [==[
@@ROWS@@
]==]

local DATA = [==[@@DATA@@]==]

local function parseRows()
    local list = {}
    for line in string.gmatch(ROWS, '[^\n]+') do
        local id, name, x, y, z, rotation, scale, zone, variant =
            string.match(line, '^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$')
        assert(id, 'malformed layout row: ' .. line)
        table.insert(list, {
            id = id, name = name, x = tonumber(x), y = tonumber(y), z = tonumber(z),
            rotation_y_deg = tonumber(rotation), scale = tonumber(scale), zone = zone,
            variant = variant ~= '-' and variant or nil,
        })
    end
    return list
end

local instances = parseRows()
local data = HttpService:JSONDecode(DATA)
Builder.INSTANCES = instances
Builder.DATA = data
Builder.SIGNS = SIGNS
Builder.EXPECTED_PARTS = @@PARTS@@

local created = 0

local function folder(parent, name)
    local item = Instance.new('Folder')
    item.Name = name
    item.Parent = parent
    return item
end

-- opts: collide, query, shape, transparency, material. Default: anchored, no collision, no query, no touch.
local function part(parent, name, size, frame, color, opts)
    opts = opts or {}
    local item = Instance.new('Part')
    item.Name = name
    item.Size = size
    item.CFrame = frame
    item.Color = color
    item.Material = opts.material or Enum.Material.SmoothPlastic
    item.Anchored = true
    item.CanCollide = opts.collide == true
    item.CanQuery = opts.query == true
    item.CanTouch = false
    item.CastShadow = opts.shadow ~= false
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    if opts.shape then item.Shape = opts.shape end
    if opts.transparency then item.Transparency = opts.transparency end
    item.Parent = parent
    created += 1
    if created % YIELD_EVERY == 0 then task.wait() end
    return item
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X; this stands it up

local function cylinder(parent, name, diameter, height, frame, color, opts)
    return part(parent, name, Vector3.new(height, diameter, diameter), frame * UPRIGHT, color, opts)
end

local function ball(parent, name, size, frame, color, opts)
    opts = opts or {}
    opts.shape = Enum.PartType.Ball
    return part(parent, name, size, frame, color, opts)
end

local function marker(parent, name, frame)
    local item = part(parent, name, Vector3.new(1, 1, 1), frame, palette.marker)
    item.Transparency = 1
    item.CastShadow = false
    return item
end

-- Roof: an invisible box only sky rays see (CanQuery), never a collider. Tagged for the roof sense.
local function roof(parent, size, frame)
    local item = part(parent, 'Roof', size, frame, palette.spot, { query = true, transparency = 1, shadow = false })
    CollectionService:AddTag(item, 'WildboundRoof')
    return item
end

local function pose(inst)
    return CFrame.new(inst.x, FLOOR_TOP + inst.y, inst.z) * CFrame.Angles(0, math.rad(inst.rotation_y_deg), 0)
end

-- ---------------------------------------------------------------------------------------------------------
-- Props. Each builder takes the instance (sector frame) and returns its Model. Sizes are studs at scale 1.
-- ---------------------------------------------------------------------------------------------------------
local props = {}

function props.PA_GiantMushroom(parent, inst)
    local s, base = inst.scale, pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    cylinder(model, 'Stem', 5 * s, 12 * s, base * CFrame.new(0, 6 * s, 0), palette.stem, { collide = true, query = true })
    ball(model, 'Cap', Vector3.new(18 * s, 9 * s, 18 * s), base * CFrame.new(0, 13.5 * s, 0), CAPS[inst.variant or 'Coral'])
    for k = 1, 5 do
        local a = math.rad(72 * k + inst.rotation_y_deg)
        ball(model, 'Spot', Vector3.new(2.6 * s, 1 * s, 2.6 * s),
            base * CFrame.new(math.cos(a) * 5 * s, 17.2 * s, math.sin(a) * 5 * s), palette.spot)
    end
    roof(model, Vector3.new(18 * s, 1, 18 * s), base * CFrame.new(0, 12.5 * s, 0))
    model.Parent = parent
    return model
end

function props.PA_PuffTree(parent, inst)
    local s, base = inst.scale, pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    local color = CAPS[inst.variant or 'Sky']
    cylinder(model, 'Trunk', 2.4 * s, 9 * s, base * CFrame.new(0, 4.5 * s, 0), palette.wood, { collide = true, query = true })
    ball(model, 'Puff', Vector3.new(7 * s, 7 * s, 7 * s), base * CFrame.new(0, 11.5 * s, 0), color)
    ball(model, 'Puff', Vector3.new(6 * s, 6 * s, 6 * s), base * CFrame.new(2.6 * s, 9.5 * s, 1.2 * s), color)
    ball(model, 'Puff', Vector3.new(5.5 * s, 5.5 * s, 5.5 * s), base * CFrame.new(-2.4 * s, 9.8 * s, -1.6 * s), color)
    roof(model, Vector3.new(10 * s, 1, 10 * s), base * CFrame.new(0, 12.5 * s, 0))
    model.Parent = parent
    return model
end

function props.PA_MushroomRing(parent, inst)
    local s, base = inst.scale, pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    for k = 1, 6 do
        local a = math.rad(60 * k)
        local at = base * CFrame.new(math.cos(a) * 3.5 * s, 0, math.sin(a) * 3.5 * s)
        cylinder(model, 'Stem', 0.7 * s, 0.9 * s, at * CFrame.new(0, 0.45 * s, 0), palette.stem)
        ball(model, 'Cap', Vector3.new(1.6 * s, 0.9 * s, 1.6 * s), at * CFrame.new(0, 1.1 * s, 0), CAPS[CAP_ORDER[k % 3 + 1]])
    end
    model.Parent = parent
    return model
end

function props.PA_PuffFlower(parent, inst)
    local s, base = inst.scale, pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    cylinder(model, 'Stems', 0.7 * s, 2.2 * s, base * CFrame.new(0, 1.1 * s, 0), palette.grass)
    ball(model, 'Puff', Vector3.new(1.6 * s, 1.6 * s, 1.6 * s), base * CFrame.new(0, 2.6 * s, 0), palette.spot)
    ball(model, 'Puff', Vector3.new(1.3 * s, 1.3 * s, 1.3 * s), base * CFrame.new(0.9 * s, 2.1 * s, 0.4 * s), palette.spot)
    ball(model, 'Puff', Vector3.new(1.2 * s, 1.2 * s, 1.2 * s), base * CFrame.new(-0.8 * s, 2.0 * s, -0.5 * s), palette.spot)
    model:SetAttribute('Gather', 'Pelusa')
    model.Parent = parent
    return model
end

function props.PA_SunflowerPost(parent, inst)
    local base = pose(inst) -- local -Z faces the circle centre (planner yaw)
    local model = Instance.new('Model')
    model.Name = inst.id
    part(model, 'Post', Vector3.new(0.4, 6, 0.4), base * CFrame.new(0, 3, 0), palette.wood, { material = Enum.Material.Wood })
    -- Discs: a Cylinder's axis is X, so the quarter turn about Y points it along local Z, toward the circle.
    local facing = CFrame.Angles(0, math.rad(90), 0)
    part(model, 'Petals', Vector3.new(0.3, 3, 3), base * CFrame.new(0, 6.4, 0) * facing, palette.capButter, { shape = Enum.PartType.Cylinder })
    part(model, 'Face', Vector3.new(0.35, 1.4, 1.4), base * CFrame.new(0, 6.4, -0.05) * facing, palette.face, { shape = Enum.PartType.Cylinder })
    ball(model, 'SunGlow', Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 0.45, 0), palette.neonSun, { material = Enum.Material.Neon })
    model:SetAttribute('SunCircle', inst.variant)
    model.Parent = parent
    return model
end

function props.PA_HillBoulder(parent, inst)
    local s, base = inst.scale, pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    ball(model, 'Rock', Vector3.new(6 * s, 5 * s, 4 * s), base * CFrame.new(0, 2 * s, 0), palette.lavender,
        { collide = true, material = Enum.Material.SmoothPlastic })
    model.Parent = parent
    return model
end

function props.PA_RainbowGate(parent, inst)
    local base = pose(inst) -- the passage runs along local +Z
    local model = Instance.new('Model')
    model.Name = inst.id
    for _, side in ipairs({ -9.5, 9.5 }) do
        part(model, 'Post', Vector3.new(1.6, 7, 1.6), base * CFrame.new(side, 3.5, 0), palette.wood,
            { collide = true, material = Enum.Material.Wood })
    end
    local bands = { { 9.0, palette.capCoral }, { 10.2, palette.capSky }, { 11.4, palette.capButter } }
    for _, band in ipairs(bands) do
        local radius, color = band[1], band[2]
        for k = 0, 6 do
            local a = math.pi * (k + 0.5) / 7
            local x, y = math.cos(a) * radius, 7 + math.sin(a) * radius * 0.6
            local tangent = math.atan2(math.cos(a) * radius * 0.6, -math.sin(a) * radius)
            local chord = 2 * radius * math.sin(math.pi / 14) + 0.5
            part(model, 'Band', Vector3.new(chord, 1.1, 1.0), base * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, tangent), color)
        end
    end
    model.Parent = parent
    return model
end

function props.PA_Pinwheel(parent, inst)
    local base = pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    part(model, 'Stick', Vector3.new(0.3, 4, 0.3), base * CFrame.new(0, 2, 0), palette.wood)
    ball(model, 'Hub', Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, 4, -0.2), palette.spot)
    for k = 1, 4 do
        local a = math.rad(90 * k)
        part(model, 'Blade', Vector3.new(1.4, 1.0, 0.1),
            base * CFrame.new(0, 4, -0.3) * CFrame.Angles(0, 0, a) * CFrame.new(0.9, 0, 0), CAPS[CAP_ORDER[k % 3 + 1]])
    end
    model:SetAttribute('Distraction', 'Molinillo')
    model.Parent = parent
    return model
end

function props.PA_SetaTrueno(parent, inst)
    local base = pose(inst)
    local model = Instance.new('Model')
    model.Name = inst.id
    cylinder(model, 'Stem', 7, 20, base * CFrame.new(0, 10, 0), palette.stem, { collide = true, query = true })
    ball(model, 'Cap', Vector3.new(26, 12, 26), base * CFrame.new(0, 20, 0), palette.capCoral, { collide = true })
    for k = 1, 4 do
        local a = math.rad(90 * k + 20)
        ball(model, 'Spot', Vector3.new(3.6, 1.4, 3.6), base * CFrame.new(math.cos(a) * 7, 25, math.sin(a) * 7), palette.spot)
    end
    for k = 0, 7 do -- the spiral of small caps a child climbs, in open sky
        local a = math.rad(55 * k)
        part(model, 'Step', Vector3.new(3, 0.6, 2.2), base * CFrame.new(math.cos(a) * 4.6, 2.5 + 2.2 * k, math.sin(a) * 4.6)
            * CFrame.Angles(0, -a, 0), CAPS[CAP_ORDER[k % 3 + 1]], { collide = true })
    end
    roof(model, Vector3.new(26, 1, 26), base * CFrame.new(0, 19, 0))
    cylinder(model, 'EventPedestal', 3, 0.4, base * CFrame.new(0, 26.2, 0), palette.neonSun, { material = Enum.Material.Neon })
    marker(model, 'EventEggMarker', base * CFrame.new(0, 27, 0))
    model:SetAttribute('Landmark', 'SetaTrueno')
    model.Parent = parent
    return model
end

-- ---------------------------------------------------------------------------------------------------------
-- Terrain, nests, sun circles, the beast placeholder and signs.
-- ---------------------------------------------------------------------------------------------------------
local function buildTerrain(root)
    local terrain = data.terrain
    local ground = folder(root, 'Ground')
    local floor = part(ground, 'Floor', Vector3.new(MAP_SIZE, 1, MAP_SIZE), CFrame.new(0, 0, 0), palette.grass,
        { collide = true, query = true, material = Enum.Material.Grass })
    for _, hill in ipairs(terrain.hills) do
        local r, cap = hill.sphere_radius, hill.cap_height
        ball(ground, 'HillShoulder_' .. hill.id, Vector3.new(2 * r, 2 * r, 2 * r), CFrame.new(hill.x, FLOOR_TOP + cap - r, hill.z),
            palette.lavender, { collide = true, query = true, material = Enum.Material.Grass })
        local r2 = r * 0.8
        ball(ground, 'HillTop_' .. hill.id, Vector3.new(2 * r2, 2 * r2, 2 * r2), CFrame.new(hill.x, FLOOR_TOP + cap - r2 + 0.05, hill.z),
            palette.grass, { collide = true, query = true, material = Enum.Material.Grass })
    end
    local pond = terrain.pond
    local water = cylinder(ground, 'Pond', 2 * pond.radius, 0.3, CFrame.new(pond.x, FLOOR_TOP + 0.08, pond.z), palette.pond,
        { collide = true, transparency = 0.15 })
    water.CastShadow = false
    local paths = folder(root, 'Paths')
    local nodes = terrain.path.nodes
    for index = 1, #nodes - 1 do
        local a = Vector3.new(nodes[index][1], FLOOR_TOP + 0.05, nodes[index][2])
        local b = Vector3.new(nodes[index + 1][1], FLOOR_TOP + 0.05, nodes[index + 1][2])
        local middle = (a + b) / 2
        part(paths, 'Path' .. index, Vector3.new(terrain.path.width, 0.1, (b - a).Magnitude + terrain.path.width),
            CFrame.lookAt(middle, b), palette.path, { collide = true, material = Enum.Material.Sand })
    end
    return floor
end

local function hexColor(hex)
    return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

-- A sleeping parent: round body, an accent on its back, closed eyes drawn as two dark lines, one soft glow.
local function buildAdult(parent, nest, point, index)
    local colors = nest.colors
    local model = Instance.new('Model')
    model.Name = 'Adult' .. index
    local at = CFrame.lookAt(Vector3.new(point.x, FLOOR_TOP + nest.y + 1, point.z),
        Vector3.new(point.x + point.faceX, FLOOR_TOP + nest.y + 1, point.z + point.faceZ))
    local body = ball(model, 'Body', Vector3.new(3, 2, 2.4), at, hexColor(colors.body))
    ball(model, 'Accent', Vector3.new(1.4, 1.0, 1.4), at * CFrame.new(0, 0.9, 0.3), hexColor(colors.accent))
    part(model, 'EyeL', Vector3.new(0.6, 0.12, 0.2), at * CFrame.new(-0.6, 0.35, -1.15), hexColor(colors.eye))
    part(model, 'EyeR', Vector3.new(0.6, 0.12, 0.2), at * CFrame.new(0.6, 0.35, -1.15), hexColor(colors.eye))
    ball(model, 'Glow', Vector3.new(0.5, 0.5, 0.5), at * CFrame.new(0, 1.2, -0.6), hexColor(colors.glow), { material = Enum.Material.Neon })
    model.PrimaryPart = body
    model:SetAttribute('Asleep', true)
    model.Parent = parent
    return model
end

local function buildNests(root)
    local nests = folder(root, 'Nests')
    for _, nest in ipairs(data.nests) do
        local model = Instance.new('Model')
        model.Name = 'Nest_' .. nest.id
        model:SetAttribute('NestId', nest.id)
        model:SetAttribute('Species', nest.species)
        model:SetAttribute('DisplayName', nest.displayName)
        model:SetAttribute('Rarity', nest.rarity)
        model:SetAttribute('EventOnly', nest.eventOnly == true)
        local base = CFrame.new(nest.x, FLOOR_TOP + nest.y, nest.z)
        cylinder(model, 'NestBed', 6.5, 0.8, base * CFrame.new(0, 0.4, 0), palette.bed, { material = Enum.Material.Wood })
        cylinder(model, 'NestStraw', 5.2, 0.3, base * CFrame.new(0, 0.9, 0), palette.straw, { material = Enum.Material.Fabric })
        local glow = cylinder(model, 'NestGlow', 7.2, 0.12, base * CFrame.new(0, 0.14, 0), hexColor(nest.colors.glow),
            { material = Enum.Material.Neon, transparency = 0.35 })
        glow.CastShadow = false
        local nestMarker = marker(model, 'NestMarker', base * CFrame.new(0, 0.5, 0))
        for index, point in ipairs(nest.adultPoints) do
            buildAdult(model, nest, point, index)
        end
        model.PrimaryPart = nestMarker
        CollectionService:AddTag(model, 'WildboundPraderaNest')
        model.Parent = nests
    end
    return nests
end

local function buildSunCircles(root)
    local circles = folder(root, 'SunCircles')
    for _, circle in ipairs(data.sun_circles) do
        local model = Instance.new('Model')
        model.Name = 'SunCircle_' .. circle.id
        model:SetAttribute('CircleId', circle.id)
        model:SetAttribute('Radius', circle.radius)
        model:SetAttribute('Permanent', circle.permanent == true)
        if circle.label then model:SetAttribute('Label', circle.label) end
        local base = CFrame.new(circle.x, FLOOR_TOP, circle.z)
        local ring = cylinder(model, 'SunRing', 2 * circle.radius, 0.1, base * CFrame.new(0, 0.12, 0), palette.neonSun,
            { material = Enum.Material.Neon, transparency = 0.55 })
        ring.CastShadow = false
        model.PrimaryPart = marker(model, 'CircleMarker', base * CFrame.new(0, 0.5, 0))
        CollectionService:AddTag(model, 'WildboundSunCircle')
        model.Parent = circles
    end
    return circles
end

-- La Nube Gruñona as a placeholder: five grey puffs, a darker belly, closed eyes, frowning brows and her shadow.
local function buildBeast(root)
    local beast = data.beast
    local model = Instance.new('Model')
    model.Name = 'NubeGrunona'
    model:SetAttribute('DisplayName', beast.displayName)
    model:SetAttribute('Leash', beast.leash)
    model:SetAttribute('StrikeZoneRadius', beast.strike_zone_radius)
    local hover = CFrame.new(beast.home[1], FLOOR_TOP + beast.hover_height + 4, beast.home[2])
    local puffs = { { 10, 7, 9, 0, 0, 0 }, { 7, 6, 6, -4.5, -0.5, 1 }, { 7, 6, 6, 4.5, -0.5, -1 },
        { 6, 5, 5, 0, 1.5, -3 }, { 6, 5, 5, 1, 1.5, 3.5 } }
    local bodyPart
    for index, p in ipairs(puffs) do
        local puff = ball(model, 'Puff', Vector3.new(p[1], p[2], p[3]), hover * CFrame.new(p[4], p[5], p[6]), palette.cloudGrey)
        if index == 1 then bodyPart = puff end
    end
    ball(model, 'Belly', Vector3.new(11, 4, 9), hover * CFrame.new(0, -2.5, 0), palette.cloudBelly)
    part(model, 'EyeL', Vector3.new(1.6, 0.25, 0.3), hover * CFrame.new(-2, 1.2, -4.6), palette.ink)
    part(model, 'EyeR', Vector3.new(1.6, 0.25, 0.3), hover * CFrame.new(2, 1.2, -4.6), palette.ink)
    part(model, 'BrowL', Vector3.new(2, 0.4, 0.3), hover * CFrame.new(-2, 2.2, -4.7) * CFrame.Angles(0, 0, math.rad(-20)), palette.ink)
    part(model, 'BrowR', Vector3.new(2, 0.4, 0.3), hover * CFrame.new(2, 2.2, -4.7) * CFrame.Angles(0, 0, math.rad(20)), palette.ink)
    local shadow = cylinder(model, 'Shadow', 40, 0.08, CFrame.new(beast.home[1], FLOOR_TOP + 0.2, beast.home[2]), palette.shadow,
        { transparency = 0.6 })
    shadow.CastShadow = false
    model.PrimaryPart = bodyPart
    local waypoints = folder(model, 'Waypoints')
    for index, wp in ipairs(beast.waypoints) do
        marker(waypoints, 'Waypoint' .. index, CFrame.new(wp[1], FLOOR_TOP + beast.hover_height + 4, wp[2]))
    end
    CollectionService:AddTag(model, 'WildboundPraderaBeast')
    model.Parent = root
    return model
end

local function buildSign(parent, spec)
    local base = CFrame.new(spec.x, FLOOR_TOP, spec.z) * CFrame.Angles(0, math.rad(spec.yaw), 0)
    part(parent, 'SignPost_' .. spec.key, Vector3.new(0.4, 4.2, 0.4), base * CFrame.new(0, 2.1, 0), palette.wood,
        { material = Enum.Material.Wood })
    local board = part(parent, 'Sign_' .. spec.key, Vector3.new(spec.width, 1.6, 0.25), base * CFrame.new(0, 4.2, 0), palette.wood,
        { material = Enum.Material.WoodPlanks })
    board:SetAttribute('SignKey', spec.key)
    local gui = Instance.new('SurfaceGui')
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.LightInfluence = 0
    gui.Parent = board
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = palette.ink
    label.Text = spec.text
    label.Parent = gui
    return board
end

local function buildSigns(root)
    local signs = folder(root, 'Signs')
    for _, spec in ipairs(SIGNS) do buildSign(signs, spec) end
    return signs
end

local function buildMarkers(root)
    local markers = folder(root, 'Markers')
    local gate = data.zones.sol.gate
    local plaza = data.zones.sol.plaza
    marker(markers, 'GateMarker', CFrame.new(gate[1], FLOOR_TOP + 1, gate[2]))
    marker(markers, 'PlazaMarker', CFrame.new(plaza[1], FLOOR_TOP + 1, plaza[2]))
    marker(markers, 'BeastHomeMarker', CFrame.new(data.beast.home[1], FLOOR_TOP + 1, data.beast.home[2]))
    local event = data.nests[#data.nests]
    marker(markers, 'EventNestMarker', CFrame.new(event.x, FLOOR_TOP + event.y + 1, event.z))
    marker(markers, 'SetaTruenoTopMarker', CFrame.new(data.beast.seta_trueno[1], FLOOR_TOP + 27, data.beast.seta_trueno[2]))
    return markers
end

local function buildProps(root)
    local groups = {}
    for _, inst in ipairs(instances) do
        local build = props[inst.name]
        assert(build, 'unknown prop ' .. tostring(inst.name))
        local group = groups[inst.name]
        if not group then
            group = folder(root, inst.name)
            groups[inst.name] = group
        end
        local model = build(group, inst)
        model:SetAttribute('Zone', inst.zone)
        model:SetAttribute('Scale', inst.scale)
    end
end

-- Builds the sector under `parent`, pivoted so the sector centre lands at `origin` (default: the hub frame
-- offset from the plan, world (+300, 0, 0)). Returns the WildboundPradera Model.
function Builder.build(parent, origin)
    assert(typeof(parent) == 'Instance', 'parent must be an Instance')
    assert(not parent:FindFirstChild('WildboundPradera'), 'WildboundPradera already exists')
    assert(origin == nil or typeof(origin) == 'CFrame', 'origin must be a CFrame')
    origin = origin or CFrame.new(data.world.offset[1], 0, data.world.offset[2])
    created = 0
    local root = Instance.new('Model')
    root.Name = 'WildboundPradera'
    root:SetAttribute('Biome', 'PraderaArcoiris')
    root:SetAttribute('Seed', @@SEED@@)
    local ok, failure = pcall(function()
        local floor = buildTerrain(root)
        root.PrimaryPart = floor
        buildProps(root)
        buildNests(root)
        buildSunCircles(root)
        buildBeast(root)
        buildSigns(root)
        buildMarkers(root)
    end)
    if not ok then
        root:Destroy()
        error(failure, 0)
    end
    root:PivotTo(origin)
    if parent:FindFirstChild('WildboundPradera') then
        root:Destroy()
        error('WildboundPradera appeared during construction')
    end
    root:SetAttribute('PartCount', created)
    root.Parent = parent
    return root
end

return Builder
"""


def render(layout):
    validate(layout)
    rows, data = rows_text(layout), data_text(layout)
    for text in (rows, data):
        if "]==]" in text:
            raise ValueError("plan text would close the Luau long string")
    counts = part_count(layout)
    out = TEMPLATE
    for token, value in (("@@PLAN@@", PLAN.name), ("@@SEED@@", str(layout["seed"])),
                         ("@@ADLER@@", str(adler32(rows + data))), ("@@PARTS@@", str(counts["total"])),
                         ("@@PALETTE@@", palette_text()), ("@@SIGNS@@", signs_text()), ("@@ROWS@@", rows),
                         ("@@DATA@@", data)):
        out = out.replace(token, value)
    return out


def report(layout, module_text):
    counts = part_count(layout)
    return {
        "name": "pradera-kit-report",
        "source": "tools/build-pradera-kit.py",
        "plan": layout["name"],
        "seed": layout["seed"],
        "status": "unvalidated: the module was never run in Studio by this tool",
        "module": MODULE.name,
        "module_adler32": adler32(module_text),
        "parts": counts,
        "parts_per_prop": PARTS,
        "palette": PALETTE,
        "signs": [{"key": key, "text": text} for key, text, *_ in SIGNS],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--check", action="store_true", help="exit 1 when the written module differs from the plan")
    parser.add_argument("--stdout", action="store_true", help="print the module instead of writing it")
    args = parser.parse_args(argv)
    layout = json.loads(args.plan.read_text(encoding="utf-8"))
    module = render(layout)
    if args.stdout:
        sys.stdout.buffer.write(module.encode("utf-8"))
        return 0
    if args.check:
        current = MODULE.read_text(encoding="utf-8") if MODULE.exists() else ""
        if current != module:
            print("stale:", MODULE)
            return 1
        print("fresh:", MODULE, "adler32", adler32(module))
        return 0
    MODULE.write_bytes(module.encode("utf-8"))
    REPORT.write_bytes((json.dumps(report(layout, module), indent=1, ensure_ascii=False) + "\n").encode("utf-8"))
    counts = part_count(layout)
    print("wrote", MODULE, "adler32", adler32(module))
    print("wrote", REPORT)
    print("parts: %d (props %d, nests %d, sun circles %d, hills %d, path %d, signs %d, beast %d, fixed %d)"
          % (counts["total"], counts["props"], counts["nests"], counts["sun_circles"], counts["hills"], counts["path"],
             counts["signs"], counts["beast"], counts["fixed"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
