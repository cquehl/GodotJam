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

# Hints for loading screen
const HINTS := [
	"Use WASD or Arrow Keys to move",
	"Press SPACE to jump over droplets",
	"Collect power-ups for temporary invincibility",
	"Stay in the center to react to droplets from any direction",
	"Jump timing is key - don't jump too early!",
	"Watch for targeted droplets that aim at you",
	"The longer you survive, the harder it gets",
	"Blue droplets are worth more points",
]
var _hint_timer: float = 0.0
var _current_hint_index: int = 0
const HINT_DURATION := 2.5
const MIN_LOADING_TIME := 1.5  # Minimum time to show loading screen

# UI references
@onready var start_prompt: Label = $VBox/StartPrompt
@onready var vbox: VBoxContainer = $VBox

# Loading indicator (created dynamically)
var _loading_bar: ProgressBar = null
var _preload_label: Label = null

# Loading screen elements
var _loading_screen: ColorRect = null
var _hint_label: Label = null
var _loading_title: Label = null
var _loading_time: float = 0.0

func _ready() -> void:
	# Start menu music (deferred to ensure AudioManager is ready)
	call_deferred("_start_menu_music")

	# Check if everything is already loaded (scenes, shaders, audio, droplet pool)
	if Preloader.is_everything_ready:
		start_prompt.text = "Press SPACE to start"
	else:
		# Show loading text and progress bar until ready
		start_prompt.text = "Loading..."
		_setup_preload_indicator()
		Preloader.loading_progress.connect(_on_loading_progress)
		Preloader.everything_ready.connect(_on_everything_ready, CONNECT_ONE_SHOT)

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

func _on_everything_ready() -> void:
	if _load_state == LoadState.IDLE:
		start_prompt.text = "Press SPACE to start"
	# Remove loading indicators
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
			# Show loading screen with hints
			_update_loading_screen(delta)

		LoadState.LOADING:
			# Wait for threaded load to complete
			_update_loading_screen(delta)

		LoadState.TRANSITIONING:
			pass  # Scene change in progress

func _handle_idle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		# Only allow starting when everything is fully loaded
		if Preloader.is_everything_ready:
			_start_game_loading()

func _unhandled_key_input(event: InputEvent) -> void:
	if _load_state != LoadState.IDLE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_open_credits()
			KEY_S:
				_open_settings()

func _open_credits() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")

func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _start_game_loading() -> void:
	_load_state = LoadState.STARTING
	_loading_time = 0.0
	_hint_timer = 0.0
	_current_hint_index = randi() % HINTS.size()

	# Hide title screen elements
	vbox.visible = false

	# Show loading screen with hints
	_create_loading_screen()

func _create_loading_screen() -> void:
	# Full screen dark overlay
	_loading_screen = ColorRect.new()
	_loading_screen.color = Color(0.05, 0.05, 0.08, 1.0)
	_loading_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_loading_screen)

	# Container for centered content
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 40)
	_loading_screen.add_child(container)

	# Loading title
	_loading_title = Label.new()
	_loading_title.text = "Loading..."
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.add_theme_font_size_override("font_size", 48)
	container.add_child(_loading_title)

	# Hint label
	_hint_label = Label.new()
	_hint_label.text = "TIP: " + HINTS[_current_hint_index]
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.9))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 600
	container.add_child(_hint_label)

func _update_loading_screen(delta: float) -> void:
	_loading_time += delta
	_hint_timer += delta

	# Animate loading dots
	_dot_timer += delta
	if _dot_timer >= DOT_INTERVAL:
		_dot_timer = 0.0
		_loading_dots = (_loading_dots + 1) % 4
		if _loading_title:
			_loading_title.text = "Loading" + ".".repeat(_loading_dots)

	# Cycle hints
	if _hint_timer >= HINT_DURATION:
		_hint_timer = 0.0
		_current_hint_index = (_current_hint_index + 1) % HINTS.size()
		if _hint_label:
			_hint_label.text = "TIP: " + HINTS[_current_hint_index]

	# Transition after minimum time (everything is already loaded)
	if _loading_time >= MIN_LOADING_TIME and Preloader.is_everything_ready:
		_do_transition()

func _do_transition() -> void:
	_load_state = LoadState.TRANSITIONING
	GameManager.start_game()

