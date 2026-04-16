"""LPC 시트에서 아이템 아이콘 추출.

각 장비 PNG 의 walk down 프레임(col 0 row 2)에서 아이템이 있는 영역을 crop
하고 32×32 캔버스로 리사이즈해 assets/sprites/items/*.png 에 덮어쓴다.

실행:
    python3 tools/build_item_icons.py
"""

from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ULPC = ROOT / "assets" / "ulpc"
OUT = ROOT / "assets" / "sprites" / "items"
OUT.mkdir(parents=True, exist_ok=True)

# item_id -> (relative PNG path, default variant filename)
# walk 시트의 col 0 row 2 (DOWN) 에서 bounding box 로 crop.
EQUIP_SOURCES = {
    "longsword":       "weapon/sword/longsword/walk/longsword.png",
    "dagger":          "weapon/sword/dagger/walk/dagger.png",
    "short_sword":     "weapon/sword/arming/universal/fg/walk/iron.png",
    "greatsword":      None,  # ULPC 없음 — 절차 생성 유지
    "long_bow":        None,  # walk_128 별도 — 아이콘 따로
    "crossbow":        None,
    "fire_staff":      None,
    "ice_staff":       None,
    "lightning_staff": None,
    "iron_shield":     "shield/crusader/fg/male/walk/crusader.png",
    "leather_chest":   None,
    "leather_helm":    None,
    "leather_boots":   None,
    "leather_gloves":  None,
    "leather_legs":    None,
    "plate_chest":     None,
    "plate_helm":      None,
    "plate_boots":     None,
    "plate_gloves":    None,
    "plate_legs":      None,
}

# 각 시트에서 DOWN 프레임 col 0 의 64×64 영역. 거기서 아이템만 bounding box crop.
FRAME_SIZE = 64


def extract_icon(src_rel: str, out_name: str) -> bool:
    src = ULPC / src_rel
    if not src.exists():
        print(f"  skip missing: {src_rel}")
        return False
    im = Image.open(src).convert("RGBA")
    # DOWN 프레임 = row 2, col 0 (ULPC 표준: N/W/S/E 순서)
    if im.height < FRAME_SIZE * 3:
        print(f"  skip short sheet: {src_rel}")
        return False
    frame = im.crop((0, FRAME_SIZE * 2, FRAME_SIZE, FRAME_SIZE * 3))
    bbox = frame.getbbox()
    if bbox is None:
        # down 이 비어 있으면 left (row 1) 시도.
        frame = im.crop((0, FRAME_SIZE, FRAME_SIZE, FRAME_SIZE * 2))
        bbox = frame.getbbox()
        if bbox is None:
            print(f"  empty frame: {src_rel}")
            return False
    cropped = frame.crop(bbox)
    # 32×32 캔버스에 비율 유지해 맞추기
    target = 32
    w, h = cropped.size
    s = min(target / w, target / h)
    new_w = max(1, int(w * s))
    new_h = max(1, int(h * s))
    resized = cropped.resize((new_w, new_h), Image.NEAREST)
    canvas = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    canvas.paste(resized, ((target - new_w) // 2, (target - new_h) // 2), resized)
    out_path = OUT / f"{out_name}.png"
    canvas.save(out_path)
    print(f"  wrote {out_path.relative_to(ROOT)}")
    return True


def main() -> None:
    ok = 0
    for item_id, src in EQUIP_SOURCES.items():
        if src is None:
            continue
        if extract_icon(src, item_id):
            ok += 1
    print(f"\n총 {ok}개 아이콘 추출")


if __name__ == "__main__":
    main()
