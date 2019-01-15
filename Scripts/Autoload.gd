extends Node

func _ready():
	randomize()

func load_json(path):
	var file = File.new()
	if file.open(path, file.READ) != OK: return
	return parse_json(file.get_as_text())

func save_json(dict, path):
	var file = File.new()
	if file.open(path, file.WRITE) != OK: return
	file.store_string(JSON.print(dict))