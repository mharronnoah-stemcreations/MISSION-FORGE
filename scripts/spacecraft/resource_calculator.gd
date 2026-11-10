class_name ResourceCalculator
extends RefCounted

# ResourceCalculator
# Calculates real-time physical, electrical, telemetry, and financial totals
# for any given spacecraft configuration against mission constraints.

static func calculate_summary(spacecraft: SpacecraftConfig, mission: MissionConfig = null) -> Dictionary:
	if spacecraft == null:
		return {}

	spacecraft.recalculate()

	var summary = {
		"total_mass": spacecraft.total_mass,
		"mass_limit": 0.0,
		"mass_ratio": 0.0, # 0.0 to 1.0+
		"mass_margin": 0.0,
		
		"power_generation": spacecraft.total_power_generation,
		"power_consumption": spacecraft.total_power_consumption,
		"net_power": spacecraft.net_power,
		"power_requirement": 0.0,
		"power_margin": 0.0,
		
		"total_cost": spacecraft.total_cost,
		"budget_limit": 0.0,
		"cost_margin": 0.0,
		"cost_ratio": 0.0,
		
		"data_generation": spacecraft.total_data_generation, # MB/day
		"comms_capacity": spacecraft.comms_capacity,         # Mbps
		"comms_requirement": 0.0,
		"data_buffer_adequate": true,
		
		"total_delta_v": spacecraft.total_delta_v,
		"delta_v_requirement": 0.0,
		"delta_v_margin": 0.0,
		
		"average_reliability": spacecraft.average_reliability,
		"reliability_percent": snapped(spacecraft.average_reliability * 100.0, 0.1),
		"total_science_value": spacecraft.total_science_value,
		"science_target": 0.0,
		"component_count": spacecraft.selected_components.size()
	}

	if mission != null:
		summary["mass_limit"] = mission.mass_limit
		summary["mass_ratio"] = spacecraft.total_mass / max(1.0, mission.mass_limit)
		summary["mass_margin"] = mission.mass_limit - spacecraft.total_mass
		
		summary["power_requirement"] = mission.power_requirement
		summary["power_margin"] = spacecraft.net_power - mission.power_requirement
		
		summary["budget_limit"] = mission.budget_limit
		summary["cost_margin"] = mission.budget_limit - spacecraft.total_cost
		summary["cost_ratio"] = spacecraft.total_cost / max(1.0, mission.budget_limit)
		
		summary["comms_requirement"] = mission.communication_requirement
		summary["delta_v_requirement"] = mission.min_delta_v
		summary["delta_v_margin"] = spacecraft.total_delta_v - mission.min_delta_v
		summary["science_target"] = mission.scientific_target

	return summary
