#!/usr/bin/env python3
"""
Extract 50 monster sprites from monster_roster_50_green.png,
remove green (#00FF00) background, and install into the game tile tree.
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET_PATH = "asset_test/monster_roster_50_green.png"
TILE_BASE  = "assets/tiles/individual/mon"
PREVIEW_DIR = "asset_test/monsters"

# (row, col) -> relative path under TILE_BASE
CELL_TO_TILE = {
    (0, 0): "humanoids/goblin.png",
    (0, 1): "humanoids/hobgoblin.png",
    (0, 2): "humanoids/kobold.png",
    (0, 3): "undead/zombies/zombie_human.png",
    (0, 4): "undead/skeletal_warrior.png",
    (0, 5): "animals/adder.png",
    (0, 6): "animals/wolf.png",
    (0, 7): "animals/black_bear.png",
    (0, 8): "animals/wolf_spider.png",
    (0, 9): "animals/scorpion.png",

    (1, 0): "animals/viper.png",
    (1, 1): "animals/anaconda.png",
    (1, 2): "humanoids/troll.png",
    (1, 3): "humanoids/orcs/orc.png",
    (1, 4): "humanoids/orcs/orc_warrior.png",
    (1, 5): "humanoids/orcs/orc_apostle_wizard1.png",
    (1, 6): "humanoids/orcs/orc_priest.png",
    (1, 7): "humanoids/gnoll.png",
    (1, 8): "humanoids/gnoll_sergeant.png",
    (1, 9): "humanoids/gnoll_shaman.png",

    (2, 0): "humanoids/ogre.png",
    (2, 1): "humanoids/elves/deep_elf_archer.png",
    (2, 2): "humanoids/elves/deep_elf_death_mage.png",
    (2, 3): "humanoids/ogre_mage.png",
    (2, 4): "undead/vampire.png",
    (2, 5): "undead/vampire_knight.png",
    (2, 6): "nonliving/gargoyle.png",
    (2, 7): "humanoids/humans/vault_warden.png",   # stone_warden
    (2, 8): "undead/wraith.png",
    (2, 9): "undead/shadow_wraith.png",

    (3, 0): "undead/ghoul.png",
    (3, 1): "undead/mummy.png",
    (3, 2): "undead/lich.png",
    (3, 3): "undead/ancient_lich.png",
    (3, 4): "demons/crimson_imp.png",
    (3, 5): "demons/red_devil.png",
    (3, 6): "demons/balrug.png",
    (3, 7): "demons/executioner.png",
    (3, 8): "humanoids/giants/stone_giant.png",
    (3, 9): "humanoids/giants/titan.png",

    (4, 0): "undead/bone_dragon.png",
    (4, 1): "animals/vampire_bat.png",
    (4, 2): "dragons/swamp_dragon.png",
    (4, 3): "dragons/ice_dragon.png",
    (4, 4): "dragons/fire_dragon.png",
    (4, 5): "humanoids/giants/cyclops.png",
    (4, 6): "animals/bog_serpent.png",
    (4, 7): "statues/glacial_sovereign.png",
    (4, 8): "demons/ember_tyrant.png",
    (4, 9): "dragons/golden_dragon.png",
}

# Preview labels (row, col) -> short name
PREVIEW_LABELS = [
    "goblin","hobgoblin","kobold","zombie","skeletal_warrior",
    "adder","wolf","black_bear","giant_wolf_spider","scorpion",
    "viper","anaconda","troll","orc","orc_warrior",
    "orc_wizard","orc_priest","gnoll","gnoll_sergeant","gnoll_shaman",
    "ogre","deep_elf_archer","deep_elf_death_mage","ogre_mage","vampire",
    "vampire_knight","gargoyle","stone_warden","wraith","shadow_wraith",
    "ghoul","mummy","lich","ancient_lich","crimson_imp",
    "red_devil","balrug","executioner","stone_giant","titan",
    "bone_dragon","vampire_bat","swamp_dragon","ice_dragon","fire_dragon",
    "cyclops","bog_serpent","glacial_sovereign","ember_tyrant","golden_dragon",
]


def remove_green_bg(arr: np.ndarray) -> np.ndarray:
    """Return RGBA array with green (#00FF00) background removed. Input may be RGB or RGBA."""
    if arr.shape[2] == 3:
        rgba = np.dstack([arr, np.full(arr.shape[:2], 255, dtype=np.uint8)])
    else:
        rgba = arr.copy()
    R, G, B = rgba[:,:,0], rgba[:,:,1], rgba[:,:,2]

    # Hard green mask with tolerance for JPEG noise
    hard = (G.astype(int) - R.astype(int) > 60) & \
           (G.astype(int) - B.astype(int) > 60) & \
           (G > 100)

    # Flood-fill from all 4 borders to isolate background
    seed = np.zeros_like(hard, dtype=bool)
    seed[0, :] = hard[0, :]
    seed[-1, :] = hard[-1, :]
    seed[:, 0] = hard[:, 0]
    seed[:, -1] = hard[:, -1]

    labeled, _ = ndimage.label(hard)
    bg_labels = set(labeled[seed].flatten()) - {0}
    bg_mask = np.isin(labeled, list(bg_labels))

    # Dilate to catch edge spill
    edge_zone = ndimage.binary_dilation(bg_mask, iterations=2)

    # Soft ramp on green-spill pixels in the edge zone
    greenness = (G.astype(float) - np.maximum(R, B).astype(float) - 20) / 80.0
    greenness = np.clip(greenness, 0.0, 1.0)
    spill_alpha = (1.0 - greenness) * 255.0

    alpha = rgba[:,:,3].astype(float)
    alpha[bg_mask] = 0.0
    alpha[edge_zone & ~bg_mask] = np.minimum(
        alpha[edge_zone & ~bg_mask],
        spill_alpha[edge_zone & ~bg_mask]
    )
    rgba[:,:,3] = alpha.astype(np.uint8)
    return rgba


def detect_separators(projection, min_gap=4, threshold_frac=0.02):
    """Return list of separator midpoint positions from a 1-D sum projection."""
    total = float(projection.max())
    thresh = total * threshold_frac
    in_gap = projection < thresh
    seps = []
    start = None
    for i, g in enumerate(in_gap):
        if g and start is None:
            start = i
        elif not g and start is not None:
            if i - start >= min_gap:
                seps.append((start + i) // 2)
            start = None
    return seps


def main():
    os.makedirs(PREVIEW_DIR, exist_ok=True)

    sheet = Image.open(SHEET_PATH).convert("RGB")
    arr = np.array(sheet)
    H, W = arr.shape[:2]

    # Detect grid lines as rows/cols that are predominantly green background
    R, G, B = arr[:,:,0].astype(float), arr[:,:,1].astype(float), arr[:,:,2].astype(float)
    # "non-green" content: high value = actual sprite pixel, near-zero = green background
    non_green = np.clip(np.maximum(R, B) - G + 30, 0, None)

    # Per-row/col sum of non-green content; separator rows/cols have near-zero sum
    row_proj = non_green.sum(axis=1)   # (H,)
    col_proj = non_green.sum(axis=0)   # (W,)
    row_seps = [s for s in detect_separators(row_proj, min_gap=4, threshold_frac=0.05)
                if 30 < s < H - 30]
    col_seps = [s for s in detect_separators(col_proj, min_gap=4, threshold_frac=0.05)
                if 30 < s < W - 30]

    # Build cell boundary lists
    row_bounds = [0] + row_seps + [H]
    col_bounds = [0] + col_seps + [W]

    n_rows = len(row_bounds) - 1
    n_cols = len(col_bounds) - 1
    print(f"Detected grid: {n_rows} rows × {n_cols} cols")

    if n_rows != 5 or n_cols != 10:
        print(f"WARNING: expected 5×10, got {n_rows}×{n_cols}. Adjust and re-run.")
        sys.exit(1)

    # Find max content size across all 50 cells (for uniform canvas)
    max_w, max_h = 0, 0
    cells = []
    for r in range(5):
        for c in range(10):
            y0, y1 = row_bounds[r], row_bounds[r+1]
            x0, x1 = col_bounds[c], col_bounds[c+1]
            cell_arr = arr[y0:y1, x0:x1].copy()  # RGB slice
            clean = remove_green_bg(cell_arr)     # -> RGBA

            # Tight crop
            alpha = clean[:,:,3]
            ys, xs = np.where(alpha > 10)
            if len(ys) == 0:
                cells.append(None)
                continue
            y_min, y_max = ys.min(), ys.max()
            x_min, x_max = xs.min(), xs.max()
            cropped = clean[y_min:y_max+1, x_min:x_max+1]
            cells.append(cropped)
            max_w = max(max_w, cropped.shape[1])
            max_h = max(max_h, cropped.shape[0])

    TARGET_SIZE = 32   # must match DungeonMap.CELL_SIZE

    PAD = 4
    canvas_w = max_w + PAD * 2
    canvas_h = max_h + PAD * 2
    print(f"Uniform canvas: {canvas_w}×{canvas_h} -> resized to {TARGET_SIZE}×{TARGET_SIZE}")

    idx = 0
    installed = 0
    for r in range(5):
        for c in range(10):
            cropped = cells[idx]
            label = PREVIEW_LABELS[idx]
            idx += 1

            if cropped is None:
                print(f"  [{r},{c}] {label}: empty cell, skipped")
                continue

            # Centre on uniform canvas
            canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
            ch, cw = cropped.shape[:2]
            off_y = (canvas_h - ch) // 2
            off_x = (canvas_w - cw) // 2
            canvas[off_y:off_y+ch, off_x:off_x+cw] = cropped
            out_img = Image.fromarray(canvas, "RGBA").resize(
                (TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)

            # Save preview
            preview_path = os.path.join(PREVIEW_DIR, f"{idx-1:02d}_{label}.png")
            out_img.save(preview_path, "PNG")

            # Install to game tile
            tile_rel = CELL_TO_TILE.get((r, c))
            if tile_rel:
                tile_path = os.path.join(TILE_BASE, tile_rel)
                os.makedirs(os.path.dirname(tile_path), exist_ok=True)
                out_img.save(tile_path, "PNG")
                installed += 1
                print(f"  [{r},{c}] {label} -> {tile_rel}")
            else:
                print(f"  [{r},{c}] {label}: no tile mapping, preview only")

    print(f"\nDone. {installed}/50 tiles installed.")


if __name__ == "__main__":
    main()
