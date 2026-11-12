# MISSIONFORGE — VISUAL ASSET CATALOG
**Event**: NASA Space Apps Challenge 2026 — Space Mission Design Game  
**Lead 3D Technical Artist**: Senior Graphics Engineer  
**Date**: November 2026  

---

## 1. Asset Policy & Source Management
All 3D models, textures, materials, and particle effects in MissionForge are created procedurally and deterministically in Godot Engine 4.7+ using GDScript, native PBR materials, procedural noise shaders, and mathematical geometry generation. No unlicensed third-party assets are used.

NASA imagery references and public-domain orbital science parameters are derived from open NASA datasets (NASA Earth Observatory, Landsat 8/9, LRO LOLA/Diviner, KPLO ShadowCam, Mars 2020 Perseverance EDL).

---

## 2. Procedural 3D Mesh Catalog (`spacecraft_preview.gd`)

| Component ID | Visual Identifier | Procedural Mesh Architecture & Materials | Aerospace Purpose |
|---|---|---|---|
| `bus_medium_sat` | `bus_medium` | Beveled rectangular prism with Kapton gold MLI foil, radiator louvers, and structural avionics mounting rails. | Standard 3-axis stabilized bus for LEO & lunar missions. |
| `bus_deep_space` | `bus_heavy` | Reinforced octagonal cylinder with titanium-composite panels and radiation shielding. | Interplanetary bus engineered for deep space radiation. |
| `chassis_mars_rover` | `rover_chassis` | 6-wheel rocker-bogie differential suspension chassis with articulated rocker links, bogie pivots, and grooved aluminum wheels. | High-clearance mobility platform for 40cm Martian boulders. |
| `mobility_lunar_rover` | `lunar_micro_rover` | 4-wheeled ultra-compact rover with Kapton gold body, sensor turret, LED illuminators, and tether bracket. | Traversing Shackleton Crater 40K Permanently Shadowed Regions. |
| `power_solar_fixed` | `solar_panel_fixed` | Body-mounted silicon wafer panels with dark blue anti-reflective coating and metallic silver busbars. | Low-mass solar generation for spinning/body-stabilized probes. |
| `power_solar_deployable` | `solar_array_dual` | Dual articulating UltraFlex round/rectangular solar wings with solar cell array facets and deployment hinges. | High-efficiency solar power tracking for orbit operations. |
| `power_rtg` | `rtg_generator` | Cylindrical Plutonium-238 heat source with radial thermal radiator fins and bi-metallic thermocouple housing. | Continuous 110W electrical / 2000W thermal nuclear power. |
| `power_dual_rtg` | `rtg_generator` | Twin MMRTG package with dual fin arrays and heavy-duty bus bracket. | 220W continuous deep-space power. |
| `power_li_battery` | `battery_pack` | Dual modular lithium-ion energy storage box with blue anodized casing and thermal heat pipe interface. | 1200 Wh battery energy buffer for eclipses and high-draw sensors. |
| `comm_high_gain_dish` | `antenna_dish` | 1.8m parabolic reflector dish with dual-axis motorized gimbal mount, sub-reflector feed horn, and struts. | High-throughput Ka/X-band telemetry to NASA Deep Space Network. |
| `comm_medium_horn` | `antenna_horn` | Flared pyramidal X-band horn antenna with wave-guide feed. | Cis-lunar and lunar polar communications. |
| `comm_omni_low_gain` | `antenna_omni` | Whip/helical low-gain antenna for omnidirectional safe-mode links. | Emergency commanding regardless of spacecraft attitude. |
| `prop_monoprop` | `thruster_rcs` | Quad-cluster catalytic hydrazine thrusters with miniature conical nozzles and propellant distribution manifold. | 3-axis attitude control, momentum dumping, and LEO stationkeeping. |
| `prop_biprop` | `thruster_main` | Aerojet-style R-4D radiative-cooled niobium/titanium rocket engine bell with fuel/oxidizer lines. | Trans-lunar / trans-Mars injection and orbit capture burns. |
| `prop_next_ion` | `thruster_ion` | Electrostatic gridded ion engine with cylindrical molybdenum accelerator grid and blue plasma glow ring. | High-$I_{sp}$ continuous low-thrust deep space cruise. |
| `prop_aux_tank` | `prop_tank` | Twin spherical Composite Overwrapped Pressure Vessels (COPV) with carbon-epoxy weave and titanium liner. | 250 kg auxiliary propellant storage for high $\Delta v$. |
| `land_lunar_legs` | `landing_gear_lunar` | 4 outward-splayed A-frame landing struts with crushable honeycomb shock absorbers, footpads, and descent thruster cluster. | Soft touchdown on lunar regolith at Shackleton Crater rim. |
| `land_mars_entry` | `heat_shield_aeroshell` | 70° sphere-cone blunt-body aeroshell with PICA ablative thermal protection shield and backshell container. | Atmospheric hypersonic kinetic energy dissipation. |
| `land_skycrane` | `skycrane_stage` | Octagonal rocket backpack with 8 canted descent engines, fuel manifolds, and 3 nylon bridle lowering tethers. | Soft rover touchdown directly onto wheels in Jezero Crater. |
| `inst_multispectral_imager` | `sensor_imager` | Dual optical pushbroom barrel with baffles, aperture door, and thermal radiator. | Landsat 8/9 OLI-2 multispectral Earth imaging. |
| `inst_sar_radar` | `radar_dish` | Planar phased-array radar antenna panel with gold-mesh backing. | Geodetic surface deformation mapping through cloud cover. |
| `inst_lunar_drill` | `drill_arm` | 1-meter rotary-percussive coring drill tower with volatile mass spectrometer and regolith transfer auger. | Extracting cryo-trapped water ice volatiles on Moon. |
| `inst_mars_drill` | `robotic_arm_drill` | 5-degree-of-freedom robotic turret arm with percussive coring drill, dust clearing tool, and ChemCam optics. | Collecting rock cores in Jezero Crater delta. |
| `inst_mastcam_stereo` | `camera_mast` | 2-meter elevated mast with dual multispectral stereo cameras and zoom optics. | 3D stereo navigation panoramas and mineralogy. |
| `inst_lunar_seismometer` | `seismometer` | Ground-deployed sensor package with thermal protective skirt and heat flow probe. | Measuring deep moonquakes and planetary thermal gradients. |
| `data_rad_computer` | `avionics_computer` | Rad-hardened RAD750 electronics enclosure with blind-mate backplane and gold grounding straps. | Triple-modular redundant flight processing and FDIR. |
| `data_solid_state_recorder`| `data_box` | Rad-tolerant solid-state mass memory module with Reed-Solomon controller. | 1 TB high-throughput observation buffering. |

---

## 3. PBR Material Standards

All materials are physically based with tuned roughness, metallic, and normal properties:
* **Kapton Gold MLI**: Albedo `#FFD034`, Metallic `0.85`, Roughness `0.22`, subtle micro-faceted specular response.
* **Solar Cell Silicon**: Albedo `#0E2044`, Metallic `0.92`, Roughness `0.12`, Deep blue anti-reflective specular coating with metallic silver busbars.
* **Aerospace Titanium**: Albedo `#C5CAD0`, Metallic `0.94`, Roughness `0.18`.
* **Carbon Fiber / COPV Composite**: Albedo `#2A2D32`, Metallic `0.30`, Roughness `0.45`.
* **Rocket Engine Niobium Alloy**: Albedo `#45484D`, Metallic `0.88`, Roughness `0.35`.
* **Lunar Regolith**: Albedo `#A0A5AA`, Metallic `0.02`, Roughness `0.96`, high directional contrast.
* **Martian Basaltic Iron Oxide**: Albedo `#C85830`, Metallic `0.05`, Roughness `0.88`, fine orange/red dust scatter.

---

## 4. Atmospheric & Trajectory Shaders
* **Atmospheric Limb Scattering Shader**: Replaces simple unshaded spheres with a custom Fresnel Rayleigh atmospheric scattering shader with blue/cyan limb glow for Earth and amber/salmon dust limb glow for Mars.
* **Orbital Conic Trajectory Renderer**: Procedural 3D line-strip ring rendering true orbital ellipses around planets with spacecraft marker nodes and sensor ground track cones.
