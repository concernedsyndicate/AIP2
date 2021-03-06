tool
extends Sprite

enum TYPE{AMMO, HEALTH}
enum VARIANT{RAILH, ROCKA}

export(TYPE) var type = 0
export(VARIANT) var variant = 0

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
		TYPE.AMMO:
			match variant:
				VARIANT.RAILH:
					bot.character.railgun_ammo += 10
				VARIANT.ROCKA:
					bot.character.rocket_ammo += 15
		TYPE.HEALTH:
			match variant:
				VARIANT.RAILH:
					bot.character.health += 50
				VARIANT.ROCKA:
					bot.character.armor += 50
