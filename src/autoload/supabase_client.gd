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
func subscribe_to_table(table: String, filter: String, callback: Callable):
	if _realtime_client == null:
		_realtime_client = supabase.realtime.client()
		_realtime_client.connect_client()
		await _realtime_client.connected
	
	var channel = _realtime_client.channel("public", table, filter)
	print("TinyHero: Subscribing to: ", channel.topic)
	
	# Safety check: Avoid duplicate connections if the signal is already connected to a lambda
	# However, since we use inline lambdas, it's hard to check for exact equality.
	# We will rely on is_valid() during execution to clean up zombie calls.
	
	channel.update.connect(func(old_record, record, _chan): 
		if callback.is_valid():
			print("TinyHero: REALTIME UPDATE received on ", table)
			callback.call({"new": record, "old": old_record, "event": "UPDATE"})
		else:
			# If the callback is invalid, we don't disconnect here (signal management is complex)
			# but we prevent the crash.
			pass
	)
	channel.insert.connect(func(record, _chan):
		if callback.is_valid():
			print("TinyHero: REALTIME INSERT received on ", table)
			callback.call({"new": record, "event": "INSERT"})
	)
	channel.delete.connect(func(old_record, _chan):
		if callback.is_valid():
			print("TinyHero: REALTIME DELETE received on ", table)
			callback.call({"old": old_record, "event": "DELETE"})
	)
	
	channel.subscribe()
	print("TinyHero: Subscription call sent for ", table)

func subscribe_to_sessions(family_id: String, callback: Callable):
	subscribe_to_table("sessions", "family_id=eq." + family_id, callback)

func subscribe_to_link_sessions(family_id: String, callback: Callable):
	subscribe_to_table("link_sessions", "family_id=eq." + family_id, callback)

# Habit Session Management
func start_session(family_id: String, habit_id: String, theme_id: String = "dino", duration_secs: int = 120) -> Dictionary:
	# 1. Check if a session already exists for this family
	var find_query = SupabaseQuery.new().from("sessions").select().eq("family_id", family_id)
	var find_task = supabase.database.query(find_query)
	await find_task.completed
	
	var data = {
		"family_id": family_id,
		"active_habit": habit_id,
		"theme_id": theme_id,
		"session_state": "ACTIVE",
		"duration_seconds": duration_secs,
		"cutoff_time": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system() + duration_secs), true),
		"updated_at": Time.get_datetime_string_from_system(true)
	}
	
	var final_task
	if find_task.data is Array and find_task.data.size() > 0:
		print("TinyHero: Session exists. Updating...")
		var session_id = find_task.data[0].id
		var update_query = SupabaseQuery.new().from("sessions").update(data).eq("id", session_id)
		final_task = supabase.database.query(update_query)
	else:
		print("TinyHero: Creating new session...")
		var insert_data = [data]
		var insert_query = SupabaseQuery.new().from("sessions").insert(insert_data)
		final_task = supabase.database.query(insert_query)
	
	await final_task.completed
	
	if final_task.error:
		print("TinyHero: start_session DB ERROR: ", final_task.error)
		return {}
		
	print("TinyHero: start_session success.")
	return final_task.data[0] if final_task.data is Array and final_task.data.size() > 0 else {}

func nudge_session(session_id: String):
	var data = {"nudge_timestamp": Time.get_datetime_string_from_system(true)}
	var query = SupabaseQuery.new().from("sessions").update(data).eq("id", session_id)
	var task = supabase.database.query(query)
	await task.completed

func approve_session(session_id: String):
	var data = {"session_state": "SUCCESS"}
	var query = SupabaseQuery.new().from("sessions").update(data).eq("id", session_id)
	var task = supabase.database.query(query)
	await task.completed

func end_session(session_id: String):
	print("TinyHero: DB RESET call for session: ", session_id)
	var data = {
		"session_state": "IDLE",
		"active_habit": "",
		"duration_seconds": 0,
		"cutoff_time": null,
		"updated_at": Time.get_datetime_string_from_system(true)
	}
	var query = SupabaseQuery.new().from("sessions").update(data).eq("id", session_id)
	var task = supabase.database.query(query)
	await task.completed
	if task.error:
		print("TinyHero: end_session DB ERROR: ", task.error)
	else:
		print("TinyHero: end_session (IDLE) DB Success.")
