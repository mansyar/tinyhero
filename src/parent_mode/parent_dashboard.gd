# parent_mode/parent_dashboard.gd
extends Control

@onready var status_label: Label = %StatusLabel

func _ready():
	status_label.text = "Logged in as Commander"
	%FamilyIDLabel.text = "Family ID: " + GameManager.family_id

func _on_link_device_pressed():
	get_tree().change_scene_to_file("res://scenes/parent_mode/link_tablet.tscn")

func _on_switch_mode_pressed():
	# Use the Parent Gate before switching to child? 
	# Actually, Parent -> Child is easy. Child -> Parent needs the gate.
	GameManager.switch_to_child_mode()

func _on_logout_pressed():
	# Simple logout logic
	GameManager.family_id = ""
	GameManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
