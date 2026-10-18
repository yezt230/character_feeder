extends RefCounted

# GAME BALANCE — the only place to add/edit stage limits, prices and visual files.
# Stage numbers must be consecutive (1, 2, 3...).
# Images for stage 2 and 3 are separate editable files; they are currently
# identical copies of the originals. No automatic blue tint is applied.
const STAGES := {
	1: {
		"unlock_cost": 0,
		"score_limit": 120.0,
		"belly_limit": 1.8,
		"score_decay_per_second": 1.0,
		"belly_decay_per_second": 0.02,
		"rare_chance": 0.0,
		"predator_texture": "res://assets/pred.png",
		"background_texture": "res://assets/Bliss_(Windows_XP).png"
	},
	2: {
		"unlock_cost": 240,
		"score_limit": 360.0,
		"belly_limit": 2.6,
		"score_decay_per_second": 0.6,
		"belly_decay_per_second": 0.012,
		"rare_chance": 0.15,
		"predator_texture": "res://assets/pred_2.png",
		"background_texture": "res://assets/background_2.png"
	},
	3: {
		"unlock_cost": 720,
		"score_limit": 900.0,
		"belly_limit": 3.4,
		"score_decay_per_second": 0.35,
		"belly_decay_per_second": 0.008,
		"rare_chance": 0.25,
		"predator_texture": "res://assets/pred_3.png",
		"background_texture": "res://assets/background_3.png"
	}
}

# Existing species are animated by edible_frame_controller.gd.
# A new *variant* can reuse one of these base species without new animations.
# For a wholly new species you must also add its spritesheet frames/animations.
const PREY_TYPES := {
	"rabbit": {"base_animal": "rabbit", "points": 10, "tint": "#ffffff", "rare": false, "min_stage": 1},
	"beaver": {"base_animal": "beaver", "points": 15, "tint": "#ffffff", "rare": false, "min_stage": 1},
	"raccoon": {"base_animal": "raccoon", "points": 20, "tint": "#ffffff", "rare": false, "min_stage": 1},
	"rare_rabbit": {
		"base_animal": "rabbit", "points": 60, "tint": "#5e54d5",
		"rare": true, "min_stage": 2, "spawn_weight": 1.0
	},
	"rare_beaver": {
		"base_animal": "beaver", "points": 85, "tint": "#ffce67",
		"rare": true, "min_stage": 3, "spawn_weight": 1.0
	}
}

const AUTO_FEED_COST: int = 80
const AUTO_FEED_INTERVAL: float = 8.0
const DECAY_DELAY: float = 10.0
const DIGEST_DURATION: float = 2.0


# Extend PREY_TYPES with a rare entry and it joins the random rare pool.
static func pick_rare_prey(current_stage: int) -> String:
	var total_weight: float = 0.0
	for prey_id in PREY_TYPES.keys():
		var info: Dictionary = PREY_TYPES[prey_id]
		if bool(info.get("rare", false)) and current_stage >= int(info.get("min_stage", 1)):
			total_weight += maxf(0.0, float(info.get("spawn_weight", 1.0)))

	if total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	for prey_id in PREY_TYPES.keys():
		var info: Dictionary = PREY_TYPES[prey_id]
		if not bool(info.get("rare", false)) or current_stage < int(info.get("min_stage", 1)):
			continue
		roll -= maxf(0.0, float(info.get("spawn_weight", 1.0)))
		if roll <= 0.0:
			return str(prey_id)

	return "rare_rabbit"
