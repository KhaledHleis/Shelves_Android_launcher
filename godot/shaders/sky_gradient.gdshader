shader_type sky;

// The background: a slow two-colour gradient with an optional pattern laid
// over it. Colours come from the selected app (icon or a palette); the style
// and the pattern are launcher-wide settings.
//
// style:   0 pools, 1 irregular blending, 2 sweep
// overlay: 0 none, 1 dots, 2 mesh, 3 triangles, 4 Chladni figures

uniform vec3 color_a : source_color = vec3(0.18, 0.14, 0.30);
uniform vec3 color_b : source_color = vec3(0.04, 0.05, 0.09);
uniform float speed = 0.05;          // gradient drift
uniform float pattern_speed = 0.15;  // how fast the pattern moves, Chladni especially
uniform float grain = 0.02;
uniform float spread = 1.05;
uniform int style = 0;
uniform int overlay = 0;
uniform float overlay_strength = 0.30;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise, smoothed between lattice points.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return sum;
}

float blob(vec2 uv, vec2 centre, float radius) {
	return smoothstep(radius, 0.0, distance(uv, centre));
}

// Two drifting pools of light — the original look.
float style_pools(vec2 uv, float t) {
	vec2 c1 = vec2(0.30 + 0.12 * sin(t * 1.3), 0.35 + 0.10 * cos(t * 0.9));
	vec2 c2 = vec2(0.72 + 0.10 * cos(t * 1.1), 0.68 + 0.12 * sin(t * 0.7));
	return clamp(blob(uv, c1, 0.75) * 0.8 + blob(uv, c2, 0.65) * 0.6, 0.0, 1.0);
}

// Irregular blending: noise warped by noise, so the two colours fold into
// each other in marbled bands rather than meeting on a clean line.
float style_blend(vec2 uv, float t) {
	vec2 p = uv * 2.6;
	vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3 - t * 0.6)));
	vec2 r = vec2(fbm(p + 3.4 * q + vec2(1.7, 9.2) + t * 0.3),
				  fbm(p + 3.4 * q + vec2(8.3, 2.8) - t * 0.2));
	float v = fbm(p + 2.2 * r);
	return clamp(v * 1.6 - 0.15, 0.0, 1.0);
}

// A soft sweep around a slowly turning axis, with a ragged noise edge.
float style_sweep(vec2 uv, float t) {
	vec2 d = uv - vec2(0.5);
	float angle = atan(d.y, d.x) + t * 0.6;
	float band = 0.5 + 0.5 * sin(angle * 1.5);
	band += (fbm(uv * 3.0 + t * 0.2) - 0.5) * 0.5;
	return clamp(band * (0.6 + 0.8 * length(d)), 0.0, 1.0);
}

float pattern_dots(vec2 uv, float t) {
	uv += vec2(sin(t * 0.7), cos(t * 0.5)) * 0.01;
	vec2 g = fract(uv * vec2(44.0, 26.0)) - 0.5;
	float d = length(g);
	return smoothstep(0.34, 0.16, d);
}

float pattern_mesh(vec2 uv, float t) {
	uv += vec2(t * 0.02, sin(t * 0.4) * 0.01);
	vec2 g = abs(fract(uv * vec2(34.0, 20.0)) - 0.5);
	float line = min(g.x, g.y);
	return smoothstep(0.1, 0.0, line);
}

float pattern_triangles(vec2 uv, float t) {
	uv += vec2(sin(t * 0.3) * 0.015, t * 0.01);
	vec2 p = uv * vec2(26.0, 16.0);
	p.x += floor(p.y) * 0.5;              // stagger, so the cells are triangular
	vec2 f = fract(p);
	float e = min(min(f.x, f.y), abs(f.x + f.y - 1.0));
	return smoothstep(0.12, 0.0, e);
}

// Chladni figures: the nodal lines of a square plate, where the sand settles.
// Both mode numbers drift, so the figure keeps rebuilding itself.
float pattern_chladni(vec2 uv, float t) {
	float n = 3.0 + 2.0 * sin(t * 0.21);
	float m = 5.0 + 3.0 * cos(t * 0.17);
	float v = sin(n * PI * uv.x) * sin(m * PI * uv.y)
			- sin(m * PI * uv.x) * sin(n * PI * uv.y);
	return smoothstep(0.06, 0.0, abs(v));
}

void sky() {
	// Derived from the view direction rather than SCREEN_UV: that one is only
	// valid in the main pass, and the compatibility renderer squeezes it.
	vec2 uv = EYEDIR.xy / max(abs(EYEDIR.z), 0.001) * spread + 0.5;
	uv = clamp(uv, -0.5, 1.5);
	uv.y = 1.0 - uv.y;
	float t = TIME * speed;
	float pt = TIME * pattern_speed;

	float m = style_pools(uv, t);
	if (style == 1) {
		m = style_blend(uv, t);
	} else if (style == 2) {
		m = style_sweep(uv, t);
	}

	// A steady vertical fall-off underneath, so the frame always reads dark.
	float fall = smoothstep(1.1, -0.1, uv.y);
	vec3 col = mix(color_b, color_a, clamp(m * 0.85 + fall * 0.35, 0.0, 1.0));

	if (overlay > 0) {
		float p = 0.0;
		if (overlay == 1) {
			p = pattern_dots(uv, pt);
		} else if (overlay == 2) {
			p = pattern_mesh(uv, pt);
		} else if (overlay == 3) {
			p = pattern_triangles(uv, pt);
		} else {
			p = pattern_chladni(uv, pt);
		}
		// Lifted towards the lit colour rather than painted on in white, so
		// the pattern belongs to the gradient underneath it.
		col = mix(col, col + color_a * 0.9 + 0.05, p * overlay_strength);
	}

	col *= 1.0 - distance(uv, vec2(0.5)) * 0.55;

	// Dither scaled by brightness: a fixed amount reads as static on a dark
	// area, where one display step is a far smaller linear step.
	float n = fract(sin(dot(uv * 1024.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain * sqrt(max(col.r, max(col.g, col.b)));

	COLOR = col;
}
