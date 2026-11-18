extends Node2D
# render/loose_ore_view.gd — draws loose ore as small dots in their
# material color, riding their source asteroid's orbit until tapped, then
# a tractor beam from the ship to each piece being reeled in. Pure
# drawing; reads the parent's (Main) loose_ore array.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var main: Node2D = get_parent()
	var ship_pos: Vector2 = main.ship.position
	if main.tractor_held:
		draw_arc(ship_pos, main.mining_range(), 0.0, TAU, 96, Color(Config.TRACTOR_BEAM_COLOR, 0.15), 1.0, true)
	for item in main.loose_ore:
		var pos: Vector2 = main.loose_ore_position(item)
		if item.pulled:
			draw_line(ship_pos, pos, Color(Config.TRACTOR_BEAM_COLOR, 0.5), 1.0, true)
		draw_circle(pos, 3.0, Materials.color(item.material))
