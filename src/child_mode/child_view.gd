# child_mode/child_view.gd
extends Control

@onready var label: Label = %StatusLabel
@onready var gate: Control = $ParentGate

func _ready():
	_setup_gate()
	_setup_character()
	_listen_for_sessions()

func _setup_gate():
	# SELF-HEALING: If the scene structure is broken, spawn the gate manually
	if not gate:
		print("TinyHero: ParentGate missing from scene, searching...")
		gate = find_child("ParentGate", true, false)
		
	if not gate:
		print("TinyHero: ParentGate still missing, spawning manually...")
		var gate_scene = load("res://src/shared/parent_gate.tscn")
		if gate_scene:
			gate = gate_scene.instantiate()
			add_child(gate)
		else:
			print("TinyHero CRITICAL: Could not load parent_gate.tscn")
			return

	if gate and not gate.gate_passed.is_connected(_on_gate_passed):
		gate.gate_passed.connect(_on_gate_passed)

func _setup_character():
	var dino_scene = load("res://src/child_mode/character_controller.tscn")
	if dino_scene:
		character = dino_scene.instantiate()
		var anchor = get_node_or_null("%HeroAnchor")
		if anchor:
			anchor.add_child(character)
			# Dynamically center the anchor if its parent is a Control
			var parent_control = anchor.get_parent() as Control
			if parent_control:
				anchor.position = parent_control.size / 2
				if not parent_control.resized.is_connected(_on_anchor_parent_resized):
					parent_control.resized.connect(_on_anchor_parent_resized)
		else:
			add_child(character) # Fallback
			character.position = size / 2
	else:
		print("TinyHero Error: Could not load character_controller.tscn")

func _on_anchor_parent_resized():
	var anchor = get_node_or_null("%HeroAnchor")
	if anchor:
		var parent_control = anchor.get_parent() as Control
		if parent_control:
			anchor.position = parent_control.size / 2

func _listen_for_sessions():
	SupabaseClient.subscribe_to_sessions(GameManager.family_id, _on_session_update)

func _on_session_update(payload: Dictionary):
	print("TinyHero: Session update: ", payload)
	var event = payload.get("event", "")
	var session = payload.get("new", {})
	
	var state = session.get("session_state", "IDLE")
	if state == null: state = "IDLE"
	
	if event == "DELETE" or state == "IDLE" or not session or session.is_empty():
		_set_hero_state("IDLE")
		return
	
	var habit = session.get("active_habit", "")
	if habit == null: habit = ""
	
	var nudge = session.get("nudge_timestamp", "")
	# Handle null from database
	if nudge == null: nudge = ""
	
	if nudge != "" and nudge != _last_nudge:
		_on_nudge_received()
		_last_nudge = nudge
	
	_set_hero_state(state, habit)

func _set_hero_state(state: String, habit: String = ""):
	if not character: return
	
	match state:
		"ACTIVE":
			character.set_state(character.State.ACTIVE)
			%StatusLabel.text = "Hero is: " + habit.to_upper()
		"SUCCESS":
			character.set_state(character.State.SUCCESS)
			%StatusLabel.text = "MISSION COMPLETE!"
		"IDLE":
			character.set_state(character.State.IDLE)
			%StatusLabel.text = "Waiting for Mission..."

func _on_nudge_received():
	print("TinyHero: Nudge received!")
	if character:
		character.play_nudge()
	# Screen shake
	var tween = create_tween()
	tween.tween_property(self, "position:x", 10.0, 0.05)
	tween.chain().tween_property(self, "position:x", -10.0, 0.05)
	tween.chain().tween_property(self, "position:x", 0.0, 0.05)
	
	# Mobile vibration
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(200)

var character: Node2D
var _last_nudge: String = ""

func _on_switch_to_parent_pressed():
	if gate and gate.has_method("open_gate"):
		gate.open_gate()
	else:
		print("TinyHero Error: Gate is null or missing 'open_gate' method")

func _on_gate_passed():
	GameManager.switch_to_parent_mode()
