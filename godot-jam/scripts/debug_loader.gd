extends Node

# =============================================================================
# DEBUG LOADER
# Logs timing information for resource loading events
# Works in both Godot editor and web browser (via print which maps to console.log)
# =============================================================================

var _start_time: int = 0
var _event_times: Dictionary = {}
var _enabled: bool = true
var _current_scene_name: String = ""

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

	# Connect to GameManager signals for gameplay tracking
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager:
		if game_manager.has_signal("score_changed"):
			game_manager.score_changed.connect(_on_score_changed)
		if game_manager.has_signal("power_up_started"):
			game_manager.power_up_started.connect(_on_power_up_started)
		if game_manager.has_signal("power_up_ended"):
			game_manager.power_up_ended.connect(_on_power_up_ended)
		if game_manager.has_signal("game_over_triggered"):
			game_manager.game_over_triggered.connect(_on_game_over)
		_log("Connected to GameManager signals")

	# Connect to scene tree for scene change tracking
	get_tree().tree_changed.connect(_on_tree_changed)
	_log("Connected to SceneTree signals")

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

# =============================================================================
# SCENE TRACKING
# =============================================================================
func _on_tree_changed() -> void:
	# Guard against null tree during scene transitions
	var tree := get_tree()
	if not tree:
		return
	# Check if the current scene has changed
	var current_scene := tree.current_scene
	if current_scene:
		var scene_name := current_scene.name
		if scene_name != _current_scene_name:
			_current_scene_name = scene_name
			_log("SCENE CHANGED: %s" % scene_name)
			mark_event("scene_%s" % scene_name.to_lower())

# =============================================================================
# GAMEPLAY TRACKING
# =============================================================================
func _on_score_changed(new_score: int) -> void:
	# Only log milestone scores to avoid spam
	if new_score > 0 and (new_score <= 5 or new_score % 10 == 0):
		_log("Score: %d" % new_score)

func _on_power_up_started() -> void:
	_log("POWER-UP STARTED")
	mark_event("power_up_start")

func _on_power_up_ended() -> void:
	_log("POWER-UP ENDED")
	mark_event("power_up_end")

func _on_game_over() -> void:
	var game_manager := get_node_or_null("/root/GameManager")
	var final_score := 0
	var game_time := 0.0
	if game_manager:
		final_score = game_manager.last_score
		game_time = game_manager.game_time
	_log("GAME OVER - Score: %d, Time: %.1fs" % [final_score, game_time])
	mark_event("game_over")

func log_game_start() -> void:
	_log("GAME STARTED")
	mark_event("game_start")
