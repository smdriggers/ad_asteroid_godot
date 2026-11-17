extends Node2D
# render/loose_ore_view.gd — draws loose ore (cargo overflow) as small
# dots in their material color, riding their source asteroid's orbit
# (DESIGN.md §10). Pure drawing; reads the parent's (Main) loose_ore array.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for item in get_parent().loose_ore:
		var pos: Vector2 = item.view.position + item.offset
		draw_circle(pos, 3.0, Materials.color(item.material))
