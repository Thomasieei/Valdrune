// Le monde : clairière du camp, forêt (arbres qu'on abat vraiment), réserve de bois, feu de camp, dépouilles.
import { THREE, G, V, tmp, emettre, son, projeter } from './moteur.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
// fusionne des objets fixes de même matière en un seul (des dizaines d'appels de dessin → un seul)
function fusionner(objets, ombre = true) {
  const parMat = new Map(); for (const o of objets) { o.updateMatrixWorld(true); o.traverse(m => { if (!m.isMesh) return; const g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone(); g.applyMatrix4(m.matrixWorld); for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal') g.deleteAttribute(k); if (!parMat.has(m.material)) parMat.set(m.material, []); parMat.get(m.material).push(g); }); }
  for (const [mat, L] of parMat) { const m = new THREE.Mesh(mergeGeometries(L), mat); m.castShadow = ombre; m.receiveShadow = true; G.scene.add(m); L.forEach(g => g.dispose()); }
}

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
export const CAMP = V(0, 0, 0), RESERVE = V(5, 0, 4), FEU = V(-1.5, 0, -1.5), CARRIERE = V(21, 0, -19);
// ---------------- Chemins : de vraies routes de terre qui relient le camp aux zones (on s'y bat, on s'y repère) ----------------
const lisse = (pts) => { const out = []; for (let i = 0; i < pts.length - 1; i++) { const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)]; for (let t = 0; t < 1; t += 0.125) { const t2 = t * t, t3 = t2 * t; out.push([0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3), 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)]); } } out.push(pts[pts.length - 1]); return out; };
export const CHEMINS = [
  lisse([[2, -3], [8, -9], [12, -15], [17, -17]]),             // camp → carrière
  lisse([[3, 6], [10, 13], [20, 18], [28, 22], [33, 26]]),     // camp → camp des pillards
  lisse([[-4, 3], [-12, 10], [-20, 16], [-26, 24], [-30, 27]]), // camp → clairière des Puglins
  lisse([[-3, -4], [-8, -14], [-12, -26], [-14, -40], [-12, -55], [-6, -80], [6, -110], [22, -140], [30, -172]]), // nord : fort de la Horde puis les Hauteurs
  lisse([[33, 26], [48, 20], [70, 8], [88, 2], [110, -6], [140, -8], [175, -30], [205, -45]]), // est : la Grande Plaine, le long du lac d'Argent
  lisse([[-30, 27], [-48, 22], [-72, 12], [-100, 2], [-128, -8], [-150, -18]]), // ouest : la Forêt profonde jusqu'au repaire gobelin
  lisse([[-72, 12], [-86, 40], [-98, 66], [-104, 80]]),       // embranchement : l'étang des Brumes
  lisse([[4, 8], [6, 30], [12, 60], [24, 95], [36, 130], [42, 160]]), // sud : les collines et la tour des pillards
  lisse([[70, 8], [72, -40], [70, -88], [62, -112]]),          // raccourci plaine → lac du Col
];
export function distChemin(x, z) { let best = 1e9; for (const L of CHEMINS) for (let i = 0; i < L.length - 1; i++) { const [ax, az] = L[i], [bx, bz] = L[i + 1], dx = bx - ax, dz = bz - az, l2 = dx * dx + dz * dz, t = Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / l2)), d = Math.hypot(x - ax - dx * t, z - az - dz * t); if (d < best) best = d; } return best; }
function bruit(x, z) { return Math.sin(x * 0.071) * Math.cos(z * 0.063) * 0.9 + Math.sin(x * 0.17 + z * 0.13) * 0.35 + Math.cos(x * 0.031 - z * 0.047) * 1.4; }
// ---------------- Le monde : 500 m × 500 m, des régions qui se lisent au premier coup d'œil ----------------
// est : Grande Plaine et lac d'Argent · ouest : Forêt profonde et étang des Brumes · nord : les Hauteurs (rocailles, pins)
// sud : collines · tout autour : une muraille de montagnes. Le camp reste au centre, sur un replat.
export const MONDE = 236;
export const LACS = [{ x: 118, z: 34, r: 34, nom: 'Lac d’Argent' }, { x: -110, z: 94, r: 22, nom: 'Étang des Brumes' }, { x: 74, z: -132, r: 17, nom: 'Lac du Col' }];
export const NIVEAU_EAU = -0.7;
const lisser = (a, b, v) => { const t = Math.min(1, Math.max(0, (v - a) / (b - a))); return t * t * (3 - 2 * t); };
export const foret = (x, z) => Math.max(lisser(-40, -85, x) * (1 - lisser(130, 175, z)), lisser(0.55, 0.8, Math.sin(x * 0.021 + 1.3) * Math.cos(z * 0.019 - 0.7)) * 0.8); // + bosquets épars
export const hautes = (x, z) => lisser(-85, -140, z);
const bord = (x, z) => lisser(205, 240, Math.max(Math.abs(x), Math.abs(z)) + Math.sin(x * 0.05) * 6 + Math.cos(z * 0.045) * 6);
export function hauteur(x, z) {
  const d = Math.hypot(x, z), k = lisser(13, 27, d), H = hautes(x, z), B = bord(x, z);
  let h = bruit(x, z) * k + lisser(40, 90, d) * Math.sin(x * 0.013 + 0.5) * Math.cos(z * 0.011) * 4 // grandes ondulations au large
    + H * (5 + Math.abs(Math.sin(x * 0.045) * Math.cos(z * 0.05)) * 9 + bruit(x * 2.1, z * 2.1) * 1.5) // les Hauteurs : crêtes et rocailles
    + lisser(120, 200, z) * (3 + bruit(x * 0.8, z * 0.8) * 2) // les collines du sud
    + B * B * (34 + bruit(x * 1.3, z * 1.3) * 8); // la muraille de montagnes
  for (const L of LACS) { const dl = Math.hypot(x - L.x, z - L.z) / L.r; if (dl < 1.35) h = h + (-3.2 - h) * lisser(1.35, 0.8, dl); }
  return h;
}
export const eau = (x, z) => { for (const L of LACS) if (Math.hypot(x - L.x, z - L.z) < L.r * 0.93) return true; return false; };
function couleurSol(x, z, y, c, c2) {
  const n = Math.sin(x * 0.9) * Math.cos(z * 0.8) * 0.5 + Math.sin(x * 0.23 + z * 0.31) * 0.5, d = Math.hypot(x, z), F = foret(x, z), H = hautes(x, z), B = bord(x, z);
  c.set('#5f9a3a').lerp(c2.set('#7fb04a'), 0.5 + n * 0.5).offsetHSL(0, 0, y * 0.006);
  c.lerp(c2.set('#3f6a2c'), F * 0.75); // sous-bois sombre
  c.lerp(c2.set('#7a7f62'), H * (0.45 + n * 0.2)); // rocaille des Hauteurs
  c.lerp(c2.set('#7c7a74'), Math.min(1, B * 1.4)); if (y > 26) c.lerp(c2.set('#eef2f6'), lisser(26, 34, y + n * 3)); // roche, puis neige
  for (const L of LACS) { const dl = Math.hypot(x - L.x, z - L.z) / L.r; if (dl < 1.25) c.lerp(c2.set(dl < 0.95 ? '#5a6a50' : '#c8b88a'), lisser(1.25, 1.02, dl) * 0.9); } // plage de sable puis vase
  const terre = Math.max(0, 1 - d / 9) * 0.9 + Math.max(0, 1 - Math.hypot(x - RESERVE.x, z - RESERVE.z) / 5) * 0.7; c.lerp(c2.set('#9a7a52'), Math.min(0.85, terre)); // sol tassé du camp
  const dc = Math.hypot(x - CARRIERE.x, z - CARRIERE.z); if (dc < 10) c.lerp(c2.set('#8a8070'), Math.min(0.8, (10 - dc) / 3.5)); // carrière : roche et gravier
  const da = Math.hypot(x + 24, z + 6); if (da < 12.5) c.lerp(c2.set('#c8b088'), Math.min(0.9, (12.5 - da) / 1.5)); // sable de l'arène
  const dch = distChemin(x, z) + Math.sin(x * 1.7 + z * 1.3) * 0.35; if (dch < 2.6) c.lerp(c2.set('#a08458').offsetHSL(0, 0, n * 0.03), Math.min(0.92, (2.6 - dch) / 1.1)); // route de terre aux bords irréguliers
}
function construireTerrain() {
  // 6 × 6 morceaux de ~83 m : la caméra ne dessine que ceux qu'elle voit
  const N = 6, T = 500, Tc = T / N, seg = 34, c = new THREE.Color(), c2 = new THREE.Color(), mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 });
  for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) {
    const ox = -T / 2 + Tc * (i + 0.5), oz = -T / 2 + Tc * (j + 0.5), geo = new THREE.PlaneGeometry(Tc, Tc, seg, seg).rotateX(-Math.PI / 2), P = geo.attributes.position, C = new Float32Array(P.count * 3);
    for (let v = 0; v < P.count; v++) { const x = P.getX(v) + ox, z = P.getZ(v) + oz, y = hauteur(x, z); P.setXYZ(v, x, y, z); couleurSol(x, z, y, c, c2); C.set([c.r, c.g, c.b], v * 3); }
    geo.setAttribute('color', new THREE.BufferAttribute(C, 3)); geo.computeVertexNormals(); geo.computeBoundingSphere();
    const sol = new THREE.Mesh(geo, mat); sol.receiveShadow = true; G.scene.add(sol);
  }
  // les lacs : une surface d'eau qui reflète le ciel
  const matEau = new THREE.MeshStandardMaterial({ color: '#3d7fb0', roughness: 0.08, metalness: 0.35, transparent: true, opacity: 0.86, envMapIntensity: 1.4 });
  for (const L of LACS) { const m = new THREE.Mesh(new THREE.CircleGeometry(L.r * 1.18, 56).rotateX(-Math.PI / 2), matEau); m.position.set(L.x, NIVEAU_EAU, L.z); m.receiveShadow = true; G.scene.add(m); L.eau = m; }
}
// ---------------- Décor en instances (un seul appel de dessin par type) ----------------
// décor en instances, découpé en secteurs de 32 m : la caméra ne dessine que les secteurs visibles (au lieu de toute la forêt)
const SECTEUR = 64, secteursVus = [], macrosVus = [], _zero = new THREE.Matrix4().makeScale(0, 0, 0), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _m4 = new THREE.Matrix4(), _m5 = new THREE.Matrix4(), _y = new THREE.Vector3(0, 1, 0);
// arbre lointain : quelques dizaines de triangles au lieu de 3 000 (silhouette et couleur suffisent à 60 m+)
const MAT_LOD = new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
function arbreSimple(modele, type) { // tronc + houppier fusionnés, couleurs dans les sommets : 1 seul appel de dessin par type et par secteur
  const b = new THREE.Box3().setFromObject(modele), H = b.max.y - b.min.y, W = Math.max(b.max.x - b.min.x, b.max.z - b.min.z);
  const peint = (g, col) => { if (g.index) g = g.toNonIndexed(); const c = new THREE.Color(col), n = g.attributes.position.count, C = new Float32Array(n * 3); for (let i = 0; i < n; i++) C.set([c.r, c.g, c.b], i * 3); g.setAttribute('color', new THREE.BufferAttribute(C, 3)); g.deleteAttribute('uv'); return g; };
  const t = peint(new THREE.CylinderGeometry(W * 0.05, W * 0.08, H * 0.45, 5).translate(0, H * 0.225, 0), '#5e4430');
  const col = { pine_01: '#2e5a36', birch_01: '#8cba58', oak_01: '#4c8a36' }[type] || '#4c8a36';
  const c = peint(type === 'pine_01' ? new THREE.ConeGeometry(W * 0.48, H * 0.85, 7).translate(0, H * 0.57, 0) : new THREE.IcosahedronGeometry(W * 0.46, 0).scale(1, (H * 0.55) / W * 1.1, 1).translate(0, H * 0.66, 0), col);
  return new THREE.Mesh(mergeGeometries([t, c]), MAT_LOD);
}
function instancier(modele, transforms, { ombre = true, loin = 260, lod = null, pres = 30 } = {}) {
  const meshes = []; modele.updateMatrixWorld(true); modele.traverse(o => { if (o.isMesh) meshes.push(o); });

  const groupe = new THREE.Group(), secteurs = new Map(), place = [];
  transforms.forEach((t, i) => { const k = Math.floor(t.p.x / SECTEUR) + ',' + Math.floor(t.p.z / SECTEUR); if (!secteurs.has(k)) secteurs.set(k, []); const L = secteurs.get(k); place[i] = { k, li: L.length }; L.push(t); });
  const parSecteur = new Map();
  const mk = (m, n, parent, omb) => { const im = new THREE.InstancedMesh(m.geometry, m.material, n); im.castShadow = omb; im.receiveShadow = true; im.userData.local = m.matrixWorld.clone(); parent.add(im); return im; };
  for (const [k, L] of secteurs) {
    const sg = new THREE.Group(), [a, b] = k.split(',').map(Number); sg.visible = false; groupe.add(sg);
    if (lod) { sg.userData.c = [(a + 0.5) * SECTEUR, (b + 0.5) * SECTEUR, pres]; sg.userData.lod = { L, macro: null }; parSecteur.set(k, meshes.map(m => mk(m, L.length, sg, ombre && m.castShadow))); }
    else { sg.userData.c = [(a + 0.5) * SECTEUR, (b + 0.5) * SECTEUR, loin]; parSecteur.set(k, meshes.map(m => mk(m, L.length, sg, ombre && m.castShadow))); }
    secteursVus.push(sg);
  }
  const poser = (im, li, t) => { _q.setFromAxisAngle(_y, t.r); _s.setScalar(t.e); _m4.compose(t.p, _q, _s); im.setMatrixAt(li, _m5.multiplyMatrices(_m4, im.userData.local)); };
  for (const [k, L] of secteurs) { const ims = parSecteur.get(k); L.forEach((t, li) => { for (const im of ims) poser(im, li, t); }); for (const im of ims) { im.instanceMatrix.needsUpdate = true; im.computeBoundingSphere(); } }
  G.scene.add(groupe);
  // arbres lointains : un seul maillage simplifié par grand secteur de 144 m ; un arbre dessiné en détail y est escamoté
  if (lod) {
    const macros = new Map(); for (const [k, L] of secteurs) { const [a, b] = k.split(',').map(Number), mk2 = Math.floor(a / 3) + ',' + Math.floor(b / 3); if (!macros.has(mk2)) macros.set(mk2, []); macros.get(mk2).push(k); }
    for (const [mk2, ks] of macros) { let n = 0; for (const k of ks) n += secteurs.get(k).length; const im = new THREE.InstancedMesh(lod.geometry, lod.material, n), [a, b] = mk2.split(',').map(Number); im.userData.local = new THREE.Matrix4(); im.userData.c = [(a + 0.5) * SECTEUR * 3, (b + 0.5) * SECTEUR * 3, loin + 40]; let j = 0;
      for (const k of ks) { const sg = groupe.children.find(g => g.userData.lod && g.userData.lod.L === secteurs.get(k)); sg.userData.lod.macro = im; sg.userData.lod.j0 = j; for (const t of secteurs.get(k)) poser(im, j++, t); }
      im.instanceMatrix.needsUpdate = true; im.computeBoundingSphere(); groupe.add(im); macrosVus.push(im); }
  }
  return { transforms, maj(i, t) { const P = place[i], ims = parSecteur.get(P.k); Object.assign(transforms[i], t); for (const im of ims) { poser(im, P.li, t); im.instanceMatrix.needsUpdate = true; } const sg = parSecteur.get(P.k)[0].parent, D = sg.userData.lod; if (D && !sg.visible) { _q.setFromAxisAngle(_y, t.r); _s.setScalar(t.e); D.macro.setMatrixAt(D.j0 + P.li, _m4.compose(t.p, _q, _s)); D.macro.instanceMatrix.needsUpdate = true; } } };
}
let graine = 7; const rnd = (a = 0, b = 1) => { graine = (graine * 16807) % 2147483647; return a + (graine / 2147483647) * (b - a); };
// ---------------- Arbres ----------------
export const arbres = []; const parType = {};
// endroits à garder dégagés : camps, arène, carrière, réserve, fort, repaire, tour
export const CLAIRIERES = [[RESERVE.x, RESERVE.z, 9], [CARRIERE.x, CARRIERE.z, 11], [-34, 30, 11], [38, 30, 14], [-24, -6, 15], [-12, -46, 20], [-150, -18, 16], [42, 160, 14], [0, 0, 15]];
const degage = (x, z, marge = 0) => { for (const [cx, cz, r] of CLAIRIERES) if (Math.hypot(x - cx, z - cz) < r + marge) return true; for (const L of LACS) if (Math.hypot(x - L.x, z - L.z) < L.r * 1.12 + marge) return true; return false; };
function construireForet() {
  // grille brouillée : une forêt dense mais aérée (on y voit loin, on y circule), des bosquets dans la plaine
  const T = { oak_01: [], birch_01: [], pine_01: [] }, pas = 6.5;
  for (let gx = -MONDE; gx < MONDE; gx += pas) for (let gz = -MONDE; gz < MONDE; gz += pas) {
    const x = gx + rnd(-2, 2), z = gz + rnd(-2, 2), F = foret(x, z), H = hautes(x, z), B = bord(x, z);
    const clair = lisser(0.5, 0.75, Math.sin(x * 0.07) * Math.cos(z * 0.06)); // petites clairières dans les bois
    const p0 = (F * 0.72 * (1 - clair * 0.8) + H * 0.22 + 0.025 + lisser(120, 200, z) * 0.06) * (1 - B * 0.8) * lisser(15, 30, Math.hypot(x, z));
    if (rnd() > p0 || distChemin(x, z) < 3.6 || degage(x, z)) continue;
    const r0 = rnd(), type = H > 0.5 || B > 0.3 ? 'pine_01' : F > 0.5 ? (r0 < 0.45 ? 'pine_01' : r0 < 0.8 ? 'oak_01' : 'birch_01') : r0 < 0.6 ? 'oak_01' : 'birch_01';
    const e = rnd(1.5, 2.4) * (F > 0.5 ? 1.1 : 1), p = V(x, hauteur(x, z), z); /* des arbres qui nous dépassent : le monde est grand */
    const ar = { type, i: T[type].length, pos: p, r: rnd(0, 6.28), e, pv: 0, pvMax: 0, etat: 'debout', bois: 0, ouvriers: 0 };
    ar.pvMax = ar.pv = Math.round(7 * e); T[type].push({ p, r: ar.r, e }); arbres.push(ar);
  }
  for (const t of Object.keys(T)) parType[t] = instancier(N[t], T[t], { lod: arbreSimple(N[t], t) });
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
  ar.etat = 'tombe'; ar.secoue = 0; parType[ar.type].maj(ar.i, { p: ar.pos, r: ar.r, e: 0.0001 });
  const g = N[ar.type].clone(); g.scale.setScalar(ar.e); g.rotation.y = ar.r; const piv = new THREE.Group(); piv.position.copy(ar.pos); piv.add(g); G.scene.add(piv);
  const dir = Math.atan2(ar.pos.x - depuis.x, ar.pos.z - depuis.z); piv.rotation.y = dir; g.rotation.y = ar.r - dir;
  chutes.push({ ar, piv, t: 0 });
  son('impactSoft_heavy_000', 0.35, 0.7, ar.pos);
}
function majChutes(dt) {
  for (let i = chutes.length - 1; i >= 0; i--) {
    const c = chutes[i]; c.t += dt; const k = Math.min(1, c.t / 1.3); c.piv.rotation.x = (k * k) * Math.PI / 2 * 0.98;
    if (k >= 1 && !c.fini) { c.fini = true; G.shake = Math.max(G.shake, 0.25); son('impactSoft_heavy_000', 0.6, 0.5, c.ar.pos); emettre(tmp(c.piv.position.x + Math.sin(c.piv.rotation.y) * 3, c.ar.pos.y + 0.3, c.piv.position.z + Math.cos(c.piv.rotation.y) * 3), { n: 30, c1: '#cfe08a', c2: '#4a6a2a', vit: 4, vie: 0.8, taille: 0.18, grav: 5 }); }
    if (c.t > 1.9) {
      G.scene.remove(c.piv); chutes.splice(i, 1);
      const ar = c.ar; ar.etat = 'abattu'; ar.bois = Math.round(14 * ar.e);
      // le tronc reste au sol : les ouvriers le débitent ; la souche reste
      const tronc = buche(0.3 * ar.e, 3.6 * ar.e); tronc.rotation.y = c.piv.rotation.y + Math.PI / 2; tronc.position.copy(ar.pos).add(V(Math.sin(c.piv.rotation.y) * 2.1 * ar.e, 0.3 * ar.e, Math.cos(c.piv.rotation.y) * 2.1 * ar.e)); G.scene.add(tronc); ar.tronc = tronc; ar.posTronc = ar.pos.clone().add(V(Math.sin(c.piv.rotation.y) * 2.1 * ar.e, 0, Math.cos(c.piv.rotation.y) * 2.1 * ar.e));
      const s = N.stump_01.clone(); s.scale.setScalar(ar.e); s.position.copy(ar.pos); s.rotation.y = ar.r; G.scene.add(s); ar.souche = s;
    }
  }
}
// débiter le tronc : chaque coup donne du bois au porteur
export function debiter(ar, n) {
  if (ar.etat !== 'abattu' || ar.bois <= 0) return 0;
  const pris = Math.min(n, ar.bois); ar.bois -= pris;
  if (ar.tronc) { const k = 0.35 + 0.65 * ar.bois / Math.round(14 * ar.e); ar.tronc.scale.set(k, 1, 1); }
  emettre(tmp(ar.posTronc.x, ar.pos.y + 0.4, ar.posTronc.z), { n: 5, c1: '#e8c48a', c2: '#7a5530', vit: 2.5, vie: 0.5, taille: 0.12, grav: 9 });
  son('chop', 0.4, 1.1, ar.posTronc);
  if (ar.bois <= 0) { G.scene.remove(ar.tronc); ar.tronc = null; ar.etat = 'souche'; ar.repousse = 0; }
  return pris;
}
// les souches repoussent : jeune pousse, puis arbre adulte
function majRepousse(dt) {
  for (const ar of arbres) {
    if (ar.etat !== 'souche') continue;
    ar.repousse += dt * (G.repousseBois || 1);
    if (ar.repousse > 90) { const k = Math.min(1, (ar.repousse - 90) / 60); parType[ar.type].maj(ar.i, { p: ar.pos, r: ar.r, e: ar.e * (0.15 + 0.85 * k) }); if (ar.souche && k > 0.2) { G.scene.remove(ar.souche); ar.souche = null; } if (k >= 1) { ar.etat = 'debout'; ar.pv = ar.pvMax; } }
  }
}
function majSecousses(dt) { for (const ar of arbres) if (ar.secoue > 0 && ar.etat === 'debout') { /* jamais sur un arbre déjà tombé : sinon il réapparaissait debout */ ar.secoue -= dt; const k = Math.max(0, ar.secoue) * 0.25; parType[ar.type].maj(ar.i, { p: V(ar.pos.x + Math.sin(G.t * 60) * k * 0.3, ar.pos.y, ar.pos.z), r: ar.r + Math.sin(G.t * 50) * k, e: ar.e }); } }
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
  if (Math.random() < dt * 40) emettre(tmp(FEU.x + (Math.random() - 0.5) * 0.4, 0.35, FEU.z + (Math.random() - 0.5) * 0.4), { n: 1, c1: '#ffd27a', c2: '#ff3a0a', vit: 0.6, vie: 0.9, taille: 0.35, grav: -2.5, haut: 1.5 });
  if (feuLum) feuLum.intensity = 5 + Math.sin(G.t * 13) * 0.8 + Math.sin(G.t * 7.3) * 0.6;
}
// ---------------- Décor ----------------
function construireDecor() {
  // chaque plante pousse là où elle a sa place ; les petites ne sont dessinées que de près (invisibles au loin de toute façon)
  const T = (cle, n, ou, emin, emax, loin = 260) => { const L = []; for (let k = 0; k < n; k++) { const x = rnd(-MONDE, MONDE), z = rnd(-MONDE, MONDE), d = Math.hypot(x, z); if (rnd() > ou(x, z, d) || degage(x, z, -4) || bord(x, z) > 0.6 || (d < 11 && cle !== 'grass_01') || (cle !== 'grass_01' && cle !== 'flowers_01' && distChemin(x, z) < 2.4)) continue; L.push({ p: V(x, hauteur(x, z), z), r: rnd(0, 6.28), e: rnd(emin, emax) }); } instancier(N[cle], L, { ombre: !/grass|flowers|pebbles|mushrooms|fern/.test(cle), loin }); };
  const plaine = (x, z) => (1 - foret(x, z)) * (1 - hautes(x, z));
  T('grass_01', 5200, (x, z, d) => d < 6 ? 0 : plaine(x, z) * 0.9 + 0.15, 0.7, 1.3, 50); T('flowers_01', 1800, (x, z) => plaine(x, z), 0.7, 1.2, 50);
  T('fern_01', 1400, (x, z) => foret(x, z) * 0.9 + 0.05, 0.8, 1.4, 55); T('bush_01', 900, (x, z) => 0.35 + foret(x, z) * 0.5, 0.8, 1.3, 90);
  T('mushrooms_01', 500, (x, z) => foret(x, z), 0.8, 1.2, 35); T('rocks_01', 500, (x, z) => 0.3 + hautes(x, z) * 0.7, 0.6, 1.2, 60); T('pebbles_01', 600, (x, z) => 0.3 + hautes(x, z) * 0.7, 0.7, 1.1, 35);
  T('boulder_01', 260, (x, z, d) => d < 18 ? 0 : 0.2 + hautes(x, z) * 0.8, 1.8, 3.8); T('rock_mossy_01', 260, (x, z, d) => d < 18 ? 0 : 0.15 + foret(x, z) * 0.85, 1.2, 2.4);
  T('deadtree_01', 90, (x, z, d) => d < 25 ? 0 : 0.08 + hautes(x, z) * 0.9, 1.5, 2.3);
  T('stump_01', 120, (x, z, d) => d < 15 ? 0 : foret(x, z), 0.9, 1.3, 60); T('log_01', 90, (x, z, d) => d < 15 ? 0 : foret(x, z) * 0.9, 0.9, 1.3, 70);
  construireMontagnes();
  construireBraseros();
}
// arène d'entraînement : cercle de menhirs, braseros, pierre du défi
export const PIERRE_DEFI = V(-24, 0, 4.5);
function construireArene() {
  const roc = new THREE.MeshStandardMaterial({ color: '#8a8478', roughness: 0.95, flatShading: true }), menhirs = [];
  for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283, x = -24 + Math.sin(a) * 13, z = -6 + Math.cos(a) * 13; if (Math.hypot(x + 24, z - 7) < 3) continue; const h = 2.2 + (i % 3) * 0.7, m = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.7, h, 6), roc); m.position.set(x, hauteur(x, z) + h / 2 - 0.1, z); m.rotation.set((i % 2) * 0.08, a, ((i * 7) % 3 - 1) * 0.06); menhirs.push(m); }
  fusionner(menhirs);
  const p = PIERRE_DEFI, pierre = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.8, 2.6, 5), new THREE.MeshStandardMaterial({ color: '#5a5664', roughness: 0.8, flatShading: true, emissive: '#3a1a8a', emissiveIntensity: 0.12 }));
  pierre.position.set(p.x, hauteur(p.x, p.z) + 1.25, p.z); pierre.castShadow = true; G.scene.add(pierre);
  const rune = new THREE.Mesh(new THREE.TorusGeometry(0.55, 0.05, 6, 20), new THREE.MeshBasicMaterial({ color: '#c8a8ff' })); rune.position.set(p.x, hauteur(p.x, p.z) + 1.7, p.z + 0.62); G.scene.add(rune);
}
// montagnes à l'horizon : des silhouettes immenses qui rappellent que le monde est vaste
function construireMontagnes() {
  const monts = [], mat = new THREE.MeshStandardMaterial({ color: '#8094a8', roughness: 1, flatShading: true, fog: false }), neige = new THREE.MeshStandardMaterial({ color: '#eef2f8', roughness: 1, flatShading: true, fog: false }); // au-delà du brouillard : silhouettes bleutées
  for (let i = 0; i < 34; i++) {
    const a = i / 34 * 6.283 + rnd(-0.08, 0.08), d = rnd(290, 340), h = rnd(70, 150), r = rnd(45, 80);
    const m = new THREE.Mesh(new THREE.ConeGeometry(r, h, 7, 3), mat); m.position.set(Math.cos(a) * d, h / 2 - 4, Math.sin(a) * d); m.rotation.y = rnd(0, 3); monts.push(m);
    if (h > 95) { const c = new THREE.Mesh(new THREE.ConeGeometry(r * 0.32, h * 0.32, 7, 1), neige); c.position.set(m.position.x, h - 4 - h * 0.16, m.position.z); c.rotation.y = m.rotation.y; monts.push(c); }
  }
  fusionner(monts, false);
}
// braseros le long des routes : on voit où aller, et les combats de nuit ont de la gueule
const braseros = [];
function construireBraseros() {
  const fer = new THREE.MeshStandardMaterial({ color: '#2a2622', metalness: 0.6, roughness: 0.5 }), braise = new THREE.MeshStandardMaterial({ color: '#ff7a2a', emissive: '#ff5a10', emissiveIntensity: 3 });
  for (const L of CHEMINS) for (let i = 4; i < L.length - 2; i += 6) {
    const [x, z] = L[i], [x2, z2] = L[i + 1], a = Math.atan2(x2 - x, z2 - z), cote = (i / 6) % 2 ? 1 : -1, px = x + Math.cos(a) * 2.9 * cote, pz = z - Math.sin(a) * 2.9 * cote;
    if (Math.hypot(px, pz) < 8) continue;
    const g = new THREE.Group(), pied = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.1, 1.3, 6), fer); pied.position.y = 0.65; const coupe = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.18, 0.28, 8, 1, true), fer); coupe.position.y = 1.38;
    const feu = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 0), braise); feu.position.y = 1.45; g.add(pied, coupe, feu); g.position.set(px, hauteur(px, pz), pz); braseros.push(g);
  }
  fusionner(braseros);
}
function majBraseros() { const c = G.camCible; for (const b of braseros) if (Math.hypot(b.position.x - c.x, b.position.z - c.z) < 30 && Math.random() < 0.35) emettre(tmp(b.position.x + (Math.random() - 0.5) * 0.2, b.position.y + 1.55, b.position.z + (Math.random() - 0.5) * 0.2), { n: 1, c1: '#ffd27a', c2: '#ff3a10', vit: 0.6, vie: 0.6, taille: 0.2, grav: -2.5 }); }
// ---------------- Carrière : filons de pierre ----------------
export const filons = [];
function construireCarriere() {
  const gris = new THREE.MeshStandardMaterial({ color: '#8a8a92', roughness: 0.9 });
  for (let k = 0; k < 7; k++) {
    const a = k / 7 * 6.283 + 0.3, d = k ? 4.5 + (k % 2) * 1.6 : 0, x = CARRIERE.x + Math.cos(a) * d, z = CARRIERE.z + Math.sin(a) * d;
    const g = N.boulder_01.clone(), e = rnd(1.5, 2.1); g.scale.setScalar(e); g.position.set(x, hauteur(x, z) - 0.1, z); g.rotation.y = rnd(0, 6.28);
    g.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color.multiplyScalar(0.95); } });
    // veines claires : on voit que c'est une ressource
    for (let i = 0; i < 4; i++) { const c = new THREE.Mesh(new THREE.IcosahedronGeometry(0.16, 0), new THREE.MeshStandardMaterial({ color: '#e6e2d6', emissive: '#3a3830', roughness: 0.4 })); c.position.set(rnd(-0.35, 0.35), rnd(0.25, 0.6), rnd(-0.35, 0.35)); g.add(c); }
    G.scene.add(g); filons.push({ g, pos: g.position, e, pierre: 40, max: 40, ouvriers: 0, repousse: 0 });
  }
  /* le sol de la carrière est peint dans le terrain lui-même (un disque posé dessus flottait et rendait le héros translucide) */
}
export function tailler(f, n, pos) {
  if (f.pierre <= 0) return 0; const pris = Math.min(n, f.pierre); f.pierre -= pris;
  emettre(tmp(f.pos.x, f.pos.y + 0.9, f.pos.z), { n: 8, c1: '#f0ece0', c2: '#6a6a70', vit: 3, vie: 0.5, taille: 0.12, grav: 9 }); son('impactMetal_light_000', 0.35, 0.7 + Math.random() * 0.2, f.pos);
  const k = 0.35 + 0.65 * f.pierre / f.max; f.g.scale.setScalar(f.e * k); if (f.pierre <= 0) { f.g.scale.setScalar(f.e * 0.22); f.repousse = 0; emettre(tmp(f.pos.x, f.pos.y + 0.5, f.pos.z), { n: 30, c1: '#d8d4c8', c2: '#5a5a60', vit: 4, vie: 0.8, taille: 0.25, grav: 8 }); } /* il reste des gravats, le filon se reforme peu à peu */
  return pris;
}
export const REPOUSSE = { bois: 150, pierre: 120 };
function majFilons(dt) { for (const f of filons) if (f.pierre <= 0) { f.repousse += dt * (G.repoussePierre || 1); const k = Math.min(1, f.repousse / REPOUSSE.pierre); f.g.scale.setScalar(f.e * (0.22 + 0.78 * k * k)); if (k >= 1) { f.pierre = f.max; emettre(tmp(f.pos.x, f.pos.y + 1, f.pos.z), { n: 20, c1: '#fff6d8', c2: '#9a9aa2', vit: 2, vie: 0.7, taille: 0.2, grav: -1 }); } } }
// minuteurs de repousse visibles près de la caméra : le joueur sait quand la ressource revient
const minut = [];
function majMinuteurs() {
  const hote = document.getElementById('bulles'); if (!hote) return; let k = 0; const c = G.camCible, fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
  const ajoute = (p, txt) => { if (k >= 14) return; const s = projeter(tmp(p.x, p.y + 1.6, p.z)); if (!s.devant) return; let e = minut[k]; if (!e) { e = document.createElement('div'); e.className = 'eti repousse'; hote.appendChild(e); minut[k] = e; } if (e._t !== txt) { e.textContent = txt; e._t = txt; } e.style.display = ''; e.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-100%)`; k++; };
  for (const a of arbres) if (a.etat === 'souche' && Math.hypot(a.pos.x - c.x, a.pos.z - c.z) < 22) ajoute(a.pos, '🌱 ' + fmt(Math.max(0, (REPOUSSE.bois - a.repousse) / (G.repousseBois || 1))));
  for (const f of filons) if (f.pierre <= 0 && Math.hypot(f.pos.x - c.x, f.pos.z - c.z) < 22) ajoute(f.pos, '⛏️ ' + fmt(Math.max(0, (REPOUSSE.pierre - f.repousse) / (G.repoussePierre || 1))));
  for (let i = k; i < minut.length; i++) minut[i].style.display = 'none';
}
let minT = 0;
export function filonProche(p, max = 999) { let b = null, bd = max; for (const f of filons) { if (f.pierre <= 0 || f.ouvriers >= 2 || (G.danger && G.danger(f.pos))) continue; const d = Math.hypot(f.pos.x - p.x, f.pos.z - p.z); if (d < bd) { bd = d; b = f; } } return b; }
export function construireMonde() {
  G.hauteur = hauteur;
  G.obstacle = (x, z) => { for (const a of arbres) if (a.etat === 'debout' && Math.abs(a.pos.x - x) < 2 && Math.abs(a.pos.z - z) < 2 && Math.hypot(a.pos.x - x, a.pos.z - z) < 0.3 + 0.28 * a.e) return true; return false; }; // seuls les troncs repoussent la caméra (le feuillage, on voit à travers)
  construireTerrain(); construireArene(); construireForet(); construireDecor(); construireReserve(); construireFeu(); construireCarriere();
}
export function majMonde(dt) { majSecteurs(dt); majMinuteurs(); majBraseros(); majFilons(dt); majChutes(dt); majRepousse(dt); majSecousses(dt); majFeu(dt); }
export function libre(x, z) { if (Math.abs(x) > MONDE || Math.abs(z) > MONDE || eau(x, z)) return false; for (const a of arbres) if (a.etat !== 'tombe' && Math.abs(a.pos.x - x) < 1.2 && Math.abs(a.pos.z - z) < 1.2 && Math.hypot(a.pos.x - x, a.pos.z - z) < 0.42 * a.e) return false; return true; }
// ne dessine les secteurs de décor qu'à portée (herbe : 70 m, arbres : jusqu'au brouillard)
let visT = 0; function majSecteurs(dt) { if ((visT -= dt) > 0) return; visT = 0.4; const c = G.camera.position; for (const g of secteursVus) { const [x, z, l] = g.userData.c, v = Math.hypot(x - c.x, z - c.z) < l + 34; if (v === g.visible) continue; g.visible = v; const D = g.userData.lod; if (D) { let j = D.j0; for (const t of D.L) { if (v) D.macro.setMatrixAt(j++, _zero); else { _q.setFromAxisAngle(_y, t.r); _s.setScalar(t.e); D.macro.setMatrixAt(j++, _m4.compose(t.p, _q, _s)); } } D.macro.instanceMatrix.needsUpdate = true; } }
  for (const m of macrosVus) { const [x, z, l] = m.userData.c; m.visible = Math.hypot(x - c.x, z - c.z) < l + 100; } }
