extends Area3D

# =============================================================================
# POOLED WATER DROPLET
# A reusable water droplet that can be reset and recycled
# =============================================================================

# Size scale constants
const LARGE_SCALE: float = 2.5
const HUGE_SCALE: float = 5.0
const GOLD_SCALE: float = 4.0
const GOLD_SPEED_MULTIPLIER: float = 0.5  # Gold orbs move slower

var velocity: Vector3 = Vector3.ZERO
var speed: float = 6.0
var is_collectible: bool = false
var is_gold: bool = false
var base_height: float = 0.3
var gold_height: float = 0.3  # Same as base height for easy collection

var _lifetime_timer: float = 0.0
var _max_lifetime: float = 6.0
var _is_active: bool = false
var _bob_time: float = 0.0  # Accumulated time for bobbing animation

# Cached reference to current material for _update_powerup_visuals
var _current_material: ShaderMaterial = null

@onready var mesh: MeshInstance3D = $Mesh
@onready var shadow: MeshInstance3D = $Shadow
@onready var trail_particles: GPUParticles3D = $Mesh/TrailParticles
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Cached materials for quick switching
var _water_material: ShaderMaterial = null
var _electric_material: ShaderMaterial = null
var _gold_material: ShaderMaterial = null

# Original state for reset
var _original_mesh_scale: Vector3 = Vector3.ONE
var _original_shadow_scale: Vector3 = Vector3.ONE
var _original_collision_shape: SphereShape3D = null

func _ready() -> void:
	# Cache original scales and collision shape
	_original_mesh_scale = mesh.scale
	_original_shadow_scale = shadow.scale
	var sphere := collision_shape.shape as SphereShape3D
	if sphere:
		_original_collision_shape = sphere.duplicate()

	# Pre-create materials
	_create_cached_materials()

	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _create_cached_materials() -> void:
	# Get shaders from pool if available, otherwise load directly
	var water_shader: Shader
	var electric_shader: Shader
	if DropletPool.water_shader:
		water_shader = DropletPool.water_shader
		electric_shader = DropletPool.electric_shader
	else:
		water_shader = load("res://shaders/water_droplet.gdshader")
		electric_shader = load("res://shaders/electric_orb.gdshader")

	# Water material (blue hazard)
	_water_material = ShaderMaterial.new()
	_water_material.shader = water_shader
	_water_material.set_shader_parameter("opacity", 1.0)

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

	# Set default material reference (water is the default type)
	_current_material = _water_material
	mesh.set_surface_override_material(0, _water_material)

## Activate the droplet for use
func activate() -> void:
	_is_active = true
	_lifetime_timer = 0.0
	collision_shape.disabled = false
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
	mesh.rotation = Vector3.ZERO
	shadow.scale = _original_shadow_scale
	position = Vector3(0, -100, 0)  # Position far below play area

	# Disable collision while pooled
	collision_shape.disabled = true

	# Restore original collision shape (avoids orphaned shape resources)
	if _original_collision_shape:
		collision_shape.shape = _original_collision_shape.duplicate()

	# Reset to water material
	mesh.set_surface_override_material(0, _water_material)
	_current_material = _water_material
	_bob_time = 0.0

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

	# Bobbing motion (using accumulated delta instead of Time.get_ticks_msec())
	_bob_time += delta * 10.0  # Equivalent speed to the old 0.01 multiplier
	var bob_offset := sin(_bob_time) * 0.1
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
	if not _current_material:
		return

	var opacity_param = _current_material.get_shader_parameter("opacity")
	var current_opacity: float = opacity_param if opacity_param != null else 1.0
	var target_opacity := 1.0

	if GameManager.is_powered_up:
		# Smooth sine wave oscillation between 0.15 and 0.85 (reuse _bob_time for consistency)
		var wave := sin(_bob_time * 0.5) * 0.5 + 0.5  # 0 to 1
		target_opacity = lerpf(0.15, 0.85, wave)

	current_opacity = lerpf(current_opacity, target_opacity, delta * 8.0)
	_current_material.set_shader_parameter("opacity", current_opacity)

func set_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * speed
	if velocity.length() > 0.01:
		var forward := velocity.normalized()
		mesh.look_at(mesh.global_position - forward, Vector3.UP)

func make_collectible() -> void:
	is_collectible = true
	trail_particles.emitting = false
	mesh.set_surface_override_material(0, _electric_material)
	_current_material = _electric_material

func make_large() -> void:
	mesh.scale = _original_mesh_scale * LARGE_SCALE
	shadow.scale = Vector3(LARGE_SCALE, 1.0, LARGE_SCALE)
	_scale_collision(LARGE_SCALE)

	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 3.5)

func make_huge() -> void:
	mesh.scale = _original_mesh_scale * HUGE_SCALE
	shadow.scale = Vector3(HUGE_SCALE, 1.0, HUGE_SCALE)
	_scale_collision(HUGE_SCALE)

	if is_collectible:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glow_intensity", 4.0)

func make_gold() -> void:
	is_gold = true
	is_collectible = true
	trail_particles.emitting = false
	speed *= GOLD_SPEED_MULTIPLIER

	mesh.scale = _original_mesh_scale * GOLD_SCALE
	shadow.scale = Vector3(GOLD_SCALE * 1.5, 1.0, GOLD_SCALE * 1.5)
	_scale_collision(GOLD_SCALE)

	mesh.set_surface_override_material(0, _gold_material)
	_current_material = _gold_material

func _scale_collision(scale_factor: float) -> void:
	if _original_collision_shape:
		# Create scaled copy from original to avoid compounding scales
		var scaled_shape := _original_collision_shape.duplicate() as SphereShape3D
		scaled_shape.radius = _original_collision_shape.radius * scale_factor
		collision_shape.shape = scaled_shape

func _return_to_pool() -> void:
	if DropletPool.is_ready():
		DropletPool.return_droplet(self)
	else:
		# Fallback: destroy if pool isn't ready
		queue_free()

func _on_body_entered(_body: Node3D) -> void:
	if _is_active:
		_handle_collision()

func _on_area_entered(_area: Area3D) -> void:
	if _is_active:
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
