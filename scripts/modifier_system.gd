class_name ModifierSystem
extends RefCounted

static func calculate_modified_value(base_value: float, active_modifiers: Array[ModifierDefinition]) -> float:
	var additive := 0.0
	var multiplier := 1.0
	var override_value := base_value
	var has_override := false
	for modifier in active_modifiers:
		if modifier == null or not modifier.is_valid():
			continue
		match modifier.type:
			ModifierDefinition.ModifierType.ADDITIVE:
				additive += modifier.value
			ModifierDefinition.ModifierType.MULTIPLICATIVE:
				multiplier *= modifier.value
			ModifierDefinition.ModifierType.OVERRIDE:
				override_value = modifier.value
				has_override = true
	if has_override:
		return override_value
	return (base_value + additive) * multiplier
