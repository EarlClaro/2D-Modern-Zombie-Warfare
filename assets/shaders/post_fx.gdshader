shader_type canvas_item;
// Full-screen finishing pass of the battle (docs/specs/lighting-pass-2.md): ground mist, cloud shadows, sun gradient,
// map-edge haze, bloom of the brightest pixels, split-toned colour grade (a parametric LUT), vignette.
// Every value comes from LightingConfig through PostFx; nothing here is a design decision.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;  // tileable noise, about four blobs across (LightingNoise)

uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 world_origin = vec2(0.0);  // world px under the screen's top-left corner
uniform float world_per_px = 1.0;       // world px per screen px (1 / zoom)
uniform vec4 world_to_ground = vec4(1.0, 0.0, 0.0, 1.0);  // ground.x = dot(world, xy), ground.y = dot(world, zw); from IsoProjection.screen_to_ground
uniform vec2 map_size = vec2(64.0, 48.0);  // ground tiles

uniform float darkness = 0.0;
uniform vec3 sky_color : source_color = vec3(0.6, 0.7, 0.85);

uniform float bloom_threshold = 0.72;
uniform float bloom_strength = 0.5;
uniform float bloom_radius = 7.0;

uniform float vignette = 0.3;
uniform float vignette_start = 0.55;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec3 shadow_tone = vec3(0.0);
uniform vec3 high_tone = vec3(0.0);

uniform float mist_strength = 0.1;
uniform vec3 mist_color : source_color = vec3(0.5, 0.6, 0.78);
uniform float mist_scale = 11.0;
uniform vec2 mist_velocity = vec2(0.35, 0.12);

uniform float cloud_strength = 0.2;
uniform float cloud_scale = 26.0;
uniform vec2 cloud_velocity = vec2(0.45, 0.2);

uniform float sun_gradient = 0.07;
uniform float edge_fade = 7.0;
uniform float edge_strength = 0.88;
uniform float edge_outside = 4.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	return texture(noise_tex, p / 4.0).r;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;

	vec2 world = world_origin + uv * view_size * world_per_px;
	vec2 ground = vec2(dot(world, world_to_ground.xy), dot(world, world_to_ground.zw));

	// --- bloom: only what is brighter than the threshold, two rings of taps ---
	if (bloom_strength > 0.0) {
		vec2 px = 1.0 / view_size;
		vec3 acc = vec3(0.0);
		// eight taps on a ring, alternating two radii: a soft halo for the cost of nine reads
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 d = vec2(cos(a), sin(a)) * bloom_radius * (1.0 + 1.2 * float(i % 2));
			acc += max(texture(screen_tex, uv + d * px).rgb - bloom_threshold, 0.0);
		}
		col += acc * (bloom_strength / 6.0);
	}

	// --- sun (or moon) gradient across the map: the upper-left, ground -x side, is brighter ---
	float side = clamp((map_size.x * 0.5 - ground.x) / (map_size.x * 0.5), -1.0, 1.0);
	col *= 1.0 + sun_gradient * side * (1.0 - 0.6 * darkness);

	// --- cloud shadows drift over the ground by day ---
	if (cloud_strength > 0.0) {
		float n = noise(ground / cloud_scale + cloud_velocity * TIME / cloud_scale);
		float c = smoothstep(0.5, 0.78, n);
		col *= 1.0 - cloud_strength * c * (1.0 - darkness);
	}

	// --- ground mist, low contrast, drifting ---
	if (mist_strength > 0.0) {
		float m = noise(ground / mist_scale + mist_velocity * TIME / mist_scale);
		float m2 = noise(ground / (mist_scale * 0.45) - mist_velocity * 1.7 * TIME / mist_scale + 0.37);
		float amount = mist_strength * smoothstep(0.25, 0.8, m * 0.7 + m2 * 0.3);
		col = mix(col, mist_color * (0.35 + 0.65 * (1.0 - darkness)), amount);
	}

	// --- the map edge fades into the sky colour; beyond it the fade releases so aircraft stay visible ---
	float inside = min(min(ground.x, ground.y), min(map_size.x - ground.x, map_size.y - ground.y));
	float edge = 1.0 - smoothstep(0.0, edge_fade, inside);
	if (inside < 0.0) {
		edge *= 1.0 - smoothstep(0.0, edge_outside, -inside);
	}
	col = mix(col, sky_color, edge * edge_strength);

	// --- colour grade: split toning, a little saturation and contrast ---
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col += shadow_tone * (1.0 - smoothstep(0.0, 0.55, l));
	col += high_tone * smoothstep(0.35, 0.95, l);
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;

	// --- vignette ---
	vec2 q = (uv - 0.5) * vec2(view_size.x / view_size.y, 1.0);
	float vd = length(q) / length(vec2(0.5 * view_size.x / view_size.y, 0.5));
	col *= 1.0 - vignette * smoothstep(vignette_start, 1.05, vd);

	// a trace of noise hides banding in the dark gradients
	col += (hash21(FRAGCOORD.xy + fract(TIME)) - 0.5) * 0.012;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
