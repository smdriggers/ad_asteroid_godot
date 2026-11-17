extends Control
# render/game_over_view.gd — shown when the ship is destroyed: the run's
# totals, then Enter starts a completely new game (DESIGN.md §15.4). Pure
# drawing; reads state from main.gd (set as `main` from main.gd's _ready()).

var main: Node2D = null

func _draw() -> void:
	if main == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Config.BG_COLOR)
	var font: Font = ThemeDB.fallback_font
	var cx: float = size.x / 2.0
	var y: float = Config.GAME_OVER_TOP

	_centered(font, "SHIP DESTROYED", Config.TRAJECTORY_CRASH_COLOR, cx, y, 24)
	y += Config.HUD_LINE_HEIGHT * 2.0

	_centered(font, "Money earned: %d" % main.credits_earned, Config.HUD_TEXT_COLOR, cx, y, 18)
	y += Config.HUD_LINE_HEIGHT
	_centered(font, "Distance flown: %d" % int(round(main.ship.distance_flown)), Config.HUD_TEXT_COLOR, cx, y, 18)
	y += Config.HUD_LINE_HEIGHT * 2.0

	_centered(font, "Blocks mined", Config.HUD_TEXT_COLOR, cx, y, 18)
	y += Config.HUD_LINE_HEIGHT
	var keys: Array = Materials.NAMES.keys()
	keys.sort()
	for mat_id in keys:
		var count: int = main.cargo.blocks_mined_by_material.get(mat_id, 0)
		var text: String = "%s: %d" % [Materials.name_of(mat_id), count]
		_centered(font, text, Materials.color(mat_id), cx, y, 16)
		y += Config.HUD_LINE_HEIGHT

	y += Config.HUD_LINE_HEIGHT
	_centered(font, "Press Enter to start over", Config.HUD_TEXT_COLOR, cx, y, 18)

func _centered(font: Font, text: String, color: Color, cx: float, y: float, font_size: int) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cx - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
