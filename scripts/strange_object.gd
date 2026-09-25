extends StaticBody3D

var activated := false

func interact() -> void:
    activated = not activated
    print("The strange object hums. Activated: ", activated)

    var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh:
        var material := mesh.get_active_material(0)
        if material is StandardMaterial3D:
            material.emission_enabled = activated
            material.emission_energy_multiplier = 3.0 if activated else 0.0

    var light := get_node_or_null("OmniLight3D") as OmniLight3D
    if light:
        light.visible = activated
