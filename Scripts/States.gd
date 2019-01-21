extends Node

onready var character = $"../Character"
onready var navigation = $"../../..".navigation
onready var bot = get_parent()

enum {EXPLORE, ATTACK, FLEE, RESTOCK, HEAL}
var state = EXPLORE

func process(delta):
	match state:
		EXPLORE:
			explore()
		HEAL:
			heal()
		RESTOCK:
			restock()
		ATTACK:
			attack()
		FLEE:
			flee()
		
func explore():
	if !bot.target:
		bot.target = navigation.keys()[randi() % navigation.size()]
#				print(self.name, " going to ", bot.target)
		
		bot.start_astar()
	
	if randf() < 0.01:
		bot.target = null
	
	var closest = can_attack()
	if closest:
		bot.target = closest
		bot.path.clear()
		state = ATTACK
	
	if character.health < 20:
		bot.target = null
		state = HEAL
	
	if character.rocket_ammo == 0 and character.railgun_ammo == 0:
		bot.target = null
		state = RESTOCK

func heal():
	if !bot.target:
		var healths = get_tree().get_nodes_in_group("health")
		bot.target = bot.closest_v(healths[randi() % healths.size()].position)
#				print(self.name, " going to ", bot.target)
		
		bot.start_astar()
		
	if character.health > 80:
		state = EXPLORE

func restock():
	if !bot.target:
		var ammos = get_tree().get_nodes_in_group("ammo")
		bot.target = bot.closest_v(ammos[randi() % ammos.size()].position)
#				print(self.name, " going to ", bot.target)
		
		bot.start_astar()
	
	if character.rocket_ammo > 2 or character.railgun_ammo > 2:
		state = EXPLORE

func attack():
	if character.railgun_cooldown <= 0 and character.railgun_ammo > 0:
		bot.shoot_railgun(bot.target)
	elif character.rocket_cooldown <= 0 and character.rocket_ammo > 0:
		bot.shoot_missile(bot.target)
	
	bot.target = null
	state = EXPLORE

func flee():
	
	state = EXPLORE

func can_attack():
	var closest = bot.get_closest_bot()
	if ((character.railgun_ammo >= 0 and character.railgun_cooldown) or (character.rocket_ammo >= 0 and character.rocket_cooldown <= 0)) and closest and bot.can_reach(closest):
		return closest