extends Control
# render/station_shop_view.gd — the station screen (DESIGN.md §12.3,
# §13.4): what just sold, credits counting up, and the upgrade shop as a
# grid of tiles. Pure drawing; reads state from main.gd (set as `main`
# from main.gd's _ready()). Only shown while docked.

var main: Node2D = null

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if main == null:
		return
	# The world (bodies, ship, asteroids) keeps rendering underneath this
	# CanvasLayer while docked, so black it out first — matches pygame's
	# screen.fill(BG_COLOR) at the top of every frame's draw().
	draw_rect(Rect2(Vector2.ZERO, size), Config.BG_COLOR)
	var font: Font = ThemeDB.fallback_font
	var cx: float = size.x / 2.0
	var y: float = Config.STATION_TEXT_TOP

	_centered(font, "Level %d - docked, cargo sold" % main.level, Config.HUD_TEXT_COLOR, cx, y, 20)
	y += 48.0

	if main.last_sale_breakdown.is_empty():
		_centered(font, "(nothing to sell)", Config.HUD_TEXT_COLOR, cx, y, 16)
		y += 24.0
	else:
		var keys: Array = main.last_sale_breakdown.keys()
		keys.sort()
		for mat_id in keys:
			var count: int = main.last_sale_breakdown[mat_id]
			var value: int = Materials.value(mat_id)
			var text: String = "%s x%d = %dcr" % [Materials.name_of(mat_id), count, count * value]
			_centered(font, text, Materials.color(mat_id), cx, y, 16)
			y += 24.0

	y += 24.0
	var progress: float = clamp(main.sale_countup_timer / Config.STATION_COUNTUP_TIME, 0.0, 1.0)
	var shown_credits: int = main.credits - main.last_sale_total + int(round(main.last_sale_total * progress))
	_centered(font, "Credits: %d" % shown_credits, Config.HUD_TEXT_COLOR, cx, y, 18)

	_draw_grid(font)
	_centered(font, "Arrows: select   Enter: buy   Tab: launch", Config.HUD_TEXT_COLOR, cx, Config.SHOP_PROMPT_Y, 14)

func _draw_grid(font: Font) -> void:
	var columns: int = Config.SHOP_GRID_COLUMNS
	var tw: float = Config.SHOP_TILE_WIDTH
	var th: float = Config.SHOP_TILE_HEIGHT
	var gap: float = Config.SHOP_TILE_GAP
	var left: float = (size.x - (columns * tw + (columns - 1) * gap)) / 2.0

	for i in range(Upgrades.SHOP_TILES.size()):
		var tile: String = Upgrades.SHOP_TILES[i]
		var rect := Rect2(left + (i % columns) * (tw + gap), Config.SHOP_GRID_TOP + (i / columns) * (th + gap), tw, th)
		_draw_tile(font, tile, rect, i == main.shop_selection)

func _draw_tile(font: Font, tile: String, rect: Rect2, selected: bool) -> void:
	var border: Color = Config.SHOP_TILE_SELECTED_COLOR if selected else Config.SHOP_TILE_BORDER_COLOR
	var width: float = Config.SHOP_TILE_SELECTED_WIDTH if selected else Config.SHOP_TILE_BORDER_WIDTH
	draw_rect(rect, border, false, width)

	var info: Dictionary = _tile_text(tile)
	var spacing: float = Config.SHOP_TILE_LINE_SPACING
	var cx: float = rect.get_center().x
	var cy: float = rect.get_center().y
	_centered(font, info.label, info.color, cx, cy - spacing, 15)
	_centered(font, info.detail, info.color, cx, cy, 15)
	_centered(font, info.price, info.color, cx, cy + spacing, 15)

func _tile_text(tile: String) -> Dictionary:
	var ship: Ship = main.ship
	if tile == Upgrades.BUY_BOMB_TILE:
		var cost: int = Upgrades.BOMB_COST
		return {
			"label": "Buy bomb", "detail": "Carrying %d" % ship.bombs,
			"price": "%dcr" % cost, "color": _affordable(cost),
		}

	if tile == Upgrades.LEVEL_UP_TILE:
		if main.level >= Config.MAX_LEVEL:
			return {
				"label": "Final level", "detail": "",
				"price": "", "color": Config.HUD_TEXT_COLOR,
			}
		var cost: int = Upgrades.level_up_cost(main.level)
		return {
			"label": "Jump", "detail": "Level %d -> %d" % [main.level, main.level + 1],
			"price": "%dcr" % cost, "color": _affordable(cost),
		}

	var label: String = Upgrades.LABELS[tile]
	var tier: int = ship.upgrade_tiers[tile]
	var value_text: String = _value_text(Upgrades.value_at(tile, tier))
	var cost = Upgrades.next_cost(tile, tier)
	if cost == null:
		return {"label": label, "detail": value_text, "price": "MAX", "color": Config.HUD_TEXT_COLOR}
	var next_text: String = _value_text(Upgrades.value_at(tile, tier + 1))
	return {
		"label": label, "detail": "%s -> %s" % [value_text, next_text],
		"price": "%dcr" % cost, "color": _affordable(cost),
	}

func _value_text(value) -> String:
	if value == null:
		return "Off"
	if value is float:
		# "%.2f" with trailing zeros/dot trimmed, since GDScript's String
		# formatting has no "%g" — avoids showing "8.00" or "1.20".
		var s: String = "%.2f" % value
		s = s.rstrip("0").rstrip(".")
		return s
	return str(value)

func _affordable(cost: int) -> Color:
	if main.credits >= cost:
		return Config.HUD_TEXT_COLOR
	return Config.HUD_TEXT_COLOR * Config.UPGRADE_UNAFFORDABLE_DIM

func _centered(font: Font, text: String, color: Color, cx: float, y: float, font_size: int) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cx - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
