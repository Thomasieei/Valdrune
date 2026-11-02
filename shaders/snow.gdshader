shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Sol enneigé : neige poudreuse scintillante, roche sur les pentes (COLOR.a = poids de roche)
uniform sampler2D roche : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roche_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.02).r;
	float n2 = texture(noise_tex, wpos.xz * 0.35).r;
	vec3 snow = vec3(0.78, 0.83, 0.93) * (0.9 + 0.12 * n1) + vec3(0.04, 0.05, 0.08) * (n2 - 0.5);
	vec3 rock = texture(roche, wpos.xz * 0.09).rgb * vec3(0.78, 0.8, 0.86);
	float r = clamp(COLOR.a + (n1 - 0.5) * 0.35, 0.0, 1.0);
	ALBEDO = mix(snow, rock, r);
	ROUGHNESS = mix(0.55, 0.95, r);
	// scintillement de la neige
	float sp = step(0.985, fract(sin(dot(floor(wpos.xz * 9.0), vec2(12.9898, 78.233))) * 43758.5453));
	EMISSION = vec3(0.6, 0.7, 0.9) * sp * (1.0 - r) * 0.5;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(roche_n, wpos.xz * 0.09).rgb, r);
}
