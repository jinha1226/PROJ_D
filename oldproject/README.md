# Stone & Depth

Godot 4.6 mobile-first action RPG using Universal LPC spritesheets.

## Play (web)

Deployed to GitHub Pages on every push to `main`:

    https://<user>.github.io/<repo>/

Desktop + mobile browsers supported. On first launch, tap/click once to unlock audio (browser gesture requirement).

## Dev setup

1. Install Godot 4.6.2 stable.
2. Open `project.godot`, let the editor import assets (first import is slow — ~5k ULPC PNGs).
3. F5 to run.

## Assets

ULPC sprites under `assets/ulpc/` are a mirrored subset of the [Universal-LPC-Spritesheet-Character-Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator). The raw generator repo is git-ignored; only the game-facing mirror is committed. See `CREDITS_LPC.md` for per-asset attribution and licenses.

## CI

`.github/workflows/deploy-web.yml` pins Godot 4.6.2, runs `--import` twice, exports the `Web` preset (single-threaded — GitHub Pages can't set COOP/COEP headers), and deploys via `actions/deploy-pages@v4`.
