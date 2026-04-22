# PROJ_D Memory Index

## Current project (PocketCrawl, MIT, at repo root)
- [PocketCrawl current state](pocketcrawl_state.md) — **READ FIRST** — current systems (core loop / unlock flow / 5 races / 5 classes / 18 items / 18 monsters / 6 spells / skills / statuses / CI / paper-doll), pending roadmap, architecture decisions, gotchas
- [Clean-room reboot decision](reboot_decision.md) — PROJ_D = old GPL DCSS port (archived in oldproject/); PocketCrawl = new MIT project at root. Legal firewall + what must NOT carry over

## Historical (pre-reboot, apply to oldproject/ only)
- [Project primary goal](project_goal.md) — **pre-reboot goal** — faithful DCSS port + PD UX. Superseded for PocketCrawl by the reboot guide
- [DCSS port progress](dcss_port_progress.md) — oldproject/ port status (map/vaults/monsters done; skills/items/spells/AI pending)
- [Next-phase direction](project_direction.md) — 2026-04-21 oldproject decision (village + companions). Not applicable to PocketCrawl
- [DCSS port backlog](dcss_port_backlog.md) — oldproject/ remaining systems checklist
- [UI conventions](ui_conventions.md) — popup/dialog UX rules — still apply to PocketCrawl (GameDialog reuses same patterns)

## Feedback / collaboration
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — accept_event() is Control-only; from CanvasLayer use get_viewport().set_input_as_handled(). Silent parse-error trap.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — don't re-Read same file region in one session; cite earlier output, use Grep+narrow Read on big files; re-read only when Edit fails or file changed externally
- [Skip brainstorm when detailed spec exists](feedback_spec_over_brainstorm.md) — if project has a current detailed design doc, go directly to TodoWrite + implementation; no re-brainstorming, no separate plan doc
