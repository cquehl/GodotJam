extends Area3D

var velocity: Vector3 = Vector3.ZERO
var speed: float = 6.0
var is_collectible: bool = false
var is_gold: bool = false
var base_height: float = 0.3  # Normal droplet height
var gold_height: float = 1.2  # Height requiring jump to collect

@onready var mesh: MeshInstance3D = $Mesh
@onready var shadow: MeshInstance3D = $Shadow

func _ready() -> void:
	# Auto-destroy after crossing platform
	var timer := get_tree().create_timer(6.0)
	timer.timeout.connect(queue_free)

	# Connect collision signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	# Slight bobbing motion
	var bob_offset := sin(Time.get_ticks_msec() * 0.01) * 0.1
	var height := gold_height if is_gold else base_height
	position.y = height + bob_offset

	# Keep shadow on ground and scale based on height
	shadow.position.y = -position.y + 0.02
	# Gold orbs have darker, larger shadows
	var shadow_base := mesh.scale.x * (1.5 if is_gold else 1.0)
	var shadow_scale := shadow_base - (bob_offset * 0.3)
	shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

	# Visual feedback for blue droplets during power-up
	if not is_collectible and not is_gold:
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var target_alpha := 1.0
			if GameManager.is_powered_up:
				var time_left := GameManager.power_up_timer
				var time_elapsed := GameManager.POWER_UP_DURATION - time_left

				if time_elapsed < 1.0:
					# First second: rapid flicker
					target_alpha = 0.3 if fmod(time_elapsed * 12.0, 1.0) < 0.5 else 0.8
				elif time_left > 2.0:
					# Middle: steady 60% opacity
					target_alpha = 0.4
				else:
					# Last 2 seconds: slowly phase back to solid
					var blink_speed := lerpf(2.0, 6.0, 1.0 - (time_left / 2.0))
					var blink := sin(time_left * blink_speed * PI) * 0.5 + 0.5
					target_alpha = lerpf(0.4, 1.0, blink)

			mat.albedo_color.a = lerpf(mat.albedo_color.a, target_alpha, delta * 10.0)

func set_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * speed

func make_collectible() -> void:
	is_collectible = true
	# Change to green color
	var mat := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.2, 1.0, 0.3, 0.8)
	mat.emission = Color(0.1, 0.8, 0.2, 1)
	mesh.set_surface_override_material(0, mat)

func make_large() -> void:
	# Scale up the droplet and shadow
	var large_scale := 2.5
	mesh.scale = Vector3.ONE * large_scale
	shadow.scale = Vector3(large_scale, 1.0, large_scale)
	# Increase collision size
	var collision_shape := $CollisionShape3D as CollisionShape3D
	var sphere := collision_shape.shape as SphereShape3D
	sphere = sphere.duplicate()
	sphere.radius *= large_scale
	collision_shape.shape = sphere
	# Make it more visible with brighter emission
	var mat := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
	mat.emission_energy_multiplier = 0.8
	mesh.set_surface_override_material(0, mat)

func make_huge() -> void:
	# Scale up the droplet and shadow
	var large_scale := 5
	mesh.scale = Vector3.ONE * large_scale
	shadow.scale = Vector3(large_scale, 1.0, large_scale)
	# Increase collision size
	var collision_shape := $CollisionShape3D as CollisionShape3D
	var sphere := collision_shape.shape as SphereShape3D
	sphere = sphere.duplicate()
	sphere.radius *= large_scale
	collision_shape.shape = sphere
	# Make it more visible with brighter emission
	var mat := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
	mat.emission_energy_multiplier = 0.8
	mesh.set_surface_override_material(0, mat)

func make_gold() -> void:
	is_gold = true
	is_collectible = true  # Gold orbs are collectible (won't kill)
	# Move 50% slower
	speed *= 0.5
	# Huge scale
	var large_scale := 4.0
	mesh.scale = Vector3.ONE * large_scale
	shadow.scale = Vector3(large_scale * 1.5, 1.0, large_scale * 1.5)
	# Increase collision size
	var collision_shape := $CollisionShape3D as CollisionShape3D
	var sphere := collision_shape.shape as SphereShape3D
	sphere = sphere.duplicate()
	sphere.radius *= large_scale
	collision_shape.shape = sphere
	# Gold color with bright emission
	var mat := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1, 1)
	mat.emission_energy_multiplier = 2.0
	mesh.set_surface_override_material(0, mat)


func _on_body_entered(_body: Node3D) -> void:
	_handle_collision()

func _on_area_entered(_area: Area3D) -> void:
	_handle_collision()

func _handle_collision() -> void:
	if is_gold:
		GameManager.activate_power_up()
		queue_free()
	elif is_collectible:
		GameManager.add_score(1)
		queue_free()
	else:
		# Blue droplet - check for invincibility
		if GameManager.is_powered_up or GameManager.is_immune:
			return  # Ignore collision while powered up or immune
		GameManager.game_over()
