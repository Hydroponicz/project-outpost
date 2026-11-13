class_name InventorySlot
extends PanelContainer
## One square in the inventory grid. Only draws itself and reports the mouse;
## the inventory screen decides which slot is highlighted.
##
## Mouse: drag a slot onto another slot (Godot's built-in drag and drop).
## Gamepad/keyboard: handled by the screen (ui/inventory_screen.gd).

## The mouse moved onto this slot.
signal hovered(index: int)
## A stack was dragged from slot "from_index" and dropped on this one.
signal dropped(from_index: int, to_index: int)

const SIZE := Vector2(84, 84)

var index: int = -1
var inventory: Inventory
## Hotbar number shown in the corner (1-8). 0 = not a hotbar slot.
var hotkey: int = 0

## Durability bar: 0..1, or -1 for "no bar".
var _durability_ratio: float = -1.0

var _label := Label.new()
var _style_normal := StyleBoxFlat.new()
var _style_highlighted := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE  # The screen handles navigation itself.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style_normal.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.3, 0.3, 0.35)
	_style_normal.set_corner_radius_all(4)
	_style_highlighted = _style_normal.duplicate() as StyleBoxFlat
	_style_highlighted.border_color = Color(1.0, 0.85, 0.4)
	_style_highlighted.set_border_width_all(3)
	add_theme_stylebox_override("panel", _style_normal)

	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	mouse_entered.connect(_on_mouse_entered)


## Shows a stack (or nothing). "dimmed" marks the slot a held stack came from.
func show_stack(stack: ItemStack, dimmed: bool) -> void:
	_label.text = get_stack_text(stack)
	modulate.a = 0.35 if dimmed else 1.0
	_durability_ratio = stack.get_durability_ratio() if stack != null else -1.0
	queue_redraw()


func set_highlighted(highlighted: bool) -> void:
	add_theme_stylebox_override("panel", _style_highlighted if highlighted else _style_normal)


static func get_stack_text(stack: ItemStack) -> String:
	if stack == null:
		return ""
	if stack.item.max_stack == 1:
		# Single items (tools) don't need a count.
		return stack.item.display_name + ("\n(broken)" if stack.is_broken() else "")
	return "%s\n%d" % [stack.item.display_name, stack.amount]


## Draws the hotbar number and the durability bar on top of the panel.
func _draw() -> void:
	if hotkey > 0:
		var font := get_theme_default_font()
		draw_string(font, Vector2(6, 16), str(hotkey), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1, 1, 1, 0.6))
	if _durability_ratio >= 0.0:
		var bar := Rect2(6, size.y - 9, size.x - 12, 4)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		var fill := Color(0.9, 0.25, 0.2).lerp(Color(0.4, 0.85, 0.3), _durability_ratio)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _durability_ratio, bar.size.y)), fill)


func _on_mouse_entered() -> void:
	hovered.emit(index)


# --- Mouse drag and drop (Godot calls these automatically) ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	var stack := inventory.get_slot(index)
	if stack == null:
		return null
	var preview := Label.new()
	preview.text = get_stack_text(stack)
	preview.add_theme_font_size_override("font_size", 15)
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 5)
	set_drag_preview(preview)
	return {"inventory_from": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory_from")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(data["inventory_from"], index)
