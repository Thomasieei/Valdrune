shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Sol : textures de détail (herbe / terre / roche) mélangées par poids (UV2), teintées par la couleur de sommet.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D herbe : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terre : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D herbe_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D terre_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roche_n : hint_normal, filter_linear_mipmap, repeat_enable;
const vec3 REF_H = vec3(0.241, 0.401, 0.145);
const vec3 REF_T = vec3(0.443, 0.344, 0.235);
const vec3 REF_R = vec3(0.448, 0.435, 0.395);
varying vec3 wpos;
varying vec2 splat;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; splat = UV2; }
void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.012).r;
	vec2 uv = wpos.xz * 0.28;
	float wr = clamp(splat.y, 0.0, 1.0);
	float wt = clamp(splat.x, 0.0, 1.0) * (1.0 - wr);
	// bordure terre/herbe irrégulière
	wt = clamp(wt + (n1 - 0.5) * 0.5 * wt * (1.0 - wt) * 4.0, 0.0, 1.0);
	float wh = max(0.0, 1.0 - wt - wr);
	// échantillons seulement pour les matières présentes (coût réduit sur mobile)
	vec3 c = texture(herbe, uv).rgb / REF_H * wh;
	if (wt > 0.01) { c += texture(terre, uv * 0.8).rgb / REF_T * wt; }
	if (wr > 0.01) { c += texture(roche, wpos.xz * 0.11).rgb / REF_R * wr; }
	c = pow(clamp(c, 0.0, 2.0), vec3(1.5)) * COLOR.rgb;
	c *= 0.84 + 0.3 * n1;   // grandes taches : casse la répétition
	ALBEDO = c;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(herbe_n, uv).rgb, wh + wt * 0.6);
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = 1.0;
}
