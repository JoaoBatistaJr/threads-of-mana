class_name CameraFade
extends RefCounted

static var _done: Dictionary = {}


static func apply(root: Node, invisible_below: float, opaque_above: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var key: int = mesh.get_instance_id()
		if _done.has(key):
			continue
		_done[key] = true
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as BaseMaterial3D
			if m == null:
				continue
			var d := m.duplicate() as BaseMaterial3D
			d.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			d.distance_fade_min_distance = invisible_below
			d.distance_fade_max_distance = opaque_above
			mesh.surface_set_material(s, d)
