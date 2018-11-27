extends Node2D

onready var camera = $Camera
onready var bots = $Bots

var bot_id = 0

var navigation = []

func _ready():
	var to_check = [$Bots/Bot.position]
	
	while !to_check.empty():
		var point = to_check.back()
		to_check.pop_back()
		
		navigation.append(point)
		
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				var p2 = point + Vector2(x * 64, y * 64)
				
				if !to_check.has(p2) and !navigation.has(p2) and is_valid(p2):
					to_check.append(p2)

func is_valid(point):
	return $MapBoundary.bounds.has_point(point) and $Walls.get_cellv(point / Vector2(128, 128)) == -1 and $Walls.get_cellv((point - Vector2(64, 64)) / Vector2(128, 128)) == -1

func _process(delta):
	camera.position = bots.get_child(bot_id).position

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		bot_id = (bot_id + 1) % bots.get_child_count()

func _draw():
	for point in navigation:
		draw_circle(point, 2, Color.white)