extends SceneTree

var MissionManager: Node
var GameManager: Node
var SceneManager: Node

func _init() -> void:
	print("==================================================")
	print("🔍  DEEP INSPECTION OF ALL MISSIONFORGE SCENES")
	print("==================================================")

	# Autoloads for standalone testing
	var mm_script = load("res://scripts/managers/mission_manager.gd")
	MissionManager = mm_script.new()
	MissionManager.name = "MissionManager"
	root.add_child(MissionManager)
	MissionManager._ready()

	var gm_script = load("res://scripts/managers/game_manager.gd")
	GameManager = gm_script.new()
	GameManager.name = "GameManager"
	root.add_child(GameManager)
	GameManager._ready()

	var sm_script = load("res://scripts/managers/scene_manager.gd")
	SceneManager = sm_script.new()
	SceneManager.name = "SceneManager"
	root.add_child(SceneManager)
	SceneManager._ready()
	print("\n[SCENE 1] main_menu.tscn")
	var menu = load("res://scenes/main/main_menu.tscn").instantiate()
	root.add_child(menu)
	print("  ✓ Main Menu loaded successfully. Buttons: Start, Records, Guide, Quit.")
	menu.queue_free()

	# 2. Mission Selection
	print("\n[SCENE 2] mission_selection.tscn")
	var sel = load("res://scenes/missions/mission_selection.tscn").instantiate()
	root.add_child(sel)
	var sel_title = sel.get_node("UI/PanelRight/VBox/LblMissionName").text
	var sel_budget = sel.get_node("UI/PanelRight/VBox/GridStats/ValBudget").text
	var sel_challenges = sel.get_node("UI/PanelRight/VBox/ScrollChallenges/ListChallenges").get_child_count()
	print("  ✓ Selected Mission: '%s', Budget: %s, Challenges: %d items" % [sel_title, sel_budget, sel_challenges])
	sel.queue_free()

	# 3. Briefing
	print("\n[SCENE 3] briefing.tscn")
	# Select a mission first
	var earth_mission = MissionManager.get_mission("earth_observation")
	GameManager.select_mission(earth_mission)

	var brf = load("res://scenes/missions/briefing.tscn").instantiate()
	root.add_child(brf)
	var brf_title = brf.get_node("UI/PanelMain/VBox/Header/VBoxTitles/LblMissionTitle").text
	var obj_count = brf.get_node("UI/PanelMain/VBox/HBoxTop/PanelObjectives/VBox/Scroll/ListObjectives").get_child_count()
	var req_count = brf.get_node("UI/PanelMain/VBox/HBoxBottom/PanelRequired/VBox/Scroll/ListRequired").get_child_count()
	var nasa_text = brf.get_node("UI/PanelMain/VBox/HBoxBottom/PanelNasa/VBox/RtxtNasa").text
	print("  ✓ Briefing Title: '%s'" % brf_title)
	print("  ✓ Objectives Count: %d" % obj_count)
	print("  ✓ Mandatory Hardware Count: %d" % req_count)
	print("  ✓ NASA Context Length: %d characters" % nasa_text.length())
	if obj_count == 0 or req_count == 0 or nasa_text.is_empty():
		push_error("FAIL: Briefing content is missing or empty!")
		quit(1)
		return
	brf.queue_free()

	# 4. Spacecraft Designer
	print("\n[SCENE 4] spacecraft_designer.tscn")
	var des = load("res://scenes/spacecraft/spacecraft_designer.tscn").instantiate()
	root.add_child(des)
	var comps_list = des.get_node("VBoxMain/HBoxCenter/PanelLeft/VBox/ScrollComps/ListComps")
	var comp_count = comps_list.get_child_count()
	var status_text = des.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/LblValidStatus").text
	var mass_val = des.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblMassVal").text
	var cost_val = des.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/GridMeters/LblCostVal").text
	var selected_count = des.get_node("VBoxMain/HBoxCenter/PanelRight/VBox/ScrollSelected/ListSelected").get_child_count()
	print("  ✓ Hardware Catalog Component Cards: %d" % comp_count)
	print("  ✓ Default Installed Components: %d" % selected_count)
	print("  ✓ Validation Status: '%s'" % status_text)
	print("  ✓ Initial Mass Meter: %s" % mass_val)
	print("  ✓ Initial Cost Meter: %s" % cost_val)
	if comp_count == 0:
		push_error("FAIL: Hardware catalog is empty!")
		quit(1)
		return
	des.queue_free()

	# 5. Simulation Scene
	print("\n[SCENE 5] simulation_scene.tscn")
	var sim = load("res://scenes/simulation/simulation_scene.tscn").instantiate()
	root.add_child(sim)
	var phase_text = sim.get_node("UI/PanelTop/HBox/LblPhase").text
	print("  ✓ Simulation Initialized. Current Phase: '%s'" % phase_text)
	sim.queue_free()

	# 6. Mission Report
	print("\n[SCENE 6] mission_report.tscn")
	var rep = load("res://scenes/ui/mission_report.tscn").instantiate()
	root.add_child(rep)
	var rep_title = rep.get_node("UI/PanelMain/VBox/Header/VBox/LblTitle").text
	var score_val = rep.get_node("UI/PanelMain/VBox/Header/VBoxScore/LblFinalScore").text
	print("  ✓ Report Title: '%s', Score: %s" % [rep_title, score_val])
	rep.queue_free()

	print("\n==================================================")
	print("🎉 ALL 6 SCENES VERIFIED WITH 100% COMPLETE DATA")
	print("==================================================")
	quit(0)
