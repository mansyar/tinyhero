# child_mode/child_view.gd
extends Control

@onready var label: Label = %StatusLabel
@onready var gate: Control = $ParentGate

func _ready():
	label.text = "Welcome, Hero!"
	# Add a hint
	%StatusLabel.text = "Hero Mode (Tap Menu to return)"
	
	# SELF-HEALING: If the scene structure is broken, spawn the gate manually
	if not gate:
		print("TinyHero: ParentGate missing from scene, spawning manually...")
		var gate_scene = preload("res://src/shared/parent_gate.tscn")
		if gate_scene:
			gate = gate_scene.instantiate()
			add_child(gate)
		else:
			print("TinyHero CRITICAL: Could not load parent_gate.tscn")
			return


	if gate:
		if not gate.gate_passed.is_connected(_on_gate_passed):
			gate.gate_passed.connect(_on_gate_passed)
	else:
		print("TinyHero Error: ParentGate STILL not found after spawning!")

func _on_switch_to_parent_pressed():
	if gate and gate.has_method("open_gate"):
		gate.open_gate()
	else:
		print("TinyHero Error: Gate is null or missing 'open_gate' method")

func _on_gate_passed():
	GameManager.switch_to_parent_mode()
