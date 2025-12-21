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
	if SupabaseClient.supabase.auth.client == null:
		print("TinyHero: No parent session. Opening login...")
		get_tree().change_scene_to_file("res://scenes/auth/login_screen.tscn")
	else:
		var user = SupabaseClient.supabase.auth.client
		GameManager.set_user(user.dict)
		print("TinyHero: Parent Authenticated. Loading dashboard...")
		# get_tree().change_scene_to_file("res://scenes/parent_mode/dashboard.tscn")

func _route_child_device():
	if GameManager.family_id == "":
		print("TinyHero: Child device not linked. Opening onboarding...")
		get_tree().change_scene_to_file("res://scenes/child_mode/onboarding_link.tscn")
	else:
		print("TinyHero: Child device linked. Loading child view...")
		# get_tree().change_scene_to_file("res://scenes/child_mode/child_view.tscn")
