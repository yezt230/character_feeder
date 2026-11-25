
extends Node

@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

var animals = {
	"rabbit": {
		"resting": 0,
		"falling": 12,
		"running": "rabbit_run"
	},
	"raccoon": {
		"resting": 1,
		"falling": 13,
		"running": "raccoon_run"
	},
	"beaver": {
		"resting": 2,
		"falling": 14,
		"running": "beaver_run"
	}
}

var current_animal: String


func _ready():
	choose_animal()


func choose_frame(frame: int):
	sprite.frame = frame


func choose_animal():
	current_animal = animals.keys().pick_random()
	choose_frame(animals[current_animal]["falling"])


# ----------------------------
# VISUAL STATES
# ----------------------------

func animal_on_ground():
	animation_player.stop()
	choose_frame(animals[current_animal]["resting"])


func animal_in_air():
	animation_player.stop()
	choose_frame(animals[current_animal]["falling"])


func animal_running():
	var animation_name = animals[current_animal]["running"]
	animation_player.play(animation_name)


func animal_dragging():
	animation_player.stop()
	choose_frame(animals[current_animal]["falling"])
	
	
func set_facing_direction(direction: int):
	sprite.flip_h = direction < 0
