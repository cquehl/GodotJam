extends Node3D

@export var spawn_interval_min: float = 0.8
@export var spawn_interval_max: float = 2.0
@export var droplet_speed: float = 6.0
@export var targeted_droplet_speed: float = 7.0

var droplet_scene: PackedScene = preload("res://scenes/water_droplet.tscn")
var spawn_timer: float = 0.0
var next_spawn_time: float = 1.0
var orb: MeshInstance3D = null

func _ready() -> void:
	_reset_timer()
	# Get reference to the player orb
	orb = get_parent().get_node_or_null("Orb")
	# Connect to score changes
	GameManager.score_changed.connect(_on_score_changed)

func _on_score_changed(new_score: int) -> void:
	if new_score >= 7:
		# Fire multiple targeted large droplets (3 or 5) with 1 second apart
		var count := 3 if randi() % 2 == 0 else 5
		_spawn_targeted_barrage(count)
	elif new_score >= 5:
		# Fire a single targeted large droplet
		_spawn_targeted_droplet()

func _spawn_targeted_droplet() -> void:
	if orb == null:
		return
	var droplet = droplet_scene.instantiate()
	add_child(droplet)
	droplet.make_large()

	var radius: float = GameManager.platform_radius
	var spawn_distance := radius + 4.0

	# Get current orb position as target
	var target_xz := Vector2(orb.position.x, orb.position.z)

	# Pick a random spawn angle
	var spawn_angle: float = randf() * TAU
	var spawn_pos := Vector3(
		cos(spawn_angle) * spawn_distance,
		0.3,
		sin(spawn_angle) * spawn_distance
	)

	# Direction towards orb
	var target_pos := Vector3(target_xz.x, 0.3, target_xz.y)

	droplet.position = spawn_pos
	droplet.speed = targeted_droplet_speed
	droplet.set_direction(target_pos - spawn_pos)

func _spawn_targeted_barrage(count: int) -> void:
	# Spawn multiple droplets with delays
	for i in range(count):
		var timer := get_tree().create_timer(i * 1.0)
		timer.timeout.connect(_spawn_targeted_droplet)

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= next_spawn_time:
		_spawn_droplet()
		_reset_timer()

func _reset_timer() -> void:
	spawn_timer = 0.0
	next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)

func _spawn_droplet() -> void:
	var droplet = droplet_scene.instantiate()
	add_child(droplet)

	# 1 in 7 chance to be a green collectible
	if randi() % 7 == 0:
		droplet.make_collectible()

	var radius: float = GameManager.platform_radius

	# Random angle for spawn point (on edge of platform)
	var spawn_angle: float = randf() * TAU

	# Target angle: weighted toward center-crossing (0 offset = direct center)
	# Use squared random to bias toward smaller offsets (center-crossing)
	var t: float = randf()
	t = t * t  # Squaring biases toward 0 (center-crossing paths)
	var angle_offset: float = lerpf(PI * 0.05, PI * 0.6, t)  # Range from near-center to edge
	if randf() > 0.5:
		angle_offset = -angle_offset
	var target_angle: float = spawn_angle + PI + angle_offset

	# Calculate positions (further outside the platform, near edge of camera view)
	var spawn_distance := radius + 4.0
	var spawn_pos := Vector3(
		cos(spawn_angle) * spawn_distance,
		0.3,
		sin(spawn_angle) * spawn_distance
	)

	var target_pos := Vector3(
		cos(target_angle) * spawn_distance,
		0.3,
		sin(target_angle) * spawn_distance
	)

	# Set droplet position and direction
	droplet.position = spawn_pos
	droplet.speed = droplet_speed
	droplet.set_direction(target_pos - spawn_pos)
