# scripts/systems — Gameplay systems

## What
Combat, magic, faith, item registry, monster AI, zone definitions, and progression rules. These should be the *single authority* for state changes in their domain — UI must route through them, not bypass.

## Key files
```
CombatSystem.gd    — attack resolution, brand, retaliation, backstab
MagicSystem.gd     — spell dispatch, AOE, scaling, projectile damage
FaithSystem.gd     — faith id normalization, getter API for bonuses
ItemRegistry.gd    — item generation, randart roll, brand stamp
MonsterAI.gd       — turn behavior, awareness propagation
ZoneManager.gd     — branch monster pools, terrain palette
```

## Domain rules
- Faith state authority: `FaithSystem`, never UI. Empty `faith_id` is migration-state only when `first_shrine_choice_done == true`.
- Resists are 4 types (fire/cold/poison/will) — do not re-expand without explicit decision.
- Combat damage pipeline order should be (1) base, (2) flat additions, (3) multiplicative chain, (4) brand extra. Currently mixed in one accumulator (audit H7).
- Brand detection: weapon checks `entry.brand` then base; armor currently only `entry.brand` — slot asymmetry (audit M5).

## Known dead data (audit H2, P3)
`FaithSystem.FAITHS` defines 8 keys not read anywhere:
- `defense_effectiveness_mult`, `shield_block_bonus` (war)
- `magic_xp_mult`, `defense_xp_mult` (war/arcana XP)
- `agility_effectiveness_mult`, `tool_effectiveness_mult`, `detect_range_mod` (trickery)
- `undead_damage_mult` (death)
- `essence_penalty_reduction` (essence)

Action: either wire into CombatSystem/XP/FOV, or remove from data and update player-facing text. Do not leave advertising what doesn't fire.

## AOE stubs (audit H1)
`Player.use_item` checks `game_node.has_method("apply_fear_aoe")` etc. — only `apply_immolation_aoe` exists. Stubs needed (or rewrite Player.gd to use `AoeEffects.gd` static helpers): `apply_fear_aoe`, `apply_fog_aoe`, `apply_silence_aoe`, `alert_all_monsters`, `dig_toward`. Until fixed, scrolls/wands consume + auto-identify with no effect.

## Modification rules
1. New combat/magic logic does not get added to `CombatSystem.gd` / `MagicSystem.gd` — extract a helper or new module.
2. When adding a faith data key, wire its read-site at the same commit.
3. UI dialogs do not call `set_equipped_*` directly anymore; that goes through Player API which decides turn cost.
4. `static var X = Engine.get_main_loop()...get_node_or_null("/root/X")` is forbidden — autoloads are auto-global.

## If you change X, also check Y
- Skill ID rename → `Game.gd` `_apply_loaded_player_state` migration table, race aptitudes, balance docs.
- Brand list → ItemRegistry weighting, weapon and armor brand getters (slot asymmetry M5).
- Faith bonus → corresponding code site + status/help text.
