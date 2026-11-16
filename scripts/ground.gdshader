shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(w.xz);
	vec2 g = abs(fract(w.xz * 0.5) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y));
	vec3 grass = mix(vec3(0.2, 0.36, 0.14), vec3(0.27, 0.42, 0.16), 0.5 + 0.5 * sin(w.x * 0.37) * sin(w.z * 0.29));
	vec3 stone = mix(vec3(0.5, 0.46, 0.4), vec3(0.36, 0.33, 0.3), line);
	ALBEDO = mix(stone, grass, smoothstep(9.0, 10.5, d));
	ROUGHNESS = 0.95;
}
