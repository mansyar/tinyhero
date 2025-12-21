# core/auth/google_oauth.gd
extends Node
class_name GoogleOAuth


signal auth_completed(user: Dictionary)
signal auth_failed(error: String)

func start_google_login():
	if not SupabaseClient.supabase or not SupabaseClient.supabase.auth:
		auth_failed.emit("Supabase client not initialized")
		return
		
	# Supabase Auth OAuth URL: [URL]/auth/v1/authorize?provider=[PROVIDER]
	# Supabase Auth OAuth URL
	var redirect_uri = "http://localhost"
	var auth_url = SupabaseClient.SUPABASE_URL + "/auth/v1/authorize?provider=google&redirect_to=" + redirect_uri


	
	print("TinyHero: Opening OAuth URL: ", auth_url)
	# Open in external browser (redirects back via deep link)
	OS.shell_open(auth_url)


func _ready():
	add_to_group("oauth_handlers")

func handle_deep_link(url: String):
	# Called when app receives deep link callback
	# URL format: com.tinyhero.app://auth-callback#access_token=...
	print("TinyHero: Received deep link: ", url)
	var token = _extract_token(url)
	
	if token != "":
		# Set the token in the plugin first so the user() call uses it
		SupabaseClient.supabase.auth.set_auth(token)
		
		var task = SupabaseClient.supabase.auth.user(token)
		await task.completed
		
		if task.user:
			# Manually attach the token back to the user object since /user endpoint doesn't return it
			task.user.access_token = token
			SupabaseClient.supabase.auth.client = task.user
			
			print("TinyHero: Auth successful for: ", task.user.email)
			auth_completed.emit(task.user.dict)
		else:
			var err = "Fetch user failed"
			if task.error:
				err += ": " + str(task.error)
			auth_failed.emit(err)
	else:
		auth_failed.emit("Authentication failed (no token in URL)")



func _extract_token(url: String) -> String:
	# Try Fragment first (#access_token=)
	if "#" in url:
		var fragment = url.split("#")[1]
		for pair in fragment.split("&"):
			if pair.begins_with("access_token="):
				return pair.split("=")[1]
	
	# Try Query second (?access_token= or ?code=)
	if "?" in url:
		var query = url.split("?")[1]
		for pair in query.split("&"):
			if pair.begins_with("access_token="):
				return pair.split("=")[1]
			if pair.begins_with("code="):
				print("TinyHero: PKCE code detected. This requires a different exchange flow. Switch Supabase to 'Implicit' flow.")
	
	print("TinyHero: No access_token found in URL: ", url)
	return ""

