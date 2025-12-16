extends Node

const CONFIG_SRC: String = "res://program_config.json"
const CONFIG_DST: String = "user://program_config.json"

var _program_config: Dictionary = {}

func ensure_loaded() -> void:
	# Call this from scenes to be safe; autoload _ready should already do it.
	if _program_config.is_empty():
		_ensure_user_config_exists()
		_load_program_config()


func get_program_config() -> Dictionary:
	return _program_config


func get_workouts() -> Array:
	return _program_config.get("workouts", [])


func get_program_meta() -> Dictionary:
	return _program_config.get("meta", {})


func get_current_workout_index() -> int:
	var workouts := get_workouts()
	if workouts.is_empty():
		return 0
	
	var meta := get_program_meta()
	var idx: int = int(meta.get("current_workout_index", 0))
	return clamp(idx, 0, workouts.size() - 1)


func get_current_workout() -> Dictionary:
	var workouts := get_workouts()
	if workouts.is_empty():
		return {}
	return workouts[get_current_workout_index()]


func commit_current_workout_results(exercise_updates: Dictionary) -> void:
	# exercise_updates: { "exercise_id": { "weight": float, "reps": int }, ... }
	if _program_config.is_empty():
		return
	
	var workouts: Array = _program_config.get("workouts", [])
	if workouts.is_empty():
		push_error("No workouts in config")
		return
	
	var meta: Dictionary = _program_config.get("meta", {})
	var current_index: int = int(meta.get("current_workout_index", 0))
	if current_index < 0 or current_index >= workouts.size():
		current_index = 0
	
	var exercise_map: Dictionary = _program_config.get("exercises", {})
	
	for ex_id in exercise_updates.keys():
		if not exercise_map.has(ex_id):
			continue
		var update: Dictionary = exercise_updates[ex_id]
		var ex_data: Dictionary = exercise_map[ex_id]
		ex_data["last_weight"] = float(update.get("weight", ex_data.get("last_weight", 0.0)))
		ex_data["last_reps"] = int(update.get("reps", ex_data.get("last_reps", 0)))
		exercise_map[ex_id] = ex_data
	
	_program_config["exercises"] = exercise_map
	
	# Advance to next workout (wrap around the list)
	var next_index: int = (current_index + 1) % workouts.size()
	meta["current_workout_index"] = next_index
	_program_config["meta"] = meta
	
	_save_program_config_to_disk()


func _ready() -> void:
	_ensure_user_config_exists()
	_load_program_config()


func _ensure_user_config_exists() -> void:
	if FileAccess.file_exists(CONFIG_DST):
		return
	
	var src: FileAccess = FileAccess.open(CONFIG_SRC, FileAccess.READ)
	if src == null:
		push_error("Could not open default config at %s" % CONFIG_SRC)
		return
	
	var dst: FileAccess = FileAccess.open(CONFIG_DST, FileAccess.WRITE)
	if dst == null:
		push_error("Could not open user config at %s" % CONFIG_DST)
		return
	
	dst.store_string(src.get_as_text())


func _load_program_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_DST, FileAccess.READ)
	if file == null:
		push_error("Could not open %s (error %d)" % [CONFIG_DST, FileAccess.get_open_error()])
		return
	
	var text: String = file.get_as_text()
	var data = JSON.parse_string(text)
	if data == null:
		push_error("Invalid JSON: failed to parse in %s" % CONFIG_DST)
		return
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON format in %s" % CONFIG_DST)
		return
	
	_program_config = data


func _save_program_config_to_disk() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_DST, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save config to %s" % CONFIG_DST)
		return
	
	var json_text: String = JSON.stringify(_program_config, "\t")
	file.store_string(json_text)
