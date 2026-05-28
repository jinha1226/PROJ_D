#!/usr/bin/env python3
"""Regenerate .import files for all 50 replaced monster tiles."""
import os, re, hashlib, random, string, glob

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

MONSTER_PATHS = [
    "assets/tiles/individual/mon/humanoids/goblin.png",
    "assets/tiles/individual/mon/humanoids/hobgoblin.png",
    "assets/tiles/individual/mon/humanoids/kobold.png",
    "assets/tiles/individual/mon/undead/zombies/zombie_human.png",
    "assets/tiles/individual/mon/undead/skeletal_warrior.png",
    "assets/tiles/individual/mon/animals/adder.png",
    "assets/tiles/individual/mon/animals/wolf.png",
    "assets/tiles/individual/mon/animals/black_bear.png",
    "assets/tiles/individual/mon/animals/wolf_spider.png",
    "assets/tiles/individual/mon/animals/scorpion.png",
    "assets/tiles/individual/mon/animals/viper.png",
    "assets/tiles/individual/mon/animals/anaconda.png",
    "assets/tiles/individual/mon/humanoids/troll.png",
    "assets/tiles/individual/mon/humanoids/orcs/orc.png",
    "assets/tiles/individual/mon/humanoids/orcs/orc_warrior.png",
    "assets/tiles/individual/mon/humanoids/orcs/orc_apostle_wizard1.png",
    "assets/tiles/individual/mon/humanoids/orcs/orc_priest.png",
    "assets/tiles/individual/mon/humanoids/gnoll.png",
    "assets/tiles/individual/mon/humanoids/gnoll_sergeant.png",
    "assets/tiles/individual/mon/humanoids/gnoll_shaman.png",
    "assets/tiles/individual/mon/humanoids/ogre.png",
    "assets/tiles/individual/mon/humanoids/elves/deep_elf_archer.png",
    "assets/tiles/individual/mon/humanoids/elves/deep_elf_death_mage.png",
    "assets/tiles/individual/mon/humanoids/ogre_mage.png",
    "assets/tiles/individual/mon/undead/vampire.png",
    "assets/tiles/individual/mon/undead/vampire_knight.png",
    "assets/tiles/individual/mon/nonliving/gargoyle.png",
    "assets/tiles/individual/mon/humanoids/humans/vault_warden.png",
    "assets/tiles/individual/mon/undead/wraith.png",
    "assets/tiles/individual/mon/undead/shadow_wraith.png",
    "assets/tiles/individual/mon/undead/ghoul.png",
    "assets/tiles/individual/mon/undead/mummy.png",
    "assets/tiles/individual/mon/undead/lich.png",
    "assets/tiles/individual/mon/undead/ancient_lich.png",
    "assets/tiles/individual/mon/demons/crimson_imp.png",
    "assets/tiles/individual/mon/demons/red_devil.png",
    "assets/tiles/individual/mon/demons/balrug.png",
    "assets/tiles/individual/mon/demons/executioner.png",
    "assets/tiles/individual/mon/humanoids/giants/stone_giant.png",
    "assets/tiles/individual/mon/humanoids/giants/titan.png",
    "assets/tiles/individual/mon/undead/bone_dragon.png",
    "assets/tiles/individual/mon/animals/vampire_bat.png",
    "assets/tiles/individual/mon/dragons/swamp_dragon.png",
    "assets/tiles/individual/mon/dragons/ice_dragon.png",
    "assets/tiles/individual/mon/dragons/fire_dragon.png",
    "assets/tiles/individual/mon/humanoids/giants/cyclops.png",
    "assets/tiles/individual/mon/animals/bog_serpent.png",
    "assets/tiles/individual/mon/statues/glacial_sovereign.png",
    "assets/tiles/individual/mon/demons/ember_tyrant.png",
    "assets/tiles/individual/mon/dragons/golden_dragon.png",
]

def godot_uid():
    chars = string.ascii_lowercase + string.digits
    return "uid://" + "".join(random.choices(chars, k=13))

def write_import(png_path: str):
    res_path = "res://" + png_path.replace("\\", "/")
    basename = os.path.basename(png_path)
    h = hashlib.md5(res_path.encode()).hexdigest()
    import_path = png_path + ".import"
    uid = godot_uid()
    content = IMPORT_TEMPLATE.format(
        uid=uid, basename=basename, hash=h, source_file=res_path)
    open(import_path, "w", newline="\n").write(content)
    print(f"  {import_path}")

def main():
    for path in MONSTER_PATHS:
        if os.path.exists(path):
            write_import(path)
        else:
            print(f"  MISSING: {path}")
    print(f"\nDone. {len(MONSTER_PATHS)} .import files regenerated.")

if __name__ == "__main__":
    main()
