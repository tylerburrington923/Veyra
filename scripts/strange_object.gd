extends StaticBody3D

var activated := false
@onready var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
@onready var light := get_node_or_null("OmniLight3D") as OmniLight3D

func _ready() -> void:
    _refresh_visual()

func interact() -> void:
    activated = not activated
    _refresh_visual()

func _refresh_visual() -> void:
    if mesh:
        var material := mesh.get_active_material(0)
        if material is StandardMaterial3D:
            material.emission_enabled = activated
            material.emission = Color(0.18, 0.58, 0.62, 1) if activated else Color(0.02, 0.05, 0.06, 1)
            material.emission_energy_multiplier = 2.2 if activated else 0.2
    if light:
        light.visible = activated
