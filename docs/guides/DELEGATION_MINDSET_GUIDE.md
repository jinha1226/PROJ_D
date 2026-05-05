# Delegation Mindset Guide

## Purpose
Most developers stay at the **AI-Aided** stage indefinitely — using AI as an autocomplete or pair-programmer while remaining the primary author of the code. The leap to **AI-Maximalist** (and later **AI-Native**) is not about using more AI; it is about a fundamental change in what you optimize for.

This guide is the operational map for that transition. Use it when you notice yourself "still doing all the typing" despite having access to capable agents.

## Core Principle
The bottleneck for AI-Aided developers is **their own typing speed and attention**. The bottleneck for AI-Maximalist developers is **how cleanly they can decompose and delegate**.

Different bottleneck → different skill set → different daily habits.

---

# The 4 Stages (Reference)

From the source PDFs, restated for this guide:

| Stage | Default question when a task arrives | Time spent typing code | Time spent designing delegation |
|---|---|---|---|
| **AI Aware** | "Should I try ChatGPT for this?" | 100% | 0% |
| **AI Aided** | "How do I write this, with AI helping?" | 70% | 5% |
| **AI Maximalist** | "How do I split this so I can delegate it?" | 20% | 50% |
| **AI Native** | (the question doesn't separate from the work) | 5% | continuous |

Most developers are in AI Aided. The PDF estimates ~90% of Korean developers, and the same is roughly true elsewhere. The Aided → Maximalist jump is the hard one. Maximalist → Native is mostly time + codebase investment.

---

# Why The Aided → Maximalist Jump Is Hard

**It feels slower at first.** Decomposing a task into delegable pieces, writing scope/constraints/output specs, then reviewing the agent's output takes longer than just typing the code yourself for small tasks. The payoff only appears at task sizes where typing-it-yourself becomes a bottleneck — but you don't get there if you keep typing-it-yourself for everything.

**You lose the dopamine of "I made this".** Reviewing diffs is less satisfying than writing them. This is real and underestimated.

**Trust building is slow.** Early delegation produces wrong output. The reflex is "I'd have done this faster myself, never again." But the trust gap closes only with reps and with better delegation prompts — which you can only build by doing it more, not less.

**Your existing tooling assumes you type.** IDEs, keybindings, snippets — all optimized for the Aided workflow. Switching feels like throwing away muscle memory.

The transition has to be deliberate. It does not happen by accident even with unlimited AI access.

---

# The Mental Shift

When a task arrives, the AI-Aided developer asks:
> "How do I solve this? Where do I start typing?"

The AI-Maximalist developer asks:
> "What does done look like? What are the 2~5 chunks this splits into? Which chunks can run in parallel? What does each chunk need from me to succeed without asking back?"

The first question is about **execution**. The second is about **decomposition + specification**.

You can practice this shift on any task you currently do solo. Before opening the editor, write out:
1. **Definition of done** (one sentence)
2. **Chunks** (2~5 bullets, each independently actionable)
3. **Per-chunk spec** (scope, constraints, expected output, verification)

If you can write all three in 5 minutes, you can delegate. If you can't, the task is still under-specified — and that under-specification is exactly what would make the Aided approach also messy.

---

# Daily Practices For The Transition

## Practice 1: The 50% rule
For one week, force yourself to delegate the second half of any task you start typing. Once you've established the structure, hand off the rest with a clear spec. This calibrates how much of your "typing time" was actually high-value design vs mechanical execution.

## Practice 2: The decomposition log
Keep a one-week log of every task you handled, and ask: could this have been split into N delegable chunks? Most tasks turn out to be 3~5 chunks. Tasks that are truly atomic (one tiny edit, one trivial fix) are fine to type yourself — but they are rarer than they feel.

## Practice 3: Spec before code
Before writing any non-trivial code yourself, write the spec you would have given to an agent. If the spec is shorter than the code would have been, delegate. If the spec is longer than the code, type it.

## Practice 4: Parallel dispatch trial
Once a week, find a task that has 2~3 independent subtasks. Dispatch all of them as parallel subagents (in Claude Code: multiple Agent calls in one message). Observe how much wall-clock time you save. The first time this works, the mental model clicks.

## Practice 5: Review-as-primary-skill
Treat reviewing agent output as a learnable skill, not a chore. Specifically: notice the patterns in what the agent gets wrong, and feed those patterns back into your delegation prompts and into `CLAUDE.md`. Each correction should produce a durable rule, not just a fix.

---

# What To Delegate vs What To Keep

Not everything should be delegated. The Maximalist is not "delegate everything"; it is "delegate by default, retain by choice."

**Delegate when:**
- Task has clear definition of done
- Task is repetitive or pattern-following
- Task involves more typing than thinking
- Task has independent subtasks that can run in parallel
- You have done this kind of task before and know what good looks like

**Keep when:**
- Task is exploratory and the spec emerges from the work itself
- Task involves ambiguous tradeoffs that need human judgment
- Task is a one-line fix where decomposition takes longer than execution
- Task is a learning opportunity for you specifically (deliberate practice)
- You don't yet trust the agent for this domain (still building calibration)

The "keep" list shrinks over time as your delegation skill grows and as the agent's reliability in your domain improves.

---

# Anti-Patterns During The Transition

Avoid:

- **Delegating everything immediately.** Trust calibration takes reps. Start with one type of task you do often (refactors, doc updates, tests), get good at delegating that, then expand.
- **"Quick prompts" instead of specs.** "Fix the bug" is not a delegation; it is a wish. A real delegation has scope, constraints, output format, verification.
- **Treating agent output as untouchable.** You are still the engineer. Edit aggressively when needed; just don't fall back into typing-from-scratch.
- **Skipping the review step.** Maximalist ≠ rubber-stamp. Quality control is now your primary contribution.
- **Optimizing for "agent did 100% of the work" as a vanity metric.** What matters is final quality and your throughput, not agent participation rate.
- **Forcing decomposition on truly atomic work.** A 3-line fix doesn't need a spec. Use judgment.

---

# Signs You're Transitioning Successfully

- You spend more time writing specs and reviewing diffs than writing code
- You routinely dispatch 2~3 things in parallel when work is independent
- You've added at least 3 entries to `CLAUDE.md` in the past month from "agent kept getting this wrong" patterns
- Your token cost per task is going down even as task complexity goes up
- New projects boot faster because you have reusable specs/templates from prior delegation
- Reviewing diffs feels productive, not draining

If most of these are true, you're past Aided. If they're aspirational, you're still in transition.

---

# Signs You've Plateaued

- Same context re-explained to agents every session → Persistent Context gap → see `CONTEXT_AND_TOKEN_GUIDE.md`
- Always serial, never parallel → decomposition skill not developed → practice with deliberately parallelizable tasks
- Review feels like overhead, not value → not yet treating review as primary skill → see Practice 5 above
- Agent quality not improving over time on your projects → `CLAUDE.md` not absorbing the corrections → fix the durable layer
- Cost per task flat or rising → likely Conversation Hygiene + Cache pollution → see `CONTEXT_AND_TOKEN_GUIDE.md` Part 2

Plateaus usually trace to one specific gap, not to "I'm not trying hard enough." Find the gap, fix it.

---

# The Native Transition (Brief)

Maximalist → Native is mostly two things:

1. **The codebase becomes AI-friendly** — see `CHECKLISTS/AI_READY_CODEBASE_SCORECARD.md`. When the codebase scores 80+, agents work reliably enough that you stop thinking about the delegation step. It just happens.
2. **Workflow patterns become invisible** — the slash commands, hooks, and templates fade into background reflex. You no longer "decide to delegate"; the workflow is the work.

Native is not a higher conscious skill than Maximalist. It is Maximalist made automatic by infrastructure. You earn Native by investing in the codebase and tooling, not by trying harder.

---

# Best Long-Term Habit

Once a month, ask:
- What tasks am I still typing entirely by hand? Which of those should now be delegable?
- What patterns did I correct in agents this month? Are they captured in durable docs?
- Is my decomposition getting faster (fewer minutes of spec-writing per task)?
- Are my delegations getting cleaner (fewer back-and-forths per task)?

Track these informally. The trend matters more than the absolute number — Aided → Maximalist is a 3~12 month shift, not a one-week change.
