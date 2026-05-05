# Session Inefficiency Audit

**Use:** Run at the END of every coding-agent session (5 minutes). Score yourself, log violations, carry actions into the next session.

**Scope:** General — applies to any Claude/Codex coding session. Project-specific items live in the appendix at the bottom.

**How to score:** Each item is PASS / FAIL / N/A. Target ≥ 80% PASS across applicable items. Any FAIL must produce a one-line action for the next session.

---

## Part 1. Token & Cost Efficiency (quantitative)

Run `/cost` (Claude Code) or equivalent before closing the session. Paste the numbers into your log.

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| 1.1 | Context window used at session end | < 70% | Split next session earlier; move stable info to memory/CLAUDE.md |
| 1.2 | Cache read ratio (cached input / total input) | ≥ 60% | Stop modifying CLAUDE.md mid-session; check for cache-busting tool calls |
| 1.3 | Total tokens for this session vs. similar past session | within 1.5× | Identify the bloat source (giant tool output? repeated reads?) |
| 1.4 | Number of full-file reads of files > 500 lines | ≤ 2 | Use offset/limit or grep first; never re-read what was just read |
| 1.5 | Auto-compaction triggered | did NOT trigger | If it triggered, your session was too long for one task — split next time |

---

## Part 2. Tool-Call Efficiency (transcript recall)

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| 2.1 | Same file Read more than once with same range | 0 occurrences | Cache mentally or note in working memory after first read |
| 2.2 | Independent tool calls run in parallel when possible | ≥ 80% of eligible groups | Re-read parallel-tool-call rules before next session |
| 2.3 | Bash used for `cat`/`head`/`tail`/`sed`/`echo` where dedicated tool exists | 0 occurrences | Use Read / Edit / Write / direct text output |
| 2.4 | Grep/find narrowed to specific paths (not full repo scan) | ≥ 90% of searches | Always start from a directory, not `/` or `.` at root |
| 2.5 | Subagent dispatched only for tasks > 3 sequential tool calls OR for context isolation | strict | If you used subagent for trivial lookup, that's overhead — use direct tool next time |
| 2.6 | Tool failures retried with same arguments | 0 occurrences | Diagnose root cause; never blind-retry |

---

## Part 3. Work Progress Efficiency (self-check)

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| 3.1 | Session covered ONE coherent task (not 2+ unrelated) | strict | Split next session; "one session = one task" |
| 3.2 | User had to re-explain something already in CLAUDE.md or memory | 0 occurrences | Update CLAUDE.md or write a memory entry — that's the lesson |
| 3.3 | Decisions reversed mid-session (chose approach A → switched to B → back to A) | ≤ 1 | Brainstorm/plan upfront before implementing |
| 3.4 | Plan or task list created for any work > 3 steps | strict | Use TaskCreate / write a plan; don't run multi-step work from working memory |
| 3.5 | Memory updated with new facts/feedback discovered this session | strict | Before closing, scan transcript for "things future-me would need to know" |
| 3.6 | Session-state snapshot written (what's done, what's pending) | strict | Write it now — pending work without a snapshot becomes lost work |
| 3.7 | User-visible updates were short (no narrating internal deliberation) | strict | Re-read tone/style guidance |

---

## Part 4. Output Quality Efficiency (diff recall)

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| 4.1 | Files written then rewritten in same session | ≤ 1 file | Plan structure before writing; don't draft-then-redraft live |
| 4.2 | New files verified with `wc -l` against the project's size convention | strict if convention exists | Add the verification step to your default workflow |
| 4.3 | CLAUDE.md modified mid-session (cache-busting) | 0 occurrences | Defer CLAUDE.md edits to start of next session |
| 4.4 | Quantitative thresholds (line counts, token budgets, scores) included where the project requires them | strict | Re-read project's "quantitative bar" requirement |
| 4.5 | Comments added that explain WHAT instead of WHY | 0 occurrences | Strip them; only WHY-comments survive |
| 4.6 | Dead code / TODO stubs / half-implementations left behind | 0 occurrences | Finish or delete; no half-states |
| 4.7 | Verification step run before claiming "done" (tests, build, or project-specific verification) | strict | "Verification before completion" — evidence before assertions |

---

## Scoring & Logging

At session end, log to `MEMORY` (or your equivalent persistent store):

```
Session: <date> / <task>
Part 1: X/5 PASS  | tokens: <n>, cache hit: <%>, context end: <%>
Part 2: X/6 PASS
Part 3: X/7 PASS
Part 4: X/7 PASS
Total:  XX/25 PASS
Top violations + next-session actions:
- <item> → <action>
- <item> → <action>
```

**Trigger thresholds:**
- Total < 80% → review the failed items before starting next session
- Same item fails 3 sessions in a row → promote to a hard rule in CLAUDE.md or harness/hook
- Same item fails across 2+ projects → promote to MASTER_GUIDES (anti-pattern section)

---

## Appendix A. AI_WORKFLOW project-specific items

Add to the audit when working in `/mnt/d/AI_WORKFLOW`:

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| A.1 | EXAMPLES/ files were NOT modified (snapshots only) | strict | Revert immediately; record the slip in feedback memory |
| A.2 | REFERENCE/ PDFs re-extracted when memory already had the extract | 0 occurrences | Always check `reference_pdf_extracts.md` first |
| A.3 | New guide/template/checklist file verified with `wc -l` | strict | Project convention — non-negotiable |
| A.4 | Hooks/TDD/CI proposed for THIS workspace (vs. as guide content) | 0 occurrences | This is a methodology project, not a code project — apply those to PocketCrawl/RWE only |
| A.5 | Same claim found 2+ times → promoted to MASTER_GUIDES; 3+ times → CHECKLISTS | strict | Promote now or note for next session |
| A.6 | Master guide vs. checklist vs. template responsibility kept separate (why/when vs. what-this-time vs. copy-paste-start) | strict | Refactor the cross-contamination |

---

## Appendix B. Game-project (PocketCrawl/RWE) additions

Add when applying the methodology to a game project:

| # | Check | Threshold | If FAIL |
|---|-------|-----------|---------|
| B.1 | Godot/Unity scene/prefab edits accompanied by code changes were verified by running the scene | strict | UI/scene changes can't be validated by type-checks alone |
| B.2 | Game data tables (CSV/JSON) edited without bumping a version/seed | 0 occurrences | Data changes need a marker for save-compat |
| B.3 | Multiplayer/networking code changed without testing both client and host paths | 0 occurrences | Half-tested networking is worse than not changing it |
