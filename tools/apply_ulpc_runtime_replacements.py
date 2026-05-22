#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from datetime import datetime
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/tiles/sheets/ulpc_runtime_concepts"
INDEX = BASE / "runtime_concepts_index.json"
TILE = 32
MAGENTA = (255, 0, 255)
MAGENTA_TOLERANCE = 22


def color_close(a: tuple[int, int, int], b: tuple[int, int, int], tol: int) -> bool:
    return all(abs(int(a[i]) - int(b[i])) <= tol for i in range(3))


def remove_magenta(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGBA")
    px = cell.load()
    out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    op = out.load()
    for y in range(cell.height):
        for x in range(cell.width):
            r, g, b, a = px[x, y]
            if a == 0 or color_close((r, g, b), MAGENTA, MAGENTA_TOLERANCE):
                continue
            op[x, y] = (r, g, b, a)
    return out


def backup_path(path: Path, backup_root: Path) -> Path:
    rel = path.relative_to(ROOT)
    return backup_root / rel


def apply_replacements(dry_run: bool = False) -> dict:
    index = json.loads(INDEX.read_text(encoding="utf-8"))
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_root = ROOT / "assets/tiles/backups/ulpc_runtime_replacements" / stamp
    report = {
        "backup_root": str(backup_root.relative_to(ROOT)),
        "dry_run": dry_run,
        "replaced": [],
        "skipped_duplicate_targets": [],
        "missing_targets": [],
    }
    seen_targets: set[Path] = set()

    for concept in index["concepts"]:
        manifest_path = BASE / concept["manifest"]
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        sheet = Image.open(BASE / manifest["image"]).convert("RGBA")

        for frame in manifest["frames"]:
            target = ROOT / frame["source"]
            if not target.exists():
                report["missing_targets"].append(frame["source"])
                continue
            if target in seen_targets:
                report["skipped_duplicate_targets"].append(
                    {
                        "concept": concept["slug"],
                        "role": frame["role"],
                        "target": frame["source"],
                    }
                )
                continue
            seen_targets.add(target)

            cell = sheet.crop(
                (
                    int(frame["x"]),
                    int(frame["y"]),
                    int(frame["x"]) + TILE,
                    int(frame["y"]) + TILE,
                )
            )
            if frame["row_type"] == "object":
                cell = remove_magenta(cell)
            else:
                cell = cell.convert("RGBA")

            backup = backup_path(target, backup_root)
            report["replaced"].append(
                {
                    "concept": concept["slug"],
                    "role": frame["role"],
                    "row_type": frame["row_type"],
                    "target": frame["source"],
                    "backup": str(backup.relative_to(ROOT)),
                }
            )

            if dry_run:
                continue

            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(target, backup)
            cell.save(target)

    report_path = backup_root / "replacement_report.json"
    if not dry_run:
        backup_root.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    report = apply_replacements(dry_run=args.dry_run)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
