extends Node2D
# render/scan_beam_view.gd — draws the scan beam: the cone's two edges
# while actively scanning (DESIGN.md §11.2), plus automatic pulses
# (§11.3), which flash briefly without the trigger. Pure drawing; reads
# the parent's (Main) scan_beam and pulse_beam/pulse_beam_timer.

var _had_any: bool = false

func _process(_delta: float) -> void:
	# Animated while there's something to show; one last redraw clears it.
	var main: Node2D = get_parent()
	var has_any: bool = not main.scan_beam.is_empty() or main.pulse_beam_timer > 0.0
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	var main: Node2D = get_parent()
	_draw_beam(main, main.scan_beam)
	if main.pulse_beam_timer > 0.0:
		_draw_beam(main, main.pulse_beam)

func _draw_beam(main: Node2D, beam: Dictionary) -> void:
	if beam.is_empty():
		return
	var ship_pos: Vector2 = main.ship.position
	Glow.line(self, ship_pos, beam.left_end, Config.SCAN_BEAM_COLOR, 1.5)
	if beam.right_end != beam.left_end:
		Glow.line(self, ship_pos, beam.right_end, Config.SCAN_BEAM_COLOR, 1.5)
