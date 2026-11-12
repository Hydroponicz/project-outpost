class_name ItemCollector
extends Area3D
## Lives on the player. Any ItemPickup that enters this area (and is ready)
## gets vacuumed into the inventory. The area's sphere size is the pickup range.
##
## Pieces only fly in if they fit. Weight never blocks pickup: being over
## the weight limit just makes you encumbered.

## Emitted (at most twice a second) when items are nearby but don't fit.
signal pickup_blocked

@export var inventory: Inventory

var _last_blocked_ms: int = -100000


func _physics_process(_delta: float) -> void:
	# Checked every frame (not just on enter) so items that land inside the
	# range and only become ready later still get picked up.
	for body in get_overlapping_bodies():
		var pickup := body as ItemPickup
		if pickup == null or not pickup.can_be_collected():
			continue
		if inventory.can_add(pickup.item, pickup.amount):
			pickup.start_attract(self)
		else:
			_report_blocked()


## Where pickups fly to.
func get_attract_point() -> Vector3:
	return global_position


## Called when a pickup arrives. Returns false if it no longer fits
## (e.g. several pieces were flying in and the last slot filled up).
func collect(pickup: ItemPickup) -> bool:
	var leftover := inventory.add_item(pickup.item, pickup.amount)
	if leftover > 0:
		pickup.amount = leftover
		_report_blocked()
		return false
	return true


func _report_blocked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_blocked_ms > 500:
		_last_blocked_ms = now
		pickup_blocked.emit()
