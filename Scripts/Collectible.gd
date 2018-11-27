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
	queue_free()
	
	match type:
		AMMO:
			match variant:
				RAILH:
					bot.railgun_ammo += 10
				ROCKA:
					bot.rocket_ammo += 15
		HEALTH:
			match variant:
				RAILH:
					bot.health += 50
				ROCKA:
					bot.armor += 50
