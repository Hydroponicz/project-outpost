class_name ResourceNode
extends StaticBody3D
## A tree, rock, or anything else that breaks into items after enough hits.
## Trees don't regrow by themselves: a sapling has to be planted (by the
## player, or by a woodcutter worker).
##
## When the player breaks it, the drops pop out as physical pieces.
## When a worker breaks it, the drops go straight into the worker's hands.

const PICKUP_SCENE := preload("res://items/item_pickup.tscn")
## Every resource node is in this group, so saving can find them.
const GROUP := &"resource_nodes"

## What it drops.
@export var item: ItemData
## Hits needed to break it (with bare hands, 1 damage per hit).
@export var max_health: int = 5
## How many separate pieces it drops.
@export var drop_count: int = 3
## Height above the base where drops pop out.
@export var drop_height: float = 1.0
## An extra drop, e.g. a sapling from a tree. Optional.
@export var extra_drop: ItemData
@export var extra_drop_count: int = 1

## True if this grew from a planted sapling (not placed in the level).
## Saving treats planted trees differently from level trees.
var is_planted: bool = false

var _health: int
var _shake_tween: Tween

@onready var _visual: Node3D = $Visual
@onready var _hittable: Hittable = $Hittable


func _ready() -> void:
	add_to_group(GROUP)
	_health = max_health
	_hittable.hit.connect(_on_hit)


func get_health() -> int:
	return _health


## Used when loading a save (a half-chopped tree stays half-chopped).
func set_health(value: int) -> void:
	_health = clampi(value, 1, max_health)


## What this needs to be hit with, e.g. "axe" for trees.
func get_required_tool() -> StringName:
	return _hittable.required_tool


func _on_hit(by: Node, damage: int) -> void:
	_health -= damage
	if _health <= 0:
		_break(by)
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


func _break(by: Node) -> void:
	var drops: Array = [[item, drop_count]]
	if extra_drop != null and extra_drop_count > 0:
		drops.append([extra_drop, extra_drop_count])

	if by != null and by.has_method("collect_drops"):
		by.call("collect_drops", drops)  # A worker: straight into its hands.
	else:
		for drop in drops:
			for _i in drop[1]:
				_spawn_pickup(drop[0])
	queue_free()
	get_tree().call_group(&"world", &"request_nav_rebake")  # A path opened up.


func _spawn_pickup(drop_item: ItemData) -> void:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = drop_item
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3(
			randf_range(-0.3, 0.3), drop_height, randf_range(-0.3, 0.3))
	# Pop out in a random direction and tumble.
	pickup.linear_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(3.0, 5.0), randf_range(-2.0, 2.0))
	pickup.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
