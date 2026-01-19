extends Node

# =============================================================================
# PLATFORM SETTINGS (3D)
# =============================================================================
var platform_radius: float = 7  # Radius of the circular platform

# =============================================================================
# ORB SETTINGS (3D)
# =============================================================================
var orb_base_height: float = 0.5  # Resting height (orb radius so it sits on platform)
var move_speed: float = 8.0  # Units per second
var jump_velocity: float = 8.0  # Initial upward velocity
var gravity: float = 25.0  # Downward acceleration

# =============================================================================
# GAME STATE
# =============================================================================
var score: int = 0
var is_paused: bool = false
var high_score: int = 0
var last_score: int = 0
var game_time: float = 0.0
var game_active: bool = false
var _transitioning: bool = false

# =============================================================================
# SETTINGS
# =============================================================================
var gold_powerups_enabled: bool = true

# =============================================================================
# POWER-UP STATE
# =============================================================================
var is_powered_up: bool = false
var power_up_timer: float = 0.0
var is_immune: bool = false
var immune_timer: float = 0.0
const POWER_UP_DURATION: float = 10.0
const IMMUNITY_DURATION: float = 2.0

# =============================================================================
# SIGNALS
# =============================================================================
signal score_changed(new_score: int)
signal power_up_started
signal power_up_ended
signal immunity_ended
signal game_over_triggered

# =============================================================================
# METHODS
# =============================================================================
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func reset_score() -> void:
	score = 0
	score_changed.emit(score)

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

func _process(delta: float) -> void:
	if game_active and not is_paused:
		game_time += delta

		# Handle power-up timer
		if is_powered_up:
			power_up_timer -= delta
			if power_up_timer <= 0:
				end_power_up()

		# Handle immunity timer
		if is_immune:
			immune_timer -= delta
			if immune_timer <= 0:
				is_immune = false
				immunity_ended.emit()

func activate_power_up() -> void:
	is_powered_up = true
	power_up_timer = POWER_UP_DURATION
	power_up_started.emit()

func end_power_up() -> void:
	is_powered_up = false
	power_up_ended.emit()
	# Start immunity period
	is_immune = true
	immune_timer = IMMUNITY_DURATION

func game_over() -> void:
	if _transitioning:
		return

	_transitioning = true
	game_active = false
	last_score = score
	if high_score < score:
		high_score = score

	game_over_triggered.emit()

	# Clear active droplets from pool
	if DropletPool.is_ready():
		DropletPool.clear_active_droplets()

	# Use preloaded scene if available
	if Preloader.is_game_over_ready:
		var scene := Preloader.get_game_over_scene()
		get_tree().change_scene_to_packed(scene)
	else:
		# Fallback to file-based load
		get_tree().change_scene_to_file("res://scenes/game_over_screen.tscn")

	reset_score()
	_transitioning = false

func start_game() -> void:
	_transitioning = false
	reset_score()
	game_time = 0.0
	game_active = true
	is_powered_up = false
	is_immune = false
	power_up_timer = 0.0
	immune_timer = 0.0

	# Log game start for debugging
	var debug_loader := get_node_or_null("/root/DebugLoader")
	if debug_loader and debug_loader.has_method("log_game_start"):
		debug_loader.log_game_start()

	# Clear any leftover droplets
	if DropletPool.is_ready():
		DropletPool.clear_active_droplets()

	# Use preloaded scene if available
	if Preloader.is_game_scene_ready:
		var scene := Preloader.get_game_scene()
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file("res://scenes/game_3d.tscn")
