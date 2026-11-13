class_name ItemCollector
extends Area3D
## Lives on the player. Any ItemPickup that enters this area (and is ready)
## gets vacuumed into the inventory. The area's sphere size is the pickup range.
##
## Pieces fly in if at least some of them fit; whatever doesn't fit drops
## back to the ground. Weight never blocks pickup: being over the weight
## limit just makes you encumbered.
##
## Also spawns items the player drops, and keeps those from being sucked
## straight back in until the player has walked out of range once.

## Emitted (at most twice a second) when items are nearby but don't fit.
signal pickup_blocked

const PICKUP_SCENE := preload("res://items/item_pickup.tscn")

@export var inventory: Inventory

var _last_blocked_ms: int = -100000
## Pickups the player dropped that haven't been walked away from yet.
## (Untyped on purpose: entries can be freed, and we check for that.)
var _dropped: Array = []

@onready var _range_shape: CollisionShape3D = $PickupRange


func _physics_process(_delta: float) -> void:
	_update_dropped()

	# Checked every frame (not just on enter) so items that land inside the
	# range and only become ready later still get picked up.
	for body in get_overlapping_bodies():
		var pickup := body as ItemPickup
		if pickup == null or not pickup.can_be_collected():
			continue
		if inventory.get_space_for(pickup.item) > 0:
			pickup.start_attract(self)
		else:
			_report_blocked()


## Where pickups fly to.
func get_attract_point() -> Vector3:
	return global_position


## Called when a pickup arrives. Adds as much as fits. Returns false if some
## is left over; the pickup then keeps the rest and drops back to the ground.
func collect(pickup: ItemPickup) -> bool:
	var leftover := inventory.add_item(pickup.item, pickup.amount, pickup.durability)
	if leftover > 0:
		pickup.amount = leftover
		_report_blocked()
		return false
	return true


## Spawns items the player dropped, as one bundle.
func drop(item: ItemData, amount: int, at: Vector3, velocity: Vector3, durability: int = -1) -> void:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	pickup.amount = amount
	pickup.durability = durability
	pickup.dropped_by_player = true
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = at
	pickup.linear_velocity = velocity
	_dropped.append(pickup)


## Once a dropped pickup is out of range, it becomes a normal pickup again.
func _update_dropped() -> void:
	var range_radius := (_range_shape.shape as SphereShape3D).radius
	for pickup in _dropped.duplicate():
		if not is_instance_valid(pickup):
			_dropped.erase(pickup)
		elif pickup.global_position.distance_to(global_position) > range_radius + 0.5:
			pickup.dropped_by_player = false
			_dropped.erase(pickup)


func _report_blocked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_blocked_ms > 500:
		_last_blocked_ms = now
		pickup_blocked.emit()
