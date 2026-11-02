extends Node3D
## Scène principale du royaume.

var player: Player
var rig: CameraRig
var _inside := false

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	Ambiance.setup(self)
	Terrain.build(self)
	Roads.build(self)
	Castle.build(self)
	if ClassDB.class_exists("Node"):
		Town.build(self)
		Fields.build(self)
		Places.build(self)
	Vegetation.build(self)
	print("monde construit en ", Time.get_ticks_msec() - t0, " ms")

	player = Player.new()
	player.name = "Joueur"
	var start := Vector2(0, -60)
	var args := OS.get_cmdline_user_args()
	player.position = Vector3(start.x, Layout.height(start.x, start.y) + 0.3, start.y)
	player.rotation.y = PI   # regarde vers le château (nord)
	add_child(player)
	rig = CameraRig.new()
	rig.target = player
	add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	var tc := TouchControls.new()
	tc.player = player
	tc.rig = rig
	ui.add_child(tc)
	var zone := find_child("ZoneDonjon", true, false) as Area3D
	if zone:
		zone.body_entered.connect(func(b): if b == player: _set_inside(true))
		zone.body_exited.connect(func(b): if b == player: _set_inside(false))
	if args.size() > 0 and args[0] == "--tour":
		var tour = load("res://scripts/tools/tour.gd").new()
		tour.world = self
		add_child(tour)

func _set_inside(v: bool) -> void:
	_inside = v
	rig.inside = v
	for l in Castle.interior_lights:
		l.visible = v
