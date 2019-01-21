extends Area2D

onready var starting_position = position
onready var bounds = $"../../MapBoundary".bounds
onready var navigation = $"../..".navigation
onready var character = $Character
onready var state = $State
onready var game = $"../.."

const MAX_SPEED = 300
const RADIUS = 32

var velocity = Vector2(0,0)

var target
var thread

var arrived_at_path_end = false

var color

func _ready():
	rotation = randf() * PI*2
	color = [Color.red, Color.blue, Color.green, Color.yellow][get_index()]

func _process(delta):
	state.process(delta)
	
	velocity = (velocity + next_step(delta)).clamped(MAX_SPEED)
	
	position += velocity * delta
	call_deferred("declip")
	rotation = velocity.angle()
	
	update()

func next_step(delta):
#	return wander()
	if arrived_at_path_end:
		arrived_at_path_end = false
		target = null
	
	return follow_path()

func seek(target_position):
	var desired_velocity = (target_position - position).normalized() * MAX_SPEED
	return desired_velocity - velocity

func declip():
	if !get_tree(): return
	
	var move = Vector2()
	
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if (obstacle.position - position).length() <= obstacle.radius + RADIUS:
			move -= (obstacle.position - position).normalized() * ((obstacle.radius + RADIUS) - (obstacle.position - position).length())
	
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster != self and (monster.position - position).length() <= monster.RADIUS + RADIUS:
#			monster.position += (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
			move -= (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
	
	position += move

var path = []

func astar(target, source = closest_v(position)): # source = closest_v(position) # wez najblizszy pkt, a przy liczeniu sceizki go wyrzuc by sie nie cofac
	if !visible: return ###debug
	var W = navigation.duplicate()
	
	var to_visit = []
	var visited = {}
	
	to_visit.append({pos = source, G = 0, H = abs(source.x - target.x) + abs(source.y - target.y), previous = null})
	
	var cur
	while !to_visit.empty():
		cur = to_visit[0]
		for p in to_visit:
			if p.G + p.H < cur.G + cur.H:
				cur = p
		
		if cur.pos == target: break
		
		to_visit.erase(cur)
		
		add_astar_neigbor(cur, target, Vector2(64, 0), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, 0), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(0, 64), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(0, -64), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(64, 64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(64, -64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, -64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, 64), 14, to_visit, visited)
	
	path.clear()
	while cur.previous:
		path.append(cur.pos)
		cur = cur.previous
	path.invert()
	
	$Path.path = path
	$Path.update()

func add_astar_neigbor(point, target, add_pos, add_g, to_visit, visited):
	var p = point.pos + add_pos
	
	if p in navigation and not p in visited:
		visited[p]= true
		to_visit.append({pos = p, G = point.G + add_g, H = abs(p.x - target.x) + abs(p.y - target.y), previous = point})

onready var follow_target = position

const FOLLOW_PATH_TOLERANCE = pow(3, 2)

func follow_path():
	if !path.empty():
		follow_target = path.front()
		if (position - path.front()).length_squared() <= FOLLOW_PATH_TOLERANCE:
			path.pop_front()
			if path.empty():
				arrived_at_path_end = true
				return seek(position)
			
			follow_target = path.front()
		
		return seek(follow_target)
	else:
		return seek(position)

func closest_v(pos):
	var base = [pos.snapped(Vector2(64,64))]
	base.append(base[0] + Vector2(64,0))
	base.append(base[0] + Vector2(0,64))
	base.append(base[0] + Vector2(64,64))
	
	var valid = []
	
	for vec in navigation:
		if vec in base:
			valid.append(vec)
	
	for vec in base:
		if vec in valid: return vec
	
	printerr("Bot poza nawigacją (wtf co on tam robi)")

func get_closest_bot():
	var min_dist = INF
	var min_bot
	
	for bot in game.bots.get_children():
		if bot != self:
			var dist = (bot.position - position).length_squared()
			if dist < min_dist:
				min_dist = dist
				min_bot = bot
	
	return min_bot

func shoot_railgun(at):
	var bullet = preload("res://Nodes/RailgunBullet.tscn").instance()
	character.railgun_cooldown = 2
	character.railgun_ammo -= 1
	rotation = (at.position - position).angle()
	
	bullet.position = position
	bullet.rotation = rotation
	bullet.attacker = self
	bullet.modulate = color

	$"../..".add_child(bullet)

func shoot_missile(at):
	var bullet = preload("res://Nodes/Missile.tscn").instance()
	character.rocket_cooldown = 0.5
	character.rocket_ammo -= 1
	rotation = (at.position - position).angle()
	
	bullet.position = position
	bullet.rotation = rotation
	bullet.attacker = self
	bullet.modulate = color

	$"../..".add_child(bullet)

func can_reach(at):
	var pos = position
	var rot = (at.position - position).angle()
	
	for i in 1000:
		pos += Vector2(cos(rot), sin(rot)) * 10
		
		var col = game.is_colliding(pos, null, self)
		if col and typeof(col) != TYPE_BOOL and col == at:
			return true
		elif col and typeof(col) == TYPE_BOOL:
			return false
	
	return false

func start_astar():
	if thread:
		thread.wait_to_finish()
	
	thread = Thread.new()
	thread.start(self, "astar", target)