shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform int mode = 0;        // 0 cercle, 1 cône, 2 ligne
uniform float prog = 0.0;    // remplissage 0→1 (impact à 1)
uniform float half_ang = 0.8;
uniform vec4 col : source_color = vec4(1.0, 0.15, 0.1, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float a = 0.0, f = 0.0, e = 0.0;
	if (mode == 0) {
		float d = length(p); a = step(d, 1.0); f = step(d, prog); e = smoothstep(0.9, 0.97, d) * a;
	} else if (mode == 1) {
		vec2 q = UV - vec2(0.5, 0.5); q *= 2.0; float d = length(q);
		float an = abs(atan(q.x, q.y));
		a = step(d, 1.0) * step(an, half_ang); f = a * step(d, prog); e = a * max(smoothstep(0.9, 0.97, d), smoothstep(half_ang - 0.06, half_ang, an));
	} else {
		a = 1.0; f = step(UV.y, prog); e = max(smoothstep(0.92, 0.99, abs(p.x)), smoothstep(0.97, 1.0, abs(p.y)));
	}
	ALBEDO = col.rgb;
	ALPHA = a * (0.18 + 0.32 * f) + e * 0.6;
}
