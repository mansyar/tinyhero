# parent_mode/parent_dashboard.gd
extends Control

@onready var status_label: Label = %StatusLabel
@onready var family_id_label: Label = %FamilyIDLabel # Added this line based on the new code's usage

func _ready():
	_setup_ui()
	_load_family_data()
	_listen_for_sessions()

func _setup_ui():
	family_id_label.text = "Family ID: " + GameManager.family_id
	# Hide active session UI by default
	%ActiveSessionUI.hide()
	%HabitSelectionUI.show()

func _load_family_data():
	# This function was called in _ready but not provided in the snippet.
	# Assuming it might be for loading other family-related data.
	# For now, it's an empty placeholder.
	pass

func _listen_for_sessions():
	SupabaseClient.subscribe_to_sessions(GameManager.family_id, _on_session_update)

func _on_session_update(payload: Dictionary):
	print("TinyHero: Session update: ", payload)
	var event = payload.get("event", "")
	var session = payload.get("new", {})
	var state = session.get("session_state", "IDLE")
	
	if event == "DELETE" or state == "IDLE" or not session or session.is_empty():
		print("TinyHero: Session reset to IDLE. Showing selection.")
		_show_habit_selection()
	else:
		_show_active_session(session)

func _show_active_session(session: Dictionary):
	%HabitSelectionUI.hide()
	%ActiveSessionUI.show()
	
	var state = session.get("session_state", "ACTIVE")
	var habit = session.get("active_habit", "Busy").to_upper()
	
	%ActiveHabitLabel.text = "Hero is: " + habit
	%SessionStatusLabel.text = "Status: " + state
	_current_session_id = session.get("id", "")
	
	# Close the loop: If already approved, turn the button into a "Reset" button
	if state == "SUCCESS":
		%Complete.text = "🏁 Finish & Reset"
		%Complete.modulate = Color(1, 1, 1) # Neutral white/blue
		%Nudge.disabled = true
	else:
		%Complete.text = "✅ APPROVE"
		%Complete.modulate = Color(0.2, 0.8, 0.2) # Success green
		%Nudge.disabled = false

func _show_habit_selection():
	%ActiveSessionUI.hide()
	%HabitSelectionUI.show()
	_current_session_id = ""

var _current_session_id = ""

# --- Signal Handlers ---

func _on_start_habit_pressed(habit_id: String):
	print("TinyHero: Starting habit: ", habit_id)
	await SupabaseClient.start_session(GameManager.family_id, habit_id)

func _on_nudge_pressed():
	if _current_session_id != "":
		SupabaseClient.nudge_session(_current_session_id)

func _on_complete_pressed():
	print("TinyHero: Complete button pressed. Current session:", _current_session_id)
	if _current_session_id != "":
		if %SessionStatusLabel.text.contains("SUCCESS"):
			print("TinyHero: Ending session...")
			SupabaseClient.end_session(_current_session_id)
			_show_habit_selection() # Local fallback
		else:
			print("TinyHero: Approving session...")
			SupabaseClient.approve_session(_current_session_id)
	else:
		print("TinyHero Error: No session ID to complete!")

func _on_cancel_session_pressed():
	if _current_session_id != "":
		SupabaseClient.end_session(_current_session_id)
		_show_habit_selection() # Local fallback

func _on_link_device_pressed():
	get_tree().change_scene_to_file("res://scenes/parent_mode/link_tablet.tscn")

func _on_switch_mode_pressed():
	# Use the Parent Gate before switching to child? 
	# Actually, Parent -> Child is easy. Child -> Parent needs the gate.
	GameManager.switch_to_child_mode()

func _on_logout_pressed():
	# Simple logout logic
	GameManager.family_id = ""
	GameManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
