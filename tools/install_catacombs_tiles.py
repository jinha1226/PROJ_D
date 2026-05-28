#!/usr/bin/env python3
"""
Extract 15 dungeon tiles from main_floor1_catacombs_sheet.png
and install to the paths listed in main_floor1_catacombs_sheet_order.txt.
Also regenerates .import files.
"""
import os, re, hashlib, random, string
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET  = "asset_test/main_floor1_catacombs_sheet.png"
ORDER  = "asset_test/main_floor1_catacombs_sheet_order.txt"
TARGET = 32

IMPORT_TEMPLATE = """\
[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{basename}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{source_file}"
dest_files=["res://.godot/imported/{basename}-{hash}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

def godot_uid():
    chars = string.ascii_lowercase + string.digits
    return "uid://" + "".join(random.choices(chars, k=13))

def ctex_hash(res_path: str) -> str:
    return hashlib.md5(res_path.encode()).hexdigest()

def write_import(png_path: str):
    res_path = "res://" + png_path.replace("\\", "/")
    basename = os.path.basename(png_path)
    h = ctex_hash(res_path)
    # Reuse existing UID if .import already exists
    import_path = png_path + ".import"
    uid = godot_uid()
    if os.path.exists(import_path):
        m = re.search(r'uid="(uid://[^"]+)"', open(import_path).read())
        if m:
            uid = m.group(1)
    content = IMPORT_TEMPLATE.format(
        uid=uid, basename=basename, hash=h,
        source_file=res_path)
    open(import_path, "w", newline="\n").write(content)


def find_cell_bounds(proj, min_gap=20, thresh_frac=0.01, min_size=50):
    thresh = float(proj.max()) * thresh_frac
    gaps=[]; in_gap=False; gs=0
    for i, v in enumerate(proj):
        if v <= thresh and not in_gap: in_gap=True; gs=i
        elif v > thresh and in_gap:
            if i - gs >= min_gap: gaps.append((gs, i-1))
            in_gap = False
    if in_gap and len(proj) - gs >= min_gap: gaps.append((gs, len(proj)-1))
    cells = [(gaps[i][1]+1, gaps[i+1][0]-1) for i in range(len(gaps)-1)]
    return [(a,b) for a,b in cells if b-a >= min_size]


def remove_green_bg(arr):
    if arr.shape[2] == 3:
        rgba = np.dstack([arr, np.full(arr.shape[:2], 255, dtype=np.uint8)])
    else:
        rgba = arr.copy()
    R, G, B = rgba[:,:,0], rgba[:,:,1], rgba[:,:,2]
    hard = (G.astype(int)-R.astype(int)>60) & (G.astype(int)-B.astype(int)>60) & (G>100)
    seed = np.zeros_like(hard, dtype=bool)
    seed[0,:]=hard[0,:]; seed[-1,:]=hard[-1,:]
    seed[:,0]=hard[:,0]; seed[:,-1]=hard[:,-1]
    labeled, _ = ndimage.label(hard)
    bg_labels = set(labeled[seed].flatten()) - {0}
    bg_mask = np.isin(labeled, list(bg_labels))
    edge_zone = ndimage.binary_dilation(bg_mask, iterations=2)
    greenness = np.clip((G.astype(float)-np.maximum(R,B).astype(float)-20)/80, 0, 1)
    alpha = rgba[:,:,3].astype(float)
    alpha[bg_mask] = 0.0
    alpha[edge_zone & ~bg_mask] = np.minimum(
        alpha[edge_zone & ~bg_mask], (1-greenness[edge_zone & ~bg_mask])*255)
    rgba[:,:,3] = alpha.astype(np.uint8)
    return rgba


def parse_order(txt_path):
    mapping = []
    for line in open(txt_path):
        m = re.search(r'res://(assets/[^\s]+\.png)', line)
        if m:
            mapping.append(m.group(1))
    return mapping


def main():
    targets = parse_order(ORDER)
    print(f"Order file: {len(targets)} targets")

    sheet = Image.open(SHEET).convert("RGB")
    arr = np.array(sheet)
    R, G, B = arr[:,:,0].astype(float), arr[:,:,1].astype(float), arr[:,:,2].astype(float)
    non_green = np.clip(np.maximum(R,B)-G+30, 0, None)

    col_cells = find_cell_bounds(non_green.sum(axis=0))
    row_cells = find_cell_bounds(non_green.sum(axis=1))
    print(f"Grid: {len(row_cells)}r x {len(col_cells)}c")

    idx = 0
    for r, (y0,y1) in enumerate(row_cells):
        for c, (x0,x1) in enumerate(col_cells):
            if idx >= len(targets):
                break

            cell = arr[y0:y1+1, x0:x1+1].copy()
            clean = remove_green_bg(cell)

            # Tight crop — skip empty cells WITHOUT consuming a target slot
            alpha = clean[:,:,3]
            ys, xs = np.where(alpha > 10)
            if len(ys) == 0:
                print(f"  [{r},{c}] empty, skipped (no target consumed)"); continue

            target = targets[idx]; idx += 1
            cropped = clean[ys.min():ys.max()+1, xs.min():xs.max()+1]

            # Resize to TARGET
            out = Image.fromarray(cropped, "RGBA").resize((TARGET,TARGET), Image.LANCZOS)

            os.makedirs(os.path.dirname(target), exist_ok=True)
            out.save(target, "PNG")
            write_import(target)
            print(f"  [{r},{c}] -> {target}")

    print(f"\nDone. {idx}/{len(targets)} tiles installed.")


if __name__ == "__main__":
    main()
