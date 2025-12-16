extends Control

@onready var title_label: Label = $MainMargin/MainVBox/TitleLabel
@onready var workout_label: Label = $MainMargin/MainVBox/WorkoutLabel
@onready var start_button: Button = $MainMargin/MainVBox/StartButton

func _ready() -> void:
	ConfigStore.ensure_loaded()
	_update_labels()
	start_button.pressed.connect(_on_start_button_pressed)


func _update_labels() -> void:
	var idx := ConfigStore.get_current_workout_index()
	var letter := String.chr(ord("A") + idx)
	workout_label.text = "%s: %s" % [letter, ConfigStore.get_current_workout_name()]
	
	#var cfg: Dictionary = ConfigStore.get_program_config()
	#var workouts: Array = cfg.get("workouts", [])
	#if workouts.is_empty():
		#title_label.text = "Workout Tracker"
		#workout_label.text = "No workouts configured"
		#return
	#
	#var current_index: int = ConfigStore.get_current_workout_index()
	#var workout: Dictionary = workouts[current_index]
	#
	#var letter := String.chr(ord("A") + current_index)
	#var workout_name: String = "%s: %s" % [
		#letter,
		#workout.get("name", "Workout %d" % current_index)
	#]
	
	title_label.text = "Workout Tracker"
	#workout_label.text = workout_name


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
