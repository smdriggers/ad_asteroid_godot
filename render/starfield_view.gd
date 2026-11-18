extends Node2D
# render/starfield_view.gd — parallax starry background. Lives in its own
# CanvasLayer behind the world (layer -1), so it draws in screen space and
# ignores the camera; each layer scrolls by the camera's world position
# times its own small factor, so nearer layers drift faster than far ones.
#
# Scrolling doesn't depend on zoom (dragging the zoom bar shouldn't sweep
# the stars sideways), and every factor is below the smallest level
# zoom_min, so stars always move slower than the world: they read as far
# away at every zoom.
#
# Each layer is one tile of randomly placed stars, generated once from a
# fixed seed and repeated to fill the screen.

const TILE: Vector2 = Vector2(1024.0, 1024.0)  # screen px per repeat
const SEED: int = 7331

# far -> near: scroll factor, stars per tile, radius range (px), brightness range
const LAYERS: Array = [
	{"factor": 0.01,  "count": 160, "size": Vector2(0.6, 1.0), "bright": Vector2(0.25, 0.5)},
	{"factor": 0.025, "count": 70,  "size": Vector2(0.9, 1.4), "bright": Vector2(0.4, 0.7)},
	{"factor": 0.05,  "count": 28,  "size": Vector2(1.3, 2.0), "bright": Vector2(0.6, 1.0)},
]
const TWINKLE_DEPTH: float = 0.3   # fraction of brightness a star's twinkle can dip
const TWINKLE_SPEED: Vector2 = Vector2(0.5, 2.0)  # radians/sec range

# Mostly white, with a few faintly blue and faintly warm stars.
const TINTS: Array = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(0.75, 0.85, 1.0), Color(1.0, 0.9, 0.75),
]

var layers: Array = []  # per layer: Array of {"pos","radius","color","phase","speed"}
var anim_time: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for spec in LAYERS:
		var stars: Array = []
		for i in range(spec.count):
			stars.append({
				"pos": Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y),
				"radius": rng.randf_range(spec.size.x, spec.size.y),
				"color": Color(TINTS[rng.randi() % TINTS.size()], rng.randf_range(spec.bright.x, spec.bright.y)),
				"phase": rng.randf() * TAU,
				"speed": rng.randf_range(TWINKLE_SPEED.x, TWINKLE_SPEED.y),
			})
		layers.append(stars)

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _draw() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	var screen: Vector2 = get_viewport_rect().size

	for li in range(layers.size()):
		var shift: Vector2 = -cam_pos * LAYERS[li].factor
		# Top-left of the first tile copy that reaches the screen.
		var origin := Vector2(fposmod(shift.x, TILE.x) - TILE.x, fposmod(shift.y, TILE.y) - TILE.y)
		for star in layers[li]:
			var col: Color = star.color
			col.a *= 1.0 - TWINKLE_DEPTH * (0.5 + 0.5 * sin(anim_time * star.speed + star.phase))
			var y: float = origin.y + star.pos.y
			while y < screen.y + 2.0:
				var x: float = origin.x + star.pos.x
				while x < screen.x + 2.0:
					if x > -2.0 and y > -2.0:
						if star.radius < 1.0:
							draw_rect(Rect2(x, y, 1.0, 1.0), col)  # a single pixel; tiny circles can vanish
						else:
							draw_circle(Vector2(x, y), star.radius, col)
					x += TILE.x
				y += TILE.y
