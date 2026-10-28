// Icônes d'objets peintes en SVG (style carte de butin) : contour sombre épais, liseré lumineux à la couleur du tier,
// volumes ombrés, reflets, détails de matière. Aucune image externe.
import { TIERS } from './data.js';

const hex = (h) => { h = h.replace('#', ''); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; };
const toHex = (r, g, b) => '#' + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
const mix = (a, b, k) => { const A = hex(a), B = hex(b); return toHex(A[0] + (B[0] - A[0]) * k, A[1] + (B[1] - A[1]) * k, A[2] + (B[2] - A[2]) * k); };
const clair = (c, k) => mix(c, '#ffffff', k), sombre = (c, k) => mix(c, '#000000', k);

// palettes de matière selon le tier : cuir/métal deviennent plus nobles en montant
function palette(tier) {
  const tc = TIERS[tier] ? TIERS[tier].color : '#9a9184';
  const metal = tier <= 1 ? '#8a7f72' : tier === 2 ? '#c4864a' : tier <= 4 ? '#b8c2cc' : tier <= 6 ? '#d6dce4' : '#eef1f6';
  const cuir = tier <= 2 ? '#7a4a2a' : tier <= 4 ? '#5a3a24' : tier <= 6 ? '#3e2a22' : '#2a1e24';
  const tissu = tier <= 1 ? '#6a5a48' : mix(tc, '#3a2a2a', 0.35);
  const orne = tier <= 1 ? '#8a7a62' : tier === 2 ? '#d89a52' : tier >= 6 ? '#ffd45a' : clair(tc, 0.25);
  return { tier, tc, metal, cuir, tissu, orne, gemme: tier >= 4 ? tc : null, halo: tier >= 3 ? clair(tc, 0.35) : null };
}

const defsBase = (P, id) => `
  <linearGradient id="${id}m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${clair(P.metal, 0.55)}"/><stop offset=".45" stop-color="${P.metal}"/><stop offset="1" stop-color="${sombre(P.metal, 0.55)}"/></linearGradient>
  <linearGradient id="${id}c" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${clair(P.cuir, 0.35)}"/><stop offset=".55" stop-color="${P.cuir}"/><stop offset="1" stop-color="${sombre(P.cuir, 0.5)}"/></linearGradient>
  <linearGradient id="${id}t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${clair(P.tissu, 0.3)}"/><stop offset="1" stop-color="${sombre(P.tissu, 0.45)}"/></linearGradient>
  <linearGradient id="${id}o" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${clair(P.orne, 0.6)}"/><stop offset=".5" stop-color="${P.orne}"/><stop offset="1" stop-color="${sombre(P.orne, 0.5)}"/></linearGradient>
  <radialGradient id="${id}g" cx=".35" cy=".3" r=".75"><stop offset="0" stop-color="#ffffff"/><stop offset=".3" stop-color="${clair(P.gemme || P.tc, 0.3)}"/><stop offset="1" stop-color="${sombre(P.gemme || P.tc, 0.5)}"/></radialGradient>
  <radialGradient id="${id}h"><stop offset="0" stop-color="${P.tc}" stop-opacity=".55"/><stop offset=".6" stop-color="${P.tc}" stop-opacity=".18"/><stop offset="1" stop-color="${P.tc}" stop-opacity="0"/></radialGradient>
  <filter id="${id}f" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="4"/></filter>
  <filter id="${id}s" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="${id}n" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="${id.length * 7}"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.4 1.1"/></filter>`;

// un « calque » peint : remplissage dégradé, ombre interne douce le long des bords (volume), reflet diffus en haut à gauche,
// grain de matière, puis contour brun sombre fin et liseré lumineux à la couleur du tier tout autour
let nCalque = 0;
function forme(d, fill, P, id, extra = '', plat = false) {
  const k = id + 'k' + (nCalque++);
  if (plat) return `${P.halo ? `<path d="${d}" fill="none" stroke="${P.halo}" stroke-width="9" stroke-linejoin="round" opacity=".6" filter="url(#${id}f)"/>` : ''}<path d="${d}" fill="${fill}" ${extra}/><path d="${d}" fill="none" stroke="#24120a" stroke-width="4" stroke-linejoin="round"/>`;
  const lis = P.halo ? `<path d="${d}" fill="none" stroke="${P.halo}" stroke-width="11" stroke-linejoin="round" opacity=".7" filter="url(#${id}f)"/>` : '';
  return `${lis}<clipPath id="${k}"><path d="${d}"/></clipPath>
    <path d="${d}" fill="${fill}" ${extra}/>
    <g clip-path="url(#${k})">
      <path d="${d}" fill="none" stroke="#1a0c04" stroke-width="13" stroke-linejoin="round" opacity=".42" filter="url(#${id}s)" transform="translate(5,6)"/>
      <path d="${d}" fill="none" stroke="#fff" stroke-width="8" opacity=".38" filter="url(#${id}s)" transform="translate(-5,-6)"/>
      <rect x="0" y="0" width="256" height="256" filter="url(#${id}n)" opacity=".07"/>
    </g>
    <path d="${d}" fill="none" stroke="#24120a" stroke-width="4.5" stroke-linejoin="round"/>`;
}
const trait = (d, c, w = 3, op = 1) => `<path d="${d}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" opacity="${op}"/>`;
const gemme = (x, y, r, id) => `<circle cx="${x}" cy="${y}" r="${r + 3}" fill="#140a04"/><circle cx="${x}" cy="${y}" r="${r}" fill="url(#${id}g)"/><circle cx="${x - r * 0.35}" cy="${y - r * 0.35}" r="${r * 0.3}" fill="#fff" opacity=".9"/>`;
const rivet = (x, y, id) => `<circle cx="${x}" cy="${y}" r="4" fill="#24120a"/><circle cx="${x}" cy="${y}" r="2.8" fill="url(#${id}o)"/>`;

// ---------------- Bottes ----------------
function botte(P, id, arriere) {
  const plaque = P.tier >= 3;
  let s = '<g>';
  s += forme('M72,42 C72,34 140,30 142,38 L144,138 C150,156 170,164 192,170 C214,176 224,192 218,206 C214,214 204,216 190,216 L80,216 C70,216 64,210 64,198 L68,150 Z', `url(#${id}c)`, P, id); // cuir
  if (plaque) s += forme('M90,52 L136,48 L139,132 C128,144 102,146 92,134 Z', `url(#${id}m)`, P, id); // grève d'acier
  if (plaque) for (const y of [74, 96, 118]) s += trait(`M92,${y} C108,${y + 4} 124,${y + 3} 138,${y - 2}`, '#24120a', 2.5, 0.75);
  s += forme('M166,170 C196,174 218,186 216,204 C214,212 204,214 192,214 L160,214 C164,200 164,184 166,170 Z', plaque ? `url(#${id}m)` : sombre(P.cuir, 0.25), P, id); // bout renforcé
  s += forme('M58,206 L222,206 C226,214 220,226 208,228 L72,228 C62,228 54,218 58,206 Z', sombre(P.cuir, 0.62), P, id); // semelle
  s += forme('M62,214 L104,214 L102,238 L66,238 Z', sombre(P.cuir, 0.5), P, id); // talon
  s += forme('M66,40 C70,26 146,20 150,32 L152,60 C128,52 92,54 66,64 Z', `url(#${id}t)`, P, id); // revers
  s += forme('M66,160 C96,150 130,150 150,158 L152,176 C130,168 96,168 66,178 Z', `url(#${id}o)`, P, id, '', true); // lanière de cheville
  s += `<rect x="98" y="152" width="16" height="22" rx="3" fill="#24120a"/><rect x="101" y="155" width="10" height="16" rx="2" fill="url(#${id}m)"/>`;
  s += trait('M64,218 L220,218', '#d8c8a8', 1.6, 0.45);
  s += trait('M150,40 C152,46 152,54 152,58', '#fff', 2, 0.4);
  if (P.gemme && !arriere) s += gemme(110, 38, 7, id);
  return s + '</g>';
}
function svgBottes(tier) {
  const P = palette(tier), id = 'b' + tier;
  return `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="130" r="118" fill="url(#${id}h)"/>` : ''}
    <g transform="translate(70,-6) scale(.74)" opacity=".93">${botte(P, id, true)}</g><g transform="translate(0,30) scale(.8)">${botte(P, id, false)}</g>`;
}

// ---------------- Casque ----------------
function svgCasque(tier) {
  const P = palette(tier), id = 'c' + tier;
  let s = `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}`;
  if (tier >= 4) { // ailes / cornes
    s += forme('M54,128 C20,110 14,72 26,44 C40,74 58,92 78,100 Z', tier >= 6 ? `url(#${id}o)` : `url(#${id}m)`, P, id);
    s += forme('M202,128 C236,110 242,72 230,44 C216,74 198,92 178,100 Z', tier >= 6 ? `url(#${id}o)` : `url(#${id}m)`, P, id);
  }
  if (tier >= 2) s += forme('M120,34 C110,14 124,4 132,6 C150,10 150,28 136,38 Z', `url(#${id}t)`, P, id); // plumet
  s += forme('M56,150 C52,84 86,40 128,38 C170,40 204,84 200,150 L196,196 C196,212 184,220 168,220 L150,220 L146,170 L110,170 L106,220 L88,220 C72,220 60,212 60,196 Z', `url(#${id}m)`, P, id);
  s += forme('M74,150 L182,150 L178,172 L78,172 Z', '#140a04', P, id); // fente des yeux
  s += forme('M120,40 L136,40 L140,170 L116,170 Z', `url(#${id}o)`, P, id, '', true); // crête
  s += forme('M58,132 C90,122 166,122 198,132 L198,146 C166,136 90,136 58,146 Z', `url(#${id}o)`, P, id, '', true); // bandeau
  s += `<path d="M150,46 C176,60 194,90 196,150 L196,196 C196,212 184,220 168,220 L156,220 Z" fill="#000" opacity=".22"/>`;
  s += trait('M76,128 C74,92 92,62 116,50', '#fff', 7, 0.35);
  s += trait('M90,196 L98,182 M166,196 L158,182', sombre(P.metal, 0.5), 3, 0.7);
  for (const x of [72, 100, 156, 184]) s += rivet(x, x < 128 ? 140 - (x - 72) * 0.05 : 140, id);
  if (P.gemme) s += gemme(128, 104, 9, id);
  return s;
}

// ---------------- Plastron ----------------
function svgPlastron(tier) {
  const P = palette(tier), id = 'p' + tier;
  let s = `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}`;
  s += forme('M60,64 L104,44 L152,44 L196,64 L222,104 L196,128 L188,108 L188,206 C160,226 96,226 68,206 L68,108 L60,128 L34,104 Z', `url(#${id}t)`, P, id); // tunique
  s += forme('M74,70 L106,54 C116,66 140,66 150,54 L182,70 L182,196 C156,212 100,212 74,196 Z', `url(#${id}m)`, P, id); // cuirasse
  s += forme('M34,104 L60,64 L96,58 C92,82 78,100 60,112 Z', `url(#${id}m)`, P, id); // épaulière gauche
  s += forme('M222,104 L196,64 L160,58 C164,82 178,100 196,112 Z', `url(#${id}m)`, P, id);
  s += forme('M74,150 C104,162 152,162 182,150 L182,166 C152,178 104,178 74,166 Z', `url(#${id}c)`, P, id); // ceinture
  s += forme('M118,150 L138,150 L140,170 L116,170 Z', `url(#${id}o)`, P, id, '', true); // boucle
  s += trait('M128,62 L128,148', '#140a04', 3, 0.5);
  s += trait('M84,84 C110,96 146,96 172,84 M84,114 C110,126 146,126 172,114', `url(#${id}o)`, 5, 1);
  s += `<path d="M140,60 L182,70 L182,196 C168,204 152,208 140,210 Z" fill="#000" opacity=".2"/>`;
  s += trait('M88,74 C86,110 86,150 92,190', '#fff', 7, 0.3);
  s += trait('M44,98 L64,74', '#fff', 4, 0.5);
  for (const [x, y] of [[50, 92], [206, 92], [80, 76], [176, 76]]) s += rivet(x, y, id);
  if (P.gemme) s += gemme(128, 102, 10, id);
  return s;
}

// ---------------- Armes ----------------
function svgEpee(tier) { // épée à deux mains
  const P = palette(tier), id = 'e' + tier;
  let s = `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}<g transform="rotate(45 128 128)">`;
  s += forme('M108,30 L128,2 L148,30 L150,164 L106,164 Z', `url(#${id}m)`, P, id); // lame
  s += `<path d="M128,6 L148,30 L150,164 L128,164 Z" fill="#000" opacity=".22"/>`;
  s += trait('M128,24 L128,156', sombre(P.metal, 0.45), 5, 0.8) + trait('M116,34 L116,156', '#fff', 3, 0.6);
  s += forme('M74,162 C96,150 160,150 182,162 L178,180 C156,170 100,170 78,180 Z', `url(#${id}o)`, P, id, '', true); // garde
  s += forme('M118,176 L138,176 L138,230 L118,230 Z', `url(#${id}c)`, P, id); // poignée
  for (const y of [186, 198, 210]) s += trait(`M120,${y} L136,${y + 6}`, sombre(P.cuir, 0.6), 3, 0.9);
  s += forme('M128,226 m-12,0 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0', `url(#${id}o)`, P, id, '', true); // pommeau
  if (P.gemme) s += gemme(128, 169, 6, id) + gemme(128, 238, 5, id);
  return s + '</g>';
}
function svgArbalete(tier) {
  const P = palette(tier), id = 'a' + tier;
  let s = `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}<g transform="rotate(-30 128 128)">`;
  s += forme('M118,40 L138,40 L142,226 L114,226 Z', `url(#${id}c)`, P, id); // fût
  s += forme('M30,92 C70,62 186,62 226,92 L220,104 C182,80 74,80 36,104 Z', `url(#${id}m)`, P, id); // arc
  s += trait('M34,98 L128,140 L222,98', '#e8e0d0', 2.5, 1); // corde
  s += forme('M124,20 L132,20 L134,150 L122,150 Z', `url(#${id}o)`, P, id, '', true); // carreau
  s += forme('M128,4 L138,22 L118,22 Z', `url(#${id}m)`, P, id);
  s += forme('M112,150 L144,150 L146,176 L110,176 Z', `url(#${id}m)`, P, id); // mécanisme
  s += trait('M122,50 L120,220', '#fff', 4, 0.25);
  if (P.gemme) s += gemme(128, 163, 7, id);
  return s + '</g>';
}
function svgBaton(tier) {
  const P = palette(tier), id = 's' + tier;
  let s = `<defs>${defsBase(P, id)}<radialGradient id="${id}fe"><stop offset="0" stop-color="#fff6c0"/><stop offset=".4" stop-color="#ffb02a"/><stop offset="1" stop-color="#e2420e" stop-opacity="0"/></radialGradient></defs>
    ${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}<g transform="rotate(30 128 128)">`;
  s += forme('M120,70 L136,70 L140,240 L116,240 Z', `url(#${id}c)`, P, id);
  s += trait('M124,80 L122,232', '#fff', 3, 0.25);
  for (const y of [110, 150, 190]) s += forme(`M114,${y} L142,${y} L142,${y + 10} L114,${y + 10} Z`, `url(#${id}o)`, P, id);
  s += forme('M96,72 C92,40 112,16 128,10 C144,16 164,40 160,72 C150,60 140,58 128,60 C116,58 106,60 96,72 Z', `url(#${id}m)`, P, id); // tête
  s += `<circle cx="128" cy="40" r="34" fill="url(#${id}fe)"/>`;
  s += gemme(128, 42, 13, id);
  return s + '</g>';
}
function svgDagues(tier, couleurLame) {
  const P = palette(tier), id = 'd' + tier + (couleurLame ? 'x' : '');
  const lame = (r) => `<g transform="rotate(${r} 128 128)">${forme('M122,24 L128,10 L136,26 L138,140 L120,140 Z', couleurLame || `url(#${id}m)`, P, id)}
    ${trait('M128,18 L129,136', '#fff', 2.5, 0.7)}${forme('M100,140 L156,140 L154,152 L102,152 Z', `url(#${id}o)`, P, id, '', true)}
    ${forme('M121,152 L135,152 L135,196 L121,196 Z', `url(#${id}c)`, P, id)}${forme('M128,204 m-9,0 a9,9 0 1,0 18,0 a9,9 0 1,0 -18,0', `url(#${id}o)`, P, id, '', true)}</g>`;
  return `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}${lame(-32)}${lame(32)}${P.gemme ? gemme(128, 132, 8, id) : ''}`;
}
function svgHaches(tier) {
  const P = palette(tier), id = 'h' + tier;
  const hache = `${forme('M122,40 L134,40 L136,236 L120,236 Z', `url(#${id}c)`, P, id)}
    ${forme('M134,34 C176,20 210,40 218,78 C210,116 176,132 134,118 Z', `url(#${id}m)`, P, id)}
    ${forme('M122,48 C108,44 98,52 96,64 C100,78 110,84 122,82 Z', `url(#${id}m)`, P, id)}
    ${trait('M142,46 C172,38 198,54 208,78', '#fff', 5, 0.65)}${trait('M156,66 L180,80 L162,96 L184,108', '#9ad0ff', 3.5, 0.95)}
    ${forme('M116,32 L140,32 L140,50 L116,50 Z', `url(#${id}o)`, P, id, '', true)}${forme('M118,200 L138,200 L138,214 L118,214 Z', `url(#${id}o)`, P, id, '', true)}`;
  return `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}
    <g transform="rotate(30 128 140)">${hache}</g><g transform="translate(256,0) scale(-1,1) rotate(30 128 140)">${hache}</g>${P.gemme ? gemme(128, 160, 9, id) : ''}`;
}
function svgGrimoire(tier) {
  const P = palette(tier), id = 'g' + tier;
  return `<defs>${defsBase(P, id)}</defs>${P.halo ? `<circle cx="128" cy="128" r="118" fill="url(#${id}h)"/>` : ''}
    ${forme('M40,70 C80,52 110,56 128,74 C146,56 176,52 216,70 L216,206 C176,190 146,192 128,210 C110,192 80,190 40,206 Z', `url(#${id}c)`, P, id)}
    ${forme('M52,78 C84,64 110,68 124,82 L124,196 C108,182 84,180 52,192 Z', '#f2e6cc', P, id, '', true)}
    ${forme('M204,78 C172,64 146,68 132,82 L132,196 C148,182 172,180 204,192 Z', '#efe0c2', P, id, '', true)}
    ${trait('M66,100 C84,94 100,94 112,100 M66,120 C84,114 100,114 112,120 M66,140 C84,134 100,134 112,140', '#5a3a6a', 3, 0.55)}
    ${trait('M144,100 C156,94 172,94 190,100 M144,120 C156,114 172,114 190,120', '#5a3a6a', 3, 0.55)}
    <circle cx="168" cy="152" r="16" fill="none" stroke="${P.tc}" stroke-width="4" opacity=".9"/>${trait('M168,136 L168,168 M152,152 L184,152', P.tc, 3, 0.9)}
    <circle cx="128" cy="38" r="14" fill="${clair(P.tc, 0.4)}" opacity=".85"/><circle cx="92" cy="30" r="6" fill="${clair(P.tc, 0.5)}" opacity=".7"/><circle cx="164" cy="28" r="7" fill="${clair(P.tc, 0.5)}" opacity=".7"/>
    ${P.gemme ? gemme(128, 222, 9, id) : ''}`;
}
export function svgObjet(cat, type, tier) {
  let corps = '';
  if (cat === 'armure') corps = type === 'casque' ? svgCasque(tier) : type === 'plastron' ? svgPlastron(tier) : svgBottes(tier);
  else if (type === 'epee') corps = svgEpee(tier);
  else if (type === 'arbalete') corps = svgArbalete(tier);
  else if (type === 'baton') corps = svgBaton(tier);
  else if (type === 'ombre') corps = svgDagues(tier, '#3a2a5a');
  else if (type === 'assassin') corps = svgDagues(tier, '#8a1a2a');
  else if (type === 'demon') corps = svgDagues(tier, '#2a0006');
  else if (type === 'invocateur') corps = svgBaton(tier);
  else if (type === 'orage') corps = svgHaches(tier);
  else if (type === 'esprit') corps = svgGrimoire(tier);
  else return null;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="14 10 228 232" width="192" height="192">${corps}</svg>`;
}
