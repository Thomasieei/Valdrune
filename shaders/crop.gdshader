shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
instance uniform float growth = 1.0;
instance uniform float ripe = 0.0;
instance uniform float kind = 0.0; // 0 blé, 1 chou
varying float hrel;
varying float ear;
varying float leaf;
void vertex() {
	hrel = UV.y;
	ear = COLOR.r;
	leaf = COLOR.g;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = growth;
	if (kind < 0.5) {
		// le blé pousse en hauteur ; l'épi n'apparaît qu'à partir de la moitié
		VERTEX.y *= g;
		VERTEX.xz *= mix(0.6, 1.0, g);
		float sway = sin(TIME * 1.6 + wp.x * 0.35 + wp.z * 0.2) * 0.07 * hrel * g;
		VERTEX.x += sway;
		VERTEX.z += sway * 0.5;
	} else {
		VERTEX *= g;
	}
}
void fragment() {
	vec3 c;
	if (kind < 0.5) {
		vec3 green = mix(vec3(0.20, 0.42, 0.12), vec3(0.42, 0.66, 0.22), hrel);
		vec3 gold = mix(vec3(0.62, 0.50, 0.20), vec3(0.93, 0.78, 0.36), hrel);
		vec3 stubble = vec3(0.70, 0.60, 0.34);
		c = mix(green, gold, ripe);
		if (ear > 0.5) {
			c = mix(vec3(0.45, 0.62, 0.22), vec3(0.96, 0.82, 0.42), ripe);
			if (growth < 0.45) discard;
		}
		if (growth < 0.15 && ripe > 0.5) c = stubble;
	} else {
		vec3 young = vec3(0.36, 0.62, 0.26);
		vec3 core = mix(vec3(0.55, 0.75, 0.40), vec3(0.62, 0.78, 0.48), ripe);
		c = leaf > 0.75 ? core : mix(young, vec3(0.30, 0.52, 0.30), ripe);
		c *= 0.8 + 0.3 * hrel;
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
