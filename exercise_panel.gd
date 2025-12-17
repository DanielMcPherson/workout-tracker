extends PanelContainer
class_name ExercisePanel

signal reps_changed

@export var weight_step: float = 5.0
@export var min_weight: float = 0.0
@export var max_weight: float = 999.9
@export var drop_set_factor: float = 0.80	# 80% of working weight

@export var reps_step: int = 1
@export var min_reps: int = 0
@export var max_reps: int = 50

@onready var title_label: Label = $ContentMargin/VBoxContainer/TitleLabel
@onready var last_value: Label = $ContentMargin/VBoxContainer/GridContainer/LastValue
@onready var drop_value_label: Label = $ContentMargin/VBoxContainer/GridContainer/DropValueLabel

@onready var weight_line_edit: LineEdit = $ContentMargin/VBoxContainer/GridContainer/WeightHBox/WeightLineEdit
@onready var reps_line_edit: LineEdit = $ContentMargin/VBoxContainer/GridContainer/RepsHBox/RepsLineEdit

@onready var weight_up_button: Button = $ContentMargin/VBoxContainer/GridContainer/WeightHBox/WeightUpButton
@onready var weight_down_button: Button = $ContentMargin/VBoxContainer/GridContainer/WeightHBox/WeightDownButton
@onready var reps_up_button: Button = $ContentMargin/VBoxContainer/GridContainer/RepsHBox/RepsUpButton
@onready var reps_down_button: Button = $ContentMargin/VBoxContainer/GridContainer/RepsHBox/RepsDownButton


func _ready() -> void:
	# Connect button signals
	weight_up_button.pressed.connect(_on_weight_up_pressed)
	weight_down_button.pressed.connect(_on_weight_down_pressed)
	reps_up_button.pressed.connect(_on_reps_up_pressed)
	reps_down_button.pressed.connect(_on_reps_down_pressed)
	# Optional: normalize any default text
	set_weight(get_weight())
	set_reps(get_reps())


func set_exercise_name(exercise_name: String) -> void:
	title_label.text = exercise_name


func set_last(weight: float, reps: int) -> void:
	# Example format: "30 lb × 11 reps"
	var w := "%.1f" % weight
	if abs(weight - int(weight)) < 0.001:
		w = str(int(weight))	# drop trailing .0
	last_value.text = "%s lb × %d reps" % [w, reps]


# Weight functions
func get_weight() -> float:
	var txt := weight_line_edit.text.strip_edges()
	if txt == "":
		return 0.0
	var value := float(txt) if txt.is_valid_float() else 0.0
	return clamp(value, min_weight, max_weight)

func set_weight(value: float) -> void:
	value = clamp(value, min_weight, max_weight)
	# Format; keep as plain number, you can decide decimals:
	weight_line_edit.text = str(value)
	_update_drop_set(value)

func _on_weight_down_pressed() -> void:
	set_weight(get_weight() - weight_step)

func _on_weight_up_pressed() -> void:
	set_weight(get_weight() + weight_step)

func _update_drop_set(weight: float) -> void:
	# Calculate raw drop-set weight
	var drop := weight * drop_set_factor
	# Round to nearest weight_step
	var step := weight_step
	drop = round(drop / step) * step
	# Clamp so we don't show negative or weird values
	drop = clamp(drop, min_weight, max_weight)
	# Format for display (drop trailing .0)
	var text := ""
	if abs(drop - int(drop)) < 0.001:
		text = str(int(drop))
	else:
		text = "%.1f" % drop
	drop_value_label.text = text + " lb"

# Reps functions
func get_reps() -> int:
	var txt := reps_line_edit.text.strip_edges()
	if txt == "":
		return 0
	var value := int(txt) if txt.is_valid_int() else 0
	return clamp(value, min_reps, max_reps)

func set_reps(value: int) -> void:
	value = clamp(value, min_reps, max_reps)
	reps_line_edit.text = str(value)
	emit_signal("reps_changed")

func _on_reps_down_pressed() -> void:
	set_reps(get_reps() - reps_step)

func _on_reps_up_pressed() -> void:
	set_reps(get_reps() + reps_step)
