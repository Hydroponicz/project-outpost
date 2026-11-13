class_name Hittable
extends Node3D
## Makes an object something the player can hit (chop, mine, ...).
## Works like Interactable: add it as a child of a physics body and move it
## to where the prompt should float. Connect the "hit" signal.

## Emitted when the player hits this object.
signal hit(by: Node, damage: int)

## Name shown in the prompt, e.g. "Tree".
@export var object_name: String = "Object"
## Verb shown in the prompt, e.g. "Chop", "Mine".
@export var action_text: String = "Hit"
## Tool type needed to hit this, e.g. "axe". Empty = anything works, even hands.
## Must match an item's "tool_type".
@export var required_tool: StringName = &""


func get_prompt_text() -> String:
	return "%s %s" % [action_text, object_name]


func take_hit(by: Node, damage: int) -> void:
	hit.emit(by, damage)


## Finds the Hittable attached to a physics body, or null if there isn't one.
static func find_on(node: Node) -> Hittable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Hittable:
			return child
	return null
