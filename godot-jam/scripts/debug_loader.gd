extends Node

# =============================================================================
# DEBUG LOADER
# Logs timing information for resource loading events
# Works in both Godot editor and web browser (via print which maps to console.log)
# =============================================================================

var _start_time: int = 0
var _event_times: Dictionary = {}
var _enabled: bool = true

func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	_log("DebugLoader initialized")

	# Connect to Preloader signals (use late binding since we load before Preloader)
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	var preloader := get_node_or_null("/root/Preloader")
	if preloader:
		preloader.resource_loaded.connect(_on_resource_loaded)
		preloader.all_resources_loaded.connect(_on_all_resources_loaded)
		preloader.loading_progress.connect(_on_loading_progress)
		preloader.everything_ready.connect(_on_everything_ready)
		_log("Connected to Preloader signals")

	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_signal("audio_loaded"):
		audio_manager.audio_loaded.connect(_on_audio_loaded)
		_log("Connected to AudioManager signals")

	var droplet_pool := get_node_or_null("/root/DropletPool")
	if droplet_pool:
		droplet_pool.pool_ready.connect(_on_pool_ready)
		_log("Connected to DropletPool signals")

func _log(message: String) -> void:
	if not _enabled:
		return
	var elapsed := Time.get_ticks_msec() - _start_time
	var timestamp := "%.3fs" % (elapsed / 1000.0)
	# print() works in both Godot and browser console
	print("[DebugLoader %s] %s" % [timestamp, message])

func mark_event(event_name: String) -> void:
	var elapsed := Time.get_ticks_msec() - _start_time
	_event_times[event_name] = elapsed
	_log("EVENT: %s" % event_name)

func _on_resource_loaded(resource_path: String) -> void:
	_log("Resource loaded: %s" % resource_path)

func _on_all_resources_loaded() -> void:
	_log("All resources loaded")

func _on_loading_progress(progress: float) -> void:
	_log("Loading progress: %.0f%%" % (progress * 100))

func _on_everything_ready() -> void:
	_log("Everything ready - game can start")
	_print_summary()

func _on_audio_loaded() -> void:
	_log("Audio loaded")

func _on_pool_ready() -> void:
	_log("Droplet pool ready")

func _print_summary() -> void:
	var total_time := Time.get_ticks_msec() - _start_time
	_log("=== LOADING SUMMARY ===")
	_log("Total load time: %.3fs" % (total_time / 1000.0))
	for event_name in _event_times:
		var event_time: int = _event_times[event_name]
		_log("  %s: %.3fs" % [event_name, event_time / 1000.0])

func disable() -> void:
	_enabled = false

func enable() -> void:
	_enabled = true
