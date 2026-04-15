extends Node
## Procedural fallback stub. The LPC pipeline in PROJ_D requires real ULPC
## assets; if we reach a SpriteGenerator path, that's a configuration bug.
## Fail loudly rather than silently hiding broken sprite composition.

func create_skeleton_frames(_tint: Color = Color.WHITE) -> SpriteFrames:
	push_error("SpriteGenerator fallback invoked — ULPC monster sheet missing. Fix assets instead of relying on procedural placeholder.")
	return SpriteFrames.new()
