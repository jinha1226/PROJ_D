# PROJ_D Memory Index

- [Project primary goal](project_goal.md) — faithful DCSS mobile port + Pixel Dungeon UX; guides every scope call
- [DCSS port progress](dcss_port_progress.md) — what's ported (map/vaults/monsters/species) vs pending (skills/items/spells/AI), license decision, source clone path
- [Next-phase direction](project_direction.md) — 2026-04-21 decision to prefer village+companions over full 26-god parity; companion-AI risk mitigations pre-agreed
- [DCSS port backlog](dcss_port_backlog.md) — checklist of remaining DCSS systems; next-session top-of-stack: finish UI upgrade tasks 4-8 (Skills ACTIVE split → Bag/Magic/Map cards → popup chrome). Gods deferred.
- [UI conventions](ui_conventions.md) — popup/dialog UX rules enforced since 2026-04-21 session
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — accept_event() is Control-only; from CanvasLayer use get_viewport().set_input_as_handled(). Silent parse-error trap.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — don't re-Read same file region in one session; cite earlier output, use Grep+narrow Read on big files; re-read only when Edit fails or file changed externally
