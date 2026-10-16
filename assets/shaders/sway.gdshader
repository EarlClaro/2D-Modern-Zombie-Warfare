shader_type canvas_item;
// Wind in the trees: the top of the sprite leans left and right a pixel or two, the base stays put.
// One shared material; each piece has its own phase (from where it stands) and strength (SceneryDefinition.sway).

instance uniform float sway_amount = 1.0;
uniform float amplitude = 1.6;
uniform float speed = 1.3;
uniform float full_height_px = 64.0;  // the height at which the lean is at its full amplitude

void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].y * 0.007;
	float top = clamp(-VERTEX.y / full_height_px, 0.0, 1.0);
	top *= top;
	float gust = 0.7 + 0.3 * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += sin(TIME * speed + phase) * amplitude * sway_amount * top * gust;
}
