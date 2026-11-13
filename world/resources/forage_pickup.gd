class_name ForagePickup
extends StaticBody3D
## Something lying on the ground you pick up by hand with Interact (E):
## fallen branches (wood) and loose stones (stone). This is how you get the
## materials for your first tools, since trees and rocks need tools.
##
## Unlike trees, forage comes back on its own after a while, so you can
## never get stuck without materials.
##
## Uses the "Forage" physics layer: the interact ray can hit it, but the
## player walks over it and dropped items fall through it.

@export var item: ItemData
@export var amount: int = 1
## Seconds before it reappears after being picked up.
@export var respawn_time: float = 180.0

## Every forage pickup is in this group, so saving can find them.
const GROUP := &"forage"

## Seconds until it comes back; 0 while it's present.
var respawn_left: float = 0.0

@onready var _interactable: Interactable = $Interactable
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	_interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn_left = 0.0
			_set_present(true)


func is_present() -> bool:
	return respawn_left <= 0.0


## Used when loading a save: gone, coming back in "seconds".
func set_gone(seconds: float) -> void:
	respawn_left = maxf(seconds, 0.01)
	_set_present(false)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null:
		return
	var inventory := player.get_inventory()
	if not inventory.can_add(item, amount):
		player.show_message("Inventory full")
		return
	inventory.add_item(item, amount)
	set_gone(respawn_time)


func _set_present(present: bool) -> void:
	_visual.visible = present
	_shape.set_deferred("disabled", not present)  # Can't be targeted while gone.
