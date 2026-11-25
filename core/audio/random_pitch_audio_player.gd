extends AudioStreamPlayer

@export var min_pitch = 0.9
@export var max_pitch = 1.05

func play_randomized_pitch():
	pitch_scale = randf_range(min_pitch, max_pitch)
	play()
