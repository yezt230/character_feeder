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


func _ready():
	spawn_flowers()


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
