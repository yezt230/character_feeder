
extends RigidBody2D

signal eaten(points: int)

const Balance = preload("res://scenes/game_balance.gd")

@onready var edible_frame_controller = $EdibleFrameController
@onready var running_timer: Timer = $EdibleFrameController/RunningTimer
@onready var state_label = $StateLabel

enum State {
	RESTING,
	RUNNING,
	FALLING,
	DRAGGING,
	AUTO_JUMP,
	EATEN
}

var current_state: State = State.FALLING
var drag_offset := Vector2.ZERO
var on_ground: bool = false
var run_direction: int = 1
var score_value: int = 10
var prey_id: String = "rabbit"
@onready var rare_marker: Label = $RareMarker

const RUN_VELOCITY: float = 150.0

func _ready():
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

	contact_monitor = true
	max_contacts_reported = 10

	running_timer.timeout.connect(_on_running_timer_timeout)
	running_timer.stop()

	apply_prey_variant(edible_frame_controller.current_animal)
	enter_state(current_state)


# ----------------------------
# STATE MACHINE
# ----------------------------

func change_state(new_state: State):
	if current_state == new_state:
		return

	if current_state == State.EATEN:
		return

	exit_state(current_state)

	current_state = new_state
	enter_state(current_state)

	# The timer runs ONLY in ground states.
	if current_state == State.RESTING or current_state == State.RUNNING:
		if running_timer.is_stopped():
			running_timer.start()
	else:
		running_timer.stop()


func enter_state(state: State):
	state_label.text = str(state)
	match state:
		State.RESTING:
			linear_velocity.x = 0.0
			edible_frame_controller.animal_on_ground()

		State.RUNNING:
			run_direction = [-1, 1].pick_random()
			edible_frame_controller.set_facing_direction(run_direction)
			edible_frame_controller.animal_running()

		State.FALLING:
			freeze = false
			linear_velocity.x = 0.0
			edible_frame_controller.animal_in_air()

		State.DRAGGING:
			freeze = true
			linear_velocity = Vector2.ZERO
			edible_frame_controller.animal_dragging()

		State.AUTO_JUMP:
			freeze = true
			linear_velocity = Vector2.ZERO
			edible_frame_controller.animal_in_air()

		State.EATEN:
			running_timer.stop()
			eaten.emit(score_value)
			queue_free()


func exit_state(state: State):
	match state:
		State.RUNNING:
			linear_velocity.x = 0.0

		State.DRAGGING, State.AUTO_JUMP:
			freeze = false


# ----------------------------
# INPUT
# ----------------------------

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			if current_state == State.EATEN or current_state == State.AUTO_JUMP:
				return

			drag_offset = global_position - get_global_mouse_position()

			change_state(State.DRAGGING)

			get_viewport().set_input_as_handled()


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:

			if current_state == State.DRAGGING:
				change_state(State.FALLING)


# ----------------------------
# PHYSICS
# ----------------------------

func _physics_process(delta):
	match current_state:
		State.RESTING:
			if not is_on_ground():
				change_state(State.FALLING)

		State.RUNNING:
			if not is_on_ground():
				change_state(State.FALLING)
			else:
				linear_velocity.x = RUN_VELOCITY * run_direction

		State.FALLING:
			if is_on_ground():
				change_state(State.RESTING)

		State.DRAGGING:
			global_position = get_global_mouse_position() + drag_offset

		State.AUTO_JUMP, State.EATEN:
			pass


# Checks whether a contact is supporting the Edible.
func is_on_ground() -> bool:
	return on_ground


# ----------------------------
# TIMERS
# ----------------------------

func _on_running_timer_timeout():
	if current_state != State.RESTING and current_state != State.RUNNING:
		return

	if randf() <= 0.5:
		change_state(State.RUNNING)
	else:
		change_state(State.RESTING)

func _integrate_forces(state: PhysicsDirectBodyState2D):
	on_ground = false
	for i in range(state.get_contact_count()):
		var normal = state.get_contact_local_normal(i)
		if normal.dot(Vector2.UP) > 0.7:
			on_ground = true
			break
# ----------------------------
# EATING
# ----------------------------

func _on_eaten_hurtbox_area_entered(area):
	if area.name != "EatenHitbox":
		return
	var predator = area.get_parent()
	if predator.has_method("can_eat") and not predator.can_eat():
		return
	change_state(State.EATEN)


# Any entry in game_balance.gd/PREY_TYPES can be displayed without new code.
# Special variants reuse the animations of their base_animal.
func apply_prey_variant(variant_id: String) -> void:
	if not Balance.PREY_TYPES.has(variant_id):
		push_warning("Unknown prey variant: " + variant_id)
		return
	var info: Dictionary = Balance.PREY_TYPES[variant_id]
	var base_animal: String = str(info["base_animal"])
	if not edible_frame_controller.animals.has(base_animal):
		push_warning("Missing sprite frames for: " + base_animal)
		return
	prey_id = variant_id
	score_value = int(info["points"])
	edible_frame_controller.current_animal = base_animal
	edible_frame_controller.animal_in_air()
	$Sprite2D.modulate = Color(str(info.get("tint", "#ffffff")))
	rare_marker.visible = bool(info.get("rare", false))


func can_auto_jump() -> bool:
	return current_state == State.RESTING or current_state == State.RUNNING or current_state == State.FALLING


func auto_jump_into_mouth(target_position: Vector2) -> void:
	if not can_auto_jump():
		return
	change_state(State.AUTO_JUMP)
	var highest_position: Vector2 = (global_position + target_position) / 2.0 + Vector2(0.0, -150.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", highest_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_auto_jump)


func _finish_auto_jump() -> void:
	var predator = get_tree().get_first_node_in_group("predator")
	if predator != null and predator.can_eat():
		change_state(State.EATEN)
	else:
		change_state(State.FALLING)
