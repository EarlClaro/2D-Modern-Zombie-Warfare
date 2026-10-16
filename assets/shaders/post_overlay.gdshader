shader_type canvas_item;
render_mode blend_premul_alpha;
// The finishing pass without reading the screen (docs/specs/lighting-pass-2.md): mist, cloud shadows, a sun
// gradient, the map-edge fade into the sky and a vignette, all composed into ONE premultiplied overlay
// (result = overlay.rgb + picture * (1 - overlay.a)). Reading the finished picture (hint_screen_texture) copies the
// whole frame, which cost 14 ms per frame on the MX330 laptop; this costs almost nothing. The luminance-keyed
// effects (bloom of bright pixels, teal-and-orange grading) need that copy and live in post_fx.gdshader instead.

uniform sampler2D noise_tex : filter_linear, repeat_enable;  // tileable noise, about four blobs across (LightingNoise)

uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 world_origin = vec2(0.0);  // world px under the screen's top-left corner
uniform float world_per_px = 1.0;       // world px per screen px (1 / zoom)
uniform vec4 world_to_ground = vec4(1.0, 0.0, 0.0, 1.0);  // ground.x = dot(world, xy), ground.y = dot(world, zw)
uniform vec2 map_size = vec2(64.0, 48.0);  // ground tiles

uniform float darkness = 0.0;
uniform vec3 sky_color : source_color = vec3(0.6, 0.7, 0.85);
uniform vec3 shadow_tone = vec3(0.0);  // a constant lift: cool shadows by day, teal at night

uniform float vignette = 0.3;
uniform float vignette_start = 0.55;

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

float noise(vec2 p) {
	return texture(noise_tex, p / 4.0).r;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 world = world_origin + uv * view_size * world_per_px;
	vec2 ground = vec2(dot(world, world_to_ground.xy), dot(world, world_to_ground.zw));

	vec3 add = max(shadow_tone, vec3(0.0));  // premultiplied colour so far (only a lift: a negative tone cannot be drawn)
	float keep = 1.0;        // how much of the picture shows through so far

	// the far side of the map from the sun (or moon) is a little darker
	float side = clamp((map_size.x * 0.5 - ground.x) / (map_size.x * 0.5), -1.0, 1.0);
	float a = sun_gradient * (1.0 - side) * 0.5 * (1.0 - 0.6 * darkness);
	add *= 1.0 - a;
	keep *= 1.0 - a;

	// cloud shadows drift over the ground by day
	if (cloud_strength > 0.0) {
		float c = smoothstep(0.5, 0.78, noise(ground / cloud_scale + cloud_velocity * TIME / cloud_scale));
		a = cloud_strength * c * (1.0 - darkness);
		add *= 1.0 - a;
		keep *= 1.0 - a;
	}

	// ground mist, low contrast, drifting
	if (mist_strength > 0.0) {
		float m = noise(ground / mist_scale + mist_velocity * TIME / mist_scale);
		float m2 = noise(ground / (mist_scale * 0.45) - mist_velocity * 1.7 * TIME / mist_scale + 0.37);
		a = mist_strength * smoothstep(0.25, 0.8, m * 0.7 + m2 * 0.3);
		add = add * (1.0 - a) + mist_color * (0.35 + 0.65 * (1.0 - darkness)) * a;
		keep *= 1.0 - a;
	}

	// the map edge fades into the sky colour; beyond it the fade releases so aircraft stay visible
	float inside = min(min(ground.x, ground.y), min(map_size.x - ground.x, map_size.y - ground.y));
	float edge = 1.0 - smoothstep(0.0, edge_fade, inside);
	if (inside < 0.0) {
		edge *= 1.0 - smoothstep(0.0, edge_outside, -inside);
	}
	a = edge * edge_strength;
	add = add * (1.0 - a) + sky_color * a;
	keep *= 1.0 - a;

	// vignette
	vec2 q = (uv - 0.5) * vec2(view_size.x / view_size.y, 1.0);
	float vd = length(q) / length(vec2(0.5 * view_size.x / view_size.y, 0.5));
	a = vignette * smoothstep(vignette_start, 1.05, vd);
	add *= 1.0 - a;
	keep *= 1.0 - a;

	COLOR = vec4(add, 1.0 - keep);
}
