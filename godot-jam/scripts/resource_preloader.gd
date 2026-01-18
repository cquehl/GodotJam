extends Node

# =============================================================================
# RESOURCE PRELOADER
# Background loading system for smooth game transitions
# =============================================================================

# Signals for loading status
signal all_resources_loaded
signal resource_loaded(resource_path: String)
signal loading_progress(progress: float)

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

func _ready() -> void:
	# Delay preloading to let first frames render smoothly
	get_tree().create_timer(0.2).timeout.connect(_start_background_loading)

var _shader_index: int = 0

func _start_background_loading() -> void:
	# Queue resources for background loading FIRST (scenes are more important)
	_loading_queue.clear()
	for path in PRELOAD_ORDER:
		_loading_queue.append(path)
	_total_to_load = _loading_queue.size()
	_loaded_count = 0

	# Start loading scenes - shaders will compile gradually after
	_load_next_resource()

	# Start shader compilation after a short delay (let first frame render)
	get_tree().create_timer(0.1).timeout.connect(_compile_next_shader)

func _compile_next_shader() -> void:
	# Compile one shader per frame to avoid stutters
	if _shader_index >= SHADER_PATHS.size():
		return

	var shader_path: String = SHADER_PATHS[_shader_index]
	var shader := load(shader_path) as Shader
	if shader:
		_compiled_shaders.append(shader)

	_shader_index += 1

	# Schedule next shader compilation
	if _shader_index < SHADER_PATHS.size():
		call_deferred("_compile_next_shader")

func _load_next_resource() -> void:
	if _loading_queue.is_empty():
		_is_loading = false
		is_fully_loaded = true
		all_resources_loaded.emit()
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
			resource_loaded.emit(_current_loading)
			loading_progress.emit(float(_loaded_count) / float(_total_to_load))
			_load_next_resource()

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Failed to load: " + _current_loading)
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
