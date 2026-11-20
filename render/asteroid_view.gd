extends Node2D
# render/asteroid_view.gd — draws an AsteroidGraph's exterior edges
# (DESIGN.md §7.2, §16.2). Pure drawing; this node's own position is the
# asteroid's world origin, so orbiting just moves the node and the
# recorded drawing goes with it — no redraw needed for movement.
#
# The drawing is rebuilt only when something it shows changes, and only
# while the rock is on screen:
#   - the graph's version (damage, a node removed, a player scan),
#   - the camera zoom (glow and tube widths are in screen px),
#   - every frame while some node is low enough to pulse (§16.2).
# A rock that changed while off screen catches up when it comes into view.

var graph: AsteroidGraph = null
var world_time: float = 0.0  # kept in sync by main.gd; drives the near-death pulse — DESIGN.md §16.2

var _drawn_version: int = -1
var _drawn_zoom: float = -1.0
var _pulsing: bool = false   # last drawing had a near-death pulse in it

func _process(_delta: float) -> void:
	if graph == null:
		return
	var stale: bool = _pulsing or graph.version != _drawn_version or not is_equal_approx(Glow.zoom_of(self), _drawn_zoom)
	if not stale:
		return
	if graph.nodes.is_empty() and _drawn_version == graph.version:
		return  # mined out and already drawn empty
	if not Glow.on_screen(self, graph.bounding_radius):
		return  # stays stale until it comes into view
	queue_redraw()

func _draw() -> void:
	_drawn_version = graph.version if graph != null else -1
	_drawn_zoom = Glow.zoom_of(self)
	_pulsing = false
	if graph == null:
		return
	# DESIGN.md §11: the outline is always drawn; a scanned edge shows its
	# owner's material color instead of grey. A deep scan can also reveal
	# interior edges, which then get drawn too, in their owner's color.
	# All edges go out in one batched, glowing draw.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for key in graph.exterior_edges.keys():
		_add_edge(key, points, colors)
	for key in graph.revealed.keys():
		if not graph.exterior_edges.has(key):
			_add_edge(key, points, colors)
	if not points.is_empty():
		Glow.multiline_colors(self, points, colors, 2.0)

func _add_edge(key: String, points: PackedVector2Array, colors: PackedColorArray) -> void:
	var n: Array = AsteroidGraph.edge_nodes(key)
	points.append(AsteroidGraph.node_offset(n[0], Config.HEX_NODE_RADIUS))
	points.append(AsteroidGraph.node_offset(n[1], Config.HEX_NODE_RADIUS))
	var color: Color = Config.UNSCANNED_EDGE_COLOR
	if graph.revealed.has(key):
		var owner: Vector2i = graph.edge_owner.get(key, n[0])
		var mat: int = graph.node_material.get(owner, Materials.IRON)
		color = _damage_color(owner, mat)
	colors.append(color)

func _damage_color(owner: Vector2i, mat: int) -> Color:
	# Damage feedback — DESIGN.md §16.2: an edge whose owner has lost HP
	# is drawn DAMAGED_EDGE_BRIGHTEN of the way toward white; below
	# NEAR_DEATH_HP_FRACTION it pulses between normal and bright instead.
	var base_color: Color = Materials.color(mat)
	var max_hp: float = Materials.hp(mat)
	var hp: float = graph.node_hp.get(owner, max_hp)
	var hp_share: float = hp / max_hp if max_hp > 0.0 else 1.0
	if hp_share >= 1.0:
		return base_color
	var bright: Color = base_color.lerp(Color.WHITE, Config.DAMAGED_EDGE_BRIGHTEN)
	if hp_share >= Config.NEAR_DEATH_HP_FRACTION:
		return bright
	_pulsing = true  # keep redrawing (while on screen) so the pulse animates
	var pulse: float = 0.5 + 0.5 * sin(TAU * Config.NEAR_DEATH_PULSE_HZ * world_time)
	return base_color.lerp(bright, pulse)
