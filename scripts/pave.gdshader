shader_type spatial;
render_mode specular_disabled;
uniform vec3 base = vec3(0.55, 0.52, 0.48);
uniform vec3 joint = vec3(0.35, 0.33, 0.3);
uniform float sc = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = w.xz / sc;
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 id = floor(p); vec2 f = fract(p);
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float j = smoothstep(0.03, 0.08, e);
	vec3 c = base * (0.86 + 0.24 * h(id));
	ALBEDO = mix(joint, c, j);
	ROUGHNESS = 0.92;
}
