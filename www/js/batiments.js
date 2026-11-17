// Bâtiments : on choisit, on pose un chantier, les ombres le construisent pièce par pièce sous tes yeux.
// Pièces Quaternius « Medieval Village MegaKit » (même style que les personnages).
import { THREE, G, V, emettre, son, projeter } from './moteur.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { buche, hauteur, arbres, RESERVE } from './monde.js';

const loader = new GLTFLoader(), texL = new THREE.TextureLoader();
const B = 'assets/batiments/';
const PIECES = ['Corner_Exterior_Brick', 'Wall_UnevenBrick_Door_Round', 'Wall_UnevenBrick_Window_Wide_Round', 'Floor_WoodLight', 'Prop_Support', 'Prop_Brick1', 'Prop_Brick2', 'Prop_MetalFence_Ornament', 'Floor_WoodDark', 'Floor_Brick', 'Corner_Exterior_Wood', 'Wall_Plaster_WoodGrid', 'Wall_Plaster_Straight', 'Wall_Plaster_Door_Round', 'Wall_UnevenBrick_Straight', 'Wall_Plaster_Window_Wide_Round', 'Roof_RoundTiles_6x6', 'Roof_RoundTiles_4x4', 'Prop_Crate', 'Prop_Wagon', 'Prop_WoodenFence_Single', 'Prop_Chimney'];
const VILLAGE = ['fire_01', 'well_01', 'stall_01', 'ladder_01'];
const M = {};
const TEX = { MI_WoodTrim: 'woodtrim', MI_WoodTrim_Wear: 'woodtrim', MI_Plaster: 'plaster', MI_RockTrim: 'rocktrim', MI_Brick: 'brick', MI_RoundTiles: 'roundtiles', MI_UnevenBrick: 'unevenbrick', MI_MetalOrnaments: 'metal', MI_RedBrick: 'redbrick' };
const mats = {};
function matKit(m) { // les pièces du kit n'ont pas de texture embarquée : on applique celle de leur matériau
  const t = TEX[m.name]; if (!t) { if (/Glass/.test(m.name)) { m.color.set('#9fc4e0'); m.roughness = 0.2; } return m; }
  if (!mats[m.name]) { const tx = texL.load(B + 'tex/' + t + '_c.jpg'); tx.colorSpace = THREE.SRGBColorSpace; tx.wrapS = tx.wrapT = THREE.RepeatWrapping; tx.anisotropy = 8; mats[m.name] = new THREE.MeshStandardMaterial({ map: tx, roughness: 0.85, metalness: t === 'metal' ? 0.6 : 0, side: THREE.DoubleSide }); }
  return mats[m.name];
}
export async function chargerBatiments() {
  await Promise.all([...PIECES.map(n => loader.loadAsync(B + n + '.gltf').then(g => { g.scene.traverse(o => { if (o.isMesh) { o.material = matKit(o.material); o.castShadow = o.receiveShadow = true; } }); M[n] = g.scene; })),
    ...VILLAGE.map(n => loader.loadAsync(B + n + '.glb').then(g => { g.scene.traverse(o => { if (o.isMesh) { o.castShadow = o.receiveShadow = true; } }); M[n] = g.scene; }))]);
}
// ---------------- Plans ----------------
// Proportions de jeu : tout le bâti est agrandi ×1,3 (murs ≈ 2,2× le perso, portes ≈ 1,6×) pour que la caméra entre dedans.
export const ECH = 1.3;
const R = Math.PI / 2, HE = 3.12;
const p = (n, x, y, z, r = 0, e = 1, haut = false) => ({ n, x, y, z, r, e, haut });
const MURS = {
  platre: { p: 'Wall_Plaster_Straight', g: 'Wall_Plaster_WoodGrid', f: 'Wall_Plaster_Window_Wide_Round', o: 'Wall_Plaster_Door_Round' },
  brique: { p: 'Wall_UnevenBrick_Straight', g: 'Wall_UnevenBrick_Straight', f: 'Wall_UnevenBrick_Window_Wide_Round', o: 'Wall_UnevenBrick_Door_Round' },
};
// maison modulaire : w×d cases de 2 m ; chaque étage décrit ses 4 côtés case par case (p plein, g colombage, f fenêtre, o porte, - ouvert)
function maison({ w, d, sol = 'Floor_WoodDark', coins = 'Corner_Exterior_Wood', etages, toit, extras = [] }) {
  const L = [], cases = (n) => Array.from({ length: n }, (_, i) => -n + 1 + 2 * i);
  for (const x of cases(w)) for (const z of cases(d)) L.push(p(sol, x, 0.02, z));
  etages.forEach((et, k) => {
    const y = k * HE, h = k > 0, M = MURS[et.m];
    if (k > 0) for (const x of cases(w)) for (const z of cases(d)) L.push(p('Floor_WoodLight', x, y + 0.02, z, 0, 1, true));
    for (const [cx, cz] of [[-w, -d], [w, -d], [w, d], [-w, d]]) L.push(p(et.coins || coins, cx, y, cz, Math.atan2(cx, cz) + Math.PI * 0.75, 1, h));
    const cote = (spec, pos, nx, nz) => (spec || '').split('').forEach((c, i) => { if (c !== '-') L.push({ ...pos(i), n: M[c], haut: h, mur: !h && c, e: 1, nx, nz }); });
    const cx = cases(w), cz = cases(d);
    cote(et.n, i => ({ x: cx[i], y, z: -d + 0.1, r: 0 }), 0, -1); cote(et.s, i => ({ x: cx[i], y, z: d - 0.1, r: Math.PI }), 0, 1);
    cote(et.w, i => ({ x: -w + 0.1, y, z: cz[i], r: R }), -1, 0); cote(et.e, i => ({ x: w - 0.1, y, z: cz[i], r: -R }), 1, 0);
  });
  L.push(p(toit, 0, etages.length * HE - 0.07, 0, 0, 1, true));
  return L.concat(extras);
}
const dalle = () => [-1, 1].flatMap(x => [-1, 1].map(z => p('Floor_Brick', x, 0.02, z))), briques = () => [[1.5, 1.2], [1.7, 1.0], [-1.6, -1.3]].map(([x, z], i) => p('Prop_Brick' + (i % 2 + 1), x, 0.11, z, i, 1.4));
const scie = p('*scie', 0, 0.02, 0.4), caisses = [p('Prop_Crate', 2, 0.02, -1.8, 0.3, 0.8), p('Prop_Crate', 2.1, 0.86, -1.8, 0.9, 0.6)];
export const TYPES = {
  scierie: {
    nom: 'Scierie', icone: '🪚', cout: { bois: 80 }, travail: 36, rayon: 5.4, demi: 3, depot: 'bois',
    niveaux: [
      { bonus: 1.3, effet: '+30 % sur chaque livraison de bois', plan: () => maison({ w: 3, d: 3, etages: [{ m: 'platre', n: 'ggg', w: 'gg-' }], toit: 'Roof_RoundTiles_6x6', extras: [...caisses, scie] }) },
      { bonus: 1.5, repousse: 2, cout: { bois: 220, pierre: 60 }, travail: 60, effet: '+50 % de bois · les arbres repoussent 2× plus vite', plan: () => maison({ w: 3, d: 3, etages: [{ m: 'brique', n: 'pfp', w: 'pp-', e: '-pp' }, { m: 'platre', n: 'ggg', w: 'ggg', e: 'ggg', s: 'gfg' }], toit: 'Roof_RoundTiles_6x6', extras: [...caisses, scie, p('Prop_Chimney', -2, 6.2, -2, 0, 1, true)] }) },
      { bonus: 1.8, repousse: 3, charge: 2, cout: { bois: 500, pierre: 200 }, travail: 90, effet: '+80 % de bois · repousse 3× · tes bûcherons portent +2', plan: () => maison({ w: 3, d: 3, coins: 'Corner_Exterior_Brick', etages: [{ m: 'brique', n: 'pfp', w: 'fpf', e: 'fpf', s: 'p-p' }, { m: 'platre', n: 'fff', w: 'fgf', e: 'fgf', s: 'fgf' }], toit: 'Roof_RoundTiles_6x6', extras: [...caisses, scie, p('Prop_Wagon', 1.8, 0, 4.6, 0.2, 0.8), p('Prop_Chimney', -2, 6.2, -2, 0, 1, true)] }) },
    ],
  },
  mine: {
    nom: 'Camp de mineurs', icone: '⛏️', cout: { bois: 150 }, travail: 50, rayon: 4.7, demi: 2, depot: 'pierre',
    niveaux: [
      { bonus: 1.3, effet: 'Débloque la pierre · +30 % par livraison', plan: () => maison({ w: 2, d: 2, sol: 'Floor_Brick', etages: [{ m: 'brique', n: 'pp' }], toit: 'Roof_RoundTiles_4x4', extras: [p('Prop_Wagon', 3.3, 0, 0.6, 0.15, 0.8), p('Prop_Crate', -1.2, 0.02, -1.2, 0.2, 0.7)] }) },
      { bonus: 1.5, repousse: 2, cout: { bois: 260, pierre: 120 }, travail: 70, effet: '+50 % de pierre · les filons reviennent 2× plus vite', plan: () => maison({ w: 2, d: 2, sol: 'Floor_Brick', etages: [{ m: 'brique', n: 'pp', w: 'p-', e: '-p' }, { m: 'platre', n: 'gg', w: 'gg', e: 'gg', s: 'fg' }], toit: 'Roof_RoundTiles_4x4', extras: [p('Prop_Wagon', 3.3, 0, 0.6, 0.15, 0.8), p('Prop_Crate', -1.2, 0.02, -1.2, 0.2, 0.7), p('Prop_Crate', 1.1, 0.02, -1.2, 0.7, 0.6)] }) },
      { bonus: 1.8, repousse: 3, charge: 2, cout: { bois: 550, pierre: 300 }, travail: 100, effet: '+80 % de pierre · repousse 3× · tes tailleurs portent +2', plan: () => maison({ w: 2, d: 2, sol: 'Floor_Brick', coins: 'Corner_Exterior_Brick', etages: [{ m: 'brique', n: 'pp', w: 'fp', e: 'pf' }, { m: 'brique', n: 'ff', w: 'ff', e: 'ff', s: 'ff' }], toit: 'Roof_RoundTiles_4x4', extras: [p('Prop_Wagon', 3.3, 0, 0.6, 0.15, 0.8), p('Prop_Crate', -1.2, 0.02, -1.2, 0.2, 0.7), p('Prop_Crate', 1.1, 0.02, -1.2, 0.7, 0.6)] }) },
    ],
  },
  palissade: {
    nom: 'Palissade', icone: '🪵', cout: { bois: 12 }, travail: 6, rayon: 1.2, segment: true, ech: 1,
    niveaux: [{ effet: 'Un segment de 2 m pour protéger ton camp (les raids arrivent bientôt)', plan: () => [p('Prop_WoodenFence_Single', 0, 0, 0, 0, 1.2)] }],
  },
  puits: {
    nom: 'Puits', icone: '💧', cout: { bois: 40, pierre: 30 }, travail: 20, rayon: 2.6, ech: 1.15,
    niveaux: [
      { mana: 20, effet: 'Cœur du futur village · +20 mana max', plan: () => [p('well_01', 0, 0, 0)] },
      { mana: 45, regen: 1.5, cout: { bois: 120, pierre: 120 }, travail: 40, effet: '+45 mana max · mana 1,5× plus rapide', plan: () => [...dalle(), p('well_01', 0, 0.03, 0), ...briques()] },
      { mana: 80, regen: 2, cout: { bois: 300, pierre: 300 }, travail: 70, effet: '+80 mana max · mana 2× plus rapide', plan: () => [...dalle(), p('well_01', 0, 0.03, 0), ...briques(), ...[0, 1, 2, 3].map(i => p('Prop_MetalFence_Ornament', Math.sin(i * R) * 2, 0, Math.cos(i * R) * 2, i * R, 0.5))] },
    ],
  },
};
for (const T of Object.values(TYPES)) T.ech ??= ECH;
export const niveauDe = (b) => b.T.niveaux[(b.s.niv || 1) - 1];
export const prochain = (b) => b.T.niveaux[b.s.niv || 1];
export const enTravaux = (b) => !b.fini || !!b.s.amel;
// ---------------- Instances ----------------
export const batiments = [];
function piece(d) {
  if (d.n === '*scie') { const g = new THREE.Group(); const b = buche(0.32, 2.4); b.position.y = 0.75; g.add(b); for (const s of [-0.9, 0.9]) { const t = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.75, 0.9), new THREE.MeshStandardMaterial({ color: '#6b4426' })); t.position.set(s, 0.37, 0); t.castShadow = true; g.add(t); } return g; }
  return M[d.n].clone();
}
function monter(b, visibles) { // (re)crée les pièces du niveau courant
  if (b.corps) b.g.remove(b.corps);
  const corps = new THREE.Group(); corps.scale.setScalar(b.T.ech); b.g.add(corps); b.corps = corps; b.murs = [];
  b.pcs = niveauDe(b).plan().map(d => { const o = piece(d); o.position.set(d.x, d.y, d.z); o.rotation.y = d.r; o.scale.setScalar(d.e); o.userData.e = d.e; o.userData.haut = d.haut; if (d.mur) o.userData.nrm = [d.nx, d.nz]; o.visible = visibles; corps.add(o); if (d.mur) b.murs.push(d); return o; });
}
function echafaudage(T) { // échafaudage visible pendant une amélioration
  const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color: '#b08a5a', roughness: 0.9 }), r = (T.demi || 1) * T.ech + 0.6, h = 3.4 * T.ech;
  for (const [x, z] of [[-r, -r], [r, -r], [r, r], [-r, r], [0, -r], [0, r], [-r, 0], [r, 0]]) { const pq = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.08, h * 1.6, 6), m); pq.position.set(x, h * 0.8, z); pq.castShadow = true; g.add(pq); }
  for (const y of [h * 0.55, h * 1.15]) for (const [x, z, rx] of [[0, -r, 0], [0, r, 0], [-r, 0, 1], [r, 0, 1]]) { const pl = new THREE.Mesh(new THREE.BoxGeometry(r * 2, 0.08, 0.5), m); pl.position.set(x, y, z); pl.rotation.y = rx * R; pl.castShadow = true; g.add(pl); }
  return g;
}
export function creerBatiment(s, fini = false) {
  const T = TYPES[s.type], g = new THREE.Group(); g.position.set(s.x, hauteur(s.x, s.z), s.z); g.rotation.y = s.r || 0; G.scene.add(g);
  s.niv ||= 1;
  const b = { s, T, g, fini, pop: [] }; monter(b, fini); b.montre = fini ? b.pcs.length : 0;
  const chantier = new THREE.Group(); const rr = T.rayon * 0.82;
  for (const [x, z] of [[-rr, -rr], [rr, -rr], [rr, rr], [-rr, rr]]) { const pq = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.9, 6), new THREE.MeshStandardMaterial({ color: '#c8a070' })); pq.position.set(x, 0.45, z); chantier.add(pq); }
  chantier.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints([V(-rr, 0.8, -rr), V(rr, 0.8, -rr), V(rr, 0.8, rr), V(-rr, 0.8, rr)]), new THREE.LineBasicMaterial({ color: '#f2d27a' })));
  chantier.visible = !fini; g.add(chantier); b.chantier = chantier;
  b.echaf = echafaudage(T); b.echaf.visible = !!s.amel; g.add(b.echaf);
  batiments.push(b); return b;
}
export function ameliorer(b) { const n = prochain(b); if (!n || !b.fini || b.s.amel) return false; b.s.amel = true; b.s.prog = 0; b.echaf.visible = true; b.echaf.scale.set(1, 0.01, 1); b.pop.push({ o: b.echaf, t: 0, e: 1, y: true }); return true; }
// un coup de marteau : le chantier avance, les pièces apparaissent dans l'ordre (sol → poteaux → murs → étage → toit)
export function marteler(b, force, pos) {
  if (!enTravaux(b)) return true;
  const amel = !!b.s.amel, T = amel ? prochain(b) : b.T;
  b.s.prog = Math.min(1, (b.s.prog || 0) + force / (T.travail || b.T.travail));
  emettre(V(pos.x, pos.y + 0.3, pos.z), { n: 5, c1: '#f2e0b8', c2: '#8a7050', vit: 1.8, vie: 0.5, taille: 0.12, grav: 6 });
  son('impactMetal_light_000', 0.32, 1 + Math.random() * 0.2, pos);
  if (!amel) {
    const voulu = Math.floor(b.s.prog * b.pcs.length + 1e-6);
    while (b.montre < voulu) { const o = b.pcs[b.montre++]; o.visible = true; o.scale.setScalar(0.01); b.pop.push({ o, t: 0 }); emettre(o.getWorldPosition(V()), { n: 14, c1: '#d8c8a8', c2: '#6a5a4a', vit: 2.2, vie: 0.7, taille: 0.25, grav: 2 }); son('impactPunch_medium_001', 0.3, 0.9, pos); }
  }
  if (b.s.prog < 1) return false;
  if (amel) { // le nouveau niveau surgit en cascade, l'échafaudage tombe
    b.s.niv++; b.s.amel = false; b.echaf.visible = false; monter(b, true);
    b.pcs.forEach((o, i) => { o.scale.setScalar(0.01); b.pop.push({ o, t: -i * 0.035 }); });
    emettre(V(b.g.position.x, b.g.position.y + 3, b.g.position.z), { n: 120, c1: '#ffe9a0', c2: '#8a7050', vit: 6, vie: 1.2, taille: 0.3, grav: 3 });
  }
  b.fini = b.s.fini = true; b.chantier.visible = false; for (const o of b.pcs) o.visible = true; return true;
}
export function majBatiments(dt) {
  for (const b of batiments) for (let i = b.pop.length - 1; i >= 0; i--) {
    const q = b.pop[i]; q.t += dt; if (q.t < 0) { q.o.scale.setScalar(0.01); continue; }
    const k = Math.min(1, q.t / 0.35), e = 1 + Math.sin(k * Math.PI) * 0.12;
    if (q.y) q.o.scale.set(1, Math.max(0.01, k), 1); else q.o.scale.setScalar(q.o.userData.e * k * e);
    if (k >= 1) { if (q.y) q.o.scale.set(1, 1, 1); else q.o.scale.setScalar(q.o.userData.e); b.pop.splice(i, 1); }
  }
}
// repère local d'un bâtiment
const _l = V();
function local(b, x, z) { const c = Math.cos(-b.g.rotation.y), s = Math.sin(-b.g.rotation.y), dx = x - b.g.position.x, dz = z - b.g.position.z; return _l.set((dx * c + dz * s) / b.T.ech, 0, (-dx * s + dz * c) / b.T.ech); }
export function dedans(x, z) { for (const b of batiments) if (b.fini && b.T.demi) { const q = local(b, x, z); if (Math.abs(q.x) < b.T.demi && Math.abs(q.z) < b.T.demi) return b; } return null; }
// collision avec les murs (les portes et les côtés ouverts laissent passer)
export function bloque(x, z, r = 0.35) {
  for (const b of batiments) {
    if (!b.fini || !b.murs || !b.murs.length) continue;
    if (Math.hypot(x - b.g.position.x, z - b.g.position.z) > b.T.rayon + 1) continue;
    const q = local(b, x, z), rr = r / b.T.ech;
    for (const m of b.murs) {
      const horiz = Math.abs(Math.sin(m.r)) < 0.5, u = horiz ? q.x - m.x : q.z - m.z, v = horiz ? q.z - m.z : q.x - m.x;
      if (Math.abs(v) > 0.25 + rr || Math.abs(u) > 1 + rr) continue;
      if (m.mur === 'o' && Math.abs(u) < 0.62 - rr * 0.3) continue; // la porte
      return true;
    }
    const D = b.T.demi; for (const [cx, cz] of [[-D, -D], [D, -D], [D, D], [-D, D]]) if (Math.hypot(q.x - cx, q.z - cz) < 0.3 + rr) return true;
  }
  return false;
}
// dépôt le plus proche pour une ressource : on livre devant le bâtiment, pas à travers les murs
export function depotProche(pos, res) {
  let best = { pos: RESERVE, bonus: 1, nom: 'reserve', r: 2.4 }, bd = Math.hypot(RESERVE.x - pos.x, RESERVE.z - pos.z);
  for (const b of batiments) if (b.fini && b.T.depot === res) {
    const f = (b.T.demi + 1.4) * b.T.ech, a = b.g.rotation.y, pt = V(b.g.position.x + Math.sin(a) * f, b.g.position.y, b.g.position.z + Math.cos(a) * f);
    const d = Math.hypot(pt.x - pos.x, pt.z - pos.z); if (d < bd) { bd = d; best = { pos: pt, bonus: niveauDe(b).bonus, nom: b.T.nom, r: 1.1 }; }
  }
  return best;
}
export const chantierProche = (pos) => { let best = null, bd = 1e9; for (const b of batiments) if (enTravaux(b)) { const d = Math.hypot(b.g.position.x - pos.x, b.g.position.z - pos.z); if (d < bd) { bd = d; best = b; } } return best; };
export const aBatiment = (type) => batiments.some(b => b.fini && b.s.type === type);
export const meilleur = (type, k) => batiments.reduce((m, b) => b.fini && b.s.type === type ? Math.max(m, niveauDe(b)[k] || 0) : m, 0);
// intérieur : quand le héros entre, l'étage et le toit s'effacent et la caméra se rapproche
let interieur = null;
export function majInterieur(x, z) {
  const b = dedans(x, z);
  if (b !== interieur) { if (interieur) for (const o of interieur.pcs) if (o.userData.haut || o.userData.nrm) o.visible = true; if (b) for (const o of b.pcs) if (o.userData.haut) o.visible = false; interieur = b; }
  if (b) { // les murs du rez-de-chaussée côté caméra s'effacent aussi : on voit toujours son héros
    const a = G.camYaw - b.g.rotation.y, cx = Math.sin(a), cz = Math.cos(a);
    for (const o of b.pcs) if (o.userData.nrm) o.visible = o.userData.nrm[0] * cx + o.userData.nrm[1] * cz < 0.35;
  }
  return b;
}
// ---------------- Placement ----------------
export function placementValide(type, x, z) {
  const T = TYPES[type], r = T.rayon;
  if (Math.hypot(x, z) > 60) return false;
  if (Math.hypot(x - RESERVE.x, z - RESERVE.z) < r + 2.6) return false;
  for (const b of batiments) { const d = Math.hypot(b.g.position.x - x, b.g.position.z - z); if (d < r + b.T.rayon - (T.segment && b.T.segment ? 0.6 : 0)) return false; }
  for (const a of arbres) if (a.etat !== 'souche' && Math.hypot(a.pos.x - x, a.pos.z - z) < r + 0.6) return false;
  return true;
}
let fantome = null;
export function fantomeBatiment(type, x, z, r, ok) {
  if (!type) { if (fantome) { G.scene.remove(fantome.g); fantome = null; } return; }
  if (!fantome || fantome.type !== type) {
    if (fantome) G.scene.remove(fantome.g);
    const g = new THREE.Group(), mat = new THREE.MeshBasicMaterial({ color: '#7dff9b', transparent: true, opacity: 0.35, depthWrite: false });
    const corps = new THREE.Group(); corps.scale.setScalar(TYPES[type].ech); g.add(corps);
    for (const d of TYPES[type].niveaux[0].plan()) { const o = piece(d); o.position.set(d.x, d.y, d.z); o.rotation.y = d.r; o.scale.setScalar(d.e); o.traverse(m => { if (m.isMesh) { m.material = mat; m.castShadow = false; } }); corps.add(o); }
    const zone = new THREE.Mesh(new THREE.RingGeometry(TYPES[type].rayon - 0.15, TYPES[type].rayon, 40).rotateX(-R), mat); zone.position.y = 0.06; g.add(zone);
    G.scene.add(g); fantome = { type, g, mat };
  }
  fantome.g.position.set(x, hauteur(x, z), z); fantome.g.rotation.y = r; fantome.mat.color.set(ok ? '#7dff9b' : '#ff5a5a');
}
// étiquettes de chantier (progression visible)
const eti = new Map();
export function majEtiquettesChantiers() {
  for (const b of batiments) {
    let e = eti.get(b);
    if (!enTravaux(b) || b.T.segment) { if (e) { e.remove(); eti.delete(b); } continue; }
    if (!e) { e = document.createElement('div'); e.className = 'eti chantier'; document.getElementById('bulles').appendChild(e); eti.set(b, e); }
    const s = projeter(V(b.g.position.x, b.g.position.y + (b.s.amel ? 9 : 2.2), b.g.position.z)), html = `${b.s.amel ? '⬆️' : '🔨'} ${b.T.nom}${b.s.amel ? ' niv. ' + (b.s.niv + 1) : ''} <em>${Math.floor((b.s.prog || 0) * 100)} %</em>`;
    if (e._h !== html) { e.innerHTML = html; e._h = html; } e.style.display = s.devant ? '' : 'none'; e.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-100%)`;
  }
}
