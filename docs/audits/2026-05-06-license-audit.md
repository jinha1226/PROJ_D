---
date: 2026-05-06
auditor: claude-code session
scope: PROJ_D pre-release license audit
status: in-progress
---

# License Audit — 2026-05-06

## Summary

PROJ_D is **likely shippable as-is** under MIT + DCSS-tiles (CC0) +
fonts (OFL/MIT). No active code path imports LPC / CC-BY-SA / GPL
assets. Risk areas: a portion of `assets/tiles/individual/` PNGs that
do not name-match DCSS RLTiles (origin unverified), and unreferenced
work-in-progress directories that bloat the repo.

## Code

| Component | License | Notes |
|---|---|---|
| `scripts/`, `scenes/`, `resources/` | MIT (`LICENSE`) | Copyright 2026 jinha1226 |
| Godot Engine runtime | MIT | Bundled by export |

## Fonts

| File | License | Source | Status |
|---|---|---|---|
| `assets/fonts/Pretendard-Regular.otf` | OFL 1.1 | github.com/orioncactus/pretendard | ✓ commercial-safe |
| `assets/fonts/Galmuri11.ttf` | MIT + OFL | github.com/quiple/galmuri | ✓ commercial-safe |
| `assets/fonts/Galmuri9.ttf` | MIT + OFL | (same) | ✓ commercial-safe |
| `assets/fonts/Galmuri7.ttf` | MIT + OFL | (same) | ✓ commercial-safe |
| `assets/fonts/Neodgm.ttf` | OFL 1.1 | github.com/neodgm/neodgm | ✓ commercial-safe |

`assets/fonts/korean_theme.tres` is the legacy Pretendard-only theme;
no longer referenced from `project.godot` (replaced by
`res://assets/theme.tres` 2026-05-06). Safe to delete.

## Tiles & sprites

`assets/tiles/individual/` — primary sprite tree.

- **Verified DCSS RLTiles (CC0)**: at minimum `player/body/leather_armour.png`,
  `player/body/chainmail.png`, `player/base/human_m.png` match by md5
  against `oldproject/crawl/crawl-ref/source/rltiles/`. DCSS LICENSE
  declares "most of tiles" are public domain / CC0.
- **Unmatched PNGs**: a portion of `assets/tiles/individual/` filenames
  do not appear in `oldproject/crawl/`. These could be: locally
  authored, sourced from `assets/generated_tileset_v*` work, or
  recolours / variants of DCSS tiles. Provenance unverified. See
  `unmatched_count` in audit-run output.
- **Custom UI**: `assets/ui/title/pocketcrawl_title.png` (1400×320
  RGBA) — appears to be project-specific title art. Origin unverified;
  if AI-generated or commissioned, document attribution.

### Recommendation
Run `tools/asset_provenance_scan.py` (TODO write) that, for each PNG
under `assets/tiles/individual/`, computes md5 and checks against:

1. DCSS rltiles (under `oldproject/crawl/`) — CC0
2. ULPC mirror (under `oldproject/Universal-LPC-Spritesheet-Character-Generator/`) — would flag CC-BY-SA / GPL contamination
3. Document any "neither" group as locally authored.

Result table goes in `docs/audits/asset_provenance.md`.

## D&D SRD references

`CREDITS.md` already documents SRD 5.1 references (CC-BY 4.0). Specific
monster/spell IDs derived from SRD are listed. Attribution requirement
satisfied.

## oldproject/

`oldproject/` is an archived previous-version snapshot. Contains:

- `Universal-LPC-Spritesheet-Character-Generator/` — CC-BY-SA 3.0 / GPL
  3.0 / CC-BY 4.0 / OGA-BY 3.0 (mixed). **Triggers share-alike if any
  derivative ships.**
- `crawl/crawl-ref/` — DCSS source mirror, GPL 2+ for code, CC0 for
  most tiles.
- `dcss-0.34.1-win32-tiles/` — upstream DCSS release.
- `assets/`, `scripts/`, `scenes/` — old PROJ_D version code.

### Code-side dependency check
- `grep -rn "oldproject" scripts/ scenes/ resources/ project.godot` →
  **0 matches** in active paths. ✓
- `grep -rn "ulpc\|Universal-LPC"` in active paths → **0 matches**. ✓

### Recommendation
**Archive outside the git repo**. Move `oldproject/` to a sibling
folder or separate repo (e.g., `~/PROJ_D_oldproject/`). Reasons:

- Removes risk of accidental future imports of LPC assets.
- Reduces clone size meaningfully (estimated several GB given 5k+ ULPC
  PNGs + crawl source).
- Eliminates need for a CREDITS_LPC at PROJ_D root.

Add a `docs/legacy_map.md` entry pointing to the archive's new
location for historical reference.

## Generated tileset directories

`assets/generated_tileset_v1/`, `assets/generated_tileset_v2/` — work-
in-progress AI-generated or template assets. **Not referenced** from
any code (`grep -rn "generated_tileset"` → 0 matches). Likely safe to
delete or move to `docs/scratch/`. If AI-generated content is intended
for later use, add a SOURCE.md noting the generator/prompt provenance.

## Sounds

No sounds in repo as of 2026-05-06 — N/A.

## Outstanding action items

| # | Action | Priority |
|---|---|---|
| 1 | Run full md5 provenance scan on `assets/tiles/individual/` | HIGH |
| 2 | Document any non-DCSS / non-LPC tiles' origin in `docs/audits/asset_provenance.md` | HIGH |
| 3 | Document `pocketcrawl_title.png` origin | MEDIUM |
| 4 | Move `oldproject/` outside git repo | MEDIUM |
| 5 | Delete or archive `assets/generated_tileset_v*/` | LOW |
| 6 | Delete legacy `assets/fonts/korean_theme.tres` (now unused) | LOW |

After 1-3 complete and any non-CC0 finds are documented or replaced,
project is clear for commercial release under MIT.
