extends Area3D

var velocity: Vector3 = Vector3.ZERO
var speed: float = 6.0
var is_collectible: bool = false

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
	position.y = 0.3 + bob_offset

	# Keep shadow on ground and scale based on height
	shadow.position.y = -position.y + 0.02
	var shadow_scale := 1.0 - (bob_offset * 0.3)
	shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

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


func _on_body_entered(_body: Node3D) -> void:
	_handle_collision()

func _on_area_entered(_area: Area3D) -> void:
	_handle_collision()

func _handle_collision() -> void:
	if is_collectible:
		GameManager.add_score(1)
		queue_free()
	else:
		GameManager.game_over()
