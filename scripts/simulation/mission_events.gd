class_name MissionEvents
extends RefCounted

# MissionEvents
# Generates authentic, NASA-style mission events and telemetry alerts
# based on spacecraft configuration and simulation conditions.

static func create_event(day: float, phase: String, title: String, message: String, severity: String = "info") -> Dictionary:
	return {
		"day": snapped(day, 0.1),
		"phase": phase,
		"title": title,
		"message": message,
		"severity": severity # "info", "success", "warning", "critical"
	}
