extends Node2D
# render/sparks_view.gd — draws hit sparks in the hit node's material
# color, dimmed when the material is harder than the laser tier
# (DESIGN.md §9.5). Pure drawing; reads the parent's (Main) sparks array.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sparks: Array = get_parent().sparks
	for s in sparks:
		var col: Color = s.color
		if s.dim:
			col = col.darkened(Config.SPARK_DIM_FACTOR)
		draw_circle(s.position, 2.5, col)
