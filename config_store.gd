extends Node

# Bundled program config — seed source on Android, primary source on desktop
const PROGRAM_PATH_RES: String = "res://program_config.json"

# All paths set at runtime based on platform
var PROGRAM_PATH: String = ""
var PROGRESS_PATH: String = ""
var HISTORY_PATH: String = ""

var _program: Dictionary = {}
var _progress: Dictionary = {}
var _history: Dictionary = {}


func _ready() -> void:
	_init_data_paths()
	_seed_program_config()
	_load_program()
	_load_or_create_progress()
	_load_or_create_history()


func _init_data_paths() -> void:
	if OS.get_name() == "Android":
		var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		var data_dir := (docs if not docs.is_empty() else "/sdcard/Documents") + "/WorkoutTracker"
		var err := DirAccess.make_dir_recursive_absolute(data_dir)
		if err == OK or DirAccess.dir_exists_absolute(data_dir):
			PROGRAM_PATH = data_dir + "/program_config.json"
			PROGRESS_PATH = data_dir + "/progress.json"
			HISTORY_PATH = data_dir + "/workout_history.json"
			return
		push_error("Cannot create external storage dir, falling back to user://")
	PROGRAM_PATH = PROGRAM_PATH_RES
	PROGRESS_PATH = "user://progress.json"
	HISTORY_PATH = "user://workout_history.json"


func _seed_program_config() -> void:
	# On Android: copy bundled program_config.json to external storage on first launch
	if PROGRAM_PATH == PROGRAM_PATH_RES:
		return
	if FileAccess.file_exists(PROGRAM_PATH):
		return
	var data = _load_json(PROGRAM_PATH_RES)
	if data != null:
		_save_json(PROGRAM_PATH, data)
	else:
		push_error("Failed to seed program_config.json from res://")


func ensure_loaded() -> void:
	if PROGRESS_PATH.is_empty():
		_init_data_paths()
		_seed_program_config()
	if _program.is_empty():
		_load_program()
	if _progress.is_empty():
		_load_or_create_progress()
	if _history.is_empty():
		_load_or_create_history()

# --------------------------------------------------------------------
# Public API for workout_menu.gd
# --------------------------------------------------------------------

func get_current_workout_index() -> int:
	ensure_loaded()
	var workouts: Array = _program.get("workouts", [])
	if workouts.is_empty():
		return 0
	var idx: int = int(_progress.get("current_workout_index", 0))
	return clamp(idx, 0, workouts.size() - 1)


func get_current_workout_name() -> String:
	ensure_loaded()
	var workouts: Array = _program.get("workouts", [])
	if workouts.is_empty():
		return "No workouts configured"

	var workout: Dictionary = workouts[get_current_workout_index()]
	return String(workout.get("name", "Workout"))

# --------------------------------------------------------------------
# Public API for main.gd
# --------------------------------------------------------------------

func get_current_workout() -> Dictionary:
	ensure_loaded()
	var workouts: Array = _program.get("workouts", [])
	if workouts.is_empty():
		return {}
	return workouts[get_current_workout_index()]


func get_current_workout_exercise_ids() -> Array:
	var workout := get_current_workout()
	return workout.get("exercises", [])


func get_exercise_name(exercise_id: String) -> String:
	ensure_loaded()
	var exercises: Dictionary = _program.get("exercises", {})
	if not exercises.has(exercise_id):
		return exercise_id
	var ex: Dictionary = exercises[exercise_id]
	return String(ex.get("name", exercise_id))


func get_max_reps(exercise_id: String, default_max:int = 12) -> int:
	ensure_loaded()
	var ex_map: Dictionary = _program.get("exercises", {})
	if not ex_map.has(exercise_id):
		return default_max
	var ex: Dictionary = ex_map[exercise_id]
	if not ex.has("max_reps"):
		return default_max
	return int(ex["max_reps"])


func get_min_reps(exercise_id: String, default_min:int = 8) -> int:
	ensure_loaded()
	var ex_map: Dictionary = _program.get("exercises", {})
	if not ex_map.has(exercise_id):
		return default_min
	var ex: Dictionary = ex_map[exercise_id]
	if not ex.has("min_reps"):
		return default_min
	return int(ex["min_reps"])


func has_drop_set(exercise_id: String) -> bool:
	ensure_loaded()
	var ex_map: Dictionary = _program.get("exercises", {})
	if not ex_map.has(exercise_id):
		return true
	var ex: Dictionary = ex_map[exercise_id]
	print("has_drop_set")
	print(ex)
	if not ex.has("drop_set"):
		return true
	return bool(ex["drop_set"])


func get_last_weight(exercise_id: String, default_weight: float = 0.0) -> float:
	ensure_loaded()
	var ex_map: Dictionary = _progress.get("exercises", {})
	if not ex_map.has(exercise_id):
		return default_weight
	var ex: Dictionary = ex_map[exercise_id]
	if not ex.has("last_weight"):
		return default_weight
	return float(ex["last_weight"])


func get_last_reps(exercise_id: String, default_reps: int = 0) -> int:
	ensure_loaded()
	var ex_map: Dictionary = _progress.get("exercises", {})
	if not ex_map.has(exercise_id):
		return default_reps
	var ex: Dictionary = ex_map[exercise_id]
	if not ex.has("last_reps"):
		return default_reps
	return int(ex["last_reps"])


func set_last_set(exercise_id: String, weight: float, reps: int) -> void:
	ensure_loaded()
	if not _progress.has("exercises") or typeof(_progress["exercises"]) != TYPE_DICTIONARY:
		_progress["exercises"] = {}

	var ex_map: Dictionary = _progress["exercises"]
	var ex: Dictionary = {}
	if ex_map.has(exercise_id) and typeof(ex_map[exercise_id]) == TYPE_DICTIONARY:
		ex = ex_map[exercise_id]

	ex["last_weight"] = float(weight)
	ex["last_reps"] = int(reps)
	ex_map[exercise_id] = ex
	_progress["exercises"] = ex_map


func advance_to_next_workout() -> void:
	ensure_loaded()
	var workouts: Array = _program.get("workouts", [])
	if workouts.is_empty():
		_progress["current_workout_index"] = 0
		return

	var idx: int = get_current_workout_index()
	_progress["current_workout_index"] = (idx + 1) % workouts.size()


func save_progress() -> void:
	ensure_loaded()
	_save_json(PROGRESS_PATH, _progress)


func log_completed_workout(exercise_data: Array[Dictionary]) -> void:
	ensure_loaded()

	var workout := get_current_workout()
	var workout_id: String = String(workout.get("id", ""))
	var workout_name: String = String(workout.get("name", ""))

	var timestamp := Time.get_datetime_string_from_system()

	var workout_entry := {
		"timestamp": timestamp,
		"workout_id": workout_id,
		"workout_name": workout_name,
		"exercises": exercise_data
	}

	var workouts: Array = _history.get("workouts", [])
	workouts.append(workout_entry)
	_history["workouts"] = workouts

	_save_json(HISTORY_PATH, _history)

# --------------------------------------------------------------------
# Loading
# --------------------------------------------------------------------

func _load_program() -> void:
	var data = _load_json(PROGRAM_PATH)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("Program config missing/invalid at %s" % PROGRAM_PATH)
		_program = {}
		return
	_program = data


func _load_or_create_progress() -> void:
	if FileAccess.file_exists(PROGRESS_PATH):
		var data = _load_json(PROGRESS_PATH)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			_progress = data
			_sanitize_progress()
			return
		push_error("Progress file exists but is invalid; recreating: %s" % PROGRESS_PATH)

	_progress = {
		"schema_version": 1,
		"current_workout_index": 0,
		"exercises": {}
	}
	_sanitize_progress()
	_save_json(PROGRESS_PATH, _progress)


func _load_or_create_history() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var data = _load_json(HISTORY_PATH)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			_history = data
			_sanitize_history()
			return
		push_error("History file exists but is invalid; recreating: %s" % HISTORY_PATH)

	_history = {
		"schema_version": 1,
		"workouts": []
	}
	_sanitize_history()
	_save_json(HISTORY_PATH, _history)


func _sanitize_history() -> void:
	if typeof(_history) != TYPE_DICTIONARY:
		_history = {}
	if not _history.has("schema_version"):
		_history["schema_version"] = 1
	if not _history.has("workouts") or typeof(_history["workouts"]) != TYPE_ARRAY:
		_history["workouts"] = []


func _sanitize_progress() -> void:
	if typeof(_progress) != TYPE_DICTIONARY:
		_progress = {}
	if not _progress.has("schema_version"):
		_progress["schema_version"] = 1
	if not _progress.has("current_workout_index"):
		_progress["current_workout_index"] = 0
	if not _progress.has("exercises") or typeof(_progress["exercises"]) != TYPE_DICTIONARY:
		_progress["exercises"] = {}

	var workouts: Array = _program.get("workouts", [])
	if workouts.is_empty():
		_progress["current_workout_index"] = 0
	else:
		var idx: int = int(_progress.get("current_workout_index", 0))
		_progress["current_workout_index"] = clamp(idx, 0, workouts.size() - 1)

# --------------------------------------------------------------------
# JSON helpers
# --------------------------------------------------------------------

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	var data: Variant = JSON.parse_string(text)
	return data


func _save_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
