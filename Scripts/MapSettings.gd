tool
extends Node2D

export var bounds = Rect2(0, 0, 1200, 1200)

func _ready():
	if !Engine.editor_hint:
		var camera = $"../Player/Camera2D"
		
		camera.limit_top = bounds.position.y
		camera.limit_left = bounds.position.x
		camera.limit_bottom = bounds.position.y + bounds.size.y
		camera.limit_right = bounds.position.x + bounds.size.x
		
		$Edge.position = bounds.position + Vector2(bounds.size.x/2, 0)
		$Edge.shape.extents.x = bounds.size.x/2
		
		$Edge2.position = bounds.position + Vector2(bounds.size.x, bounds.size.y/2)
		$Edge2.shape.extents.y = bounds.size.y/2

		$Edge3.position = bounds.position + Vector2(bounds.size.x/2, bounds.size.y)
		$Edge3.shape.extents.x = bounds.size.x/2
		
		$Edge4.position = bounds.position + Vector2(0, bounds.size.y/2)
		$Edge4.shape.extents.y = bounds.size.y/2

func _draw():
	if Engine.editor_hint: draw_rect(bounds, Color.blue, false)