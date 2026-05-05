# PROJ_D Memory Index

PocketCrawl is a Godot/GDScript mobile-leaning roguelike. **Post-reboot (2026-04-25), clean of GPL DCSS sources** — current code is original, data borrows DCSS numerical balance only, tiles are CC0. Commercial release path open.

## Read first in new session
- [Next session priorities](next_session_priorities.md) — roadmap after 2026-05-05 curation: Phase 1 Critical 4 → Phase 2 → audits → Phase 3/4. Phase 0 (corpse) already done.
- [Audit baseline 2026-05-05](audit_2026_05_05_baseline.md) — 4 Critical / 9 High issues + 7 recurring debt patterns.
- [Current state snapshot](pocketcrawl_state.md) — built systems, architecture decisions, file map. Predates 2026-05-05 audit.
- [Pending backlog (4-27)](backlog_pocketcrawl.md) — task list with header note pointing to audit baseline.

## Decision log
- [Clean-room reboot decision (2026-04-25)](reboot_decision.md) — historical record of why oldproject/ exists and what current code must avoid.

## Collaboration / feedback
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — Use `get_viewport().set_input_as_handled()` from CanvasLayer scripts; `accept_event()` is Control-only and produces silent parse error.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — In long sessions, cite earlier reads instead of re-opening; use Grep+narrow Read on big files.
- [Skip brainstorm when detailed spec exists](feedback_spec_over_brainstorm.md) — When project has current detailed spec, go directly to TodoWrite + implementation. Exception: if spec is stale/contradicts code (as triggered 2026-05-05 audit), fall back to clarifying questions.

## Archived (do not consult unless researching history)
- `archive/dcss_port_progress.md`, `archive/dcss_port_backlog.md` — pre-reboot DCSS port state, describes oldproject/ not current code
- `archive/project_direction.md`, `archive/project_goal.md` — pre-reboot "faithful DCSS port first" direction, superseded by reboot decision

## Quick facts (current as of 2026-05-05)
- License: PROJ_D code original, MIT-friendly. Tiles CC0 (DCSS rltiles, verified). Commercial release viable.
- Active runtime: Godot 4.6 editor on PROJ_D root.
- DCSS reference clone lives in `oldproject/crawl/` (firewall: do not import code/data from there into active scripts).
- Full audit report: `D:/PROJ_D/docs/audits/2026-05-05-codebase-audit.md`
