extends Node

# Adds spatial audio with reverb probes to the Sponza scene.
# Attach this to the scene root or autoload it.
# Plays a looping tone that you can walk around and hear reverb change.

var audio_player: AudioStreamPlayer3D
var probe_gi: ReverbProbeGI

func _ready() -> void:
	# Set up spatial audio bus.
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Spatial")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_type(1, AudioServer.BUS_TYPE_SPATIAL_3D)

	# Add a sound source in the middle of the atrium.
	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "Spatial"
	audio_player.position = Vector3(0, 2, 0)
	add_child(audio_player)

	# Generate a 440Hz tone.
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 48000
	gen.buffer_length = 1.0
	audio_player.stream = gen
	audio_player.play()

	set_process(true)

	# Bake reverb probes — attach to the camera so the node's position
	# tracks the listener. Each player would have their own ReverbProbeGI.
	probe_gi = ReverbProbeGI.new()
	probe_gi.wall_material = ReverbProbeGI.MATERIAL_PLASTER_SMOOTH
	var mat_map = load("res://resonance_audio_material_map.tres")
	if mat_map:
		probe_gi.material_map = mat_map
		print("Loaded material map with %d mappings" % mat_map.get_material_mappings().size())
	else:
		print("WARNING: No material map found at res://resonance_audio_material_map.tres")
	var scene_root := get_tree().current_scene
	var camera := get_viewport().get_camera_3d()
	if camera:
		camera.add_child(probe_gi)
	elif scene_root:
		scene_root.add_child(probe_gi)
	else:
		add_child(probe_gi)

	var probes := PackedVector3Array()
	for x in range(-10, 11, 4):
		for y in range(0, 12, 4):
			for z in range(-6, 7, 4):
				probes.append(Vector3(x, y, z))

	var bake_root := scene_root if scene_root else get_parent()
	print("Baking %d reverb probes on Sponza..." % probes.size())
	var err := probe_gi.bake(bake_root, probes, 5000, 50)
	if err == ReverbProbeGI.BAKE_ERROR_OK:
		print("Bake complete. Walk around to hear reverb change.")
	else:
		print("Bake failed: %d" % err)

var _phase := 0.0

func _process(_delta: float) -> void:
	if audio_player == null or not audio_player.is_playing():
		return
	var playback := audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frames := playback.get_frames_available()
	for i in range(frames):
		var click := 0.0
		var sample_in_period := int(_phase * 48000.0 / (2.0 * PI)) % 24000
		if sample_in_period < 48:
			click = sin(float(sample_in_period) * 2.0 * PI * 1000.0 / 48000.0) * 0.5
			click *= 1.0 - float(sample_in_period) / 48.0
		playback.push_frame(Vector2(click, click))
		_phase += 2.0 * PI / 48000.0
		if _phase > 2.0 * PI:
			_phase -= 2.0 * PI
