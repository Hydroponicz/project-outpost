class_name RecipeRow
extends PanelContainer
## One recipe in the crafting list: name on top, ingredients underneath
## ("Wood 3/3   Stone 1/2"). Greyed out when you can't craft it.
## Click (or highlight + A/Enter) to craft.

signal hovered(index: int)
signal clicked(index: int)

const WIDTH := 300.0

var index: int = -1

var _label := Label.new()
var _style_normal := StyleBoxFlat.new()
var _style_highlighted := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style_normal.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.3, 0.3, 0.35)
	_style_normal.set_corner_radius_all(4)
	_style_normal.set_content_margin_all(8)
	_style_highlighted = _style_normal.duplicate() as StyleBoxFlat
	_style_highlighted.border_color = Color(1.0, 0.85, 0.4)
	_style_highlighted.set_border_width_all(3)
	add_theme_stylebox_override("panel", _style_normal)

	_label.add_theme_font_size_override("font_size", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	mouse_entered.connect(_on_mouse_entered)


func show_recipe(recipe: RecipeData, inventory: Inventory, craftable: bool, highlighted: bool) -> void:
	var parts: PackedStringArray = []
	for ingredient in recipe.ingredients:
		parts.append("%s %d/%d" % [ingredient.item.display_name,
				inventory.count_item(ingredient.item), ingredient.amount])
	_label.text = "%s\n%s" % [recipe.get_display_name(), "   ".join(parts)]
	modulate.a = 1.0 if craftable else 0.45
	add_theme_stylebox_override("panel", _style_highlighted if highlighted else _style_normal)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()


func _on_mouse_entered() -> void:
	hovered.emit(index)
