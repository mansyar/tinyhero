# autoload/game_manager.gd
extends Node

enum DeviceMode { PARENT, CHILD, UNKNOWN }

var current_mode: DeviceMode = DeviceMode.UNKNOWN
var is_tablet: bool = false
var family_id: String = ""
var current_user: Dictionary = {}

func _ready():
	detect_device_type()
	
	# Listen for deep links from the OS
	get_tree().node_added.connect(_on_node_added)
	
	if JavaScriptBridge:
		var window = JavaScriptBridge.get_interface("window")
		if window:
			window.addEventListener("hashchange", _on_deep_link_received)

	
	# Primary Godot callback for deep links (Android/iOS)
	# For Godot 4.x, we usually check this in a loop or via OS signals
	# But we'll add a helper to relay to the GoogleOAuth script
	if OS.has_feature("android") or OS.has_feature("ios"):
		# Get command line arguments which often contains the URI that opened it
		var args = OS.get_cmdline_args()
		for arg in args:
			if arg.begins_with("com.tinyhero.app://"):
				_on_deep_link_received(arg)

func _on_node_added(_node: Node):
	# If a GoogleOAuth node is added later, check if we have a pending link
	pass

func _on_deep_link_received(url: String):
	print("TinyHero: Global deep link received: ", url)
	# Broadcast to any active GoogleOAuth handlers
	get_tree().call_group("oauth_handlers", "handle_deep_link", url)


func detect_device_type():
	var screen_size = DisplayServer.screen_get_size()
	var aspect_ratio = float(screen_size.x) / float(screen_size.y)
	
	# Tablets typically have aspect ratio closer to 4:3 (1.33) vs phones 16:9 (1.78)
	is_tablet = aspect_ratio < 1.5 or min(screen_size.x, screen_size.y) > 600
	
	# Default mode suggestion
	current_mode = DeviceMode.CHILD if is_tablet else DeviceMode.PARENT
	print("TinyHero: Detected device type. Is Tablet: ", is_tablet, " Suggested Mode: ", current_mode)

func switch_to_parent_mode():
	current_mode = DeviceMode.PARENT
	# get_tree().change_scene_to_file("res://src/parent_mode/scenes/parent_dashboard.tscn")

func switch_to_child_mode():
	current_mode = DeviceMode.CHILD
	# get_tree().change_scene_to_file("res://src/child_mode/scenes/child_view.tscn")

func set_user(user_dict: Dictionary):
	current_user = user_dict
	# Trigger family lookup/creation
	_ensure_family_exists()


func _ensure_family_exists():
	if current_user.has("id"):
		var family = await SupabaseClient.get_family(current_user["id"])
		if family.is_empty():
			family = await SupabaseClient.create_family(current_user["id"], current_user.get("email", ""))
		
		if family.has("id"):
			family_id = family["id"]
			print("TinyHero: Family loaded: ", family_id)
