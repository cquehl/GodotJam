extends Area3D

# =============================================================================
# POOLED WATER DROPLET
# A reusable water droplet that can be reset and recycled
# =============================================================================

var velocity: Vector3 = Vector3.ZERO
var speed: float = 6.0
var is_collectible: bool = false
var is_gold: bool = false
var base_height: float = 0.3
var gold_height: float = 1.2

var _lifetime_timer: float = 0.0
var _max_lifetime: float = 6.0
var _is_active: bool = false

@onready var mesh: MeshInstance3D = $Mesh
@onready var shadow: MeshInstance3D = $Shadow
@onready var trail_particles: GPUParticles3D = $Mesh/TrailParticles
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Cached materials for quick switching
var _water_material: ShaderMaterial = null
var _electric_material: ShaderMaterial = null
var _gold_material: ShaderMaterial = null

# Original scale for reset
var _original_mesh_scale: Vector3 = Vector3.ONE
var _original_shadow_scale: Vector3 = Vector3.ONE
var _original_collision_radius: float = 0.2

func _ready() -> void:
	# Cache original scales
	_original_mesh_scale = mesh.scale
	_original_shadow_scale = shadow.scale
	var sphere := collision_shape.shape as SphereShape3D
	if sphere:
		_original_collision_radius = sphere.radius

	# Pre-create materials
	_create_cached_materials()

	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _create_cached_materials() -> void:
	var water_shader := DropletPool.water_shader
	var electric_shader := DropletPool.electric_shader

	# Water material (blue hazard)
	_water_material = ShaderMaterial.new()
	_water_material.shader = water_shader
	_water_material.set_shader_parameter("water_color", Color(0.2, 0.5, 1.0, 0.85))

	# Electric material (green collectible)
	_electric_material = ShaderMaterial.new()
	_electric_material.shader = electric_shader
	_electric_material.set_shader_parameter("electric_color", Color(0.2, 1.0, 0.3, 0.8))
	_electric_material.set_shader_parameter("core_color", Color(0.8, 1.0, 0.9, 1.0))
	_electric_material.set_shader_parameter("glow_intensity", 2.5)

	# Gold material (power-up)
	_gold_material = ShaderMaterial.new()
	_gold_material.shader = electric_shader
	_gold_material.set_shader_parameter("electric_color", Color(1.0, 0.85, 0.2, 1.0))
	_gold_material.set_shader_parameter("core_color", Color(1.0, 1.0, 0.8, 1.0))
	_gold_material.set_shader_parameter("glow_intensity", 3.0)

## Activate the droplet for use
func activate() -> void:
	_is_active = true
	_lifetime_timer = 0.0
	trail_particles.emitting = true

## Reset to default state for pooling
func reset_droplet() -> void:
	_is_active = false
	velocity = Vector3.ZERO
	speed = 6.0
	is_collectible = false
	is_gold = false
	_lifetime_timer = 0.0

	# Reset transforms
	mesh.scale = _original_mesh_scale
	shadow.scale = _original_shadow_scale
	position = Vector3.ZERO

	# Reset collision shape
	var sphere := collision_shape.shape as SphereShape3D
	if sphere:
		sphere.radius = _original_collision_radius

	# Reset to water material
	mesh.set_surface_override_material(0, _water_material)

	# Stop particles
	trail_particles.emitting = false

func _process(delta: float) -> void:
	if not _is_active:
		return

	# Update lifetime
	_lifetime_timer += delta
	if _lifetime_timer >= _max_lifetime:
		_return_to_pool()
		return

	# Movement
	position += velocity * delta

	# Bobbing motion
	var bob_offset := sin(Time.get_ticks_msec() * 0.01) * 0.1
	var height := gold_height if is_gold else base_height
	position.y = height + bob_offset

	# Shadow positioning
	shadow.position.y = -position.y + 0.02
	var shadow_base := mesh.scale.x * (1.5 if is_gold else 1.0)
	var shadow_scale := shadow_base - (bob_offset * 0.3)
	shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

	# Power-up visual feedback
	if not is_collectible and not is_gold:
		_update_powerup_visuals(delta)

func _update_powerup_visuals(delta: float) -> void:
	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	if not mat:
		return

	var current_color := mat.get_shader_parameter("water_color") as Color
	var target_alpha := 0.85

	if GameManager.is_powered_up:
		var time_left := GameManager.power_up_timer
		var time_elapsed := GameManager.POWER_UP_DURATION - time_left

		if time_elapsed < 1.0:
			target_alpha = 0.3 if fmod(time_elapsed * 12.0, 1.0) < 0.5 else 0.8
		elif time_left > 2.0:
			target_alpha = 0.4
		else:
			var blink_speed := lerpf(2.0, 6.0, 1.0 - (time_left / 2.0))
			var blink := sin(time_left * blink_speed * PI) * 0.5 + 0.5
			target_alpha = lerpf(0.4, 0.85, blink)

	current_color.a = lerpf(current_color.a, target_alpha, delta * 10.0)
	mat.set_shader_parameter("water_color", current_color)

func set_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * speed
	if velocity.length() > 0.01:
		var forward := velocity.normalized()
		mesh.look_at(mesh.global_position - forward, Vector3.UP)

func make_collectible() -> void:
	is_collectible = true
	trail_particles.emitting = false
	mesh.set_surface_override_material(0, _electric_material)

func make_large() -> void:
	var large_scale := 2.5
	mesh.scale = _original_mesh_scale * large_scale
	shadow.scale = Vector3(large_scale, 1.0, large_scale)
	_scale_collision(large_scale)

	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 3.5)

func make_huge() -> void:
	var large_scale := 5.0
	mesh.scale = _original_mesh_scale * large_scale
	shadow.scale = Vector3(large_scale, 1.0, large_scale)
	_scale_collision(large_scale)

	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 4.0)

func make_gold() -> void:
	is_gold = true
	is_collectible = true
	trail_particles.emitting = false
	speed *= 0.5

	var large_scale := 4.0
	mesh.scale = _original_mesh_scale * large_scale
	shadow.scale = Vector3(large_scale * 1.5, 1.0, large_scale * 1.5)
	_scale_collision(large_scale)

	mesh.set_surface_override_material(0, _gold_material)

func _scale_collision(scale_factor: float) -> void:
	var sphere := collision_shape.shape as SphereShape3D
	if sphere:
		# Duplicate to avoid affecting other instances
		sphere = sphere.duplicate()
		sphere.radius = _original_collision_radius * scale_factor
		collision_shape.shape = sphere

func _return_to_pool() -> void:
	DropletPool.return_droplet(self)

func _on_body_entered(_body: Node3D) -> void:
	_handle_collision()

func _on_area_entered(_area: Area3D) -> void:
	_handle_collision()

func _handle_collision() -> void:
	if is_gold:
		GameManager.activate_power_up()
		_return_to_pool()
	elif is_collectible:
		GameManager.add_score(1)
		_return_to_pool()
	else:
		if GameManager.is_powered_up or GameManager.is_immune:
			return
		AudioManager.play_hit()
		GameManager.game_over()
