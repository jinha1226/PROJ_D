#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/tiles/sheets/ulpc_runtime_concepts"
INVENTORY = ROOT / "assets/tiles/sheets/ulpc_concepts/used_dngn_tile_inventory.json"
TILE = 32
MAGENTA = (255, 0, 255, 255)


def crop_grid_cell(img: Image.Image, cols: int, rows: int, col: int, row: int) -> Image.Image:
    w, h = img.size
    cell_w = w / cols
    cell_h = h / rows
    margin_x = max(0, int(cell_w * 0.025))
    margin_y = max(0, int(cell_h * 0.025))
    return img.crop(
        (
            round(col * cell_w) + margin_x,
            round(row * cell_h) + margin_y,
            round((col + 1) * cell_w) - margin_x,
            round((row + 1) * cell_h) - margin_y,
        )
    )


def color_close(a: tuple[int, int, int], b: tuple[int, int, int], tol: int = 34) -> bool:
    return all(abs(a[i] - b[i]) <= tol for i in range(3))


def object_on_magenta(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGBA")
    w, h = cell.size
    px = cell.load()
    corners = [px[0, 0][:3], px[w - 1, 0][:3], px[0, h - 1][:3], px[w - 1, h - 1][:3]]
    bg = max(corners, key=corners.count)
    visited = [[False] * h for _ in range(w)]
    q = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    for x, y in q:
        visited[x][y] = True

    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= nx < w and 0 <= ny < h) or visited[nx][ny]:
                continue
            if color_close(px[nx, ny][:3], bg):
                visited[nx][ny] = True
                q.append((nx, ny))

    fg = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    fp = fg.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            if visited[x][y]:
                continue
            fp[x, y] = px[x, y]
            xs.append(x)
            ys.append(y)

    out = Image.new("RGBA", (TILE, TILE), MAGENTA)
    if not xs:
        return out
    bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    fg = fg.crop(bbox)
    scale = min((TILE - 2) / fg.width, (TILE - 2) / fg.height)
    resized = fg.resize(
        (max(1, round(fg.width * scale)), max(1, round(fg.height * scale))),
        Image.Resampling.LANCZOS,
    )
    out.alpha_composite(resized, ((TILE - resized.width) // 2, (TILE - resized.height) // 2))
    return out


def normalize_standard(slug: str, entries: list[dict], counts: dict) -> dict:
    raw = Image.open(BASE / f"{slug}_raw.png").convert("RGBA")
    rows = []
    if counts["floor"]:
        rows.append(("floor", counts["floor"]))
    if counts["wall"]:
        rows.append(("wall", counts["wall"]))
    if counts["object"]:
        rows.append(("object", counts["object"]))
    cols = max(count for _, count in rows)
    out = Image.new("RGBA", (cols * TILE, len(rows) * TILE), (0, 0, 0, 0))
    frames = []
    entry_by_type = {k: [e for e in entries if e["row_type"] == k] for k, _ in rows}

    for row_idx, (kind, count) in enumerate(rows):
        for col in range(count):
            source_cell = crop_grid_cell(raw, cols, len(rows), col, row_idx)
            if kind == "object":
                cell = object_on_magenta(source_cell)
            else:
                cell = source_cell.resize((TILE, TILE), Image.Resampling.LANCZOS)
            out.alpha_composite(cell, (col * TILE, row_idx * TILE))
            entry = entry_by_type[kind][col]
            frames.append(
                {
                    "index": len(frames),
                    "role": entry["role"],
                    "row_type": kind,
                    "source": entry["path"],
                    "x": col * TILE,
                    "y": row_idx * TILE,
                    "w": TILE,
                    "h": TILE,
                }
            )

    image = f"{slug}_sheet.png"
    manifest = f"{slug}_sheet.json"
    out.save(BASE / image)
    data = {
        "image": image,
        "raw_image": f"{slug}_raw.png",
        "tile_size": TILE,
        "columns": cols,
        "rows": len(rows),
        "counts": counts,
        "frames": frames,
    }
    (BASE / manifest).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return {"slug": slug, "image": image, "manifest": manifest, "counts": counts}


def normalize_temple(entries: list[dict], counts: dict) -> dict:
    raw = Image.open(BASE / "temple_raw.png").convert("RGBA")
    out = Image.new("RGBA", (17 * TILE, 3 * TILE), (0, 0, 0, 0))

    # The generated temple sheet intentionally leaves black filler in rows 1-2.
    # Crop the visible first-column floor/wall from the left side, then split the magenta altar strip.
    floor_crop = raw.crop((0, int(raw.height * 0.12), int(raw.width * 0.13), int(raw.height * 0.37)))
    wall_crop = raw.crop((0, int(raw.height * 0.38), int(raw.width * 0.13), int(raw.height * 0.61)))
    object_strip = raw.crop((0, int(raw.height * 0.61), raw.width, int(raw.height * 0.88)))

    out.alpha_composite(floor_crop.resize((TILE, TILE), Image.Resampling.LANCZOS), (0, 0))
    out.alpha_composite(wall_crop.resize((TILE, TILE), Image.Resampling.LANCZOS), (0, TILE))

    frames = []
    floor_entry = [e for e in entries if e["row_type"] == "floor"][0]
    wall_entry = [e for e in entries if e["row_type"] == "wall"][0]
    frames.append({"index": 0, "role": floor_entry["role"], "row_type": "floor", "source": floor_entry["path"], "x": 0, "y": 0, "w": TILE, "h": TILE})
    frames.append({"index": 1, "role": wall_entry["role"], "row_type": "wall", "source": wall_entry["path"], "x": 0, "y": TILE, "w": TILE, "h": TILE})

    objects = [e for e in entries if e["row_type"] == "object"]
    for col, entry in enumerate(objects):
        cell = crop_grid_cell(object_strip, 17, 1, col, 0)
        out.alpha_composite(object_on_magenta(cell), (col * TILE, 2 * TILE))
        frames.append(
            {
                "index": len(frames),
                "role": entry["role"],
                "row_type": "object",
                "source": entry["path"],
                "x": col * TILE,
                "y": 2 * TILE,
                "w": TILE,
                "h": TILE,
            }
        )

    image = "temple_sheet.png"
    manifest = "temple_sheet.json"
    out.save(BASE / image)
    data = {
        "image": image,
        "raw_image": "temple_raw.png",
        "tile_size": TILE,
        "columns": 17,
        "rows": 3,
        "counts": counts,
        "frames": frames,
    }
    (BASE / manifest).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return {"slug": "temple", "image": image, "manifest": manifest, "counts": counts}


def main() -> None:
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))["concepts"]
    index = {
        "tile_size": TILE,
        "chroma_key": "#ff00ff",
        "source_inventory": str(INVENTORY.relative_to(ROOT)),
        "concepts": [],
    }
    for slug, data in inventory.items():
        if not (BASE / f"{slug}_raw.png").exists():
            continue
        if slug == "temple":
            item = normalize_temple(data["tiles"], data["counts"])
        else:
            item = normalize_standard(slug, data["tiles"], data["counts"])
        index["concepts"].append(item)

    (BASE / "runtime_concepts_index.json").write_text(
        json.dumps(index, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(index["concepts"], indent=2))


if __name__ == "__main__":
    main()
