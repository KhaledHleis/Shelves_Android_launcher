class_name Style
extends RefCounted
## One place for colours and sizes, so the look can be themed in v0.6 without
## hunting through every script.

const BG_DARK := Color(0.054, 0.058, 0.082)
const BG_MID := Color(0.11, 0.12, 0.18)
const TEXT := Color(0.93, 0.94, 0.97)
const TEXT_DIM := Color(0.60, 0.63, 0.72)
const ACCENT := Color(0.98, 0.45, 0.32)
const GOOD := Color(0.42, 0.85, 0.55)
const WARN := Color(0.97, 0.72, 0.30)
const BAD := Color(0.93, 0.35, 0.35)
const PANEL := Color(0, 0, 0, 0.35)

const SURFACE := Color(0.14, 0.15, 0.20)
const SURFACE_HI := Color(0.90, 0.91, 0.95)
const ON := Color(0.25, 0.72, 0.42)
const OFF := Color(0.80, 0.28, 0.30)

const RADIUS := 999            ## fully rounded, which is what makes it a pill
const CARD_RADIUS := 14

## One scale, each step a little over 1.25x the last, so sizes relate to each
## other instead of being picked per screen.
const FONT_CAPTION := 20
const FONT_SMALL := 24
const FONT_BODY := 30
const FONT_HEADING := 38
const FONT_TITLE := 48

const BAR_HEIGHT := 96
const PROMPT_ICON := 40
const GUTTER := 56                ## distance from the screen edge, everywhere
const GAP := 14                   ## between things that belong together


## A rounded fill. radius 999 gives a pill, smaller gives a card.
static func pill(color: Color, radius: int = RADIUS, border: Color = Color(0, 0, 0, 0),
		border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	if border_width > 0:
		box.set_border_width_all(border_width)
		box.border_color = border
	return box
