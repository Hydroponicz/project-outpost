class_name ResourceNode
extends StaticBody3D
## A tree, rock, or anything else that breaks into items after enough hits.
## Trees and rocks don't come back on their own (replanting comes later).

const PICKUP_SCENE := preload("res://items/item_pickup.tscn")

## What it drops.
@export var item: ItemData
## Hits needed to break it (with bare hands, 1 damage per hit).
@export var max_health: int = 5
## How many separate pieces it drops.
@export var drop_count: int = 3
## Height above the base where drops pop out.
@export var drop_height: float = 1.0

var _health: int
var _shake_tween: Tween

@onready var _visual: Node3D = $Visual
@onready var _hittable: Hittable = $Hittable


func _ready() -> void:
	_health = max_health
	_hittable.hit.connect(_on_hit)


func _on_hit(_by: Node, damage: int) -> void:
	_health -= damage
	if _health <= 0:
		_break()
	else:
		_shake()


## Quick wobble from the base so each hit feels like it landed.
func _shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_visual.rotation = Vector3.ZERO
	var angle := randf() * TAU
	var tilt := Vector3(cos(angle), 0.0, sin(angle)) * deg_to_rad(4.0)
	_shake_tween = create_tween()
	_shake_tween.tween_property(_visual, "rotation", tilt, 0.05)
	_shake_tween.tween_property(_visual, "rotation", -tilt * 0.5, 0.08)
	_shake_tween.tween_property(_visual, "rotation", Vector3.ZERO, 0.1)


func _break() -> void:
	for _i in drop_count:
		var pickup: ItemPickup = PICKUP_SCENE.instantiate()
		pickup.item = item
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector3(
				randf_range(-0.3, 0.3), drop_height, randf_range(-0.3, 0.3))
		# Pop out in a random direction and tumble.
		pickup.linear_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(3.0, 5.0), randf_range(-2.0, 2.0))
		pickup.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	queue_free()
