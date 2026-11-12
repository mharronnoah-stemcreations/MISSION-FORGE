class_name MissionValidator
extends RefCounted

# MissionValidator
# Evaluates spacecraft configurations against mission objectives and real-world aerospace constraints.
# Enforces Hard Constraints (launch blockers) and Soft Constraints (operational risk warnings).
# Provides actionable educational remediation tips.

static func validate(spacecraft: SpacecraftConfig, mission: MissionConfig) -> ValidationResult:
	var result = ValidationResult.new()
	if spacecraft == null or mission == null:
		result.add_error("Invalid spacecraft or mission configuration.")
		return result

	var summary = ResourceCalculator.calculate_summary(spacecraft, mission)

	# 1. Structural Bus Hard Check
	if not spacecraft.has_category("Structure"):
		result.add_error("HARD CONSTRAINT: Spacecraft lacks a primary structural bus or rover chassis. Install 'Standard Medium Satellite Bus', 'Deep Space Heavy Probe Bus', or 'Rocker-Bogie Rover Mobility Chassis'.")

	# 2. Launch Mass Constraints
	if summary["total_mass"] > mission.mass_limit:
		var over_kg = summary["total_mass"] - mission.mass_limit
		result.add_error("HARD CONSTRAINT: Launch vehicle capacity exceeded by %.1f kg (Total: %.1f kg / Max: %.1f kg). Reduce payload mass or remove heavy auxiliary components." % [
			over_kg, summary["total_mass"], mission.mass_limit
		])
	elif summary["total_mass"] > (mission.mass_limit * 0.95):
		result.add_warning("SOFT WARNING: Critical mass margin: Spacecraft utilizes >95%% of launch booster capacity. Minimal propellant reserves available for launch trajectory dispersions.")
		result.add_tip("Actionable Tip: Swap heavy metal structures or remove duplicate secondary instruments to increase mass margin.")

	# 3. Financial Budget Constraints
	if summary["total_cost"] > mission.budget_limit:
		var over_cost = summary["total_cost"] - mission.budget_limit
		result.add_error("HARD CONSTRAINT: Mission budget exceeded by $%.1fM (Total Cost: $%.1fM / Cap: $%.1fM). De-scope optional instrumentation to meet congressional cost cap." % [
			over_cost, summary["total_cost"], mission.budget_limit
		])
	elif summary["total_cost"] > (mission.budget_limit * 0.92):
		result.add_warning("SOFT WARNING: Tight budget reserve: Less than 8%% contingency funding remaining ($%.1fM remaining)." % [
			mission.budget_limit - summary["total_cost"]
		])
		result.add_tip("Actionable Tip: Consider substituting deployable solar arrays with fixed panels if power margins allow.")

	# 4. Electrical Power & Energy Storage
	if spacecraft.total_power_generation <= 0.0:
		result.add_error("HARD CONSTRAINT: Zero electrical power generation installed. Spacecraft cannot survive without solar arrays or RTG nuclear power.")
	elif spacecraft.net_power < 0.0:
		if spacecraft.total_battery_capacity_wh <= 0.0:
			result.add_error("HARD CONSTRAINT: Electrical deficit: Continuous consumption (%.0fW) exceeds generation (%.0fW) with NO battery storage buffer installed. Immediate vehicle brownout." % [
				spacecraft.total_power_consumption, spacecraft.total_power_generation
			])
		else:
			result.add_warning("SOFT WARNING: Intermittent power deficit: Peak instrument load (%.0fW) exceeds continuous generation (%.0fW). Instruments must be duty-cycled using battery reserve (%.0f Wh installed)." % [
				spacecraft.total_power_consumption, spacecraft.total_power_generation, spacecraft.total_battery_capacity_wh
			])
			result.add_tip("Actionable Tip: Upgrade to 'Dual MMRTG Nuclear Power System' or add 'High-Capacity Li-Ion Battery Storage Buffer' to support simultaneous instrument operation.")
	elif summary["power_margin"] < 0.0:
		result.add_warning("SOFT WARNING: Net power (%.0fW) is below recommended mission target (%.0fW). High-energy sensors may experience duty-cycle throttling." % [
			spacecraft.net_power, mission.power_requirement
		])

	# 5. Scientific Payload
	if not spacecraft.has_category("Instruments"):
		result.add_error("HARD CONSTRAINT: No scientific instruments installed. Mission cannot fulfill primary scientific exploration return.")
	elif summary["total_science_value"] < mission.scientific_target:
		result.add_warning("SOFT WARNING: Current instrument suite produces %.0f science pts (Target: %.0f pts). Lower mission evaluation grade expected." % [
			summary["total_science_value"], mission.scientific_target
		])
		result.add_tip("Actionable Tip: Equip complementary spectrometers, coring drills, or high-resolution imagers to meet science objectives.")

	# 6. Communications Capability
	if not spacecraft.has_category("Communications"):
		result.add_error("HARD CONSTRAINT: No communications antenna installed. Spacecraft cannot uplink commands or downlink scientific telemetry to Earth.")
	elif summary["comms_capacity"] < mission.communication_requirement:
		result.add_warning("SOFT WARNING: Downlink bandwidth (%.1f Mbps) is below requirement (%.1f Mbps). Expect transmission queue bottlenecks and risk of data buffer overflow." % [
			summary["comms_capacity"], mission.communication_requirement
		])
		result.add_tip("Actionable Tip: Equip 'Medium-Gain X-Band Horn' or '1.8m High-Gain Parabolic Dish' for higher telemetry throughput.")

	# 7. Delta-V & Propulsion (Tsiolkovsky Equation)
	if mission.min_delta_v > 0.0:
		if summary["total_delta_v"] < (mission.min_delta_v * 0.70):
			result.add_error("HARD CONSTRAINT: Insufficient propulsion: Rocket delta-v (%.0f m/s) cannot achieve orbital insertion or descent (Needs %.0f m/s). Vehicle will miss destination or crash." % [
				summary["total_delta_v"], mission.min_delta_v
			])
		elif summary["total_delta_v"] < mission.min_delta_v:
			result.add_warning("SOFT WARNING: Marginal delta-v budget (%.0f m/s vs %.0f m/s required). High risk of trajectory injection failure under non-nominal burns." % [
				summary["total_delta_v"], mission.min_delta_v
			])
			result.add_tip("Actionable Tip: Install 'Auxiliary Propellant Tank Module' (250kg fuel) or switch to high-Isp bipropellant/ion propulsion.")

	# 8. Required Components Verification
	for req_id in mission.required_components:
		if not spacecraft.has_component(req_id):
			var comp_title = req_id
			var loop = Engine.get_main_loop()
			if loop is SceneTree and loop.root and loop.root.has_node("MissionManager"):
				var comp = loop.root.get_node("MissionManager").get_component(req_id)
				if comp: comp_title = comp.display_name
			result.add_error("HARD CONSTRAINT: Missing mandatory mission component: %s." % comp_title)

	# 9. Mission-Specific Environmental & Operational Rules
	match mission.destination:
		"Mars":
			if not spacecraft.has_component("land_mars_entry"):
				result.add_error("HARD CONSTRAINT: Mars mission missing atmospheric Entry Aeroshell & Heat Shield. Hypersonic entry will vaporize vehicle.")
			if not spacecraft.has_component("land_skycrane"):
				result.add_warning("SOFT WARNING: Missing Sky Crane terminal descent stage: Direct parachute landing will subject rover mobility chassis to high-g touchdown shocks.")
				result.add_tip("Actionable Tip: Equip 'Rocket-Powered Sky Crane' to gently lower rover onto its wheels in Jezero Crater.")
			if not spacecraft.has_component("power_rtg") and not spacecraft.has_component("power_dual_rtg"):
				result.add_warning("SOFT WARNING: Solar panels on Mars suffer from 57% solar flux reduction and dust storm obscuration. MMRTG nuclear power provides continuous 24/7 energy.")
			if not spacecraft.has_component("comm_high_gain_dish"):
				result.add_warning("SOFT WARNING: Deep-space Mars distance requires High-Gain Parabolic Dish to communicate with NASA Deep Space Network.")

		"Moon":
			if not spacecraft.has_component("land_lunar_legs"):
				result.add_error("HARD CONSTRAINT: Lunar mission missing Throttleable Descent Engines & Landing Gear. Lander cannot survive surface touchdown.")
			if not spacecraft.has_component("power_li_battery") and spacecraft.total_power_generation > 0.0:
				result.add_warning("SOFT WARNING: Lunar polar low-sun elevation and crater shadows cause extended eclipse periods. Battery storage buffer is strongly recommended.")
			if not spacecraft.has_component("mobility_lunar_rover"):
				result.add_warning("SOFT WARNING: Artemis Prospector lacks surface mobility. A stationary lander on Shackleton Crater rim cannot reach water ice volatiles inside Permanently Shadowed Regions (PSRs).")
				result.add_tip("Actionable Tip: Equip 'Autonomous Lunar Micro-Rover (Shadow Explorer)' to explore deep into Shackleton Crater.")

		"Earth":
			if not spacecraft.has_component("power_li_battery") and spacecraft.total_power_generation > 0.0:
				result.add_warning("SOFT WARNING: 705 km Sun-synchronous orbit spends 35 minutes per 98-minute orbit in eclipse. Battery storage buffer recommended to avoid instrument cold resets.")
				result.add_tip("Actionable Tip: Install 'High-Capacity Li-Ion Battery Storage Buffer' to sustain instrument heaters through eclipse.")
			if not spacecraft.has_component("data_solid_state_recorder"):
				result.add_tip("Actionable Tip: Optical and SAR Earth sensors produce heavy continuous data. Adding a 1 TB Solid-State Data Recorder prevents data buffer overflow when out of line-of-sight of ground stations.")

	# 10. Subsystem Reliability Check
	if spacecraft.average_reliability < 0.70:
		result.add_warning("SOFT WARNING: Overall spacecraft mission reliability is low (%.1f%%). High risk of subsystem telemetry anomalies or in-flight component failures." % [
			spacecraft.average_reliability * 100.0
		])

	return result
