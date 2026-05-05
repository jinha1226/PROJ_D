# Context & Token Efficiency Guide

## Purpose
This guide is the operational counterpart to `AI_AGENT_MASTER_GUIDE.md`. Where the master guide covers documentation discipline and `HARNESS_AND_HOOKS_GUIDE.md` covers runtime safeguards, this guide covers the **token economy** — how to keep agent context clean, cheap, and high-signal across sessions.

Read this when:
- Sessions feel slow or expensive
- The agent re-asks the same questions across sessions
- You suspect prompt cache is being broken
- Context bloats halfway through a task

## Core Principle
**Cost is a function of context.** Every token in input and output costs money and time. Clean context produces better output for less money. Polluted context produces worse output for more money.

This is not just an economics issue. A bloated, noisy context degrades agent reasoning quality even when budget is not a concern. Treat context cleanliness as a quality lever, not a cost lever.

---

# Part 1 — The 3 Token-Efficiency Principles

These three principles cover almost every token-saving decision worth making.

## Principle 1: Persistent Context
**Don't re-teach what the agent should already know.**

What this looks like:
- Project facts (architecture, conventions, runtime command) live in `CLAUDE.md`, not in every prompt
- Domain rules and "things we tried and abandoned" live in durable docs, not in chat history
- Memory system stores user role, feedback, project state across sessions
- Reference extracts (e.g., PDF summaries) are stored once, reused indefinitely

The failure mode: typing "remember, our backend uses FastAPI on port 8502 with PostgreSQL" into every new session. That is wasted tokens and a sign the durable layer is incomplete.

The fix: when you find yourself explaining the same fact twice, write it down in `CLAUDE.md`, in a module doc, or in the memory system — depending on whether it is project structure, project state, or user preference.

## Principle 2: Precise Prompt
**Don't make the agent guess.**

What this looks like:
- Specify file paths, function names, and exact constraints
- Specify the output format you want (one-line summary vs full report vs diff vs JSON)
- Specify scope explicitly ("only files under `pg/routes/`", not "the relevant files")
- Specify what NOT to do when ambiguous

The failure mode: "fix the bug" → agent reads 30 files trying to find context → produces a sprawling change → you discard most of it. All those reads are tokens.

The fix: spend 30 seconds adding 3 sentences of constraint to the prompt. Reduces agent exploration by 5~10x.

A useful template:
```
Goal: <one sentence>
Scope: <exact files or modules>
Constraints: <what not to change, what to preserve>
Output: <format, length, level of detail>
```

## Principle 3: Conversation Hygiene
**One session, one main task. Compress and reset before drift.**

What this looks like:
- Start a new session for each major task instead of piling unrelated work into one thread
- When a session gets long, summarize what was done and start fresh for the next task
- When context fills past ~30~40%, compress (or let auto-compaction handle it) before continuing
- Don't keep "while we're here, can you also..." accumulating in the same session

The failure mode: a 4-hour single session that started as "fix login bug" and ended with refactor + new feature + tests + deploy script. Agent quality degraded around hour 2; you didn't notice because the slope was gentle.

The fix: when the original task is done, write a short handoff (or update the relevant doc), close the session, start a new one. Cache miss is cheap; bad output is expensive.

---

# Part 2 — The 3 Context Pollution Patterns

These are the failure modes. Each one has a recognizable symptom and a specific fix.

## Pattern A: Context Bloat
**Symptom:** Context fills steadily across the session. Agent starts repeating itself, missing instructions from earlier, or producing increasingly generic output. Token usage per turn keeps creeping up.

**Common causes:**
- Multiple unrelated tasks in one session
- Agent re-reading the same files because it forgot it already read them
- Verbose tool outputs accumulating with no summarization
- User dumping large pasted contexts (logs, full files) instead of pointing to paths

**Fixes:**
- **One session per task.** Boring rule, biggest single win.
- **Compress proactively at ~30~40% context.** Don't wait for auto-compact at 90%; the quality drop happens earlier than the limit.
- **Specify output format** in prompts to prevent verbose responses ("respond in one paragraph", "return only the file paths").
- **Use durable docs as memory.** When mid-session you discover something worth remembering, write it down — both for current and future sessions.

## Pattern B: Giant Tool Outputs
**Symptom:** A single tool call (file read, grep, log dump, build output) returns thousands of tokens. After that, every subsequent turn is more expensive because the giant output sits in context.

**Common causes:**
- Reading entire large files when only a section was needed
- `grep` without filters returning hundreds of matches
- Running tests/builds with full verbose output
- Listing huge directories without filters

**Fixes:**
- **Read with line offsets/limits** when the file is large and you know the region
- **Grep with narrow patterns and head/limit** to bound output size
- **Pipe build/test output through filters** (e.g., `2>&1 | tail -50`) before showing to agent
- **Route to a subagent** when the work itself requires reading many files. The subagent absorbs the giant context and returns a small summary. The main session never sees the raw bytes.
  - Example: instead of grepping 100 files yourself, dispatch an `Explore` subagent with the question.
- **Use `find -maxdepth N`** instead of unbounded find when surveying structure

## Pattern C: Poor Cache Utilization
**Symptom:** Token costs are 2~5x what they should be. Sessions that should be cheap are not. No obvious culprit.

**Cause:** The Anthropic prompt cache has a ~5-minute TTL and is invalidated by changes to anything in the cached prefix. If `CLAUDE.md` is modified mid-session, or the system prompt changes, or 5+ minutes pass without activity, the cache is broken and the next request re-pays for the entire context.

**Common causes:**
- Editing `CLAUDE.md` in the middle of a session (the agent then re-reads it; cache breaks)
- Long idle gaps (>5 min) between turns — common when working on something else in parallel
- Tool calls that modify the prefix indirectly (e.g., changing project-level config files the agent reads at startup)

**Fixes:**
- **Do not edit `CLAUDE.md` mid-session** unless that edit *is* the task. Save updates for end-of-session or new-session.
- **Batch your turns.** If you know you need to step away for 10+ minutes, finish or pause cleanly first. Don't leave a half-turn hanging.
- **Be aware of the 5-minute TTL when planning waits.** If you must wait, either wait under 5 minutes (cache stays warm) or commit to >20 minutes (one cache miss buys you a long block of time). 5~15 minutes is the worst-of-both zone.
- **Keep root `CLAUDE.md` stable.** Volatile project state belongs in module docs or memory, not in the most-cached file.

---

# Part 3 — Active vs Passive Optimization

Two ways to apply the principles above:

**Active optimization** — you consciously do it.
- Compress context before it bloats
- Edit `CLAUDE.md` only between sessions
- Specify output format in every prompt
- Dispatch subagents for heavy reads

This works but depends on discipline. You will forget some of the time.

**Passive optimization** — the harness enforces it.
- Hook auto-compresses context at threshold
- Hook routes large reads to subagents automatically
- Hook auto-refreshes `CLAUDE.md` at session start, never mid-session
- Permission denylist prevents reading whole large files

This is more reliable. Build passive optimization for the patterns you fail at repeatedly.

The general rule: every recurring active habit should eventually become a passive enforcement. See `HARNESS_AND_HOOKS_GUIDE.md` for the hook patterns.

---

# Part 4 — Project Applicability

| Pattern / Principle | Methodology project (this repo) | Code project (small) | Code project (large/team) |
|---|---|---|---|
| Persistent Context | memory + CLAUDE.md (active) | CLAUDE.md set | CLAUDE.md set + module docs + decision log |
| Precise Prompt | habit | habit + prompt templates | habit + slash commands |
| Conversation Hygiene | habit | habit | habit + session-end hooks |
| Context Bloat fix | habit | habit + auto-compress hook | required hooks |
| Giant Output fix | habit | subagent dispatch | required subagent routing + filtered tool wrappers |
| Cache preservation | habit (don't edit CLAUDE.md mid-session) | hook (block CLAUDE.md edits during active sessions) | hook + tooling alerts |

**This methodology project**: principles applied as habits; no enforcement infrastructure needed. Memory system is the main persistent layer.

**RWE / XENIA**: cache preservation matters most given multi-file edits across sessions. Active habit + a "do not edit CLAUDE.md mid-session" reminder in root `CLAUDE.md`.

**PocketCrawl**: subagent routing for "read all 10 .gd files" tasks. Currently done linearly, wastes tokens.

---

# Part 5 — Diagnostics

When sessions feel inefficient, run through this in order:

1. **Is the same fact being re-explained across sessions?** → Persistent Context gap. Add to `CLAUDE.md` or memory.
2. **Is the agent reading more files than necessary per turn?** → Precise Prompt gap. Add scope constraints.
3. **Has this session been running for over an hour on multiple tasks?** → Conversation Hygiene gap. Close it.
4. **Did costs spike after a specific tool call?** → Giant Tool Output. Filter or subagent the next time.
5. **Are repeat-pattern sessions costing differently?** → Likely cache utilization. Check if `CLAUDE.md` was edited or if there were >5 min idle gaps.

A good habit: at the end of any unusually expensive session, write one sentence in a "session debrief" doc (or memory) — what wasted tokens. After 5~10 entries, the patterns become obvious and you know exactly which hook to build next.

---

# Anti-Patterns

Avoid:
- **Pasting whole files into the prompt** when you could give a path. The agent's read tool is cache-friendly; user-pasted content is not.
- **Leaving sessions open "in case I need them later".** A session you might come back to in 3 hours is a cache miss waiting to happen.
- **Rewriting `CLAUDE.md` after every session** as a "cleanup" habit. Each rewrite is a cache invalidation for next session. Update only when the change is durable and substantial.
- **Building elaborate prompt templates for one-off questions.** Templates are for repeated tasks. For a one-off, plain text is faster.
- **Optimizing token cost on a project where token cost is not the bottleneck.** If you only run 5 sessions a month, this guide's investment may not pay back. Apply where volume justifies it.

---

# Best Long-Term Habit

Once a week, look at the sessions that felt expensive or slow, and ask:
- Which of the 3 principles failed? (Persistent / Precise / Hygiene)
- Which of the 3 pollution patterns appeared? (Bloat / Giant Output / Poor Cache)
- Was this an active-discipline failure (I forgot) or a missing passive enforcement (no hook)?

Each answer points to a specific durable fix: a `CLAUDE.md` entry, a prompt template, a hook, or a workflow change. That is how the token economy improves over time instead of staying static.
