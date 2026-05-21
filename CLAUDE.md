# PocketCrawl

## Project Overview
PocketCrawl is a mobile-leaning dungeon crawler — DCSS-flavored build identity and consumable tension, intentionally simplified for compact UI. Reference inspirations: DCSS first, Pixel Dungeon for pacing/UX. Targeted as a commercial mobile release (Android first).

**Status (post-reboot, 2026-04-25)**: current code is original GDScript — DCSS source/data/tile-tree dependencies live only in `oldproject/` (read-only archive). Active code references DCSS in comments only (formula citations / inspiration), no translated `.cc` files.

**Non-goals**: full DCSS clone, gear-escalator Pixel Dungeon clone, content-complete traditional roguelike.

## License & IP
- Code: original GDScript, MIT-friendly. Commercial release viable.
- Tiles: DCSS rltiles, **CC0** (public domain) per `oldproject/crawl/LICENSE` line 24-28 + `rltiles/license.txt`. Commercial use OK; attribution recommended (not legally required) — add to in-game credits before ship.
- **Firewall**: do not import code/data files from `oldproject/` into active scripts. Numerical balance data borrowed from DCSS is fact-data (not copyrightable in itself); translated `.cc` logic would taint with GPL.
- Risk areas to verify before ship: any monster/god/unique name copied verbatim from DCSS may be a trademark concern even when stats are not. Spot-check `resources/monsters/` and `resources/spells/` for distinctive names.
- Final ship: legal review recommended.

## Tech Stack
- Engine: Godot 4.6
- Language: GDScript
- Data: `.tres`, `.json`, scene/script-driven runtime data
- Target: mobile-first (Android), desktop for development/testing

## Active Runtime
- Open `D:\PROJ_D\` in Godot editor → wait for import → F5 smoke-test the start flow.
- Smoke path: MainMenu → New Run → RaceSelect → JobSelect → walk, bump, auto-walk, read scroll, descend, ascend, die.
- Headless/scripted checks where available; record explicitly if runtime cannot be verified in-session.

## Directory Map
```
D:\PROJ_D\scenes        scene entrypoints, HUD, menus, dialogs
D:\PROJ_D\scripts       gameplay logic, entities, systems, UI, dungeon gen
D:\PROJ_D\resources     classes, monsters, items, spells, races (.tres)
D:\PROJ_D\assets        tiles, icons, art (CC0 / own work)
D:\PROJ_D\docs          design notes, audits, guides, checklists, templates
D:\PROJ_D\oldproject    READ-ONLY archive (pre-reboot project + DCSS clone)
D:\PROJ_D\archive       (forthcoming) ship-time archives
```

## Cross-Cutting Rules
1. Identify task type before editing: refactor / balance / feature / bugfix.
2. Save/load schema changes require migration plan + `save_version` bump. **C1 from audit shows current schema is incomplete** — see audit report.
3. Equip/unequip slots must use `set_equipped_<slot>("")` to trigger affix removal — never bare `equipped_<slot>_id = ""`. armor/shield slots have known asymmetry (C2).
4. Faith/Essence/drops/skills are high-volatility — keep player-facing text, mechanics, and balance handoff docs in sync when touching.
5. UI must NOT directly mutate system state or call `TurnManager.end_player_turn()`. Route through Player/system APIs that own turn cost.
6. Game.gd is god-object (3112 lines as of audit). New work must extract, not extend. See module index for designated targets.
7. Follow `docs/doc_update_protocol.md` whenever design or system rules change.
8. Documentation is part of implementation, not afterthought — fixes for repeated confusion get promoted into CLAUDE.md or balance docs, not rediscovered each session.

## Forbidden / Caution Areas
- **Do not import from `oldproject/`** into active scripts/resources/assets — GPL firewall.
- Do not extend `Game.gd`, `CombatSystem.gd`, `MagicSystem.gd` with new logic branches when extraction into `scripts/systems/` is possible.
- Do not silently change save-state shape (see C1 / Rule 2).
- Do not mix pure refactor with balance changes unless task explicitly calls for both.
- Do not add `static var X = Engine.get_main_loop()...get_node_or_null("/root/X")` — autoload names are auto-global in GDScript 4 (audit pattern P4, 19 files affected).
- Do not assume `dcss_port_*` memories or `archive/oldproject_*/` describe current code — those are pre-reboot.

## Tribal Knowledge (from 2026-05-05 audit)
- **Critical 4 / High 9 / Medium 11 / Low 5** issues catalogued in `docs/audits/2026-05-05-codebase-audit.md`. Phase 0 → 1 must complete before deeper structural work — Critical regressions otherwise compound.
- 7 recurring debt patterns: Game.gd god-object · slot equip asymmetry · dead data keys · save schema gaps · UI→system reverse calls · log/effect timing mismatch · static-var autoload shadowing.
- Faith data has 8 keys defined but unread by code (`shield_block_bonus`, XP mults, agility/tool effectiveness, detect_range_mod, etc.) — advertised bonuses don't fire. Either wire up or remove.
- Inventory tab filter omits shield/wand/throwing/essence — long-standing user complaint, root cause identified (`BagDialog.gd:69-71`).
- Corpse system was pointing into `oldproject/...UNUSED/`. Fix moves tile load to repo-internal path (Phase 0).
- Past sessions trusted `CLAUDE.md` over reading code, missing the corpse oldproject dependency for multiple sessions. Default: when behavior contradicts docs, read code first.

## Verification Expectations
- Preferred: actual Godot runtime/scene verification via F5.
- Fallback: explicit runtime checklist + note of what could not be verified.
- High-priority post-change flows: start (race→class→run), first boss → shrine/faith choice, essence acquisition/replacement, combat + kill rewards, save/load round-trip, branch entry+exit (esp. branch 1F up — see C4).

## Module Index
- `scripts/main/CLAUDE.md` — Game.gd god-object decomposition plan, branch lifecycle, save migration
- `scripts/systems/CLAUDE.md` — CombatSystem/MagicSystem/FaithSystem rules, dead-data audit, AOE helper plan
- `scripts/core/CLAUDE.md` — TurnManager, SaveManager (C1 schema gap), GameManager
- `scripts/ui/CLAUDE.md` — UI ↔ system boundary rules, BagDialog filter (H3), ItemDetailDialog stale-index (H4)
- `scripts/dungeon/CLAUDE.md` — DungeonMap rendering perf, FOV, MapGen
- `docs/balance/...` — balance handoff docs (still authoritative for balance work)
- `docs/refactoring_todo.md` — refactor progress, Phase 0~4 priorities

## Reference Docs
- `docs/audits/2026-05-05-codebase-audit.md` — full audit (Critical 4 / High 9 / Medium 11 / Low 5 + patterns)
- `docs/refactoring_todo.md`
- `docs/doc_update_protocol.md`
- `docs/balance/claude_code_balance_handoff.md`
- `docs/balance/claude_code_drop_table_handoff.md`
- `docs/balance/claude_code_essence_and_resistance_handoff.md`
- `docs/balance/claude_code_faith_and_essence_handoff.md`
- `docs/balance/claude_code_first_boss_shrine_faith_flow.md`
- `docs/balance/claude_code_ui_help_and_bestiary_handoff.md`
- `docs/clean_room_reboot_guide.md` — historical, why oldproject/ exists
- `docs/decision_log.md`
- `docs/guides/` — workspace methodology guides (delegation, context, harness, skills)
- `docs/checklists/AI_READY_CODEBASE_SCORECARD.md` — periodic self-audit
- `docs/templates/GODOT_GAME_CONTEXT_TEMPLATE.md` — module CLAUDE.md template

## Where to look first (new session)
1. Read this file + `docs/audits/2026-05-05-codebase-audit.md` summary section.
2. Memory baseline: `audit_2026_05_05_baseline.md` (auto-loaded).
3. `git log --oneline -20` for recent landings.
4. Check `docs/refactoring_todo.md` for current Phase position.
5. F5 smoke-test before structural work.

## Current Working Truths
- Active progression: XL 20, skill max 9. Long-term balance reference still cites DCSS 27-scale internally where helpful.
- Active skill model: 9 visible skills (`weapon_mastery`, `archery`, `tactics`, `defense`, `magery`, `stealth`, `lockpicking`, `tracking`, `survival`) plus hidden familiarity sub-skills stored in `hidden_skills`.
- Current focus before context reset: starting shop, essence loop, and turn budget are being implemented/tested. Keep authored large maps postponed until these core loops are verified on the current small maps.
- Recent skill UI state: `SkillsDialog` and `StatusDialog` intentionally show visible skills plus hidden familiarity rows for debugging actual action-driven XP gain. This is temporary verification UI, not final mobile presentation.
- Map art/design handoff lives in `docs/map_art_design.md`: zone-by-zone sub-regions, prop/tile choices, and implementation notes for later authored map dressing.
- Next verification pass: new run enters/exits starting shop, essence pickup/equip/effect/save-load works, turn budget decreases on move/wait/attack/cast/item/stairs, and hidden XP rises for weapon/ranged/magic/defense actions.
- Resists simplified to 4 types: fire / cold / poison / will. Do not re-expand without explicit decision.
- Map size: 32×36 (compressed for mobile readability vs Pixel Dungeon ~larger and DCSS ~much larger).
- Faith and Essence are parallel build axes; `faith_id == ""` is migration-state only after `first_shrine_choice_done == true`.
- DCSS reference clone in `oldproject/crawl/` for cross-checking formulas — never import into active code.
