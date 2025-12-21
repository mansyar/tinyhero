# parent_mode/link_tablet.gd
extends Control

@onready var code_label: Label = %CodeLabel
@onready var status_label: Label = %StatusLabel
@onready var timer_label: Label = %TimerLabel

var current_token: String = ""
var expiry_time: float = 0.0

func _ready():
	_generate_new_code()

func _generate_new_code():
	status_label.text = "Generating code..."
	
	# Create a random 6-character code
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" # No ambiguous O/0/I/1
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	
	current_token = code
	
	# Save to Supabase
	var family_id = GameManager.family_id
	if family_id == "":
		status_label.text = "Error: No family ID found. Please log in again."
		return
		
	var expires_at = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system() + 300))

	var expires_str = "%d-%02d-%02dT%02d:%02d:%02dZ" % [expires_at.year, expires_at.month, expires_at.day, expires_at.hour, expires_at.minute, expires_at.second]
	
	var data = [{
		"family_id": family_id,
		"token": code,
		"expires_at": expires_str
	}]
	
	var query = SupabaseQuery.new().from("link_sessions").insert(data)
	var task = SupabaseClient.supabase.database.query(query)
	await task.completed
	
	if task.error:
		status_label.text = "Error saving code: " + str(task.error.message)
	else:
		code_label.text = code
		status_label.text = "Waiting for Hero to join..."
		expiry_time = Time.get_unix_time_from_system() + 300
		_subscribe_to_handshake()

func _subscribe_to_handshake():
	# Use the specific handshake subscription
	SupabaseClient.subscribe_to_link_sessions(GameManager.family_id, _on_session_update)


func _on_session_update(payload: Dictionary):
	var new_record = payload.get("new", {})
	if new_record.has("token") and new_record["token"] == current_token:
		if new_record.get("claimed_by_device_id"):
			# Don't show success if WE are the one who claimed it (shouldn't happen but good for safety)
			if new_record["claimed_by_device_id"] == GameManager.get_device_id():
				return
				
			status_label.text = "Success! Hero device linked."

			await get_tree().create_timer(2.0).timeout
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _process(_delta):
	if expiry_time > 0:
		var remaining = int(expiry_time - Time.get_unix_time_from_system())
		if remaining > 0:
			var minutes = int(remaining / 60.0)
			var seconds = int(remaining) % 60
			timer_label.text = "Expires in: %d:%02d" % [minutes, seconds]

		else:
			timer_label.text = "Expired"
			_generate_new_code()
