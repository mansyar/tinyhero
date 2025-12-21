# scenes/main.gd
extends Control

func _ready():
	# Initial delay or visual splash
	await get_tree().create_timer(1.0).timeout
	
	if GameManager.current_mode == GameManager.DeviceMode.CHILD:
		_route_child_device()
	else:
		_route_parent_device()

func _route_parent_device():
	var auth_client = SupabaseClient.supabase.auth.client
	if auth_client == null:
		print("TinyHero: No parent session. Opening login...")
		get_tree().change_scene_to_file("res://scenes/auth/login_screen.tscn")
	else:
		# auth_client IS the user object itself in this plugin version
		if auth_client.id != "":
			# We'll try to convert it to a dictionary or just use the properties
			# Most Godot Supabase plugins have a .get_dict() or simple properties
			# For now, let's just ensure we pass it correctly. 
			# If GameManager expects a dict, let's give it one with common fields.
			var user_dict = {
				"id": auth_client.id,
				"email": auth_client.email
			}
			GameManager.set_user(user_dict)
			print("TinyHero: Parent Authenticated. Loading dashboard...")
			get_tree().change_scene_to_file("res://scenes/parent_mode/parent_dashboard.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/auth/login_screen.tscn")

func _route_child_device():
	if GameManager.family_id == "":
		print("TinyHero: Child device not linked. Opening onboarding...")
		get_tree().change_scene_to_file("res://scenes/child_mode/onboarding_link.tscn")
	else:
		print("TinyHero: Child device linked. Loading child view...")
		get_tree().change_scene_to_file("res://scenes/child_mode/child_view.tscn")
