extends Control

@onready var title_label: Label = $MainMargin/MainVBox/TitleLabel
@onready var workout_label: Label = $MainMargin/MainVBox/WorkoutLabel
@onready var start_button: Button = $MainMargin/MainVBox/StartButton

const CONFIG_SRC: String = "res://program_config.json"
const CONFIG_DST: String = "user://program_config.json"

var _program_config: Dictionary = {}

func _ready() -> void:
	_ensure_user_config_exists()
	_load_program_config()
	start_button.pressed.connect(_on_start_button_pressed)

func _ensure_user_config_exists() -> void:
	if FileAccess.file_exists(CONFIG_DST):
		return
	
	var src := FileAccess.open(CONFIG_SRC, FileAccess.READ)
	if src == null:
		push_error("Could not open default config at %s" % CONFIG_SRC)
		return
	
	var dst := FileAccess.open(CONFIG_DST, FileAccess.WRITE)
	if dst == null:
		push_error("Could not open user config at %s" % CONFIG_DST)
		return
	
	var contents := src.get_as_text()
	dst.store_string(contents)

func _load_program_config() -> void:
	var file := FileAccess.open(CONFIG_DST, FileAccess.READ)
	if file == null:
		push_error("Could not open %s (error %d)" % [CONFIG_DST, FileAccess.get_open_error()])
		return
	
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s: %s" % [CONFIG_DST, json.get_error_message()])
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid JSON format in %s" % CONFIG_DST)
		return
	
	_program_config = data
	_update_ui_for_current_workout()

func _update_ui_for_current_workout() -> void:
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
	var letter := String.chr(ord("A") + current_index)
	var workout_name: String = "%s: %s" % [
		letter,
		workout.get("name", "Workout %d" % current_index)
	]
	
	title_label.text = "Workout Tracker"
	workout_label.text = workout_name

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
