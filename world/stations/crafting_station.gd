class_name CraftingStation
extends StaticBody3D
## A place that unlocks recipes when the player is close, like a workbench.
## Recipes name the station they need by its station_id.

const GROUP := &"crafting_stations"

## Must match the "station" field of recipes that need this station.
@export var station_id: StringName = &"workbench"
## How close the player must be (in meters) to use this station's recipes.
@export var craft_range: float = 5.0


func _ready() -> void:
	add_to_group(GROUP)
