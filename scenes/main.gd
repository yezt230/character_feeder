extends Node2D

@export var flower : PackedScene

func _ready():
	spawn_flowers()
	
	
func spawn_flowers():
	var flower_amt : int = 8
	for indv_flower in flower_amt:
		var flower_instance : Node2D = flower.instantiate()
		var flower_pos_x = randf_range(0, 400) if randf() < 0.5 else randf_range(800, 1100)
		var flower_pos_y = randf_range(450, 600)
		flower_instance.global_position = Vector2(flower_pos_x, flower_pos_y)
		
		var anim_player: AnimationPlayer = flower_instance.get_node("SwayAnimationPlayer")
		anim_player.play("sway")
		var animation_length = anim_player.get_animation("sway").length
		var start_time = remap(
			flower_pos_x,
			0.0, 1100.0,
			0.0, animation_length / 3.0
		)
		anim_player.seek(start_time, true)
		
		var flower_layer = get_tree().current_scene.get_node("FlowerLayer")
		flower_layer.add_child(flower_instance)
		
