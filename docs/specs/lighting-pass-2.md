# Spec: Lighting pass 2 (night lights and shadows, wet ground, rain, mist, bloom, grade; day sun, water, clouds, ambient motion)

Status: **v0.2, implemented 2026-10-16 from the user's two lighting briefs (night/rain and daylight); manual checks (look, mood, feel) are the user's.** Presentation only: no rule, stat, spawn or balance changes; the camera stays the fixed 2:1 isometric view. Builds on [environment.md](environment.md) (DayNight, Atmosphere, glows) and [art-pack-2.md](art-pack-2.md) (SceneryShadows).

## Purpose
The first night and day passes tinted the world and added light pools and ground shadows. The result still reads flat: lights do not flicker or get blocked by walls, wet ground does not reflect, rain ignores the lamps, there is no mist, no bloom, no grade, the area outside the map is grey, and the day has no cloud, water or wind motion.

## Decisions
1. **Lights are not `PointLight2D`.** They were measured at 9 to 18 FPS against ~80 on the dressed map (every sprite is redrawn once per light). Lights stay additive pools (`LightField`), but become real-time in the sense that matters: they flicker, are culled to the screen, capped, receive short flashes from muzzle and explosion events, and are **occluded by walls, buildings and towers** (shadow volumes built once per light and caster, drawn with the SUB blend so they cancel exactly that light's pool).
2. **One finishing overlay (`PostFx`)**: ambient mist, cloud shadows, sun gradient, map-edge haze into the sky colour and vignette, composed into one premultiplied overlay that does not read the screen and is drawn at quarter size in a sub-viewport. **Changed from v0.1 (measured):** reading the finished picture to do real bloom of the brightest pixels and a luminance-keyed teal-orange grade costs 14 ms per frame on the MX330 even for a pass that does nothing else, so that version (`post_fx.gdshader`) is kept behind `LightingConfig.SCREEN_PASS` (off). With it off, wide faint halos around bright lights stand in for bloom, and the teal-orange look comes from the cool ambient tint (shadows) and the warm light colours (highlights) plus a constant lift. A true LUT texture was never built: the grade is parametric either way.
3. **One ground shader** on the terrain layer does everything that depends on which terrain a pixel is: wet darkening, puddles, lamp reflections (4 nearest lights) and rain ripples on the slick terrains (asphalt, runway, steel), water shimmer and sparkles, and low-frequency variation that breaks up the tile checker. The terrain row is read from the tile's atlas UV (verified). Noise comes from one shared texture (`LightingNoise`), not from per-pixel maths.
4. **Every number is a constant in `LightingConfig`** (`scripts/battle/lighting_config.gd`), documented there.
5. **The grey background goes away:** the viewport clear colour follows the time of day (dark navy mist at night, pale sky by day) and the map edge fades into it.

## Scope
Night: ambient (cool blue multiply, kept readable, see art-pack-2 night luminance guard), warm flickering lights on every floodlight, tower lamp, street lamp and fire; light blocked by walls; bloom; wet specular and ripples on runway, asphalt, concrete, paving; two rain layers (near, far) whose drops brighten near lights; drifting ground mist; muzzle and explosion flashes that light nearby ground and units; vignette; teal and orange grade; dark fade at the map edge.
Day: sun direction fixed upper-left (ground +x, screen down-right), blue-tinted soft shadows that lengthen toward dawn and dusk (also for units and aircraft: `IsoShadow`), contact darkening (ambient occlusion) under pieces, a gentle light gradient across the map, animated water (scroll, sparkle, foam edge on the banks), slow cloud shadows, haze toward the map edges and vignette, a light warm-highlight and cool-shadow grade, tree sway, smoke from burning pieces, occasional dust puffs near moving units. All of it blends by `DayNight` (time of day), so the same parameters give dusk and night.

## Design
- `DayNight` gains pure functions: `shadow_scale_at(t)`, `sky_at(t)` (clear colour / haze colour), `grade_at(t)` (shadow and highlight tint strengths). Tested.
- `LightingConfig`: constants for every effect (strengths, radii, counts, speeds, caps).
- `LightField` (replaces the inner `GlowLayer`; node name `Glows` and `visible` semantics kept): static lights from scenery glows, dynamic flashes, flicker (`flicker_at(kind, phase, t)` pure), cap `MAX_LIGHTS` nearest to the camera centre, off-screen cull, shadow volumes via `LightShadows` (pure geometry, tested).
- `PostFx`: CanvasLayer 4 + ColorRect with `assets/shaders/post_fx.gdshader`; camera transform uniforms each frame; light positions for bloom are not needed (bloom is threshold based).
- `WeatherView`: rain in two parallax layers (far: short, slow, faint; near: long, fast, brighter), streaks within a light's radius are drawn brighter; fog and dust unchanged.
- Ground: `assets/shaders/ground.gdshader` on the `Ground` TileMapLayer; per terrain-row wetness table; up to `GROUND_LIGHTS` nearest lights as reflections. `ShoreFoam` draws animated foam along water cells that border land.
- `SceneryShadows`: colour and length from `DayNight`, contact AO ellipses. `IsoShadow`: blue-tinted dark colour.
- `AmbientFx`: smoke puffs at burning pieces near the camera and dust puffs behind moving units, hard-capped.
- Trees sway with `assets/shaders/sway.gdshader` (shared material, per-sprite phase) on scenery whose definition has `sway > 0`.

## Result (2026-10-16)
Implemented as above; 527 tests, two failing that belong to another session's uncommitted deck work (`test_deck_state.gd`, draw-cap timer). Frame rate: see BALANCE.md; the 60 FPS base-view target is met only on a quiet machine (43 to 50 FPS measured on a loaded one against 71 to 77 with the pass off). The `FPS 1` in the user's screenshot is the first frame after load, before the counter has averaged anything. Not done on purpose: real `PointLight2D`, a true LUT texture, normal maps, per-unit lamp shadows.

## Non-goals
Real `PointLight2D` or normal-mapped lighting, per-unit dynamic shadows from lamps, volumetric light cones, god rays, a true 3D LUT texture, changes to the simulation, new art.

## Acceptance criteria
1. Everything is presentation: the simulation tests and the x2 balance sweep results do not change.
2. `LightingConfig` holds every tunable; no magic numbers for these effects elsewhere.
3. Pure functions are tested: flicker range and determinism, light selection (cap, nearest first, culling), shadow volume geometry (away from the light, empty for low pieces, none for the light's own piece), `DayNight` additions (continuous, bounds), config sanity (positive caps).
4. A battle still builds with the atmosphere in headless runs (no errors, shaders load); full test suite passes.
5. Frame rate of `tools/perf_world.gd` (windowed 1920x1080, night rain, 400 enemies): base view >= 60 FPS average and the whole-map view not worse than before this pass (baseline 72 and 51 FPS measured 2026-10-16, machine not quiet); measured and recorded in BALANCE.md.
6. Screenshots (tools/shots.gd) of day, dusk and night show the effects listed above.
7. Manual (user): mood, flicker speed and strength, whether lights read as warm and clean, bloom amount, wet look, rain brightening, mist level, sway amount, smoke and dust amounts, and whether any of it is distracting.

## Risks
- Fill-rate on the MX330: a screen-reading pass costs 14 ms (see decision 2); the ground shader's wet branch was the other hot spot (21 ms before the noise texture, about 5 ms after). Numbers in BALANCE.md; `--off=` on `tools/perf_world.gd` prices each part.
- SUB-blend shadows are approximate where several lights overlap and where the 8-bit buffer saturates; accepted, tunable (`SHADOW_STRENGTH`).
- Reading the terrain row from the atlas UV depends on how Godot passes UV to TileMapLayer shaders; verified by screenshot and a fallback of "dry".
