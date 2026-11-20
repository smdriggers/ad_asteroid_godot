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
# Nothing here redraws per frame. Each layer's stars are split into a few
# twinkle groups; each group is a child node that draws its stars once
# (one tile, repeated enough times to cover the screen) and is then only
# moved (scrolling) and faded via `modulate` (twinkling). Groups redraw
# only if the window size changes.

const TILE: Vector2 = Vector2(1024.0, 1024.0)  # screen px per repeat
const SEED: int = 7331

# far -> near: scroll factor, stars per tile, radius range (px), brightness range
const LAYERS: Array = [
	{"factor": 0.01,  "count": 160, "size": Vector2(0.6, 1.0), "bright": Vector2(0.25, 0.5)},
	{"factor": 0.025, "count": 70,  "size": Vector2(0.9, 1.4), "bright": Vector2(0.4, 0.7)},
	{"factor": 0.05,  "count": 28,  "size": Vector2(1.3, 2.0), "bright": Vector2(0.6, 1.0)},
]
const TWINKLE_GROUPS: int = 4      # per layer; each group fades on its own rhythm
const TWINKLE_DEPTH: float = 0.3   # fraction of brightness a group's twinkle can dip
const TWINKLE_SPEED: Vector2 = Vector2(0.5, 2.0)  # radians/sec range

# Mostly white, with a few faintly blue and faintly warm stars.
const TINTS: Array = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(0.75, 0.85, 1.0), Color(1.0, 0.9, 0.75),
]

class StarGroup extends Node2D:
	# One twinkle group of one layer: its stars, drawn once across enough
	# tile copies to cover the screen from any scroll offset.
	var stars: Array = []   # {"pos","radius","color"} within one tile
	var copies: Vector2i = Vector2i.ONE
	var factor: float = 0.0
	var phase: float = 0.0
	var speed: float = 1.0

	func _draw() -> void:
		for star in stars:
			for ty in range(copies.y):
				for tx in range(copies.x):
					var p: Vector2 = star.pos + Vector2(tx * TILE.x, ty * TILE.y)
					if star.radius < 1.0:
						draw_rect(Rect2(p, Vector2.ONE), star.color)  # a single pixel; tiny circles can vanish
					else:
						draw_circle(p, star.radius, star.color)

var groups: Array = []   # Array[StarGroup]
var anim_time: float = 0.0
var _screen: Vector2 = Vector2.ZERO

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for spec in LAYERS:
		var layer_groups: Array = []
		for g in range(TWINKLE_GROUPS):
			var group := StarGroup.new()
			group.factor = spec.factor
			group.phase = rng.randf() * TAU
			group.speed = rng.randf_range(TWINKLE_SPEED.x, TWINKLE_SPEED.y)
			add_child(group)
			layer_groups.append(group)
			groups.append(group)
		for i in range(spec.count):
			var group: StarGroup = layer_groups[rng.randi() % TWINKLE_GROUPS]
			group.stars.append({
				"pos": Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y),
				"radius": rng.randf_range(spec.size.x, spec.size.y),
				"color": Color(TINTS[rng.randi() % TINTS.size()], rng.randf_range(spec.bright.x, spec.bright.y)),
			})

func _process(delta: float) -> void:
	anim_time += delta
	var screen: Vector2 = get_viewport_rect().size
	if screen != _screen:
		# Enough tile copies to cover the screen plus one tile of scroll.
		_screen = screen
		var copies := Vector2i(ceili(screen.x / TILE.x) + 1, ceili(screen.y / TILE.y) + 1)
		for group in groups:
			group.copies = copies
			group.queue_redraw()

	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	for group in groups:
		var shift: Vector2 = -cam_pos * group.factor
		# Top-left of the first tile copy, wrapped so the copies always cover the screen.
		group.position = Vector2(fposmod(shift.x, TILE.x) - TILE.x, fposmod(shift.y, TILE.y) - TILE.y)
		group.modulate.a = 1.0 - TWINKLE_DEPTH * (0.5 + 0.5 * sin(anim_time * group.speed + group.phase))
