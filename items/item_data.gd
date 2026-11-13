class_name ItemData
extends Resource
## Describes one kind of item (wood, stone, ...). Each item is a small .tres
## data file in the items/ folder. To add a new item, make a new file:
## right-click the items folder > New Resource > ItemData.
##
## Inventory (step 4) and crafting (step 5) will read these same files.

## Unique ID used by code and save files. Never change it once released.
@export var id: StringName = &""
## Name shown to the player.
@export var display_name: String = "Item"
## How many fit in one inventory slot.
@export var max_stack: int = 50
## Weight of ONE of this item. Carrying more than the limit makes you slow.
@export var weight: float = 1.0
## Gray-box placeholder: color of the dropped item cube until real art exists.
@export var drop_color: Color = Color.WHITE

@export_group("Tool")
## What this tool can gather with, e.g. "axe" or "pickaxe". Empty = not a tool.
## Must match the "required_tool" of Hittables (trees need "axe", rocks "pickaxe").
@export var tool_type: StringName = &""
## Damage per hit when used as a tool.
@export var tool_damage: int = 1
## Uses before it breaks. 0 = never wears out. Broken tools are repaired
## for free at a workbench.
@export var max_durability: int = 0
