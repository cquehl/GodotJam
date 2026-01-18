extends Area3D

var velocity: Vector3 = Vector3.ZERO
var speed: float = 6.0
var is_collectible: bool = false
var is_gold: bool = false
var base_height: float = 0.3  # Normal droplet height
var gold_height: float = 1.2  # Height requiring jump to collect

@onready var mesh: MeshInstance3D = $Mesh
@onready var shadow: MeshInstance3D = $Shadow
@onready var trail_particles: GPUParticles3D = $Mesh/TrailParticles

# Preload shaders
var water_shader: Shader = preload("res://shaders/water_droplet.gdshader")
var electric_shader: Shader = preload("res://shaders/electric_orb.gdshader")

func _ready() -> void:
	# Apply water droplet shader to blue droplets by default
	_apply_water_shader()

	# Auto-destroy after crossing platform
	var timer := get_tree().create_timer(6.0)
	timer.timeout.connect(queue_free)

	# Connect collision signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _apply_water_shader() -> void:
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = water_shader
	shader_mat.set_shader_parameter("opacity", 1.0)
	mesh.set_surface_override_material(0, shader_mat)

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
	# Oscillate between 15% and 85% opacity when orb is big (yellow/powered up)
	if not is_collectible and not is_gold:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			var opacity_param = mat.get_shader_parameter("opacity")
			var current_opacity: float = opacity_param if opacity_param != null else 1.0
			var target_opacity := 1.0
			if GameManager.is_powered_up:
				# Smooth sine wave oscillation between 0.15 and 0.85
				var wave := sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5  # 0 to 1
				target_opacity = lerpf(0.15, 0.85, wave)
			current_opacity = lerpf(current_opacity, target_opacity, delta * 8.0)
			mat.set_shader_parameter("opacity", current_opacity)

func set_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * speed
	# Rotate mesh so tail (-Z) trails behind (opposite to movement)
	if velocity.length() > 0.01:
		var forward := velocity.normalized()
		# Look away from movement so -Z (tail) points backward
		mesh.look_at(mesh.global_position - forward, Vector3.UP)

func make_collectible() -> void:
	is_collectible = true
	trail_particles.emitting = false
	# Apply electric shader  for green collectibles
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = electric_shader
	shader_mat.set_shader_parameter("electric_color", Color(0.2, 1.0, 0.3, 0.8))
	shader_mat.set_shader_parameter("core_color", Color(0.8, 1.0, 0.9, 1.0))
	shader_mat.set_shader_parameter("glow_intensity", 2.5)
	mesh.set_surface_override_material(0, shader_mat)

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
	# Make it more visible with brighter glow (only for green collectibles)
	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 3.5)

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
	# Make it more visible with brighter glow (only for green collectibles)
	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 4.0)

func make_gold() -> void:
	is_gold = true
	is_collectible = true  # Gold orbs are collectible (won't kill)
	trail_particles.emitting = false
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
	# Gold color - use electric shader with gold tint
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = electric_shader
	shader_mat.set_shader_parameter("electric_color", Color(1.0, 0.85, 0.2, 1.0))
	shader_mat.set_shader_parameter("core_color", Color(1.0, 1.0, 0.8, 1.0))
	shader_mat.set_shader_parameter("glow_intensity", 3.0)
	mesh.set_surface_override_material(0, shader_mat)


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
		AudioManager.play_hit()
		GameManager.game_over()
