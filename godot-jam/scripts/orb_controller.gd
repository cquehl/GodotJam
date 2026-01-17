extends Node2D

@onready var orb: ColorRect = $Orb
@onready var plane: ColorRect = $Plane

# Position in normalized coordinates (-1 to 1)
var shadow_normalized: Vector2 = Vector2.ZERO

# Jump state
var jump_offset: float = 0.0  # Current height above base
var vertical_velocity: float = 0.0
var is_grounded: bool = true

func _ready() -> void:
	_update_plane_size()
	_update_visuals()
	GameManager.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	_update_plane_size()
	_update_visuals()

func _update_plane_size() -> void:
	var width: float = GameManager.plane_radius * 2.0
	var height: float = GameManager.plane_radius * 2.0 * GameManager.vertical_squash
	plane.size = Vector2(width, height)

	var viewport_size := get_viewport_rect().size
	plane.position = (viewport_size - plane.size) / 2.0

func _process(delta: float) -> void:
	# === HORIZONTAL MOVEMENT ===
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	if input.length() > 1.0:
		input = input.normalized()

	var half_width: float = GameManager.plane_radius
	var half_height: float = GameManager.plane_radius * GameManager.vertical_squash

	shadow_normalized.x += input.x * GameManager.move_speed * delta / half_width
	shadow_normalized.y += input.y * GameManager.move_speed * delta / half_height

	if shadow_normalized.length() > 1.0:
		shadow_normalized = shadow_normalized.normalized()

	# === JUMPING ===
	if Input.is_action_just_pressed("jump") and is_grounded:
		vertical_velocity = GameManager.jump_velocity
		is_grounded = false

	# Apply gravity
	if not is_grounded:
		vertical_velocity -= GameManager.gravity * delta
		jump_offset += vertical_velocity * delta

		# Land
		if jump_offset <= 0.0:
			jump_offset = 0.0
			vertical_velocity = 0.0
			is_grounded = true

	_update_visuals()

func _update_visuals() -> void:
	var plane_center := plane.position + plane.size / 2.0
	var half_width: float = GameManager.plane_radius
	var half_height: float = GameManager.plane_radius * GameManager.vertical_squash

	var shadow_pixels := Vector2(
		shadow_normalized.x * half_width,
		shadow_normalized.y * half_height
	)

	# Total height = base + jump offset
	var total_height: float = GameManager.orb_base_height + jump_offset
	var orb_pixels := shadow_pixels + Vector2(0, -total_height)
	orb.position = plane_center + orb_pixels - orb.size / 2.0

	# Update shader with shadow casting parameters
	var plane_shader := plane.material as ShaderMaterial
	if plane_shader:
		plane_shader.set_shader_parameter("orb_pos", shadow_normalized)
		var normalized_height: float = total_height / half_height
		plane_shader.set_shader_parameter("orb_height", normalized_height)
		var normalized_radius: float = (orb.size.x * 0.5) / half_width
		plane_shader.set_shader_parameter("orb_radius", normalized_radius)
