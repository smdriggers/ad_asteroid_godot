extends RefCounted
class_name Glow
# render/glow.gd — neon-tube look for the wireframe. Each shape is drawn
# as (bottom to top): a couple of tight, faint halo strokes, the solid
# colored "tube", then a thin near-white hot core down the middle. Done by
# hand rather than with Godot's glow post-process, which isn't dependable
# on the web/Compatibility renderer this ships on.
#
# Halo, tube and core sizes are in screen px, so lines look the same at
# every zoom (the tube is never thinner than GLOW_TUBE_PX). Every function
# takes the CanvasItem to draw on and an optional `strength` (1 = normal;
# the star uses more, the tractor rings less).

static func on_screen(ci: Node2D, radius: float) -> bool:
	# Whether a circle of `radius` (world units) round this item's position
	# is at least partly in view, counting the glow's halo. Used to skip
	# rebuilding drawings nobody can see.
	var vp: Viewport = ci.get_viewport()
	var to_world: Transform2D = vp.get_canvas_transform().affine_inverse()
	var view: Rect2 = to_world * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	var margin: float = Config.ON_SCREEN_MARGIN_PX / vp.get_canvas_transform().get_scale().x
	return view.grow(radius + margin).has_point(ci.global_position)

static func zoom_of(ci: CanvasItem) -> float:
	# The camera's zoom as seen by this item; drawings sized in screen px
	# (glow, tubes) must be rebuilt when this changes.
	return ci.get_global_transform_with_canvas().get_scale().x

static func _px(ci: CanvasItem) -> float:
	# World units per screen px at this item (1 / the camera's zoom).
	return 1.0 / ci.get_global_transform_with_canvas().get_scale().x

static func _passes(strength: float) -> Array:
	# [extra width in screen px, alpha], widest/faintest first.
	if not Config.GLOW_ENABLED:
		return []
	var out: Array = []
	for p in Config.GLOW_PASSES:
		out.append([p[0] * strength, minf(1.0, p[1] * Config.GLOW_INTENSITY)])
	return out

static func _core(color: Color) -> Color:
	return Color(color.lerp(Color.WHITE, Config.GLOW_CORE_WHITEN), color.a)

static func _widths(width: float, px: float) -> Vector2:
	# x = tube width, y = core width (world units).
	if not Config.GLOW_ENABLED:
		return Vector2(width, 0.0)
	return Vector2(maxf(width, Config.GLOW_TUBE_PX * px), Config.GLOW_CORE_PX * px)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, strength: float = 1.0) -> void:
	var px: float = _px(ci)
	var w: Vector2 = _widths(width, px)
	for p in _passes(strength):
		ci.draw_line(a, b, Color(color, color.a * p[1]), w.x + p[0] * px)
	ci.draw_line(a, b, color, w.x)
	if w.y > 0.0:
		ci.draw_line(a, b, _core(color), w.y)

static func polyline(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float, strength: float = 1.0) -> void:
	var px: float = _px(ci)
	var w: Vector2 = _widths(width, px)
	for p in _passes(strength):
		ci.draw_polyline(points, Color(color, color.a * p[1]), w.x + p[0] * px)
	ci.draw_polyline(points, color, w.x)
	if w.y > 0.0:
		ci.draw_polyline(points, _core(color), w.y)

static func multiline_colors(ci: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, width: float, strength: float = 1.0) -> void:
	# Batched segments (pairs of points), one color per segment.
	var px: float = _px(ci)
	var w: Vector2 = _widths(width, px)
	for p in _passes(strength):
		var faint := PackedColorArray()
		faint.resize(colors.size())
		for i in range(colors.size()):
			faint[i] = Color(colors[i], colors[i].a * p[1])
		ci.draw_multiline_colors(points, faint, w.x + p[0] * px)
	ci.draw_multiline_colors(points, colors, w.x)
	if w.y > 0.0:
		var hot := PackedColorArray()
		hot.resize(colors.size())
		for i in range(colors.size()):
			hot[i] = _core(colors[i])
		ci.draw_multiline_colors(points, hot, w.y)

static func arc(ci: CanvasItem, center: Vector2, radius: float, color: Color, width: float, segments: int = 48, strength: float = 1.0) -> void:
	var px: float = _px(ci)
	var w: Vector2 = _widths(width, px)
	for p in _passes(strength):
		ci.draw_arc(center, radius, 0.0, TAU, segments, Color(color, color.a * p[1]), w.x + p[0] * px)
	ci.draw_arc(center, radius, 0.0, TAU, segments, color, w.x)
	if w.y > 0.0:
		ci.draw_arc(center, radius, 0.0, TAU, segments, _core(color), w.y)

static func dot(ci: CanvasItem, center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	var px: float = _px(ci)
	var r: float = maxf(radius, Config.GLOW_TUBE_PX * px) if Config.GLOW_ENABLED else radius
	for p in _passes(strength):
		ci.draw_circle(center, r + p[0] * 0.5 * px, Color(color, color.a * p[1]))
	ci.draw_circle(center, r, color)
	if Config.GLOW_ENABLED:
		ci.draw_circle(center, r * 0.45, _core(color))
