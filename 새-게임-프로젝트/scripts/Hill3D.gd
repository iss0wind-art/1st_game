extends Area3D

func _on_body_entered(body):
	if body.has_method("set_elevation"):
		body.set_elevation(1)
		print("Unit entered 3D Hill: ", body.name)

func _on_body_exited(body):
	if body.has_method("set_elevation"):
		body.set_elevation(0)
