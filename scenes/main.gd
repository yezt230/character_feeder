extends Node2D

@export var flower : PackedScene
@export var flower_count : int = 8

## Flower placement as fractions of the visible screen (0 = left/top, 1 = right/bottom).
## Flowers spawn in one of two horizontal bands, leaving the centre clear for the seat.
@export var left_band := Vector2(0.0, 0.35)
@export var right_band := Vector2(0.69, 0.95)
@export var vertical_band := Vector2(0.69, 0.93)

# Plain Node2D (not a CanvasLayer), placed after the background and before the
# seat/predator in the scene tree, so flowers draw above the background but
# beneath the predator and its growing belly.
@onready var flower_layer : Node2D = $FlowerLayer

## Distance (in screen pixels) from the bottom of the seat sprite up to the middle
## of its base footprint. Animals whose feet are above this line are "behind"
## the seat and predator; below it, they're in front.
@export var seat_footprint_offset : float = 42.0

@onready var seat_sprite : Sprite2D = $SeatSprite
@onready var predator : Node2D = $Predator
@onready var cover : Node2D = $Cover


func _ready():
	apply_depth_sorting()
	spawn_flowers()


# Animals live in the same canvas as the seat/predator and set their z_index to
# their feet Y (see edible.gd). Giving the seat and predator a z_index equal to
# the seat's depth line makes farther animals draw behind them, nearer in front.
func apply_depth_sorting():
	var seat_bottom := seat_sprite.global_position.y + seat_sprite.get_rect().end.y * seat_sprite.scale.y
	var depth_z := int(seat_bottom - seat_footprint_offset)
	seat_sprite.z_index = depth_z
	predator.z_index = depth_z
	cover.z_index = depth_z


func spawn_flowers():
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
