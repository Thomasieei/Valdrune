class_name AnimRetarget
## Adapte les animations humaines (UAL1/UAL2, squelette Quaternius universel) aux créatures du Bestiary,
## qui partagent les mêmes noms d'os mais pas les mêmes proportions :
## on ne garde que les rotations, et la translation du bassin est mise à l'échelle de la créature.

static var _cache := {}

static func library(src: AnimationLibrary, skel: Skeleton3D, key: String, keep: Array) -> AnimationLibrary:
	var ck := key + "|" + str(src.get_instance_id())
	if _cache.has(ck):
		return _cache[ck]
	var pelvis := skel.find_bone("pelvis")
	var ratio := 1.0
	if pelvis >= 0:
		ratio = skel.get_bone_global_rest(pelvis).origin.y / 0.9167   # bassin humain UAL
	var out := AnimationLibrary.new()
	for name in src.get_animation_list():
		if not keep.is_empty() and not (name in keep):
			continue
		var a: Animation = src.get_animation(name).duplicate(true)
		var t := a.get_track_count() - 1
		while t >= 0:
			var path := String(a.track_get_path(t))
			var bone := path.get_slice(":", 1)
			var ty := a.track_get_type(t)
			if ty == Animation.TYPE_SCALE_3D or (ty == Animation.TYPE_POSITION_3D and bone != "pelvis"):
				a.remove_track(t)
			elif ty == Animation.TYPE_POSITION_3D and bone == "pelvis":
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, v * ratio)
			elif skel.find_bone(bone) < 0 and bone != "":
				a.remove_track(t)
			t -= 1
		out.add_animation(name, a)
	_cache[ck] = out
	return out
