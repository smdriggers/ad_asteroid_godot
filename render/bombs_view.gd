extends Node2D
# render/bombs_view.gd — draws active bombs as small dots (DESIGN.md
# §16.1 style; bomb-specific color/size). Pure drawing; reads the
# parent's (Main) bombs array each frame.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var bombs: Array = get_parent().bombs
	for bomb in bombs:
		Glow.dot(self, bomb.position, Config.BOMB_DRAW_RADIUS, Config.BOMB_COLOR)
