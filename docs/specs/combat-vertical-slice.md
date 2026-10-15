# Spec: Milestone 1 — Combat Vertical Slice

Status: draft; do not implement until Milestone 0.5 is approved.

## Purpose
Prove that core combat is satisfying and readable on the isometric view, with the fewest systems.

## Scope
- One small map (≈24x24 tiles): one base/core, one enemy spawn, one chokepoint.
- One fixed gun/soldier (`UnitDefinition` + `WeaponDefinition` resources) with targeting, firing, ammo-free.
- One zombie (Shambler) walking straight/along simple waypoint path to the core, attacking it on contact.
- Health component, `DamageService` (base damage, armor, blast falloff — pure, tested), death.
- Mission end: core health ≤ 0 → fail; survive N seconds → win (ADR-007 resolution). Minimal result label.
- Feedback pass (placeholder-grade): muzzle flash, tracer or hitscan line, impact spark, hit flash, death response, shake-lite, placeholder sound with per-category concurrency cap.
- Projectile approach decision (hitscan for rifle; one arcing projectile prototype only if time allows), recorded in ARCHITECTURE.

## Non-goals
Cards, deck, multiple enemy types, flow field, save, progression, final art/audio.

## Data model (draft)
`UnitDefinition{id, display_name, max_health, footprint_radius, height_class, weapon_ids[]}`, `WeaponDefinition{id, damage, damage_type, fire_rate, range, projectile_kind, blast_radius, ...}`, `EnemyDefinition{id, max_health, speed, armor, attack_damage, attack_rate}`, `MissionDefinition{id, duration, core_health, spawn_points, waves[]}`.

## Interactions
Targeting picks nearest valid enemy in ground range (tie-break: lowest id). Damage applied by `DamageService`. Death emits `died`. Mission director listens to `core_destroyed` and timer.

## Failure cases
No targets → idle; target dies mid-shot → retarget; zero/negative stats rejected by definition validation; mission ends once.

## Acceptance criteria
1. Automated: damage/armor/falloff math, targeting selection & invalid targets, health/death, mission win/fail & same-tick tie → fail.
2. Headless import clean; scene launches headless for N frames without errors.
3. Manual: shots visibly originate at the gun and reach targets; enemies react; kills are legible with 20+ zombies; user judges "satisfying" (go/no-go).
4. Performance baseline recorded (zombies count, FPS, machine) in BALANCE/TESTING — no claims beyond measured.
