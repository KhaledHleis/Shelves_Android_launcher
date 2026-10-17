shader_type sky;

// Slowly moving two-colour gradient. The colours come from the selected app's
// icon (see main.gd / icon_colors.gd), which is what gives every shelf its own
// mood with no setup.
//
// v0.6 adds the texture overlay on top of this (dots, mesh, Chladni figures).

uniform vec3 color_a : source_color = vec3(0.18, 0.14, 0.30);
uniform vec3 color_b : source_color = vec3(0.04, 0.05, 0.09);
uniform float speed = 0.05;
uniform float grain = 0.015;
uniform float spread = 1.05;

float blob(vec2 uv, vec2 centre, float radius) {
	return smoothstep(radius, 0.0, distance(uv, centre));
}

void sky() {
	// Derived from the view direction rather than SCREEN_UV: that one is only
	// valid in the main pass, and the compatibility renderer squeezes it.
	vec2 uv = EYEDIR.xy / max(abs(EYEDIR.z), 0.001) * spread + 0.5;
	uv = clamp(uv, -0.5, 1.5);
	uv.y = 1.0 - uv.y;
	float t = TIME * speed;

	// two drifting pools of light
	vec2 c1 = vec2(0.30 + 0.12 * sin(t * 1.3), 0.35 + 0.10 * cos(t * 0.9));
	vec2 c2 = vec2(0.72 + 0.10 * cos(t * 1.1), 0.68 + 0.12 * sin(t * 0.7));
	float m = clamp(blob(uv, c1, 0.75) * 0.8 + blob(uv, c2, 0.65) * 0.6, 0.0, 1.0);

	// a steady vertical fall-off underneath, so the frame always reads as dark
	float fall = smoothstep(1.1, -0.1, uv.y);
	vec3 col = mix(color_b, color_a, clamp(m * 0.85 + fall * 0.35, 0.0, 1.0));

	// vignette
	col *= 1.0 - distance(uv, vec2(0.5)) * 0.55;

	// a little dither keeps wide gradients from banding on cheap panels
	float n = fract(sin(dot(uv * 1024.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = col;
}
