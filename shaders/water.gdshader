shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform vec3 shallow : source_color = vec3(0.36, 0.70, 0.72);
uniform vec3 deep : source_color = vec3(0.10, 0.33, 0.48);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.35 + TIME * 1.1) * 0.04 + cos(wpos.z * 0.3 + TIME * 0.9) * 0.04;
}
void fragment() {
	float d = COLOR.r;
	float t = TIME;
	vec2 p = wpos.xz;
	vec3 nrm = normalize(vec3(
		sin(p.x * 0.9 + t * 1.3) * 0.08 + sin(p.y * 1.7 - t * 1.7) * 0.05 + sin((p.x + p.y) * 2.3 + t * 2.1) * 0.03,
		1.0,
		cos(p.y * 1.1 + t * 1.2) * 0.08 + cos(p.x * 1.9 + t * 1.5) * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ALBEDO = mix(shallow, deep, smoothstep(0.0, 1.0, d));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(ALBEDO, vec3(0.75, 0.86, 0.95), fres * 0.5);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(0.55, 0.92, smoothstep(0.0, 0.5, d));
	// écume sur la berge
	float foam = (1.0 - smoothstep(0.02, 0.12, d)) * (0.6 + 0.4 * sin(t * 2.0 + p.x * 1.3 + p.y));
	ALBEDO = mix(ALBEDO, vec3(0.92, 0.96, 0.97), foam * 0.7);
}
