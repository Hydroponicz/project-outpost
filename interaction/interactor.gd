class_name Interactor
extends Node
## Lives on the player. Every physics frame it looks for a usable object at
## the center of the screen, and uses it when you press the interact button.
##
## How targeting works:
##   1. Cast an invisible ray from the camera, straight through screen center.
##   2. Take the first thing it hits. Walls block it, so no using things
##      through walls.
##   3. Only accept it if it's within "reach" of the CHARACTER (not the
##      camera, which can be zoomed far back).

## Emitted when the target changes. "target" is null when nothing is targeted.
signal target_changed(target: Interactable)

@export var camera: Camera3D
@export var body: CharacterBody3D
## How far the character can reach, in meters.
@export var reach: float = 2.5
## Reach is measured from this height above the character's feet (about chest height).
@export var reach_origin_height: float = 1.0
## How far the camera ray looks. Only needs to be longer than max zoom + reach.
@export var ray_length: float = 20.0

## The object currently targeted, or null.
var target: Interactable = null


func _physics_process(_delta: float) -> void:
	var new_target := _find_target()
	# A targeted object might have been deleted since last frame.
	if target != null and not is_instance_valid(target):
		target = null
	if new_target != target:
		target = new_target
		target_changed.emit(target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and target != null:
		target.interact(body)
		get_viewport().set_input_as_handled()


func _find_target() -> Interactable:
	var from := camera.global_position
	var to := from - camera.global_basis.z * ray_length  # Cameras look along -Z.

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [body.get_rid()]  # Don't hit our own body.

	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var reach_origin := body.global_position + Vector3.UP * reach_origin_height
	if reach_origin.distance_to(hit.position) > reach:
		return null

	return Interactable.find_on(hit.collider)
