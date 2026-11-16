extends SceneTree
# Construit res://assets/anims.res : 1 seule librairie compressée, pistes "Skeleton3D:os"
const SRC = ["General","MovementBasic","MovementAdvanced","CombatMelee","CombatRanged","Special","Simulation","Tools"]
const LOOP = ["Idle","Walking","Running","Sneaking","Crawling","Crouching","Blocking","Aiming","Shooting","Spellcasting_Long","Chopping","Digging","Hammering","Sawing","Pickaxing","Lockpicking","Working","Holding","Push_Ups","Sit_Ups","Fishing_Idle","Fishing_Reeling","Fishing_Struggling","Spinning","Waving","Cheering"]
func _init():
	var lib := AnimationLibrary.new()
	for s in SRC:
		var sc = load("res://tools/anims_src/%s.glb" % s).instantiate()
		var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
		for n in ap.get_animation_list():
			if n == "T-Pose" or n == "RESET": continue
			var a: Animation = ap.get_animation(n).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := str(a.track_get_path(t))
				var bone := p.get_slice(":", 1)
				if bone == "": a.remove_track(t); continue
				a.track_set_path(t, NodePath("Skeleton3D:" + bone))
			var lp := false
			for k in LOOP: if n.contains(k): lp = true
			if n.ends_with("_Pose") or n.contains("Inactive"): lp = false
			a.loop_mode = Animation.LOOP_LINEAR if lp else Animation.LOOP_NONE
			lib.add_animation(n, a)
		sc.free()
	print("ANIMS ", lib.get_animation_list().size())
	print("PATH ", lib.get_animation("Idle_A").track_get_path(0))
	ResourceSaver.save(lib, "res://assets/anims.res", ResourceSaver.FLAG_COMPRESS)
	for c in ["Knight","Barbarian","Mage","Rogue","Rogue_Hooded"]:
		var s = load("res://assets/chars/%s.glb" % c).instantiate()
		var acc = []
		for n in s.get_node("Rig/Skeleton3D").get_children(): if n is BoneAttachment3D: acc.append(n.name)
		print(c, ": ", ", ".join(acc)); s.free()
	quit()
