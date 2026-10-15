class_name BattleFeedback
extends Node
## Presentation layer for a battle: reacts to BattleController signals with flashes, sparks, recoil,
## tracers, death collapse, camera shake and sounds. It only reads signals and never changes rules,
## so the simulation is identical with or without it.

const FLASH_HIT_S: float = 0.06
const FLASH_CORE_S: float = 0.14
const CORE_SHAKE_PX: float = 3.0
const CORE_SHAKE_S: float = 0.15
const ALERT_MIN_INTERVAL_S: float = 1.0

const HIT_FLASH: Color = Color(2.6, 2.6, 2.6)  # >1 brightens toward white
const CORE_FLASH: Color = Color(1.9, 0.45, 0.4)
const SPARK_ENEMY: Color = Color(0.85, 1.0, 0.45)
const SPARK_UNIT: Color = Color(1.0, 0.55, 0.3)
const SPARK_CORE: Color = Color(0.9, 0.95, 1.0)

var sfx: SfxService
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
	shake = CameraShake.new()
	shake.name = "Shake"
	shake.camera = battle.camera_node()
	add_child(shake)
	battle.shot_fired.connect(_on_shot)
	battle.hit_landed.connect(_on_hit)
	battle.enemy_died.connect(_on_enemy_died)
	battle.unit_died.connect(_on_unit_died)


func _on_shot(shooter: BattleUnit, target: BattleEnemy) -> void:
	var from := shooter.muzzle_world()
	var to := target.chest_world()
	Tracer.spawn(_fx, from, to)
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
	DeathPuff.spawn(_fx, enemy.position)
	sfx.play("death")


func _on_unit_died(unit: BattleUnit) -> void:
	DeathPuff.spawn(_fx, unit.position)
	sfx.play("death")
