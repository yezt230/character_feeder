extends Control
## Main menu: the game's entry point. Picks a game mode to start.

@export var free_play_scene: PackedScene
@export var tower_defense_scene: PackedScene
## If set, skips the menu and starts this mode immediately
## (handy for testing, or for a build that should launch straight into a mode).
@export var auto_start_scene: PackedScene

@onready var free_play_button: Button = %FreePlayButton
@onready var tower_defense_button: Button = %TowerDefenseButton


func _ready():
	if auto_start_scene:
		SceneManager.start_mode.call_deferred(auto_start_scene)
		return

	free_play_button.pressed.connect(SceneManager.start_mode.bind(free_play_scene))
	tower_defense_button.pressed.connect(SceneManager.start_mode.bind(tower_defense_scene))
	free_play_button.grab_focus()
