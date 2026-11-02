extends Node3D
func _ready() -> void:
	Ambiance.setup(self)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm; add_child(g)
	var ual: Node = load("res://assets/anims/UAL1_Standard.glb").instantiate()
	var hs: Skeleton3D = ual.get_node("Armature/Skeleton3D")
	print("human pelvis y=", hs.get_bone_global_rest(hs.find_bone("pelvis")).origin.y)
	var lib1: AnimationLibrary = (ual.get_node("AnimationPlayer") as AnimationPlayer).get_animation_library("")
	var anim := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "Walk"
	var i := 0
	for p in ["res://assets/monsters/Imp.glb", "res://assets/monsters/Puglin.glb"]:
		var m: Node3D = load(p).instantiate()
		add_child(m)
		m.position = Vector3(-3 + i * 2.5, 0, 0)
		var sk: Skeleton3D = m.get_node("Armature/Skeleton3D")
		print(p, " pelvis y=", sk.get_bone_global_rest(sk.find_bone("pelvis")).origin.y)
		var ap := AnimationPlayer.new(); m.add_child(ap)
		ap.add_animation_library("", AnimRetarget.library(lib1, sk, p, []))
		ap.play(anim); ap.seek(0.4, true)
		i += 1
	var z := CharBuilder.build({"outfit": "paysan_h", "hair": "Hair_Buzzed", "tint": Color(0.6, 0.7, 0.55)})
	z.position = Vector3(2.5, 0, 0); add_child(z)
	(z.get_node("AnimationPlayer") as AnimationPlayer).play("b/Zombie_Walk_Fwd"); 
	var m1: Node3D = load("res://assets/monsters/Monster01_AllAnim.fbx").instantiate()
	m1.position = Vector3(5, 0, 0); add_child(m1)
	var ap1: AnimationPlayer = m1.find_child("AnimationPlayer", true, false)
	print(ap1.get_animation_list())
	ap1.play("Monster01_Walk")
	var cam := Camera3D.new(); cam.position = Vector3(1, 1.6, 7); add_child(cam); cam.look_at(Vector3(1, 0.9, 0)); cam.current = true
	for f in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/monstres_%s.png" % anim); get_tree().quit()
