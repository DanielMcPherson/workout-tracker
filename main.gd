extends Control

@onready var exercise1: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel1
@onready var exercise2: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel2
@onready var exercise3: PanelContainer = $MainMargin/MainVBox/ScrollContainer/ExerciseVBox/ExercisePanel3

@onready var timer_button: Button = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerButton
@onready var complete_button: Button = $MainMargin/MainVBox/FooterPanel/MarginContainer/CompleteButton
@onready var timer_value: Label = $MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerValue

var _elapsed_ms: int = 0
var _tick_timer: Timer
var _timer_running: bool = false


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


func _on_complete_button_pressed() -> void:
	print("Complete Workout")
	print("%s lb × %d reps" % [exercise1.get_weight(), exercise1.get_reps()])
		# Optional: stop the timer when workout is complete
	if _timer_running:
		_tick_timer.stop()
		_timer_running = false
