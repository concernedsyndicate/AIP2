tool
extends Sprite

enum TYPE{AMMO, HEALTH}
enum VARIANT{RAILH, ROCKA}

export(TYPE) var type = AMMO
export(VARIANT) var variant = RAILH

func _process(delta):
	if Engine.editor_hint:
		frame = int(variant)

func collect(bot):
	var respawner = preload("res://Nodes/Respawner.tscn").instance()
	respawner.collectible = self
	respawner.position = position
	get_parent().add_child(respawner)
	get_parent().call_deferred("remove_child", self)
	
	match type:
		AMMO:
			match variant:
				RAILH:
					bot.character.railgun_ammo += 10
				ROCKA:
					bot.character.rocket_ammo += 15
		HEALTH:
			match variant:
				RAILH:
					bot.character.health += 50
				ROCKA:
					bot.character.armor += 50
