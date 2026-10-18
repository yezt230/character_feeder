extends Button

func _pressed() -> void:
    get_tree().current_scene.start_digest()
