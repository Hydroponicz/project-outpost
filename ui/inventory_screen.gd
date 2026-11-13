class_name InventoryScreen
extends CanvasLayer
## The inventory screen: your grid of InventorySlots on the left. On the
## right, either the crafting list, or (when opened from a chest) the
## chest's grid.
##
## Open/close: Tab, or View/Select on gamepad. Esc / B / Start also closes.
## Interacting with a chest (E) opens it with the chest's grid.
## While open, the game keeps running but the player's controls are off.
##
## Moving stacks (also between your inventory and a chest):
##   Mouse:   press on a stack, drag, release on another slot.
##   Gamepad: move the highlight (d-pad / left stick / arrow keys), press A
##            (or Enter) to grab a stack; it rides along with the highlight.
##            Press A again to drop it, B to put it back.
##
## Dropping on the ground (whole stack):
##   Mouse:   drag a stack outside the panel and release.
##   Button:  Q / Y drops the highlighted stack (or the one being held).
##
## Hotbar: the top row of your slots (numbered 1-8) is the hotbar.
##
## Crafting (when not at a chest):
##   Mouse:   click a recipe.
##   Gamepad: move right past your grid's last column into the recipe list,
##            up/down to pick, A to craft. Left goes back to the grid.
##
## The screen tracks the highlight itself and reads its own menu_* input
## actions, so it doesn't depend on Godot's built-in UI focus navigation.

## Which part of the screen the highlight is in.
enum Area { GRID, CHEST, RECIPES }

## Stands in for the "Repair tools" row in the crafting list.
const REPAIR_ENTRY := &"repair"

@export var player: Player
@export var inventory: Inventory
@export var crafter: Crafter

var is_open: bool = false

var _slots: Array[InventorySlot] = []
var _chest_slots: Array[InventorySlot] = []
## The open chest's inventory, or null when not at a chest.
var _chest: Inventory = null

var _recipe_rows: Array[RecipeRow] = []
## Crafting list entries shown right now (same order as _recipe_rows):
## RecipeData, or REPAIR_ENTRY for the repair row.
var _recipes: Array = []

var _area: Area = Area.GRID
## Highlighted index in each area.
var _cursor: int = 0
var _chest_cursor: int = 0
var _recipe_cursor: int = 0
## The stack grabbed with A/Enter: which inventory and slot, or null / -1.
var _held_inventory: Inventory = null
var _held_index: int = -1

@onready var _grid: GridContainer = $Center/Panel/Margin/Columns/InventoryColumn/Grid
@onready var _weight_label: Label = $Center/Panel/Margin/Columns/InventoryColumn/Weight
@onready var _crafting_column: Control = $Center/Panel/Margin/Columns/CraftingColumn
@onready var _recipe_list: VBoxContainer = $Center/Panel/Margin/Columns/CraftingColumn/Recipes
@onready var _craft_info: Label = $Center/Panel/Margin/Columns/CraftingColumn/Info
@onready var _chest_column: Control = $Center/Panel/Margin/Columns/ChestColumn
@onready var _chest_title: Label = $Center/Panel/Margin/Columns/ChestColumn/Title
@onready var _chest_grid: GridContainer = $Center/Panel/Margin/Columns/ChestColumn/Grid
@onready var _held_label: Label = $HeldLabel
@onready var _drop_zone: InventoryDropZone = $Dim


func _ready() -> void:
	visible = false
	for i in inventory.get_slot_count():
		var slot := _make_slot(inventory, i)
		if i < Hotbar.SIZE:
			slot.hotkey = i + 1  # Top row = hotbar.
		_grid.add_child(slot)
		_slots.append(slot)
	_drop_zone.stack_dropped.connect(_drop_to_ground)
	inventory.changed.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	# _input runs before the GUI, so Tab isn't eaten by focus navigation.
	if event.is_action_pressed("inventory"):
		if not is_open and not player.controls_enabled:
			return  # Another menu (e.g. the build menu) is open.
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


## Menu controls are read once per frame as "just pressed", not from input
## events: an analog stick sends a stream of events while held, which would
## skip several slots per push.
func _process(_delta: float) -> void:
	if not is_open:
		return
	if Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("pause"):
		if _held_index != -1:
			_clear_held()  # First press just puts the held stack back.
			_refresh()
		else:
			close()
	elif Input.is_action_just_pressed("menu_accept"):
		match _area:
			Area.GRID:
				_grab_or_drop(inventory, _cursor)
			Area.CHEST:
				_grab_or_drop(_chest, _chest_cursor)
			Area.RECIPES:
				_craft(_recipe_cursor)
	elif Input.is_action_just_pressed("drop_item"):
		if _held_index != -1:
			_drop_to_ground(_held_inventory, _held_index)
		elif _area == Area.GRID:
			_drop_to_ground(inventory, _cursor)
		elif _area == Area.CHEST:
			_drop_to_ground(_chest, _chest_cursor)
	elif Input.is_action_just_pressed("menu_left"):
		_move_highlight(-1, 0)
	elif Input.is_action_just_pressed("menu_right"):
		_move_highlight(1, 0)
	elif Input.is_action_just_pressed("menu_up"):
		_move_highlight(0, -1)
	elif Input.is_action_just_pressed("menu_down"):
		_move_highlight(0, 1)


## Opens your inventory with the crafting list.
func open() -> void:
	_open(null, "")


## Opens your inventory next to a chest (or any other container).
func open_container(container: Inventory, title: String) -> void:
	_open(container, title)


func close() -> void:
	is_open = false
	visible = false
	_clear_held()
	_set_chest(null, "")
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open(container: Inventory, title: String) -> void:
	is_open = true
	visible = true
	_clear_held()
	_area = Area.GRID
	_craft_info.text = ""
	_set_chest(container, title)
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## Shows the chest column (and hides crafting), or the other way round.
func _set_chest(container: Inventory, title: String) -> void:
	if _chest != null and _chest.changed.is_connected(_refresh):
		_chest.changed.disconnect(_refresh)
	for slot in _chest_slots:
		slot.queue_free()
	_chest_slots.clear()

	_chest = container
	_chest_cursor = 0
	_chest_column.visible = _chest != null
	_crafting_column.visible = _chest == null
	if _chest == null:
		return
	_chest_title.text = title
	for i in _chest.get_slot_count():
		var slot := _make_slot(_chest, i)
		_chest_grid.add_child(slot)
		_chest_slots.append(slot)
	_chest.changed.connect(_refresh)


func _make_slot(owner_inventory: Inventory, index: int) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.index = index
	slot.inventory = owner_inventory
	slot.hovered.connect(_on_slot_hovered)
	slot.dropped.connect(_on_slot_dropped)
	return slot


func _move_highlight(dx: int, dy: int) -> void:
	match _area:
		Area.RECIPES:
			if dx < 0:
				_area = Area.GRID  # Back to the grid, where we left it.
			elif dy != 0 and not _recipes.is_empty():
				_recipe_cursor = clampi(_recipe_cursor + dy, 0, _recipes.size() - 1)
		Area.CHEST:
			var columns := _chest_grid.columns
			if dx < 0 and _chest_cursor % columns == 0:
				_area = Area.GRID  # Off the chest's left edge, back to your grid.
			else:
				_chest_cursor = _step(_chest_cursor, _chest_slots.size(), columns, dx, dy)
		Area.GRID:
			var columns := _grid.columns
			if dx > 0 and _cursor % columns == columns - 1:
				# Off your grid's right edge: into the chest, or the recipe list
				# (not while holding a stack, so it can't get lost over there).
				if _chest != null:
					_area = Area.CHEST
				elif not _recipes.is_empty() and _held_index == -1:
					_area = Area.RECIPES
			else:
				_cursor = _step(_cursor, _slots.size(), columns, dx, dy)
	_refresh()


## Moves an index around a grid by whole columns/rows, stopping at the edges.
static func _step(index: int, count: int, columns: int, dx: int, dy: int) -> int:
	var rows := ceili(float(count) / columns)
	var col := clampi(index % columns + dx, 0, columns - 1)
	var row := clampi(floori(float(index) / columns) + dy, 0, rows - 1)
	return mini(row * columns + col, count - 1)


func _grab_or_drop(target_inventory: Inventory, index: int) -> void:
	if _held_index == -1:
		if target_inventory.get_slot(index) != null:
			_held_inventory = target_inventory  # Grab.
			_held_index = index
	else:
		var from_inventory := _held_inventory
		var from_index := _held_index
		_clear_held()  # Drop.
		Inventory.transfer(from_inventory, from_index, target_inventory, index)
	_refresh()


## Takes the whole stack out of a slot and drops it in front of the player.
func _drop_to_ground(from_inventory: Inventory, index: int) -> void:
	_clear_held()
	var stack := from_inventory.take_slot(index)
	if stack != null:
		player.drop_items(stack.item, stack.amount, stack.durability)
	_refresh()


func _clear_held() -> void:
	_held_inventory = null
	_held_index = -1


func _craft(recipe_index: int) -> void:
	if recipe_index < 0 or recipe_index >= _recipes.size():
		return
	var entry: Variant = _recipes[recipe_index]
	if entry is StringName and entry == REPAIR_ENTRY:
		var repaired := crafter.repair_all()
		if repaired == 0:
			_craft_info.text = "Nothing to repair"
		elif repaired == 1:
			_craft_info.text = "Repaired 1 tool"
		else:
			_craft_info.text = "Repaired %d tools" % repaired
		_refresh()
		return

	var recipe: RecipeData = entry
	if crafter.craft(recipe):
		_craft_info.text = "Crafted %s" % recipe.get_display_name()
	elif not crafter.has_ingredients(recipe):
		_craft_info.text = "Missing ingredients"
	else:
		_craft_info.text = "No room in inventory"
	_refresh()


func _on_slot_hovered(slot: InventorySlot) -> void:
	if slot.inventory == inventory:
		_area = Area.GRID
		_cursor = slot.index
	else:
		_area = Area.CHEST
		_chest_cursor = slot.index
	_refresh()


func _on_slot_dropped(from_inventory: Inventory, from_index: int, to_slot: InventorySlot) -> void:
	_clear_held()
	Inventory.transfer(from_inventory, from_index, to_slot.inventory, to_slot.index)
	_on_slot_hovered(to_slot)  # Highlight where it landed (also refreshes).


func _on_recipe_hovered(index: int) -> void:
	_area = Area.RECIPES
	_recipe_cursor = index
	_refresh()


func _on_recipe_clicked(index: int) -> void:
	_recipe_cursor = index
	_craft(index)


func _refresh() -> void:
	# A held stack can't vanish today, but be safe if it ever does.
	if _held_index != -1 and (_held_inventory == null or _held_inventory.get_slot(_held_index) == null):
		_clear_held()

	for i in _slots.size():
		_slots[i].show_stack(inventory.get_slot(i), _held_inventory == inventory and i == _held_index)
		_slots[i].set_highlighted(_area == Area.GRID and i == _cursor)
	for i in _chest_slots.size():
		_chest_slots[i].show_stack(_chest.get_slot(i), _held_inventory == _chest and i == _held_index)
		_chest_slots[i].set_highlighted(_area == Area.CHEST and i == _chest_cursor)

	var weight := inventory.get_total_weight()
	_weight_label.text = "Weight  %d / %d" % [roundi(weight), roundi(inventory.max_weight)]
	_weight_label.modulate = Color(1.0, 0.4, 0.4) if inventory.is_overweight() else Color.WHITE

	_refresh_recipes()

	_held_label.visible = _held_index != -1
	if _held_index != -1:
		var held_text := InventorySlot.get_stack_text(_held_inventory.get_slot(_held_index))
		_held_label.text = held_text.replace("\n", " ×")
		_held_label.reset_size()
		_update_held_label_position.call_deferred()


func _refresh_recipes() -> void:
	var available: Array = []
	if crafter.can_repair_here():
		available.append(REPAIR_ENTRY)
	available.append_array(crafter.get_available_recipes())
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
		var highlighted := _area == Area.RECIPES and i == _recipe_cursor
		var entry: Variant = _recipes[i]
		if entry is StringName and entry == REPAIR_ENTRY:
			_recipe_rows[i].show_entry("Repair tools", "Free at the workbench",
					inventory.has_damaged_items(), highlighted)
		else:
			var recipe: RecipeData = entry
			_recipe_rows[i].show_recipe(recipe, inventory, crafter.can_craft(recipe), highlighted)


## Floats the held stack's name just above the highlighted slot.
## Deferred so the grid has finished laying out the first time it opens.
func _update_held_label_position() -> void:
	var slot: InventorySlot = null
	if _area == Area.CHEST and _chest_cursor < _chest_slots.size():
		slot = _chest_slots[_chest_cursor]
	elif _cursor < _slots.size():
		slot = _slots[_cursor]
	if slot != null:
		_held_label.position = slot.global_position + Vector2(0, -_held_label.size.y)
