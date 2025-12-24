# child_mode/child_view.gd
extends Control

@onready var label: Label = %StatusLabel
@onready var gate: Control = $ParentGate

func _ready():
	_setup_gate()
	_setup_character()
	_listen_for_sessions()
	%MissionUI.hide()

func _process(_delta):
	if %MissionUI.visible and _cutoff_unix > 0:
		var time_left = max(0, _cutoff_unix - Time.get_unix_time_from_system())
		
		# Update Timer label
		var mins = int(time_left / 60.0)
		var secs = int(time_left) % 60
		%TimerLabel.text = "%02d:%02d" % [mins, secs]
		
		# Update Progress Bar
		if _duration_secs > 0:
			var progress = (1.0 - (float(time_left) / _duration_secs)) * 100.0
			%BoneProgressBar.value = progress
			
		# Handle automatic transition to SLEEPY if needed? 
		# (Roadmap says parent handles nudge/approve, but sleepy can be local)
		if time_left <= 0:
			# For now just show 00:00. Sleepy state logic could be added here.
			pass

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
	
	_current_session_id = session.get("id", "")
	
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

	var duration = session.get("duration_seconds", 0)
	var cutoff = session.get("cutoff_time", "")
	
	if state == "ACTIVE":
		%MissionUI.show()
		_duration_secs = int(duration)
		if cutoff != "" and cutoff != null:
			_cutoff_unix = Time.get_unix_time_from_datetime_string(cutoff)
	else:
		%MissionUI.hide()
		_cutoff_unix = 0
	
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
			_show_reward_reveal()
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

func _show_reward_reveal():
	# Avoid duplicate reveals
	if has_node("RewardReveal"): return
	
	var scene = load("res://scenes/child_mode/reward_reveal.tscn")
	if scene:
		var reveal = scene.instantiate()
		reveal.name = "RewardReveal"
		add_child(reveal)
		reveal.start_reveal()
		# When reward is claimed, we reset locally. 
		# The Parent will also reset via their "Finish" button.
		reveal.reward_claimed.connect(func(): 
			print("TinyHero: Reward claimed, resetting Hero and Session state.")
			if _current_session_id != "":
				SupabaseClient.end_session(_current_session_id)
			_set_hero_state("IDLE")
		)

var character: Node2D
var _last_nudge: String = ""
var _current_session_id: String = ""
var _duration_secs: int = 0
var _cutoff_unix: float = 0.0

func _on_switch_to_parent_pressed():
	if gate and gate.has_method("open_gate"):
		gate.open_gate()
	else:
		print("TinyHero Error: Gate is null or missing 'open_gate' method")

func _on_gate_passed():
	GameManager.switch_to_parent_mode()
