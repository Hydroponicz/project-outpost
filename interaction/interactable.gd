class_name Interactable
extends Node3D
## Makes an object usable by the player.
##
## How to use it: add an Interactable node as a child of any physics body
## (StaticBody3D, RigidBody3D, ...), then move it to where the prompt should
## float, usually just above the object. Connect the "interacted" signal to
## whatever the object should do when used.
##
## Every usable thing in the game (trees, chests, workbenches, workers) will
## use this same node.

## Emitted when the player uses this object. "by" is whoever used it.
signal interacted(by: Node)

## Name shown in the prompt, e.g. "Test Box".
@export var object_name: String = "Object"
## Verb shown in the prompt, e.g. "Use", "Open", "Chop".
@export var action_text: String = "Use"


## The prompt without the button, e.g. "Use Test Box".
func get_prompt_text() -> String:
	return "%s %s" % [action_text, object_name]


func interact(by: Node) -> void:
	interacted.emit(by)


## Finds the Interactable attached to a physics body, or null if there isn't one.
static func find_on(node: Node) -> Interactable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Interactable:
			return child
	return null
