---
name: Prefer prior Read output over re-reading
description: Rule about how to handle file reads to conserve context in long sessions — cite prior reads instead of re-opening the same file region
type: feedback
originSessionId: bda8e519-d968-4fec-8b43-05dd2de5b447
---
When a file was already read earlier in the same conversation and is unlikely
to have changed (no external edits, no user-triggered regen, no time gap
spanning an out-of-band refactor), use that prior content directly instead
of issuing a fresh `Read` call. Apply this to every tool choice:

- For `Edit`: trust the prior-read text as the `old_string`. If the edit
  fails with "string not found", THEN re-read the section to get the
  current state — don't speculatively re-read first.
- For locating a symbol: use `Grep` with line numbers, then only `Read`
  the specific window around the match (offset + limit ≤ 50 lines for
  big files).
- For code review / cross-reference: cite the earlier Read's line numbers
  in the response instead of pulling them again.

**Why:** The user can't easily supply line numbers to kick off each task,
so the efficiency burden is on me. In a prior long session (2026-04-22)
file reads alone consumed ~77k tokens (~8% of context); most of that was
re-reading `GameBootstrap.gd` and similarly-large files across turns
when the earlier read was still valid. Conserving these tokens
directly extends how long a session can run before autocompact triggers.

**How to apply:**
- Before calling `Read`, ask: "did I already see this section in this
  conversation, and is it still valid?" If yes, skip the call.
- On large files (>1000 lines), default to `Grep` + narrow `Read` — never
  dump the whole file unless the user asks for a full audit.
- When the `Edit` tool returns "File has been updated successfully",
  treat that as ground truth for the changed region — don't verify via
  a follow-up `Read`.
- Re-read only when: (a) `Edit` failed, (b) file was touched by Bash /
  outside the session, (c) the user reports a symptom that implies my
  mental model is stale.
