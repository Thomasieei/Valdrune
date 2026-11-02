extends Node3D
func _ready() -> void:
	Ambiance.setup(self)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm; add_child(g)
	var rots := [Vector3(-90, 0, 0), Vector3(90, 0, 90), Vector3(90, 0, 0), Vector3(180, 0, 0)]
	for i in rots.size():
		var c := CharBuilder.build({"hero": true, "outfit": "rodeur_h"})
		c.position = Vector3(-3 + i * 2.0, 0, 0)
		add_child(c)
		var ap: AnimationPlayer = c.get_node("AnimationPlayer")
		ap.play("b/Sword_Regular_A"); ap.seek(0.35, true); ap.pause()
		var skel: Skeleton3D = c.get_node("Armature/Skeleton3D")
		var att := BoneAttachment3D.new(); att.bone_name = "hand_r"; skel.add_child(att)
		var sp := Kit.dungeon(att, "Sword", Vector3.ZERO, 0.0, 1.0)
		sp.rotation_degrees = rots[i]
		var l := Label3D.new(); l.text = str(i); l.position = c.position + Vector3(0, 2.2, 0); l.font_size = 64; add_child(l)
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.6, 4.5); add_child(cam); cam.look_at(Vector3(0, 1.0, 0)); cam.current = true
	for f in 8: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/sword_test.png"); get_tree().quit()
