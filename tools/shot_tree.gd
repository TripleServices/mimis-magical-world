extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var root_node: Node = scene.instantiate()
	root.add_child(root_node)
	await process_frame
	await process_frame
	root_node.set("test_mode", true)
	var mimi = root_node.get("mimi")
	mimi.global_position = Vector3(-0.8, 0.3, 13.2)
	for i in range(40):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tools/shots/shot-tree.png")
	print("TREE SHOT SAVED")
	quit()
