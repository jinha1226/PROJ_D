---
name: PROJ_D next-phase direction
description: 2026-04-22 direction pivot — complete faithful DCSS port FIRST, then Pixel Dungeon mobilize as a second pass. Optional "original DCSS experience" mode toggle.
type: project
originSessionId: a6787a73-c32f-4d97-bf7b-67620bf7e827
---

## 2026-04-22 direction pivot (supersedes 2026-04-21 village-first plan)

User locked in the sequencing question: **complete the faithful DCSS
0.34 port first, THEN do the Pixel Dungeon mobile simplification as a
second pass on top of a finished base**. Rationale: don't simplify
systems you haven't fully understood / implemented yet. A toggle or
post-clear unlock can expose the "original DCSS experience" alongside
the mobilized default for players who want it.

### What this means in practice

1. **Current phase — port completion.** Everything not yet ported or
   only flag-registered needs real implementation. Accept the scope.
2. **Next phase — mobilization layer.** UX compression, help scaffolds,
   progression pruning, glance-and-tap friendliness. The port becomes
   the backing store; mobile UX is a presentation layer.
3. **Option toggle** (future): settings switch between "faithful
   DCSS" and "mobilized" presentations — same systems, different UX.

### Retracted

The 2026-04-21 plan that deferred 26-god parity in favor of
village+companions is now deprioritized. Village + companions still
live as a long-run differentiator, but they come AFTER faithful port
completion.

### Order for port completion (rough, based on gaps as of 2026-04-22)

1. **Gods — 26-deity full parity** (the single biggest gap)
   - Invocations (per-god abilities scaled by Invocations skill)
   - Passives (Vehumet/Chei/Gozag/Ru/etc.)
   - Conducts (done for 7/26; expand to all)
   - Gifts (Trog/Okawaru weapons, Sif spellbooks, etc.)
2. **Portal vaults** — 10 types (Sewer/Ossuary/Bailey/Volcano/Icecave/
   Wizlab/Trove/Labyrinth/Desolation/Gauntlet). Timed mini-branches.
3. **Unrandart roster** — expand 22 → 200 entries. Data-entry heavy.
4. **Transformation full scaling** — add Shapeshifting skill so
   unarmed_scaling / ac_scaling fire.
5. **Status effects rest** — Silenced zone (needs aura monsters),
   Enthralled (needs friendly-monster state), Liquefaction (needs
   Liquefy Earth spell + LIQUEFIED tile).
6. **Mutations effects** — 216 mutations data loaded; many have no
   mechanical handler yet.
7. **Branch visual differentiation** — acid floor tile, glass /
   translucent walls, crystal walls (Zot), tombstones (Crypt).
8. **Beam fills** — set-on-fire (burn_wall), beam bouncing
   (lightning), reflection for spells (not just missiles).
9. **Full ranged combat** — throwing-vs-firing split, ammo (if we
   keep DCSS pre-0.30 style), range-band UI.
10. **Floor gen for every branch** — Hell/Pan/Abyss/Zot special
    layouts (not just the default overlapping-boxes fallback).

### What NOT to start yet

- Village hub / companion expansion beyond what's shipped.
- Mobile-specific UX cuts (those come in Phase 2).
- New non-DCSS systems (Essence is already custom enough — freeze
  scope until port is complete).

### How to apply

- Every new PR should ask: "does this close a DCSS-parity gap or
  does it add non-DCSS scope?" Non-DCSS scope is deferred.
- Keep referencing crawl/source/ in code comments so the port remains
  auditable.
- When porting a new system, match DCSS formulas first, simplify
  later during Phase 2.
