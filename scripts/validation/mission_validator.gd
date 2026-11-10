class_name MissionValidator
extends RefCounted

# MissionValidator
# Evaluates spacecraft configurations against mission objectives and real-world aerospace constraints.
# Generates structured errors, warnings, and educational recommendations.

static func validate(spacecraft: SpacecraftConfig, mission: MissionConfig) -> ValidationResult:
	var result = ValidationResult.new()
	if spacecraft == null or mission == null:
		result.add_error("Invalid spacecraft or mission configuration.")
		return result

	var summary = ResourceCalculator.calculate_summary(spacecraft, mission)

	# 1. Structural Bus Check
	if not spacecraft.has_category("Structure"):
		result.add_error("Spacecraft lacks a primary structural bus or rover chassis.")

	# 2. Launch Mass Constraint
	if summary["total_mass"] > mission.mass_limit:
		var over_kg = summary["total_mass"] - mission.mass_limit
		result.add_error("Launch vehicle capacity exceeded by %.1f kg (Total: %.1f kg / Max: %.1f kg)." % [
			over_kg, summary["total_mass"], mission.mass_limit
		])
	elif summary["total_mass"] > (mission.mass_limit * 0.95):
		result.add_warning("Critical mass margin: Spacecraft utilizes >95% of launch payload limit.")

	# 3. Financial Budget Constraint
	if summary["total_cost"] > mission.budget_limit:
		var over_cost = summary["total_cost"] - mission.budget_limit
		result.add_error("Mission budget exceeded by $%.1fM (Cost: $%.1fM / Budget: $%.1fM)." % [
			over_cost, summary["total_cost"], mission.budget_limit
		])
	elif summary["total_cost"] > (mission.budget_limit * 0.92):
		result.add_warning("Tight budget reserve: Less than 8% contingency funding remaining.")

	# 4. Power Balance
	if spacecraft.total_power_generation <= 0.0:
		result.add_error("No electrical power generation installed (solar arrays or RTG required).")
	elif spacecraft.net_power < 0.0:
		result.add_error("Severe electrical deficit: Consumption (%.0fW) exceeds generation (%.0fW) by %.0fW." % [
			spacecraft.total_power_consumption, spacecraft.total_power_generation, abs(spacecraft.net_power)
		])
	elif summary["power_margin"] < 0.0:
		result.add_warning("Net power (%.0fW) is below mission target (%.0fW). Instruments may brown out." % [
			spacecraft.net_power, mission.power_requirement
		])

	# 5. Scientific Payload
	if not spacecraft.has_category("Instruments"):
		result.add_error("No scientific instruments installed. Mission cannot fulfill scientific return.")
	elif summary["total_science_value"] < mission.scientific_target:
		result.add_warning("Current instrument package yields %.0f science pts (Target: %.0f pts). Lower scientific rating expected." % [
			summary["total_science_value"], mission.scientific_target
		])

	# 6. Communications Capability
	if not spacecraft.has_category("Communications"):
		result.add_error("No communications antenna installed. Spacecraft cannot downlink data to Earth.")
	elif summary["comms_capacity"] < mission.communication_requirement:
		result.add_warning("Communications bandwidth (%.1f Mbps) below target (%.1f Mbps). Expect transmission queue bottlenecks." % [
			summary["comms_capacity"], mission.communication_requirement
		])

	# 7. Delta-V & Propulsion
	if mission.min_delta_v > 0.0:
		if summary["total_delta_v"] < (mission.min_delta_v * 0.7):
			result.add_error("Insufficient propulsion impulse: Spacecraft delta-v (%.0f m/s) cannot achieve destination capture (Needs %.0f m/s)." % [
				summary["total_delta_v"], mission.min_delta_v
			])
		elif summary["total_delta_v"] < mission.min_delta_v:
			result.add_warning("Marginal delta-v (%.0f m/s vs %.0f m/s required). High risk of orbital insertion failure." % [
				summary["total_delta_v"], mission.min_delta_v
			])

	# 8. Required Components Verification
	for req_id in mission.required_components:
		if not spacecraft.has_component(req_id):
			var comp_title = req_id
			var loop = Engine.get_main_loop()
			if loop is SceneTree and loop.root and loop.root.has_node("MissionManager"):
				var comp = loop.root.get_node("MissionManager").get_component(req_id)
				if comp: comp_title = comp.display_name
			result.add_error("Missing mandatory mission component: %s." % comp_title)

	# 9. Mission-Specific Rules
	match mission.destination:
		"Mars":
			if not spacecraft.has_component("land_mars_entry"):
				result.add_error("Mars mission missing atmospheric Entry Aeroshell & Heat Shield.")
			if not spacecraft.has_component("land_skycrane"):
				result.add_warning("Missing Sky Crane descent stage: Rover touchdown shock may damage mobility chassis.")
			if not spacecraft.has_component("power_rtg") and spacecraft.has_component("power_solar_fixed"):
				result.add_tip("Tip: Martian dust storms drastically degrade solar panels. MMRTG nuclear power provides reliable 24/7 energy.")
			if not spacecraft.has_component("comm_high_gain_dish"):
				result.add_warning("Deep-space Mars distance requires High-Gain Dish to communicate with Deep Space Network.")

		"Moon":
			if not spacecraft.has_component("land_lunar_legs"):
				result.add_error("Lunar mission missing Throttleable Descent Engines & Landing Gear.")
			if not spacecraft.has_component("power_li_battery"):
				result.add_warning("Lunar night and crater shadows last for days. Secondary Li-Ion battery buffer is strongly recommended.")

		"Earth":
			if not spacecraft.has_component("power_li_battery") and spacecraft.total_power_generation > 0.0:
				result.add_warning("LEO orbit spends 35 minutes per orbit in eclipse. Battery buffer recommended to avoid instrument reset.")

	# 10. Reliability Check
	if spacecraft.average_reliability < 0.70:
		result.add_warning("Overall mission reliability is only %.1f%%. High probability of subsystem failures during simulation." % [
			spacecraft.average_reliability * 100.0
		])

	return result
