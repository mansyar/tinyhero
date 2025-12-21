# autoload/supabase_client.gd
extends Node

var SUPABASE_URL = ""
var SUPABASE_ANON_KEY = ""


var supabase: Supabase

func _ready():
	# Use the global Autoload instance
	var env = get_node_or_null("/root/Env")
	if env:
		SUPABASE_URL = env.SUPABASE_URL
		SUPABASE_ANON_KEY = env.SUPABASE_ANON_KEY
	
	if SUPABASE_URL == "" or SUPABASE_ANON_KEY == "":
		push_warning("TinyHero: Supabase credentials missing in Env.gd")
		return

		
	supabase = Supabase.new()
	supabase.set_config(SUPABASE_URL, SUPABASE_ANON_KEY)
	add_child(supabase)
	print("TinyHero: Supabase Client Initialized via Env.gd")




# Database queries
func get_family(parent_uid: String) -> Dictionary:
	var query = SupabaseQuery.new().from("families").select().eq("parent_uid", parent_uid)
	var task = supabase.database.query(query)
	await task.completed
	if task.data is Array and task.data.size() > 0:
		return task.data[0]
	return {}

func create_family(parent_uid: String, email: String) -> Dictionary:
	var data = [{"parent_uid": parent_uid, "email": email}]
	var query = SupabaseQuery.new().from("families").insert(data)
	var task = supabase.database.query(query)
	await task.completed
	return task.data[0] if task.data is Array and task.data.size() > 0 else {}


var _realtime_client: RealtimeClient

# Realtime subscription
func subscribe_to_sessions(family_id: String, callback: Callable):
	if _realtime_client == null:
		_realtime_client = supabase.realtime.client()
		_realtime_client.connect_client()
		await _realtime_client.connected
	
	var channel = _realtime_client.channel("public", "sessions", "family_id=eq." + family_id)
	
	# The 4.x plugin uses signals: update, insert, delete, all
	# We map them to a dictionary format similar to what we planned
	channel.update.connect(func(old_record, new_record, _chan): 
		callback.call({"new": new_record, "old": old_record})
	)
	
	channel.subscribe()

