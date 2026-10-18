class_name BattleFeedback
extends Node
## Presentation layer for a battle: reacts to BattleController signals with flashes, sparks, recoil,
## tracers, death collapse, camera shake and sounds. It only reads signals and never changes rules,
## so the simulation is identical with or without it.

const FLASH_HIT_S: float = 0.06
const FLASH_CORE_S: float = 0.14
const CORE_SHAKE_PX: float = 3.0
const BLAST_SHAKE_PX: float = 2.5
const BLAST_SHAKE_S: float = 0.18
const SPARK_BLAST := Color(1.0, 0.7, 0.3)
const CORE_SHAKE_S: float = 0.15
const ALERT_MIN_INTERVAL_S: float = 1.0
const CRATER_MIN_RADIUS: float = 1.7  # blasts at least this wide (tiles) leave a crater

const HIT_FLASH: Color = Color(2.6, 2.6, 2.6)  # >1 brightens toward white
const CORE_FLASH: Color = Color(1.9, 0.45, 0.4)
const SPARK_ENEMY: Color = Color(0.85, 1.0, 0.45)
const SPARK_UNIT: Color = Color(1.0, 0.55, 0.3)
const SPARK_CORE: Color = Color(0.9, 0.95, 1.0)

var sfx: SfxService
var music: MusicService
var shake: CameraShake

var _battle: BattleController
var _fx: Node2D
var _last_alert_s: float = -100.0


func bind(battle: BattleController) -> void:
	_battle = battle
	_fx = battle.fx_layer()
	sfx = SfxService.new()
	sfx.name = "Sfx"
	add_child(sfx)
	music = MusicService.new()
	music.name = "Music"
	add_child(music)
	music.play("battle")
	battle.battle_ended.connect(func(res: MissionRules.Result) -> void: music.sting("victory" if res.status == MissionRules.Status.WON else "defeat"))
	shake = CameraShake.new()
	shake.name = "Shake"
	shake.camera = battle.camera_node()
	add_child(shake)
	battle.shot_fired.connect(_on_shot)
	battle.hit_landed.connect(_on_hit)
	battle.enemy_died.connect(_on_enemy_died)
	battle.unit_died.connect(_on_unit_died)
	battle.blast_landed.connect(_on_blast)
	battle.projectile_launched.connect(_on_projectile_launched)
	battle.enemy_attacked.connect(_on_enemy_attacked)


## The thunder of a lightning strike, a moment after the flash (the further the strike, the longer the wait).
func on_thunder(delay_s: float) -> void:
	if is_inside_tree():
		get_tree().create_timer(delay_s).timeout.connect(func() -> void: sfx.play("thunder", 0.05))


func _on_shot(shooter: BattleUnit, target: BattleEnemy) -> void:
	var from := shooter.muzzle_world()
	var to := target.chest_world()
	Tracer.spawn(_fx, from, to)
	target.stagger(to - from)
	MuzzleFlash.spawn(_fx, from, to - from)
	shooter.kick(to - from)
	sfx.play(shooter.weapon.sfx_id)


func _on_hit(target: Node, _amount: float) -> void:
	if target is BattleEnemy:
		var e := target as BattleEnemy
		ImpactSpark.spawn(_fx, e.chest_world(), SPARK_ENEMY)
		e.flash(HIT_FLASH, FLASH_HIT_S)
		sfx.play("impact")
	elif target is BattleUnit:
		var u := target as BattleUnit
		ImpactSpark.spawn(_fx, u.chest_world(), SPARK_UNIT)
		u.flash(HIT_FLASH, FLASH_HIT_S)
		sfx.play("impact")
	elif target is BattleCore:
		var c := target as BattleCore
		ImpactSpark.spawn(_fx, c.chest_world(), SPARK_CORE)
		c.flash(CORE_FLASH, FLASH_CORE_S)
		shake.trigger(CORE_SHAKE_PX, CORE_SHAKE_S)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_alert_s >= ALERT_MIN_INTERVAL_S:
			_last_alert_s = now
			sfx.play("alert", 0.0)


func _on_enemy_died(enemy: BattleEnemy) -> void:
	if GroundMark.leaves_blood(enemy.ground_pos):
		var variant := int(GroundMark.unit_hash(enemy.ground_pos * 3.1) * float(GroundMark.VARIANTS)) % GroundMark.VARIANTS
		GroundMark.spawn(_battle.decal_layer(), enemy.ground_pos, GroundMark.BLOOD, variant)
	DeathPuff.spawn(_fx, enemy.position)
	sfx.play("death")


func _on_unit_died(unit: BattleUnit) -> void:
	var sheet := unit.def.sprite
	if sheet != null and sheet.explosion_px > 0.0:
		# Vehicles and emplacements blow up (after the fall, for aircraft) instead of dropping a dust puff.
		var at := IsoProjection.ground_to_screen(unit.ground_pos) + Vector2(0, -sheet.chest_px)
		var delay := sheet.fall_time_s()
		VehicleExplosion.spawn(_fx, at, sheet.explosion_px, delay)
		ScorchMark.spawn(_battle.decal_layer(), unit.ground_pos, clampf(sheet.explosion_px / 40.0, 0.4, 1.0), delay)
		if delay > 0.0 and is_inside_tree():
			get_tree().create_timer(delay).timeout.connect(_explosion_bang)
		else:
			_explosion_bang()
		return
	DeathPuff.spawn(_fx, unit.position)
	sfx.play("impact" if unit.def.structure else "death")


func _explosion_bang() -> void:
	sfx.play("explosion")
	shake.trigger(BLAST_SHAKE_PX, BLAST_SHAKE_S)


func _on_blast(center: Vector2, radius: float) -> void:
	Explosion.spawn(_fx, center, radius)
	if radius >= CRATER_MIN_RADIUS:  # a big blast burns the ground and leaves a crater
		ScorchMark.spawn(_battle.decal_layer(), center, radius * 0.5)
		GroundMark.spawn(_battle.decal_layer(), center, GroundMark.CRATER, GroundMark.crater_variant(radius))
	var pos := IsoProjection.ground_to_screen(center)
	for k in 8:
		ImpactSpark.spawn(_fx, pos, SPARK_BLAST)  # flying debris
	sfx.play("blast")
	shake.trigger(BLAST_SHAKE_PX, BLAST_SHAKE_S)


func _on_enemy_attacked(enemy: BattleEnemy, target: Node) -> void:
	if enemy.def.spits and target is IsoEntity:
		AcidSpit.spawn(_fx, enemy.mouth_world(), (target as IsoEntity).chest_world())


func _on_projectile_launched(shooter: BattleUnit, weapon: WeaponDefinition, from_ground: Vector2, target_ground: Vector2) -> void:
	var from := IsoProjection.ground_to_screen_z(from_ground, shooter.altitude) + Vector2(0, -6)  # the pylon, below the body
	var to := IsoProjection.ground_to_screen(target_ground)
	MuzzleFlash.spawn(_fx, from, to - from)
	DeathPuff.spawn(_fx, from + Vector2(0, 4))  # launch smoke
	shooter.kick(to - from)
	sfx.play(weapon.sfx_id)

