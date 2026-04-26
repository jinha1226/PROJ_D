from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "config" / "balance" / "art_tileset_v2_manifest.json"

BG_TOL = 26


def open_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def color_close(a: tuple[int, int, int], b: tuple[int, int, int], tol: int = BG_TOL) -> bool:
    return all(abs(int(a[i]) - int(b[i])) <= tol for i in range(3))


def crop_cell(img: Image.Image, cols: int, rows: int, col: int, row: int) -> Image.Image:
    w, h = img.size
    x0 = round(col * w / cols)
    x1 = round((col + 1) * w / cols)
    y0 = round(row * h / rows)
    y1 = round((row + 1) * h / rows)
    return img.crop((x0, y0, x1, y1))


def extract_foreground(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGBA")
    w, h = cell.size
    px = cell.load()
    corners = [px[0, 0][:3], px[w - 1, 0][:3], px[0, h - 1][:3], px[w - 1, h - 1][:3]]
    visited = [[False] * h for _ in range(w)]
    q = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    for x, y in q:
        visited[x][y] = True
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if visited[nx][ny]:
                continue
            c = px[nx, ny][:3]
            if any(color_close(c, bg) for bg in corners):
                visited[nx][ny] = True
                q.append((nx, ny))
    xs: list[int] = []
    ys: list[int] = []
    for x in range(w):
        for y in range(h):
            if not visited[x][y]:
                xs.append(x)
                ys.append(y)
    if not xs:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    crop = cell.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    cp = crop.load()
    out = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    op = out.load()
    for x in range(crop.size[0]):
        for y in range(crop.size[1]):
            if not any(color_close(cp[x, y][:3], bg) for bg in corners):
                op[x, y] = cp[x, y]
    return out


def fit_to_template(src: Image.Image, template_path: Path, out_path: Path | None = None) -> None:
    template = open_rgba(template_path)
    out_path = out_path or template_path
    bbox = template.getchannel("A").getbbox()
    if bbox is None:
        bbox = (2, 2, template.width - 2, template.height - 2)
    tw = max(1, bbox[2] - bbox[0])
    th = max(1, bbox[3] - bbox[1])
    sw, sh = src.size
    scale = min(tw / sw, th / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", template.size, (0, 0, 0, 0))
    ox = bbox[0] + (tw - nw) // 2
    oy = bbox[1] + (th - nh) // 2
    out.alpha_composite(resized, (ox, oy))
    out.save(out_path)


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def apply_player_sheets(base_sheet: Path, body_sheet: Path, hand1_sheet: Path, hand2_sheet: Path) -> None:
    manifest = load_manifest()
    bases = open_rgba(base_sheet)
    body = open_rgba(body_sheet)
    hand1 = open_rgba(hand1_sheet)
    hand2 = open_rgba(hand2_sheet)

    base_map = {
        "human_m.png": (0, 0),
        "orc_m.png": (1, 0),
        "elf_m.png": (2, 0),
        "kobold_m.png": (0, 1),
        "troll_m.png": (1, 1),
        "demonspawn_red_m.png": (2, 1),
    }
    for name, (col, row) in base_map.items():
        fit_to_template(
            extract_foreground(crop_cell(bases, 3, 2, col, row)),
            ROOT / "assets" / "tiles" / "individual" / "player" / "base" / name,
        )

    body_names = ["robe_blue.png", "leather_armour.png", "chainmail.png"]
    for idx, name in enumerate(body_names):
        fit_to_template(
            extract_foreground(crop_cell(body, 3, 1, idx, 0)),
            ROOT / "assets" / "tiles" / "individual" / "player" / "body" / name,
        )

    hand1_names = ["dagger.png", "short_sword.png", "mace.png", "spear.png", "bow.png", "staff.png"]
    for idx, name in enumerate(hand1_names):
        fit_to_template(
            extract_foreground(crop_cell(hand1, 6, 1, idx, 0)),
            ROOT / "assets" / "tiles" / "individual" / "player" / "hand1" / name,
        )

    hand2_map = {
        "buckler_round.png": (0, ROOT / "assets" / "tiles" / "individual" / "player" / "hand2" / "buckler_round.png"),
        "kite_shield_round1.png": (
            1,
            ROOT / "assets" / "tiles" / "individual" / "player" / "hand2" / "doll_only" / "kite_shield_round1.png",
        ),
    }
    for _, (idx, target) in hand2_map.items():
        fit_to_template(extract_foreground(crop_cell(hand2, 2, 1, idx, 0)), target)

    print("Applied player sheets using", manifest["version"])


if __name__ == "__main__":
    print(
        "Usage:\n"
        "  python tools/apply_generated_tileset_v2.py\n\n"
        "Edit this script with concrete generated sheet paths, then run it with the bundled Python runtime."
    )
