extends Control

@onready var exercise1: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel1
@onready var exercise2: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel2
@onready var exercise3: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel3

@onready var timer_button: Button = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerButton
@onready var complete_button: Button = $MainMargin/MainVBox/FooterPanel/MarginContainer/CompleteButton


func _ready() -> void:
	complete_button.pressed.connect(_on_complete_button_pressed)
	# Test setting weights
	exercise1.set_exercise_name("Hammer curls")
	exercise1.set_last(30, 14)
	exercise1.set_weight(35)
	exercise2.set_exercise_name("Machine row")
	exercise2.set_last(120, 9)
	exercise2.set_weight(120)
	exercise3.set_exercise_name("Hamstring curls")
	exercise3.set_last(70, 10)
	exercise3.set_weight(70)


func _on_complete_button_pressed() -> void:
	print("Complete Workout")
	print("%s lb × %d reps" % [exercise1.get_weight(), exercise1.get_reps()])
