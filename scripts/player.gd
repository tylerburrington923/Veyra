extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.003

var look_pitch := 0.0
var touch_start := {}
var move_input := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1

func _physics_process(delta: float) -> void:
    var input := move_input

    # Keep keyboard support for desktop testing.
    if input.length() < 0.01:
        input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    var direction := transform.basis * Vector3(input.x, 0.0, input.y)
    direction.y = 0.0
    direction = direction.normalized()

    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.45:
                move_touch_id = event.index
                touch_start[event.index] = event.position
                move_input = Vector2.ZERO
            else:
                look_touch_id = event.index
                touch_start[event.index] = event.position
        else:
            if event.index == move_touch_id:
                move_touch_id = -1
                move_input = Vector2.ZERO
            if event.index == look_touch_id:
                look_touch_id = -1
            touch_start.erase(event.index)

    elif event is InputEventScreenDrag:
        if event.index == move_touch_id:
            var origin: Vector2 = touch_start.get(event.index, event.position)
            var delta: Vector2 = event.position - origin
            move_input = delta.limit_length(100.0) / 100.0
            move_input.y = -move_input.y

        elif event.index == look_touch_id:
            rotate_y(-event.relative.x * mouse_sensitivity * 2.0)
            look_pitch = clamp(look_pitch - event.relative.y * mouse_sensitivity * 2.0, deg_to_rad(-75.0), deg_to_rad(70.0))
            var camera := get_node_or_null("Camera3D") as Camera3D
            if camera:
                camera.rotation.x = look_pitch

    elif event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)
