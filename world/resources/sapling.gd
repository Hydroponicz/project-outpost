class_name Sapling
extends Node3D
## A planted sapling. Grows a little bigger over time, then turns into a
## full tree. It has no collision, so you (and workers) can walk past it.

## Every sapling is in this group, so saving can find them.
const GROUP := &"saplings"

## Seconds from planting until it becomes a tree.
@export var grow_time: float = 300.0
## Scene it turns into (a path, not a direct link, so tree -> sapling item
## -> sapling -> tree doesn't load in a circle).
@export_file("*.tscn") var grows_into: String = "res://world/resources/tree.tscn"

## Seconds it has been growing.
var age: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	_update_size()


func _process(delta: float) -> void:
	age += delta
	_update_size()
	if age >= grow_time:
		_become_tree()


func _update_size() -> void:
	_visual.scale = Vector3.ONE * lerpf(0.4, 1.0, clampf(age / grow_time, 0.0, 1.0))


func _become_tree() -> void:
	var tree: ResourceNode = (load(grows_into) as PackedScene).instantiate()
	tree.is_planted = true
	get_parent().add_child(tree)
	tree.global_transform = global_transform
	get_tree().call_group(&"world", &"request_nav_rebake")  # Workers walk around it now.
	queue_free()
