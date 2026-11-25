extends GameMode
## Tower Defense: animals arrive in waves and try to run off the edges of the
## screen. Drag them to the predator before they escape. Each escape costs a
## life; survive every wave to win.

@export var starting_lives: int = 5

@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var wave_label: Label = %WaveLabel
@onready var lives_label: Label = %LivesLabel
@onready var score_label: Label = %ScoreLabel
@onready var wave_banner: Label = %WaveBanner
@onready var end_panel: Control = %EndPanel
@onready var end_label: Label = %EndLabel

var lives: int
var score: int = 0
var game_over: bool = false
var banner_tween: Tween


func _start_mode():
	lives = starting_lives
	score = 0
	end_panel.visible = false
	wave_banner.modulate.a = 0.0

	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.all_waves_finished.connect(_on_all_waves_finished)
	wave_spawner.start()
	update_hud()


func _on_edible_eaten(_edible: Edible):
	if game_over:
		return
	score += 1
	update_hud()


func _on_edible_escaped(_edible: Edible):
	if game_over:
		return
	lives -= 1
	update_hud()
	if lives <= 0:
		end_game(false)


func _on_wave_started(wave_number: int, _edible_count: int):
	update_hud()
	show_banner("Wave %d" % wave_number)


func _on_all_waves_finished():
	end_game(true)


func end_game(won: bool):
	if game_over:
		return
	game_over = true
	wave_spawner.stop()
	if not won:
		playfield.clear_edibles()
	end_label.text = "You win!" if won else "Game over"
	end_panel.visible = true


func update_hud():
	wave_label.text = "Wave %d / %d" % [wave_spawner.current_wave, wave_spawner.wave_count]
	lives_label.text = "Lives: %d" % lives
	score_label.text = "Eaten: %d" % score


func show_banner(text: String):
	wave_banner.text = text
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.25)
	banner_tween.tween_interval(1.2)
	banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
