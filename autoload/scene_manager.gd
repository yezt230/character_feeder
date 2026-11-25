extends Node
## Global (autoload) scene switching between the main menu and game modes.


func go_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


func start_mode(mode_scene: PackedScene):
	get_tree().paused = false
	get_tree().change_scene_to_packed(mode_scene)


func restart_mode():
	get_tree().paused = false
	get_tree().reload_current_scene()
