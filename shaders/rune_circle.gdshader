shader_type spatial;
// Cercle runique au sol : anneaux, graduations, glyphes tournants, étoile à six branches.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, blend_add, fog_disabled;
uniform vec4 color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float progress = 1.0;
uniform float spin = 0.5;
uniform float intensity = 1.0;
float ring(float r, float c, float w) { return smoothstep(w, 0.0, abs(r - c)); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * spin;
	float v = ring(r, 0.96, 0.018) + ring(r, 0.86, 0.012) + ring(r, 0.58, 0.014) * 0.9 + ring(r, 0.3, 0.012) * 0.7;
	// graduations entre les deux anneaux externes
	float tick = step(0.82, fract((a + t) / 6.2831853 * 64.0)) * step(0.87, r) * step(r, 0.95);
	// glyphes : blocs irréguliers dans la couronne
	float k = floor((a - t * 0.6) / 6.2831853 * 18.0);
	float hsh = fract(sin(k * 91.7) * 43758.5);
	float band = step(0.62, r) * step(r, 0.82);
	float glyph = band * step(0.35, hsh) * step(0.2, fract((a - t * 0.6) / 6.2831853 * 18.0)) * step(fract((a - t * 0.6) / 6.2831853 * 18.0), 0.8)
		* step(abs(r - 0.72), 0.03 + 0.05 * hsh);
	// hexagramme qui tourne en sens inverse
	float star = 0.0;
	for (int i = 0; i < 6; i++) {
		float a0 = -t + float(i) * 1.0471976;
		vec2 q0 = vec2(cos(a0), sin(a0)) * 0.58;
		vec2 q1 = vec2(cos(a0 + 2.0943951), sin(a0 + 2.0943951)) * 0.58;
		star += seg(p, q0, q1, 0.012);
	}
	float total = v + tick * 0.8 + glyph * 0.9 + star * 0.8;
	float appear = smoothstep(progress * 1.1 - 0.1, progress * 1.1, 1.0 - r) + step(1.0, progress);
	float edge = smoothstep(1.0, 0.97, r);
	float fill = smoothstep(1.0, 0.0, r) * 0.12;
	ALBEDO = color.rgb * intensity * (total + fill) * clamp(appear, 0.0, 1.0) * edge;
}
