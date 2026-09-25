extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.003
@export var joystick_radius := 70.0
@export var joystick_deadzone := 0.12

var look_pitch := 0.0
var touch_start := {}
var move_input := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1
var joystick_center := Vector2.ZERO

@onready var controls := get_node_or_null("MobileControls")
@onready var joystick_base := get_node_or_null("MobileControls/JoystickBase")
@onready var joystick_knob := get_node_or_null("MobileControls/JoystickBase/JoystickKnob")
@onready var interact_button := get_node_or_null("MobileControls/InteractButton")

func _ready() -> void:
    add_to_group("local_player")
    if interact_button:
        interact_button.pressed.connect(_on_interact_pressed)
    _hide_joystick()

func _physics_process(delta: float) -> void:
    var input := move_input
    if input.length() < 0.01:
        input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    if input.length() > 1.0:
        input = input.normalized()

    # The joystick's Y axis is already converted so up on the screen means forward.
    var direction := transform.basis * Vector3(input.x, 0.0, input.y)
    direction.y = 0.0

    if direction.length_squared() > 0.001:
        direction = direction.normalized()
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    move_and_slide()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and move_touch_id == -1:
                move_touch_id = event.index
                touch_start[event.index] = event.position
                joystick_center = event.position
                move_input = Vector2.ZERO
                _show_joystick(event.position)
            elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.48 and look_touch_id == -1:
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
            var distance := delta.length()

            if distance > joystick_deadzone * joystick_radius:
                var clamped := delta.limit_length(joystick_radius)
                move_input = Vector2(clamped.x / joystick_radius, -clamped.y / joystick_radius)
            else:
                move_input = Vector2.ZERO

            _update_joystick(event.position)

        elif event.index == look_touch_id:
            rotate_y(-event.relative.x * mouse_sensitivity * 2.0)
            look_pitch = clamp(
                look_pitch - event.relative.y * mouse_sensitivity * 2.0,
                deg_to_rad(-75.0),
                deg_to_rad(70.0)
            )
            var camera := get_node_or_null("Camera3D") as Camera3D
            if camera:
                camera.rotation.x = look_pitch

    elif event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)

func _show_joystick(pos: Vector2) -> void:
    if not joystick_base or not joystick_knob:
        return

    # Controls use top-left coordinates. Center the base exactly under the finger.
    var base_size := joystick_base.size
    joystick_base.position = pos - base_size * 0.5
    joystick_base.visible = true

    # The knob is a child of the base, so its position must be local to the base.
    joystick_knob.position = (base_size - joystick_knob.size) * 0.5
    joystick_knob.visible = true

func _update_joystick(pos: Vector2) -> void:
    if not joystick_base or not joystick_knob:
        return

    var base_size := joystick_base.size
    var base_center := joystick_base.position + base_size * 0.5
    var offset := (pos - base_center).limit_length(joystick_radius)

    var knob_center := base_size * 0.5 + offset
    joystick_knob.position = knob_center - joystick_knob.size * 0.5

func _hide_joystick() -> void:
    if joystick_base:
        joystick_base.visible = false
    if joystick_knob:
        joystick_knob.visible = false

func add_resource(resource_type: String, amount: int) -> void:
    var inventory_node := get_node_or_null("Inventory")
    if inventory_node and inventory_node.has_method("add_resource"):
        inventory_node.add_resource(resource_type, amount)

func _on_interact_pressed() -> void:
    var ray := get_node_or_null("Camera3D/InteractionRay")
    if ray and ray.has_method("try_interact"):
        ray.try_interact()
