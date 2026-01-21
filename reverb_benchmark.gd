extends SceneTree

# Reverb probe bake benchmark on Sponza.
# Usage: godot --headless --path E:\godot-sponza --script res://reverb_benchmark.gd

var started := false
func _process(_delta: float) -> bool:
	if not started:
		started = true
		run_benchmark.call_deferred()
	return false

func run_benchmark() -> void:
	print("=== Reverb Probe Bake Benchmark (Sponza) ===")
	print("")

	# Load Sponza scene.
	var scene_res := load("res://scenes/sponza.scn")
	if scene_res == null:
		print("ERROR: Could not load sponza.scn")
		quit(1)
		return

	var scene_node: Node = scene_res.instantiate()
	root.add_child(scene_node)

	# Wait for scene to settle.
	for i in range(3):
		await process_frame

	var probe_gi := ReverbProbeGI.new()
	probe_gi.wall_material = ReverbProbeGI.MATERIAL_PLASTER_SMOOTH
	scene_node.add_child(probe_gi)

	# Generate probe grid covering the Sponza atrium.
	# Sponza is roughly 25m x 15m x 12m.
	var probes := PackedVector3Array()
	for x in range(-10, 11, 4):
		for y in range(0, 12, 4):
			for z in range(-6, 7, 4):
				probes.append(Vector3(x, y, z))

	print("Probe count: %d" % probes.size())
	print("Scene: Sponza (%d children)" % scene_node.get_child_count())
	print("")

	# Benchmark: low ray count (fast).
	print("--- Low quality (1000 rays, 20 bounces) ---")
	var err := probe_gi.bake(scene_node, probes, 1000, 20)
	if err != ReverbProbeGI.BAKE_ERROR_OK:
		print("Bake failed: %d" % err)
	else:
		_print_rt60_summary(probe_gi.bake_data)
	print("")

	# Benchmark: medium ray count.
	print("--- Medium quality (5000 rays, 50 bounces) ---")
	err = probe_gi.bake(scene_node, probes, 5000, 50)
	if err != ReverbProbeGI.BAKE_ERROR_OK:
		print("Bake failed: %d" % err)
	else:
		_print_rt60_summary(probe_gi.bake_data)
	print("")

	# Benchmark: high ray count.
	print("--- High quality (50000 rays, 100 bounces) ---")
	err = probe_gi.bake(scene_node, probes, 50000, 100)
	if err != ReverbProbeGI.BAKE_ERROR_OK:
		print("Bake failed: %d" % err)
	else:
		_print_rt60_summary(probe_gi.bake_data)

	print("")
	print("=== Benchmark complete ===")
	scene_node.queue_free()
	quit(0)

func _print_rt60_summary(data: ReverbBakeData) -> void:
	if data == null:
		print("  No data")
		return
	var rt60 := data.get_rt60_values()
	var count := data.get_probe_count()
	var bands := [31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]

	# Average RT60 across all probes per band.
	print("  Band(Hz)   Avg RT60(s)  Min(s)   Max(s)")
	for b in range(9):
		var sum := 0.0
		var mn := 999.0
		var mx := 0.0
		for p in range(count):
			var v: float = rt60[p * 9 + b]
			sum += v
			if v < mn: mn = v
			if v > mx: mx = v
		var avg: float = sum / count if count > 0 else 0
		print("  %7.0f    %8.3f    %8.3f  %8.3f" % [bands[b], avg, mn, mx])
