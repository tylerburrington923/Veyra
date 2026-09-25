extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.003

var look_pitch := 0.0

func _physics_process(delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    # Movement is relative to the direction the player is facing.
    var direction := (transform.basis * Vector3(input.x, 0.0, input.y))
    direction.y = 0.0
    direction = direction.normalized()

    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        rotate_y(-drag.relative.x * mouse_sensitivity)
        look_pitch = clamp(look_pitch - drag.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
        var camera := get_node_or_null("Camera3D") as Camera3D
        if camera:
            camera.rotation.x = look_pitch
    elif event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)
        var camera := get_node_or_null("Camera3D") as Camera3D
        if camera:
            camera.rotation.x = look_pitch
