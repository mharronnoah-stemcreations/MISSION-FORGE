class_name ValidationResult
extends RefCounted

var is_valid: bool = true
var errors: Array[String] = []
var warnings: Array[String] = []
var tips: Array[String] = []

func add_error(msg: String) -> void:
	errors.append(msg)
	is_valid = false

func add_warning(msg: String) -> void:
	warnings.append(msg)

func add_tip(msg: String) -> void:
	tips.append(msg)

func get_summary_text() -> String:
	if is_valid and warnings.is_empty():
		return "Spacecraft configuration is nominal and fully validated for launch."
	elif is_valid and not warnings.is_empty():
		return "Configuration is launchable with %d operational warning(s)." % warnings.size()
	else:
		return "Launch blocked: %d critical engineering constraint violation(s)." % errors.size()
