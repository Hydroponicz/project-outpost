class_name Crafter
extends Node
## Lives on the player. Knows every recipe, which ones are available right
## now (by hand, or because the right station is nearby), and does the crafting.
##
## Crafting is instant and done by the player. (Timed processing, like a
## smelter, is a separate system for workers later.)

const RECIPE_FOLDER := "res://crafting/recipes/"

@export var inventory: Inventory
## The player's body, used to measure distance to stations.
@export var body: Node3D

## Every recipe found in RECIPE_FOLDER.
var recipes: Array[RecipeData] = []


func _ready() -> void:
	_load_recipes()


## Recipes that can be made here: hand recipes, plus those whose station is in range.
func get_available_recipes() -> Array[RecipeData]:
	var available: Array[RecipeData] = []
	for recipe in recipes:
		if recipe.station == &"" or is_station_near(recipe.station):
			available.append(recipe)
	return available


func is_station_near(station_id: StringName) -> bool:
	for node in get_tree().get_nodes_in_group(CraftingStation.GROUP):
		var station := node as CraftingStation
		if station != null and station.station_id == station_id \
				and station.global_position.distance_to(body.global_position) <= station.craft_range:
			return true
	return false


func has_ingredients(recipe: RecipeData) -> bool:
	for ingredient in recipe.ingredients:
		if inventory.count_item(ingredient.item) < ingredient.amount:
			return false
	return true


func has_space_for(recipe: RecipeData) -> bool:
	return inventory.get_space_for(recipe.output) >= recipe.output_amount


func can_craft(recipe: RecipeData) -> bool:
	return has_ingredients(recipe) and has_space_for(recipe)


## Uses up the ingredients and adds the result. Returns false if it couldn't.
func craft(recipe: RecipeData) -> bool:
	if not can_craft(recipe):
		return false
	for ingredient in recipe.ingredients:
		inventory.remove_item(ingredient.item, ingredient.amount)
	inventory.add_item(recipe.output, recipe.output_amount)
	return true


func _load_recipes() -> void:
	for file in DirAccess.get_files_at(RECIPE_FOLDER):
		# Exported games rename files to "name.tres.remap"; load the original name.
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var recipe := load(RECIPE_FOLDER + file_name) as RecipeData
		if recipe != null and recipe.output != null:
			recipes.append(recipe)
	recipes.sort_custom(_sort_recipes)


## Hand recipes first, then by name, so the list is always in the same order.
static func _sort_recipes(a: RecipeData, b: RecipeData) -> bool:
	var a_by_hand := a.station == &""
	var b_by_hand := b.station == &""
	if a_by_hand != b_by_hand:
		return a_by_hand
	return a.get_display_name() < b.get_display_name()
