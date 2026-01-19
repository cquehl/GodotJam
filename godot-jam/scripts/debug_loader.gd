extends Node

# =============================================================================
# DEBUG LOADER
# Comprehensive debug logging for all background tasks and startup timing
# Works in both Godot editor and web browser (via print which maps to console.log)
# =============================================================================

var _start_time: int = 0
var _event_times: Dictionary = {}
var _enabled: bool = false
var _current_scene_name: String = ""

# Task tracking
var _active_tasks: Dictionary = {}  # task_name -> start_time
var _completed_tasks: Dictionary = {}  # task_name -> {start, end, duration}

# Frame timing for lag detection
var _frame_times: Array[float] = []
var _last_frame_time: int = 0
var _frame_count: int = 0
const LAG_THRESHOLD_MS := 50  # Log frames taking longer than 50ms
const TRACK_FRAMES := 60  # Track last 60 frames for average

# Startup phase tracking
var _startup_phase: String = "boot"

func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	_last_frame_time = _start_time
	_log("=== DEBUG LOADER INITIALIZED ===")
	_log("Startup phase: boot")

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

func _process(_delta: float) -> void:
	if not _enabled:
		return

	var now := Time.get_ticks_msec()
	var frame_duration := now - _last_frame_time
	_last_frame_time = now
	_frame_count += 1

	# Track frame times
	_frame_times.append(frame_duration)
	if _frame_times.size() > TRACK_FRAMES:
		_frame_times.pop_front()

	# Log lag spikes during startup (first 5 seconds)
	var elapsed := now - _start_time
	if elapsed < 5000 and frame_duration > LAG_THRESHOLD_MS:
		_log("LAG SPIKE: Frame %d took %dms (threshold: %dms)" % [_frame_count, frame_duration, LAG_THRESHOLD_MS])

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

# =============================================================================
# TASK TRACKING API
# Use these to track background tasks with start/end timing
# =============================================================================

## Start tracking a task
func task_start(task_name: String, details: String = "") -> void:
	var now := Time.get_ticks_msec() - _start_time
	_active_tasks[task_name] = now
	if details.is_empty():
		_log("TASK START: %s" % task_name)
	else:
		_log("TASK START: %s - %s" % [task_name, details])

## Mark a task as completed
func task_end(task_name: String, details: String = "") -> void:
	var now := Time.get_ticks_msec() - _start_time
	var start_time: int = _active_tasks.get(task_name, now)
	var duration := now - start_time
	_active_tasks.erase(task_name)
	_completed_tasks[task_name] = {"start": start_time, "end": now, "duration": duration}
	if details.is_empty():
		_log("TASK END: %s (%dms)" % [task_name, duration])
	else:
		_log("TASK END: %s (%dms) - %s" % [task_name, duration, details])

## Log a task step (for multi-step tasks)
func task_step(task_name: String, step: String) -> void:
	var now := Time.get_ticks_msec() - _start_time
	var start_time: int = _active_tasks.get(task_name, now)
	var elapsed := now - start_time
	_log("  [%s +%dms] %s" % [task_name, elapsed, step])

## Set the current startup phase
func set_phase(phase: String) -> void:
	_startup_phase = phase
	_log("=== PHASE: %s ===" % phase.to_upper())
	mark_event("phase_%s" % phase)

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
	_log("Total frames: %d" % _frame_count)

	# Frame timing stats
	if not _frame_times.is_empty():
		var sum := 0.0
		var max_frame := 0.0
		for ft in _frame_times:
			sum += ft
			if ft > max_frame:
				max_frame = ft
		var avg := sum / _frame_times.size()
		_log("Avg frame time: %.1fms, Max: %.1fms" % [avg, max_frame])

	# Task timing breakdown
	if not _completed_tasks.is_empty():
		_log("--- Task Timings ---")
		for task_name in _completed_tasks:
			var task_data: Dictionary = _completed_tasks[task_name]
			_log("  %s: %dms (started at %.3fs)" % [task_name, task_data.duration, task_data.start / 1000.0])

	# Still active tasks (shouldn't happen)
	if not _active_tasks.is_empty():
		_log("--- Still Active Tasks (WARN) ---")
		for task_name in _active_tasks:
			var start_time: int = _active_tasks[task_name]
			_log("  %s: started at %.3fs" % [task_name, start_time / 1000.0])

	# Events
	if not _event_times.is_empty():
		_log("--- Events ---")
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
