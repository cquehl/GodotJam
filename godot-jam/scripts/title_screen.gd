extends Control

# =============================================================================
# TITLE SCREEN
# Shows immediate visual feedback and uses background-preloaded resources
# =============================================================================

const GAME_SCENE_PATH := "res://scenes/game_3d.tscn"

# Loading states
enum LoadState { IDLE, STARTING, LOADING, TRANSITIONING }
var _load_state: LoadState = LoadState.IDLE
var _loading_dots: int = 3
var _dot_timer: float = 0.0
const DOT_INTERVAL := 0.3

# Hint flash animation
var _flash_timer: float = 0.0
const FLASH_SPEED := 3.0  # Speed of the flash pulse
const MIN_TRANSITION_TIME := 0.5  # Minimum time to show loading screen

# Hints for loading screen
const HINTS := [
	"The initial loading takes the longest.",
	"Jumping with Space Bar helps get out of tight spots.",
	"When you get a Green Orb, Blue Orbs are fired at your location.",
	"Be cautious to trigger too many barrages at once.",
	"Use WASD or Arrow Keys to move.",
	"Collect power-ups for temporary invincibility.",
	"The longer you survive, the harder it gets.",
]
var _hint_timer: float = 0.0
var _current_hint_index: int = 0
const HINT_DURATION := 3.67

# UI references
@onready var start_prompt: Label = $VBox/StartPrompt
@onready var vbox: VBoxContainer = $VBox

# Loading screen elements
var _loading_screen: ColorRect = null
var _hint_label: Label = null
var _loading_title: Label = null

func _ready() -> void:
	# Start menu music (deferred to ensure AudioManager is ready)
	call_deferred("_start_menu_music")

	# Show start prompt immediately - player can press anytime
	start_prompt.text = "Press SPACE to start"

	# Connect to loading signals for hint screen (if player starts before load completes)
	if not Preloader.is_everything_ready:
		Preloader.everything_ready.connect(_on_everything_ready, CONNECT_ONE_SHOT)

func _start_menu_music() -> void:
	AudioManager.play_menu_music()

func _on_everything_ready() -> void:
	# If we're on the loading screen, transition now
	if _load_state == LoadState.STARTING or _load_state == LoadState.LOADING:
		_do_transition()

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
		# Always show loading screen with hints
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
	_hint_timer = 0.0
	_flash_timer = 0.0
	_current_hint_index = 0  # Always start with first hint

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
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 40)
	_loading_screen.add_child(container)

	# Loading title
	_loading_title = Label.new()
	_loading_title.text = "Loading Game..."
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_title.add_theme_font_size_override("font_size", 48)
	container.add_child(_loading_title)

	# Hint label
	_hint_label = Label.new()
	_hint_label.text = "TIP: " + HINTS[_current_hint_index]
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.9))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(_hint_label)

func _update_loading_screen(delta: float) -> void:
	_hint_timer += delta
	_flash_timer += delta

	# Animate loading dots
	_dot_timer += delta
	if _dot_timer >= DOT_INTERVAL:
		_dot_timer = 0.0
		_loading_dots = (_loading_dots + 1) % 4
		if _loading_title:
			_loading_title.text = "Loading Game" + ".".repeat(_loading_dots)

	# Flash/pulse the hint label
	if _hint_label:
		# Sine wave oscillation between 0.4 and 1.0 alpha
		var flash_alpha := 0.7 + 0.3 * sin(_flash_timer * FLASH_SPEED)
		_hint_label.modulate.a = flash_alpha

	# Cycle hints
	if _hint_timer >= HINT_DURATION:
		_hint_timer = 0.0
		_current_hint_index = (_current_hint_index + 1) % HINTS.size()
		if _hint_label:
			_hint_label.text = "TIP: " + HINTS[_current_hint_index]

	# Transition once everything is loaded and minimum time has passed
	if Preloader.is_everything_ready and _flash_timer >= MIN_TRANSITION_TIME:
		_do_transition()

func _do_transition() -> void:
	_load_state = LoadState.TRANSITIONING
	GameManager.start_game()
