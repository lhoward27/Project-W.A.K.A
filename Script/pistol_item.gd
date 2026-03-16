extends Area3D

@onready var pistol: Node3D = $Pistol

func _on_body_entered(body: Node3D) -> void:
	var item_node = body.get_node("PlayerModel/Armature/Skeleton3D/RightHandAttachment/Items")
	var items = item_node.get_children()
	for item in items:
		if item.name == "Pistol": return
	if item_node.get_child_count() < 3:
		var pistol_node = pistol.duplicate()
		item_node.add_child(pistol_node)
		self.queue_free()
