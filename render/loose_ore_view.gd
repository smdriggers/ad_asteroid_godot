extends Node2D
# render/loose_ore_view.gd — draws loose ore as small dots in their
# material color, riding their source asteroid's orbit until grabbed, then
# an abduction-style tractor beam (concentric flattened rings flowing from
# the ore up to the ship) for each piece being reeled in. Pure drawing;
# reads the parent's (Main) loose_ore array.

const RING_SEGMENTS: int = 20

var anim_time: float = 0.0

var _had_any: bool = false

func _process(delta: float) -> void:
	anim_time += delta
	# Ore positions and beams are worked out here each frame, so this stays
	# animated while there's anything to show; one last redraw clears it.
	var main: Node2D = get_parent()
	var has_any: bool = not main.loose_ore.is_empty() or main.tractor_held
	if has_any or _had_any:
		queue_redraw()
	_had_any = has_any

func _draw() -> void:
	var main: Node2D = get_parent()
	var ship_pos: Vector2 = main.ship.position
	var zoom_scale: float = (main.get_node("Ship/Camera2D") as CameraControl).zoom_scale
	if main.tractor_held:
		draw_arc(ship_pos, main.mining_range(), 0.0, TAU, 96, Color(Config.TRACTOR_BEAM_COLOR, 0.15), 1.0, true)
	for item in main.loose_ore:
		var pos: Vector2 = main.loose_ore_position(item)
		if item.pulled:
			if item.puller == null:
				_draw_beam(pos, ship_pos, zoom_scale, Config.TRACTOR_BEAM_COLOR)
			else:
				_draw_beam(pos, item.puller.position, zoom_scale, Config.COMP_COLOR)  # a competitor's beam
		Glow.dot(self, pos, 3.0, Materials.color(item.material))

func _draw_beam(ore_pos: Vector2, ship_pos: Vector2, zoom_scale: float, beam_color: Color) -> void:
	var to_ship: Vector2 = ship_pos - ore_pos
	var length: float = to_ship.length()
	if length < 1.0:
		return
	var along: Vector2 = to_ship / length
	var across: Vector2 = along.orthogonal()
	var px: float = 1.0 / zoom_scale  # one screen pixel in world units
	var spacing: float = Config.TRACTOR_RING_SPACING * px
	var offset: float = fmod(anim_time * Config.TRACTOR_RING_SPEED * px, spacing)

	var d: float = offset
	while d < length:
		var s: float = d / length  # 0 at the ore, 1 at the ship
		var half_w: float = lerpf(Config.TRACTOR_RING_WIDTH_FAR, Config.TRACTOR_RING_WIDTH_NEAR, s) * px
		var half_h: float = half_w * Config.TRACTOR_RING_FLATNESS
		# Fade in just off the ore and out just before the ship.
		var alpha: float = 0.8 * minf(1.0, minf(s, 1.0 - s) * 6.0)
		_draw_ring(ore_pos + along * d, across, along, half_w, half_h, Color(beam_color, alpha), px)
		d += spacing

func _draw_ring(center: Vector2, major_dir: Vector2, minor_dir: Vector2, half_w: float, half_h: float, color: Color, px: float) -> void:
	var points := PackedVector2Array()
	for i in range(RING_SEGMENTS + 1):
		var a: float = TAU * float(i) / float(RING_SEGMENTS)
		points.append(center + major_dir * (cos(a) * half_w) + minor_dir * (sin(a) * half_h))
	Glow.polyline(self, points, color, 1.2 * px, 0.5)
