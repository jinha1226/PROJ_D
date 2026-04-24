# PROJ_D Memory Index

## Current project (PocketCrawl, MIT, at repo root)
- [UI conventions](ui_conventions.md) — popup/dialog UX rules (GameDialog patterns)
- [Pending backlog](backlog_pocketcrawl.md) — Zone expansion ✅완료 (branch pushed) + 기존 버그 5개
- [Zone expansion spec](../../mnt/d/PROJ_D/docs/superpowers/specs/2026-04-23-zone-monster-expansion-design.md) — 8존×3층+보스, 38몬스터, 11종족, CA맵, 환경피해 — **모두 구현 완료**

## Feedback / collaboration
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — accept_event() is Control-only; from CanvasLayer use get_viewport().set_input_as_handled(). Silent parse-error trap.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — don't re-Read same file region in one session; cite earlier output, use Grep+narrow Read on big files; re-read only when Edit fails or file changed externally
- [Skip brainstorm when detailed spec exists](feedback_spec_over_brainstorm.md) — if project has a current detailed design doc, go directly to TodoWrite + implementation; no re-brainstorming, no separate plan doc
