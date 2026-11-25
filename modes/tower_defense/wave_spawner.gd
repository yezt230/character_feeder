class_name WaveSpawner
extends Node
## Spawns edibles into a Playfield in escalating waves.
## A wave finishes once all its animals are spawned and none are left alive.

signal wave_started(wave_number: int, edible_count: int)
signal wave_finished(wave_number: int)
signal all_waves_finished

enum Phase { IDLE, SPAWNING, WAITING_FOR_CLEAR, BETWEEN_WAVES, DONE }

@export var playfield: Playfield
@export var edible_scene: PackedScene

@export_group("Waves")
@export var wave_count: int = 5
@export var first_wave_size: int = 3
@export var wave_size_increase: int = 2
## Seconds between spawns in the first wave.
@export var spawn_interval: float = 1.5
## How much faster spawning gets each wave.
@export var spawn_interval_decrease: float = 0.15
@export var min_spawn_interval: float = 0.4
@export var time_before_first_wave: float = 1.5
@export var time_between_waves: float = 3.0

@export_group("Spawn Area")
## Horizontal spawn range, as fractions of the screen width.
@export var spawn_x_range := Vector2(0.15, 0.85)
## Spawn height, as a fraction of the screen height from the top.
@export_range(0.0, 1.0, 0.01) var spawn_y_fraction: float = 0.1

var phase: Phase = Phase.IDLE
var current_wave: int = 0
var alive_count: int = 0

var _left_to_spawn: int = 0
var _timer: float = 0.0


func start():
	current_wave = 0
	alive_count = 0
	phase = Phase.BETWEEN_WAVES
	_timer = time_before_first_wave


func stop():
	phase = Phase.IDLE


func _process(delta):
	match phase:
		Phase.SPAWNING:
			_timer -= delta
			if _timer <= 0.0:
				_spawn_one()
				_left_to_spawn -= 1
				if _left_to_spawn <= 0:
					phase = Phase.WAITING_FOR_CLEAR
				else:
					_timer = _get_wave_interval()

		Phase.WAITING_FOR_CLEAR:
			if alive_count <= 0:
				wave_finished.emit(current_wave)
				if current_wave >= wave_count:
					phase = Phase.DONE
					all_waves_finished.emit()
				else:
					phase = Phase.BETWEEN_WAVES
					_timer = time_between_waves

		Phase.BETWEEN_WAVES:
			_timer -= delta
			if _timer <= 0.0:
				_begin_next_wave()


func _begin_next_wave():
	current_wave += 1
	_left_to_spawn = first_wave_size + (current_wave - 1) * wave_size_increase
	_timer = 0.0
	phase = Phase.SPAWNING
	wave_started.emit(current_wave, _left_to_spawn)


func _get_wave_interval() -> float:
	return maxf(min_spawn_interval, spawn_interval - (current_wave - 1) * spawn_interval_decrease)


func _spawn_one():
	var screen := get_viewport().get_visible_rect()
	var spawn_position := Vector2(
		screen.position.x + screen.size.x * randf_range(spawn_x_range.x, spawn_x_range.y),
		screen.position.y + screen.size.y * spawn_y_fraction
	)
	var edible := playfield.spawn_edible(edible_scene, spawn_position)
	alive_count += 1
	# Covers eaten, escaped, and any other removal.
	edible.tree_exiting.connect(func(): alive_count -= 1)
