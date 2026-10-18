extends Node2D

const Balance = preload("res://scenes/game_balance.gd")

@onready var predator = $Predator
@onready var background: Sprite2D = $BGSprite
@onready var edible_layer: CanvasLayer = $EdibleLayer
@onready var spawner = $CanvasLayer/MarginContainer/HBoxContainer/EdibleSpawner
@onready var digest_button: Button = $CanvasLayer/MarginContainer/HBoxContainer/ResetButton
@onready var score_label: Label = $CanvasLayer/MarginContainer/HBoxContainer/Shop/ScoreLabel
@onready var bank_label: Label = $CanvasLayer/MarginContainer/HBoxContainer/Shop/BankLabel
@onready var status_label: Label = $CanvasLayer/MarginContainer/HBoxContainer/Shop/StatusLabel
@onready var auto_button: Button = $CanvasLayer/MarginContainer/HBoxContainer/Shop/AutoUpgradeButton
@onready var stage_button: Button = $CanvasLayer/MarginContainer/HBoxContainer/Shop/StageUpgradeButton
@onready var auto_timer: Timer = $AutoFeedTimer

var run_score: float = 0.0
var bank_score: int = 0
var stage: int = 1
var auto_unlocked: bool = false
var idle_time: float = 0.0
var is_digesting: bool = false


func _ready() -> void:
	auto_button.pressed.connect(buy_auto_upgrade)
	stage_button.pressed.connect(buy_stage_upgrade)
	auto_timer.timeout.connect(_on_auto_timer_timeout)
	auto_timer.wait_time = Balance.AUTO_FEED_INTERVAL
	load_progress()
	apply_stage_visuals()
	if auto_unlocked:
		auto_timer.start()
	update_ui()


func current_stage_data() -> Dictionary:
	return Balance.STAGES.get(stage, Balance.STAGES[1])


func _process(delta: float) -> void:
	if is_digesting:
		return
	if run_score <= 0.0 and predator.belly.scale.x <= 1.0:
		return
	idle_time += delta
	if idle_time < Balance.DECAY_DELAY:
		return

	var info: Dictionary = current_stage_data()
	run_score = maxf(0.0, run_score - float(info["score_decay_per_second"]) * delta)
	predator.shrink_belly(float(info["belly_decay_per_second"]) * delta)
	update_ui()


func get_score_limit() -> float:
	return float(current_stage_data()["score_limit"])


func get_belly_limit() -> float:
	return float(current_stage_data()["belly_limit"])


# Called from the predator's existing gulp animation at 0.4 s.
func register_eaten(points: int) -> void:
	if is_digesting:
		return
	run_score = minf(get_score_limit(), run_score + float(points))
	idle_time = 0.0
	update_ui()


# DIGEST keeps the original mouth-opening frame and returns the belly to 1x.
func start_digest() -> void:
	if is_digesting or run_score < 1.0 or predator.has_pending_gulps():
		return

	is_digesting = true
	predator.start_digest_animation() # Starts the 2-second silent sound too.
	update_ui()

	var tween: Tween = create_tween()
	tween.tween_property(predator.belly, "scale", Vector2.ONE, Balance.DIGEST_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	bank_score += int(floorf(run_score))
	run_score = 0.0
	idle_time = 0.0
	predator.finish_digest_animation()
	is_digesting = false
	save_progress()
	update_ui()


func buy_auto_upgrade() -> void:
	if is_digesting or auto_unlocked or bank_score < Balance.AUTO_FEED_COST:
		return
	bank_score -= Balance.AUTO_FEED_COST
	auto_unlocked = true
	auto_timer.start()
	save_progress()
	update_ui()


func buy_stage_upgrade() -> void:
	var next_stage: int = stage + 1
	if is_digesting or not Balance.STAGES.has(next_stage):
		return
	var price: int = int(Balance.STAGES[next_stage]["unlock_cost"])
	if bank_score < price:
		return
	bank_score -= price
	stage = next_stage
	apply_stage_visuals()
	save_progress()
	update_ui()


func apply_stage_visuals() -> void:
	var info: Dictionary = current_stage_data()
	var predator_path: String = str(info["predator_texture"])
	var background_path: String = str(info["background_texture"])
	if ResourceLoader.exists(predator_path):
		predator.set_stage_texture(load(predator_path) as Texture2D)
	else:
		push_warning("Missing predator image: " + predator_path)
	if ResourceLoader.exists(background_path):
		background.texture = load(background_path) as Texture2D
	else:
		push_warning("Missing background image: " + background_path)
	# No color-modulate fallbacks: each stage uses its own files.
	predator.get_node("Visuals").modulate = Color.WHITE
	background.modulate = Color.WHITE


func _on_auto_timer_timeout() -> void:
	if is_digesting:
		return
	var candidates: Array[Node] = []
	for prey in edible_layer.get_children():
		if prey.has_method("can_auto_jump") and prey.can_auto_jump():
			candidates.append(prey)

	if candidates.is_empty():
		spawner.spawn_edible()
		for prey in edible_layer.get_children():
			if prey.has_method("can_auto_jump") and prey.can_auto_jump():
				candidates.append(prey)

	if candidates.is_empty():
		return
	var chosen_prey = candidates.pick_random()
	var mouth_position: Vector2 = predator.get_node("EatenHitbox/CollisionShape2D").global_position
	chosen_prey.auto_jump_into_mouth(mouth_position)


func update_ui() -> void:
	score_label.text = "Belly points: %d / %d" % [int(floorf(run_score)), int(get_score_limit())]
	bank_label.text = "Banked points: %d" % bank_score
	status_label.text = "Stage: %d/%d | Auto feed: %s" % [stage, Balance.STAGES.size(), "ON" if auto_unlocked else "OFF"]

	digest_button.disabled = is_digesting or run_score < 1.0 or predator.has_pending_gulps()
	digest_button.text = "Digesting..." if is_digesting else "Digest"
	auto_button.disabled = is_digesting or auto_unlocked or bank_score < Balance.AUTO_FEED_COST
	auto_button.text = "Auto Feed: OWNED" if auto_unlocked else "Auto Feed — %d" % Balance.AUTO_FEED_COST

	var next_stage: int = stage + 1
	if not Balance.STAGES.has(next_stage):
		stage_button.text = "All stages unlocked"
		stage_button.disabled = true
	else:
		var price: int = int(Balance.STAGES[next_stage]["unlock_cost"])
		stage_button.text = "Unlock Stage %s — %d" % [to_roman(next_stage), price]
		stage_button.disabled = is_digesting or bank_score < price


func to_roman(number: int) -> String:
	var numeral: String = ""
	var remaining: int = number
	var values: Array[int] = [100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols: Array[String] = ["C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	for i in range(values.size()):
		while remaining >= values[i]:
			numeral += symbols[i]
			remaining -= values[i]
	return numeral


func save_progress() -> void:
	var data := {
		"bank_score": bank_score,
		"stage": stage,
		"auto_unlocked": auto_unlocked
	}
	var file := FileAccess.open("user://character_feeder_save.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func load_progress() -> void:
	if not FileAccess.file_exists("user://character_feeder_save.json"):
		return
	var file := FileAccess.open("user://character_feeder_save.json", FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		bank_score = maxi(0, int(data.get("bank_score", 0)))
		stage = clampi(int(data.get("stage", 1)), 1, Balance.STAGES.size())
		auto_unlocked = bool(data.get("auto_unlocked", false))
