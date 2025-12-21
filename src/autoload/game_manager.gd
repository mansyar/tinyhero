# autoload/game_manager.gd
extends Node

enum DeviceMode { PARENT, CHILD, UNKNOWN }

var current_mode: DeviceMode = DeviceMode.UNKNOWN
var is_tablet: bool = false
var family_id: String = ""
var current_user: Dictionary = {}
var _debug_id: String = ""

func get_device_id() -> String:
	if OS.is_debug_build():
		if _debug_id == "":
			_debug_id = OS.get_unique_id() + "_" + str(randi() % 1000)
		return _debug_id
	return OS.get_unique_id()
var SETTINGS_PATH = "user://settings.cfg"

func _init():
	# For multi-instance testing, use separate settings files
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		var arg = args[i]
		if arg.contains("instance"):
			var idx = ""
			if "=" in arg:
				idx = arg.split("=")[-1]
			elif i + 1 < args.size():
				idx = args[i+1]
			
			if idx != "":
				SETTINGS_PATH = "user://settings_" + idx + ".cfg"
				DisplayServer.window_set_title("TinyHero - Instance " + idx)
				print("TinyHero: Using isolated settings path: ", SETTINGS_PATH)
				break


func _ready():
	load_settings()
	if current_mode == DeviceMode.UNKNOWN:
		detect_device_type()
	
	# ... rest of the original _ready logic ...
	get_tree().node_added.connect(_on_node_added)
	
	if JavaScriptBridge:
		var window = JavaScriptBridge.get_interface("window")
		if window:
			window.addEventListener("hashchange", _on_deep_link_received)
	
	if OS.has_feature("android") or OS.has_feature("ios"):
		var args = OS.get_cmdline_args()
		for arg in args:
			if arg.begins_with("com.tinyhero.app://"):
				_on_deep_link_received(arg)

func _input(event):
	if OS.is_debug_build() and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE and event.shift_pressed:
			print("TinyHero: DEBUG RESET TRIGGERED")
			family_id = ""
			current_mode = DeviceMode.UNKNOWN
			var dir = DirAccess.open("user://")
			if dir:
				dir.remove(SETTINGS_PATH.get_file())
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_node_added(_node: Node):
	# If a GoogleOAuth node is added later, check if we have a pending link
	pass

func _on_deep_link_received(url: String):
	print("TinyHero: Global deep link received: ", url)
	# Broadcast to any active GoogleOAuth handlers
	get_tree().call_group("oauth_handlers", "handle_deep_link", url)

func save_settings():
	var config = ConfigFile.new()

	config.set_value("device", "mode", current_mode)
	config.set_value("device", "family_id", family_id)
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		print("TinyHero: Error saving settings: ", err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err == OK:
		current_mode = config.get_value("device", "mode", DeviceMode.UNKNOWN) as DeviceMode
		family_id = config.get_value("device", "family_id", "")
		print("TinyHero: Settings loaded. Mode: ", current_mode, " Family: ", family_id)

func detect_device_type():
	var screen_size = DisplayServer.screen_get_size()
	var aspect_ratio = float(screen_size.x) / float(screen_size.y)
	
	# Detect tablet vs phone
	is_tablet = aspect_ratio < 1.5 or min(screen_size.x, screen_size.y) > 600
	
	# If on Desktop (Windows/macOS/Linux), default to PARENT regardless of screen size
	# This avoids the "1280x800 PC window = Tablet" issue.
	if OS.has_feature("pc"):
		current_mode = DeviceMode.PARENT
	else:
		current_mode = DeviceMode.CHILD if is_tablet else DeviceMode.PARENT
		
	print("TinyHero: Detected platform: ", "PC" if OS.has_feature("pc") else "Mobile")
	print("TinyHero: Detected device type. Is Tablet: ", is_tablet, " Suggested Mode: ", current_mode)


func switch_to_parent_mode():
	current_mode = DeviceMode.PARENT
	save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn") # Refresh router

func switch_to_child_mode():
	current_mode = DeviceMode.CHILD
	save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn") # Refresh router


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
			save_settings()
			print("TinyHero: Family loaded: ", family_id)
