extends Control
# render/instructions_view.gd — the controls screen shown once at startup,
# dismissed by any key or mouse click (DESIGN.md §15.1). Pure drawing;
# main.gd owns the showing_instructions flag and hides this node.

const LINES: Array[String] = [
	"Q / E       - rotate ship",
	"W / S       - thrust forward / back",
	"A / D       - strafe left / right",
	"Shift       - precision (half speed)",
	"Mouse wheel - adjust auto-zoom",
	"G           - switch between mine and scan modes",
	"Hold LMB / Space, mine mode - fire laser at asteroids",
	"Hold LMB / Space, scan mode - beam reveals the ore it touches",
	"Arrows / Enter - pick and buy upgrades at the station",
	"Tab         - launch from the station",
]

const TOUCH_LINES: Array[String] = [
	"Left stick  - point the ship; push further to thrust",
	"            (small push = aim only, medium = half thrust)",
	"BLAST       - fire laser at asteroids",
	"BOMB        - drop a bomb (buy them at the station)",
	"SCAN        - hold to reveal the ore the beam touches",
	"Station     - tap a tile to select, tap again to buy",
]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Config.BG_COLOR)
	var font: Font = ThemeDB.fallback_font
	var cx: float = size.x / 2.0
	var y: float = 100.0

	_centered(font, "Ad Asteroid", Config.HUD_TEXT_COLOR, cx, y, 28)
	y += Config.HUD_LINE_HEIGHT * 2.0

	var touch: bool = PlayerInput.touch_ui()
	for text in (TOUCH_LINES if touch else LINES):
		_centered(font, text, Config.HUD_TEXT_COLOR, cx, y, 16)
		y += Config.HUD_LINE_HEIGHT

	y += Config.HUD_LINE_HEIGHT
	_centered(font, "Tap to begin" if touch else "Press any key to begin", Config.HUD_TEXT_COLOR, cx, y, 18)

func _centered(font: Font, text: String, color: Color, cx: float, y: float, font_size: int) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cx - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
