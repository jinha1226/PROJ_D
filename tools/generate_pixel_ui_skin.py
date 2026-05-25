#!/usr/bin/env python3
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui" / "pixel"


def _draw_frame(size: tuple[int, int], palette: dict[str, tuple[int, int, int, int]], inset: int = 2) -> Image.Image:
	img = Image.new("RGBA", size, palette["fill"])
	draw = ImageDraw.Draw(img)
	w, h = size

	# Chunky mobile-roguelike frame: warm carved edge, dark inset, hard pixels.
	draw.rectangle((3, h - 4, w - 3, h - 2), fill=palette["shadow"])
	draw.rectangle((w - 4, 3, w - 2, h - 3), fill=palette["shadow"])

	draw.rectangle((0, 0, w - 1, h - 1), outline=palette["edge_dark"], width=2)
	draw.rectangle((2, 2, w - 4, h - 4), outline=palette["edge"], width=2)
	draw.line((3, 3, w - 6, 3), fill=palette["highlight"], width=2)
	draw.line((3, 3, 3, h - 6), fill=palette["highlight"], width=2)
	draw.line((4, h - 6, w - 6, h - 6), fill=palette["lowlight"], width=2)
	draw.line((w - 6, 4, w - 6, h - 6), fill=palette["lowlight"], width=2)
	draw.point((3, h - 5), fill=palette["edge"])
	draw.point((w - 5, 3), fill=palette["edge"])

	if inset > 0:
		draw.rectangle((inset + 5, inset + 5, w - inset - 7, h - inset - 7), outline=palette["inner"], width=1)
	return img


def _draw_slot(size: tuple[int, int], palette: dict[str, tuple[int, int, int, int]]) -> Image.Image:
	img = _draw_frame(size, palette, inset=1)
	draw = ImageDraw.Draw(img)
	w, h = size
	draw.rectangle((8, 8, w - 10, h - 10), fill=palette["well"])
	draw.rectangle((8, 8, w - 10, h - 10), outline=palette["inner"], width=2)
	draw.line((10, 10, w - 12, 10), fill=palette["well_highlight"], width=1)
	draw.line((10, 10, 10, h - 12), fill=palette["well_highlight"], width=1)
	draw.rectangle((5, 5, 6, 6), fill=palette["rivet"])
	draw.rectangle((w - 8, 5, w - 7, 6), fill=palette["rivet"])
	draw.rectangle((5, h - 8, 6, h - 7), fill=palette["rivet"])
	draw.rectangle((w - 8, h - 8, w - 7, h - 7), fill=palette["rivet"])
	return img


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)

	base = {
		"fill": (86, 91, 82, 246),
		"well": (47, 51, 45, 238),
		"well_highlight": (104, 110, 99, 220),
		"shadow": (0, 0, 0, 145),
		"edge_dark": (48, 52, 47, 255),
		"edge": (132, 139, 126, 255),
		"highlight": (194, 199, 180, 255),
		"lowlight": (65, 70, 63, 255),
		"inner": (113, 120, 108, 235),
		"rivet": (210, 214, 192, 255),
	}
	hover = base | {
		"fill": (100, 104, 93, 250),
		"edge": (161, 168, 149, 255),
		"highlight": (226, 231, 205, 255),
		"inner": (137, 144, 128, 245),
		"rivet": (240, 239, 205, 255),
	}
	pressed = base | {
		"fill": (66, 72, 65, 250),
		"well": (36, 39, 35, 242),
		"well_highlight": (70, 76, 68, 230),
		"edge": (101, 111, 99, 255),
		"highlight": (169, 178, 155, 255),
		"inner": (84, 93, 82, 245),
		"rivet": (190, 196, 170, 255),
	}
	disabled = base | {
		"fill": (54, 57, 53, 178),
		"well": (34, 35, 33, 170),
		"well_highlight": (66, 68, 62, 160),
		"edge": (82, 86, 78, 178),
		"highlight": (122, 126, 113, 178),
		"lowlight": (43, 46, 41, 178),
		"inner": (69, 73, 66, 170),
		"rivet": (127, 132, 117, 178),
	}
	panel = base | {
		"fill": (55, 61, 53, 250),
		"edge_dark": (38, 42, 38, 255),
		"edge": (128, 136, 122, 255),
		"highlight": (210, 214, 192, 255),
		"lowlight": (66, 72, 65, 255),
		"inner": (96, 104, 91, 230),
	}

	for name, pal in {
		"button_normal": base,
		"button_hover": hover,
		"button_pressed": pressed,
		"button_disabled": disabled,
		"slot_normal": base,
		"slot_hover": hover,
		"slot_pressed": pressed,
		"slot_disabled": disabled,
	}.items():
		img = _draw_slot((32, 32), pal) if name.startswith("slot_") else _draw_frame((32, 32), pal)
		img.save(OUT / f"{name}.png")

	_draw_frame((48, 48), panel).save(OUT / "panel_window.png")


if __name__ == "__main__":
	main()
