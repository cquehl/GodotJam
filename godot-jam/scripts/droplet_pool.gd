extends Node

# =============================================================================
# DROPLET OBJECT POOL
# Reuses water droplet instances to reduce garbage collection and allocation
# =============================================================================

signal pool_ready

const INITIAL_POOL_SIZE := 30
const MAX_POOL_SIZE := 50
const WATER_DROPLET_PATH := "res://scenes/water_droplet.tscn"

var _droplet_scene: PackedScene = null
var _available_pool: Array[Node] = []
var _active_droplets: Array[Node] = []
var _pool_parent: Node = null
var _is_initialized: bool = false

# Preloaded shaders for quick material setup
var water_shader: Shader = null
var electric_shader: Shader = null

func _ready() -> void:
	# Defer initialization to run after Preloader's deferred _start_background_loading
	call_deferred("_initialize_pool")

func _initialize_pool() -> void:
	# Try to get scene from preloader (may not be ready yet since it loads async)
	# Falls back to synchronous load if preloader hasn't finished
	if Preloader.is_resource_loaded(WATER_DROPLET_PATH):
		_droplet_scene = Preloader.get_water_droplet_scene()
	else:
		_droplet_scene = load(WATER_DROPLET_PATH)

	# Get pre-compiled shaders from Preloader (these load synchronously at startup)
	water_shader = load("res://shaders/water_droplet.gdshader")
	electric_shader = load("res://shaders/electric_orb.gdshader")

	# Create hidden parent for pooled objects
	_pool_parent = Node.new()
	_pool_parent.name = "DropletPoolStorage"
	add_child(_pool_parent)

	# Pre-instantiate droplets
	for i in INITIAL_POOL_SIZE:
		_create_pooled_droplet()

	_is_initialized = true
	pool_ready.emit()

func _create_pooled_droplet() -> Node:
	var droplet := _droplet_scene.instantiate()
	# Scene already has pooled_water_droplet.gd attached
	droplet.process_mode = Node.PROCESS_MODE_DISABLED
	droplet.visible = false
	_pool_parent.add_child(droplet)
	_available_pool.append(droplet)
	return droplet

## Get a droplet from the pool
func get_droplet() -> Node:
	if not _is_initialized:
		push_warning("DropletPool not initialized yet")
		return null

	var droplet: Node = null

	# Try to get a valid droplet from available pool
	while not _available_pool.is_empty() and droplet == null:
		var candidate = _available_pool.pop_back()
		if is_instance_valid(candidate):
			droplet = candidate
		# Invalid droplets are just discarded

	if droplet == null:
		# Expand pool if under max size
		if _active_droplets.size() < MAX_POOL_SIZE:
			droplet = _create_pooled_droplet()
			_available_pool.erase(droplet)
		else:
			# Recycle oldest active droplet
			while not _active_droplets.is_empty():
				var candidate = _active_droplets.pop_front()
				if is_instance_valid(candidate):
					droplet = candidate
					droplet.reset_droplet()
					break
			if droplet == null:
				# All droplets invalid, create new one
				droplet = _create_pooled_droplet()
				_available_pool.erase(droplet)

	_active_droplets.append(droplet)
	droplet.process_mode = Node.PROCESS_MODE_INHERIT
	droplet.visible = true
	droplet.activate()

	return droplet

## Return a droplet to the pool
func return_droplet(droplet: Node) -> void:
	if not is_instance_valid(droplet):
		_active_droplets.erase(droplet)
		return

	if droplet in _active_droplets:
		_active_droplets.erase(droplet)

	droplet.reset_droplet()
	droplet.process_mode = Node.PROCESS_MODE_DISABLED
	droplet.visible = false
 
	# Reparent to pool storage if needed
	var parent = droplet.get_parent()
	if parent and parent != _pool_parent:
		parent.remove_child(droplet)
		_pool_parent.add_child(droplet)

	if droplet not in _available_pool:
		_available_pool.append(droplet)

## Clear all active droplets (e.g., on game restart)
func clear_active_droplets() -> void:
	for droplet in _active_droplets.duplicate():
		if is_instance_valid(droplet):
			return_droplet(droplet)
		else:
			_active_droplets.erase(droplet)

## Get pool statistics
func get_stats() -> Dictionary:
	return {
		"available": _available_pool.size(),
		"active": _active_droplets.size(),
		"total": _available_pool.size() + _active_droplets.size()
	}

## Check if pool is ready
func is_ready() -> bool:
	return _is_initialized
