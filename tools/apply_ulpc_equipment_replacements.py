#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import shutil
from collections import deque
from datetime import datetime
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/tiles/sheets/ulpc_equipment"
INVENTORY = BASE / "equipment_tile_inventory.json"
TILE = 32
MAGENTA = (255, 0, 255)
MAGENTA_TOL = 36

SHEET_LAYOUTS = {
    "weapons": ("weapons_raw.png", 7, 3),
    "armour": ("armour_raw.png", 6, 3),
    "jewellery": ("jewellery_raw.png", 6, 3),
}


def color_close(a: tuple[int, int, int], b: tuple[int, int, int], tol: int = MAGENTA_TOL) -> bool:
    return all(abs(int(a[i]) - int(b[i])) <= tol for i in range(3))


def crop_grid_cell(img: Image.Image, cols: int, rows: int, index: int) -> Image.Image:
    col = index % cols
    row = index // cols
    w, h = img.size
    cell_w = w / cols
    cell_h = h / rows
    margin_x = max(2, int(cell_w * 0.025))
    margin_y = max(2, int(cell_h * 0.025))
    return img.crop(
        (
            round(col * cell_w) + margin_x,
            round(row * cell_h) + margin_y,
            round((col + 1) * cell_w) - margin_x,
            round((row + 1) * cell_h) - margin_y,
        )
    )


def object_on_alpha(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGBA")
    w, h = cell.size
    px = cell.load()
    corners = [px[0, 0][:3], px[w - 1, 0][:3], px[0, h - 1][:3], px[w - 1, h - 1][:3]]
    bg = max(corners + [MAGENTA], key=lambda c: corners.count(c) + (2 if color_close(c, MAGENTA) else 0))
    visited = [[False] * h for _ in range(w)]
    q = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    for x, y in q:
        visited[x][y] = True
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= nx < w and 0 <= ny < h) or visited[nx][ny]:
                continue
            c = px[nx, ny][:3]
            if color_close(c, bg) or color_close(c, MAGENTA):
                visited[nx][ny] = True
                q.append((nx, ny))

    fg = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    fp = fg.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            if visited[x][y] or color_close(px[x, y][:3], MAGENTA):
                continue
            fp[x, y] = px[x, y]
            xs.append(x)
            ys.append(y)

    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
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


def backup_file(path: Path, backup_root: Path, report: dict) -> None:
    if not path.exists():
        return
    backup = backup_root / path.relative_to(ROOT)
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(path, backup)
    report["backups"].append(str(backup.relative_to(ROOT)))


def set_tile_path(resource_path: Path, new_project_path: str) -> None:
    text = resource_path.read_text(encoding="utf-8")
    new_res = "res://" + new_project_path
    if re.search(r'^tile_path\s*=\s*"[^"]*"', text, re.M):
        text = re.sub(r'^tile_path\s*=\s*"[^"]*"', f'tile_path = "{new_res}"', text, count=1, flags=re.M)
    else:
        text = text.replace("[resource]\n", f'[resource]\ntile_path = "{new_res}"\n', 1)
    resource_path.write_text(text, encoding="utf-8")


def main() -> None:
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_root = ROOT / "assets/tiles/backups/ulpc_equipment_replacements" / stamp
    report = {
        "backup_root": str(backup_root.relative_to(ROOT)),
        "chroma_key_removed": "#ff00ff",
        "replaced": [],
        "resource_updates": [],
        "backups": [],
    }

    for group, entries in inventory["groups"].items():
        raw_name, cols, rows = SHEET_LAYOUTS[group]
        raw = Image.open(BASE / raw_name).convert("RGBA")
        sheet = Image.new("RGBA", (cols * TILE, rows * TILE), (0, 0, 0, 0))
        frames = []
        for index, entry in enumerate(entries):
            cell = object_on_alpha(crop_grid_cell(raw, cols, rows, index))
            x = (index % cols) * TILE
            y = (index // cols) * TILE
            sheet.alpha_composite(cell, (x, y))

            target = ROOT / entry["target_tile_path"]
            resource = ROOT / entry["resource"]
            backup_file(target, backup_root, report)
            if entry["updates_resource_tile_path"]:
                backup_file(resource, backup_root, report)
                set_tile_path(resource, entry["target_tile_path"])
                report["resource_updates"].append(
                    {
                        "resource": entry["resource"],
                        "old_tile_path": entry["original_tile_path"],
                        "new_tile_path": entry["target_tile_path"],
                    }
                )
            target.parent.mkdir(parents=True, exist_ok=True)
            cell.save(target)
            frames.append(
                {
                    "index": index,
                    "id": entry["id"],
                    "kind": entry["kind"],
                    "slot": entry["slot"],
                    "target": entry["target_tile_path"],
                    "x": x,
                    "y": y,
                    "w": TILE,
                    "h": TILE,
                }
            )
            report["replaced"].append({"id": entry["id"], "target": entry["target_tile_path"]})

        sheet_name = f"{group}_sheet.png"
        manifest_name = f"{group}_sheet.json"
        sheet.save(BASE / sheet_name)
        (BASE / manifest_name).write_text(
            json.dumps(
                {
                    "image": sheet_name,
                    "raw_image": raw_name,
                    "tile_size": TILE,
                    "columns": cols,
                    "rows": rows,
                    "count": len(entries),
                    "frames": frames,
                },
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

    backup_root.mkdir(parents=True, exist_ok=True)
    (backup_root / "replacement_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps({k: len(v) if isinstance(v, list) else v for k, v in report.items()}, indent=2))


if __name__ == "__main__":
    main()
