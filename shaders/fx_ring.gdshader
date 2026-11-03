shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Onde au sol / lueur / arc de taille : couleur pleine et lumineuse (lisible en plein jour)
uniform vec4 col : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float inner = 0.85;      // 0 = disque plein (lueur), ~0.85 = anneau fin (onde)
uniform float open_ang = 6.2832; // ouverture angulaire (arc de taille)
uniform float fade = 1.0;        // 1 → 0 au fil de l'effet
uniform float soft = 0.08;
uniform float lead = 0.0;        // 1 = bord d'attaque plus lumineux (arc)
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.x, p.y);
	float half_ang = open_ang * 0.5;
	float am = 1.0 - smoothstep(half_ang - 0.25, half_ang, abs(a));
	if (open_ang > 6.2) { am = 1.0; }
	float ring = smoothstep(inner - soft, inner, r) * (1.0 - smoothstep(1.0 - soft, 1.0, r));
	float core = 1.0 - smoothstep(0.0, 0.5, abs(r - (inner + 1.0) * 0.5) / max(0.01, (1.0 - inner) * 0.5));
	if (inner <= 0.01) { ring = 1.0 - smoothstep(0.0, 1.0, r); ring *= ring; core = ring; }
	float edge = mix(1.0, 0.25 + 0.75 * clamp((a / max(0.01, half_ang)) * 0.5 + 0.5, 0.0, 1.0), lead);
	float alpha = ring * am * edge * fade;
	// cœur blanc brûlant, bords colorés
	ALBEDO = mix(col.rgb, vec3(1.0), core * 0.55);
	ALPHA = clamp(alpha * col.a * 1.15, 0.0, 1.0);
}
