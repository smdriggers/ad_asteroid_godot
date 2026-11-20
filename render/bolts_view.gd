extends Node2D
# render/bolts_view.gd — draws active bolts as short bright trailing
# lines (DESIGN.md §16.1). Pure drawing; reads the parent's (Main) bolts
# array each frame.

var _had_any: bool = false

func _process(_delta: float) -> void:
	# Animated while there's something to show; one last redraw clears it.
	var has_any: bool = not get_parent().bolts.is_empty()
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	var bolts: Array = get_parent().bolts
	for bolt in bolts:
		var dir: Vector2 = bolt.velocity
		if dir.length() > 0.0:
			dir = dir.normalized()
		Glow.line(self, bolt.position, bolt.position - dir * Config.BOLT_TRAIL_LENGTH, Config.BOLT_COLOR, 2.0)
