shader_type spatial;
render_mode specular_disabled;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float v = n(w.xz * 0.08) * 0.6 + n(w.xz * 0.5) * 0.4;
	ALBEDO = mix(vec3(0.22, 0.38, 0.15), vec3(0.36, 0.52, 0.22), v);
	ROUGHNESS = 1.0;
}
