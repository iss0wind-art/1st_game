extends Area3D

func _on_body_entered(body):
	if body.get("is_in_water") != null:
		body.is_in_water = true
		print("Unit entered 3D River: ", body.name)

func _on_body_exited(body):
	if body.get("is_in_water") != null:
		body.is_in_water = false
