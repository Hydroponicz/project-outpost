class_name ItemPickup
extends RigidBody3D
## An item lying in the world. It pops out with physics, waits a moment so
## you can see it land, then gets vacuumed into the player when they're close.

@export var item: ItemData
@export var amount: int = 1
## Seconds after spawning before it can be picked up.
@export var pickup_delay: float = 1.5
## How fast the vacuum speeds up, in meters per second, per second.
@export var attract_acceleration: float = 40.0
## Starting speed of the vacuum.
@export var attract_start_speed: float = 2.0
## Collected once it's this close to the player.
@export var collect_distance: float = 0.3
## Size multiplier for bundles (more than one item in a single pickup).
@export var bundle_scale: float = 1.6

## True for items the player dropped on purpose. They aren't auto-picked up
## until the player has walked out of pickup range (ItemCollector clears it).
var dropped_by_player: bool = false

var _age: float = 0.0
var _collector: ItemCollector = null
var _attract_speed: float = 0.0
var _normal_layer: int
var _normal_mask: int
var _base_scale: Vector3 = Vector3.ONE

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	_normal_layer = collision_layer
	_normal_mask = collision_mask

	# Bundles look (and collide) bigger. The shape is shared between all
	# pickups, so make this one its own copy before resizing it.
	if amount > 1:
		var collision: CollisionShape3D = $CollisionShape3D
		var box := collision.shape.duplicate() as BoxShape3D
		box.size *= bundle_scale
		collision.shape = box
		_base_scale = Vector3.ONE * bundle_scale
		_mesh.scale = _base_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = item.drop_color if item else Color.WHITE
	_mesh.material_override = material


func can_be_collected() -> bool:
	return _collector == null and _age >= pickup_delay and not dropped_by_player


## Called by the player's ItemCollector. Switches off physics and starts flying.
func start_attract(collector: ItemCollector) -> void:
	_collector = collector
	_attract_speed = attract_start_speed
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0  # Fly through anything on the way.


func _physics_process(delta: float) -> void:
	_age += delta
	if _collector == null:
		return
	if not is_instance_valid(_collector):
		queue_free()
		return

	var to_target := _collector.get_attract_point() - global_position
	var distance := to_target.length()
	_attract_speed += attract_acceleration * delta
	var step := _attract_speed * delta

	if distance <= maxf(collect_distance, step):
		if _collector.collect(self):
			queue_free()
		else:
			_drop_back()  # Didn't fit after all.
		return

	global_position += to_target / distance * step
	# Shrink as it gets close, for a satisfying "slurp".
	_mesh.scale = _base_scale * clampf(distance / 1.5, 0.3, 1.0)


## Turns physics back on and lets the piece fall where it is.
func _drop_back() -> void:
	_collector = null
	_age = 0.0  # Wait the pickup delay again before retrying.
	freeze = false
	collision_layer = _normal_layer
	collision_mask = _normal_mask
	linear_velocity = Vector3.ZERO
	_mesh.scale = _base_scale
