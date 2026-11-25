class_name Playfield
extends Node2D
## The shared game world: background, scenery, predator, walls and the
## animals. Every game mode instances this scene and drives it through the
## public API below (spawn_edible, signals, field helpers). Mode-specific rules
## (goals, spawning patterns, HUD) live in the mode scenes, never in here.

signal edible_spawned(edible: Edible)
signal edible_eaten(edible: Edible)
signal edible_escaped(edible: Edible)

# ----------------------------
# MODE CONFIGURATION
# ----------------------------
# Modes repurpose the playfield by overriding these on their Playfield instance.

## Show the background art (turn off for a transparent desktop-pet window).
@export var show_background: bool = true:
	set(value):
		show_background = value
		if is_node_ready():
			background.visible = value

@export var flower : PackedScene
@export var flower_count : int = 8

## Fraction of the screen height (from the bottom) that animals can walk in.
@export_range(0.05, 1.0, 0.01) var field_height_fraction: float = 0.3

## When true, running animals leave the screen at the left/right edges instead
## of turning around, and edible_escaped is emitted.
@export var edibles_escape_off_screen: bool = false

## Flower placement as fractions of the visible screen (0 = left/top, 1 = right/bottom).
## Flowers spawn in one of two horizontal bands, leaving the centre clear for the seat.
@export var left_band := Vector2(0.0, 0.35)
@export var right_band := Vector2(0.69, 0.95)
@export var vertical_band := Vector2(0.69, 0.93)

## Distance (in screen pixels) from the bottom of the seat sprite up to the middle
## of its base footprint. Animals whose feet are above this line are "behind"
## the seat and predator; below it, they're in front.
@export var seat_footprint_offset : float = 42.0

# Plain Node2D (not a CanvasLayer), placed after the background and before the
# seat/predator in the scene tree, so flowers draw above the background but
# beneath the predator and its growing belly.
@onready var background : Node2D = $Background
@onready var flower_layer : Node2D = $FlowerLayer
@onready var seat_sprite : Sprite2D = $SeatSprite
@onready var predator : Predator = $Predator
@onready var edible_layer : Node2D = $EdibleLayer
@onready var cover : Node2D = $Cover


func _ready():
	background.visible = show_background
	apply_depth_sorting()
	spawn_flowers()


# ----------------------------
# PUBLIC API
# ----------------------------

## Spawns an edible at a global position and wires it into the playfield.
## All modes should spawn animals through here.
func spawn_edible(edible_scene: PackedScene, spawn_position: Vector2) -> Edible:
	var edible : Edible = edible_scene.instantiate()
	edible.playfield = self
	edible.escape_off_screen = edibles_escape_off_screen
	edible.global_position = spawn_position
	edible.eaten.connect(_on_edible_eaten.bind(edible))
	edible.escaped.connect(_on_edible_escaped.bind(edible))
	edible_layer.add_child(edible)
	edible_spawned.emit(edible)
	return edible


func get_edibles() -> Array[Edible]:
	var result : Array[Edible] = []
	for child in edible_layer.get_children():
		if child is Edible and not child.is_queued_for_deletion():
			result.append(child)
	return result


func clear_edibles():
	for edible in get_edibles():
		edible.queue_free()


## The walkable field: full screen width, bottom portion of the screen height.
## An animal's "depth" is the screen Y of its feet within this band.
func get_field_rect() -> Rect2:
	var screen := get_viewport().get_visible_rect()
	var height := screen.size.y * field_height_fraction
	return Rect2(screen.position.x, screen.end.y - height, screen.size.x, height)


## The neutral depth is the predator's depth line, kept inside the field.
## Grabbed animals are brought to this depth.
func get_neutral_depth() -> float:
	var field := get_field_rect()
	return clampf(predator.depth_line_y, field.position.y, field.end.y)


# ----------------------------
# INTERNALS
# ----------------------------

func _on_edible_eaten(edible: Edible):
	predator.on_edible_eaten()
	edible_eaten.emit(edible)


func _on_edible_escaped(edible: Edible):
	edible_escaped.emit(edible)


# Animals live in the same canvas as the seat/predator and set their z_index to
# their feet Y (see edible.gd). Giving the seat and predator a z_index equal to
# the seat's depth line makes farther animals draw behind them, nearer in front.
func apply_depth_sorting():
	var seat_bottom := seat_sprite.global_position.y + seat_sprite.get_rect().end.y * seat_sprite.scale.y
	var depth_z := int(seat_bottom - seat_footprint_offset)
	seat_sprite.z_index = depth_z
	predator.z_index = depth_z
	predator.depth_line_y = depth_z
	cover.z_index = depth_z


func spawn_flowers():
	if flower == null:
		return
	var screen := get_viewport().get_visible_rect()

	for i in flower_count:
		var flower_instance : Node2D = flower.instantiate()

		var band := left_band if randf() < 0.5 else right_band
		var x := screen.position.x + screen.size.x * randf_range(band.x, band.y)
		var y := screen.position.y + screen.size.y * randf_range(vertical_band.x, vertical_band.y)

		flower_layer.add_child(flower_instance)
		flower_instance.global_position = Vector2(x, y)

		# Offset each flower's sway by its horizontal position for a wave effect.
		var anim_player : AnimationPlayer = flower_instance.get_node("SwayAnimationPlayer")
		anim_player.play("sway")
		var animation_length := anim_player.get_animation("sway").length
		var start_time := remap(x, screen.position.x, screen.end.x, 0.0, animation_length / 3.0)
		anim_player.seek(start_time, true)
