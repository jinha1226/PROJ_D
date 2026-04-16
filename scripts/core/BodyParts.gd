extends Node
## Minimal BodyParts autoload stub for LPCSpriteLoader.
## PROJ_B has a rich limb-damage system; we only need the PartStatus enum here
## because LPCSpriteLoader.DAMAGE_TINT keys on it. Damage-tint code paths are
## never invoked by Player/Monster in PROJ_D (damage_status is always {}),
## but the enum must resolve at parse time for the const dict.

enum PartStatus { HEALTHY, WOUNDED, CRIPPLED, LOST }
