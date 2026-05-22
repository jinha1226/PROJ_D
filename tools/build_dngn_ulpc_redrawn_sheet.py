#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


TILE = 32
DEFAULT_COLUMNS = 64


PALETTES = {
    "stone": [(72, 75, 76), (92, 96, 96), (120, 124, 122), (48, 50, 52), (158, 160, 154)],
    "dark": [(31, 32, 38), (47, 49, 58), (70, 72, 80), (21, 22, 27), (105, 106, 116)],
    "sand": [(126, 107, 72), (158, 137, 92), (191, 171, 118), (86, 72, 48), (218, 201, 150)],
    "dirt": [(83, 58, 38), (111, 78, 48), (145, 105, 66), (52, 38, 29), (181, 136, 82)],
    "grass": [(45, 92, 51), (65, 122, 62), (93, 151, 77), (26, 56, 36), (146, 179, 93)],
    "water": [(28, 72, 104), (38, 106, 145), (62, 145, 181), (17, 43, 68), (125, 190, 210)],
    "lava": [(91, 32, 24), (158, 56, 29), (222, 103, 43), (48, 23, 22), (255, 189, 72)],
    "ice": [(92, 135, 154), (134, 180, 192), (190, 224, 221), (50, 82, 106), (231, 247, 240)],
    "metal": [(71, 73, 78), (104, 107, 114), (151, 153, 156), (39, 40, 45), (211, 208, 190)],
    "wood": [(92, 55, 31), (130, 78, 39), (166, 108, 55), (54, 34, 25), (210, 156, 84)],
    "purple": [(64, 38, 88), (96, 57, 132), (139, 87, 169), (38, 27, 55), (202, 152, 219)],
    "red": [(83, 38, 38), (133, 57, 48), (178, 82, 58), (45, 26, 28), (225, 144, 91)],
    "gold": [(109, 82, 31), (161, 122, 40), (216, 171, 67), (66, 49, 28), (246, 224, 127)],
    "bone": [(116, 108, 88), (154, 146, 116), (198, 189, 150), (72, 67, 59), (229, 218, 181)],
}


def seed_for(path: Path) -> int:
    return int(hashlib.sha1(path.as_posix().encode("utf-8")).hexdigest()[:12], 16)


def palette_for(name: str, category: str) -> list[tuple[int, int, int]]:
    text = f"{category}/{name}".lower()
    if any(k in text for k in ("water", "sea", "blue", "pool")):
        return PALETTES["water"]
    if any(k in text for k in ("lava", "flame", "fire", "hell", "red")):
        return PALETTES["lava"]
    if any(k in text for k in ("ice", "frost", "snow", "crystal")):
        return PALETTES["ice"]
    if any(k in text for k in ("grass", "tree", "moss", "green", "bog", "swamp", "garden")):
        return PALETTES["grass"]
    if any(k in text for k in ("sand", "desert", "beige", "yellow")):
        return PALETTES["sand"]
    if any(k in text for k in ("dirt", "mud", "earth", "brown", "soil")):
        return PALETTES["dirt"]
    if any(k in text for k in ("wood", "door", "shop", "book", "crate")):
        return PALETTES["wood"]
    if any(k in text for k in ("metal", "iron", "steel", "grate", "gate")):
        return PALETTES["metal"]
    if any(k in text for k in ("crypt", "bone", "tomb", "skull", "statue")):
        return PALETTES["bone"]
    if any(k in text for k in ("purple", "abyss", "magic", "portal", "xom", "lugonu")):
        return PALETTES["purple"]
    if any(k in text for k in ("gold", "altar", "zin", "shining", "treasure")):
        return PALETTES["gold"]
    if any(k in text for k in ("dark", "black", "shadow")):
        return PALETTES["dark"]
    return PALETTES["stone"]


def rect(draw: ImageDraw.ImageDraw, xy, fill, outline=None) -> None:
    x0, y0, x1, y1 = [int(v) for v in xy]
    x0, x1 = sorted((max(0, min(TILE - 1, x0)), max(0, min(TILE - 1, x1))))
    y0, y1 = sorted((max(0, min(TILE - 1, y0)), max(0, min(TILE - 1, y1))))
    draw.rectangle((x0, y0, x1, y1), fill=fill, outline=outline)


def line(draw: ImageDraw.ImageDraw, xy, fill, width=1) -> None:
    draw.line([int(v) for v in xy], fill=fill, width=width)


def dot_noise(draw: ImageDraw.ImageDraw, rng: random.Random, colors, count: int) -> None:
    for _ in range(count):
        x = rng.randrange(TILE)
        y = rng.randrange(TILE)
        c = rng.choice(colors)
        draw.point((x, y), fill=c)


def draw_floor(path: Path, pal) -> Image.Image:
    rng = random.Random(seed_for(path))
    name = path.stem.lower()
    img = Image.new("RGBA", (TILE, TILE), pal[0] + (255,))
    d = ImageDraw.Draw(img)

    if any(k in name for k in ("brick", "tile", "labyrinth", "herring", "zig")):
        h = 8 if "large" in name else 6
        for y in range(0, TILE + h, h):
            offset = (y // h % 2) * 8
            line(d, (0, y, TILE, y), pal[3])
            for x in range(-offset, TILE, 16):
                line(d, (x, y, x, min(TILE, y + h)), pal[3])
                rect(d, (x + 1, y + 1, x + 14, min(TILE - 1, y + h - 1)), pal[rng.randrange(0, 3)])
    elif any(k in name for k in ("cobble", "stone", "rock", "pebble", "masonry")):
        for _ in range(18):
            x = rng.randrange(-4, TILE)
            y = rng.randrange(-4, TILE)
            w = rng.randrange(7, 15)
            h = rng.randrange(5, 11)
            rect(d, (x, y, x + w, y + h), rng.choice(pal[:3]), pal[3])
            d.point((x + 2, y + 1), fill=pal[4])
    elif any(k in name for k in ("water", "sea", "lava", "acid")):
        for y in range(3, TILE, 6):
            for x in range(-4, TILE, 12):
                line(d, (x, y + rng.randrange(-1, 2), x + 5, y - 2, x + 11, y), pal[2], 1)
        dot_noise(d, rng, [pal[1], pal[2], pal[4]], 22)
    elif any(k in name for k in ("grass", "moss", "plant")):
        dot_noise(d, rng, [pal[1], pal[2], pal[3]], 90)
        for _ in range(12):
            x = rng.randrange(TILE)
            y = rng.randrange(TILE)
            line(d, (x, y, x + rng.randrange(-1, 2), y - rng.randrange(2, 5)), pal[4])
    else:
        dot_noise(d, rng, [pal[1], pal[2], pal[3], pal[4]], 80)
        for _ in range(8):
            x = rng.randrange(TILE)
            y = rng.randrange(TILE)
            line(d, (x, y, x + rng.randrange(2, 8), y), rng.choice([pal[2], pal[3]]))

    line(d, (0, 0, TILE - 1, 0), tuple(min(255, c + 18) for c in pal[1]))
    line(d, (0, 0, 0, TILE - 1), tuple(min(255, c + 12) for c in pal[1]))
    line(d, (0, TILE - 1, TILE - 1, TILE - 1), pal[3])
    line(d, (TILE - 1, 0, TILE - 1, TILE - 1), pal[3])
    return img


def draw_wall(path: Path, pal) -> Image.Image:
    rng = random.Random(seed_for(path))
    img = Image.new("RGBA", (TILE, TILE), pal[0] + (255,))
    d = ImageDraw.Draw(img)
    name = path.stem.lower()

    if any(k in name for k in ("brick", "red", "slime")):
        h = 7
        for y in range(-1, TILE, h):
            offset = (y // h % 2) * 8
            line(d, (0, y, TILE, y), pal[3])
            for x in range(-offset, TILE, 16):
                rect(d, (x, y + 1, x + 15, y + h - 1), rng.choice(pal[:3]), pal[3])
                d.point((x + 2, y + 2), fill=pal[4])
    else:
        for _ in range(20):
            x = rng.randrange(-5, TILE)
            y = rng.randrange(-3, TILE)
            w = rng.randrange(7, 16)
            h = rng.randrange(6, 13)
            rect(d, (x, y, x + w, y + h), rng.choice(pal[:3]), pal[3])

    rect(d, (0, 0, TILE - 1, 4), pal[2])
    line(d, (0, 5, TILE - 1, 5), pal[4])
    rect(d, (0, TILE - 4, TILE - 1, TILE - 1), pal[3])
    return img


def draw_water(path: Path, pal) -> Image.Image:
    img = draw_floor(path, pal)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed_for(path) + 9)
    for _ in range(5):
        x = rng.randrange(-3, 26)
        y = rng.randrange(4, 29)
        line(d, (x, y, x + 4, y - 2, x + 10, y), pal[4])
    return img


def draw_door(path: Path, pal) -> Image.Image:
    name = path.stem.lower()
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    frame = PALETTES["metal"] if "gate" in name else PALETTES["wood"]
    if "open" in name or "broken" in name:
        rect(d, (6, 6, 12, 29), frame[1], frame[3])
        rect(d, (20, 6, 26, 29), frame[1], frame[3])
        if "broken" in name:
            line(d, (8, 9, 12, 20, 7, 29), frame[4])
            line(d, (24, 8, 20, 17, 25, 28), frame[4])
    else:
        rect(d, (7, 5, 25, 29), frame[1], frame[3])
        rect(d, (10, 8, 22, 27), frame[2], frame[3])
        line(d, (16, 8, 16, 27), frame[3])
        d.ellipse((20, 16, 22, 18), fill=PALETTES["gold"][2])
    if "runed" in name or "sealed" in name:
        line(d, (11, 12, 21, 22), PALETTES["purple"][4])
        line(d, (21, 12, 11, 22), PALETTES["purple"][4])
    return img


def draw_altar(path: Path, pal) -> Image.Image:
    rng = random.Random(seed_for(path))
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rect(d, (7, 21, 25, 27), pal[1], pal[3])
    rect(d, (10, 15, 22, 22), pal[2], pal[3])
    rect(d, (12, 11, 20, 16), pal[0], pal[3])
    accent = rng.choice([PALETTES["gold"][4], PALETTES["purple"][4], PALETTES["water"][4], PALETTES["lava"][4]])
    d.ellipse((13, 5, 19, 11), fill=accent, outline=pal[4])
    line(d, (16, 11, 16, 16), accent)
    return img


def draw_statue(path: Path, pal) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone = PALETTES["bone"] if "angel" in path.stem.lower() else PALETTES["stone"]
    rect(d, (8, 25, 24, 29), stone[1], stone[3])
    rect(d, (11, 19, 21, 25), stone[2], stone[3])
    d.ellipse((12, 8, 20, 16), fill=stone[2], outline=stone[3])
    line(d, (13, 17, 9, 23), stone[1], 2)
    line(d, (19, 17, 23, 23), stone[1], 2)
    line(d, (13, 9, 19, 9), stone[4])
    return img


def draw_tree(path: Path, pal) -> Image.Image:
    rng = random.Random(seed_for(path))
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood = PALETTES["wood"]
    rect(d, (14, 18, 18, 29), wood[1], wood[3])
    for _ in range(6):
        x = rng.randrange(5, 18)
        y = rng.randrange(3, 15)
        d.ellipse((x, y, x + rng.randrange(8, 14), y + rng.randrange(7, 13)), fill=rng.choice(pal[:3]), outline=pal[3])
    line(d, (7, 8, 21, 6), pal[4])
    return img


def draw_trap(path: Path, pal) -> Image.Image:
    img = draw_floor(path, PALETTES["stone"])
    d = ImageDraw.Draw(img)
    name = path.stem.lower()
    if "shaft" in name:
        d.ellipse((8, 8, 24, 24), fill=PALETTES["dark"][0], outline=PALETTES["dark"][4])
    elif "web" in name:
        for p in [(16, 2), (30, 16), (16, 30), (2, 16)]:
            line(d, (16, 16, *p), (218, 218, 210))
        d.ellipse((7, 7, 25, 25), outline=(218, 218, 210))
    else:
        metal = PALETTES["metal"]
        for x in (9, 15, 21):
            d.polygon([(x, 22), (x + 3, 9), (x + 6, 22)], fill=metal[2], outline=metal[3])
    return img


def draw_gateway(path: Path, pal) -> Image.Image:
    rng = random.Random(seed_for(path))
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone = PALETTES["stone"]
    d.arc((5, 3, 27, 29), 180, 360, fill=stone[3], width=4)
    rect(d, (5, 14, 10, 29), stone[1], stone[3])
    rect(d, (22, 14, 27, 29), stone[1], stone[3])
    color = rng.choice([PALETTES["purple"][4], PALETTES["water"][4], PALETTES["lava"][4], PALETTES["gold"][4]])
    d.ellipse((10, 8, 22, 25), fill=color + (90,), outline=color)
    line(d, (13, 14, 19, 20), color)
    line(d, (19, 14, 13, 20), color)
    return img


def draw_shop(path: Path, pal) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood = PALETTES["wood"]
    rect(d, (5, 10, 27, 28), wood[1], wood[3])
    rect(d, (4, 6, 28, 12), PALETTES["red"][2], wood[3])
    for x in range(6, 28, 6):
        line(d, (x, 6, x + 3, 12), PALETTES["gold"][3])
    rect(d, (12, 16, 20, 28), wood[3], wood[4])
    return img


def source_mask_icon(path: Path, pal) -> Image.Image:
    try:
        src = Image.open(path).convert("RGBA").resize((TILE, TILE), Image.Resampling.NEAREST)
    except Exception:
        return draw_floor(path, pal)

    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pixels = src.load()
    out = img.load()
    for y in range(TILE):
        for x in range(TILE):
            r, g, b, a = pixels[x, y]
            if a <= 24:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            idx = 0 if lum < 56 else 1 if lum < 112 else 2 if lum < 176 else 4
            c = pal[idx]
            out[x, y] = c + (255,)

    alpha = img.getchannel("A")
    for y in range(TILE):
        for x in range(TILE):
            if alpha.getpixel((x, y)):
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < TILE and 0 <= ny < TILE and alpha.getpixel((nx, ny)):
                    d.point((x, y), fill=(31, 27, 27, 190))
                    break
    return img


def draw_tile(path: Path, source_root: Path) -> Image.Image:
    rel = path.relative_to(source_root)
    parts = rel.parts
    category = parts[0] if len(parts) > 1 else "misc"
    pal = palette_for(path.stem, category)

    if category == "floor":
        return draw_floor(path, pal)
    if category == "wall" or category == "vaults":
        return draw_wall(path, pal)
    if category == "water":
        return draw_water(path, PALETTES["water"])
    if category == "doors":
        return draw_door(path, pal)
    if category == "altars":
        return draw_altar(path, pal)
    if category == "statues":
        return draw_statue(path, pal)
    if category == "trees":
        return draw_tree(path, pal)
    if category == "traps":
        return draw_trap(path, pal)
    if category == "gateways":
        return draw_gateway(path, pal)
    if category == "shops":
        return draw_shop(path, pal)
    if category == "decor" and "fountain" in path.stem.lower():
        return draw_gateway(path, PALETTES["water"])
    if category == "path":
        img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        line(d, (4, 16, 28, 16), PALETTES["gold"][4], 2)
        line(d, (22, 10, 28, 16, 22, 22), PALETTES["gold"][4], 2)
        return img
    return source_mask_icon(path, pal)


def build(source: Path, out: Path, manifest: Path, columns: int) -> None:
    root = Path.cwd().resolve()
    source = source.resolve()
    out = out.resolve()
    manifest = manifest.resolve()
    files = sorted(source.rglob("*.png"), key=lambda p: p.relative_to(source).as_posix())
    rows = math.ceil(len(files) / columns)
    sheet = Image.new("RGBA", (columns * TILE, rows * TILE), (0, 0, 0, 0))
    frames = []

    for index, path in enumerate(files):
        tile = draw_tile(path, source)
        x = (index % columns) * TILE
        y = (index // columns) * TILE
        sheet.alpha_composite(tile, (x, y))
        frames.append(
            {
                "index": index,
                "name": path.stem,
                "source": path.relative_to(root).as_posix(),
                "x": x,
                "y": y,
                "w": TILE,
                "h": TILE,
            }
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    manifest.write_text(
        json.dumps(
            {
                "image": out.name,
                "tile_size": TILE,
                "columns": columns,
                "rows": rows,
                "count": len(frames),
                "style": "ULPC-style redrawn dungeon tile sheet; source files used as semantic references",
                "frames": frames,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="assets/tiles/individual/dngn")
    parser.add_argument("--out", default="assets/tiles/sheets/dngn_ulpc_redrawn_sheet.png")
    parser.add_argument("--manifest", default="assets/tiles/sheets/dngn_ulpc_redrawn_sheet.json")
    parser.add_argument("--columns", type=int, default=DEFAULT_COLUMNS)
    args = parser.parse_args()
    build(Path(args.source), Path(args.out), Path(args.manifest), args.columns)


if __name__ == "__main__":
    main()
