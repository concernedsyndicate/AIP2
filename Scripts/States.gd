extends Node

onready var character = $"../Character"
onready var navigation = $"../../..".navigation
onready var bot = get_parent()

enum {EXPLORE, ATTACK, FLEE, RESTOCK, HEAL}
var state = EXPLORE

var thread

func process(delta):
	match state:
		EXPLORE:
			if !bot.target:
				bot.target = navigation.keys()[randi() % navigation.size()]
#				print(self.name, " going to ", bot.target)
				
				thread = Thread.new()
				thread.start(bot, "astar", bot.target)
			
			if randf() < 0.01:
				bot.target = null
			
			if randf() < 0.01:
				bot.target = null
				state = ATTACK
			
			if character.health < 20:
				state = HEAL
			
			if character.rocket_ammo < 2 and character.railgun_ammo < 2:
				state = RESTOCK
		HEAL:
			if !bot.target:
				var healths = get_tree().get_nodes_in_group("health")
				bot.target = bot.closest_v(healths[randi() % healths.size()].position)
#				print(self.name, " going to ", bot.target)
				
				thread = Thread.new()
				thread.start(bot, "astar", bot.target)
				
			if character.health > 80:
				state = EXPLORE
		RESTOCK:
			if !bot.target:
				var ammos = get_tree().get_nodes_in_group("ammo")
				bot.target = bot.closest_v(ammos[randi() % ammos.size()].position)
#				print(self.name, " going to ", bot.target)
				
				thread = Thread.new()
				thread.start(bot, "astar", bot.target)
			
			if character.rocket_ammo > 2 or character.railgun_ammo > 2:
				state = EXPLORE
		ATTACK:
			var bot2 = bot.get_closest_bot()
			
			if character.railgun_cooldown <= 0 and character.railgun_ammo > 0:
				bot.shoot_railgun(bot2)
			elif character.rocket_cooldown <= 0 and character.rocket_ammo > 0:
				bot.shoot_missile(bot2)
			
			state = EXPLORE