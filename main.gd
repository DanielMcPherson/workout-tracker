extends Control

@onready var workout_title_label: Label = $Panel/MainMargin/MainVBox/TitlePanel/MarginContainer/WorkoutTitleLabel

@onready var exercises_container: VBoxContainer = $Panel/MainMargin/MainVBox/ScrollContainer/ExerciseVBox
var _exercise_panels: Array[ExercisePanel] = []
var _bound_exercise_ids: Array[String] = []

@onready var timer_button: Button = $Panel/MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerButton
@onready var complete_button: Button = $Panel/MainMargin/MainVBox/FooterPanel/MarginContainer/VBoxContainer/CompleteButton
@onready var cancel_button: Button = $Panel/MainMargin/MainVBox/FooterPanel/MarginContainer/VBoxContainer/CancelButton
@onready var timer_value: Label = $Panel/MainMargin/MainVBox/TimerPanel/MarginContainer/TimerVBox/TimerValue

var _elapsed_ms: int = 0
var _tick_timer: Timer
var _timer_running: bool = false

var _complete_dialog: ConfirmationDialog
var _cancel_dialog: ConfirmationDialog


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
	cancel_button.pressed.connect(_on_cancel_button_pressed)
		
	# Create the confirmation dialog
	_complete_dialog = ConfirmationDialog.new()
	_complete_dialog.title = "Complete workout?"
	_complete_dialog.dialog_text = "Finish workout and save these sets?"
	add_child(_complete_dialog)
	# When user taps OK in the dialog, run our completion logic
	_complete_dialog.confirmed.connect(_on_complete_confirmed)
	# Create the cancel dialog
	_cancel_dialog = ConfirmationDialog.new()
	_cancel_dialog.title = "Cancel workout?"
	_cancel_dialog.dialog_text = "Abandon workout without saving sets?"
	add_child(_cancel_dialog)
	_cancel_dialog.confirmed.connect(_on_cancel_confirmed)
	
	# Load workout config
	ConfigStore.ensure_loaded()
	_collect_exercise_panels()
	_update_complete_button_enabled()
	_apply_current_workout()


func _collect_exercise_panels() -> void:
	_exercise_panels.clear()
	for child in exercises_container.get_children():
		if child is ExercisePanel:
			var panel: ExercisePanel = child
			_exercise_panels.append(panel)
			# Connect reps_changed -> _on_any_reps_changed once
			if not panel.reps_changed.is_connected(_on_any_reps_changed):
				panel.reps_changed.connect(_on_any_reps_changed)


func _apply_current_workout() -> void:
	workout_title_label.text = ConfigStore.get_current_workout_name()
	
	var ids: Array = ConfigStore.get_current_workout_exercise_ids()
	_bound_exercise_ids.clear()
	
	var n : int = min(ids.size(), _exercise_panels.size())
	for i in range(n):
		var ex_id := String(ids[i])
		_bound_exercise_ids.append(ex_id)
		_setup_exercise_panel(_exercise_panels[i], ex_id)
		_exercise_panels[i].visible = true
	
	# Hide unused panels (e.g., you have 4 panels but workout only has 3)
	for i in range(n, _exercise_panels.size()):
		_exercise_panels[i].visible = false


func _setup_exercise_panel(panel: ExercisePanel, exercise_id: String) -> void:
	var exercise_name: String = ConfigStore.get_exercise_name(exercise_id)
	var last_weight: float = ConfigStore.get_last_weight(exercise_id, 0.0)
	var last_reps: int = ConfigStore.get_last_reps(exercise_id, 0)
	var max_reps := ConfigStore.get_max_reps(exercise_id)
	var has_drop_set := ConfigStore.has_drop_set(exercise_id)
	
	# Set exercise name
	panel.set_exercise_name(exercise_name + " x " + str(max_reps))
	panel.set_has_drop_set(has_drop_set)
	
	# Show "Last: X lb × Y reps"
	panel.set_last(last_weight, last_reps)
	
	# Pre-fill working weight with last_weight (and apply your >12 rule)
	var current_weight := last_weight
	if last_reps > ConfigStore.get_max_reps(exercise_id):
		current_weight += 5.0
		print("Increasing weight on " + exercise_name)
	panel.set_weight(current_weight)


func _save_current_workout_results() -> void:
	var n : int = min(_bound_exercise_ids.size(), _exercise_panels.size())
	for i in range(n):
		var ex_id := _bound_exercise_ids[i]
		var panel := _exercise_panels[i]
		ConfigStore.set_last_set(ex_id, float(panel.get_weight()), int(panel.get_reps()))
	
	ConfigStore.advance_to_next_workout()
	ConfigStore.save_progress()


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
	var all_have_reps := true
	for panel:ExercisePanel in _exercise_panels:
		if panel.is_visible() and panel.get_reps() == 0:
			all_have_reps = false
	return all_have_reps


func _on_complete_button_pressed() -> void:
	_complete_dialog.popup_centered()


func _on_cancel_button_pressed() -> void:
	_cancel_dialog.popup_centered()


func _on_complete_confirmed() -> void:
	print("Complete Workout")
	for panel: ExercisePanel in _exercise_panels:
		if panel.is_visible():
			print("%s lb × %d reps" % [panel.get_weight(), panel.get_reps()])
	
	# Optional: stop the timer when workout is finished
	if _timer_running:
		_tick_timer.stop()
		_timer_running = false
		
	_save_current_workout_results()
	
	# Go to “Workout Completed / Next Workout” screen
	get_tree().change_scene_to_file("res://workout_menu.tscn")


func _on_cancel_confirmed() -> void:
	print("Canceling workout")
	get_tree().change_scene_to_file("res://workout_menu.tscn")
