# PROJ_D Memory Index

## Current project (PocketCrawl, MIT, at repo root)
- [UI conventions](ui_conventions.md) — popup/dialog UX rules (GameDialog patterns)
- [Pending backlog](backlog_pocketcrawl.md) — 5개 미완료 버그/기능 (몬스터속도, 마법책, 미감정아이템, 계단, auto-walk)

## Feedback / collaboration
- [Godot CanvasLayer accept_event trap](feedback_godot_canvaslayer.md) — accept_event() is Control-only; from CanvasLayer use get_viewport().set_input_as_handled(). Silent parse-error trap.
- [Prefer prior Read output over re-reading](feedback_read_efficiency.md) — don't re-Read same file region in one session; cite earlier output, use Grep+narrow Read on big files; re-read only when Edit fails or file changed externally
- [Skip brainstorm when detailed spec exists](feedback_spec_over_brainstorm.md) — if project has a current detailed design doc, go directly to TodoWrite + implementation; no re-brainstorming, no separate plan doc
