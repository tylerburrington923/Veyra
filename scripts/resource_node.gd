extends StaticBody3D
class_name VeyraResourceNode

@export_enum("Stone", "Wood", "Metal", "Echo-Stone", "Vitreous Lux") var resource_type := "Stone"
@export var amount := 1

var depleted := false

func interact() -> void:
    if depleted:
        return

    var player := get_tree().get_first_node_in_group("local_player")
    if player and player.has_method("add_resource"):
        player.add_resource(resource_type, amount)
        depleted = true
        visible = false
        collision_layer = 0
        collision_mask = 0
        print("Gathered ", amount, " ", resource_type)
