extends Node

# =============================================================================
# PLATFORM SETTINGS (3D)
# =============================================================================
var platform_radius: float = 7  # Radius of the circular platform

# =============================================================================
# ORB SETTINGS (3D)
# =============================================================================
var orb_radius: float = 0.5  # Orb size
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
# =============================================================================
# SIGNALS
# =============================================================================
signal settings_changed
signal score_changed(new_score: int)
signal game_paused(paused: bool)

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
	game_paused.emit(is_paused)

func _process(delta: float) -> void:
	if game_active and not is_paused:
		game_time += delta

func game_over() -> void:
	game_active = false
	last_score = score
	if high_score < score:
		high_score = score
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	reset_score()

func start_game() -> void:
	reset_score()
	game_time = 0.0
	game_active = true
	get_tree().change_scene_to_file("res://scenes/game_3d.tscn")
