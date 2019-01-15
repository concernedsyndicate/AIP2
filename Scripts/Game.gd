extends Node2D

onready var camera = $Camera
onready var bots = $Bots
onready var spawners = $BotSpawners

var bot_id = 0

var navigation = {}

var to_respawn = {}

func _ready():
	var cached = Autoload.load_json("res://MapCache.json")
	if cached:
		for pos in cached:
			var split = pos.split(", ")
			navigation[Vector2(int(split[0]), int(split[1]))] = true
		
		return
	
	var to_check = [$Bots/Bot.position]
	
	while !to_check.empty():
		var point = to_check.back()
		to_check.pop_back()
		
		navigation[point] = true
		
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				var p2 = point + Vector2(x * 64, y * 64)
				
				if !to_check.has(p2) and !navigation.has(p2) and is_valid(p2) and is_valid(p2 + Vector2(32, 32)) and is_valid(p2 + Vector2(-32, 32)) and is_valid(p2 + Vector2(32, -32)) and is_valid(p2 + Vector2(-32, -32)):
					to_check.append(p2)
	
	Autoload.save_json(navigation, "res://MapCache.json")

func is_valid(point):
	if $MapBoundary.bounds.has_point(point):
		for triangle in $Geometry.get_children():
			if inside_triangle(triangle.polygon[0].x, triangle.polygon[0].y, triangle.polygon[1].x, triangle.polygon[1].y,
					triangle.polygon[2].x, triangle.polygon[2].y, point.x, point.y):
				return false
		
		return true

const COLLISION_RADIUS = pow(30, 2)

func is_colliding(point, damage, attacker):
	if !is_valid(point):
		return true
	
	for bot in bots.get_children():
		if bot == attacker: continue
		
		if (point - bot.position).length_squared() < COLLISION_RADIUS:
			if !damage: return bot
			
			bot.character.damage(damage)
			
			if bot.character.health <= 0:
				bot.get_parent().call_deferred("remove_child", bot)
				if bot_id == bot.get_index() + 1: bot_id -= 1
				bot.character.health = 100
				bot.character.armor = 0
				bot.character.railgun_ammo = 0
				bot.character.rocket_ammo = 0
				
				bot.target = null
				bot.path.clear()
				bot.state.state = bot.state.EXPLORE
				
				to_respawn[bot] = 3
			
			return true

func triangle_area(x1, y1, x2, y2, x3, y3): 
    return abs((x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)) / 2.0)

func inside_triangle(x1, y1, x2, y2, x3, y3, x, y):
    var A = triangle_area(x1, y1, x2, y2, x3, y3) 
    var A1 = triangle_area(x, y, x2, y2, x3, y3) 
    var A2 = triangle_area (x1, y1, x, y, x3, y3) 
    var A3 = triangle_area (x1, y1, x2, y2, x, y) 
	
    if A == A1 + A2 + A3: return true

func _process(delta):
	if bot_id > 0:
		camera.zoom = Vector2(1, 1)
		camera.position += (bots.get_child(bot_id-1).position - camera.position)/10
	else:
		camera.zoom = Vector2(2.5, 2.5)
		var average = Vector2()
		for bot in bots.get_children():
			average += bot.position
		
		camera.position += (average/bots.get_child_count() - camera.position)/10
	
	for respawn in to_respawn:
		to_respawn[respawn] -= delta
		if to_respawn[respawn] <= 0:
			var pos = spawners.get_child(randi() % spawners.get_child_count()).position
			
			respawn.position = pos
			bots.add_child(respawn)
			to_respawn.erase(respawn)

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		bot_id = (bot_id + 1) % (bots.get_child_count()+1)

func _draw():
	for point in navigation:
		draw_circle(point, 2, Color.white)