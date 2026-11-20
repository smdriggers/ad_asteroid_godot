extends RefCounted
class_name DebugFlags
# debug_flags.gd — debug switches that can be flipped while playing, from
# the DEBUG menu (render/debug_menu_view.gd). main.gd sets them from the
# matching Config.DEBUG_* defaults at startup. Debug only; not for release.

static var show_speed: bool = false
static var show_perf: bool = false
