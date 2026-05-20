# PROJ_D Memory Index

PocketCrawl is a Godot/GDScript mobile-leaning roguelike. **Post-reboot (2026-04-25), clean of GPL DCSS sources** — current code is original, data borrows DCSS numerical balance only, tiles are CC0. Commercial release path open.

## Read first in new session
- [Next session priorities](next_session_priorities.md) — Phase 1 ✅ done (commit e476e94f, 2026-05-06). Now on Phase 2 (user-pain: H3 inventory tab → H4 → H5).
- [Audit baseline 2026-05-05](audit_2026_05_05_baseline.md) — Critical 4 closed; 9 High / 11 Medium / 5 Low remain. 7 recurring debt patterns.
- [Current state snapshot](pocketcrawl_state.md) — built systems, architecture decisions, file map. Predates 2026-05-05 audit.
- [Pending backlog (4-27)](backlog_pocketcrawl.md) — task list with header note pointing to audit baseline.

## Decision log
- [Clean-room reboot decision (2026-04-25)](reboot_decision.md) — historical record of why oldproject/ exists and what current code must avoid.

## Collaboration / feedback
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — Use `get_viewport().set_input_as_handled()` from CanvasLayer scripts; `accept_event()` is Control-only and produces silent parse error.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — In long sessions, cite earlier reads instead of re-opening; use Grep+narrow Read on big files.
- [Skip brainstorm when detailed spec exists](feedback_spec_over_brainstorm.md) — When project has current detailed spec, go directly to TodoWrite + implementation. Exception: if spec is stale/contradicts code (as triggered 2026-05-05 audit), fall back to clarifying questions.
- [Keep already-built systems dormant rather than delete](feedback_keep_built_systems.md) — When user says "remove X", default to removing the gameplay trigger only and leaving implementation code as dormant. Mass deletion requires explicit confirmation.

## Archived (do not consult unless researching history)
- `archive/dcss_port_progress.md`, `archive/dcss_port_backlog.md` — pre-reboot DCSS port state, describes oldproject/ not current code
- `archive/project_direction.md`, `archive/project_goal.md` — pre-reboot "faithful DCSS port first" direction, superseded by reboot decision

## Quick facts (current as of 2026-05-05)
- License: PROJ_D code original, MIT-friendly. Tiles CC0 (DCSS rltiles, verified). Commercial release viable.
- Active runtime: Godot 4.6 editor on PROJ_D root.
- DCSS reference clone lives in `oldproject/crawl/` (firewall: do not import code/data from there into active scripts).
- Full audit report: `D:/PROJ_D/docs/audits/2026-05-05-codebase-audit.md`
