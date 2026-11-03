shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Tourbillon d'un portail de faille (inspiré du portail de Brèche Écarlate) : spirale de bruit, cœur lumineux, liseré
uniform vec4 c1 : source_color = vec4(0.35, 0.05, 0.1, 1.0);
uniform vec4 c2 : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.85, 0.7, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.5, 0.3, 1.0);

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME;
	float sw = a + r * 5.0 - t * 1.6;
	vec2 q = vec2(cos(sw), sin(sw)) * r * 3.0;
	float f = n(q * 2.0 + t * 0.3) * 0.6 + n(q * 5.0 - t * 0.5) * 0.4;
	float cr = smoothstep(0.55, 0.0, r);
	float rm = smoothstep(0.75, 1.0, r);
	vec3 c = mix(c1.rgb, c2.rgb, clamp(f * 1.2, 0.0, 1.0));
	c += core.rgb * cr * cr * 0.9;
	c += rim.rgb * rm * 1.4;
	ALBEDO = c * 1.3;
	ALPHA = smoothstep(1.0, 0.96, r) * 0.96;
}
