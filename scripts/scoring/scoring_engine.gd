class_name ScoringEngine
extends RefCounted

# ScoringEngine
# Implements transparent scoring according to PRD Section 15.5:
# S = 0.30*A + 0.25*R + 0.20*E + 0.15*B + 0.10*C
# Accompanied by detailed engineering breakdown and recommendations.

static func calculate_score(
	spacecraft: SpacecraftConfig,
	mission: MissionConfig,
	completed_phases: int,
	total_phases: int,
	data_transmitted: float,
	data_target: float,
	simulation_events: Array
) -> MissionResult:
	var result = MissionResult.new()
	result.mission_id = mission.mission_id
	result.mission_name = mission.mission_name
	result.destination = mission.destination
	result.spacecraft_name = spacecraft.spacecraft_name
	result.reached_phase = completed_phases
	result.total_mass = spacecraft.total_mass
	result.total_cost = spacecraft.total_cost
	result.data_transmitted = data_transmitted
	result.data_target = data_target
	result.mission_completed = (completed_phases >= total_phases)

	# 1. Scientific Achievement (A) - Weight 30%
	var data_ratio = clamp(data_transmitted / max(1.0, data_target), 0.0, 1.2)
	var raw_science = spacecraft.total_science_value * data_ratio
	var a_score = clamp((raw_science / max(1.0, mission.scientific_target)) * 100.0, 0.0, 100.0)
	result.scientific_score = snapped(a_score, 0.1)

	# 2. Reliability (R) - Weight 25%
	var r_score = spacecraft.average_reliability * 100.0
	# Deduct for failure/anomaly events
	for ev in simulation_events:
		if ev.get("severity", "") == "critical":
			r_score -= 15.0
		elif ev.get("severity", "") == "warning":
			r_score -= 5.0
	r_score = clamp(r_score, 0.0, 100.0)
	result.reliability_score = snapped(r_score, 0.1)

	# 3. Resource Efficiency (E) - Weight 20%
	# Optimal payload mass fraction and power sizing
	var mass_fraction = spacecraft.total_mass / max(1.0, mission.mass_limit)
	var power_fraction = spacecraft.net_power / max(1.0, mission.power_requirement)
	
	var mass_eff = 100.0
	if mass_fraction > 1.0:
		mass_eff = max(0.0, 100.0 - (mass_fraction - 1.0) * 200.0)
	elif mass_fraction < 0.4:
		# Under-utilized launch vehicle
		mass_eff = 70.0 + (mass_fraction / 0.4) * 30.0
		
	var power_eff = 100.0
	if power_fraction < 1.0:
		power_eff = max(0.0, power_fraction * 80.0)
	elif power_fraction > 2.5:
		power_eff = 85.0 # Slight oversizing penalty
		
	var e_score = clamp((mass_eff * 0.5) + (power_eff * 0.5), 0.0, 100.0)
	result.efficiency_score = snapped(e_score, 0.1)

	# 4. Budget Management (B) - Weight 15%
	var cost_ratio = spacecraft.total_cost / max(1.0, mission.budget_limit)
	var b_score = 100.0
	if cost_ratio > 1.0:
		b_score = max(0.0, 100.0 - (cost_ratio - 1.0) * 250.0)
	else:
		# Reward cost savings while delivering science
		var savings_fraction = 1.0 - cost_ratio
		b_score = 80.0 + (savings_fraction * 20.0)
	b_score = clamp(b_score, 0.0, 100.0)
	result.budget_score = snapped(b_score, 0.1)

	# 5. Mission Completion (C) - Weight 10%
	var c_score = clamp((float(completed_phases) / float(max(1, total_phases))) * 100.0, 0.0, 100.0)
	result.completion_score = snapped(c_score, 0.1)

	# Final Formula
	var final_s = (0.30 * result.scientific_score) + \
	              (0.25 * result.reliability_score) + \
	              (0.20 * result.efficiency_score) + \
	              (0.15 * result.budget_score) + \
	              (0.10 * result.completion_score)
	result.final_score = snapped(final_s, 0.1)

	# Generate detailed engineering feedback
	_generate_engineering_analysis(result, spacecraft, mission, simulation_events)

	return result

static func _generate_engineering_analysis(
	result: MissionResult,
	spacecraft: SpacecraftConfig,
	mission: MissionConfig,
	events: Array
) -> void:
	# Strengths
	if result.scientific_score >= 85.0:
		result.strengths.append("High Scientific Output: Scientific payload gathered abundant data surpassing nominal survey targets.")
	if spacecraft.has_component("power_rtg"):
		result.strengths.append("Robust Nuclear Power: MMRTG generated uninterrupted power unaffected by solar distance or nighttime.")
	if spacecraft.has_component("comm_high_gain_dish"):
		result.strengths.append("High-Throughput Downlink: High-Gain Parabolic Dish maintained continuous deep-space data transmission.")
	if result.budget_score >= 90.0:
		result.strengths.append("Fiscal Responsibility: Mission delivered strong scientific value with substantial budget contingency preserved.")
	if spacecraft.average_reliability >= 0.85:
		result.strengths.append("High System Reliability: Conservative subsystem selection prevented catastrophic flight computer failures.")

	# Weaknesses
	if result.scientific_score < 60.0:
		result.weaknesses.append("Low Scientific Return: Spacecraft collected or transmitted insufficient scientific data.")
	if spacecraft.net_power < mission.power_requirement:
		result.weaknesses.append("Power Deficit: Spacecraft net power was below nominal requirements, forcing duty-cycling.")
	if spacecraft.comms_capacity < mission.communication_requirement:
		result.weaknesses.append("Telemetry Bottleneck: Antenna throughput was unable to keep pace with instrument data generation.")
	if spacecraft.total_mass > mission.mass_limit:
		result.weaknesses.append("Mass Overweight: Launch mass exceeded fairing limits, causing propulsion margins to diminish.")

	# Recommendations
	if mission.destination == "Mars" and not spacecraft.has_component("power_rtg"):
		result.recommendations.append("Consider replacing fixed solar arrays with an MMRTG (Radioisotope Thermoelectric Generator) to survive Martian dust and cold nights.")
	if spacecraft.comms_capacity < mission.communication_requirement:
		result.recommendations.append("Upgrade communications package to a High-Gain Dish or add a Solid-State Data Recorder to buffer observations during occultation.")
	if spacecraft.total_delta_v < mission.min_delta_v:
		result.recommendations.append("Equip Dual-Mode Bipropellant propulsion or NEXT-C Ion engines to ensure adequate delta-v for capture burn.")
	if not spacecraft.has_component("power_li_battery"):
		result.recommendations.append("Include a Li-Ion battery bank to buffer high-draw sensors and survive orbital darkness.")

	# Educational Takeaways
	match mission.destination:
		"Earth":
			result.educational_takeaways.append("Spacecraft in Low Earth Orbit encounter eclipse for ~35% of each orbit. Solar-powered satellites require precise energy storage sizing.")
			result.educational_takeaways.append("Earth remote sensing balances spatial resolution against data downlink rates; modern Earth observation relies heavily on multi-spectral imaging.")
		"Moon":
			result.educational_takeaways.append("Without an atmosphere to brake against, lunar landers must carry dedicated rocket engines and landing legs capable of canceling all 1.7 km/s orbital velocity.")
			result.educational_takeaways.append("Permanently shadowed polar craters harbor billions of tons of water ice, a critical resource for sustainable lunar habitation.")
		"Mars":
			result.educational_takeaways.append("Interplanetary radio signals take between 4 and 20 minutes to travel from Mars to Earth. Mission control cannot steer live landing; autonomous systems are essential.")
			result.educational_takeaways.append("Mars' thin atmosphere requires a dual-stage landing system: a hypersonic heat shield to bleed orbital kinetic energy, followed by supersonic parachutes and a powered Sky Crane.")
