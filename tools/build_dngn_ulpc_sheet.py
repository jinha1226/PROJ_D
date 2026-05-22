#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageEnhance


TILE_SIZE = 32
DEFAULT_COLUMNS = 64


def nontransparent_rgb(path: Path, max_samples: int = 4096) -> list[tuple[int, int, int]]:
    img = Image.open(path).convert("RGBA")
    pixels = list(img.getdata())
    colors = [(r, g, b) for r, g, b, a in pixels if a > 32]
    if len(colors) <= max_samples:
        return colors
    step = max(1, len(colors) // max_samples)
    return colors[::step][:max_samples]


def build_reference_palette(root: Path, colors: int = 96) -> list[tuple[int, int, int]]:
    refs: list[Path] = []
    refs.extend(sorted((root / "assets/tiles/individual/dngn/floor").glob("lpc_*.png")))
    refs.extend(sorted((root / "assets/tiles/individual/dngn/wall").glob("lpc_*.png")))
    refs.extend(sorted((root / "assets/tiles/individual/player/human_lpc").glob("*.png")))

    samples: list[tuple[int, int, int]] = []
    for ref in refs:
        samples.extend(nontransparent_rgb(ref))

    if not samples:
        return []

    width = 256
    height = math.ceil(len(samples) / width)
    sample_img = Image.new("RGB", (width, height), (0, 0, 0))
    sample_img.putdata(samples + [(0, 0, 0)] * (width * height - len(samples)))
    paletted = sample_img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    palette = paletted.getpalette()[: colors * 3]
    return [(palette[i], palette[i + 1], palette[i + 2]) for i in range(0, len(palette), 3)]


def nearest_palette_color(
    color: tuple[int, int, int], palette: list[tuple[int, int, int]]
) -> tuple[int, int, int]:
    r, g, b = color
    return min(
        palette,
        key=lambda p: (r - p[0]) * (r - p[0])
        + (g - p[1]) * (g - p[1])
        + (b - p[2]) * (b - p[2]),
    )


def fit_tile(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    if img.size == (TILE_SIZE, TILE_SIZE):
        return img

    fitted = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    scale = min(TILE_SIZE / img.width, TILE_SIZE / img.height)
    new_size = (
        max(1, round(img.width * scale)),
        max(1, round(img.height * scale)),
    )
    resized = img.resize(new_size, Image.Resampling.NEAREST)
    fitted.alpha_composite(
        resized, ((TILE_SIZE - new_size[0]) // 2, (TILE_SIZE - new_size[1]) // 2)
    )
    return fitted


def shift_toward_ulpc_palette(
    img: Image.Image, palette: list[tuple[int, int, int]]
) -> Image.Image:
    img = ImageEnhance.Contrast(img).enhance(1.10)
    img = ImageEnhance.Color(img).enhance(1.08)
    img = ImageEnhance.Brightness(img).enhance(1.02)

    if not palette:
        return img

    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()

    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue

            pr, pg, pb = nearest_palette_color((r, g, b), palette)
            lum = (r * 299 + g * 587 + b * 114) / 1000
            mix = 0.48 if lum > 42 else 0.32
            nr = round(r * (1 - mix) + pr * mix)
            ng = round(g * (1 - mix) + pg * mix)
            nb = round(b * (1 - mix) + pb * mix)

            # ULPC reads best with crisp top-left light and restrained bottom-right shade.
            light = 1.06 - ((x + y) / (img.width + img.height)) * 0.12
            if x >= img.width - 2 or y >= img.height - 2:
                light *= 0.90
            if x <= 1 or y <= 1:
                light *= 1.05

            dst[x, y] = (
                max(0, min(255, round(nr * light))),
                max(0, min(255, round(ng * light))),
                max(0, min(255, round(nb * light))),
                a,
            )

    return out


def add_object_outline(img: Image.Image) -> Image.Image:
    alpha = img.getchannel("A")
    opaque = alpha.point(lambda p: 255 if p > 48 else 0)
    bbox = opaque.getbbox()
    if not bbox:
        return img

    # Only outline sparse/object tiles. Full floor and wall tiles should stay seamless.
    coverage = sum(1 for p in opaque.getdata() if p) / (TILE_SIZE * TILE_SIZE)
    if coverage > 0.88:
        return img

    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src_alpha = opaque.load()
    out_px = out.load()

    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            if src_alpha[x, y]:
                continue
            neighbor = False
            for ny in (y - 1, y, y + 1):
                for nx in (x - 1, x, x + 1):
                    if 0 <= nx < TILE_SIZE and 0 <= ny < TILE_SIZE and src_alpha[nx, ny]:
                        neighbor = True
                        break
                if neighbor:
                    break
            if neighbor:
                out_px[x, y] = (36, 30, 28, 120)

    out.alpha_composite(img)
    return out


def build_sheet(source_dir: Path, output_png: Path, output_json: Path, columns: int) -> None:
    root = Path.cwd().resolve()
    source_dir = source_dir.resolve()
    output_png = output_png.resolve()
    output_json = output_json.resolve()
    files = sorted(source_dir.rglob("*.png"), key=lambda p: p.relative_to(source_dir).as_posix())
    if not files:
        raise SystemExit(f"No PNG files found under {source_dir}")

    palette = build_reference_palette(root)
    rows = math.ceil(len(files) / columns)
    sheet = Image.new("RGBA", (columns * TILE_SIZE, rows * TILE_SIZE), (0, 0, 0, 0))
    frames = []

    for index, path in enumerate(files):
        tile = fit_tile(Image.open(path))
        tile = shift_toward_ulpc_palette(tile, palette)
        tile = add_object_outline(tile)

        col = index % columns
        row = index // columns
        x = col * TILE_SIZE
        y = row * TILE_SIZE
        sheet.alpha_composite(tile, (x, y))
        frames.append(
            {
                "index": index,
                "name": path.stem,
                "source": path.relative_to(root).as_posix(),
                "x": x,
                "y": y,
                "w": TILE_SIZE,
                "h": TILE_SIZE,
            }
        )

    output_png.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_png)
    output_json.write_text(
        json.dumps(
            {
                "image": output_png.name,
                "tile_size": TILE_SIZE,
                "columns": columns,
                "rows": rows,
                "count": len(frames),
                "style": "ULPC-compatible remaster from source dungeon tiles",
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
    parser.add_argument("--out", default="assets/tiles/sheets/dngn_ulpc_sheet.png")
    parser.add_argument("--manifest", default="assets/tiles/sheets/dngn_ulpc_sheet.json")
    parser.add_argument("--columns", type=int, default=DEFAULT_COLUMNS)
    args = parser.parse_args()

    build_sheet(Path(args.source), Path(args.out), Path(args.manifest), args.columns)


if __name__ == "__main__":
    main()
