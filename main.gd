extends Control

@onready var workout_title_label: Label = $MainMargin/MainVBox/TitlePanel/MarginContainer/WorkoutTitleLabel

@onready var exercise1: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel1
@onready var exercise2: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel2
@onready var exercise3: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel3

@onready var timer_button: Button = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerButton
@onready var complete_button: Button = $MainMargin/MainVBox/FooterPanel/MarginContainer/CompleteButton
@onready var timer_value: Label = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerValue

var _elapsed_ms: int = 0
var _tick_timer: Timer
var _timer_running: bool = false

var _complete_dialog: ConfirmationDialog

const CONFIG_SRC: String = "res://program_config.json"
const CONFIG_DST: String = "user://program_config.json"
var _program_config: Dictionary = {}

# Copy blank default program config to user directory
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


func _ready() -> void:
		# Create and configure the internal tick timer
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 0.1   # update every 100 ms
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	
	timer_value.custom_minimum_size.x = 400  # tweak to taste
	timer_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Initial timer display
	_reset_timer_display()
	
	# Connect buttons
	timer_button.pressed.connect(_on_timer_button_pressed)
	complete_button.pressed.connect(_on_complete_button_pressed)
	
	# Listen for reps changes from each exercise
	exercise1.reps_changed.connect(_on_any_reps_changed)
	exercise2.reps_changed.connect(_on_any_reps_changed)
	exercise3.reps_changed.connect(_on_any_reps_changed)
	_update_complete_button_enabled()
	
	# Create the confirmation dialog
	_complete_dialog = ConfirmationDialog.new()
	_complete_dialog.title = "Complete workout?"
	_complete_dialog.dialog_text = "Finish workout and save these sets?"
	add_child(_complete_dialog)
	
	# When user taps OK in the dialog, run our completion logic
	_complete_dialog.confirmed.connect(_on_complete_confirmed)
	
	# Ensure user config exists, then load it
	_ensure_user_config_exists()
	_load_program_config()


func _load_program_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_DST, FileAccess.READ)
	if file == null:
		push_error("Could not open %s (error %d)" % [CONFIG_DST, FileAccess.get_open_error()])
		return
	
	var text: String = file.get_as_text()
	var data: Dictionary = JSON.parse_string(text)
	if data.is_empty():
		push_error("Invalid JSON: empty or failed to parse in %s" % CONFIG_DST)
		return
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON format in %s" % CONFIG_DST)
		return
	
	_program_config = data
	_apply_current_workout()


func _apply_current_workout() -> void:
	if _program_config.is_empty():
		return

	var meta: Dictionary = _program_config.get("meta", {})
	var workouts: Array = _program_config.get("workouts", [])
	if workouts.is_empty():
		push_error("No workouts defined in program_config.json")
		return

	var current_index: int = int(meta.get("current_workout_index", 0))
	current_index = clamp(current_index, 0, workouts.size() - 1)

	var workout: Dictionary = workouts[current_index]
	
	var workout_name: String = workout.get("name")
	workout_title_label.text = workout_name
	
	var exercise_ids: Array = workout.get("exercises", [])
	if exercise_ids.size() < 3:
		push_error("Workout %s does not have 3 exercises" % str(workout.get("id", "?")))
		return

	var exercise_map: Dictionary = _program_config.get("exercises", {})

	_setup_exercise_panel(exercise1, exercise_ids[0], exercise_map)
	_setup_exercise_panel(exercise2, exercise_ids[1], exercise_map)
	_setup_exercise_panel(exercise3, exercise_ids[2], exercise_map)


func _setup_exercise_panel(panel: Node, exercise_id: String, exercise_map: Dictionary) -> void:
	if not exercise_map.has(exercise_id):
		push_error("Exercise id '%s' not found in config" % exercise_id)
		return

	var data: Dictionary = exercise_map[exercise_id]
	var exercise_name: String = data.get("name", exercise_id)

	var last_weight_raw = data.get("last_weight", null)
	var last_reps_raw = data.get("last_reps", null)

	# Treat null as "no previous data" → 0 for now
	var last_weight: float = 0.0
	var last_reps: int = 0

	if last_weight_raw != null:
		last_weight = float(last_weight_raw)
	if last_reps_raw != null:
		last_reps = int(last_reps_raw)

	# Set exercise name
	if panel.has_method("set_exercise_name"):
		panel.set_exercise_name(exercise_name)

	# Show "Last: X lb × Y reps" (or whatever your panel does)
	if panel.has_method("set_last"):
		panel.set_last(last_weight, last_reps)

	# Pre-fill working weight with last_weight (and update drop-set label)
	if panel.has_method("set_weight"):
		var current_weight := last_weight
		if last_reps > 12:
			current_weight += 5.0
		panel.set_weight(current_weight)


func _save_current_workout_results() -> void:
	if _program_config.is_empty():
		return

	var workouts: Array = _program_config.get("workouts", [])
	var exercise_map: Dictionary = _program_config.get("exercises", {})
	if workouts.is_empty():
		push_error("No workouts in config")
		return

	var meta: Dictionary = _program_config.get("meta", {})
	var current_index: int = int(meta.get("current_workout_index", 0))
	if current_index < 0 or current_index >= workouts.size():
		current_index = 0

	var workout: Dictionary = workouts[current_index]
	var exercise_ids: Array = workout.get("exercises", [])
	if exercise_ids.size() < 3:
		push_error("Workout has fewer than 3 exercises")
		return

	var panels: Array = [exercise1, exercise2, exercise3]

	for i in range(3):
		var ex_id: String = String(exercise_ids[i])
		if not exercise_map.has(ex_id):
			continue

		var panel: Node = panels[i]
		var ex_data: Dictionary = exercise_map[ex_id]
		var weight: float = panel.get_weight()
		var reps: int = panel.get_reps()

		ex_data["last_weight"] = weight
		ex_data["last_reps"] = reps
		exercise_map[ex_id] = ex_data

	_program_config["exercises"] = exercise_map

	# Advance to next workout (wrap around the list)
	var next_index: int = (current_index + 1) % workouts.size()
	meta["current_workout_index"] = next_index
	_program_config["meta"] = meta

	_save_program_config_to_disk()


func _save_program_config_to_disk() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_DST, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save config to %s" % CONFIG_DST)
		return

	var json_text: String = JSON.stringify(_program_config, "\t")
	file.store_string(json_text)



func _on_timer_button_pressed() -> void:
	# "Start/Reset": always reset to 0 and ensure the timer is running.
	_elapsed_ms = 0
	_update_timer_label()

	if not _timer_running:
		_tick_timer.start()
		_timer_running = true
	# If already running, we just reset the elapsed time and keep counting up.

func _on_tick_timer_timeout() -> void:
	_elapsed_ms += 100
	_update_timer_label()

func _reset_timer_display() -> void:
	_elapsed_ms = 0
	timer_value.text = "0:00"


func _update_timer_label() -> void:
	var total_ms: int = _elapsed_ms
	var minutes: int = total_ms / 60000
	var seconds: int = (total_ms / 1000) % 60
	var hundredths: int = (total_ms / 10) % 100

	timer_value.text = "%02d:%02d.%02d" % [minutes, seconds, hundredths]


func _on_any_reps_changed() -> void:
	_update_complete_button_enabled()


func _update_complete_button_enabled() -> void:
	complete_button.disabled = not _all_exercises_have_reps()


func _all_exercises_have_reps() -> bool:
	return exercise1.get_reps() > 0 \
		and exercise2.get_reps() > 0 \
		and exercise3.get_reps() > 0

func _on_complete_button_pressed() -> void:
	_complete_dialog.popup_centered()


func _on_complete_confirmed() -> void:
	print("Complete Workout")
	print("%s lb × %d reps" % [exercise1.get_weight(), exercise1.get_reps()])
	print("%s lb × %d reps" % [exercise2.get_weight(), exercise2.get_reps()])
	print("%s lb × %d reps" % [exercise3.get_weight(), exercise3.get_reps()])

	# Optional: stop the timer when workout is finished
	if _timer_running:
		_tick_timer.stop()
		_timer_running = false
		
	_save_current_workout_results()
	
	# Go to “Workout Completed / Next Workout” screen
	get_tree().change_scene_to_file("res://workout_menu.tscn")
