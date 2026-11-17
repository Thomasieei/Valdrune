// Le monde : clairière du camp, forêt (arbres qu'on abat vraiment), réserve de bois, feu de camp, dépouilles.
import { THREE, G, V, emettre, son } from './moteur.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
const N = {};
const NATURE = ['oak_01', 'birch_01', 'pine_01', 'stump_01', 'log_01', 'boulder_01', 'rocks_01', 'rock_mossy_01', 'bush_01', 'fern_01', 'flowers_01', 'grass_01', 'mushrooms_01', 'pebbles_01', 'deadtree_01'];
export async function chargerNature(progres) {
  let n = 0;
  await Promise.all(NATURE.map(k => loader.loadAsync(`assets/nature/${k}.glb`).then(g => { N[k] = g.scene; g.scene.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; if (o.material) o.material.envMapIntensity = 0.6; } }); progres && progres(++n / NATURE.length); })));
}
// bûche : écorce brune, cœur clair (lisible même de loin)
const GEO_BUCHE = new THREE.CylinderGeometry(1, 1, 1, 10, 1).rotateZ(Math.PI / 2);
const MAT_ECORCE = new THREE.MeshStandardMaterial({ color: '#6b4426', roughness: 0.95 }), MAT_COEUR = new THREE.MeshStandardMaterial({ color: '#e2bf86', roughness: 0.8 });
export function buche(rayon, longueur) {
  const g = new THREE.Group(), b = new THREE.Mesh(GEO_BUCHE, [MAT_ECORCE, MAT_COEUR, MAT_COEUR]); b.scale.set(longueur, rayon, rayon); b.castShadow = b.receiveShadow = true; g.add(b); return g;
}
// ---------------- Terrain ----------------
export const CAMP = V(0, 0, 0), RESERVE = V(5, 0, 4), FEU = V(-1.5, 0, -1.5);
function bruit(x, z) { return Math.sin(x * 0.071) * Math.cos(z * 0.063) * 0.9 + Math.sin(x * 0.17 + z * 0.13) * 0.35 + Math.cos(x * 0.031 - z * 0.047) * 1.4; }
export function hauteur(x, z) { const d = Math.hypot(x, z); const k = Math.min(1, Math.max(0, (d - 13) / 14)); return bruit(x, z) * k * k * (3 - 2 * k); }
function construireTerrain() {
  const T = 170, geo = new THREE.PlaneGeometry(T, T, 120, 120).rotateX(-Math.PI / 2), P = geo.attributes.position, C = new Float32Array(P.count * 3), c = new THREE.Color(), c2 = new THREE.Color();
  for (let i = 0; i < P.count; i++) {
    const x = P.getX(i), z = P.getZ(i), y = hauteur(x, z); P.setY(i, y);
    const n = Math.sin(x * 0.9) * Math.cos(z * 0.8) * 0.5 + Math.sin(x * 0.23 + z * 0.31) * 0.5, d = Math.hypot(x, z);
    c.set('#5f9a3a').lerp(c2.set('#7fb04a'), 0.5 + n * 0.5).offsetHSL(0, 0, y * 0.015);
    const terre = Math.max(0, 1 - Math.abs(d - 0) / 9) * 0.9 + Math.max(0, 1 - Math.hypot(x - RESERVE.x, z - RESERVE.z) / 5) * 0.7; // sol tassé du camp
    c.lerp(c2.set('#9a7a52'), Math.min(0.85, terre));
    C.set([c.r, c.g, c.b], i * 3);
  }
  geo.setAttribute('color', new THREE.BufferAttribute(C, 3)); geo.computeVertexNormals();
  const sol = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 })); sol.receiveShadow = true; G.scene.add(sol);
}
// ---------------- Décor en instances (un seul appel de dessin par type) ----------------
function instancier(modele, transforms) {
  const meshes = []; modele.updateMatrixWorld(true); modele.traverse(o => { if (o.isMesh) meshes.push(o); });
  const groupe = new THREE.Group(), m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s = V();
  const liste = meshes.map(m => { const im = new THREE.InstancedMesh(m.geometry, m.material, transforms.length); im.castShadow = m.castShadow; im.receiveShadow = true; im.userData.local = m.matrixWorld.clone(); groupe.add(im); return im; });
  transforms.forEach((t, i) => { q.setFromAxisAngle(V(0, 1, 0), t.r); s.setScalar(t.e); m4.compose(t.p, q, s); for (const im of liste) im.setMatrixAt(i, m4.clone().multiply(im.userData.local)); });
  for (const im of liste) { im.instanceMatrix.needsUpdate = true; im.computeBoundingSphere(); }
  G.scene.add(groupe); return { liste, transforms, maj(i, t) { q.setFromAxisAngle(V(0, 1, 0), t.r); s.setScalar(t.e); m4.compose(t.p, q, s); for (const im of liste) { im.setMatrixAt(i, m4.clone().multiply(im.userData.local)); im.instanceMatrix.needsUpdate = true; } } };
}
let graine = 7; const rnd = (a = 0, b = 1) => { graine = (graine * 16807) % 2147483647; return a + (graine / 2147483647) * (b - a); };
// ---------------- Arbres ----------------
export const arbres = []; const parType = {};
function construireForet() {
  const types = ['oak_01', 'birch_01', 'pine_01'], T = { oak_01: [], birch_01: [], pine_01: [] };
  for (let k = 0; k < 140; k++) {
    const a = rnd(0, 6.283), d = rnd(15, 62), x = Math.cos(a) * d, z = Math.sin(a) * d;
    if (Math.hypot(x - RESERVE.x, z - RESERVE.z) < 9) continue;
    if (arbres.some(b => Math.hypot(b.pos.x - x, b.pos.z - z) < 3.2)) continue;
    const type = types[Math.floor(rnd(0, 3))], e = rnd(0.85, 1.25), p = V(x, hauteur(x, z), z);
    const ar = { type, i: T[type].length, pos: p, r: rnd(0, 6.28), e, pv: 0, pvMax: 0, etat: 'debout', bois: 0, ouvriers: 0 };
    ar.pvMax = ar.pv = Math.round(10 * e); T[type].push({ p, r: ar.r, e }); arbres.push(ar);
  }
  for (const t of types) parType[t] = instancier(N[t], T[t]);
}
export function arbreProche(p, filtre, max = 999) { let b = null, bd = max; for (const a of arbres) { if (!filtre(a)) continue; const d = Math.hypot(a.pos.x - p.x, a.pos.z - p.z); if (d < bd) { bd = d; b = a; } } return b; }
// un coup de hache : copeaux, son ; à 0 PV l'arbre tombe vraiment
export function frapperArbre(ar, depuis, force = 1) {
  if (ar.etat !== 'debout') return false;
  ar.pv -= force;
  const h = V(ar.pos.x, ar.pos.y + 1.1, ar.pos.z);
  emettre(h, { n: 7, c1: '#e8c48a', c2: '#7a5530', vit: 3.2, vie: 0.6, taille: 0.13, grav: 9, haut: 0.4 });
  son('chop', 0.5, 0.95 + Math.random() * 0.15, ar.pos);
  ar.secoue = 0.25;
  if (ar.pv <= 0) abattre(ar, depuis);
  return true;
}
const chutes = [];
function abattre(ar, depuis) {
  ar.etat = 'tombe'; parType[ar.type].maj(ar.i, { p: ar.pos, r: ar.r, e: 0.0001 });
  const g = N[ar.type].clone(); g.scale.setScalar(ar.e); g.rotation.y = ar.r; const piv = new THREE.Group(); piv.position.copy(ar.pos); piv.add(g); G.scene.add(piv);
  const dir = Math.atan2(ar.pos.x - depuis.x, ar.pos.z - depuis.z); piv.rotation.y = dir; g.rotation.y = ar.r - dir;
  chutes.push({ ar, piv, t: 0 });
  son('impactSoft_heavy_000', 0.35, 0.7, ar.pos);
}
function majChutes(dt) {
  for (let i = chutes.length - 1; i >= 0; i--) {
    const c = chutes[i]; c.t += dt; const k = Math.min(1, c.t / 1.3); c.piv.rotation.x = (k * k) * Math.PI / 2 * 0.98;
    if (k >= 1 && !c.fini) { c.fini = true; G.shake = Math.max(G.shake, 0.25); son('impactSoft_heavy_000', 0.6, 0.5, c.ar.pos); emettre(V(c.piv.position.x + Math.sin(c.piv.rotation.y) * 3, c.ar.pos.y + 0.3, c.piv.position.z + Math.cos(c.piv.rotation.y) * 3), { n: 30, c1: '#cfe08a', c2: '#4a6a2a', vit: 4, vie: 0.8, taille: 0.18, grav: 5 }); }
    if (c.t > 1.9) {
      G.scene.remove(c.piv); chutes.splice(i, 1);
      const ar = c.ar; ar.etat = 'abattu'; ar.bois = Math.round(18 * ar.e);
      // le tronc reste au sol : les ouvriers le débitent ; la souche reste
      const tronc = buche(0.3 * ar.e, 3.6 * ar.e); tronc.rotation.y = c.piv.rotation.y + Math.PI / 2; tronc.position.copy(ar.pos).add(V(Math.sin(c.piv.rotation.y) * 2.1, 0.3 * ar.e, Math.cos(c.piv.rotation.y) * 2.1)); G.scene.add(tronc); ar.tronc = tronc; ar.posTronc = ar.pos.clone().add(V(Math.sin(c.piv.rotation.y) * 1.8, 0, Math.cos(c.piv.rotation.y) * 1.8));
      const s = N.stump_01.clone(); s.scale.setScalar(ar.e); s.position.copy(ar.pos); s.rotation.y = ar.r; G.scene.add(s); ar.souche = s;
    }
  }
}
// débiter le tronc : chaque coup donne du bois au porteur
export function debiter(ar, n) {
  if (ar.etat !== 'abattu' || ar.bois <= 0) return 0;
  const pris = Math.min(n, ar.bois); ar.bois -= pris;
  if (ar.tronc) { const k = 0.35 + 0.65 * ar.bois / Math.round(18 * ar.e); ar.tronc.scale.set(k, 1, 1); }
  emettre(V(ar.posTronc.x, ar.pos.y + 0.4, ar.posTronc.z), { n: 5, c1: '#e8c48a', c2: '#7a5530', vit: 2.5, vie: 0.5, taille: 0.12, grav: 9 });
  son('chop', 0.4, 1.1, ar.posTronc);
  if (ar.bois <= 0) { G.scene.remove(ar.tronc); ar.tronc = null; ar.etat = 'souche'; ar.repousse = 0; }
  return pris;
}
// les souches repoussent : jeune pousse, puis arbre adulte
function majRepousse(dt) {
  for (const ar of arbres) {
    if (ar.etat !== 'souche') continue;
    ar.repousse += dt;
    if (ar.repousse > 90) { const k = Math.min(1, (ar.repousse - 90) / 60); parType[ar.type].maj(ar.i, { p: ar.pos, r: ar.r, e: ar.e * (0.15 + 0.85 * k) }); if (ar.souche && k > 0.2) { G.scene.remove(ar.souche); ar.souche = null; } if (k >= 1) { ar.etat = 'debout'; ar.pv = ar.pvMax; } }
  }
}
function majSecousses(dt) { for (const ar of arbres) if (ar.secoue > 0) { ar.secoue -= dt; const k = Math.max(0, ar.secoue) * 0.25; parType[ar.type].maj(ar.i, { p: V(ar.pos.x + Math.sin(G.t * 60) * k * 0.3, ar.pos.y, ar.pos.z), r: ar.r + Math.sin(G.t * 50) * k, e: ar.e }); } }
// ---------------- Réserve de bois : la pile grandit vraiment ----------------
const pile = []; let pileGroupe = null;
function construireReserve() {
  pileGroupe = new THREE.Group(); pileGroupe.position.copy(RESERVE); G.scene.add(pileGroupe);
  // plancher de rondins : la pile repose dessus (et se voit monter)
  const bois = new THREE.MeshStandardMaterial({ color: '#7a5434', roughness: 0.9 });
  for (let i = 0; i < 7; i++) { const pl = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.1, 2.2), bois); pl.position.set((i - 3) * 0.46, 0.06, 0); pl.rotation.y = (i % 2 ? 0.02 : -0.02); pl.receiveShadow = pl.castShadow = true; pileGroupe.add(pl); }
  for (const x of [-1.75, 1.75]) { const p = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.11, 1.5, 8), bois); p.position.set(x, 0.75, 0); p.castShadow = true; pileGroupe.add(p); }
  let k = 0;
  for (let rang = 0; rang < 5; rang++) for (let i = 0; i < 8 - rang; i++) {
    const b = buche(0.2, 2); b.rotation.y = Math.PI / 2; b.position.set((i - (7 - rang) / 2) * 0.41, 0.31 + rang * 0.36, 0); b.visible = false; pileGroupe.add(b); pile.push(b); k++;
  }
}
export function majPile(bois) { const n = Math.min(pile.length, Math.ceil(bois / 10)); pile.forEach((b, i) => { b.visible = i < n; }); }
// ---------------- Feu de camp ----------------
let feuLum = null;
function construireFeu() {
  const g = new THREE.Group(); g.position.copy(FEU); G.scene.add(g);
  for (let i = 0; i < 6; i++) { const r = N.rocks_01.clone(); r.scale.setScalar(0.28); r.position.set(Math.cos(i * 1.05) * 0.75, 0, Math.sin(i * 1.05) * 0.75); g.add(r); }
  for (let i = 0; i < 3; i++) { const b = buche(0.09, 0.9); b.rotation.set(0, i * 2.1, 0.3); b.position.y = 0.15; g.add(b); }
  feuLum = new THREE.PointLight('#ff9a4a', 6, 11, 1.8); feuLum.position.set(FEU.x, 1.2, FEU.z); G.scene.add(feuLum);
}
function majFeu(dt) {
  if (Math.random() < dt * 40) emettre(V(FEU.x + (Math.random() - 0.5) * 0.4, 0.35, FEU.z + (Math.random() - 0.5) * 0.4), { n: 1, c1: '#ffd27a', c2: '#ff3a0a', vit: 0.6, vie: 0.9, taille: 0.35, grav: -2.5, haut: 1.5 });
  if (feuLum) feuLum.intensity = 5 + Math.sin(G.t * 13) * 0.8 + Math.sin(G.t * 7.3) * 0.6;
}
// ---------------- Décor ----------------
function construireDecor() {
  const T = (cle, n, dmin, dmax, emin, emax, eviteCamp = 11) => { const L = []; for (let k = 0; k < n; k++) { const a = rnd(0, 6.283), d = rnd(dmin, dmax), x = Math.cos(a) * d, z = Math.sin(a) * d; if (Math.hypot(x, z) < eviteCamp || Math.hypot(x - RESERVE.x, z - RESERVE.z) < 5) continue; L.push({ p: V(x, hauteur(x, z), z), r: rnd(0, 6.28), e: rnd(emin, emax) }); } instancier(N[cle], L); };
  T('grass_01', 260, 6, 70, 0.7, 1.3, 6); T('flowers_01', 90, 8, 60, 0.7, 1.2, 8); T('fern_01', 70, 14, 65, 0.8, 1.3); T('bush_01', 45, 13, 66, 0.8, 1.3);
  T('mushrooms_01', 30, 16, 60, 0.8, 1.2); T('rocks_01', 25, 12, 66, 0.6, 1.2); T('boulder_01', 12, 20, 70, 0.8, 1.6, 18); T('rock_mossy_01', 14, 18, 70, 0.7, 1.3); T('pebbles_01', 30, 4, 50, 0.7, 1.1, 3);
  T('deadtree_01', 6, 30, 70, 0.9, 1.3, 25);
}
export function construireMonde() {
  G.hauteur = hauteur;
  G.obstacle = (x, z) => { for (const a of arbres) if (a.etat === 'debout' && Math.abs(a.pos.x - x) < 2 && Math.abs(a.pos.z - z) < 2 && Math.hypot(a.pos.x - x, a.pos.z - z) < 1.6 * a.e) return true; return false; };
  construireTerrain(); construireForet(); construireDecor(); construireReserve(); construireFeu();
}
export function majMonde(dt) { majChutes(dt); majRepousse(dt); majSecousses(dt); majFeu(dt); }
export function libre(x, z) { for (const a of arbres) if (a.etat !== 'tombe' && Math.hypot(a.pos.x - x, a.pos.z - z) < 0.7) return false; return Math.hypot(x, z) < 80; }
