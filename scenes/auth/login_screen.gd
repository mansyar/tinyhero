# scenes/auth/login_screen.gd
extends Control

@onready var login_button = %LoginButton
@onready var status_label = %StatusLabel
@onready var link_input = %LinkInput

var oauth: GoogleOAuth

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	link_input.text_submitted.connect(_on_link_submitted)
	
	oauth = GoogleOAuth.new()
	add_child(oauth)
	
	oauth.auth_completed.connect(_on_auth_completed)
	oauth.auth_failed.connect(_on_auth_failed)

func _on_login_pressed():
	login_button.disabled = true
	status_label.text = "Opening browser..."
	oauth.start_google_login()

func _on_link_submitted(text: String):
	if text.begins_with("com.tinyhero.app://") or text.begins_with("http://localhost"):
		status_label.text = "Processing manual link..."
		oauth.handle_deep_link(text)
	else:
		# Try to process it anyway if it contains a token
		if "access_token=" in text:
			oauth.handle_deep_link(text)
		else:
			status_label.text = "Invalid link format"


func _on_auth_completed(user_data: Dictionary):
	status_label.text = "Login successful! Loading family..."
	GameManager.set_user(user_data)
	# After GameManager finishes lookup, it will change scene
	# For now, let's just wait a beat
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_auth_failed(error_msg: String):
	login_button.disabled = false
	status_label.text = "Error: " + error_msg
	print("TinyHero: Auth failed: ", error_msg)
