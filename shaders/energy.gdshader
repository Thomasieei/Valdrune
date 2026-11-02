shader_type spatial;
// Énergie magique : cœur translucide animé, veines lumineuses, contour (fresnel) éclatant.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, fog_disabled;
uniform vec4 color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float alpha = 0.55;
uniform float fres_pow = 2.2;
uniform float glow = 1.0;
uniform float hex = 0.0;
uniform float dissolve = 0.0;
uniform vec2 scroll = vec2(0.05, 0.6);
uniform float nscale = 1.6;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), fres_pow);
	float n = texture(noise, UV * nscale + scroll * TIME).r;
	float n2 = texture(noise, UV * nscale * 2.3 - scroll * TIME * 1.4).g;
	float veins = smoothstep(0.08, 0.0, abs(n - n2));
	float h = 0.0;
	if (hex > 0.0) {
		vec2 g = UV * vec2(28.0, 14.0);
		vec2 c = abs(fract(g) - 0.5);
		h = smoothstep(0.43, 0.49, max(c.x, c.y));
	}
	vec3 col = color.rgb * (0.55 + 0.45 * n) + color.rgb * veins * 0.5 + (color.rgb * 0.75 + vec3(0.25)) * f + color.rgb * h * hex * 0.6;
	ALBEDO = col * glow;
	float a = alpha * (0.45 + 0.55 * n) + f * 0.9 + veins * 0.45 + h * hex * 0.6;
	a *= smoothstep(dissolve, dissolve + 0.12, n2 + 0.05);
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
