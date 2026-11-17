// Bâtiments : on choisit, on pose un chantier, les ombres le construisent pièce par pièce sous tes yeux.
// Pièces Quaternius « Medieval Village MegaKit » (même style que les personnages).
import { THREE, G, V, emettre, son, projeter } from './moteur.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { buche, hauteur, arbres, RESERVE } from './monde.js';

const loader = new GLTFLoader(), texL = new THREE.TextureLoader();
const B = 'assets/batiments/';
const PIECES = ['Floor_WoodDark', 'Floor_Brick', 'Corner_Exterior_Wood', 'Wall_Plaster_WoodGrid', 'Wall_Plaster_Straight', 'Wall_Plaster_Door_Round', 'Wall_UnevenBrick_Straight', 'Wall_Plaster_Window_Wide_Round', 'Roof_RoundTiles_6x6', 'Roof_RoundTiles_4x4', 'Prop_Crate', 'Prop_Wagon', 'Prop_WoodenFence_Single', 'Prop_Chimney'];
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
const R = Math.PI / 2;
const p = (n, x, y, z, r = 0, e = 1) => ({ n, x, y, z, r, e });
export const TYPES = {
  scierie: {
    nom: 'Scierie', icone: '🪚', cout: { bois: 80 }, travail: 36, rayon: 4.2, depot: 'bois', bonus: 1.3,
    effet: 'Dépôt de bois au cœur de la forêt · +30 % sur chaque livraison',
    plan: () => [
      ...[-2, 0, 2].flatMap(x => [-2, 0, 2].map(z => p('Floor_WoodDark', x, 0.02, z))),
      p('Corner_Exterior_Wood', -3, 0, -3), p('Corner_Exterior_Wood', 3, 0, -3), p('Corner_Exterior_Wood', -3, 0, 3), p('Corner_Exterior_Wood', 3, 0, 3),
      p('Wall_Plaster_WoodGrid', -2, 0, -2.9), p('Wall_Plaster_WoodGrid', 0, 0, -2.9), p('Wall_Plaster_WoodGrid', 2, 0, -2.9),
      p('Wall_Plaster_WoodGrid', -2.9, 0, -2, R), p('Wall_Plaster_WoodGrid', -2.9, 0, 0, R),
      p('Roof_RoundTiles_6x6', 0, 3.05, 0),
      p('Prop_Crate', 2, 0.02, -1.8, 0.3, 0.8), p('Prop_Crate', 2.1, 0.86, -1.8, 0.9, 0.6), p('*scie', 0, 0.02, 0.4),
    ],
  },
  mine: {
    nom: 'Camp de mineurs', icone: '⛏️', cout: { bois: 150 }, travail: 50, rayon: 3.6, depot: 'pierre', bonus: 1.3,
    effet: 'Débloque la pierre : tes ombres taillent les filons de la carrière',
    plan: () => [
      ...[-1, 1].flatMap(x => [-1, 1].map(z => p('Floor_Brick', x, 0.02, z))),
      p('Corner_Exterior_Wood', -2, 0, -2), p('Corner_Exterior_Wood', 2, 0, -2), p('Corner_Exterior_Wood', -2, 0, 2), p('Corner_Exterior_Wood', 2, 0, 2),
      p('Wall_UnevenBrick_Straight', -1, 0, -1.9), p('Wall_UnevenBrick_Straight', 1, 0, -1.9),
      p('Roof_RoundTiles_4x4', 0, 3.0, 0),
      p('Prop_Wagon', 3.3, 0, 0.6, 0.15, 0.8), p('Prop_Crate', -1.2, 0.02, -1.2, 0.2, 0.7),
    ],
  },
  palissade: {
    nom: 'Palissade', icone: '🪵', cout: { bois: 12 }, travail: 6, rayon: 1.2, segment: true,
    effet: 'Un segment de 2 m pour protéger ton camp (les raids arrivent bientôt)',
    plan: () => [p('Prop_WoodenFence_Single', 0, 0, 0, 0, 1.2)],
  },
  puits: {
    nom: 'Puits', icone: '💧', cout: { bois: 40, pierre: 30 }, travail: 20, rayon: 1.6,
    effet: 'Cœur du futur village · +20 mana max',
    plan: () => [p('well_01', 0, 0, 0)],
  },
};
// ---------------- Instances ----------------
export const batiments = [];
function piece(d) {
  if (d.n === '*scie') { const g = new THREE.Group(); const b = buche(0.32, 2.4); b.position.y = 0.75; g.add(b); for (const s of [-0.9, 0.9]) { const t = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.75, 0.9), new THREE.MeshStandardMaterial({ color: '#6b4426' })); t.position.set(s, 0.37, 0); t.castShadow = true; g.add(t); } return g; }
  const o = M[d.n].clone(); return o;
}
export function creerBatiment(s, fini = false) {
  const T = TYPES[s.type], g = new THREE.Group(); g.position.set(s.x, hauteur(s.x, s.z), s.z); g.rotation.y = s.r || 0; G.scene.add(g);
  const pcs = T.plan().map(d => { const o = piece(d); o.position.set(d.x, d.y, d.z); o.rotation.y = d.r; o.scale.setScalar(d.e); o.userData.e = d.e; g.add(o); o.visible = fini; return o; });
  // chantier : piquets et cordes tant que ce n'est pas fini
  const chantier = new THREE.Group(); const rr = T.rayon * 0.82;
  for (const [x, z] of [[-rr, -rr], [rr, -rr], [rr, rr], [-rr, rr]]) { const pq = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.9, 6), new THREE.MeshStandardMaterial({ color: '#c8a070' })); pq.position.set(x, 0.45, z); chantier.add(pq); }
  const corde = new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints([V(-rr, 0.8, -rr), V(rr, 0.8, -rr), V(rr, 0.8, rr), V(-rr, 0.8, rr)]), new THREE.LineBasicMaterial({ color: '#f2d27a' })); chantier.add(corde);
  chantier.visible = !fini; g.add(chantier);
  const b = { s, T, g, pcs, chantier, fini, montre: fini ? pcs.length : 0, pop: [] };
  batiments.push(b); return b;
}
// un coup de marteau : le chantier avance, les pièces apparaissent dans l'ordre (sol → poteaux → murs → toit)
export function marteler(b, force, pos) {
  if (b.fini) return true;
  b.s.prog = Math.min(1, (b.s.prog || 0) + force / b.T.travail);
  emettre(V(pos.x, pos.y + 0.3, pos.z), { n: 5, c1: '#f2e0b8', c2: '#8a7050', vit: 1.8, vie: 0.5, taille: 0.12, grav: 6 });
  son('impactMetal_light_000', 0.32, 1 + Math.random() * 0.2, pos);
  const voulu = Math.floor(b.s.prog * b.pcs.length + 1e-6);
  while (b.montre < voulu) { const o = b.pcs[b.montre++]; o.visible = true; o.scale.setScalar(0.01); b.pop.push({ o, t: 0 }); emettre(o.getWorldPosition(V()), { n: 14, c1: '#d8c8a8', c2: '#6a5a4a', vit: 2.2, vie: 0.7, taille: 0.25, grav: 2 }); son('impactPunch_medium_001', 0.3, 0.9, pos); }
  if (b.s.prog >= 1) { b.fini = b.s.fini = true; b.chantier.visible = false; for (const o of b.pcs) o.visible = true; return true; }
  return false;
}
export function majBatiments(dt) {
  for (const b of batiments) for (let i = b.pop.length - 1; i >= 0; i--) { const q = b.pop[i]; q.t += dt; const k = Math.min(1, q.t / 0.35), e = 1 + Math.sin(k * Math.PI) * 0.12; q.o.scale.setScalar(q.o.userData.e * k * e); if (k >= 1) { q.o.scale.setScalar(q.o.userData.e); b.pop.splice(i, 1); } }
}
// dépôt le plus proche pour une ressource (réserve du camp ou bâtiment spécialisé, avec bonus)
export function depotProche(pos, res) {
  let best = { pos: RESERVE, bonus: 1, nom: 'reserve' }, bd = Math.hypot(RESERVE.x - pos.x, RESERVE.z - pos.z);
  for (const b of batiments) if (b.fini && b.T.depot === res) { const d = Math.hypot(b.g.position.x - pos.x, b.g.position.z - pos.z); if (d < bd) { bd = d; best = { pos: b.g.position, bonus: b.T.bonus, nom: b.T.nom }; } }
  return best;
}
export const chantierProche = (pos) => { let best = null, bd = 1e9; for (const b of batiments) if (!b.fini) { const d = Math.hypot(b.g.position.x - pos.x, b.g.position.z - pos.z); if (d < bd) { bd = d; best = b; } } return best; };
export const aBatiment = (type) => batiments.some(b => b.fini && b.s.type === type);
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
    for (const d of TYPES[type].plan()) { const o = piece(d); o.position.set(d.x, d.y, d.z); o.rotation.y = d.r; o.scale.setScalar(d.e); o.traverse(m => { if (m.isMesh) { m.material = mat; m.castShadow = false; } }); g.add(o); }
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
    if (b.fini || b.T.segment) { if (e) { e.remove(); eti.delete(b); } continue; }
    if (!e) { e = document.createElement('div'); e.className = 'eti chantier'; document.getElementById('bulles').appendChild(e); eti.set(b, e); }
    const s = projeter(V(b.g.position.x, b.g.position.y + 2.2, b.g.position.z)), html = `🔨 ${b.T.nom} <em>${Math.floor((b.s.prog || 0) * 100)} %</em>`;
    if (e._h !== html) { e.innerHTML = html; e._h = html; } e.style.display = s.devant ? '' : 'none'; e.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-100%)`;
  }
}
