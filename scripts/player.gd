extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 18.0

func _physics_process(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_2d.x, 0.0, input_2d.y)
	
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	
	move_and_slide()
