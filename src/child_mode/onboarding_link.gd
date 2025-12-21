# child_mode/onboarding_link.gd
extends Control

@onready var code_input: LineEdit = %CodeInput
@onready var status_label: Label = %StatusLabel
@onready var submit_button: Button = %SubmitButton

@onready var to_parent_button: Button = %ToParentButton

func _ready():
	submit_button.pressed.connect(_on_submit_pressed)
	to_parent_button.pressed.connect(_on_to_parent_pressed)
	code_input.text_changed.connect(_on_code_changed)

func _on_to_parent_pressed():
	GameManager.switch_to_parent_mode()


func _on_code_changed(new_text: String):
	code_input.text = new_text.to_upper()
	code_input.caret_column = code_input.text.length()

func _on_submit_pressed():
	var code = code_input.text
	if code.length() != 6:
		status_label.text = "Code must be 6 characters"
		return
		
	status_label.text = "Linking..."
	submit_button.disabled = true
	
	# 1. Find the session
	var query = SupabaseQuery.new().from("link_sessions").select().eq("token", code)
	var task = SupabaseClient.supabase.database.query(query)
	await task.completed
	
	if task.error or task.data.size() == 0:
		status_label.text = "Invalid or expired code"
		submit_button.disabled = false
		return
		
	var session = task.data[0]
	var family_id = session["family_id"]
	var device_id = GameManager.get_device_id()

	
	# 2. Claim it
	var update_data = {"claimed_by_device_id": device_id}
	var update_query = SupabaseQuery.new().from("link_sessions").update(update_data).eq("token", code)
	var update_task = SupabaseClient.supabase.database.query(update_query)
	await update_task.completed
	
	if update_task.error:
		status_label.text = "Link failed try again"
		submit_button.disabled = false
		return
		
	# 3. Create permanent link
	var link_data = [{
		"family_id": family_id,
		"device_id": device_id
	}]
	var link_query = SupabaseQuery.new().from("linked_devices").insert(link_data)
	var link_task = SupabaseClient.supabase.database.query(link_query)
	await link_task.completed
	
	# 4. Success! Save family ID and restart
	GameManager.family_id = family_id
	GameManager.save_settings()
	
	status_label.text = "Success! Hero linked."
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
