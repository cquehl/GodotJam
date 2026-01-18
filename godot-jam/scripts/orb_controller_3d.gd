extends Node3D

@onready var orb: MeshInstance3D = $Orb
@onready var platform: MeshInstance3D = $Platform

# Position & velocity on X/Z plane
var position_xz: Vector2 = Vector2.ZERO
var velocity_xz: Vector2 = Vector2.ZERO

# Jump state
var jump_offset: float = 0.0
var vertical_velocity: float = 0.0
var is_grounded: bool = true

# Jump feel improvements
var coyote_timer: float = 0.0  # Time since leaving ground
var jump_buffer_timer: float = 0.0  # Time since jump was pressed
var has_released_jump: bool = true  # For variable jump height

# Visual feedback
var target_scale: Vector3 = Vector3.ONE
var current_scale: Vector3 = Vector3.ONE

# Tuning constants
const ACCELERATION: float = 60.0  # How fast we reach max speed
const FRICTION: float = 12.0  # How fast we stop (ground)
const AIR_FRICTION: float = 3.0  # How fast we stop (air)
const AIR_CONTROL: float = 0.6  # Movement multiplier in air
const COYOTE_TIME: float = 0.1  # Seconds to still jump after leaving ground
const JUMP_BUFFER_TIME: float = 0.12  # Seconds to buffer jump before landing
const JUMP_CUT_MULTIPLIER: float = 0.4  # Velocity multiplier when releasing jump early
const SQUASH_AMOUNT: float = 0.3  # How much to squash/stretch

func _ready() -> void:
	# Scale platform to match GameManager radius (mesh default is 5.0)
	var scale_factor := GameManager.platform_radius / 5.0
	platform.scale = Vector3(scale_factor, 1.0, scale_factor)

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_jumping(delta)
	_update_visuals(delta)

func _handle_movement(delta: float) -> void:
	# Get input
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	# Compensate for camera angle (45° = ~1.4x to feel equal)
	input.y *= 1.4

	if input.length() > 1.0:
		input = input.normalized()

	# Reduce control in air
	var control_multiplier := 1.0 if is_grounded else AIR_CONTROL
	var current_friction := FRICTION if is_grounded else AIR_FRICTION

	# Apply acceleration toward target velocity
	var target_velocity := input * GameManager.move_speed
	velocity_xz = velocity_xz.move_toward(target_velocity * control_multiplier, ACCELERATION * delta)

	# Apply friction when no input
	if input.length() < 0.1:
		velocity_xz = velocity_xz.move_toward(Vector2.ZERO, current_friction * delta)

	# Update position
	position_xz += velocity_xz * delta

	# Clamp to circular platform
	if position_xz.length() > GameManager.platform_radius:
		position_xz = position_xz.normalized() * GameManager.platform_radius
		# Bounce off edge slightly
		var normal := position_xz.normalized()
		velocity_xz = velocity_xz.slide(normal) * 0.5

func _handle_jumping(delta: float) -> void:
	# Update timers
	if is_grounded:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	jump_buffer_timer -= delta

	# Buffer jump input
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
		has_released_jump = false

	# Track jump release for variable height
	if Input.is_action_just_released("jump"):
		has_released_jump = true
		# Cut jump short if released early while rising
		if vertical_velocity > 0 and not is_grounded:
			vertical_velocity *= JUMP_CUT_MULTIPLIER

	# Execute jump (with coyote time and buffer)
	var can_jump := coyote_timer > 0 or is_grounded
	if jump_buffer_timer > 0 and can_jump and is_grounded:
		vertical_velocity = GameManager.jump_velocity
		is_grounded = false
		coyote_timer = 0
		jump_buffer_timer = 0
		# Squash on jump
		target_scale = Vector3(0.8, 1.0 + SQUASH_AMOUNT, 0.8)

	# Apply gravity
	if not is_grounded:
		# Faster fall for snappier feel
		var gravity_multiplier := 1.0
		if vertical_velocity < 0:
			gravity_multiplier = 1.5  # Fall faster than rise

		vertical_velocity -= GameManager.gravity * gravity_multiplier * delta
		jump_offset += vertical_velocity * delta

		# Landing
		if jump_offset <= 0.0:
			jump_offset = 0.0
			vertical_velocity = 0.0
			is_grounded = true
			# Squash on land
			target_scale = Vector3(1.0 + SQUASH_AMOUNT, 1.0 - SQUASH_AMOUNT * 0.5, 1.0 + SQUASH_AMOUNT)

func _update_visuals(delta: float) -> void:
	# Smooth scale interpolation (squash & stretch)
	current_scale = current_scale.lerp(target_scale, 15.0 * delta)
	target_scale = target_scale.lerp(Vector3.ONE, 8.0 * delta)
	orb.scale = current_scale

	# Update orb position
	var orb_y := GameManager.orb_base_height + jump_offset
	orb.position = Vector3(position_xz.x, orb_y, position_xz.y)
