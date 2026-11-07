"""Tiny shared drawing layer for the biome layout plans: one scene, written as SVG and, when
Pillow is importable, as PNG. Standard library for the SVG; Pillow is optional.

Coordinates are pixels. World is the transform from stud coordinates (origin at the map
centre, x east, z south) to pixels.
"""

import math
from xml.sax.saxutils import escape


class World:
    def __init__(self, scale, left, top, half):
        self.s, self.left, self.top, self.half = scale, left, top, half

    def px(self, x):
        return self.left + (x + self.half) * self.s

    def py(self, z):
        return self.top + (z + self.half) * self.s

    def pt(self, p):
        return (self.px(p[0]), self.py(p[1]))


def _rgba(color, opacity=1.0):
    color = color.lstrip("#")
    return (int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16), round(255 * opacity))


class Scene:
    def __init__(self, width, height, background="#f4f1e8"):
        self.w, self.h, self.items = width, height, []
        self.rect(0, 0, width, height, fill=background)

    def poly(self, pts, fill=None, stroke=None, sw=1.0, fo=1.0, so=1.0, dash=None, closed=True):
        self.items.append(("poly", [tuple(p) for p in pts], dict(fill=fill, stroke=stroke, sw=sw, fo=fo, so=so,
                                                                 dash=dash), closed))

    def rect(self, x, y, w, h, **style):
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], **style)

    def circle(self, cx, cy, r, **style):
        self.poly([(cx + r * math.cos(math.tau * k / 48), cy + r * math.sin(math.tau * k / 48))
                   for k in range(48)], **style)

    def line(self, pts, stroke="#000000", sw=1.0, so=1.0, dash=None):
        self.poly(pts, stroke=stroke, sw=sw, so=so, dash=dash, closed=False)

    def text(self, x, y, s, size=13, fill="#1d2530", anchor="start", bold=False):
        self.items.append(("text", (x, y, s), dict(size=size, fill=fill, anchor=anchor, bold=bold), False))

    def to_svg(self):
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
               f'viewBox="0 0 {self.w} {self.h}" font-family="Arial, Helvetica, sans-serif">']
        for kind, data, st, closed in self.items:
            if kind == "text":
                x, y, s = data
                weight = ' font-weight="bold"' if st["bold"] else ""
                out.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{st["size"]}" fill="{st["fill"]}" '
                           f'text-anchor="{st["anchor"]}"{weight}>{escape(s)}</text>')
                continue
            points = " ".join(f"{x:.1f},{y:.1f}" for x, y in data)
            fill = f'fill="{st["fill"]}" fill-opacity="{st["fo"]}"' if st["fill"] and closed else 'fill="none"'
            stroke = (f'stroke="{st["stroke"]}" stroke-width="{st["sw"]}" stroke-opacity="{st["so"]}"'
                      + (f' stroke-dasharray="{st["dash"][0]},{st["dash"][1]}"' if st["dash"] else "")
                      + ' stroke-linejoin="round" stroke-linecap="round"') if st["stroke"] else 'stroke="none"'
            out.append(f'<{"polygon" if closed else "polyline"} points="{points}" {fill} {stroke}/>')
        out.append("</svg>")
        return "\n".join(out) + "\n"

    def to_png(self, path, supersample=2):
        from PIL import Image, ImageDraw, ImageFont
        ss = supersample
        image = Image.new("RGB", (self.w * ss, self.h * ss), "#ffffff")
        draw = ImageDraw.Draw(image, "RGBA")
        fonts = {}

        def font(size, bold):
            key = (size, bold)
            if key not in fonts:
                for name in (("arialbd.ttf", "DejaVuSans-Bold.ttf") if bold else ("arial.ttf", "DejaVuSans.ttf")):
                    try:
                        fonts[key] = ImageFont.truetype(name, round(size * ss))
                        break
                    except OSError:
                        continue
                else:
                    fonts[key] = ImageFont.load_default(round(size * ss))
            return fonts[key]

        for kind, data, st, closed in self.items:
            if kind == "text":
                x, y, s = data
                draw.text((x * ss, y * ss), s, font=font(st["size"], st["bold"]), fill=_rgba(st["fill"]),
                          anchor={"start": "ls", "middle": "ms", "end": "rs"}[st["anchor"]])
                continue
            scaled = [(x * ss, y * ss) for x, y in data]
            if st["fill"] and closed:
                draw.polygon(scaled, fill=_rgba(st["fill"], st["fo"]))
            if st["stroke"]:
                outline = scaled + [scaled[0]] if closed else scaled
                color, width = _rgba(st["stroke"], st["so"]), max(1, round(st["sw"] * ss))
                if st["dash"]:
                    on, off = st["dash"][0] * ss, st["dash"][1] * ss
                    for (x1, y1), (x2, y2) in zip(outline, outline[1:]):
                        length, pos = math.hypot(x2 - x1, y2 - y1), 0.0
                        while pos < length and length > 0:
                            end = min(pos + on, length)
                            draw.line([(x1 + (x2 - x1) * pos / length, y1 + (y2 - y1) * pos / length),
                                       (x1 + (x2 - x1) * end / length, y1 + (y2 - y1) * end / length)],
                                      fill=color, width=width)
                            pos += on + off
                else:
                    draw.line(outline, fill=color, width=width, joint="curve")
        image.resize((self.w, self.h), Image.Resampling.LANCZOS).save(path, optimize=True)
