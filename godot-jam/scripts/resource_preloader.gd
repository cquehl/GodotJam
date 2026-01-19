extends Node

# =============================================================================
# RESOURCE PRELOADER
# Background loading system for smooth game transitions
# =============================================================================

# Signals for loading status
signal all_resources_loaded
signal resource_loaded(resource_path: String)
signal loading_progress(progress: float)
signal everything_ready  # Emitted when ALL subsystems are loaded (scenes, shaders, audio, pool)

# Resources to preload
const GAME_SCENE_PATH := "res://scenes/game_3d.tscn"
const GAME_OVER_SCENE_PATH := "res://scenes/game_over_screen.tscn"
const FIRE_SCENE_PATH := "res://fire/fire.tscn"
const WATER_DROPLET_PATH := "res://scenes/water_droplet.tscn"
const TITLE_SCREEN_PATH := "res://scenes/title_screen.tscn"

# Shader paths for pre-compilation
const SHADER_PATHS := [
	"res://shaders/water_droplet.gdshader",
	"res://shaders/electric_orb.gdshader",
	"res://shaders/starfield_skybox.gdshader",
	"res://shaders/galaxy_disc.gdshader",
	"res://fire/Fire_Drop_Shader.gdshader",
]

# Load priority order (most important first)
const PRELOAD_ORDER := [
	GAME_SCENE_PATH,
	WATER_DROPLET_PATH,
	FIRE_SCENE_PATH,
	GAME_OVER_SCENE_PATH,
	TITLE_SCREEN_PATH,
]

# Cached resources
var _cached_resources: Dictionary = {}
var _loading_queue: Array[String] = []
var _current_loading: String = ""
var _is_loading: bool = false
var _total_to_load: int = 0
var _loaded_count: int = 0

# Pre-compiled shaders
var _compiled_shaders: Array[Shader] = []

# Loading state
var is_game_scene_ready: bool = false
var is_game_over_ready: bool = false
var is_fully_loaded: bool = false
var is_shaders_compiled: bool = false
var is_pool_ready: bool = false
var is_audio_ready: bool = false
var is_everything_ready: bool = false

# Debug settings
const DEBUG_PRELOADER := true

func _ready() -> void:
	_debug_log("Preloader._ready() - deferring background loading")
	# Start loading immediately - title screen will wait for completion
	call_deferred("_start_background_loading")

var _shader_index: int = 0

func _debug_log(message: String) -> void:
	if DEBUG_PRELOADER and DebugLoader:
		DebugLoader._log("[Preloader] " + message)

func _start_background_loading() -> void:
	_debug_log("Starting background loading...")
	DebugLoader.task_start("Preloader.scenes", "%d scenes" % PRELOAD_ORDER.size())
	DebugLoader.task_start("Preloader.shaders", "%d shaders" % SHADER_PATHS.size())

	# Queue resources for background loading FIRST (scenes are more important)
	_loading_queue.clear()
	for path in PRELOAD_ORDER:
		_loading_queue.append(path)
	_total_to_load = _loading_queue.size()
	_loaded_count = 0

	# Use late binding for AudioManager to avoid circular autoload dependency
	var audio_manager := get_node_or_null("/root/AudioManager")

	# Preload gameplay music tracks to avoid blocking when game starts
	if audio_manager:
		for track_path in audio_manager.GAMEPLAY_TRACKS:
			if ResourceLoader.exists(track_path):
				ResourceLoader.load_threaded_request(track_path)

		# Check if AudioManager already finished loading (in case of race condition)
		if audio_manager.is_audio_loaded:
			is_audio_ready = true
		else:
			# Connect to AudioManager signal
			if not audio_manager.audio_loaded.is_connected(_on_audio_loaded):
				audio_manager.audio_loaded.connect(_on_audio_loaded, CONNECT_ONE_SHOT)
	else:
		# AudioManager not ready yet, mark as ready to avoid blocking
		is_audio_ready = true

	# Start loading scenes and shaders in parallel
	_load_next_resource()
	_compile_next_shader()

func _compile_next_shader() -> void:
	# Compile one shader per frame to avoid stutters
	if _shader_index >= SHADER_PATHS.size():
		is_shaders_compiled = true
		_debug_log("All shaders compiled (%d total)" % _compiled_shaders.size())
		DebugLoader.task_end("Preloader.shaders", "%d compiled" % _compiled_shaders.size())
		_on_shaders_compiled()
		return

	var shader_path: String = SHADER_PATHS[_shader_index]
	var shader := load(shader_path) as Shader
	if shader:
		_compiled_shaders.append(shader)
		_debug_log("Compiled shader %d/%d: %s" % [_shader_index + 1, SHADER_PATHS.size(), shader_path.get_file()])

	_shader_index += 1

	# Schedule next shader compilation
	if _shader_index < SHADER_PATHS.size():
		call_deferred("_compile_next_shader")
	else:
		is_shaders_compiled = true
		_debug_log("All shaders compiled (%d total)" % _compiled_shaders.size())
		DebugLoader.task_end("Preloader.shaders", "%d compiled" % _compiled_shaders.size())
		_on_shaders_compiled()

func _on_shaders_compiled() -> void:
	# Initialize DropletPool now that shaders are ready (gradual, one droplet per frame)
	if not is_pool_ready and not DropletPool.is_ready():
		DropletPool.pool_ready.connect(_on_pool_ready, CONNECT_ONE_SHOT)
		DropletPool.ensure_initialized()
	elif DropletPool.is_ready():
		# Pool already initialized
		_on_pool_ready()

func _on_pool_ready() -> void:
	is_pool_ready = true
	_debug_log("DropletPool ready")
	_check_everything_ready()

func _on_audio_loaded() -> void:
	is_audio_ready = true
	_debug_log("Audio ready")
	_check_everything_ready()

func _check_everything_ready() -> void:
	_debug_log("Status check: scenes=%s shaders=%s pool=%s audio=%s" % [is_fully_loaded, is_shaders_compiled, is_pool_ready, is_audio_ready])
	if is_fully_loaded and is_shaders_compiled and is_pool_ready and is_audio_ready:
		if not is_everything_ready:
			is_everything_ready = true
			_debug_log("=== EVERYTHING READY ===")
			DebugLoader.set_phase("ready")
			everything_ready.emit()

func _load_next_resource() -> void:
	if _loading_queue.is_empty():
		_is_loading = false
		is_fully_loaded = true
		_debug_log("All scenes loaded")
		DebugLoader.task_end("Preloader.scenes", "%d loaded" % _loaded_count)
		all_resources_loaded.emit()
		_check_everything_ready()
		return

	_current_loading = _loading_queue.pop_front()

	# Skip if already cached
	if _cached_resources.has(_current_loading):
		_loaded_count += 1
		_update_loading_flags(_current_loading)
		call_deferred("_load_next_resource")
		return

	_is_loading = true
	ResourceLoader.load_threaded_request(_current_loading, "", true)

func _process(_delta: float) -> void:
	if not _is_loading or _current_loading.is_empty():
		return

	var status := ResourceLoader.load_threaded_get_status(_current_loading)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(_current_loading)
			_cached_resources[_current_loading] = resource
			_loaded_count += 1
			_update_loading_flags(_current_loading)
			_debug_log("Loaded %d/%d: %s" % [_loaded_count, _total_to_load, _current_loading.get_file()])
			resource_loaded.emit(_current_loading)
			loading_progress.emit(float(_loaded_count) / float(_total_to_load))
			_load_next_resource()

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Failed to load: " + _current_loading)
			_debug_log("FAILED: %s" % _current_loading)
			_loaded_count += 1
			_load_next_resource()

func _update_loading_flags(path: String) -> void:
	match path:
		GAME_SCENE_PATH:
			is_game_scene_ready = true
		GAME_OVER_SCENE_PATH:
			is_game_over_ready = true

# =============================================================================
# PUBLIC API
# =============================================================================

## Get a cached resource, or load synchronously if not cached
func get_resource(path: String) -> Resource:
	if _cached_resources.has(path):
		return _cached_resources[path]

	# Fallback to sync load (shouldn't happen if preloading worked)
	var resource := load(path)
	_cached_resources[path] = resource
	return resource

## Get the game scene (PackedScene)
func get_game_scene() -> PackedScene:
	return get_resource(GAME_SCENE_PATH) as PackedScene

## Get the game over scene (PackedScene)
func get_game_over_scene() -> PackedScene:
	return get_resource(GAME_OVER_SCENE_PATH) as PackedScene

## Get the water droplet scene (PackedScene)
func get_water_droplet_scene() -> PackedScene:
	return get_resource(WATER_DROPLET_PATH) as PackedScene

## Get the title screen scene (PackedScene)
func get_title_screen_scene() -> PackedScene:
	return get_resource(TITLE_SCREEN_PATH) as PackedScene

## Check if a specific resource is loaded
func is_resource_loaded(path: String) -> bool:
	return _cached_resources.has(path)

## Get overall loading progress (0.0 to 1.0)
func get_loading_progress() -> float:
	if _total_to_load == 0:
		return 1.0
	return float(_loaded_count) / float(_total_to_load)

## Request priority loading of a specific resource
func request_priority_load(path: String) -> void:
	if _cached_resources.has(path):
		return

	# Move to front of queue
	if path in _loading_queue:
		_loading_queue.erase(path)
	_loading_queue.push_front(path)

## Ensure game scene is loaded (blocking if necessary, but only as fallback)
func ensure_game_scene_loaded() -> PackedScene:
	if is_game_scene_ready:
		return get_game_scene()

	# Wait for threaded load to complete
	if _current_loading == GAME_SCENE_PATH:
		while ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			OS.delay_msec(1)
		var resource := ResourceLoader.load_threaded_get(GAME_SCENE_PATH)
		_cached_resources[GAME_SCENE_PATH] = resource
		is_game_scene_ready = true
		return resource as PackedScene

	# Fallback: sync load
	var scene := load(GAME_SCENE_PATH) as PackedScene
	_cached_resources[GAME_SCENE_PATH] = scene
	is_game_scene_ready = true
	return scene
