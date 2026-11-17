extends Node2D
# render/thrust_puffs_view.gd — draws thrust puffs as small fading dots
# behind the ship (DESIGN.md §16.3). Pure drawing; reads the parent's
# (Main) thrust_puffs array.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Node2D drawing here is already under the camera's view transform
	# (like bolts_view.gd, sparks_view.gd), so screen-size clamping means
	# clamping the *world*-space radius we hand to draw_circle — the
	# inverse of CameraControl.drawn_radius()'s own min-size floor.
	var zoom_scale: float = Config.ZOOM_DEFAULT
	var cam := get_viewport().get_camera_2d()
	if cam is CameraControl:
		zoom_scale = cam.zoom_scale
	for puff in get_parent().thrust_puffs:
		var fade: float = Particles.life_fraction(puff)
		var color: Color = Config.THRUST_PUFF_COLOR * fade
		color.a = 1.0
		var world_radius: float = clamp(Particles.radius(puff),
			Config.THRUST_PUFF_MIN_SCREEN_RADIUS / zoom_scale,
			Config.THRUST_PUFF_MAX_SCREEN_RADIUS / zoom_scale)
		draw_circle(puff.position, world_radius, color)
