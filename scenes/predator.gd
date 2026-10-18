extends Node2D

@onready var belly = $Visuals/Belly
@onready var entire_animation_player = $EntireAnimationPlayer
@onready var body_animation_player = $BodyAnimationPlayer
@onready var belly_animation_player = $BellyAnimationPlayer
@onready var audio_stream_player = $AudioStreamPlayer
@onready var digest_audio_player: AudioStreamPlayer = $DigestAudioPlayer
#@onready var cover = $"../Cover"

@onready var body_sprite: Sprite2D = $Visuals/Sprite2D
@onready var belly_sprite: Sprite2D = $Visuals/Belly/BellySprite/Sprite2D

var prey_eaten_count: int = 0
var gulping: bool = false
var digesting: bool = false
var gulp_queue: Array[int] = []
var current_gulp_points: int = 0


# Сигнал edible.eaten сообщает стоимость конкретной жертвы.
func _on_edible_eaten(points: int) -> void:
	if digesting:
		return
	gulp_queue.append(points)
	if not gulping:
		start_next_gulp()


func start_next_gulp() -> void:
	if digesting or gulping or gulp_queue.is_empty():
		return
	current_gulp_points = gulp_queue.pop_front()
	gulping = true
	play_gulp_animation()
	get_parent().update_ui()


# Этот метод УЖЕ вызывается из анимации gulp на 0,4 секунды.
func increase_belly_size() -> void:
	prey_eaten_count += 1
	get_parent().register_eaten(current_gulp_points)
	belly_animation_player.play("belly_enlarge")

	var max_size: float = get_parent().get_belly_limit()
	var new_size: float = minf(max_size, belly.scale.x + 0.1)
	var tween: Tween = create_tween()
	tween.tween_property(belly, "scale", Vector2(new_size, new_size), 0.15)

	#if prey_eaten_count >= 3 and is_instance_valid(cover):
		#cover.visible = false


func shrink_belly(amount: float) -> void:
	var new_size: float = maxf(1.0, belly.scale.x - amount)
	belly.scale = Vector2(new_size, new_size)


func play_gulp_animation() -> void:
	body_animation_player.play("gulp")
	audio_stream_player.play()


func _on_mouth_open_collision_area_entered(_area) -> void:
	if not gulping and not digesting:
		body_animation_player.play("mouth_open")


func _on_mouth_open_collision_area_exited(_area) -> void:
	if not gulping and not digesting:
		body_animation_player.play("idle")


# Этот метод УЖЕ вызывается из анимации gulp на 0,9 секунды.
func finished_gulping() -> void:
	gulping = false
	if not gulp_queue.is_empty():
		call_deferred("start_next_gulp")
	else:
		body_animation_player.play("idle")
		get_parent().update_ui()


func has_pending_gulps() -> bool:
	return gulping or not gulp_queue.is_empty()


func can_eat() -> bool:
	return not digesting


func start_digest_animation() -> void:
	digesting = true
	body_animation_player.play("mouth_open")
	digest_audio_player.play()


func finish_digest_animation() -> void:
	prey_eaten_count = 0
	digest_audio_player.stop()
	digesting = false
	body_animation_player.play("idle")
	#if is_instance_valid(cover):
		#cover.visible = true


func set_stage_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	# Оба фрагмента тела должны использовать один и тот же spritesheet.
	body_sprite.texture = texture
	belly_sprite.texture = texture
