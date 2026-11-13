extends CanvasLayer
## The inventory screen: a grid of InventorySlots on the left, and the
## crafting list (recipes available right here) on the right.
##
## Open/close: Tab, or View/Select on gamepad. Esc / B / Start also closes.
## While open, the game keeps running but the player's controls are off.
##
## Moving stacks:
##   Mouse:   press on a stack, drag, release on another slot.
##   Gamepad: move the highlight (d-pad / left stick / arrow keys), press A
##            (or Enter) to grab a stack; it rides along with the highlight.
##            Press A again to drop it, B to put it back.
##
## Dropping on the ground (whole stack):
##   Mouse:   drag a stack outside the panel and release.
##   Button:  Q / Y drops the highlighted stack (or the one being held).
##
## Crafting:
##   Mouse:   click a recipe.
##   Gamepad: move right past the grid's last column into the recipe list,
##            up/down to pick, A to craft. Left goes back to the grid.
##
## The screen tracks the highlight itself and reads its own menu_* input
## actions, so it doesn't depend on Godot's built-in UI focus navigation.

enum Area { GRID, RECIPES }

@export var player: Player
@export var inventory: Inventory
@export var crafter: Crafter

var is_open: bool = false

var _slots: Array[InventorySlot] = []
var _recipe_rows: Array[RecipeRow] = []
## Recipes shown right now (same order as _recipe_rows).
var _recipes: Array[RecipeData] = []

## Which part of the screen the highlight is in.
var _area: Area = Area.GRID
## Highlighted slot index (grid) and recipe index (list).
var _cursor: int = 0
var _recipe_cursor: int = 0
## Slot index of the stack grabbed with A/Enter, or -1 when not holding one.
var _held_from: int = -1

@onready var _grid: GridContainer = $Center/Panel/Margin/Columns/InventoryColumn/Grid
@onready var _weight_label: Label = $Center/Panel/Margin/Columns/InventoryColumn/Weight
@onready var _recipe_list: VBoxContainer = $Center/Panel/Margin/Columns/CraftingColumn/Recipes
@onready var _craft_info: Label = $Center/Panel/Margin/Columns/CraftingColumn/Info
@onready var _held_label: Label = $HeldLabel
@onready var _drop_zone: InventoryDropZone = $Dim


func _ready() -> void:
	visible = false
	for i in inventory.get_slot_count():
		var slot := InventorySlot.new()
		slot.index = i
		slot.inventory = inventory
		slot.hovered.connect(_on_slot_hovered)
		slot.dropped.connect(_on_slot_dropped)
		_grid.add_child(slot)
		_slots.append(slot)
	_drop_zone.stack_dropped.connect(_drop_to_ground)
	inventory.changed.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	# _input runs before the GUI, so Tab isn't eaten by focus navigation.
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	var handled := true
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("toggle_mouse_capture"):
		if _held_from != -1:
			_held_from = -1  # First press just puts the held stack back.
			_refresh()
		else:
			close()
	elif event.is_action_pressed("menu_accept"):
		if _area == Area.GRID:
			_grab_or_drop(_cursor)
		else:
			_craft(_recipe_cursor)
	elif event.is_action_pressed("drop_item"):
		if _area == Area.GRID:
			_drop_to_ground(_held_from if _held_from != -1 else _cursor)
	elif event.is_action_pressed("menu_left"):
		_move_highlight(-1, 0)
	elif event.is_action_pressed("menu_right"):
		_move_highlight(1, 0)
	elif event.is_action_pressed("menu_up"):
		_move_highlight(0, -1)
	elif event.is_action_pressed("menu_down"):
		_move_highlight(0, 1)
	else:
		handled = false

	if handled:
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	visible = true
	_held_from = -1
	_area = Area.GRID
	_craft_info.text = ""
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	is_open = false
	visible = false
	_held_from = -1
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _move_highlight(dx: int, dy: int) -> void:
	if _area == Area.RECIPES:
		if dx < 0:
			_area = Area.GRID  # Back to the grid, where we left it.
		elif dy != 0 and not _recipes.is_empty():
			_recipe_cursor = clampi(_recipe_cursor + dy, 0, _recipes.size() - 1)
		_refresh()
		return

	var columns := _grid.columns
	var rows := ceili(float(_slots.size()) / columns)
	var col := _cursor % columns
	# Moving right from the last column enters the recipe list
	# (not while holding a stack, so it can't get lost over there).
	if dx > 0 and col == columns - 1 and not _recipes.is_empty() and _held_from == -1:
		_area = Area.RECIPES
		_refresh()
		return

	col = clampi(col + dx, 0, columns - 1)
	var row := clampi(floori(float(_cursor) / columns) + dy, 0, rows - 1)
	_cursor = mini(row * columns + col, _slots.size() - 1)
	_refresh()


func _grab_or_drop(index: int) -> void:
	if _held_from == -1:
		if inventory.get_slot(index) != null:
			_held_from = index  # Grab.
			_refresh()
	else:
		var from := _held_from
		_held_from = -1  # Drop.
		inventory.move_stack(from, index)
		_refresh()


## Takes the whole stack out of a slot and drops it in front of the player.
func _drop_to_ground(index: int) -> void:
	_held_from = -1
	var stack := inventory.take_slot(index)
	if stack != null:
		player.drop_items(stack.item, stack.amount)
	_refresh()


func _craft(recipe_index: int) -> void:
	if recipe_index < 0 or recipe_index >= _recipes.size():
		return
	var recipe := _recipes[recipe_index]
	if crafter.craft(recipe):
		_craft_info.text = "Crafted %s" % recipe.get_display_name()
	elif not crafter.has_ingredients(recipe):
		_craft_info.text = "Missing ingredients"
	else:
		_craft_info.text = "No room in inventory"
	_refresh()


func _on_slot_hovered(index: int) -> void:
	_area = Area.GRID
	_cursor = index
	_refresh()


func _on_slot_dropped(from_index: int, to_index: int) -> void:
	_held_from = -1
	_cursor = to_index
	inventory.move_stack(from_index, to_index)
	_refresh()


func _on_recipe_hovered(index: int) -> void:
	_area = Area.RECIPES
	_recipe_cursor = index
	_refresh()


func _on_recipe_clicked(index: int) -> void:
	_recipe_cursor = index
	_craft(index)


func _refresh() -> void:
	# A held stack can't vanish today, but be safe if it ever does.
	if _held_from != -1 and inventory.get_slot(_held_from) == null:
		_held_from = -1

	for i in _slots.size():
		_slots[i].show_stack(inventory.get_slot(i), i == _held_from)
		_slots[i].set_highlighted(_area == Area.GRID and i == _cursor)

	var weight := inventory.get_total_weight()
	_weight_label.text = "Weight  %d / %d" % [roundi(weight), roundi(inventory.max_weight)]
	_weight_label.modulate = Color(1.0, 0.4, 0.4) if inventory.is_overweight() else Color.WHITE

	_refresh_recipes()

	_held_label.visible = _held_from != -1
	if _held_from != -1:
		_held_label.text = InventorySlot.get_stack_text(inventory.get_slot(_held_from)).replace("\n", " ×")
		_held_label.reset_size()
		_update_held_label_position.call_deferred()


func _refresh_recipes() -> void:
	var available := crafter.get_available_recipes()
	# Only rebuild the rows when the list itself changed (e.g. near a new station).
	if available != _recipes:
		_recipes = available
		for row in _recipe_rows:
			row.queue_free()
		_recipe_rows.clear()
		for i in _recipes.size():
			var row := RecipeRow.new()
			row.index = i
			row.hovered.connect(_on_recipe_hovered)
			row.clicked.connect(_on_recipe_clicked)
			_recipe_list.add_child(row)
			_recipe_rows.append(row)

	if _recipes.is_empty():
		_recipe_cursor = 0
		if _area == Area.RECIPES:
			_area = Area.GRID
	else:
		_recipe_cursor = clampi(_recipe_cursor, 0, _recipes.size() - 1)

	for i in _recipe_rows.size():
		_recipe_rows[i].show_recipe(_recipes[i], inventory, crafter.can_craft(_recipes[i]),
				_area == Area.RECIPES and i == _recipe_cursor)


## Floats the held stack's name just above the highlighted slot.
## Deferred so the grid has finished laying out the first time it opens.
func _update_held_label_position() -> void:
	var slot := _slots[_cursor]
	_held_label.position = slot.global_position + Vector2(0, -_held_label.size.y)
