# autoload/supabase_client.gd
extends Node

# NOTE TO USER: Fill these in your project settings or env
const SUPABASE_URL = "https://uqvwmuulxcbkgtwmtnxp.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxdndtdXVseGNia2d0d210bnhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMTY4MTMsImV4cCI6MjA4MTg5MjgxM30.-yz162J5PaGJhWMwuh6ghHXRJBpr8mi2e1owyZdTi2A"

var supabase: Supabase

func _ready():
	if SUPABASE_URL == "" or SUPABASE_ANON_KEY == "":
		push_warning("TinyHero: Supabase URL or Anon Key is missing. Please configure them in supabase_client.gd")
		return
		
	supabase = Supabase.new()
	supabase.set_config(SUPABASE_URL, SUPABASE_ANON_KEY)
	add_child(supabase)
	print("TinyHero: Supabase Client Initialized")


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

