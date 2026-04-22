# Roguelike (working title)

Mobile roguelike in Godot 4 — portrait-orientation, touch-first, inspired
by the traditional roguelike genre (Pixel Dungeon / classic Crawl).

**Status**: pre-alpha. Project scaffolding set up; MVP in progress. See
[`docs/clean_room_reboot_guide.md`](docs/clean_room_reboot_guide.md) for the
4-week build plan.

## Project layout

```
/                         — this project (MIT, new clean-room start)
├── assets/tiles/         — CC0 tile art from DCSS RLTiles
├── scripts/              — GDScript (core / dungeon / entities / systems / ui / fx)
├── scenes/               — Godot scenes
├── resources/            — MonsterData / ItemData / ClassData .tres
├── docs/
│   └── clean_room_reboot_guide.md  — architecture, system specs, build order
└── oldproject/           — archived DCSS mobile port (GPL v2+), kept for
                            reference and continued fan distribution
```

## License

This project (everything under `/` except `oldproject/`) is MIT-licensed.
Tile art is CC0. See `LICENSE`.

`oldproject/` is GPL v2+ (DCSS-derived). Its own `oldproject/README.md`
documents its terms.

## Getting started

1. Install Godot 4.3+ (4.4 / 4.5 fine).
2. Open the project folder in Godot.
3. Run the main scene (F5). (Currently not much — we're at scaffold.)

## Roadmap

- Week 1: core loop (grid move, FOV, one monster, inventory, stairs)
- Week 2: content (20 monsters, 15 items, 3 classes, save/load)
- Week 3: polish (tile art integration, sound, mobile UI)
- Week 4: release (Android APK / itch.io upload / donation links)

Detailed specs per system in
[`docs/clean_room_reboot_guide.md`](docs/clean_room_reboot_guide.md).
