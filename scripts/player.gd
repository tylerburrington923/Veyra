extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.003

var look_pitch := 0.0
var touch_start := {}
var move_input := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1
var joystick_center := Vector2.ZERO

@onready var controls := get_node_or_null("MobileControls")
@onready var joystick_base := get_node_or_null("MobileControls/JoystickBase")
@onready var joystick_knob := get_node_or_null("MobileControls/JoystickBase/JoystickKnob")

func _ready() -> void:
    add_to_group("local_player")
    if joystick_base:
        joystick_base.visible = false
    if joystick_knob:
        joystick_knob.visible = false

func _physics_process(delta: float) -> void:
    var input := move_input
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
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.48:
                move_touch_id = event.index
                touch_start[event.index] = event.position
                joystick_center = event.position
                move_input = Vector2.ZERO
                _show_joystick(event.position)
            else:
                look_touch_id = event.index
                touch_start[event.index] = event.position
        else:
            if event.index == move_touch_id:
                move_touch_id = -1
                move_input = Vector2.ZERO
                _hide_joystick()
            if event.index == look_touch_id:
                look_touch_id = -1
            touch_start.erase(event.index)

    elif event is InputEventScreenDrag:
        if event.index == move_touch_id:
            var origin: Vector2 = touch_start.get(event.index, event.position)
            var delta: Vector2 = event.position - origin
            move_input = delta.limit_length(100.0) / 100.0
            move_input.y = -move_input.y
            _update_joystick(event.position)
        elif event.index == look_touch_id:
            rotate_y(-event.relative.x * mouse_sensitivity * 2.0)
            look_pitch = clamp(look_pitch - event.relative.y * mouse_sensitivity * 2.0, deg_to_rad(-75.0), deg_to_rad(70.0))
            var camera := get_node_or_null("Camera3D") as Camera3D
            if camera:
                camera.rotation.x = look_pitch
    elif event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)

func _show_joystick(pos: Vector2) -> void:
    if joystick_base:
        joystick_base.position = pos
        joystick_base.visible = true
    if joystick_knob:
        joystick_knob.position = pos
        joystick_knob.visible = true

func _update_joystick(pos: Vector2) -> void:
    if not joystick_knob:
        return
    var offset := (pos - joystick_center).limit_length(100.0)
    joystick_knob.position = joystick_center + offset

func _hide_joystick() -> void:
    if joystick_base:
        joystick_base.visible = false
    if joystick_knob:
        joystick_knob.visible = false


func add_resource(resource_type: String, amount: int) -> void:
    var inventory_node := get_node_or_null("Inventory")
    if inventory_node and inventory_node.has_method("add_resource"):
        inventory_node.add_resource(resource_type, amount)
