extends Node2D
# render/bombs_view.gd — draws active bombs as small dots (DESIGN.md
# §16.1 style; bomb-specific color/size). Pure drawing; reads the
# parent's (Main) bombs array each frame.

var _had_any: bool = false

func _process(_delta: float) -> void:
	# Animated while there's something to show; one last redraw clears it.
	var has_any: bool = not get_parent().bombs.is_empty()
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	var bombs: Array = get_parent().bombs
	for bomb in bombs:
		Glow.dot(self, bomb.position, Config.BOMB_DRAW_RADIUS, Config.BOMB_COLOR)
