# Korean Font

This project requires a Korean-capable font for the UI. The default Godot font
has no CJK glyphs, so all hangul renders as tofu.

## Required file

Place one of the following at `assets/fonts/Pretendard-Regular.otf`:

### Option A — Pretendard (recommended, lightweight, SIL OFL)

```bash
curl -L -o assets/fonts/Pretendard-Regular.otf \
  "https://github.com/orioncactus/pretendard/raw/main/packages/pretendard/dist/public/static/Pretendard-Regular.otf"
```

### Option B — Noto Sans KR (Google Fonts, SIL OFL)

Download `NotoSansKR-Regular.otf` from
https://fonts.google.com/noto/specimen/Noto+Sans+KR and rename it to
`Pretendard-Regular.otf`, OR edit `assets/theme/default_theme.tres` to point at
the new filename.

## License

Both fonts are SIL Open Font License 1.1 — free for commercial use. See
`CREDITS_FONTS.md` at the project root for attribution.
