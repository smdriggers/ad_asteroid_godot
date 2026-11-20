extends Node2D
# render/sparks_view.gd — draws hit sparks in the hit node's material
# color, dimmed when the material is harder than the laser tier
# (DESIGN.md §9.5). Pure drawing; reads the parent's (Main) sparks array.

var _had_any: bool = false

func _process(_delta: float) -> void:
	# Animated while there's something to show; one last redraw clears it.
	var has_any: bool = not get_parent().sparks.is_empty()
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	var sparks: Array = get_parent().sparks
	for s in sparks:
		var col: Color = s.color
		if s.dim:
			col = col.darkened(Config.SPARK_DIM_FACTOR)
		Glow.dot(self, s.position, 2.5, col)
