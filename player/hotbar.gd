class_name Hotbar
extends Node
## The top row of the inventory (slots 0-7) doubles as the hotbar.
## Keys 1-8 pick a slot; LB / RB cycle on gamepad. If the selected slot holds
## a tool, the character holds it; otherwise they're bare-handed.

signal selection_changed(index: int)

const SIZE := 8

@export var inventory: Inventory

## Index of the selected slot (0-7).
var selected: int = 0
## False while a menu is open.
var enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	for i in SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("hotbar_next"):
		select((selected + 1) % SIZE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		select((selected - 1 + SIZE) % SIZE)
		get_viewport().set_input_as_handled()


func select(index: int) -> void:
	if index != selected:
		selected = index
		selection_changed.emit(selected)


func get_selected_stack() -> ItemStack:
	return inventory.get_slot(selected)


## The selected stack if it's a tool, otherwise null (bare hands).
func get_held_tool() -> ItemStack:
	var stack := get_selected_stack()
	if stack != null and stack.item.tool_type != &"":
		return stack
	return null


## True if the selected slot holds a tool of this type (e.g. "hammer").
func is_holding(tool_type: StringName) -> bool:
	var held := get_held_tool()
	return held != null and held.item.tool_type == tool_type


## Why the held tool can't be used on something needing "required_tool",
## e.g. "Needs an Axe". Empty string = good to go.
func get_tool_problem(required_tool: StringName) -> String:
	if required_tool == &"":
		return ""
	var held := get_held_tool()
	if held == null or held.item.tool_type != required_tool:
		var tool_name := String(required_tool).capitalize()
		var article := "an" if tool_name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
		return "Needs %s %s" % [article, tool_name]
	if held.is_broken():
		return "Your %s is broken" % held.item.display_name
	return ""


## Wears down the held tool by one use.
func use_held_tool() -> void:
	if get_held_tool() != null:
		inventory.use_durability(selected, 1)
