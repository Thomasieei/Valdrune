shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform vec4 col : source_color = vec4(0.9, 0.15, 0.1, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float b = step(0.04, UV.x) * step(UV.x, 0.96) * step(0.18, UV.y) * step(UV.y, 0.82);
	float inner = (UV.x - 0.04) / 0.92;
	vec3 c = mix(vec3(0.08), col.rgb, step(inner, fill) * b);
	ALBEDO = c; ALPHA = 0.92;
}
