# AI-Ready Codebase Scorecard

## Purpose
Apply this scorecard to any code project to measure how prepared its codebase and documentation are for AI-assisted development. The score predicts how reliably an agent (Claude, Codex) can do real work in the project without getting lost.

Total: **100 points**, split across 10 categories. Each item is observable — score it from the repo state, not from intent.

## How to Score
For each item, choose one:
- **Yes (full points)** — clearly satisfied, would survive a fresh agent's first session
- **Partial (half points, round down)** — present but incomplete or stale
- **No (0 points)** — missing or actively misleading

Sum the category points. Total interprets per the bands at the bottom.

---

## 1. Navigation (15 points)

| Pts | Criterion |
|---|---|
| 5 | Root `CLAUDE.md` exists and lists every module's `CLAUDE.md` (the index) |
| 5 | A fresh agent can locate any subsystem (auth, DB, frontend route, etc.) in **1~2 file reads** starting from root `CLAUDE.md` |
| 5 | Cross-references between docs use real, valid file paths (no broken links, no "see the wiki" without specifying which wiki) |

## 2. Context Document Quality (8 points)

| Pts | Criterion |
|---|---|
| 3 | Root `CLAUDE.md` is **100~200 lines** (not 50, not 500) |
| 3 | Module `CLAUDE.md` files are **25~35 lines / ~1k tokens** each |
| 2 | Every actionable rule has a concrete command, path, or decision rule (no abstract advice) |

## 3. Tribal Knowledge Capture (15 points)

| Pts | Criterion |
|---|---|
| 5 | "Non-obvious patterns" / "gotchas" sections exist in module CLAUDE.md and contain real entries (not placeholders) |
| 5 | At least one "we tried X, it failed because Y, do Z instead" note exists somewhere in the doc set |
| 5 | Deprecated paths, legacy code, and "do not edit" zones are explicitly marked, not just implied |

## 4. Freshness (10 points)

| Pts | Criterion |
|---|---|
| 4 | Doc set was updated within the last 10 substantial commits to the project |
| 3 | A hook or process auto-prompts CLAUDE.md updates after relevant changes (or a written habit exists) |
| 3 | No CLAUDE.md contradicts the current code's actual behavior (spot-check 3 random claims) |

## 5. Module Decomposition (12 points)

| Pts | Criterion |
|---|---|
| 4 | Per-module `CLAUDE.md` files exist for all major modules (not just root) |
| 4 | Module boundaries in docs match actual code boundaries (no doc covering 5 modules in one file) |
| 4 | All 5 questions (What/How/Non-Obvious/Navigation/Tribal) are answered in each module CLAUDE.md |

## 6. Verification Commands (10 points)

| Pts | Criterion |
|---|---|
| 4 | Root `CLAUDE.md` lists explicit compile/test/lint commands |
| 3 | Commands are current (running them succeeds on a clean checkout) |
| 3 | Each module CLAUDE.md notes its own verification command if different from project default |

## 7. Active Runtime Clarity (8 points)

| Pts | Criterion |
|---|---|
| 4 | There is exactly **one** documented "how to run this project" command per role (backend, frontend, worker) |
| 2 | Legacy / inactive code paths are clearly marked as not the active runtime |
| 2 | Migration / transition states (in-progress refactors) are noted with status |

## 8. Forbidden Zones (7 points)

| Pts | Criterion |
|---|---|
| 3 | Explicit "do not" list exists in root `CLAUDE.md` (security, data sensitivity, legacy paths) |
| 2 | `settings.json` permissions has a deny list for destructive operations |
| 2 | Forbidden zones include the **why**, not just the rule (so agents can reason about edge cases) |

## 9. Reference Index (5 points)

| Pts | Criterion |
|---|---|
| 2 | `docs/architecture.md` (or equivalent) exists and is current |
| 1 | `docs/conventions.md` exists |
| 1 | `docs/handoff.md` or recent handoff notes exist |
| 1 | `docs/runtime_checklist.md` exists for systems-heavy projects (skip for trivial projects) |

## 10. Onboarding Speed (10 points)

A fresh agent given **only** the root `CLAUDE.md` and 5 minutes should be able to answer:

| Pts | Question the agent must answer |
|---|---|
| 3 | "What does this project do?" (1 paragraph) |
| 3 | "How do I run it?" (exact command) |
| 2 | "What should I never do here?" (at least 2 specific items) |
| 2 | "Where is the auth / DB / API layer?" (correct module path) |

If you cannot test this directly, simulate by reading only the root file yourself and self-scoring.

---

## Total Interpretation

| Score | Stage | Meaning |
|---|---|---|
| **80~100** | AI-Native ready | Agents work reliably with minimal hand-holding. Maintain freshness. |
| **60~79** | AI-Maximalist friendly | Agents can do most tasks; specific gaps cause occasional confusion. Fix targeted gaps. |
| **40~59** | AI-Aided level | Agents need significant per-session re-explaining. Most projects sit here. Restructure priority categories. |
| **0~39** | Not AI-ready | Agents will get lost frequently and produce unreliable work. Bootstrap from `TEMPLATES/CODEBASE_CONTEXT_TEMPLATE.md` first. |

The 4 stages map to the AI-Native 4-stage framework (Aware / Aided / Maximalist / Native). A codebase that scores 80+ does not automatically make its developer Native — but a codebase under 40 actively prevents the developer from operating Maximalist-or-above no matter how skilled they are.

---

## Sample Score Sheet

```
Project: <name>
Date: <YYYY-MM-DD>

1. Navigation          : __ / 15
2. Context Doc Quality : __ /  8
3. Tribal Knowledge    : __ / 15
4. Freshness           : __ / 10
5. Module Decomposition: __ / 12
6. Verification Cmds   : __ / 10
7. Active Runtime      : __ /  8
8. Forbidden Zones     : __ /  7
9. Reference Index     : __ /  5
10. Onboarding Speed   : __ / 10
                         ----
Total                  : __ / 100

Stage: <Aware / Aided / Maximalist / Native>

Top 3 lowest-scoring categories (priority for next iteration):
1.
2.
3.
```

---

## Reapply Cadence

- **First time**: when picking up an unfamiliar project, or before a major AI-driven refactor
- **Repeat**: after every significant doc set update, and roughly every 3 months on active projects
- **After methodology changes**: when this project (`AI_WORKFLOW`) updates the master guides or the 5-question framework, re-score active projects against the new bar

## Related Docs
- `MASTER_GUIDES/AI_AGENT_MASTER_GUIDE.md` — general principles
- `MASTER_GUIDES/HARNESS_AND_HOOKS_GUIDE.md` — hooks for items 4 and 8
- `TEMPLATES/CODEBASE_CONTEXT_TEMPLATE.md` — what each scored item should look like when done well
