extends Node2D

onready var camera = $Camera
onready var bots = $Bots

var bot_id = 0

func _process(delta):
	camera.position = bots.get_child(bot_id).position

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		bot_id = (bot_id + 1) % bots.get_child_count()