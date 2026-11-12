extends Node
## Global helper (an "autoload", always running, reachable as InputPrompts).
##
## Remembers whether the player last used keyboard/mouse or a gamepad, and
## turns an input action into a short button label like "E", "X" or "Square".

signal device_changed(using_gamepad: bool)

var using_gamepad: bool = false


func _input(event: InputEvent) -> void:
	var gamepad := using_gamepad
	if event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		gamepad = false  # Ignore tiny accidental mouse bumps.
	elif event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		gamepad = true  # Ignore stick drift.

	if gamepad != using_gamepad:
		using_gamepad = gamepad
		device_changed.emit(using_gamepad)


## Returns the label for an action's button on the current device.
func get_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if using_gamepad and event is InputEventJoypadButton:
			return _joy_button_name((event as InputEventJoypadButton).button_index)
		if not using_gamepad and event is InputEventKey:
			var physical := (event as InputEventKey).physical_keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
	return "?"


func _joy_button_name(index: int) -> String:
	var ps := _is_playstation()
	match index:
		JOY_BUTTON_A: return "Cross" if ps else "A"
		JOY_BUTTON_B: return "Circle" if ps else "B"
		JOY_BUTTON_X: return "Square" if ps else "X"
		JOY_BUTTON_Y: return "Triangle" if ps else "Y"
	return "Button %d" % index


func _is_playstation() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var pad_name := Input.get_joy_name(pads[0]).to_lower()
	for hint in ["playstation", "dualsense", "dualshock", "ps4", "ps5", "sony"]:
		if pad_name.contains(hint):
			return true
	return false
