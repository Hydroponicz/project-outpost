class_name Worker
extends CharacterBody3D
## A worker that does a job at a Workplace on its own.
##
## Woodcutter routine:
##   1. Walk to the nearest grown tree inside the post's work radius.
##   2. Chop it (workers don't need tools). The drops go into its hands.
##   3. Walk back and put everything into the post's storage.
##   4. If the post has a sapling and a spot where a tree was cut, walk
##      there and plant it. (A separate step, so a Forester job can take
##      it over later.)
##   5. Repeat. If storage is full or there are no trees, wait and say why.
##
## Press Interact (E) on a worker to assign it to the nearest post that has
## no worker yet; press again to unassign.
##
## Movement uses Godot's navigation (NavigationAgent3D), so workers walk
## around walls and trees. All walking goes through _walk_to().

enum State { IDLE, TO_TREE, CHOPPING, RETURNING, TO_PLANT, PLANTING, WAITING }

## Every worker is in this group, so saving can find them.
const GROUP := &"workers"

@export var worker_name: String = "Worker"
@export var move_speed: float = 3.5
## Seconds between chops.
@export var chop_interval: float = 1.2
@export var chop_damage: int = 1
## Seconds spent planting a sapling.
@export var plant_time: float = 1.5
## Seconds to wait before checking again when there's nothing to do.
@export var wait_time: float = 2.0
## Give up on a target that takes longer than this to reach (seconds).
@export var give_up_time: float = 30.0

## Trees currently being worked on, so two workers don't pick the same one.
static var _claimed_trees: Dictionary = {}

var workplace: Workplace = null

var _state: State = State.IDLE
var _target_tree: ResourceNode = null
var _plant_spot: Vector3
var _timer: float = 0.0
var _travel_time: float = 0.0
var _pending_workplace_id: String = ""
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _carry: Inventory = $Carry
@onready var _label: Label3D = $StatusLabel
@onready var _visual: Node3D = $Visual
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(GROUP)
	_interactable.interacted.connect(_on_interacted)
	_set_state(State.IDLE)


func _exit_tree() -> void:
	_release_tree()


# --- Assignment ---

func assign(new_workplace: Workplace) -> void:
	unassign()
	workplace = new_workplace
	workplace.set_worker(self)
	_interactable.action_text = "Unassign"
	_decide()


func unassign() -> void:
	_release_tree()
	if workplace != null and is_instance_valid(workplace) and workplace.worker == self:
		workplace.set_worker(null)
	workplace = null
	if is_inside_tree():
		_interactable.action_text = "Assign"
		_set_state(State.IDLE)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if workplace != null:
		unassign()
		if player:
			player.show_message("%s is now idle" % worker_name)
		return
	var nearest: Workplace = null
	for node in get_tree().get_nodes_in_group(Workplace.GROUP):
		var candidate := node as Workplace
		if candidate.worker != null:
			continue
		if nearest == null or candidate.global_position.distance_to(global_position) \
				< nearest.global_position.distance_to(global_position):
			nearest = candidate
	if nearest == null:
		if player:
			player.show_message("No free workplace. Build a Woodcutter's Post.")
		return
	assign(nearest)
	if player:
		player.show_message("%s now works at the %s" % [worker_name, nearest.display_name])


# --- Called by a tree when this worker breaks it ---

func collect_drops(drops: Array) -> void:
	for drop in drops:
		_carry.add_item(drop[0], drop[1])


# --- The routine ---

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _pending_workplace_id != "":
		_resolve_pending_workplace()
	if workplace != null and not is_instance_valid(workplace):
		unassign()

	match _state:
		State.IDLE:
			pass
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_decide()
		State.TO_TREE:
			if not _tree_still_there():
				_decide()
			elif _walk_to(_target_tree.global_position, 1.6, delta):
				_set_state(State.CHOPPING)
				_timer = chop_interval
		State.CHOPPING:
			_face(_target_tree.global_position if _tree_still_there() else global_position)
			_timer -= delta
			if not _tree_still_there():
				_decide()
			elif _timer <= 0.0:
				_timer = chop_interval
				_chop()
		State.RETURNING:
			if _walk_to(workplace.global_position, 1.8, delta):
				_deposit()
		State.TO_PLANT:
			if _walk_to(_plant_spot, 0.8, delta):
				_set_state(State.PLANTING)
				_timer = plant_time
		State.PLANTING:
			_timer -= delta
			if _timer <= 0.0:
				_plant()

	move_and_slide()


## Picks the next thing to do.
func _decide() -> void:
	_release_tree()
	if workplace == null:
		_set_state(State.IDLE)
		return
	if not _carry.is_empty():
		_set_state(State.RETURNING)
		return

	var storage := workplace.get_inventory()
	var sapling := _find_sapling(storage)
	if sapling != null and not workplace.plant_spots.is_empty():
		_plant_spot = workplace.plant_spots[0]
		_set_state(State.TO_PLANT)
		return

	if not _storage_has_room(storage):
		_wait("Storage full")
		return

	_target_tree = _find_tree()
	if _target_tree == null:
		_wait("No trees in range")
		return
	_claimed_trees[_target_tree] = self
	_set_state(State.TO_TREE)


func _chop() -> void:
	var tree := _target_tree
	var spot := tree.global_position
	var hittable := Hittable.find_on(tree)
	if hittable == null:
		_decide()
		return
	hittable.take_hit(self, chop_damage)
	if tree.is_queued_for_deletion():
		workplace.add_plant_spot(spot)  # Remember where a sapling can go.
		_decide()


func _deposit() -> void:
	var storage := workplace.get_inventory()
	for i in _carry.get_slot_count():
		var stack := _carry.get_slot(i)
		if stack == null:
			continue
		var leftover := storage.add_item(stack.item, stack.amount, stack.durability)
		if leftover > 0:
			stack.amount = leftover
		else:
			_carry.set_slot(i, null)
	if _carry.is_empty():
		_decide()
	else:
		_wait("Storage full")


func _plant() -> void:
	var storage := workplace.get_inventory()
	var sapling := _find_sapling(storage)
	workplace.plant_spots.erase(_plant_spot)
	if sapling != null and storage.remove_item(sapling, 1) == 1:
		var plant: Node3D = sapling.plant_scene.instantiate()
		get_tree().current_scene.add_child(plant)
		plant.global_position = _plant_spot
	_decide()


# --- Helpers ---

## Walks toward "goal" this frame. Returns true once within "arrive_distance".
## This is the one place movement happens; swap it out to change pathfinding.
func _walk_to(goal: Vector3, arrive_distance: float, delta: float) -> bool:
	var flat := goal - global_position
	flat.y = 0.0
	if flat.length() <= arrive_distance:
		_travel_time = 0.0
		return true

	_travel_time += delta
	if _travel_time > give_up_time:
		_travel_time = 0.0
		_wait("Can't get there")
		return false

	if _agent.target_position.distance_to(goal) > 0.1:
		_agent.target_position = goal
	var next := _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		direction = flat  # No path yet (map still building): walk straight.
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face(global_position + direction)
	return false


func _face(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		_visual.rotation.y = atan2(-direction.x, -direction.z)


func _find_tree() -> ResourceNode:
	var best: ResourceNode = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		var tree := node as ResourceNode
		if tree.is_queued_for_deletion() or tree.get_required_tool() != &"axe":
			continue
		if not workplace.is_in_range(tree.global_position):
			continue
		var claimer: Variant = _claimed_trees.get(tree)
		if claimer != null and claimer != self and is_instance_valid(claimer):
			continue
		var distance := tree.global_position.distance_to(global_position)
		if distance < best_distance:
			best = tree
			best_distance = distance
	return best


func _tree_still_there() -> bool:
	return _target_tree != null and is_instance_valid(_target_tree) \
			and not _target_tree.is_queued_for_deletion()


func _release_tree() -> void:
	if _target_tree != null and _claimed_trees.get(_target_tree) == self:
		_claimed_trees.erase(_target_tree)
	_target_tree = null


static func _find_sapling(storage: Inventory) -> ItemData:
	for i in storage.get_slot_count():
		var stack := storage.get_slot(i)
		if stack != null and stack.item.plant_scene != null:
			return stack.item
	return null


## True if at least some wood would fit (what a tree mostly gives).
func _storage_has_room(storage: Inventory) -> bool:
	var wood := GameDatabase.get_item(&"wood")
	return wood == null or storage.get_space_for(wood) > 0


func _wait(reason: String) -> void:
	_set_state(State.WAITING, reason)
	_timer = wait_time


func _set_state(state: State, reason: String = "") -> void:
	_state = state
	_travel_time = 0.0
	var text := ""
	match state:
		State.IDLE: text = "Idle"
		State.TO_TREE: text = "Walking to tree"
		State.CHOPPING: text = "Chopping"
		State.RETURNING: text = "Returning"
		State.TO_PLANT: text = "Walking to plant"
		State.PLANTING: text = "Planting"
		State.WAITING: text = reason
	_label.text = "%s\n%s" % [worker_name, text]


# --- Saving ---

func get_save_data() -> Dictionary:
	return {
		"scene": scene_file_path,
		"name": worker_name,
		"position": [global_position.x, global_position.y, global_position.z],
		"workplace": workplace.workplace_id if workplace != null else "",
		"carry": _carry.get_save_data(),
	}


func apply_save_data(data: Dictionary) -> void:
	worker_name = str(data.get("name", worker_name))
	var pos: Array = data.get("position", [0, 0, 0])
	global_position = Vector3(pos[0], pos[1], pos[2])
	_carry.apply_save_data(data.get("carry", []))
	_pending_workplace_id = str(data.get("workplace", ""))
	_set_state(State.IDLE)


## After loading, find the saved workplace by its ID (it may load later).
func _resolve_pending_workplace() -> void:
	for node in get_tree().get_nodes_in_group(Workplace.GROUP):
		var candidate := node as Workplace
		if candidate.workplace_id == _pending_workplace_id:
			_pending_workplace_id = ""
			assign(candidate)
			return
	_pending_workplace_id = ""  # It's gone; stay idle.
