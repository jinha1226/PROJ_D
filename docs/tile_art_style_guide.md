# PocketCrawl Tile Art Style Guide

## Core Direction
PocketCrawl tile art should read as a small but clear remaster of DCSS tiles.
The goal is not high-resolution illustration. The goal is strong readability at gameplay size.

Priority order:
1. Readability at 32x32
2. Strong silhouette
3. DCSS-compatible front-facing composition
4. Slightly upgraded detail over original DCSS
5. Atmosphere

## Working Resolution
All final production tiles should be authored directly for 32x32 use.
Do not rely on drawing large and shrinking later as the main workflow.
If a larger sketch is used during concepting, the accepted final must be cleaned at 32x32.

## Camera / Pose Rules
- Default view is front-facing.
- Humanoids should be as front-facing as possible.
- Player-usable humanoids must always use a strict front-facing sprite base.
- Non-humanoids may use slight angle only if their species becomes clearer that way.
- Avoid dramatic perspective, side view, or dynamic illustration poses.

## Proportion Rules
- No SD or chibi proportions.
- Keep the tall DCSS-style body ratio.
- Head should stay relatively small.
- Body and legs must remain readable.
- Small races, medium races, and large races should feel different in scale group, but still follow the same front-facing structure.

## Detail Rules
- Slightly more detail than original DCSS is good.
- Tiny decorative noise is not helpful.
- Favor large readable forms over tiny surface detail.
- One or two signature features should dominate the tile.

Good detail examples:
- clear shoulder shape
- readable weapon silhouette
- strong hood, helm, skull, book, or flame motif
- large hands, jaw, ears, horns, or tail if species needs it

Bad detail examples:
- tiny jewelry everywhere
- layered cloth folds that vanish at game size
- subtle texture patterns only visible when zoomed in

## Line and Value Rules
- Keep a strong dark outline.
- Interior lines should be selective.
- Use larger value grouping than painterly micro-shading.
- Highlights should be sparse and intentional.
- A tile should still read when viewed quickly on a phone screen.

## Color Rules
- Slightly cleaner and richer than raw DCSS is fine.
- Do not oversaturate.
- Maintain dungeon mood.
- Use one dominant color family per tile and only a few support colors.

Suggested altar palette anchors:
- War: iron, ember red, ash orange
- Arcana: blue-violet, white-blue glow
- Trickery: green, teal-black, shadow accents
- Death: bone, lavender, deep purple-black
- Essence: amethyst, pale violet flame, rune glow

## Humanoid Base Rules
Humanoid sprites are not one-off monster paintings. They are body templates.
They must support equipment overlays and player use.

Use 3 standardized body classes:
- humanoid_small
- humanoid_medium
- humanoid_large

Rules:
- Within each size class, body pixel structure should stay consistent.
- Head, shoulders, torso, hips, knees, and feet should stay in stable positions.
- Race differences should come mostly from skin tone and a few silhouette traits.
- Keep the body simple enough that armor and weapons can sit on top cleanly.

## Race Differentiation Rules
Race distinction should come from:
- skin tone
- ear shape
- jaw width
- eye brightness
- horn or hair silhouette
- hand/foot bulk

Do not rebuild the full body for every humanoid race.
The shared base matters more than per-race flourish.

## Equipment Overlay Rules
Equipment compatibility is a first-class requirement.
All humanoid tiles should be easy to dress with:
- weapon overlays
- armor overlays
- helmet overlays
- cloak overlays
- shield overlays
- boots or lower-body accents if needed

This means:
- torso area must stay readable
- weapon hand positions must be stable
- shoulder width should not fluctuate wildly inside the same size class
- no large decorative forms should occupy overlay zones unless that species requires it

## Monster Rules
### Humanoids
Humanoid monsters should follow the same visual language as player-usable bodies.
They may get simpler or rougher equipment, but the body logic should remain compatible.

### Non-humanoids
Non-humanoid monsters should emphasize one or two iconic traits only.
Examples:
- adder: head shape and curve of body
- ogre: huge shoulder mass and club
- goblin: small frame, ears, rough blade
- dragon: head, chest, wing mass
- troll: arms, jaw, hunched mass

## Item Rules
- Item silhouette matters more than texture.
- Ring, potion, scroll, wand, and weapon shapes must read instantly.
- Use color and one strong icon cue rather than many tiny details.

## Altar Rules
- Front-facing
- Strong central symbol
- One readable base pedestal
- Avoid over-complex mashups that become noisy at 32x32
- Reuse DCSS altar logic where possible, but simplify to what actually reads

## Acceptance Checklist
A tile is ready only if it passes these checks:
1. Reads clearly at 32x32 actual gameplay size
2. Still fits next to original DCSS tiles without looking like a different game
3. Has one dominant silhouette and no noisy clutter
4. Works with intended overlays if humanoid
5. Still makes sense on a phone screen at a quick glance

## Production Workflow
1. Pick the base type or reference tile.
2. Define the dominant silhouette.
3. Block the tile directly for 32x32 readability.
4. Add only the detail that survives gameplay size.
5. Check against neighboring tiles for consistency.
6. If unsure, remove detail before adding more.

## Current Project Decision
PocketCrawl should use direct 32x32 production tiles rather than a higher-resolution base-first workflow.
The style target is "DCSS remaster" rather than SD, painterly, or highly rendered fantasy art.

## Humanoid Size Specs
### Small
- Use the same frontal body logic as medium, but reduce shoulder width and total leg mass.
- Good for kobold- and spriggan-scale silhouettes.
- Ears, eye glow, and head shape should carry more identity than body bulk.

### Medium
- Default player and humanoid baseline.
- Human, elf, orc, and most armed delver silhouettes should derive from this class.
- Armor overlay anchors should be authored from this class first.

### Large
- Preserve the same body plan, but widen torso, forearms, and stance.
- Good for troll-, ogre-, and heavily built humanoid variants.
- Keep readable front posture rather than turning them into side-view brutes.

### Shared Anchor Rule
- Head top, shoulder line, hand hold zone, torso center, hip line, and feet base should stay predictable across each class.
- Equipment overlays may scale between small/medium/large, but anchor logic must stay consistent.
