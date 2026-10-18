shader_type sky;

// The background: a slow two-colour gradient with an optional pattern laid
// over it. Colours come from the selected app (icon or a palette); the style
// and the pattern are launcher-wide settings.
//
// style:   0 pools, 1 irregular blending, 2 sweep, 3 aurora, 4 waves,
//          5 radial, 6 linear, 7 corners
// overlay: 0 none, 1 dots, 2 mesh, 3 triangles, 4 Chladni figures,
//          5 bubbles, 6 strips, 7 sparkles, 8 hexagons, 9 ripples

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
//
// atan() jumps from +PI to -PI on the left of the centre — nine o'clock — so
// anything periodic in the angle has to repeat a whole number of times per
// turn or it shows a seam there. sin(angle * 1.5) did not. Whole harmonics
// only, and the noise is sampled in screen space, which has no seam at all.
float style_sweep(vec2 uv, float t) {
	vec2 d = (uv - vec2(0.5));
	float angle = atan(d.y, d.x) + t * 0.6;
	float band = 0.5 + 0.35 * sin(angle) + 0.15 * sin(angle * 2.0 - t * 0.4);
	band += (fbm(uv * 3.0 + t * 0.2) - 0.5) * 0.4;
	return clamp(band * (0.65 + 0.6 * length(d)), 0.0, 1.0);
}

// Curtains of light hanging from the top, swaying.
float style_aurora(vec2 uv, float t) {
	float x = uv.x * 3.0 + fbm(vec2(uv.x * 2.0, t * 0.5)) * 1.5;
	float curtain = 0.5 + 0.5 * sin(x * 2.4 + t * 1.3);
	curtain *= 0.6 + 0.4 * fbm(vec2(uv.x * 6.0, uv.y * 0.8 - t * 0.6));
	float hang = smoothstep(1.05, 0.15, uv.y) * smoothstep(-0.1, 0.25, uv.y);
	return clamp(curtain * hang * 1.3, 0.0, 1.0);
}

// Broad horizontal bands rolling slowly upward.
float style_waves(vec2 uv, float t) {
	float y = uv.y + 0.08 * sin(uv.x * 4.0 + t * 2.0) + 0.05 * sin(uv.x * 9.0 - t * 1.4);
	float v = 0.5 + 0.5 * sin(y * 7.0 - t * 2.2);
	return clamp(mix(v, fbm(uv * 2.0 + t * 0.2), 0.25), 0.0, 1.0);
}

// A glow from the middle that breathes.
float style_radial(vec2 uv, float t) {
	vec2 d = (uv - vec2(0.5, 0.45));
	float r = length(d) / (0.85 + 0.12 * sin(t * 2.0));
	return clamp(1.0 - r + (fbm(uv * 2.5 + t * 0.15) - 0.5) * 0.25, 0.0, 1.0);
}

// A straight gradient whose direction turns very slowly.
float style_linear(vec2 uv, float t) {
	float a = t * 0.5 + 0.7;
	vec2 dir = vec2(cos(a), sin(a));
	float v = dot((uv - 0.5), dir) * 0.7 + 0.5;
	return clamp(v, 0.0, 1.0);
}

// Four corners, each pulling its own way: the colour sits where they meet.
float style_corners(vec2 uv, float t) {
	float a = 0.5 + 0.5 * sin(t * 1.1);
	float b = 0.5 + 0.5 * sin(t * 0.8 + 2.0);
	float c = 0.5 + 0.5 * sin(t * 1.3 + 4.0);
	float d = 0.5 + 0.5 * sin(t * 0.9 + 1.0);
	vec2 f = smoothstep(0.0, 1.0, clamp(uv, 0.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Patterns work in square space. uv comes from the view direction, so it
// already carries the screen's aspect — one unit is as wide as it is tall.
// Multiplying x by 16/9 on top of that squashed every pattern into tall
// ovals, which the rings made obvious.
vec2 square(vec2 uv) {
	return uv;
}

float pattern_dots(vec2 uv, float t) {
	vec2 p = square(uv) + vec2(sin(t * 0.7), cos(t * 0.5)) * 0.01;
	vec2 g = fract(p * 48.0) - 0.5;
	return smoothstep(0.22, 0.12, length(g));
}

float pattern_mesh(vec2 uv, float t) {
	vec2 p = square(uv) + vec2(t * 0.02, sin(t * 0.4) * 0.01);
	vec2 g = abs(fract(p * 30.0) - 0.5);
	return smoothstep(0.055, 0.0, min(g.x, g.y));
}

float pattern_triangles(vec2 uv, float t) {
	// A real triangular lattice: shear the grid, then measure the distance to
	// the three edges of the cell.
	vec2 p = square(uv) + vec2(sin(t * 0.3) * 0.015, t * 0.01);
	p *= 22.0;
	p.x += p.y * 0.5;
	vec2 f = fract(p);
	float e = min(min(f.x, f.y), abs(f.x + f.y - 1.0));
	return smoothstep(0.07, 0.0, e);
}

// Chladni figures: the nodal lines of a square plate, where the sand settles.
// Both mode numbers drift, so the figure keeps rebuilding itself.
float pattern_chladni(vec2 uv, float t) {
	float n = 3.0 + 2.0 * sin(t * 0.21);
	float m = 5.0 + 3.0 * cos(t * 0.17);
	vec2 p = square(uv);  // square plate
	float v = sin(n * PI * p.x) * sin(m * PI * p.y)
			- sin(m * PI * p.x) * sin(n * PI * p.y);
	return smoothstep(0.06, 0.0, abs(v));
}

// PS5-style bubbles: soft circles drifting up, each its own size and pace,
// brighter at the rim than in the middle like a lens bokeh.
float pattern_bubbles(vec2 uv, float t) {
	vec2 p = square(uv);
	float acc = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float scale = 3.0 + float(layer) * 2.2;
		vec2 q = p * scale;
		q.y += t * (0.35 + float(layer) * 0.18);
		vec2 cell = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(cell + float(layer) * 17.0);
		if (h < 0.72) {
			continue;
		}
		vec2 wob = vec2(sin(t * 1.3 + h * 40.0), cos(t * 0.9 + h * 23.0)) * 0.12;
		float radius = 0.16 + 0.22 * hash(cell * 1.7 + 3.0);
		float dist = length(f - wob);
		float disc = smoothstep(radius, radius - 0.05, dist);
		float rim = smoothstep(radius - 0.09, radius - 0.01, dist) * disc;
		acc += (disc * 0.35 + rim * 0.65) * (1.0 - float(layer) * 0.25);
	}
	return clamp(acc, 0.0, 1.0);
}

// PS4-style strips: thin ribbons of light flowing across the screen in a
// loose bundle, each a little out of phase with the next.
float pattern_strips(vec2 uv, float t) {
	vec2 p = square(uv);
	float acc = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float y = 0.55 + 0.10 * sin(p.x * 1.6 + t * 0.9 + fi * 0.45)
				+ 0.06 * sin(p.x * 3.1 - t * 0.6 + fi * 0.8)
				+ (fi - 3.0) * 0.018;
		float width = 0.0025 + 0.002 * sin(t + fi);
		float line = smoothstep(width * 4.0, 0.0, abs(p.y - y));
		acc += line * (0.45 + 0.55 * (0.5 + 0.5 * sin(p.x * 2.0 + t * 1.7 + fi)));
	}
	// A soft glow under the bundle, so it reads as light and not wire.
	float centre = 0.55 + 0.10 * sin(p.x * 1.6 + t * 0.9 + 1.35);
	acc += smoothstep(0.16, 0.0, abs(p.y - centre)) * 0.25;
	return clamp(acc, 0.0, 1.0);
}

// Pinpoints that fade in and out.
float pattern_sparkles(vec2 uv, float t) {
	vec2 q = square(uv) * 26.0;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash(cell);
	vec2 at = vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5;
	float twinkle = pow(0.5 + 0.5 * sin(t * (2.0 + h * 4.0) + h * 30.0), 6.0);
	float star = smoothstep(0.10, 0.0, length(f - at * 0.6));
	return step(0.5, h) * star * (0.25 + twinkle) * 2.0;
}

// Honeycomb outlines.
float pattern_hexagons(vec2 uv, float t) {
	vec2 p = square(uv) * 14.0 + vec2(t * 0.15, t * 0.05);
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	float edge = 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
	return smoothstep(0.05, 0.0, edge);
}

// Thin rings spreading out from a point that wanders, like a drop in water.
float pattern_ripples(vec2 uv, float t) {
	vec2 p = square(uv);
	vec2 c = vec2(0.5 + 0.25 * sin(t * 0.21), 0.5 + 0.15 * cos(t * 0.17));
	float r = length(p - c);
	float ring = abs(fract(r * 9.0 - t * 0.6) - 0.5);
	float line = smoothstep(0.06, 0.0, ring);
	return line * smoothstep(1.1, 0.1, r);
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
	} else if (style == 3) {
		m = style_aurora(uv, t);
	} else if (style == 4) {
		m = style_waves(uv, t);
	} else if (style == 5) {
		m = style_radial(uv, t);
	} else if (style == 6) {
		m = style_linear(uv, t);
	} else if (style == 7) {
		m = style_corners(uv, t);
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
		} else if (overlay == 4) {
			p = pattern_chladni(uv, pt);
		} else if (overlay == 5) {
			p = pattern_bubbles(uv, pt);
		} else if (overlay == 6) {
			p = pattern_strips(uv, pt);
		} else if (overlay == 7) {
			p = pattern_sparkles(uv, pt);
		} else if (overlay == 8) {
			p = pattern_hexagons(uv, pt);
		} else {
			p = pattern_ripples(uv, pt);
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
