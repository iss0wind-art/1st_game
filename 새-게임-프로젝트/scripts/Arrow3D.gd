extends CharacterBody3D

var speed = 25.0
var damage = 10.0
var team = 0
var target_pos = Vector3.ZERO
var start_pos = Vector3.ZERO
var gravity = 9.8
var velocity_vec = Vector3.ZERO

func setup(start, target, t, dmg, _shooter_pos):
	var distance = start.distance_to(target)
	# [Phase 17: 3D 명중률 & 퍼짐] 거리에 비례하여 타겟 위치 무작위 오프셋
	var spread = distance * distance * 0.005 # 3D 스케일에 맞게 조정
	var random_offset = Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	)
	
	global_position = start
	target_pos = target + random_offset
	team = t
	damage = dmg
	start_pos = start
	
	# 탄도학 계산 (물물리적 포물선)
	var diff = target_pos - start_pos
	var horizontal_diff = Vector2(diff.x, diff.z)
	var dist = horizontal_diff.length()
	var time = dist / speed
	
	var vx = horizontal_diff.x / time
	var vz = horizontal_diff.y / time
	var vy = (diff.y / time) + (0.5 * gravity * time)
	
	velocity_vec = Vector3(vx, vy, vz)
	
	# 화살 방향 회전
	if velocity_vec.length() > 0.1:
		look_at(global_position + velocity_vec)

func _physics_process(delta):
	velocity_vec.y -= gravity * delta
	var collision = move_and_collide(velocity_vec * delta)
	
	if velocity_vec.length() > 0.1:
		look_at(global_position + velocity_vec)
		
	if collision:
		var collider = collision.get_collider()
		if collider.has_method("take_damage") and collider.get("team") != team:
			collider.take_damage(damage, collision.get_position())
		queue_free()
		
	# 낙하 처리 (바닥 아래로 내려가면 제거)
	if global_position.y < -5:
		queue_free()
