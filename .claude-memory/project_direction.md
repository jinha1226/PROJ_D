---
name: PROJ_D next-phase direction
description: 2026-04-21 user decision on post-DCSS-core work. Marketplace/companions over god-full-parity.
type: project
originSessionId: a6787a73-c32f-4d97-bf7b-67620bf7e827
---
## 2026-04-21 direction decision

User weighed three paths after wholesale DCSS ports stabilized:
1. Finish 26 gods to full parity (Vehumet MP discount, Okawaru gifts, Ru sacrifices, Gozag gold economy, Ashenzari curse-boost, etc.)
2. Expand essence system (drops / fusion / upgrades / synergy with gods)
3. Village hub + companions

**Decision logged but not started:** prefer village + companions as the long-run identity differentiator (distinguishes us from a plain DCSS port), with god-parity only bumped for the 4-5 most popular deities (Trog / Makhleb / Okawaru / Sif Muna / Ashenzari) as a side task.

**Companion AI concern raised**: user worries about path-jam / stuck-on-stairs / friendly-fire. Mitigations pre-agreed:
- Start with **1 companion max** (N≥2 is the pathing-hell inflection point)
- Escape hatch: if companion >3 turns out of LOS, teleport to player's side
- Reuse existing `scripts/entities/Companion.gd` + `CompanionAI.gd` (already ~200 lines shipping via god invocations) rather than a fresh AI tree

**Suggested order if resumed:**
1. Village/town static hub (zero AI risk, biggest UX payoff) — 3-4 sessions
2. Companion recruitment + persistence across floors — 2 sessions
3. Essence system expansion (drops/synergy) — 1-2 sessions
4. Selected god full-parity — ad hoc, 1 god per session

Do NOT start on companion AI without first stabilising floor-transition persistence (companion follow-up-stairs + reappear-near-player logic).
