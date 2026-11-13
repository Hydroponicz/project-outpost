class_name Vitals
extends Node
## Health, stamina and hunger.
##
## Hunger slowly drains. Below the "low" mark, stamina recovers at half
## speed and health stops regenerating. At zero you slowly lose health.
## Stamina is used by sprinting, jumping and tool swings; once empty you're
## "exhausted" until it has partly recovered.
## Every number is in the Inspector (select the Vitals node on the Player).

signal changed
signal died

@export_group("Health")
@export var max_health: float = 100.0
## Health regained per second while fed (hunger above the low mark).
@export var health_regen_per_second: float = 0.5

@export_group("Hunger")
@export var max_hunger: float = 100.0
## Seconds for hunger to go from full to empty.
@export var hunger_drain_time: float = 1200.0
## Fraction of hunger (0-1) below which you count as "hungry".
@export_range(0.0, 1.0) var low_hunger: float = 0.25
## Health lost per second while starving (hunger at zero).
@export var starve_damage_per_second: float = 0.5

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen_per_second: float = 25.0
## Seconds after using stamina before it starts refilling.
@export var stamina_regen_delay: float = 1.0
## Once empty, stamina must refill to this before you can use it again.
@export var exhausted_recover_at: float = 20.0
@export var sprint_cost_per_second: float = 12.0
@export var jump_cost: float = 10.0
@export var swing_cost: float = 8.0

var health: float
var stamina: float
var hunger: float
var is_dead: bool = false

var _exhausted: bool = false
var _regen_wait: float = 0.0


func _ready() -> void:
	reset()


func reset(hunger_fraction: float = 1.0) -> void:
	health = max_health
	stamina = max_stamina
	hunger = max_hunger * hunger_fraction
	is_dead = false
	_exhausted = false
	_regen_wait = 0.0
	changed.emit()


func is_hungry() -> bool:
	return hunger < max_hunger * low_hunger


func is_exhausted() -> bool:
	return _exhausted


## Spends stamina for a one-off action (jump, swing). Returns false (and
## spends nothing) if you're too tired.
func use_stamina(amount: float) -> bool:
	if _exhausted or stamina <= 0.0:
		return false
	_spend(amount)
	return true


## Spends stamina over time (sprinting). Returns false if too tired.
func drain_stamina(per_second: float, delta: float) -> bool:
	if _exhausted:
		return false
	_spend(per_second * delta)
	return true


func damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	changed.emit()
	if health <= 0.0:
		is_dead = true
		died.emit()


## Eats a food item. Returns false if it isn't food or you're already full.
func eat(item: ItemData) -> bool:
	if item.hunger_restore <= 0.0 or hunger >= max_hunger - 0.5:
		return false
	hunger = minf(hunger + item.hunger_restore, max_hunger)
	changed.emit()
	return true


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	hunger = maxf(hunger - max_hunger / hunger_drain_time * delta, 0.0)
	if hunger <= 0.0:
		damage(starve_damage_per_second * delta)
	elif not is_hungry():
		health = minf(health + health_regen_per_second * delta, max_health)

	if _regen_wait > 0.0:
		_regen_wait -= delta
	else:
		var regen := stamina_regen_per_second * (0.5 if is_hungry() else 1.0)
		stamina = minf(stamina + regen * delta, max_stamina)
		if _exhausted and stamina >= exhausted_recover_at:
			_exhausted = false

	changed.emit()


func _spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = stamina_regen_delay
	if stamina <= 0.0:
		_exhausted = true
	changed.emit()


func get_save_data() -> Dictionary:
	return {"health": health, "stamina": stamina, "hunger": hunger}


func apply_save_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", max_health)), 1.0, max_health)
	stamina = clampf(float(data.get("stamina", max_stamina)), 0.0, max_stamina)
	hunger = clampf(float(data.get("hunger", max_hunger)), 0.0, max_hunger)
	changed.emit()
