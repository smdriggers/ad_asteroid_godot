extends Control
# render/hud_view.gd — the flight HUD (DESIGN.md §15.2): level, mode,
# credits, bombs, ore left, cargo. Screen-space overlay; pure drawing,
# reads state from main.gd (set as `main` from main.gd's _ready()).
# Hidden while docked (render/station_shop_view.gd takes over then) and
# while the instructions/game-over screens are up.

var main: Node2D = null

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if main == null:
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 18
	var x: float = Config.HUD_MARGIN
	var y: float = Config.HUD_MARGIN
	var line: float = Config.HUD_LINE_HEIGHT

	draw_string(font, Vector2(x, y), "Level %d" % main.level, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Config.HUD_TEXT_COLOR)
	y += line

	var scanning: bool = main.player_mode == "scan" or PlayerInput.touch_scan
	var mode_text: String = "Mode: SCAN" if scanning else "Mode: MINE"
	var mode_color: Color = Config.SCAN_BEAM_COLOR if scanning else Config.HUD_TEXT_COLOR
	draw_string(font, Vector2(x, y), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, mode_color)
	y += line

	draw_string(font, Vector2(x, y), "Credits: %d" % main.credits, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Config.HUD_TEXT_COLOR)
	y += line

	draw_string(font, Vector2(x, y), "Bombs: %d" % main.ship.bombs, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Config.HUD_TEXT_COLOR)
	y += line

	var ore_pct: int = int(main.ore_fraction * 100.0)  # rounds down — DESIGN.md §15.2
	draw_string(font, Vector2(x, y), "ORE %d%%" % ore_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Config.HUD_TEXT_COLOR)
	y += line

	if DebugFlags.show_speed:
		# Debug readout, not for release: the ship's speed in world px/sec.
		_centered(font, "SPEED %.1f" % main.ship.velocity.length(), Config.HUD_TEXT_COLOR, size.x / 2.0, Config.HUD_MARGIN, font_size)

	if DebugFlags.show_perf:
		# Debug readout, not for release. Objects / orphans climbing steadily
		# during play means a leak; memory reads 0 in release builds, where
		# Godot doesn't track it.
		var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var perf: String = "FPS %d  |  objects %d  |  orphans %d  |  draw calls %d" % [
			Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		]
		if mem_mb > 0.0:
			perf += "  |  mem %.0f MB" % mem_mb
		_centered(font, perf, Config.HUD_TEXT_COLOR, size.x / 2.0, Config.HUD_MARGIN + Config.HUD_LINE_HEIGHT, 14)

	if main.stripped_time != null and main.world_time - main.stripped_time < Config.STRIPPED_MESSAGE_TIME:
		_centered(font, "THE SYSTEM IS STRIPPED", Config.STRIPPED_MESSAGE_COLOR, size.x / 2.0, size.y / 3.0, 22)

	draw_string(font, Vector2(x, y), "Cargo: %d/%d" % [main.cargo.total, main.cargo.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Config.HUD_TEXT_COLOR)
	y += line

	var keys: Array = main.cargo.counts.keys()
	keys.sort()
	for mat_id in keys:
		var count: int = main.cargo.counts[mat_id]
		if count <= 0:
			continue
		var text: String = "%s: %d" % [Materials.name_of(mat_id), count]
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Materials.color(mat_id))
		y += line

func _centered(font: Font, text: String, color: Color, cx: float, y: float, font_size: int) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cx - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
