extends Button
## HUD button that drops an edible into the Playfield when pressed.

@export var edible_scene : PackedScene
## The Playfield to spawn into. Falls back to the first node in the
## "playfield" group if left empty.
@export var playfield : Playfield
@onready var button_sprite = $ButtonSprite
@onready var audio_stream_player = $AudioStreamPlayer
@onready var spawn_marker_2d = $SpawnMarker2D

var button_scale_x_const : float
var button_scale_y_const : float

func _ready():
	button_scale_x_const = button_sprite.scale.x
	button_scale_y_const = button_sprite.scale.y
	if playfield == null:
		playfield = get_tree().get_first_node_in_group("playfield")


func spawn_edible():
	audio_stream_player.play_randomized_pitch()
	playfield.spawn_edible(edible_scene, get_spawn_position())


func _on_pressed():
	spawn_edible()


func get_spawn_position():
	var base_x = spawn_marker_2d.global_position.x
	var difference : float= 75.0
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randf_range(base_x - difference, base_x + difference)
	
	return Vector2(random_x, spawn_marker_2d.global_position.y)


func _on_mouse_entered():
	var tween = get_tree().create_tween()
	var shrink_amt : float = 0.9
	var target_scale_x = button_scale_x_const * shrink_amt
	var target_scale_y = button_scale_y_const * shrink_amt
	var target_scale : Vector2 = Vector2(target_scale_x, target_scale_y)
	tween.tween_property(button_sprite, "scale", target_scale, 0.15)


func _on_mouse_exited():
	var tween = get_tree().create_tween()
	var target_scale : Vector2 = Vector2(button_scale_x_const, button_scale_y_const)
	tween.tween_property(button_sprite, "scale", target_scale, 0.15)
