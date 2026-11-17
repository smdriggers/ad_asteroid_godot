extends Node2D
class_name OrbitBody
# game/orbit_body.gd — a body on a circular rail: its position is a pure
# function of time, never a simulated force. DESIGN.md §3.2:
#
#   pos(t) = parent.pos(t) + r * (cos(w*t + phase), sin(w*t + phase))
#   w = sqrt(G * parent_mass / r^3)
#
# The star is an OrbitBody with orbit_radius 0 and no parent, which pins
# it to the origin. No drawing here — see render/orbit_body_view.gd.

var orbit_radius: float = 0.0       # distance from parent; 0 = fixed at the parent's position
var phase: float = 0.0              # radians; position at t = 0
var mass: float = 0.0               # gravity source strength; 0 = no gravity — DESIGN.md §3.3
var gravity_radius: float = 0.0     # ships beyond this don't feel this body's gravity
var body_radius: float = 0.0        # collision + draw radius; 0 = not fatal to touch, not drawn

var parent_body: OrbitBody = null   # null = orbits a fixed point (the origin)
var angular_speed: float = 0.0      # w; computed once in setup()

func setup(p_parent: OrbitBody, p_orbit_radius: float, p_phase: float, p_mass: float, p_gravity_radius: float, p_body_radius: float) -> void:
	parent_body = p_parent
	orbit_radius = p_orbit_radius
	phase = p_phase
	mass = p_mass
	gravity_radius = p_gravity_radius
	body_radius = p_body_radius
	if orbit_radius > 0.0 and parent_body != null and parent_body.mass > 0.0:
		angular_speed = sqrt(Config.G * parent_body.mass / pow(orbit_radius, 3))
	else:
		angular_speed = 0.0

func position_at(t: float) -> Vector2:
	var parent_pos: Vector2 = Vector2.ZERO
	if parent_body != null:
		parent_pos = parent_body.position_at(t)
	if orbit_radius == 0.0:
		return parent_pos
	var angle: float = angular_speed * t + phase
	return parent_pos + orbit_radius * Vector2(cos(angle), sin(angle))

func velocity_at(t: float) -> Vector2:
	# Analytic derivative of position_at, recursed through the parent
	# chain. Used for the launch orbit (§12.2) and later for competitors
	# "matching motion" against a moving frame (§14.4).
	var parent_vel: Vector2 = Vector2.ZERO
	if parent_body != null:
		parent_vel = parent_body.velocity_at(t)
	if orbit_radius == 0.0:
		return parent_vel
	var angle: float = angular_speed * t + phase
	var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
	return parent_vel + orbit_radius * angular_speed * tangent
