class_name GameTheme
extends Node

## Typography scale — single source of truth for dialog font sizes.
## Use these constants instead of hardcoded numbers in `add_theme_font_size_override`.
## Mobile target: body 20-24, title 28-32, caption 16-18 (4.5:1 contrast assumed
## via theme colors). Scale up by ≥2 between adjacent levels to keep hierarchy
## clear at small phone sizes.
##
## Usage:
##   lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
# Sizes are Galmuri11 multiples (11/22/33/44) for clean pixel-grid alignment.
# Off-multiple sizes produce slight aliasing on the pixel font — accept it for
# fine-print only. Hierarchy via color/weight/spacing where size collapses.
const TYPO_CAPTION: int = 22      # tips, hints, fine-print (was 18)
const TYPO_BODY: int = 22         # default running text, descriptions (2x)
const TYPO_BODY_LARGE: int = 22   # action button labels, prominent values
const TYPO_LABEL: int = 22        # row item names (bag entries, etc.)
const TYPO_SUBTITLE: int = 33     # row entity names with hierarchy (3x)
const TYPO_TITLE: int = 33        # dialog content headings, player name
const TYPO_HEADER: int = 33       # top-of-dialog headers
const TYPO_DISPLAY: int = 44      # large glyphs, hero counts (4x)

## Tap-target sizing — Android Material guideline is 48dp minimum.
## At 720×1280 viewport on phone, 1px ≈ 1dp.
const TAP_MIN_HEIGHT: int = 48
const ROW_MIN_HEIGHT: int = 56    # list rows (more comfortable than min tap)

## Layout spacing — keep dialog padding/separation consistent.
const PAD_S: int = 4
const PAD_M: int = 8
const PAD_L: int = 12
const PAD_XL: int = 16

## Static path to the master theme. Edit visuals there; this file holds only
## the layout/typography token constants and the loader entry point.
const THEME_PATH: String = "res://assets/theme.tres"

static func create() -> Theme:
	# Returns the same shared resource — Godot caches loads, so callers don't
	# duplicate stylebox memory. Mutating the returned Theme would affect every
	# user, but no caller currently mutates it.
	return load(THEME_PATH) as Theme
