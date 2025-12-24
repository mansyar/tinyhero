# character_controller.gd
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

enum State { IDLE, ACTIVE, NUDGE, SUCCESS, SLEEPY }

var current_state: State = State.IDLE

func _ready():
	anim_tree.active = true
	
	# Add audio player dynamically
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Give the animation tree a frame to initialize
	await get_tree().process_frame
	set_state(State.IDLE)
	print("TinyHero: Character Controller Ready at ", global_position)

func _process(_delta):
	# DEBUG: Force visibility if something is hiding it
	# Use is_equal_approx or a length check for robust scale detection
	if sprite.scale.length() < 0.1:
		sprite.scale = Vector2.ONE
	
	# Force visibility on both self and sprite
	if not visible:
		visible = true
	if not sprite.visible:
		sprite.visible = true
	
	# Force alpha to be visible
	if modulate.a < 0.1:
		modulate.a = 1.0

func set_state(new_state: State, habit_id: String = ""):
	current_state = new_state
	match current_state:
		State.IDLE:
			state_machine.travel("idle")
		State.ACTIVE:
			# Map habit IDs to specific animations
			match habit_id.to_lower():
				"bedtime":
					state_machine.travel("sleeping")
				"brushing_teeth", "brushing":
					state_machine.travel("brushing")
				"jump", "happy":
					state_machine.travel("happy")
				_:
					state_machine.travel("brushing") # default
		State.NUDGE:
			state_machine.travel("nudge")
		State.SUCCESS:
			state_machine.travel("happy")
			_play_sfx("res://assets/audio/shared/mission_success.wav")
		State.SLEEPY:
			state_machine.travel("sleeping")

func play_nudge():
	set_state(State.NUDGE)
	_play_sfx("res://assets/audio/dino/dino_roar_nudge.wav")
	
	# Script-based pop to avoid AnimationTree conflicts
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if get_viewport().get_mouse_position().distance_to(global_position) < 150: # Simple collision check
			play_fun_reaction()

func play_fun_reaction():
	# Small jump or sound
	_play_sfx("res://assets/audio/shared/ui_tap.wav")
	Input.vibrate_handheld(50) # Light tap feedback
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _play_sfx(path: String):
	if audio_player:
		var sfx = load(path)
		if sfx:
			audio_player.stream = sfx
			audio_player.play()
		else:
			print("TinyHero Error: Could not load SFX: ", path)

var audio_player: AudioStreamPlayer2D
