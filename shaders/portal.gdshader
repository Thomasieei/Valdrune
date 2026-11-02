shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 9.0 - TIME * 1.6) * 0.5 + 0.5;
	float rim = smoothstep(0.5, 1.0, r);
	vec3 c = mix(vec3(0.25, 0.35, 0.95), vec3(0.65, 0.4, 1.0), swirl);
	ALBEDO = c * (0.35 + 0.65 * swirl) + vec3(0.6, 0.8, 1.0) * rim * 0.4;
	ALPHA = 0.55;
}
