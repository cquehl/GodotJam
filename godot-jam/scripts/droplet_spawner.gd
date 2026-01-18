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
	if new_score < 3:
		return
	var count := 1
	if new_score < 5:
		count = 1
	elif new_score <= 10:
		count = 2 if randi() % 2 == 0 else 3
	else:
		count = randi() % 5 + 5
	_spawn_targeted_barrage(count)



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
	
	
func _spawn_huge_targeted_droplet() -> void:
	if orb == null:
		return
	var droplet = droplet_scene.instantiate()
	add_child(droplet)
	droplet.make_huge()

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
	if GameManager.score >=15:
		_spawn_targeted_droplet()
	
	var droplet = droplet_scene.instantiate()
	add_child(droplet)

	# 1 in 7 chance to be a green collectible
	#if randi() % 7 == 0:
		#droplet.make_collectible()

	# Gold power-up: 1/10 chance after 10 seconds, if not already powered up
	var is_gold := false
	if GameManager.game_time >= 10.0 and not GameManager.is_powered_up:
		if randi() % 10 == 0:
			droplet.make_gold()
			is_gold = true

	# As score increases, bigger drops become more likely
	var huge_chance = mini(GameManager.score, 30)  # 0-30%
	var large_chance = mini(GameManager.score * 2, 40)  # 0-40%

	var is_collectible := false
	if not is_gold:
		var roll = randi() % 100
		if randi() % 5 == 0:
			droplet.make_collectible()
			is_collectible = true
		elif roll < huge_chance:
			droplet.make_huge()
		elif roll < large_chance:
			droplet.make_large()

	var radius: float = GameManager.platform_radius

	# Random angle for spawn point (on edge of platform)
	var spawn_angle: float = randf() * TAU

	# Target angle: weighted toward center-crossing (0 offset = direct center)
	var t: float = randf()
	t = t * t  # Squaring biases toward 0 (center-crossing paths)
	# Collectibles always cross through center, others can edge-graze
	var max_offset := PI * 0.15 if is_collectible else PI * 0.6
	var angle_offset: float = lerpf(PI * 0.05, max_offset, t)
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

	var target_pos: Vector3
	# 1 in 12 chance to target the player
	if randi() % 12 == 0 and orb != null:
		target_pos = Vector3(orb.position.x, 0.3, orb.position.z)
	else:
		target_pos = Vector3(
			cos(target_angle) * spawn_distance,
			0.3,
			sin(target_angle) * spawn_distance
		)

	# Set droplet position and direction
	droplet.position = spawn_pos
	droplet.speed = droplet_speed
	droplet.set_direction(target_pos - spawn_pos)
