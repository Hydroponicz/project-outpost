class_name ItemPickup
extends RigidBody3D
## An item lying in the world. It pops out with physics, waits a moment so
## you can see it land, then gets vacuumed into the player when they're close.

@export var item: ItemData
@export var amount: int = 1
## Seconds after spawning before it can be picked up.
@export var pickup_delay: float = 0.6
## How fast the vacuum speeds up, in meters per second, per second.
@export var attract_acceleration: float = 40.0
## Starting speed of the vacuum.
@export var attract_start_speed: float = 2.0
## Collected once it's this close to the player.
@export var collect_distance: float = 0.3

var _age: float = 0.0
var _collector: ItemCollector = null
var _attract_speed: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = item.drop_color if item else Color.WHITE
	_mesh.material_override = material


func can_be_collected() -> bool:
	return _collector == null and _age >= pickup_delay


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
		_collector.collect(self)
		queue_free()
		return

	global_position += to_target / distance * step
	# Shrink as it gets close, for a satisfying "slurp".
	_mesh.scale = Vector3.ONE * clampf(distance / 1.5, 0.3, 1.0)
