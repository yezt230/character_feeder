extends Node2D

@onready var belly = $Visuals/Belly
@onready var entire_animation_player = $EntireAnimationPlayer
@onready var body_animation_player = $BodyAnimationPlayer
@onready var belly_animation_player = $BellyAnimationPlayer
@onready var audio_stream_player = $AudioStreamPlayer
@onready var cover = $"../Cover"

## Belly growth uses diminishing returns: each meal closes a fixed fraction
## of the remaining gap to a maximum size, so growth slows as more prey is eaten.
## The most the belly can ever grow beyond its starting scale (1.5 = up to 2.5x).
@export var belly_max_growth : float = 1.5
## Fraction of the remaining growth kept after each meal (0-1).
## Closer to 1 = slower falloff. With 0.933 the first meal adds ~0.1 scale.
@export_range(0.0, 1.0, 0.001) var belly_growth_decay : float = 0.933
@export var belly_tween_duration : float = 0.15

var prey_eaten_count : int = 0
# Screen Y of the predator/seat "depth line" (set by main.gd). Grabbed animals
# are brought to this depth.
var depth_line_y : float
var gulping : bool = false
var belly_base_scale : Vector2
var belly_tween : Tween


func _ready():
	belly_base_scale = belly.scale

func _on_edible_eaten():
	gulping = true
	play_gulp_animation()
	
	
func increase_belly_size():
	prey_eaten_count += 1
	belly_animation_player.play("belly_enlarge")

	# Restart from the true target rather than the mid-tween scale,
	# so rapid feeding never loses or double-counts growth.
	if belly_tween:
		belly_tween.kill()
	belly_tween = create_tween()
	belly_tween.tween_property(belly, "scale", get_belly_target_scale(), belly_tween_duration)

	if prey_eaten_count >= 3:
		if cover:
			cover.queue_free()


# growth(n) = max_growth * (1 - decay^n)
# Each meal adds max_growth * (1 - decay) * decay^(n-1): a geometric series
# whose steps shrink every meal and whose total approaches max_growth.
func get_belly_target_scale() -> Vector2:
	var growth := belly_max_growth * (1.0 - pow(belly_growth_decay, prey_eaten_count))
	return belly_base_scale * (1.0 + growth)


func play_gulp_animation():
	body_animation_player.play("gulp")
	audio_stream_player.play()


func _on_mouth_open_collision_area_entered(area):
	if not gulping:
		body_animation_player.play("mouth_open")


func _on_mouth_open_collision_area_exited(area):
	if not gulping:
		body_animation_player.play("idle")


func finished_gulping():
	gulping = false
