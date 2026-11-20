extends Node2D
# render/bolts_view.gd — draws active bolts as short bright trailing
# lines (DESIGN.md §16.1). Pure drawing; reads the parent's (Main) bolts
# array each frame.

var _had_any: bool = false

func _process(_delta: float) -> void:
	# Animated while there's something to show; one last redraw clears it.
	var has_any: bool = not get_parent().bolts.is_empty()
	for comp in get_parent().competitors:
		if not comp.bolts.is_empty():
			has_any = true
			break
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	# Every bolt (player's and competitors') goes out in one batched,
	# glowing draw: a maxed laser keeps hundreds in the air at once.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	_add_bolts(get_parent().bolts, Config.BOLT_COLOR, points, colors)
	for comp in get_parent().competitors:
		_add_bolts(comp.bolts, Config.COMP_COLOR, points, colors)  # competitors' shots, in their amber
	if not points.is_empty():
		Glow.multiline_colors(self, points, colors, 2.0)

func _add_bolts(bolts: Array, color: Color, points: PackedVector2Array, colors: PackedColorArray) -> void:
	for bolt in bolts:
		var dir: Vector2 = bolt.velocity
		if dir.length() > 0.0:
			dir = dir.normalized()
		points.append(bolt.position)
		points.append(bolt.position - dir * Config.BOLT_TRAIL_LENGTH)
		colors.append(color)
