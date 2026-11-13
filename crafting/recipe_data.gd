class_name RecipeData
extends Resource
## One crafting recipe. Each recipe is a .tres file in crafting/recipes/.
## To add a recipe: right-click that folder > New Resource > RecipeData,
## then fill in the output, ingredients and (optionally) the station.
## Every file in the folder is loaded automatically.

## What gets made.
@export var output: ItemData
@export var output_amount: int = 1
## What gets used up.
@export var ingredients: Array[ItemAmount] = []
## ID of the station that must be nearby (e.g. "workbench").
## Leave empty to craft by hand anywhere.
@export var station: StringName = &""


func get_display_name() -> String:
	if output_amount > 1:
		return "%s ×%d" % [output.display_name, output_amount]
	return output.display_name
