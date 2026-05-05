# Harness & Hooks Guide

## Purpose
This guide is a personal operating manual for designing the **harness** around coding agents — the safeguards, hooks, and permission boundaries that make AI work safe and consistent across projects.

The goal is to move from "manually checking what the AI did" to "the system blocks bad actions before they happen."

Use this together with `AI_AGENT_MASTER_GUIDE.md`. That guide covers context and documentation discipline. This guide covers the runtime guardrails.

## Core Principle
A coding agent has full execution access. If the agent decides it is right, it will run the command — even when wrong.

**Human review is an inefficient safeguard.** It catches some mistakes, misses others, and adds latency to every change. The real safeguard is a system that auto-blocks the bad action.

Reference incident: Amazon deployed AI-written code without review, lost ~6.3M orders over 6 hours. The fix that scales is not "require senior approval" — it is "make the dangerous action impossible to execute in the first place."

## When This Guide Applies
- Any code project where the agent has write/execute access (essentially all)
- Especially: projects with deploy paths, DB write access, secret handling, or service uptime requirements
- Skip / minimal: pure docs projects, methodology projects, scratch experiments — the ROI is too low

## Harness Layer Map

The harness has four layers. Use all of them, not just one:

1. **Permissions** (`settings.json` `permissions`) — what the agent is allowed to invoke at all
2. **Hooks** (`settings.json` `hooks`) — scripts that fire before/after agent actions
3. **Subagent isolation** — route risky or context-heavy work to a separate agent so the main session is unaffected
4. **Verification commands** (per project, in CLAUDE.md) — what the agent must run before claiming "done"

Layers 1 and 2 are enforced by the runtime. Layers 3 and 4 are habits the agent follows. Always prefer 1+2 over 3+4 — enforced beats voluntary.

## Hook Taxonomy

Hooks fire at lifecycle events. The ones that matter most:

| Event | Fires when | Use for |
|---|---|---|
| `PreToolUse` | Before any tool runs | Block dangerous commands, enforce TDD, require lint pass |
| `PostToolUse` | After a tool runs | Auto-format, auto-stage, auto-update docs |
| `UserPromptSubmit` | When user sends a message | Inject context, log session intent |
| `Stop` | When agent finishes a turn | Run lint/test/build, verify nothing left broken |
| `SessionStart` | New session starts | Load project state, remind of active branch/migration |

A hook that fires `PreToolUse` and exits non-zero **blocks the tool call**. That is the enforcement primitive.

## The 4 Practical Hooks

Start every code project with these four. They cover the majority of real failure modes.

### 1. Lint / Test / Build Hook
Fires before commit (or before any write to main code paths).

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "scripts/precommit_guard.sh"}
        ]
      }
    ]
  }
}
```

The `precommit_guard.sh` inspects the command (e.g., `git commit`) and runs lint/typecheck/build. Non-zero exit blocks the commit.

**Why this matters:** Without it, the agent commits broken code, then "fixes" it in a follow-up commit, polluting history and wasting tokens.

**RWE applicability:** Hook should run `python -m py_compile pg/...` and `cd frontend && npm run build` before any commit touching `pg/` or `frontend/`.

**PocketCrawl applicability:** Engine parse check on changed `.gd` files.

### 2. PR Review Hook (Subagent-Routed)
Fires before pushing or before marking a task complete. Routes the diff to a separate agent for review.

The reason this needs a subagent: the main agent is biased — it just wrote the code and wants to ship. A fresh agent reviewing the diff has no commitment to the implementation and catches what the main agent rationalized.

Implementation: `Stop` hook → invoke `code-reviewer` subagent with the current diff → report findings to user.

**Don't** auto-block on review findings unless they are clearly critical. Surface them, let user decide.

### 3. TDD Hook
Fires `PreToolUse` on `Edit` / `Write` to source files. If no test file has been touched in this session for the changed module, **block the edit** with a message like "write or update the test for this module first."

This is the most behaviorally powerful hook. It changes how the agent decomposes work — from "write feature, then maybe tests" to "test first, then feature."

**When to skip:** prototype/spike work, throwaway scripts, docs. Configure the hook to only fire on specific paths (e.g., `pg/routes/*.py`, not `scripts/*.py`).

**RWE applicability:** Currently no test suite. TDD hook would force test infrastructure to exist before further endpoint work — useful forcing function.

**PocketCrawl applicability:** Godot tests are weak. Substitute with "scene parse check" requirement instead of TDD.

### 4. Incident-Pattern Hook
Whenever a real incident happens (deployed bad code, broken migration, leaked secret), the post-mortem becomes a pattern, and the pattern becomes a hook.

Example: "we once committed a `.env` file." → `PreToolUse` hook on `Bash` matching `git add .env*` → block.

Example: "we once dropped a table without a backup." → `PreToolUse` hook on `Bash` matching `DROP TABLE` → require explicit confirmation flag.

This is the **post-mortem → pattern → hook embed** loop. The point is that you only have to suffer each class of incident once.

## Permissions As Parallel Safeguard

Hooks block at runtime. Permissions block at configuration time — the agent never even attempts the action.

Use `settings.json` `permissions` for:
- **deny** list: destructive commands you never want even attempted (`rm -rf /`, `git push --force origin main`, `DROP DATABASE`)
- **allow** list: read-only and well-known safe commands (`ls`, `cat`, `grep`, `git status`) — reduces permission prompts
- **ask** list: ambiguous commands where a one-time prompt is fine

A good rule: any command that touched production once and you regretted it → add to deny. Any command you approve >3 times in a session → add to allow.

## Subagent Isolation

When a task would balloon the main context (reading 50 files, running a long search, parsing a giant log), dispatch it to a subagent. The subagent returns a summary; the main session never sees the raw output.

Use cases:
- Codebase exploration ("find all uses of this deprecated function") → `Explore` subagent
- Code review of a diff → `code-reviewer` subagent
- Plan synthesis from multiple sources → `Plan` subagent
- Security audit of changed files → dedicated security subagent

Anti-pattern: dispatching subagents for trivial single-file work. The dispatch overhead exceeds the benefit.

## Hook Design Loop

This is the workflow for evolving the hook set over time:

1. **Incident or near-miss happens** — agent did something dangerous, or you caught it just in time
2. **Write a one-paragraph post-mortem** — what action, what trigger, what damage if not caught
3. **Extract the pattern** — is this a class of action (deletion of state files, force-push to main, secret commit) or a one-off
4. **Encode as hook** — `PreToolUse` matcher + script that detects the pattern, exits non-zero with explanation
5. **Test the hook** — try to perform the dangerous action, confirm it is blocked
6. **Document in CLAUDE.md** — add a one-line note "this action is blocked by hook X" so the next session understands the constraint

This loop replaces "remember not to do that" with "system enforces it."

## Anti-Patterns

Avoid:
- **Hooks that produce noisy output on every action** — they erode signal value, get ignored
- **Hooks that block on warnings, not errors** — agent then disables the hook, defeating the point
- **Permissions allow-all + reliance on prompts** — equivalent to having no permissions
- **Hook scripts inside the repo without execution restrictions** — the agent could rewrite its own constraints
- **Building hooks for hypothetical incidents** — only encode patterns you have actually seen, otherwise the hook set bloats and slows everything

## Project Applicability Matrix

| Hook | Pure docs project | Code project (small) | Code project (with deploy) |
|---|---|---|---|
| Lint/Test/Build | skip | optional | required |
| PR Review (subagent) | skip | optional | required |
| TDD | skip | optional (test infra exists?) | required |
| Incident-Pattern | skip | as incidents occur | as incidents occur |
| Permissions deny list | minimal | yes | strict |
| Permissions allow list | trim noisy prompts | yes | yes |

**This methodology project (`AI_WORKFLOW`)**: hooks not applicable. Permission allowlist for common reads is the only useful piece.

**RWE / XENIA**: all four hooks apply. Highest priority is **Incident-Pattern** for `psql` / `DROP` / `legacy/server.py` invocation, since prod DB and read-only guard are core concerns.

**PocketCrawl**: TDD hook → substitute with scene-parse-check hook. Incident-Pattern hook for save-file overwrites.

## Minimum Bootstrap For A New Code Project

Day 1 setup, in this order:

1. **Permissions deny list** — write down 5-10 commands that must never run in this project
2. **Permissions allow list** — add the 10 most common read-only commands you already approve
3. **Lint/Test/Build hook** — even a 3-line script. Iterate later.
4. Skip TDD/PR Review hooks until the project has actual tests / actual review needs
5. Add Incident-Pattern hooks reactively, not proactively

Adding all four hooks Day 1 is over-engineering. The goal is to start with the harness skeleton and grow it as real incidents teach you what matters.

## Verification Standard For This Guide

A hook setup is "good enough" when:
- The dangerous action you most fear in this project is auto-blocked, with a clear error message
- Common safe actions do not produce permission prompts (allowlist tuned)
- The hook script itself is in the repo, version controlled, and reviewed when changed
- A new session can read CLAUDE.md and understand which hooks are active without reading the hook scripts

If any of these fails, iterate before considering the harness complete.

## Best Long-Term Habit

After every coding session, ask:
- Did I approve any command I shouldn't have to approve again? → allowlist
- Did I almost do something dangerous? → denylist or hook
- Did the agent burn tokens on context that a hook could have shortened? → context hook
- Did a sub-task explode my main context? → subagent route next time

This turns runtime friction into permanent harness improvements. That is how the harness gets better with every session instead of staying static.
