class_name GameMode
extends Node2D
## Base class for every game mode.
##
## A mode scene instances the shared Playfield (res://core/playfield/) as a
## child and layers its own rules, spawning and HUD on top. Shared mechanics
## (dragging, eating, depth, predator) stay in the Playfield and its entities,
## so changes to them apply to every mode automatically.
##
## Subclasses override the hooks below instead of _ready().

## The Playfield this mode drives. Defaults to a child named "Playfield".
@export var playfield: Playfield


func _ready():
	if playfield == null:
		playfield = get_node_or_null("Playfield")
	assert(playfield != null, "%s needs a Playfield child." % name)

	playfield.edible_spawned.connect(_on_edible_spawned)
	playfield.edible_eaten.connect(_on_edible_eaten)
	playfield.edible_escaped.connect(_on_edible_escaped)

	_start_mode()


# ----------------------------
# HOOKS (override in subclasses)
# ----------------------------

## Called once the mode and its Playfield are ready.
func _start_mode():
	pass


func _on_edible_spawned(_edible: Edible):
	pass


func _on_edible_eaten(_edible: Edible):
	pass


func _on_edible_escaped(_edible: Edible):
	pass


# ----------------------------
# COMMON ACTIONS
# ----------------------------

func restart():
	SceneManager.restart_mode()


func back_to_menu():
	SceneManager.go_to_menu()
