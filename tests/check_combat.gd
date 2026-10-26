extends Node3D
var failures: Array[String] = []
var player: Player

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func enemy_at(at: Vector3, type := "rusher") -> Enemy:
	var enemy := WaveDirector.make_enemy(StringName(type))
	enemy.position = at
	enemy.target = player
	enemy.dummy = true
	add_child(enemy)
	enemy._activate()
	enemy.health = 1000
	enemy.max_health = 1000
	return enemy

func gun(id: String) -> Weapon:
	var weapon := Arsenal.make(id)
	weapon.camera = player.camera
	weapon.wielder = player
	weapon.fx_parent = self
	player.camera.add_child(weapon)
	weapon._raise = 0
	return weapon

func _ready() -> void:
	if not Progress.isolated:
		get_tree().quit(1)
		return
	player = Player.new()
	player.build = {"guns": Arsenal.DEFAULT, "grenade": "frag", "effects": {}}
	add_child(player)
	player.set_physics_process(false)
	player.camera.position.y = -0.95 # Aim through the low rusher hitboxes.
	var first := enemy_at(Vector3(0, 0, -4))
	var second := enemy_at(Vector3(0, 0, -8))
	var behind := enemy_at(Vector3(0, 0, -16))
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 0, -12)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 1)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	var rail := gun("railgun")
	rail._fire()
	check(first.health < 1000 and second.health < 1000 and behind.health == 1000, "rail penetrates enemies but stops at wall")
	var a := first.health
	var b := second.health
	var arc := gun("arc")
	arc._fire()
	check(is_equal_approx(a - first.health, arc.damage) and is_equal_approx(b - second.health, arc.damage), "arc visits each target once")
	check(behind.health == 1000, "arc cannot chain through wall")
	var burst := gun("burst")
	for i in 50:
		burst.tick(0.02, i < 2, false, false)
	check(burst.mag == burst.mag_size - 3, "tap emits exactly one three-shot burst")
	var charged := gun("railgun")
	for i in 20:
		charged.tick(0.02, true, false, false)
	charged.tick(0.02, false, false, false)
	check(charged.mag == charged.mag_size, "short rail hold cancels without ammunition loss")
	for i in 40:
		charged.tick(0.02, true, false, false)
	check(charged.mag == charged.mag_size - 1, "charged rail consumes one round")
	var shield := enemy_at(Vector3(8, 0, -4), "shield") as ShieldRobot
	var front := shield.global_position - shield._body.global_basis.z * 3.0
	Combat.hit(shield, 100, -1, &"rifle", front, player, {})
	check(is_equal_approx(shield.health, 965), "frontal shield mitigates")
	Combat.hit(shield, 100, -1, &"rifle", shield.global_position + shield._body.global_basis.z * 3.0, player, {})
	check(is_equal_approx(shield.health, 865), "rear shield exposure")
	shield.apply_emp(2, 1)
	Combat.hit(shield, 100, -1, &"rifle", front, player, {})
	check(is_equal_approx(shield.health, 765) and shield.shield_disabled == 3.0, "EMP disrupts shield")
	var boss := enemy_at(Vector3(15, 0, -4), "boss")
	boss.apply_emp(3.0, 0)
	check(boss._stagger_left == 0.0 and boss.slow_left > 0.0, "EMP slows rather than stuns boss")
	var field := Ordnance.new()
	field.kind = &"incendiary"
	field.position = Vector3(0, 0.1, -4)
	field.player = player
	field.effects = {"burn_slow": 3}
	add_child(field)
	a = first.health
	field._burn()
	field._burn()
	check(is_equal_approx(a - first.health, 9.0), "overlapping burns do not multiply damage")
	check(first.slow_factor < 1.0, "burn slow effect")
	a = behind.health
	Combat.explode(self, Vector3(0, 1, -10), &"frag", player, {}, 10.0)
	check(behind.health == a, "cover blocks blast")
	var support := enemy_at(Vector3(2, 0, -4), "support") as SupportRobot
	first.health = 500
	second.health = 1000
	shield.health = 1000
	support._act(0.3, Vector3(0, 0, 4))
	check(first.health == 506, "support repairs visible wounded ally")
	var other_support := enemy_at(Vector3(2, 0, -5), "support")
	other_support.health = 10
	first.health = 1000
	behind.health = 1
	support._act(0.3, Vector3(0, 0, 4))
	check(other_support.health == 10 and behind.health == 1, "support excludes supports and occluded allies")
	player._grenade_input(0.016)
	Input.action_press("grenade")
	player._grenade_input(0.016)
	check(player._preview, "grenade hold previews")
	player.cancel_grenade()
	Input.action_release("grenade")
	player._grenade_input(0.016)
	check(player.grenades == 2, "preview cancellation preserves supply")
	Input.action_press("grenade")
	player._grenade_input(0.016)
	Input.action_release("grenade")
	player._grenade_input(0.016)
	check(player.grenades == 1, "preview release throws once")
	var before := field.fuse
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(field.fuse == before, "pause freezes ordnance fuse")
	get_tree().paused = false
	print("COMBAT: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
