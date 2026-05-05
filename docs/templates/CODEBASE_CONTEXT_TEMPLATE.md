# Codebase Context Template

## Purpose
Use this template when starting any new project or reorganizing an existing one for AI-assisted development.

This is designed for:
- root `CLAUDE.md`
- module-level `CLAUDE.md`
- durable project context for Codex and Claude

---

# 0. The 5-Question Framework

Every `CLAUDE.md` (root or module) must answer 5 questions. If any are missing, the file is incomplete.

1. **What** — what this code does, in one short paragraph
2. **How** — the typical pattern for modifying this area (not how the code internally works, but what a normal change looks like)
3. **Non-Obvious Pattern** — what would surprise a reader who only saw the code; the constraints that don't show up in any single file
4. **Navigation** — what this depends on, what depends on this, and where to find related docs
5. **Tribal Knowledge** — gotchas, deprecated paths, things tried and abandoned, "we learned this the hard way" notes

Most "AI getting lost" failures trace back to a missing answer — usually #3 or #5. Code review can recover #1 and #2; only the docs can carry #3, #4, #5 across sessions.

The templates below are concrete shapes for fulfilling these 5 questions in different module types. The section names map as follows:

| 5-Question | Template section |
|---|---|
| What | "What" / "Project Overview" |
| How | "If You Change X, Also Check Y" / "Cross-Cutting Rules" |
| Non-Obvious Pattern | "Non-Obvious Domain Knowledge" / "Forbidden / Caution Areas" |
| Navigation | "Module CLAUDE.md Index" / "Reference Docs" / "Key Files" |
| Tribal Knowledge | "Non-Obvious Domain Knowledge" / "Current Working Truths" / "Forbidden / Caution Areas" |

---

# 1. Root `CLAUDE.md` Template

> **Size budget:** keep root `CLAUDE.md` under **100~200 lines**. It loads into agent context every session, so length directly costs tokens. If it grows past 200, split into module files and leave only the index here.

```md
# <PROJECT NAME>

## Project Overview
<One short paragraph: what this project does, who it serves, current scale, and major constraints.>

## Tech Stack
- Frontend: <framework/version>
- Backend: <framework/version>
- DB: <database/version>
- Infra: <hosting/runtime>
- AI/LLM: <if applicable>

## Active Runtime
```bash
<primary backend run command>
<primary frontend run command>
<primary worker/job command if any>
```

## Directory Map
```
<top-level-folder>  ??<what lives here>
<top-level-folder>  ??<what lives here>
docs/               ??architecture, conventions, handoff, runtime checklists
legacy/             ??archived or inactive code
```

## Cross-Cutting Rules
1. <critical repo-wide rule>
2. <critical security or data rule>
3. <critical runtime or formatting rule>
4. <critical migration or compatibility rule>

## Verification Commands
```bash
<compile command>
<test command>
<lint/typecheck command>
```

## Forbidden / Caution Areas
- Do not <dangerous thing>
- Do not assume <legacy path> is active
- Do not weaken <auth / security / data handling rule>

## Module CLAUDE.md Index
- `backend/CLAUDE.md` or `pg/CLAUDE.md` ??backend rules, DB patterns, auth, endpoint rules
- `frontend/CLAUDE.md` ??UI rules, API client patterns, state rules
- `data/CLAUDE.md` ??import/export rules, encoding, schemas
- `infra/CLAUDE.md` ??deployment, env, secrets, background jobs

## Reference Docs
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/security.md`
- `docs/handoff.md`
- `docs/runtime_checklist.md`
```

---

# 2. Backend / `pg/CLAUDE.md` Template

> **Size budget:** module `CLAUDE.md` should be **25~35 lines / ~1k tokens**. Module files are loaded conditionally; if they bloat, agents skip them. Push detail into separate focused docs and link from here.

```md
# <MODULE NAME> ??Backend

## What
<Short paragraph about the module's responsibility.>

## Key Files
```
server.py            ??app composition / entrypoint
routes/              ??endpoint files
db.py                ??connection and pool handling
models.py            ??request/response models
security.py          ??auth / access control
```

## Runtime Rules
- Active entrypoint: `<command>`
- Read-only vs write DB paths: <rule>
- Transaction/connection pattern: <rule>

## SQL / Data Rules
- Parameter binding style: <rule>
- Allowlist / dynamic query guard: <rule>
- Known date / null / encoding caveats: <rule>

## Auth / Security
- Roles: <list>
- Guard middleware: <location>
- Sensitive endpoints: <rule>
- Required audit/logging behavior: <rule>

## Non-Obvious Domain Knowledge
### <domain code / enum / workflow>
<explanation>

### <analytics caveat>
<explanation>

### <data model quirk>
<explanation>

## If You Change X, Also Check Y
- If you add a POST analysis endpoint, also update <file/rule>.
- If you add dynamic SQL, also update <allowlist/guard>.
- If you change auth logic, also update <audit/tests/docs>.

## Verification Commands
```bash
<backend compile command>
<backend test command>
```
```

---

# 3. Frontend `CLAUDE.md` Template

```md
# <MODULE NAME> ??Frontend

## What
<Short paragraph about the frontend's responsibility and main feature areas.>

## Key Files
```
src/api/client.ts       ??API client
src/types/              ??shared TS types
src/pages/              ??page-level screens
src/components/         ??reusable UI components
```

## Critical UI Rules
- <import rule>
- <chart/rendering rule>
- <design system rule>
- <state persistence rule>

## API Integration Pattern
- Add endpoint wrappers in `src/api/client.ts`
- Reuse shared types where possible
- Do not fetch directly in ad-hoc scattered ways unless necessary

## State / UX Rules
- <state management approach>
- <navigation / tab / session persistence approach>
- <date formatting / null handling approach>

## Non-Obvious Domain Knowledge
### <page pattern>
<explanation>

### <component quirk>
<explanation>

### <analysis flow pattern>
<explanation>

## If You Change X, Also Check Y
- If you add a backend endpoint, add client wrapper and types.
- If you add a chart, follow the existing chart factory/import rule.
- If you change response shape, update both API client and consuming page/component.

## Verification Commands
```bash
<frontend dev/build command>
<frontend test/lint/typecheck command>
```
```

---

# 4. Optional Module Types

You can also create:
- `data/CLAUDE.md` for importers, schemas, encodings, source systems
- `infra/CLAUDE.md` for deploy/runtime/env/secrets
- `scripts/CLAUDE.md` for jobs, migrations, cron tasks, one-off tooling
- `legacy/CLAUDE.md` for archived code that must not be treated as active

---

# 5. Recommended Quality Bar

## Quantitative bar
- Root `CLAUDE.md`: **100~200 lines max**
- Module `CLAUDE.md`: **25~35 lines / ~1k tokens**
- Every `CLAUDE.md` answers **all 5 questions** (see Section 0)
- Every actionable rule has either a **command** to run, a **file path** to check, or a **decision rule** to apply — no abstract advice
- Every reference to "see X" links to a real file path that exists

## Qualitative bar
A good `CLAUDE.md` is:
- short enough to scan in one breath
- specific enough to change behavior
- focused on non-obvious things (#3 and #5 of the 5 questions)
- updated when the same mistake happens twice

A bad `CLAUDE.md` is:
- too generic ("write good code")
- too long (root past 200 lines, module past 50)
- redundant with what the code already says obviously
- missing the active runtime command and verification commands
- silent on tribal knowledge — only describing what is, never what was tried and abandoned

## Self-audit prompt
Apply `CHECKLISTS/AI_READY_CODEBASE_SCORECARD.md` to score the current state of any project's CLAUDE.md set. Below 60 → restructure. 60~79 → fill specific gaps. 80+ → maintain freshness only.

---

# 6. Recommended First Pass For Any New Project

Create:
1. root `CLAUDE.md`
2. backend `CLAUDE.md`
3. frontend `CLAUDE.md`
4. `docs/architecture.md`
5. `docs/conventions.md`
6. `docs/runtime_checklist.md`
7. `docs/handoff.md`

That gives AI enough structure to be useful very early.

---

# 7. Raw Sources -> Wiki -> Agent Rules

When organizing a new project, think in three layers:

1. Raw sources
- code
- DB schema
- tickets / specs
- spreadsheets / source files
- legacy notes

2. Persistent wiki
- docs/architecture.md
- docs/conventions.md
- docs/security.md or docs/security_plan.md
- docs/handoff.md
- docs/runtime_checklist.md
- focused notes for domain rules, migrations, or analysis behavior

3. Agent rules
- root CLAUDE.md
- module CLAUDE.md files
- reusable team or personal templates

Recommended update flow:
- discover facts from raw sources
- summarize and stabilize them in docs
- elevate repeated rules into CLAUDE.md or templates

This prevents the same discovery work from being repeated in every AI session.

# 8. Recommended Durable Docs Beyond The Minimum

For medium or complex projects, also consider creating:
- docs/domain_rules.md
- docs/data_sensitivity.md
- docs/legacy_map.md
- docs/decision_log.md
- docs/analysis_rules.md

These documents make it easier for future AI sessions to continue work without depending on prior chat context.
