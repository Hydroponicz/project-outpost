class_name ItemCollector
extends Area3D
## Lives on the player. Any ItemPickup that enters this area (and is ready)
## gets vacuumed in. The area's sphere size is the pickup range.
##
## TEMPORARY: collected items go into a simple tally ("counts") until the
## real inventory arrives in step 4. A weight limit will also hook in here.

signal item_collected(item: ItemData, amount: int)

## Temporary tally: ItemData -> amount.
var counts: Dictionary = {}


func _physics_process(_delta: float) -> void:
	# Checked every frame (not just on enter) so items that land inside the
	# range and only become ready later still get picked up.
	for body in get_overlapping_bodies():
		var pickup := body as ItemPickup
		if pickup != null and pickup.can_be_collected():
			pickup.start_attract(self)


## Where pickups fly to.
func get_attract_point() -> Vector3:
	return global_position


func collect(pickup: ItemPickup) -> void:
	counts[pickup.item] = counts.get(pickup.item, 0) + pickup.amount
	item_collected.emit(pickup.item, pickup.amount)
