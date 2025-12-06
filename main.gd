extends Control

@onready var exercise1: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel1
@onready var exercise2: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel2
@onready var exercise3: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel3

@onready var timer_button: Button = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerButton
@onready var complete_button: Button = $MainMargin/MainVBox/FooterPanel/MarginContainer/CompleteButton


func _ready() -> void:
	complete_button.pressed.connect(_on_complete_button_pressed)
	# Test setting weights
	exercise1.set_weight(10)
	exercise2.set_weight(20)
	exercise3.set_weight(30)


func _on_complete_button_pressed() -> void:
	print("Complete Workout")
	print(exercise1.get_weight())
