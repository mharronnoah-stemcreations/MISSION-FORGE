class_name SpacecraftConfig
extends Resource

@export var spacecraft_name: String = "Odyssey-1"
var selected_components: Array[SpaceComponent] = []

# Calculated properties
var total_mass: float = 0.0
var total_cost: float = 0.0
var total_power_generation: float = 0.0
var total_power_consumption: float = 0.0
var net_power: float = 0.0
var total_data_generation: float = 0.0
var total_science_value: float = 0.0
var average_reliability: float = 1.0
var comms_capacity: float = 0.0
var total_delta_v: float = 0.0

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
	total_cost = 0.0
	total_power_generation = 0.0
	total_power_consumption = 0.0
	total_data_generation = 0.0
	total_science_value = 0.0
	comms_capacity = 0.0
	total_delta_v = 0.0
	
	if selected_components.is_empty():
		average_reliability = 1.0
		net_power = 0.0
		return

	var reliability_product: float = 1.0
	for comp in selected_components:
		total_mass += comp.mass
		total_cost += comp.cost
		total_power_generation += comp.power_generation
		total_power_consumption += comp.power_consumption
		total_data_generation += comp.data_generation
		total_science_value += comp.science_value
		comms_capacity = max(comms_capacity, comp.comms_bandwidth)
		total_delta_v += comp.delta_v_impulse
		reliability_product *= comp.reliability

	net_power = total_power_generation - total_power_consumption
	average_reliability = reliability_product
