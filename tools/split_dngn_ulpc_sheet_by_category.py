#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path

from PIL import Image


DEFAULT_COLUMNS = 32
DNGN_ROOT = "assets/tiles/individual/dngn/"


def category_for(source: str) -> str:
    if not source.startswith(DNGN_ROOT):
        return "misc"

    rest = source[len(DNGN_ROOT) :]
    parts = rest.split("/")
    if len(parts) == 1:
        return "misc"
    return parts[0]


def split_sheet(
    source_png: Path,
    source_manifest: Path,
    output_dir: Path,
    columns: int,
    prefix: str,
) -> None:
    sheet = Image.open(source_png).convert("RGBA")
    manifest = json.loads(source_manifest.read_text(encoding="utf-8"))
    tile_size = int(manifest["tile_size"])

    grouped = defaultdict(list)
    for frame in manifest["frames"]:
        grouped[category_for(frame["source"])].append(frame)

    output_dir.mkdir(parents=True, exist_ok=True)
    index = {
        "source_image": source_png.name,
        "source_manifest": source_manifest.name,
        "tile_size": tile_size,
        "columns": columns,
        "categories": [],
    }

    for category in sorted(grouped):
        frames = grouped[category]
        rows = math.ceil(len(frames) / columns)
        category_sheet = Image.new(
            "RGBA", (columns * tile_size, rows * tile_size), (0, 0, 0, 0)
        )
        category_frames = []

        for new_index, frame in enumerate(frames):
            src_box = (
                frame["x"],
                frame["y"],
                frame["x"] + frame["w"],
                frame["y"] + frame["h"],
            )
            tile = sheet.crop(src_box)
            x = (new_index % columns) * tile_size
            y = (new_index // columns) * tile_size
            category_sheet.alpha_composite(tile, (x, y))
            category_frames.append(
                {
                    "index": new_index,
                    "original_index": frame["index"],
                    "name": frame["name"],
                    "source": frame["source"],
                    "x": x,
                    "y": y,
                    "w": tile_size,
                    "h": tile_size,
                }
            )

        image_name = f"{prefix}_{category}.png"
        json_name = f"{prefix}_{category}.json"
        category_sheet.save(output_dir / image_name)
        (output_dir / json_name).write_text(
            json.dumps(
                {
                    "image": image_name,
                    "category": category,
                    "tile_size": tile_size,
                    "columns": columns,
                    "rows": rows,
                    "count": len(category_frames),
                    "frames": category_frames,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        index["categories"].append(
            {
                "category": category,
                "image": image_name,
                "manifest": json_name,
                "count": len(category_frames),
                "columns": columns,
                "rows": rows,
            }
        )

    (output_dir / f"{prefix}_index.json").write_text(
        json.dumps(index, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-png", default="assets/tiles/sheets/dngn_ulpc_sheet.png")
    parser.add_argument(
        "--source-manifest", default="assets/tiles/sheets/dngn_ulpc_sheet.json"
    )
    parser.add_argument("--output-dir", default="assets/tiles/sheets/dngn_ulpc_categories")
    parser.add_argument("--columns", type=int, default=DEFAULT_COLUMNS)
    parser.add_argument("--prefix", default="dngn_ulpc")
    args = parser.parse_args()

    split_sheet(
        Path(args.source_png),
        Path(args.source_manifest),
        Path(args.output_dir),
        args.columns,
        args.prefix,
    )


if __name__ == "__main__":
    main()
