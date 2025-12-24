# child_mode/reward_reveal.gd
extends Control

signal reward_claimed

@onready var egg_sprite: TextureRect = %EggSprite
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var egg_closed_tex = load("res://assets/sprites/dino/egg_closed.png")
var egg_cracked_tex = load("res://assets/sprites/dino/egg_cracked.png")

func _ready():
	egg_sprite.texture = egg_closed_tex
	%ClaimButton.hide()
	%StickerLabel.hide()

func start_reveal():
	# 1. Shake the egg
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(egg_sprite, "position:x", 10.0, 0.05).as_relative()
		tween.tween_property(egg_sprite, "position:x", -10.0, 0.05).as_relative()
	tween.tween_property(egg_sprite, "position:x", 0.0, 0.05)
	await tween.finished
	
	# 2. Play crack sound and change texture
	if audio_player:
		var sfx = load("res://assets/audio/shared/egg_crack.wav")
		if sfx:
			audio_player.stream = sfx
			audio_player.play()
	
	egg_sprite.texture = egg_cracked_tex
	
	# Small celebrate bounce
	var bounce = create_tween()
	bounce.tween_property(egg_sprite, "scale", Vector2(1.2, 1.2), 0.1)
	bounce.tween_property(egg_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	await bounce.finished
	
	# 3. Show sticker and claim button
	%StickerLabel.text = "YOU GOT A NEW STICKER!"
	%StickerLabel.show()
	%ClaimButton.show()

func _on_claim_button_pressed():
	reward_claimed.emit()
	queue_free()
