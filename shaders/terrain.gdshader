shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.012).r;
	float n2 = texture(noise_tex, wpos.xz * 0.09).r;
	float n3 = texture(noise_tex, wpos.xz * 0.45).r;
	vec3 c = COLOR.rgb;
	c *= 0.86 + 0.22 * n1;
	c *= 0.93 + 0.12 * n2;
	c *= 0.96 + 0.08 * n3;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
