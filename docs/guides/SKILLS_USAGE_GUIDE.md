# Skills Usage Guide

## Purpose
Claude Code (and similar harnesses) supports **skills** — reusable named procedures the agent can invoke on demand. They are the natural home for repeated workflows that are too specific for the agent's general training but too generic to bake into one project's `CLAUDE.md`.

This guide covers:
- What skills are and how they differ from prompts, hooks, and agents
- When to invoke an existing skill vs skip it
- When to write a custom skill vs leave the work in `CLAUDE.md`
- How to design a skill that other sessions will actually use

## Core Principle
A skill is **codified judgment**. It encodes "when situation X arises, do procedure Y" in a way the agent can recall and apply consistently. The point is not to add capability — the agent could already do the procedure. The point is **reliability and shared vocabulary** across sessions.

If a procedure works once and is never repeated, it doesn't need to be a skill. If it works repeatedly but each repetition rediscovers the steps, it should be a skill.

---

# What Skills Are (And Aren't)

| Concept | Lives in | Loaded when | Best for |
|---|---|---|---|
| **Prompt** | The current message | Each turn | One-off instructions |
| **`CLAUDE.md`** | Repo file | Auto every session | Project-specific facts and rules |
| **Skill** | Skill file (frontmatter + body) | When invoked or matched | Reusable procedures spanning many projects |
| **Hook** | `settings.json` | Lifecycle event | Enforced safeguards |
| **Subagent** | Dispatched per call | On invocation | Isolated heavy work |

A skill is the right tool when:
- The procedure applies across multiple projects
- The procedure has multi-step structure that an ad-hoc prompt would garble
- You want the agent to recognize when to apply it (not always be told)
- Different team members or sessions should follow the same procedure

A skill is the wrong tool when:
- The procedure is project-specific (use `CLAUDE.md`)
- The procedure must always run (use a hook, not a skill)
- The procedure is a one-off (use a prompt)
- The procedure requires complex state or external services (use a real tool/script)

---

# When To Invoke An Existing Skill

Most environments come with a set of pre-installed skills (e.g., `superpowers:` skills in Claude Code). Default behavior should be: **invoke when relevant, skip when overhead exceeds benefit.**

## Invoke when
- The skill description matches the current task with high confidence
- You're starting a category of work the skill exists for (e.g., debugging, code review, plan writing)
- You're new to the workflow the skill encodes — let it teach you the procedure
- The skill's discipline is exactly what's needed (e.g., TDD for production code, verification-before-completion before marking done)

## Skip when
- The task is trivial and the skill's ceremony exceeds the work itself ("brainstorming" skill for "rename this variable")
- The user has already been clear about intent and the skill would re-litigate it (e.g., brainstorming after the user already said "implement X exactly")
- You're in tight iteration with a user who values speed over process — let user instructions take precedence
- You've already invoked the skill earlier in the same task and would just re-trigger it

The general rule from Claude Code's own guidance: "if a skill might apply, invoke it." Bias toward invocation in unfamiliar territory; bias toward skipping in fast iteration with a known user.

## When skills conflict with user instructions
**User instructions always win.** A skill that says "always brainstorm first" can be overridden by a user who says "skip the questions, just do it." Skills are defaults, not rules. This is true at the harness level (CLAUDE.md > skill > system default).

---

# When To Write A Custom Skill

Write a custom skill when **you have personally taught the agent the same procedure 3+ times across different sessions or projects**, and the procedure is not project-specific.

Real signals:
- "Every time I start a Postgres migration, I need to remind the agent of these 5 safety steps" → migration skill
- "Whenever I onboard a new repo, I always do the same 4-step exploration" → onboarding skill
- "I keep correcting agents on how to write commit messages for this team" → commit-message skill

Anti-signals (don't write a skill for these):
- "I did this once and it worked" — wait for repetition
- "This is specific to project X" — put it in project X's `CLAUDE.md`
- "I want the agent to always do this" — that's a hook, not a skill
- "I want this to be enforced" — also a hook

## Skill Quality Bar

A good skill:
- **Has a clear trigger description** — the frontmatter `description` is what the agent reads when deciding whether to invoke. It must say *when to use this*, not *what this does*.
- **Is short enough to load without ceremony** — under ~200 lines is comfortable. Skills longer than that probably need to be split or pushed into a real document.
- **Specifies behavior, not philosophy** — concrete steps and decision rules beat abstract advice. "If condition X, do Y; else do Z" beats "be thoughtful about edge cases."
- **Is honest about when to skip itself** — explicit "do not use when..." sections prevent miscalibration.
- **Composes with other skills** — references related skills by name when they should be used together (e.g., a debugging skill referencing a verification skill).

## Skill Frontmatter Pattern

```markdown
---
name: <skill-name>
description: <one sentence: when to invoke this skill — must be specific enough that the agent can match it to a real situation>
---

<body — the procedure, in concrete steps>
```

The `description` is the most important field. It is the only thing the agent sees before deciding to invoke. If the description is vague ("for general code work"), the skill will either be over-invoked or never invoked.

Good description: "Use when implementing any feature or bugfix, before writing implementation code — establishes test-first discipline."

Bad description: "Helpful skill for development tasks."

---

# Skill vs Hook vs CLAUDE.md — Decision Tree

When you have a recurring concern, decide where it lives:

```
Is this concern project-specific?
├─ Yes → CLAUDE.md (root or module)
└─ No → Continue
   │
   Must this happen every time, enforced?
   ├─ Yes → Hook (settings.json)
   └─ No → Continue
      │
      Does the agent need to recognize when to apply it?
      ├─ Yes → Skill
      └─ No → Prompt template (used when manually invoked)
```

Most concerns end up in `CLAUDE.md` because most concerns are project-specific. Skills are the right home for the small subset that genuinely spans projects.

---

# Skill Invocation Discipline

A few rules that prevent skill-invocation noise:

1. **Don't invoke skills you don't intend to follow.** Invoking and ignoring trains bad habits and confuses session intent.
2. **Announce skill invocation to the user.** "Using <skill> for <purpose>" before the action. Lets the user redirect if the skill is wrong for the moment.
3. **Don't double-invoke.** If a skill is already loaded in the current task, don't re-invoke for sub-steps. The procedure is already in context.
4. **Default to invoking process skills before implementation skills.** A debugging skill before a domain-specific fix skill, etc. Process determines how, implementation determines what.
5. **If the user says "skip the skill," skip it.** User intent overrides any "you must always invoke" rule.

---

# Anti-Patterns

Avoid:
- **Skill sprawl.** 50 skills mean the agent can't pick reliably. Better to have 10 well-scoped skills than 50 narrow ones.
- **Project-specific skills.** "Skill for the RWE backend" → put it in RWE's `CLAUDE.md`. Skills are for cross-project knowledge.
- **Skills that duplicate hook behavior.** If you want lint enforcement, write a hook, not a skill called "remember to lint."
- **Skills with vague descriptions.** They will be either ignored or invoked at the wrong times.
- **Skills that just re-state common sense.** A skill for "write good code" adds noise and saves no judgment.
- **Treating skills as documentation.** Documentation is for humans; skills are for agent invocation. If the audience is humans, write a doc and link it from `CLAUDE.md`.

---

# Project Applicability

| Project type | Use existing skills? | Write custom skills? |
|---|---|---|
| Methodology project (this repo) | Process skills (writing-plans, brainstorming) sometimes | Probably none — this repo's content *is* the methodology |
| Solo code project | Yes, lightly | Only if procedures repeat across personal projects |
| Multi-project personal workflow | Yes | Yes — extract patterns common across your projects |
| Team / shared codebase | Yes | Yes — encode team conventions as skills, version-controlled |

For solo work, custom skills are usually overkill. The investment pays back at 3+ projects following the same procedure or a team adopting shared workflow.

---

# Best Long-Term Habit

After every session where you found yourself manually instructing the agent on a multi-step procedure, ask:

1. Have I done this same instruction sequence before?
2. Will I do it again in the next month?
3. Does it apply outside this one project?

If yes to all three → candidate for a custom skill. Draft it before you forget. Refine it the next 2~3 times you invoke it.

If yes to (1) and (2) but no to (3) → it belongs in that project's `CLAUDE.md` instead.

If no to (2) → it was a one-off; nothing needs to be saved.

This converts repeated typing into reusable procedure, which is the AI-Maximalist way of building leverage. See `DELEGATION_MINDSET_GUIDE.md` for the broader mindset.
