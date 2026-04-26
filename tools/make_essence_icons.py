from __future__ import annotations

from pathlib import Path
from PIL import Image


SOURCE = Path(
    r"C:\Users\iipms\.codex\generated_images\019db911-ceea-77e2-a0c2-c8aafb73f02a\ig_06e76b661d70feac0169ee92a8114c8191aae541c11f6b8d2f.png"
)
OUT_DIR = Path(r"D:\PROJ_D\assets\tiles\individual\item\essence")
OUT_DIR.mkdir(parents=True, exist_ok=True)

NAMES = ["essence_normal.png", "essence_rare.png", "essence_unique.png"]
MAGENTA = (255, 0, 255)


def build_alpha(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            # Remove the flat chroma-key background with a little tolerance.
            if r > 235 and g < 30 and b > 235:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, a)
    return rgba


def trim_alpha(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def fit_cell(im: Image.Image, size: int = 32, inset: int = 2) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    target = size - inset * 2
    fitted = im.copy()
    fitted.thumbnail((target, target), Image.Resampling.LANCZOS)
    ox = (size - fitted.width) // 2
    oy = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (ox, oy))
    return canvas


def main() -> None:
    src = Image.open(SOURCE).convert("RGBA")
    w, h = src.size
    cell_w = w // 3
    for idx, name in enumerate(NAMES):
        left = idx * cell_w
        right = w if idx == 2 else (idx + 1) * cell_w
        panel = src.crop((left, 0, right, h))
        panel = build_alpha(panel)
        panel = trim_alpha(panel)
        panel = fit_cell(panel, 32, 2)
        panel.save(OUT_DIR / name)
        print(OUT_DIR / name)


if __name__ == "__main__":
    main()
