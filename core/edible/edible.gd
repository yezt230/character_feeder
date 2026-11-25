class_name Edible
extends RigidBody2D

signal eaten
## Emitted when the animal runs off the screen (only if escape_off_screen).
signal escaped

@onready var edible_frame_controller = $EdibleFrameController
@onready var running_timer: Timer = $EdibleFrameController/RunningTimer
@onready var state_label = $StateLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $EatenHurtbox
@onready var drag_area: Area2D = $DragArea

enum State {
	RESTING,
	RUNNING,
	FALLING,
	DRAGGING,
	EATEN,
	ESCAPED
}

# ----------------------------
# PSEUDO-3D FIELD
# ----------------------------
# The walkable field (owned by the Playfield) is the full screen width and the
# bottom portion of the screen height. An animal's "depth" is the screen Y of
# its feet within that band: higher on screen = farther away (smaller, slower),
# lower = closer.
## Visual scale at the back (top) of the field.
@export var far_scale: float = 0.55
## Visual scale at the front (bottom) of the field.
@export var near_scale: float = 1.1
## Distance from the body's origin down to the animal's feet, at scale 1.
@export var foot_offset: float = 66.0
## Max vertical component of a run heading, relative to horizontal (0 = flat).
@export_range(0.0, 1.0, 0.05) var max_vertical_ratio: float = 0.6
## Depth movement appears slower on screen than sideways movement.
@export_range(0.0, 1.0, 0.05) var vertical_speed_factor: float = 0.5

## How long the grow/shrink to the neutral depth takes when grabbed.
@export var grab_scale_duration: float = 0.5

const RUN_VELOCITY: float = 150.0
const DRAG_Z_INDEX: int = 4000

var current_state: State = State.FALLING
var drag_offset := Vector2.ZERO
var run_direction: int = 1
var vertical_direction: float = 0.0

# Feet Y of the spot on the field this animal stands on / will land on.
var ground_y: float
var depth_scale: float = 1.0
var depth_scale_tween: Tween
# Scale at the moment of grabbing, so the grabbed point stays under the cursor.
var grab_scale: float = 1.0

## The Playfield this animal lives in. Set by Playfield.spawn_edible().
var playfield: Playfield
## Run off the left/right screen edges instead of turning around.
## Set by Playfield.spawn_edible() from the playfield's configuration.
var escape_off_screen: bool = false

# Original transforms of scaled children, so perspective scaling is relative.
var base_sprite_scale: Vector2
var base_shape_scale: Vector2
var base_shape_position: Vector2
var base_hurtbox_scale: Vector2
var base_drag_area_scale: Vector2


func _ready():
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

	if playfield == null:
		playfield = get_tree().get_first_node_in_group("playfield")
		assert(playfield != null, "Edible needs a Playfield; spawn it with Playfield.spawn_edible().")

	base_sprite_scale = sprite.scale
	base_shape_scale = body_shape.scale
	base_shape_position = body_shape.position
	base_hurtbox_scale = hurtbox.scale
	base_drag_area_scale = drag_area.scale

	# Pick a random spot on the field to land on.
	var field := get_field_rect()
	ground_y = randf_range(field.position.y, field.end.y)
	apply_depth_scale()

	running_timer.timeout.connect(_on_running_timer_timeout)
	running_timer.stop()

	enter_state(current_state)


# ----------------------------
# FIELD / PERSPECTIVE HELPERS
# ----------------------------

func get_field_rect() -> Rect2:
	return playfield.get_field_rect()


# 0 at the back of the field, 1 at the front.
func get_depth_t(feet_y: float) -> float:
	var field := get_field_rect()
	return clampf(inverse_lerp(field.position.y, field.end.y, feet_y), 0.0, 1.0)


func get_scale_at(feet_y: float) -> float:
	return lerpf(far_scale, near_scale, get_depth_t(feet_y))


func get_neutral_depth() -> float:
	return playfield.get_neutral_depth()


# Snaps the visual scale to match the current ground depth.
func apply_depth_scale():
	set_depth_scale(get_scale_at(ground_y))

	# Closer animals draw over farther ones (dragged ones draw on top of all).
	if current_state != State.DRAGGING:
		z_index = int(ground_y)


func set_depth_scale(value: float):
	depth_scale = value
	sprite.scale = base_sprite_scale * depth_scale
	body_shape.scale = base_shape_scale * depth_scale
	body_shape.position = base_shape_position * depth_scale
	hurtbox.scale = base_hurtbox_scale * depth_scale
	drag_area.scale = base_drag_area_scale * depth_scale


func stop_depth_scale_tween():
	if depth_scale_tween:
		depth_scale_tween.kill()


func get_feet_y() -> float:
	return global_position.y + foot_offset * depth_scale


func set_feet_y(feet_y: float):
	global_position.y = feet_y - foot_offset * depth_scale


# ----------------------------
# STATE MACHINE
# ----------------------------

func change_state(new_state: State):
	if current_state == new_state:
		return

	if current_state == State.EATEN or current_state == State.ESCAPED:
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
			# Grounded animals are moved by hand, not by physics.
			freeze = true
			linear_velocity = Vector2.ZERO
			edible_frame_controller.animal_on_ground()

		State.RUNNING:
			freeze = true
			# Field movement drives the scale directly from here on.
			stop_depth_scale_tween()
			run_direction = [-1, 1].pick_random()
			vertical_direction = randf_range(-max_vertical_ratio, max_vertical_ratio)
			edible_frame_controller.set_facing_direction(run_direction)
			edible_frame_controller.animal_running()

		State.FALLING:
			freeze = false
			edible_frame_controller.animal_in_air()

		State.DRAGGING:
			freeze = true
			linear_velocity = Vector2.ZERO
			z_index = DRAG_Z_INDEX
			# Bring the animal to the neutral (predator) depth: it grows if it was
			# farther away, shrinks if it was closer. It will land at this depth.
			grab_scale = depth_scale
			ground_y = get_neutral_depth()
			stop_depth_scale_tween()
			depth_scale_tween = create_tween()
			depth_scale_tween.tween_method(set_depth_scale, depth_scale, get_scale_at(ground_y), grab_scale_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			edible_frame_controller.animal_dragging()

		State.EATEN:
			running_timer.stop()
			eaten.emit()
			queue_free()

		State.ESCAPED:
			running_timer.stop()
			escaped.emit()
			queue_free()


func exit_state(state: State):
	match state:
		State.DRAGGING:
			freeze = false
			z_index = int(ground_y)


# ----------------------------
# INPUT
# ----------------------------

# Clicks are picked up by DragArea, not the physics body, so the grab area
# can be shaped independently of the floor/wall collision shape.
func _on_drag_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			if current_state == State.EATEN or current_state == State.ESCAPED:
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
			set_feet_y(ground_y)

		State.RUNNING:
			move_on_field(delta)

		State.FALLING:
			# Land once the feet reach this animal's spot on the field.
			if linear_velocity.y >= 0.0 and get_feet_y() >= ground_y:
				set_feet_y(ground_y)
				change_state(State.RESTING)

		State.DRAGGING:
			# Scale the grab offset with the animal so the spot that was clicked
			# stays under the cursor while it grows/shrinks.
			global_position = get_global_mouse_position() + drag_offset * (depth_scale / grab_scale)

		State.EATEN, State.ESCAPED:
			pass


func move_on_field(delta: float):
	var field := get_field_rect()

	# Farther animals move slower on screen, for perspective.
	var speed := RUN_VELOCITY * depth_scale
	global_position.x += run_direction * speed * delta
	ground_y += vertical_direction * speed * vertical_speed_factor * delta

	# Turn around at the front/back edges of the field.
	if ground_y <= field.position.y or ground_y >= field.end.y:
		ground_y = clampf(ground_y, field.position.y, field.end.y)
		vertical_direction = -vertical_direction

	apply_depth_scale()
	set_feet_y(ground_y)

	var half_width := sprite.get_rect().size.x * 0.5 * sprite.scale.x

	# Escaping animals keep going until they're fully off-screen.
	if escape_off_screen:
		if global_position.x < field.position.x - half_width or global_position.x > field.end.x + half_width:
			change_state(State.ESCAPED)
		return

	# Turn around at the left/right edges of the screen.
	var min_x := field.position.x + half_width
	var max_x := field.end.x - half_width
	if global_position.x <= min_x or global_position.x >= max_x:
		global_position.x = clampf(global_position.x, min_x, max_x)
		run_direction = -run_direction
		edible_frame_controller.set_facing_direction(run_direction)


# ----------------------------
# TIMERS
# ----------------------------

func _on_running_timer_timeout():
	if current_state != State.RESTING and current_state != State.RUNNING:
		return

	if randf() <= 0.5:
		# Re-enter RUNNING too, so a running animal can pick a new heading.
		if current_state == State.RUNNING:
			change_state(State.RESTING)
		change_state(State.RUNNING)
	else:
		change_state(State.RESTING)


# ----------------------------
# EATING
# ----------------------------

func _on_eaten_hurtbox_area_entered(area):
	change_state(State.EATEN)
