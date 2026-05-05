# AI Agent Master Guide

## Purpose
This guide is a personal operating manual for using coding agents such as Codex and Claude across any software project.

The goal is not just to "use AI", but to make AI consistently useful, safe, and reusable.

## Core Principle
Treat AI as an execution partner, not as a magic answer machine.

Good results come from:
- clear scope
- strong context
- explicit constraints
- objective verification
- written handoff

## When To Use Codex vs Claude

### Use Codex for
- codebase exploration with file edits
- structured refactors
- repetitive code changes
- API and backend fixes
- security hardening
- documentation generation tied to the repo
- handoff files and implementation summaries

### Use Claude for
- requirement shaping
- reasoning-heavy design discussions
- prompt design
- domain rule extraction
- natural-language interpretation
- deciding how to structure a task before implementation

### Best combined workflow
1. Use Claude to clarify the problem and define the work.
2. Use Codex to implement, verify, and document it.
3. Use either tool to review the final output against the original goal.

## Golden Rules

1. Always start with context, not code.
2. Always define the active runtime path before changing anything.
3. Always separate refactoring from behavior changes when possible.
4. Always give a verification target.
5. Always leave a written summary after substantial work.
6. Always constrain AI with permissions, allowlists, and safe defaults.
7. Always prefer modular documents over one giant undocumented repo.
8. Always reset or restart when context gets noisy.
9. Always turn repeated corrections into written rules.
10. Always optimize for future reuse, not just today's fix.

## Recommended Project Bootstrap

For any new project, create these first:

1. Root context file
- `CLAUDE.md`

2. Module context files
- `backend/CLAUDE.md` or `pg/CLAUDE.md`
- `frontend/CLAUDE.md`
- optional: `data/CLAUDE.md`, `infra/CLAUDE.md`, `scripts/CLAUDE.md`

3. Supporting docs
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/security.md` or `docs/security_plan.md`
- `docs/handoff.md`
- `docs/runtime_checklist.md`

## What Every Root CLAUDE.md Should Contain

### Required
- project overview
- tech stack
- active runtime command
- directory map
- cross-cutting rules
- index of module CLAUDE files
- reference docs

### Strongly recommended
- verification commands
- forbidden actions
- data sensitivity notes
- current migration status
- known legacy paths

## What Every Module CLAUDE.md Should Contain

### Required
- what this module does
- key files
- non-obvious patterns
- rules for modifying this area
- if you add feature X, also update Y

### Strongly recommended
- verification commands for this module
- ownership boundaries
- known pitfalls
- example request/response or state-flow pattern

## Prompt Pattern That Works Best

Use prompts shaped like this:

```text
Goal:
Fix/refactor/implement X.

Scope:
Only work in these files or modules.

Constraints:
Do not change runtime behavior unless necessary.
Do not touch legacy paths unless explicitly needed.
Do not weaken auth/security rules.

Verification:
Run compile/test/lint command Y.
Confirm endpoint Z still works.

Output:
Summarize what changed, what was verified, and what remains.
```

## Session Types

### 1. Orientation session
Use when entering an unfamiliar codebase.

Ask for:
- active runtime
- legacy/runtime split
- top risks
- module boundaries

### 2. Fix session
Use when something is broken.

Ask for:
- root cause
- minimal safe fix
- validation command
- residual risk

### 3. Refactor session
Use when structure is the main problem.

Ask for:
- behavior-preserving extraction
- file split by responsibility
- compile/test verification
- handoff summary

### 4. Hardening session
Use when safety matters.

Ask for:
- permission boundaries
- allowlist enforcement
- timeout/resource limits
- logging/audit coverage

### 5. Handoff session
Use when you or another AI will continue later.

Ask for:
- what changed
- why it changed
- what was verified
- what still remains

## Verification Standards

Never end a substantial coding session without at least one of:
- compile check
- test run
- lint/typecheck
- runtime checklist
- explicit explanation of what could not be verified

If tests are deferred, write that down clearly.

## Conversation Hygiene

Use one session for one main task whenever possible.

Recommended pattern:
- session 1: orientation / risk review
- session 2: implementation or refactor
- session 3: cleanup / documentation / handoff

When a session gets long or noisy:
- summarize what changed
- record what remains
- start a fresh session for the next major task

Do not keep piling unrelated work into one giant thread if the original objective has already changed.

## Anti-Patterns

Avoid:
- one giant session covering design, implementation, cleanup, and testing without summaries
- asking for "make this better" with no scope
- letting AI discover security rules implicitly
- keeping tribal knowledge only in chat
- allowing LLM-generated SQL or automation without runtime boundaries
- mixing legacy and active runtime paths in one document

## How To Build An AI-Ready Codebase

An AI-ready codebase usually has:
- clear entrypoints
- small, named modules
- stable conventions
- explicit security boundaries
- minimal hidden tribal knowledge
- local verification commands
- handoff docs that survive chat history
## Knowledge Layers

Treat project knowledge as three layers:
- raw sources: schema files, original specs, imports, tickets, spreadsheets, legacy notes
- persistent wiki: architecture notes, handoff docs, checklists, security plans, runtime guides
- schema for agents: CLAUDE.md, module rules, templates, explicit workflow constraints

Do not rely on chat history alone. When useful conclusions are discovered, promote them upward:
- repeated findings from raw sources should become wiki notes
- repeated wiki guidance should become CLAUDE.md or template rules
- repeated corrections should become durable checklists

This keeps knowledge cumulative instead of rediscovering the same facts every session.

## Wiki Maintenance Habit

After substantial work, decide whether the result belongs in one of these buckets:
- implementation summary
- runtime checklist
- security note
- domain rule note
- handoff doc
- module CLAUDE.md update

A good rule: if the same explanation would be needed again in a future session, write it down in the persistent wiki layer instead of leaving it in chat.

## Minimal End-Of-Task Checklist

Before considering a task done, ask:
- Is the active runtime path still correct?
- Did behavior change, or only structure?
- What was verified?
- What remains risky?
- Did we leave a handoff note?

## Best Long-Term Habit

Whenever you correct an AI twice on the same topic, convert that correction into one of:
- a CLAUDE.md rule
- a conventions doc entry
- a checklist item
- a template section

That is how one-off chat effort becomes a durable engineering system.

