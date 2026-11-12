class_name SpacecraftConfig
extends Resource

@export var spacecraft_name: String = "Odyssey-1"
var selected_components: Array[SpaceComponent] = []

# Physical mass properties
var total_mass: float = 0.0               # Wet mass (kg)
var dry_mass: float = 0.0                 # Mass without propellant (kg)
var total_propellant_mass: float = 0.0    # Usable propellant mass (kg)

# Financial & Electrical
var total_cost: float = 0.0               # $ Millions
var total_power_generation: float = 0.0   # Continuous generation (Watts)
var total_power_consumption: float = 0.0  # Continuous consumption (Watts)
var net_power: float = 0.0                # Gen - Con (Watts)
var total_battery_capacity_wh: float = 0.0# Stored energy capacity (Wh)
var total_thermal_output_w: float = 0.0   # Thermal output (Watts)

# Telemetry, Data & Science
var total_data_generation: float = 0.0    # MB/day
var total_storage_capacity_gb: float = 0.0# Solid-state memory buffer (GB)
var comms_capacity: float = 0.0           # Mbps downlink bandwidth
var total_science_value: float = 0.0      # Baseline science points
var average_reliability: float = 1.0      # Subsystem product reliability

# Propulsion & Orbital Mechanics
var effective_isp: float = 0.0            # Weighted average specific impulse (seconds)
var total_thrust_n: float = 0.0           # Combined thrust (Newtons)
var total_delta_v: float = 0.0            # Tsiolkovsky delta-v (m/s)

func clear() -> void:
	selected_components.clear()
	recalculate()

func add_component(comp: SpaceComponent) -> void:
	if comp == null:
		return
	selected_components.append(comp)
	recalculate()

func remove_component(comp: SpaceComponent) -> bool:
	var idx = selected_components.find(comp)
	if idx != -1:
		selected_components.remove_at(idx)
		recalculate()
		return true
	return false

func remove_component_by_id(comp_id: String) -> bool:
	for i in range(selected_components.size()):
		if selected_components[i].id == comp_id:
			selected_components.remove_at(i)
			recalculate()
			return true
	return false

func has_component(comp_id: String) -> bool:
	for c in selected_components:
		if c.id == comp_id:
			return true
	return false

func count_category(cat: String) -> int:
	var cnt: int = 0
	for c in selected_components:
		if c.category == cat:
			cnt += 1
	return cnt

func has_category(cat: String) -> bool:
	return count_category(cat) > 0

func get_components_of_category(cat: String) -> Array[SpaceComponent]:
	var result: Array[SpaceComponent] = []
	for c in selected_components:
		if c.category == cat:
			result.append(c)
	return result

func recalculate() -> void:
	total_mass = 0.0
	dry_mass = 0.0
	total_propellant_mass = 0.0
	total_cost = 0.0
	total_power_generation = 0.0
	total_power_consumption = 0.0
	total_battery_capacity_wh = 0.0
	total_thermal_output_w = 0.0
	total_data_generation = 0.0
	total_storage_capacity_gb = 0.0
	total_science_value = 0.0
	comms_capacity = 0.0
	effective_isp = 0.0
	total_thrust_n = 0.0
	total_delta_v = 0.0
	
	if selected_components.is_empty():
		average_reliability = 1.0
		net_power = 0.0
		return

	var reliability_product: float = 1.0
	var weighted_isp_sum: float = 0.0
	var legacy_impulse_sum: float = 0.0

	for comp in selected_components:
		total_mass += comp.mass
		total_propellant_mass += comp.propellant_mass
		total_cost += comp.cost
		total_power_generation += comp.power_generation
		total_power_consumption += comp.power_consumption
		total_battery_capacity_wh += comp.battery_capacity_wh
		total_thermal_output_w += comp.thermal_output_w
		total_data_generation += comp.data_generation
		total_storage_capacity_gb += comp.storage_capacity_gb
		total_science_value += comp.science_value
		comms_capacity = max(comms_capacity, comp.comms_bandwidth)
		total_thrust_n += comp.thrust_n
		legacy_impulse_sum += comp.delta_v_impulse
		reliability_product *= comp.reliability

		if comp.propellant_mass > 0.0 and comp.isp_seconds > 0.0:
			weighted_isp_sum += comp.propellant_mass * comp.isp_seconds

	net_power = total_power_generation - total_power_consumption
	average_reliability = reliability_product
	dry_mass = max(1.0, total_mass - total_propellant_mass)

	# Tsiolkovsky Rocket Equation calculation:
	# Δv = Isp * g0 * ln(m0 / mf)
	# Where g0 = 9.80665 m/s^2, m0 = total wet mass, mf = dry mass
	const G0: float = 9.80665
	if total_propellant_mass > 0.0 and weighted_isp_sum > 0.0 and total_mass > dry_mass:
		effective_isp = weighted_isp_sum / total_propellant_mass
		var mass_ratio = total_mass / dry_mass
		total_delta_v = effective_isp * G0 * log(mass_ratio)
	elif legacy_impulse_sum > 0.0:
		total_delta_v = legacy_impulse_sum
