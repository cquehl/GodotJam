extends Control

# =============================================================================
# TITLE SCREEN
# Shows immediate visual feedback and uses background-preloaded resources
# =============================================================================

const GAME_SCENE_PATH := "res://scenes/game_3d.tscn"

# Loading states
enum LoadState { IDLE, STARTING, LOADING, TRANSITIONING }
var _load_state: LoadState = LoadState.IDLE
var _loading_dots: int = 0
var _dot_timer: float = 0.0
const DOT_INTERVAL := 0.3

# UI references
@onready var start_prompt: Label = $VBox/StartPrompt
@onready var vbox: VBoxContainer = $VBox

# Loading indicator (created dynamically)
var _loading_bar: ProgressBar = null
var _preload_label: Label = null

func _ready() -> void:
	# Start menu music (deferred to ensure AudioManager is ready)
	call_deferred("_start_menu_music")

	# If game scene is already loaded, we're ready immediately
	if Preloader.is_game_scene_ready:
		start_prompt.text = "Press SPACE to start"
	else:
		Preloader.resource_loaded.connect(_on_resource_loaded)

	# Show preloading status if resources are still loading
	if not Preloader.is_fully_loaded:
		_setup_preload_indicator()
		Preloader.loading_progress.connect(_on_loading_progress)
		Preloader.all_resources_loaded.connect(_on_all_resources_loaded)

func _start_menu_music() -> void:
	AudioManager.play_menu_music()

func _setup_preload_indicator() -> void:
	_preload_label = Label.new()
	_preload_label.text = "Loading resources..."
	_preload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preload_label.add_theme_font_size_override("font_size", 24)
	_preload_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(400, 8)
	_loading_bar.max_value = 1.0
	_loading_bar.value = Preloader.get_loading_progress()
	_loading_bar.show_percentage = false
	_loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	vbox.add_child(_preload_label)
	vbox.add_child(_loading_bar)

func _on_loading_progress(progress: float) -> void:
	if _loading_bar:
		_loading_bar.value = progress

func _on_resource_loaded(path: String) -> void:
	if path == GAME_SCENE_PATH and _load_state == LoadState.IDLE:
		start_prompt.text = "Press SPACE to start"

func _on_all_resources_loaded() -> void:
	if _preload_label:
		_preload_label.queue_free()
		_preload_label = null
	if _loading_bar:
		_loading_bar.queue_free()
		_loading_bar = null

func _process(delta: float) -> void:
	match _load_state:
		LoadState.IDLE:
			_handle_idle_input()

		LoadState.STARTING:
			# Show immediate feedback, then check if ready
			_animate_loading_text(delta)
			_check_scene_ready()

		LoadState.LOADING:
			# Wait for threaded load to complete
			_animate_loading_text(delta)
			_check_threaded_load()

		LoadState.TRANSITIONING:
			pass  # Scene change in progress

func _handle_idle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_start_game_loading()

func _start_game_loading() -> void:
	# IMMEDIATE visual feedback - change text instantly
	_load_state = LoadState.STARTING
	start_prompt.text = "Starting"
	_loading_dots = 0
	_dot_timer = 0.0

	# Hide preload indicator immediately
	if _preload_label:
		_preload_label.visible = false
	if _loading_bar:
		_loading_bar.visible = false

func _check_scene_ready() -> void:
	# Check if the scene is already preloaded
	if Preloader.is_game_scene_ready:
		_transition_to_game()
	else:
		# Need to wait for loading - request priority and start threaded load
		Preloader.request_priority_load(GAME_SCENE_PATH)

		# Start our own threaded load as backup
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(GAME_SCENE_PATH)

		_load_state = LoadState.LOADING

func _check_threaded_load() -> void:
	# First check if preloader finished
	if Preloader.is_game_scene_ready:
		_transition_to_game()
		return

	# Check our threaded request
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_transition_to_game()

func _animate_loading_text(delta: float) -> void:
	_dot_timer += delta
	if _dot_timer >= DOT_INTERVAL:
		_dot_timer = 0.0
		_loading_dots = (_loading_dots + 1) % 4

		var dots := ".".repeat(_loading_dots)
		var base_text := "Starting" if _load_state == LoadState.STARTING else "Loading"
		start_prompt.text = base_text + dots

func _transition_to_game() -> void:
	_load_state = LoadState.TRANSITIONING
	start_prompt.text = "Go!"

	# Let GameManager handle state reset and scene transition
	GameManager.start_game()
