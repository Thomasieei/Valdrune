shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float amt = 1.0;
void fragment() {
	vec3 c = texture(scr, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 f = mix(c, vec3(g) * vec3(0.8, 0.95, 1.2), 0.8 * amt);
	float v = smoothstep(0.9, 0.3, length(SCREEN_UV - 0.5));
	COLOR = vec4(f * mix(1.0, 0.6 + 0.4 * v, amt), 1.0);
}
