shader_type canvas_item;
// The ground layer (docs/specs/lighting-pass-2.md): wet sheen with lamp reflections and rain ripples on roads,
// runways and concrete; shimmer and sparkles on water; and a low-frequency brightness variation that breaks up the
// repeating tile look. The terrain of a pixel comes from its row in the atlas (UV.y over the whole atlas).
// Numbers come from LightingConfig through GroundLook.

uniform float row_count = 33.0;
uniform float wet[64];     // 0 dry .. 1 slick, per atlas row
uniform float water[64];   // 1 for water rows
uniform float rain = 0.0;  // 0 .. 1: how hard it rains; wet ground is the row's wettability times this
uniform float darkness = 0.0;
uniform vec3 sky_color : source_color = vec3(0.6, 0.7, 0.85);

uniform float variation = 0.07;
uniform float variation_px = 240.0;

uniform float reflection_strength = 0.5;
uniform float reflection_streak = 3.2;
uniform int light_count = 0;
uniform vec4 light_a[4];  // xy: pool centre (world px), z: pool radius px, w: brightness
uniform vec4 light_b[4];  // rgb: colour

uniform float ripple_cell = 26.0;
uniform float ripple_period = 1.3;
uniform float ripple_strength = 0.5;

uniform float shimmer = 0.12;
uniform float sparkle = 0.7;
uniform vec2 scroll = vec2(0.06, 0.03);

uniform sampler2D noise_tex : filter_linear, repeat_enable;  // tileable noise, about four blobs across (LightingNoise)

varying vec2 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// one read of the shared noise: `blob_px` is the size of a blob in world px
float noise(vec2 p, float blob_px) {
	return texture(noise_tex, p / (blob_px * 4.0)).r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	int row = clamp(int(floor(UV.y * row_count)), 0, 63);
	float is_water = water[row];
	float w = wet[row];
	vec3 col = base.rgb;

	// brightness variation: slow, world-space, so neighbouring tiles of one kind no longer look stamped
	float v = noise(world_pos, variation_px) - 0.5;
	col *= 1.0 + variation * 2.0 * v * (1.0 - is_water);

	if (is_water > 0.5) {
		vec2 q = floor(world_pos / 2.0);
		float s1 = noise(world_pos + scroll * TIME * 64.0, 38.0);
		float s2 = noise(world_pos - scroll.yx * TIME * 90.0 + 41.0, 17.0);
		float band = smoothstep(0.62, 0.78, s1 * 0.6 + s2 * 0.4);
		col += vec3(0.5, 0.7, 0.85) * band * shimmer * 2.0;
		float phase = floor(TIME * 2.5 + hash21(q) * 6.0);
		float spark = step(0.992, hash21(q + phase * 0.37));
		col += vec3(1.0) * spark * sparkle * (0.5 + 0.5 * band);
		col = mix(col, sky_color, 0.06 * (1.0 - darkness));
	} else if (w > 0.01 && rain > 0.0) {
		float wetness = clamp(w * rain, 0.0, 1.0);
		// wet ground is darker; the slick surfaces (asphalt, runway, steel) also hold puddles, ripples and reflections
		col *= 1.0 - 0.16 * wetness;
		if (w > 0.5) {
			float puddle = smoothstep(0.52, 0.72, noise(world_pos + 90.0, 110.0)) * wetness;
			col = mix(col, mix(col, sky_color * 0.55, 0.5), puddle * 0.45);
			vec3 refl = vec3(0.0);
			float ripple_n = 0.55 + 0.45 * noise(vec2(world_pos.x * 3.0, world_pos.y - TIME * 22.0), 21.0);
			for (int i = 0; i < 4; i++) {
				if (i >= light_count) {
					break;
				}
				vec2 d = world_pos - light_a[i].xy;
				float r = light_a[i].z;
				if (abs(d.x) > r || d.y > r || d.y < -0.4 * r) {
					continue;  // outside this light's pool and streak: nearly every pixel leaves here
				}
				// the bulb's reflection is a streak that hangs down the screen from the base of the lamp
				float across = d.x / (r * 0.16);
				float along = d.y / (r * 0.16 * reflection_streak);
				float streak = exp(-across * across) * smoothstep(-0.4, 0.2, along) * (1.0 - smoothstep(0.5, 1.9, along));
				float pool = 1.0 - smoothstep(0.0, 1.0, length(vec2(d.x, d.y * 2.0)) / r);
				refl += light_b[i].rgb * light_a[i].w * (streak * ripple_n * 0.9 + pool * 0.25) * wetness * (0.5 + puddle);
			}
			col += refl * reflection_strength;
			if (puddle > 0.2) {  // rain rings on the standing water
				vec2 cell = floor(world_pos / ripple_cell);
				vec2 local = fract(world_pos / ripple_cell) - 0.5;
				vec3 rv = texture(noise_tex, cell * 0.173).rgb;
				float rnd = fract(rv.r * 7.31);
				float ph = fract(TIME / ripple_period + rnd);
				local.y *= 2.0;
				local += (vec2(fract(rv.r * 13.7), fract(rv.r * 29.3)) - 0.5) * 0.5;
				float ring = smoothstep(0.07, 0.0, abs(length(local) - ph * 0.42)) * (1.0 - ph);
				col += vec3(0.7, 0.8, 0.95) * ring * ripple_strength * rain * wetness * step(0.35, rnd);
			}
		}
	}
	COLOR = vec4(col, base.a);
}
