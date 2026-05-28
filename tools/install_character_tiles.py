#!/usr/bin/env python3
"""
Extract 28 pre-composed character sprites from character_roster_28_green_v8.png
and install to assets/tiles/individual/player/composed/.

Grid layout:
  Rows (armor tier):  0=robe  1=leather  2=chain  3=plate
  Cols (weapon type): 0=none  1=dagger   2=sword  3=axe  4=greatsword  5=spear  6=staff
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET_PATH = "asset_test/character_roster_28_green_v8.png"
OUT_DIR    = "assets/tiles/individual/player/composed"
PREVIEW_DIR = "asset_test/characters"
TARGET_SIZE = 32

ARMOR_NAMES  = ["robe", "leather", "chain", "plate"]
WEAPON_NAMES = ["none", "dagger", "sword", "axe", "greatsword", "spear", "staff"]


def find_cell_bounds(projection, min_gap=5, threshold_frac=0.01):
    thresh = float(projection.max()) * threshold_frac
    gaps = []; in_gap = False; gs = 0
    for i, v in enumerate(projection):
        if v <= thresh and not in_gap:
            in_gap = True; gs = i
        elif v > thresh and in_gap:
            if i - gs >= min_gap:
                gaps.append((gs, i - 1))
            in_gap = False
    if in_gap and len(projection) - gs >= min_gap:
        gaps.append((gs, len(projection) - 1))
    return [(gaps[i][1] + 1, gaps[i + 1][0] - 1) for i in range(len(gaps) - 1)]


def remove_green_bg(arr: np.ndarray) -> np.ndarray:
    if arr.shape[2] == 3:
        rgba = np.dstack([arr, np.full(arr.shape[:2], 255, dtype=np.uint8)])
    else:
        rgba = arr.copy()
    R, G, B = rgba[:,:,0], rgba[:,:,1], rgba[:,:,2]
    hard = (G.astype(int) - R.astype(int) > 60) & \
           (G.astype(int) - B.astype(int) > 60) & \
           (G > 100)
    seed = np.zeros_like(hard, dtype=bool)
    seed[0, :] = hard[0, :]; seed[-1, :] = hard[-1, :]
    seed[:, 0] = hard[:, 0]; seed[:, -1] = hard[:, -1]
    labeled, _ = ndimage.label(hard)
    bg_labels = set(labeled[seed].flatten()) - {0}
    bg_mask = np.isin(labeled, list(bg_labels))
    edge_zone = ndimage.binary_dilation(bg_mask, iterations=2)
    greenness = (G.astype(float) - np.maximum(R, B).astype(float) - 20) / 80.0
    greenness = np.clip(greenness, 0.0, 1.0)
    spill_alpha = (1.0 - greenness) * 255.0
    alpha = rgba[:,:,3].astype(float)
    alpha[bg_mask] = 0.0
    alpha[edge_zone & ~bg_mask] = np.minimum(
        alpha[edge_zone & ~bg_mask], spill_alpha[edge_zone & ~bg_mask])
    rgba[:,:,3] = alpha.astype(np.uint8)
    return rgba


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)

    sheet = Image.open(SHEET_PATH).convert("RGB")
    arr = np.array(sheet)
    H, W = arr.shape[:2]

    R, G, B = arr[:,:,0].astype(float), arr[:,:,1].astype(float), arr[:,:,2].astype(float)
    non_green = np.clip(np.maximum(R, B) - G + 30, 0, None)

    col_cells = find_cell_bounds(non_green.sum(axis=0))
    row_cells = find_cell_bounds(non_green.sum(axis=1))

    n_rows, n_cols = len(row_cells), len(col_cells)
    print(f"Detected grid: {n_rows} rows × {n_cols} cols")
    if n_rows != 4 or n_cols != 7:
        print(f"ERROR: expected 4×7, got {n_rows}×{n_cols}")
        return

    # Find max content size for uniform canvas
    max_w = max_h = 0
    cells = []
    for r in range(4):
        for c in range(7):
            y0, y1 = row_cells[r]; x0, x1 = col_cells[c]
            cell_arr = arr[y0:y1+1, x0:x1+1].copy()
            clean = remove_green_bg(cell_arr)
            alpha = clean[:,:,3]
            ys, xs = np.where(alpha > 10)
            if len(ys) == 0:
                cells.append(None); continue
            y_min, y_max = ys.min(), ys.max()
            x_min, x_max = xs.min(), xs.max()
            cropped = clean[y_min:y_max+1, x_min:x_max+1]
            cells.append(cropped)
            max_w = max(max_w, cropped.shape[1])
            max_h = max(max_h, cropped.shape[0])

    PAD = 4
    canvas_w = max_w + PAD * 2
    canvas_h = max_h + PAD * 2
    print(f"Uniform canvas: {canvas_w}×{canvas_h} → {TARGET_SIZE}×{TARGET_SIZE}")

    idx = 0
    for r, armor in enumerate(ARMOR_NAMES):
        for c, weapon in enumerate(WEAPON_NAMES):
            cropped = cells[idx]; idx += 1
            name = f"{armor}_{weapon}"

            if cropped is None:
                print(f"  [{r},{c}] {name}: empty, skipped"); continue

            canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
            ch, cw = cropped.shape[:2]
            off_y = (canvas_h - ch) // 2
            off_x = (canvas_w - cw) // 2
            canvas[off_y:off_y+ch, off_x:off_x+cw] = cropped
            out_img = Image.fromarray(canvas, "RGBA").resize(
                (TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)

            out_img.save(os.path.join(PREVIEW_DIR, f"{name}.png"), "PNG")
            out_img.save(os.path.join(OUT_DIR, f"{name}.png"), "PNG")
            print(f"  [{r},{c}] {name}.png")

    print(f"\nDone. 28 sprites installed to {OUT_DIR}/")


if __name__ == "__main__":
    main()
