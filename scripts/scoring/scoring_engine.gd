class_name ScoringEngine
extends RefCounted

# ScoringEngine
# Calculates the comprehensive "Mission Performance Index (MPI)":
# MPI = 0.30*A (Science) + 0.25*R (Reliability) + 0.20*E (Resource Efficiency) + 0.15*B (Budget) + 0.10*C (Completion)
# Accompanied by root-cause aerospace engineering analysis and authentic NASA educational takeaways.

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
	var data_ratio = clamp(data_transmitted / max(1.0, data_target), 0.0, 1.3)
	var raw_science = spacecraft.total_science_value * data_ratio
	var a_score = clamp((raw_science / max(1.0, mission.scientific_target)) * 100.0, 0.0, 100.0)
	result.scientific_score = snapped(a_score, 0.1)

	# 2. Subsystem Reliability (R) - Weight 25%
	var r_score = spacecraft.average_reliability * 100.0
	for ev in simulation_events:
		if ev.get("severity", "") == "critical":
			r_score -= 15.0
		elif ev.get("severity", "") == "warning":
			r_score -= 4.0
	r_score = clamp(r_score, 0.0, 100.0)
	result.reliability_score = snapped(r_score, 0.1)

	# 3. Resource Efficiency (E) - Weight 20%
	# Evaluates payload mass fraction, Tsiolkovsky delta-v margin, and power sizing
	var mass_fraction = spacecraft.total_mass / max(1.0, mission.mass_limit)
	var power_fraction = spacecraft.net_power / max(1.0, mission.power_requirement)
	
	var mass_eff = 100.0
	if mass_fraction > 1.0:
		mass_eff = max(0.0, 100.0 - (mass_fraction - 1.0) * 200.0)
	elif mass_fraction < 0.4:
		mass_eff = 70.0 + (mass_fraction / 0.4) * 30.0
		
	var power_eff = 100.0
	if power_fraction < 1.0 and spacecraft.total_battery_capacity_wh <= 0.0:
		power_eff = max(0.0, power_fraction * 70.0)
	elif power_fraction < 1.0 and spacecraft.total_battery_capacity_wh > 0.0:
		power_eff = 85.0 # Battery buffers deficit
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
		var savings_fraction = 1.0 - cost_ratio
		b_score = 80.0 + (savings_fraction * 20.0)
	b_score = clamp(b_score, 0.0, 100.0)
	result.budget_score = snapped(b_score, 0.1)

	# 5. Mission Completion (C) - Weight 10%
	var c_score = clamp((float(completed_phases) / float(max(1, total_phases))) * 100.0, 0.0, 100.0)
	result.completion_score = snapped(c_score, 0.1)

	# Final Mission Performance Index (MPI) Formula
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
	if spacecraft.has_component("mobility_lunar_rover") and mission.destination == "Moon":
		result.strengths.append("Surface PSR Mobility: Shadow Explorer micro-rover penetrated Shackleton Crater cold traps, discovering sub-surface water ice.")
	if spacecraft.has_component("power_dual_rtg") or spacecraft.has_component("power_rtg"):
		result.strengths.append("Nuclear Power Survivability: MMRTG continuous power enabled uninterrupted operation regardless of eclipse or dust storms.")
	if spacecraft.has_component("power_li_battery"):
		result.strengths.append("Energy Buffer Storage: 1.2 kWh Li-ion battery bank provided essential energy reserves through darkness and high-power instrument duty cycles.")
	if spacecraft.has_component("comm_high_gain_dish"):
		result.strengths.append("High-Throughput Downlink: High-Gain Parabolic Dish maintained high-speed telemetry links with NASA Deep Space Network.")
	if spacecraft.has_component("data_solid_state_recorder"):
		result.strengths.append("Onboard Data Storage: 1 TB Solid-State Recorder prevented memory buffer overflow during ground station occultation.")
	if result.budget_score >= 90.0:
		result.strengths.append("Fiscal Responsibility: Mission delivered strong scientific return while preserving significant budget contingency.")
	if spacecraft.average_reliability >= 0.85:
		result.strengths.append("High System Reliability: Conservative subsystem selection prevented in-flight hardware failures.")

	# Weaknesses
	if result.scientific_score < 60.0:
		result.weaknesses.append("Low Scientific Return: Spacecraft collected or downlinked insufficient scientific data.")
	if spacecraft.net_power < 0.0 and spacecraft.total_battery_capacity_wh < 500.0:
		result.weaknesses.append("Power Margin Deficit: Electrical consumption exceeded generation with minimal battery buffer.")
	if spacecraft.comms_capacity < mission.communication_requirement:
		result.weaknesses.append("Telemetry Bottleneck: Antenna bandwidth was insufficient for instrument generation rates.")
	if spacecraft.total_mass > mission.mass_limit:
		result.weaknesses.append("Mass Overweight: Launch mass exceeded booster payload limit, reducing trajectory performance.")
	if mission.destination == "Moon" and not spacecraft.has_component("mobility_lunar_rover"):
		result.weaknesses.append("Stationary Rim Constraint: Lacking a deployable micro-rover, lander was unable to traverse into Shackleton Crater PSRs.")

	# Recommendations
	if mission.destination == "Mars" and not spacecraft.has_component("power_rtg") and not spacecraft.has_component("power_dual_rtg"):
		result.recommendations.append("Equip an MMRTG nuclear power source to avoid solar array degradation from Martian dust storms.")
	if mission.destination == "Moon" and not spacecraft.has_component("mobility_lunar_rover"):
		result.recommendations.append("Install the 'Autonomous Lunar Micro-Rover (Shadow Explorer)' to explore permanently shadowed crater floors.")
	if spacecraft.comms_capacity < mission.communication_requirement:
		result.recommendations.append("Upgrade communications package to High-Gain Dish or add Solid-State Recorder to prevent data loss.")
	if spacecraft.total_delta_v < mission.min_delta_v:
		result.recommendations.append("Equip Bipropellant propulsion or add an Auxiliary Propellant Tank to meet Tsiolkovsky delta-v requirements.")
	if not spacecraft.has_component("power_li_battery"):
		result.recommendations.append("Add a Secondary Li-Ion battery storage buffer to survive orbital eclipse and cold nights.")

	# Educational Takeaways
	match mission.destination:
		"Earth":
			result.educational_takeaways.append("Spacecraft in 705 km Low Earth Orbit spend ~35 minutes of every 99-minute orbit in eclipse. Battery storage must sustain avionics heaters.")
			result.educational_takeaways.append("Earth observation satellites utilize Sun-synchronous orbits so they cross the equator at the same local solar time on every pass, providing consistent lighting.")
		"Moon":
			result.educational_takeaways.append("Lacking an atmosphere to decelerate against, lunar landers must carry dedicated rocket engines and landing legs capable of canceling all 1.7 km/s orbital velocity.")
			result.educational_takeaways.append("Permanently Shadowed Regions (PSRs) at the lunar south pole maintain temperatures of 40 Kelvin (-233°C), cold enough to trap water ice for over 2 billion years.")
		"Mars":
			result.educational_takeaways.append("Interplanetary radio light-travel time from Mars to Earth is 4 to 20 minutes. Atmospheric entry, descent, and landing (EDL) must be 100% autonomous.")
			result.educational_takeaways.append("Mars' thin atmosphere requires a hypersonic heat shield to bleed 99% of kinetic energy, followed by supersonic parachutes and a rocket Sky Crane.")
