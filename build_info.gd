extends RefCounted
class_name BuildInfo
# build_info.gd — build label shown on the start screen. "dev" for local
# runs; the web deploy workflow overwrites this file with the run number
# and commit before exporting.
const LABEL: String = "dev"
