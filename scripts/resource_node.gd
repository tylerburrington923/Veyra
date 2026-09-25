extends StaticBody3D
class_name VeyraResourceNode

@export_enum("Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux") var resource_type := "Stone"
@export var amount := 1

var depleted := false
var respawn_time := 0.0
@export var respawn_seconds := 45.0

func _ready() -> void:
    add_to_group("resource_node")

func _process(delta: float) -> void:
    if not depleted:
        return
    respawn_time -= delta
    if respawn_time <= 0.0:
        _restore()

func interact() -> void:
    if depleted:
        return

    var player := get_tree().get_first_node_in_group("local_player")
    if player and player.has_method("add_resource"):
        player.add_resource(resource_type, amount)
        depleted = true
        respawn_time = maxf(1.0, respawn_seconds)
        visible = false
        collision_layer = 0
        collision_mask = 0

func _restore() -> void:
    depleted = false
    respawn_time = 0.0
    visible = true
    collision_layer = 1
    collision_mask = 1
