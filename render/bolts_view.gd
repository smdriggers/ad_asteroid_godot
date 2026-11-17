extends Node2D
# render/bolts_view.gd — draws active bolts as short bright trailing
# lines (DESIGN.md §16.1). Pure drawing; reads the parent's (Main) bolts
# array each frame.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var bolts: Array = get_parent().bolts
	for bolt in bolts:
		var dir: Vector2 = bolt.velocity
		if dir.length() > 0.0:
			dir = dir.normalized()
		draw_line(bolt.position, bolt.position - dir * Config.BOLT_TRAIL_LENGTH, Config.BOLT_COLOR, 2.0)
