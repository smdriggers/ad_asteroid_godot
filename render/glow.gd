extends RefCounted
class_name Glow
# render/glow.gd — neon glow for the wireframe look. Each shape is drawn
# as a few wide, faint halo strokes underneath, then the normal sharp
# line on top. Done by hand rather than with Godot's glow post-process,
# which isn't dependable on the web/Compatibility renderer this ships on.
#
# Halo widths are in screen px, so the glow looks the same at every zoom.
# Every function takes the CanvasItem to draw on and an optional
# `strength` (1 = normal; the star uses more).

static func _zoom(ci: CanvasItem) -> float:
	# Screen px per world unit at this item (the camera's zoom).
	return ci.get_global_transform_with_canvas().get_scale().x

static func _passes(strength: float) -> Array:
	# [extra width in screen px, alpha], widest/faintest first.
	if not Config.GLOW_ENABLED:
		return []
	var out: Array = []
	for p in Config.GLOW_PASSES:
		out.append([p[0] * strength, minf(1.0, p[1] * Config.GLOW_INTENSITY)])
	return out

static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, strength: float = 1.0) -> void:
	var px: float = 1.0 / _zoom(ci)
	for p in _passes(strength):
		ci.draw_line(a, b, Color(color, color.a * p[1]), width + p[0] * px)
	ci.draw_line(a, b, color, width)

static func polyline(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float, strength: float = 1.0) -> void:
	var px: float = 1.0 / _zoom(ci)
	for p in _passes(strength):
		ci.draw_polyline(points, Color(color, color.a * p[1]), width + p[0] * px)
	ci.draw_polyline(points, color, width)

static func multiline_colors(ci: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, width: float, strength: float = 1.0) -> void:
	# Batched segments (pairs of points), one color per segment.
	var px: float = 1.0 / _zoom(ci)
	for p in _passes(strength):
		var faint := PackedColorArray()
		faint.resize(colors.size())
		for i in range(colors.size()):
			faint[i] = Color(colors[i], colors[i].a * p[1])
		ci.draw_multiline_colors(points, faint, width + p[0] * px)
	ci.draw_multiline_colors(points, colors, width)

static func arc(ci: CanvasItem, center: Vector2, radius: float, color: Color, width: float, segments: int = 48, strength: float = 1.0) -> void:
	var px: float = 1.0 / _zoom(ci)
	for p in _passes(strength):
		ci.draw_arc(center, radius, 0.0, TAU, segments, Color(color, color.a * p[1]), width + p[0] * px)
	ci.draw_arc(center, radius, 0.0, TAU, segments, color, width)

static func dot(ci: CanvasItem, center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	var px: float = 1.0 / _zoom(ci)
	for p in _passes(strength):
		ci.draw_circle(center, radius + p[0] * 0.5 * px, Color(color, color.a * p[1]))
	ci.draw_circle(center, radius, color)
