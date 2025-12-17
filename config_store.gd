extends Node

# Program file (definition) lives in the repo and ships with the app.
const PROGRAM_PATH: String = "res://program_config.json"

# Progress file (state) lives in user storage and is never overwritten.
const PROGRESS_PATH: String = "user://progress.json"

# Legacy combined file (old approach)
const LEGACY_COMBINED_PATH: String = "user://program_config.json"
const LEGACY_BACKUP_PATH: String = "user://program_config.json.bak"

var _program: Dictionary = {}
var _progress: Dictionary = {}


func _ready() -> void:
	_load_program()
	_load_or_create_progress()


func ensure_loaded() -> void:
	# Safe to call from any scene.
	if _program.is_empty():
		_load_program()
	if _progress.is_empty():
		_load_or_create_progress()

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

# --------------------------------------------------------------------
# Loading / migration
# --------------------------------------------------------------------

func _load_program() -> void:
	var data = _load_json(PROGRAM_PATH)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("Program config missing/invalid at %s" % PROGRAM_PATH)
		_program = {}
		return
	_program = data


func _load_or_create_progress() -> void:
	# Preferred: new progress file exists
	if FileAccess.file_exists(PROGRESS_PATH):
		var data = _load_json(PROGRESS_PATH)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			_progress = data
			_sanitize_progress()
			return
		push_error("Progress file exists but is invalid; recreating: %s" % PROGRESS_PATH)
	
	# No progress file yet: attempt migration from legacy combined file
	if FileAccess.file_exists(LEGACY_COMBINED_PATH):
		var migrated := _migrate_from_legacy_combined()
		if migrated:
			_sanitize_progress()
			_save_json(PROGRESS_PATH, _progress)
			_archive_legacy_file()
			return
		push_error("Legacy config exists but migration failed; starting fresh progress.")
	
	# Fresh progress
	_progress = {
		"schema_version": 1,
		"current_workout_index": 0,
		"exercises": {}
	}
	_sanitize_progress()
	_save_json(PROGRESS_PATH, _progress)


func _migrate_from_legacy_combined() -> bool:
	var legacy = _load_json(LEGACY_COMBINED_PATH)
	if legacy == null or typeof(legacy) != TYPE_DICTIONARY:
		return false
	
	# old structure: { "meta": { "current_workout_index": ... }, "exercises": { id: { last_weight, last_reps, ... } }, ... }
	var meta: Dictionary = legacy.get("meta", {})
	var idx: int = int(meta.get("current_workout_index", 0))
	
	var out_exercises: Dictionary = {}
	var legacy_ex: Dictionary = legacy.get("exercises", {})
	if typeof(legacy_ex) == TYPE_DICTIONARY:
		for ex_id in legacy_ex.keys():
			if typeof(ex_id) != TYPE_STRING and typeof(ex_id) != TYPE_STRING_NAME:
				continue
			var ex_data = legacy_ex[ex_id]
			if typeof(ex_data) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = {}
			if ex_data.has("last_weight"):
				entry["last_weight"] = float(ex_data["last_weight"])
			if ex_data.has("last_reps"):
				entry["last_reps"] = int(ex_data["last_reps"])

			# Only keep entries that actually have progress
			if not entry.is_empty():
				out_exercises[String(ex_id)] = entry
	
	_progress = {
		"schema_version": 1,
		"current_workout_index": idx,
		"exercises": out_exercises
	}
	return true

func _archive_legacy_file() -> void:
	# Rename legacy combined file to .bak, overwriting any existing .bak
	if not FileAccess.file_exists(LEGACY_COMBINED_PATH):
		return
	
	# Remove existing backup to allow rename.
	if FileAccess.file_exists(LEGACY_BACKUP_PATH):
		DirAccess.remove_absolute(LEGACY_BACKUP_PATH)
	
	var err := DirAccess.rename_absolute(LEGACY_COMBINED_PATH, LEGACY_BACKUP_PATH)
	if err != OK:
		push_error("Failed to archive legacy file (%s -> %s). Error: %d" % [LEGACY_COMBINED_PATH, LEGACY_BACKUP_PATH, err])


func _sanitize_progress() -> void:
	# Ensure required keys exist and are correct types
	if typeof(_progress) != TYPE_DICTIONARY:
		_progress = {}
	
	if not _progress.has("schema_version"):
		_progress["schema_version"] = 1
	if not _progress.has("current_workout_index"):
		_progress["current_workout_index"] = 0
	if not _progress.has("exercises") or typeof(_progress["exercises"]) != TYPE_DICTIONARY:
		_progress["exercises"] = {}
	
	# Clamp workout index into current program range
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
