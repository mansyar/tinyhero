# parent_gate.gd
extends Control
class_name ParentGate

signal gate_passed

@onready var timer: Timer = $Timer
@onready var progress: TextureProgressBar = $Center/VBox/ProgressBar
@onready var label: Label = $Center/VBox/Label


var is_pressing: bool = false
var hold_time_required: float = 3.0
var current_hold_time: float = 0.0

func _ready():
	add_to_group("parent_gates")
	hide()
	progress.max_value = 1.0
	progress.value = 0
	set_process(false)
	# This ensures the gate catches all clicks and blocks the game underneath
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event):
	if not is_visible_in_tree():
		return
		
	# Check for both Mouse and Touch
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch
	
	if is_click or is_touch:
		if event.pressed:
			if not is_pressing:
				is_pressing = true
				set_process(true)
				print("TinyHero: Hold detected. Start filling...")
		else:
			if is_pressing:
				is_pressing = false
				set_process(false)
				current_hold_time = 0.0
				progress.value = 0
				print("TinyHero: Release detected. Resetting bar.")

func _process(delta):
	if is_pressing:
		current_hold_time += delta
		progress.value = current_hold_time / hold_time_required
		
		if current_hold_time >= hold_time_required:
			is_pressing = false
			set_process(false)
			print("TinyHero: Gate hold complete!")
			gate_passed.emit()
			hide()
			current_hold_time = 0.0
			progress.value = 0

func open_gate():
	show()
	current_hold_time = 0.0
	progress.value = 0
	label.text = "HOLD ANYWHERE FOR 3 SECONDS"


