extends Node

# =============================================================================
# DROPLET OBJECT POOL
# Reuses water droplet instances to reduce garbage collection and allocation
# =============================================================================

signal pool_ready

const INITIAL_POOL_SIZE := 10
const MAX_POOL_SIZE := 50
const WATER_DROPLET_PATH := "res://scenes/water_droplet.tscn"

var _droplet_scene: PackedScene = null
var _available_pool: Array[Node] = []
var _active_droplets: Array[Node] = []
var _pool_parent: Node = null
var _is_initialized: bool = false
var _is_initializing: bool = false
var _init_count: int = 0

# Preloaded shaders for quick material setup
var water_shader: Shader = null
var electric_shader: Shader = null

# Debug settings
const DEBUG_POOL := true

func _ready() -> void:
	# DON'T initialize pool at startup - it's too heavy (30 GPU particle objects)
	# Pool will be initialized on-demand when first droplet is requested
	pass

## Initialize pool on-demand (called from get_droplet or explicitly)
## This starts gradual initialization - one droplet per frame to avoid blocking
func ensure_initialized() -> void:
	if _is_initialized or _is_initializing:
		return
	_start_gradual_init()

func _start_gradual_init() -> void:
	_is_initializing = true
	_init_count = 0

	if DEBUG_POOL:
		print("[DropletPool] Starting gradual initialization (target: %d droplets)" % INITIAL_POOL_SIZE)

	# Use late binding for Preloader to avoid circular autoload dependency
	var preloader := get_node_or_null("/root/Preloader")

	# Try to get scene from preloader (may not be ready yet since it loads async)
	# Falls back to synchronous load if preloader hasn't finished
	if preloader and preloader.is_resource_loaded(WATER_DROPLET_PATH):
		_droplet_scene = preloader.get_water_droplet_scene()
	else:
		_droplet_scene = load(WATER_DROPLET_PATH)

	# Get pre-compiled shaders from Preloader's cache (avoids reloading)
	if preloader:
		water_shader = preloader.get_resource("res://shaders/water_droplet.gdshader") as Shader
		electric_shader = preloader.get_resource("res://shaders/electric_orb.gdshader") as Shader

	# Create hidden parent for pooled objects
	_pool_parent = Node.new()
	_pool_parent.name = "DropletPoolStorage"
	add_child(_pool_parent)

	# Start creating droplets one per frame
	call_deferred("_create_next_pooled_droplet")

func _create_next_pooled_droplet() -> void:
	if _init_count >= INITIAL_POOL_SIZE:
		# Done initializing
		_is_initialized = true
		_is_initializing = false
		if DEBUG_POOL:
			print("[DropletPool] Pool ready! (%d droplets)" % _available_pool.size())
		pool_ready.emit()
		return

	_create_pooled_droplet()
	_init_count += 1

	if DEBUG_POOL:
		print("[DropletPool] Created droplet %d/%d" % [_init_count, INITIAL_POOL_SIZE])

	# Schedule next droplet creation
	if _init_count < INITIAL_POOL_SIZE:
		call_deferred("_create_next_pooled_droplet")
	else:
		_is_initialized = true
		_is_initializing = false
		if DEBUG_POOL:
			print("[DropletPool] Pool ready! (%d droplets)" % _available_pool.size())
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
	# If pool not ready, create a one-off droplet (rare fallback)
	if not _is_initialized:
		if not _is_initializing:
			ensure_initialized()
		# Create a temporary droplet while pool initializes
		if _droplet_scene == null:
			_droplet_scene = load(WATER_DROPLET_PATH)
		var temp_droplet := _droplet_scene.instantiate()
		temp_droplet.activate()
		if DEBUG_POOL:
			print("[DropletPool] WARN: Pool not ready, created temp droplet")
		return temp_droplet

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
			if DEBUG_POOL:
				print("[DropletPool] Expanded pool (now %d total)" % (_available_pool.size() + _active_droplets.size() + 1))
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
	# Use deferred to avoid physics callback errors
	droplet.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
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
