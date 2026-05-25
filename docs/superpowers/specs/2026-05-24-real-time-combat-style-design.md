# Real-Time Combat Style Design

**Date:** 2026-05-24
**Status:** Planning document only
**Scope:** Preserve the current turn-based rules as a backup path, then prototype a real-time style control/combat layer.

---

## 1. Goal

Shift the player-facing combat feel from strict turn-based input into a mobile-friendly real-time style:

- Movement uses a 4-direction control.
- Basic attacks are automatic.
- The player has active defensive buttons: dodge and parry.
- Existing dungeon, map, monster, item, skill, and elemental systems should remain usable.
- The current turn-based system must stay recoverable during the transition.

This is not a full rewrite of the game. The first target is a playable real-time combat prototype that reuses the current combat formulas, monsters, maps, statuses, and UI where possible.

---

## 2. Design Direction

### Player Control

The core loop becomes:

1. Player holds or taps one of four directions.
2. Character moves at a rate derived from movement speed.
3. If an enemy is in attack range, the character attacks automatically after attack cooldown.
4. Player uses dodge or parry to answer enemy attacks and boss patterns.

Manual bump-attacking should no longer be the primary action. Directional input is for positioning.

### Attack Model

Auto attack should be predictable and readable:

- Melee weapons attack the nearest adjacent hostile.
- Ranged weapons attack the nearest visible hostile in line of fire.
- Magic starter/basic staff can either:
  - auto-cast a simple bolt at visible target, or
  - keep auto attack as weak staff melee until active spell controls are redesigned.

Initial recommendation: melee and ranged auto attack first; magic can keep existing targeted spells until the real-time prototype is stable.

### Defense Model

Dodge and parry should be short-window actions, not passive stats.

- **Dodge**
  - Brief invulnerability or hit-avoidance window.
  - Moves or steps the player if a direction is held.
  - Has cooldown.
  - Scales with movement speed / agility-style stat.

- **Parry**
  - Brief frontal block window.
  - Works best against melee attacks and some projectiles.
  - Poor or invalid against AoE, clouds, traps, and large boss slams unless explicitly marked parryable.
  - Successful parry can stagger the attacker or speed up the next auto attack.

---

## 3. Turn-Based Backup Strategy

The existing `TurnManager` should not be deleted in the first implementation.

Recommended approach:

- Add a combat mode switch:
  - `TURN_BASED`
  - `REAL_TIME`
- Keep the current turn-based path intact behind `TURN_BASED`.
- Implement real-time ticking as a new runtime layer that can coexist with existing systems.
- Avoid changing save format until the real-time prototype proves stable.

This makes rollback simple if the real-time model feels wrong or breaks important systems like stairs, shops, spell targeting, or boss logic.

---

## 4. Real-Time Runtime Model

### Time Tick

Use a fixed simulation tick instead of one action per turn.

Recommended first values:

- Simulation tick: `0.05s` or `0.1s`
- Player movement cooldown: derived from `Player.movement_action_cost()`
- Player attack cooldown: derived from `Player.attack_action_cost()`
- Monster decision interval: derived from monster speed / current action cost

The goal is not animation-frame perfect combat. It should feel responsive while preserving roguelike stat meaning.

### Monster AI

Existing monster AI can be adapted by giving each monster its own action timer.

When a monster timer is ready:

- If adjacent, attack.
- If it has a boss pattern and cooldown is ready, use pattern.
- Otherwise path toward player or reposition.

Important: boss telegraphs should remain readable. Bosses need wind-up time before large attacks.

### Player Cooldowns

The player should have separate cooldowns:

- `move_cooldown`
- `attack_cooldown`
- `dodge_cooldown`
- `parry_cooldown`
- optional `global_recovery` after heavy actions

This lets weapons keep identity:

- Dagger: fast attack, low damage.
- Sword: balanced.
- Mace/axe/heavy weapon: slower, harder hit, stronger stagger/parry reward.
- Spear: slightly longer reach if supported later.
- Bow: needs line of sight and attack cadence.

---

## 5. UI Requirements

### Mobile Combat Controls

First prototype layout:

- Left side: 4-direction cross pad.
- Right side:
  - Dodge button.
  - Parry button.
  - Optional spell/item button remains for later.

### HUD Stats

The existing visible combat stats should stay:

- Attack
- Defense
- Movement speed
- Attack speed

For real-time mode, movement speed and attack speed become more important and should update when equipment/status changes.

### Feedback

Real-time mode needs clearer immediate feedback than turn-based mode:

- Auto attack cooldown flash or small swing indicator.
- Dodge cooldown fill.
- Parry success effect.
- Boss wind-up marker.
- Wet/electric, fire/wet, cold/wet reactions should show short text popups or status icons.

---

## 6. Balance Targets

### Early Melee

The early melee character should feel reliable:

- Basic melee hit rate should not feel like repeated whiffs.
- First-floor enemies should die in a small number of clean hits.
- Dodge should save the player from poor positioning, not be required every hit.
- Parry should reward timing but not be mandatory for normal monsters.

### Weapon Identity

Real-time weapon tuning should use cooldown and reach more than raw damage only.

| Weapon Type | Real-Time Identity |
|---|---|
| Dagger | Very fast, low damage, good after dodge |
| Sword | Stable baseline, easiest starter |
| Mace | Slower, high stagger/parry payoff |
| Axe | High damage, wider recovery |
| Spear | Safer spacing if reach is implemented |
| Bow | Positional ranged auto attack |
| Staff | Magic bridge, later tied to spell auto-cast |

### Monster Count

Since movement is real-time, monster density needs retesting.

- More monsters can feel better if the player has active defense and auto attack.
- Too many adjacent enemies can become unfair because turns no longer serialize clearly.
- First prototype should keep the increased map/monster counts but cap simultaneous melee pressure around the player.

---

## 7. Existing Mechanics To Preserve

The following systems should continue to matter:

- Fixed main dungeon floors and branch maps.
- District/zone concept for map structure and monster/object placement.
- Stair guardians before floor transitions.
- Boss size/readability.
- Elemental reactions:
  - Wet + electric: increased damage.
  - Wet + fire: wet removed, fire moderated.
  - Wet + cold: freeze.
  - Poison + fire cloud: fire conversion.
  - Acid/corrosion.
- Skill scaling and low-zone XP reduction.
- Starter split: melee / ranged / magic.

Real-time mode should not discard the roguelike build structure. It changes input and pacing first.

---

## 8. Implementation Phases

### Phase 0: Document And Backup

Goal: make the current turn-based state easy to recover.

Tasks:

- Keep this planning document as the design reference.
- Before real-time implementation, create a git commit or branch that captures the current turn-based build.
- Record known current behavior: movement, attack, skill XP, monster AI, boss guardian flow.

Exit gate:

- Current build launches with headless Godot check.
- Turn-based version is recoverable by branch or commit.

### Phase 1: Runtime Mode Switch

Goal: add mode separation without changing gameplay yet.

Tasks:

- Add a combat mode enum or config.
- Route turn-based behavior through the existing path.
- Add a real-time update loop scaffold that is disabled by default.

Exit gate:

- Turn-based mode still works exactly as before.
- Real-time mode can be enabled for local testing without deleting turn-based behavior.

### Phase 2: Real-Time Player Movement

Goal: move the player with cooldown-based directional input.

Tasks:

- Add directional input state.
- Convert movement into a cooldown/timer action in real-time mode.
- Keep collision, stairs, props, water/lava, traps, and field-of-view updates working.

Exit gate:

- Player can move through the current maps in real-time mode.
- Blocking props still block movement.
- FOV updates while moving.

### Phase 3: Auto Attack

Goal: remove manual bump-attack dependence.

Tasks:

- Add target selection for melee/ranged.
- Add player attack cooldown.
- Reuse existing combat damage/hit logic where possible.
- Show attack feedback.

Exit gate:

- Melee starter clears first-floor enemies using movement + auto attack.
- Ranged starter can shoot visible enemies if line of fire is valid.

### Phase 4: Monster Timers

Goal: make monsters act in real time.

Tasks:

- Give monsters action timers.
- Adapt existing chase/attack/pattern behavior to timer-ready decisions.
- Add pressure limits if too many enemies attack simultaneously.

Exit gate:

- Normal monsters chase and attack without the turn loop.
- Boss guardians still use readable patterns.

### Phase 5: Dodge And Parry

Goal: add active defensive play.

Tasks:

- Add dodge window/cooldown.
- Add parry window/cooldown and frontal check.
- Define which attacks are parryable.
- Add UI buttons and keyboard bindings.

Exit gate:

- Dodge avoids damage during a short window.
- Parry blocks or counters valid attacks.
- Boss AoE and elemental hazards remain dangerous.

### Phase 6: Balance Pass

Goal: tune feel and fairness.

Tasks:

- Tune weapon cooldowns.
- Tune monster attack cadence.
- Tune boss wind-up time.
- Tune wet/electric and other reaction damage in real-time pacing.
- Tune starting melee/ranged/magic survivability.

Exit gate:

- First floor is readable and fair.
- Melee feels reliable.
- Ranged and magic have distinct play patterns.
- Boss guardians are recognizable and avoidable.

---

## 9. Risks

### Risk: Existing Systems Assume Turn End

Many systems may currently trigger on `TurnManager.end_player_turn()`.

Mitigation:

- Replace "turn ended" dependencies with "action completed" or "simulation tick" hooks only where needed.
- Do not delete the turn manager until equivalent hooks exist.

### Risk: UI Becomes Too Crowded

Mobile controls, HUD stats, inventory, spells, log, and map can compete for space.

Mitigation:

- Start with direction + dodge + parry only.
- Keep spell/item redesign for a later pass.

### Risk: Boss Patterns Become Unfair

Turn-based warning timing may not translate directly to real-time.

Mitigation:

- Give every boss pattern wind-up, warning tiles, and recovery.
- Larger boss sprites must not imply larger collision unless explicitly designed.

### Risk: Auto Attack Chooses Bad Targets

Bad target selection can make the player feel out of control.

Mitigation:

- Prefer nearest hostile in facing direction.
- If none, prefer nearest visible hostile.
- Later add target lock only if needed.

---

## 10. Initial Recommendation

Proceed with a prototype, but only after preserving the current turn-based version in git.

The safest first playable target is:

- Current dungeon/maps unchanged.
- Real-time mode optional.
- Directional movement working.
- Melee auto attack working.
- Monsters still simple but timer-based.
- Dodge implemented before parry.
- Boss guardians retuned after core movement/attack feels good.

Do not rebalance every class, spell, and monster before the control model is proven. The control feel comes first; full balance comes after.
