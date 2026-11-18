// Les humains : deux villages et une ville, qui vivent sans toi (travail, discussions, allées et venues).
// De temps en temps, l'un d'eux vient jusqu'à ton camp ; et quand un village est attaqué, un messager court te chercher.
import { THREE, G, V, tmp, texteFlottant, son, emettre } from './moteur.js';
import { Perso } from './persos.js';
import { hauteur, VILLAGES, LACS, NIVEAU_EAU } from './monde.js';
import { plan3D, modele, piece, maison } from './batiments.js';
import { lancerInvasion, finirInvasion, epee } from './combat.js';
import { construireCapitale, peuplerCapitale } from './capitale.js';
import { prop } from './persos.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

let C = null; // { J, joueur, toast, sauver, majHud, ajouter }
const rnd = (a, b) => a + Math.random() * (b - a), pick = (L) => L[Math.floor(Math.random() * L.length)];
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const TENUES = ['#c8a070', '#8aa0c0', '#b07a6a', '#9ab07a', '#c8b890', '#a08ab8', '#d0c0a0', '#7a9a9a'];
export const habitants = [];
export const blocs = []; // maisons : on ne traverse pas les murs
export const bloqueHumain = (x, z) => { for (const b of blocs) if (Math.abs(b.x - x) < b.r && Math.abs(b.z - z) < b.r && Math.hypot(b.x - x, b.z - z) < b.r) return true; return false; };

// ---------------- Construction : toutes les maisons d'un village fusionnées par matière (une dizaine d'appels de dessin) ----------------
const _c = new THREE.Vector3();
export function fusionner(groupe, parent) {
  groupe.updateMatrixWorld(true); const parMat = new Map(), seuls = [];
  groupe.traverse(o => { if (!o.isMesh) return; if (Array.isArray(o.material)) { seuls.push(o); return; } const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone(); g.applyMatrix4(o.matrixWorld); for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k); if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2)); if (!parMat.has(o.material)) parMat.set(o.material, []); parMat.get(o.material).push(g); });
  for (const [mat, L] of parMat) { // découpé en carrés de 20 m : la caméra et les ombres ne traitent que les morceaux proches
    const cases = new Map(); for (const g of L) { g.computeBoundingBox(); const c = g.boundingBox.getCenter(_c), k = Math.floor(c.x / 20) + ',' + Math.floor(c.z / 20); if (!cases.has(k)) cases.set(k, []); cases.get(k).push(g); }
    for (const G2 of cases.values()) { const m = new THREE.Mesh(mergeGeometries(G2), mat); m.castShadow = m.receiveShadow = true; parent.add(m); } L.forEach(g => g.dispose()); }
  for (const o of seuls) { const c = o.clone(); o.matrixWorld.decompose(c.position, c.quaternion, c.scale); parent.add(c); }
}
// ---- un champ : terre labourée en sillons et rangs de blé ou de choux (2 appels de dessin) ----
const MAT_TERRE = new THREE.MeshStandardMaterial({ color: '#6e5236', roughness: 1 }), MAT_BLE = new THREE.MeshStandardMaterial({ color: '#d8b850', roughness: 0.9, flatShading: true }), MAT_CHOU = new THREE.MeshStandardMaterial({ color: '#6aa040', roughness: 0.9, flatShading: true });
export function champ(x, z, r, L, W, ble) {
  const g = new THREE.Group(), sol = [], pl = [];
  for (let i = 0; i < Math.floor(W / 1.1); i++) { const ox = -W / 2 + 0.55 + i * 1.1; const s = new THREE.BoxGeometry(0.6, 0.18, L).translate(ox, 0.05, 0); sol.push(s);
    for (let k = 0; k < L / 0.7; k++) { const oz = -L / 2 + 0.35 + k * 0.7, h = ble ? rnd(0.6, 0.9) : 0.3; const p = ble ? new THREE.ConeGeometry(0.16, h, 4).translate(ox, 0.15 + h / 2, oz) : new THREE.IcosahedronGeometry(0.24, 0).translate(ox, 0.25, oz); pl.push(p); } }
  const m1 = new THREE.Mesh(mergeGeometries(sol), MAT_TERRE), m2 = new THREE.Mesh(mergeGeometries(pl), ble ? MAT_BLE : MAT_CHOU); m1.receiveShadow = true; m2.castShadow = true; g.add(m1, m2);
  g.position.set(x, hauteur(x, z) - 0.02, z); g.rotation.y = r; return g;
}
// ---- un village organique : une rue qui serpente, des maisons de part et d'autre (portes sur la rue),
// jardins clôturés, champs derrière, puits sur la place, étal, lanternes, tas de bois, tonneaux ----
// ---- objets du kit « Modular Village » et de la ferme (convertis en glb) ----
const VP = {}; const VP_NOMS = ['Prop_Boat_1', 'Prop_Boat_2', 'Prop_Boat_Oars_1', 'Prop_Cart_1_Hay', 'Prop_Cart_1_Barrels', 'Prop_Hay_1', 'Prop_Lamp_Street', 'Wall_Prop_Windmill_1', 'Wood_Floor_Straight_1', 'Wood_Post_Large', 'Wood_Railing_Straight', 'Prop_Barrel_1', 'Prop_Crate_1', 'Prop_Ladder_1', 'Wall_Prop_Lamp', 'Wall_Prop_Bell_1', 'Canopy_Full', 'Wall_Prop_Sign_1', 'Roof_Prop_Chimney_Stone', 'Fence_01', 'Cabbage_01', 'TomatoPlant_01', 'Box_01'];
export async function chargerVillage() { const { GLTFLoader } = await import('three/addons/loaders/GLTFLoader.js'), L = new GLTFLoader(); await Promise.all(VP_NOMS.map(n => L.loadAsync('assets/village/' + n + '.glb').then(g => { g.scene.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); VP[n] = g.scene; }).catch(() => {}))); }
const vp = (n) => VP[n] ? VP[n].clone() : new THREE.Group();
// ---- un vrai village : une grand-rue qui serpente + une ruelle, 9 à 11 maisons de tailles variées alignées sur les rues,
// potagers clôturés (choux, tomates), charrettes de foin, meules, lanternes de rue, cloche et panneau sur la place,
// fumée aux cheminées ; et un lieu qui donne son caractère : le moulin des Saules, le ponton de pêche de Port-au-Lac ----
function construire(Vg) {
  if (Vg.type === 'ville') return construireCapitale(Vg);
  const brut = new THREE.Group(), autres = new THREE.Group(), cx = Vg.x, cz = Vg.z, spots = [], portes = [], e = Vg.entree, K = 1.8;
  const pose = (o, x, z, r = 0, k = 1, dy = 0) => { o.position.set(x, hauteur(x, z) + dy, z); o.rotation.y = r; o.scale.multiplyScalar(k); brut.add(o); return o; };
  const surRue = (t) => [cx + Math.sin(e) * t + Math.cos(e) * Math.sin(t * 0.11) * 3, cz + Math.cos(e) * t - Math.sin(e) * Math.sin(t * 0.11) * 3];
  const libre = (x, z, r) => !blocs.some(b => Math.hypot(b.x - x, b.z - z) < b.r + r);
  Vg.fumees = [];
  const maison = (x, z, r, i) => { // une maison, sa porte, son détail devant, parfois un potager
    const grange = i % 5 === 2, niv = grange ? 1 : [1, 2, 2, 3][i % 4]; pose(plan3D(grange ? 'scierie' : 'maison', niv), x, z, r); blocs.push({ x, z, r: grange ? 3.8 : 3.2 });
    const fx = Math.sin(r), fz = Math.cos(r), lx = Math.cos(r), lz = -Math.sin(r), px = x + fx * 3.6 - lx * 1.3, pz = z + fz * 3.6 - lz * 1.3; portes.push(V(px, 0, pz)); spots.push({ x: px, z: pz, anim: 'Interact', dur: [2, 4], regard: r + Math.PI });
    if (!grange) Vg.fumees.push(V(x - fx * 0.8 + lx * 1.2, hauteur(x, z) + (niv > 1 ? 9.5 : 6.6), z - fz * 0.8 + lz * 1.2));
    const deco = i % 4; if (deco === 0) { pose(vp('Prop_Barrel_1'), x + fx * 3.3 + lx * 2.4, z + fz * 3.3 + lz * 2.4, 0, K); pose(vp('Prop_Barrel_1'), x + fx * 3.0 + lx * 2.9, z + fz * 3.0 + lz * 2.9, 1, K * 0.9); }
    else if (deco === 1) pose(modele('Bench'), x + fx * 3.5 + lx * 2.2, z + fz * 3.5 + lz * 2.2, r + Math.PI / 2, 0.85);
    else if (deco === 2) pose(vp('Prop_Ladder_1'), x - lx * 2.9, z - lz * 2.9, r + Math.PI / 2, K * 0.9).rotation.z = -0.25;
    else pose(vp('Prop_Crate_1'), x + fx * 3.2 + lx * 2.6, z + fz * 3.2 + lz * 2.6, 0.4, K * 0.6);
    if (i % 3 === 0) { // potager clôturé sur le côté de la maison
      const gx = x + lx * 6.2 - fx * 0.6, gz = z + lz * 6.2 - fz * 0.6; if (libre(gx, gz, 2.5)) {
        for (const [ox, oz, rr] of [[0, 2.6, 0], [0, -2.6, 0], [2.6, 0, Math.PI / 2], [-2.6, 0, Math.PI / 2]]) for (const k of [-1, 0, 1]) { if (oz > 0 && k === 0) continue; const ax = ox ? ox : k * 1.72, az = oz ? oz : k * 1.72; pose(vp('Fence_01'), gx + lx * ax + fx * az, gz + lz * ax + fz * az, r + rr, 1); }
        for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) pose(vp((a + b) % 2 ? 'Cabbage_01' : 'TomatoPlant_01'), gx + lx * a * 1.4 + fx * b * 1.4, gz + lz * a * 1.4 + fz * b * 1.4, a + b, (a + b) % 2 ? 0.012 : 0.011);
        blocs.push({ x: gx, z: gz, r: 2.4 }); spots.push({ x: gx + fx * 2.9, z: gz + fz * 2.9, anim: 'Farm_Harvest', dur: [8, 16], regard: r + Math.PI }); } }
  };
  // la grand-rue
  let cote = 1, n = 0;
  for (let t = Vg.r - 1; t > -Vg.r - 4; t -= rnd(7.6, 8.6)) { if (Math.abs(t) < 7) continue; const [rx, rz] = surRue(t);
    for (const s of [1, -1]) { if ((n + (s > 0 ? 0 : 1)) % 3 === 2 && Math.abs(t) > Vg.r - 4) continue; const off = rnd(9.2, 10), x = rx + Math.cos(e) * off * s, z = rz - Math.sin(e) * off * s; if (!libre(x, z, 3.2)) continue; maison(x, z, Math.atan2(rx - x, rz - z) + rnd(-0.12, 0.12), n++); } }
  // la ruelle (perpendiculaire, depuis la place) avec 2 maisons de chaque côté
  const ep = e + Math.PI / 2; for (let t = 9; t < 24; t += 7.5) { const rx = cx + Math.sin(ep) * t, rz = cz + Math.cos(ep) * t; for (const s of [1, -1]) { const x = rx + Math.cos(ep) * 8.5 * s, z = rz - Math.sin(ep) * 8.5 * s; if (libre(x, z, 3.2)) maison(x, z, Math.atan2(rx - x, rz - z), n++); } }
  Vg.ruelle = [cx + Math.sin(ep) * 26, cz + Math.cos(ep) * 26];
  // lanternes de rue
  for (let t = Vg.r + 2; t > -Vg.r; t -= 9) { const [rx, rz] = surRue(t), s = (Math.round(t / 9) % 2) ? 1 : -1, x = rx + Math.cos(e) * 3 * s, z = rz - Math.sin(e) * 3 * s; if (libre(x, z, 0.5)) pose(vp('Prop_Lamp_Street'), x, z, e + (s > 0 ? Math.PI : 0), K); }
  // la place : puits, cloche, étal sous auvent, charrette de foin, meules
  pose(modele('well_01'), cx, cz, 0, 1.15); blocs.push({ x: cx, z: cz, r: 1.3 });
  for (let k = 0; k < 3; k++) { const a = k * 2.1 + 0.4; spots.push({ x: cx + Math.sin(a) * 2.4, z: cz + Math.cos(a) * 2.4, anim: 'Idle_Talking_Loop', dur: [8, 16], regard: a + Math.PI, place: true }); }
  { const x = cx + Math.cos(e) * 4.8, z = cz - Math.sin(e) * 4.8, r = e + Math.PI / 2; pose(vp('Canopy_Full'), x, z, r, K * 1.4); pose(vp('Prop_Crate_1'), x, z, 0, K * 0.55); pose(vp('Prop_Crate_1'), x + 0.6, z + 0.6, 0.3, K * 0.4); spots.push({ x: x - Math.cos(e) * 1.9, z: z + Math.sin(e) * 1.9, anim: 'PickUp_Table', dur: [5, 10], regard: r + Math.PI }); }
  { const x = cx - Math.cos(e) * 5 + Math.sin(e) * 3, z = cz + Math.sin(e) * 5 + Math.cos(e) * 3; const p = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.15, 3.2, 6), MAT_POTEAU); p.position.y = 1.6; const g = new THREE.Group(); g.add(p); const cl = vp('Wall_Prop_Bell_1'); cl.position.set(0, 2.2, 0); cl.scale.setScalar(K); g.add(cl); pose(g, x, z, e); }
  { const x = cx - Math.cos(e) * 4.5 - Math.sin(e) * 2, z = cz + Math.sin(e) * 4.5 - Math.cos(e) * 2; pose(modele('fire_01'), x, z); Vg.feu = V(x, hauteur(x, z), z); spots.push({ x: x + 1.4, z, anim: 'Idle_Talking_Loop', dur: [8, 15], regard: -Math.PI / 2 }); }
  { const x = cx + Math.cos(e) * 6 - Math.sin(e) * 6, z = cz - Math.sin(e) * 6 - Math.cos(e) * 6; pose(vp('Prop_Cart_1_Hay'), x, z, e + 0.5, K); for (let k = 0; k < 3; k++) pose(vp('Prop_Hay_1'), x + 2.4 + k * 0.4, z - 1 + k * 1.1, k, K * 1.3); }
  // champs de blé derrière le village, charrette de tonneaux
  for (const s of [1, -1]) { const x = cx + Math.cos(e) * 21 * s - Math.sin(e) * 4, z = cz - Math.sin(e) * 21 * s - Math.cos(e) * 4; autres.add(champ(x, z, e, 14, 8, true)); for (let k = 0; k < 2; k++) spots.push({ x: x + Math.sin(e) * (k * 6 - 3), z: z + Math.cos(e) * (k * 6 - 3), anim: 'Farm_Harvest', dur: [10, 20], regard: e + Math.PI / 2 * s }); }
  // panneau à l'entrée
  { const [rx, rz] = surRue(Vg.r + 4), x = rx + Math.cos(e) * 2.6, z = rz - Math.sin(e) * 2.6; pose(modele('sign_inn_01'), x, z, e + Math.PI / 2, 1); }
  // ---- le lieu emblématique ----
  Vg.animes = [];
  if (Vg.id === 'saules') { // le moulin : grande roue à ailes qui tourne sur le pignon d'une maison haute
    const [rx, rz] = surRue(-Vg.r - 2), x = rx - Math.cos(e) * 9, z = rz + Math.sin(e) * 9, r = Math.atan2(rx - x, rz - z); pose(plan3D('maison', 3), x, z, r); blocs.push({ x, z, r: 3.3 });
    const ailes = vp('Wall_Prop_Windmill_1'); ailes.scale.setScalar(1.25); const g = new THREE.Group(); g.add(ailes); g.position.set(x - Math.sin(r) * 3.4, hauteur(x, z) + 7.6, z - Math.cos(r) * 3.4); g.rotation.y = r + Math.PI / 2; autres.add(g); Vg.animes.push({ o: ailes, ax: 'x', v: 0.6 });
    spots.push({ x: x + Math.sin(r) * 3.8, z: z + Math.cos(r) * 3.8, anim: 'Walk_Carry_Loop', dur: [3, 6], regard: r });
  }
  if (Vg.id === 'portlac') { // le ponton de pêche, barques amarrées qui tanguent
    const L = LACS.find(l => l.nom.includes('Argent')), dxl = Vg.x - L.x, dzl = Vg.z - L.z, dl = Math.hypot(dxl, dzl), ux = dxl / dl, uz = dzl / dl, a = Math.atan2(-ux, -uz), y = NIVEAU_EAU + 0.95;
    const s0x = L.x + ux * L.r * 1.02, s0z = L.z + uz * L.r * 1.02; const pont = new THREE.Group();
    for (let k = 0; k < 9; k++) for (const w of [-1, 0, 1]) { const t = vp('Wood_Floor_Straight_1'); t.scale.setScalar(K); t.position.set(w * K, 0, k * K); pont.add(t); if (k % 2 === 0 && w !== 0) { const p = vp('Wood_Post_Large'); p.scale.set(K, 3, K); p.position.set(w * K * 1.25, -1.5, k * K); pont.add(p); } }
    for (let k = 0; k < 9; k++) for (const w of [-1, 1]) { const rl = vp('Wood_Railing_Straight'); rl.scale.setScalar(K); rl.rotation.y = w > 0 ? -Math.PI / 2 : Math.PI / 2; rl.position.set(w * K * 1.1, 0, k * K); if (k > 1) pont.add(rl); }
    pont.position.set(s0x, y, s0z); pont.rotation.y = a; autres.add(pont);
    for (const [k, w, b] of [[3, 2.6, 'Prop_Boat_1'], [6, -2.6, 'Prop_Boat_2'], [8, 2.6, 'Prop_Boat_1']]) { const bt = vp(b); bt.scale.setScalar(K); const g = new THREE.Group(); g.add(bt); const ox = Math.sin(a) * k * K + Math.cos(a) * w, oz = Math.cos(a) * k * K - Math.sin(a) * w; g.position.set(s0x + ox, NIVEAU_EAU - 0.55, s0z + oz); g.rotation.y = a + 0.15; autres.add(g); Vg.animes.push({ o: g, tangage: rnd(0, 6) }); if (b === 'Prop_Boat_1') { const r2 = vp('Prop_Boat_Oars_1'); r2.scale.setScalar(K); bt.add(r2); } }
    const bout = [s0x + Math.sin(a) * 8 * K, s0z + Math.cos(a) * 8 * K]; Vg.pecheur = { x: bout[0], z: bout[1], y: y, regard: a };
    pose(vp('Canopy_Full'), s0x - Math.sin(a) * 4 + Math.cos(a) * 3, s0z - Math.cos(a) * 4 - Math.sin(a) * 3, a, K * 1.4); for (let k = 0; k < 2; k++) pose(vp('Prop_Barrel_1'), s0x - Math.sin(a) * 5 + Math.cos(a) * (4.6 + k * 0.9), s0z - Math.cos(a) * 5 - Math.sin(a) * (4.6 + k * 0.9), k, K);
    spots.push({ x: s0x - Math.sin(a) * 2.5 + Math.cos(a) * 3, z: s0z - Math.cos(a) * 2.5 - Math.sin(a) * 3, anim: 'PickUp_Table', dur: [6, 12], regard: a + Math.PI });
    spots.push({ x: s0x + Math.sin(a) * 3, z: s0z + Math.cos(a) * 3, anim: 'Idle_FoldArms_Loop', dur: [8, 16], regard: a });
  }
  const g = new THREE.Group(); fusionner(brut, g); g.add(autres); G.scene.add(g); Vg.g = g; Vg.spots = spots; Vg.portes = portes;
}
export const MAT_POTEAU = new THREE.MeshStandardMaterial({ color: '#4a3524', roughness: 0.9 });
// ======== Valcourt, la capitale ========
// Plan (nord = la route) : grande porte fortifiée (herse levée, battants ouverts, gardes) → avenue royale bordée de lanternes
// → place du marché (étals et marchands, puits) → quartiers d'habitation → escalier du palais → salle du trône (le roi Aldric).
const HE = 3.12, K = 1.3;
const MAT_POT = new THREE.MeshStandardMaterial({ color: '#4a3524', roughness: 0.9 });
export const MAT_OR = new THREE.MeshStandardMaterial({ color: '#e8c050', metalness: 0.8, roughness: 0.3, emissive: '#5a3a00', emissiveIntensity: 0.4 });
export function tour(pose, x, z, niveaux, k = K) { // tour octogonale : 8 pans de mur par niveau, fenêtres en haut, toit conique de tuiles
  const ap = 2.414 * k;
  for (let n = 0; n < niveaux; n++) for (let i = 0; i < 8; i++) { const a = i / 8 * 6.2832 + Math.PI / 8; const o = modele(n === niveaux - 1 ? 'Wall_UnevenBrick_Window_Wide_Round' : 'Wall_UnevenBrick_Straight'); pose(o, x + Math.sin(a) * ap, z + Math.cos(a) * ap, a + Math.PI, k, n * HE * k); }
  pose(modele('Roof_Tower_RoundTiles'), x, z, 0, k * 1.05, niveaux * HE * k + 0.3);
  blocs.push({ x, z, r: ap + 0.4 });
}
const MAT_DALLE = new THREE.MeshStandardMaterial({ color: '#b0a690', roughness: 0.95 });
export async function chargerValcourt() {}

// ---------------- Les habitants ----------------
export class Villageois {
  constructor(Vg, x, z, { garde = false, visiteur = false, roi = false, marchand = false, enfant = false, sexe = null, nomme = null } = {}) {
    this.v = Vg; this.garde = garde || roi || marchand; this.roi = roi; this.marchand = marchand;
    this.m = new Perso({ sexe: sexe || nomme?.sexe || (roi || garde ? 'h' : Math.random() < 0.5 ? 'h' : 'f'), tenue: garde || roi ? 'rodeur' : 'paysan', cheveux: roi ? 2 : Math.floor(rnd(0, 3)), couleurTenue: nomme ? nomme.couleur : roi ? '#6a2a9a' : garde ? '#4a6ab0' : marchand ? pick(['#b05a3a', '#3a7a5a', '#8a6a2a']) : pick(TENUES) });
    if (garde) this.m.tenir(epee(), 'hand_r');
    if (enfant) { this.m.root.scale.setScalar(0.62); this.enfant = true; }
    this.m.portee = 45; /* habitants : dessinés jusqu'à 50 m (ce sont les personnages qui coûtent le plus) */
    this.m.root.position.set(x, hauteur(x, z), z); this.m.root.rotation.y = rnd(0, 6.28); G.scene.add(this.m.root);
    this.etat = 'faire'; this.t = rnd(0.5, 6); this.m.jouer(garde ? 'Sword_Idle' : 'Idle_Loop', { vitesse: rnd(0.85, 1.1) }); this.vit = rnd(1.15, 1.5);
    habitants.push(this);
  }
  get pos() { return this.m.root.position; }
  tourner(a, dt) { let da = a - this.m.root.rotation.y; da = Math.atan2(Math.sin(da), Math.cos(da)); this.m.root.rotation.y += da * Math.min(1, dt * 7); }
  aller(dest, dt, vit, anim) {
    const dx = dest.x - this.pos.x, dz = dest.z - this.pos.z, d = Math.hypot(dx, dz); if (d < 0.3) return true;
    let vx = dx / d, vz = dz / d; for (const o of habitants) if (o !== this && !o.cache) { const ox = this.pos.x - o.pos.x, oz = this.pos.z - o.pos.z, od = Math.hypot(ox, oz); if (od < 0.9 && od > 0.01) { vx += ox / od * 0.6; vz += oz / od * 0.6; } } // on se croise sans se rentrer dedans
    const l = Math.hypot(vx, vz) || 1, pas = Math.min(d, vit * dt), nx = this.pos.x + vx / l * pas, nz = this.pos.z + vz / l * pas;
    if (bloqueHumain(nx, nz)) { const a = Math.atan2(vx, vz) + 1.2; this.pos.x += Math.sin(a) * pas; this.pos.z += Math.cos(a) * pas; } else { this.pos.x = nx; this.pos.z = nz; } // contourne la maison
    this.pos.y = hauteur(this.pos.x, this.pos.z); this.tourner(Math.atan2(vx, vz), dt); this.m.jouer(anim, { vitesse: anim === 'Walk_Loop' || anim === 'Walk_Carry_Loop' ? vit / 1.6 : vit / 4.5 }); return false;
  }
  maj(dt) {
    if (this.cache) { if (!this.v.attaque) { this.cache = false; this.m.root.visible = true; this.etat = 'fete'; this.t = rnd(2, 4); this.m.jouer('Yes', { forcer: true }); } return; }
    this.m.maj(dt);
    if (this.v.attaque && this.etat !== 'fuir' && !this.messager) { this.etat = 'fuir'; this.abri = pick(this.v.portes); if (dist(this.pos, G.camera.position) < 50) texteFlottant(tmp(this.pos.x, this.pos.y + 2.2, this.pos.z), pick(['Au secours !', 'Fuyez !', 'À l’abri !']), 'alerte'); }
    const E = this.etat;
    if (E === 'fuir') { if (this.aller(this.abri, dt, 4.2, 'Sprint_Loop')) { this.cache = true; this.m.root.visible = false; } return; }
    if (E === 'fete') { this.t -= dt; if (this.t <= 0) this.etat = 'faire'; return; }
    if (E === 'messager') return this.majMessager(dt);
    if (E === 'visite') return this.majVisite(dt);
    if (this.cerveau) return this.cerveau(this, dt);
    if (this.patrouille) { const b = this.patrouille[this.pi]; if (this.aller(b, dt, 1.3, 'Walk_Loop')) this.pi = 1 - this.pi; return; }
    if (this.roi) { const d = dist(this.pos, C.joueur.pos); if (d < 5 && !this.v.audience) { this.v.audience = true; parlerRoi(this); } return; }
    if (this.marchand) { if (this.regard != null) this.tourner(this.regard, dt); if (this.v.type === 'ville' && dist(this.pos, C.joueur.pos) < 3.6) G.marchandT = G.t; /* à portée d'un marchand de Valcourt : on peut commercer */ this.cri = (this.cri ?? rnd(2, 8)) - dt; if (this.cri <= 0) { this.cri = rnd(7, 14); if (dist(this.pos, C.joueur.pos) < 14) { texteFlottant(tmp(this.pos.x, this.pos.y + 2.3, this.pos.z), pick(['Pommes fraîches !', 'Du bon pain, du bon !', 'Épices d’Orient !', 'Lames affûtées !', 'Tissus de Valcourt !', 'Approchez, approchez !']), 'info'); this.m.jouer('Idle_Talking_Loop', { forcer: true }); } else this.m.jouer('Idle_Loop'); } return; }
    if (this.garde) { if (this.regard != null) this.tourner(this.regard, dt); return; }
    if (E === 'faire') { this.t -= dt; if (this.t > 0) { if (this.spot) this.tourner(this.spot.regard, dt); return; }
      const libres = this.v.spots.filter(s => !s.pris || s.place); this.spot && (this.spot.pris = false); this.spot = pick(libres); this.spot.pris = true; this.but = V(this.spot.x + rnd(-0.3, 0.3), 0, this.spot.z + rnd(-0.3, 0.3)); this.etat = 'aller'; this.charge = Math.random() < 0.25; return; }
    if (E === 'aller' && this.aller(this.but, dt, this.vit, this.charge ? 'Walk_Carry_Loop' : 'Walk_Loop')) { this.etat = 'faire'; this.t = rnd(...this.spot.dur); this.m.jouer(this.spot.anim, { forcer: true, vitesse: rnd(0.85, 1.1) }); }
  }
  // ---- le messager : il court jusqu'à toi, reprend son souffle, et te supplie ----
  majMessager(dt) {
    const J = C.joueur.pos;
    if (!this.parle) { if (dist(this.pos, J) > 3.2) { this.aller(J, dt, 5.2, 'Sprint_Loop'); return; } this.parle = true; this.t = 4; this.m.jouer('Idle_Talking_Loop', { forcer: true }); son('confirmation_001', 0.5, 0.8); texteFlottant(tmp(this.pos.x, this.pos.y + 2.4, this.pos.z), `Seigneur ! ${this.v.nom} est attaqué !`, 'alerte-sort'); C.toast(`📯 ${this.v.nom} appelle à l’aide : repousse les envahisseurs !`); }
    this.tourner(Math.atan2(J.x - this.pos.x, J.z - this.pos.z), dt); this.t -= dt; if (this.t <= 0) { this.etat = 'visite'; this.retour = true; this.messager = false; this.parle = false; }
  }
  // ---- le visiteur : il vient flâner à ton camp, regarde, discute, puis rentre chez lui ----
  majVisite(dt) {
    if (!this.retour) { if (!this.sur) { if (this.aller(this.dest, dt, this.vit, 'Walk_Loop')) { this.sur = true; this.t = rnd(25, 45); this.m.jouer(pick(['Idle_Talking_Loop', 'Idle_FoldArms_Loop', 'Idle_Loop']), { forcer: true }); } return; } this.t -= dt; if (this.t <= 0) this.retour = true; return; }
    const maison = V(this.v.x, 0, this.v.z); if (this.aller(maison, dt, this.vit, 'Walk_Loop') || dist(this.pos, maison) < this.v.r) { this.etat = 'faire'; this.t = rnd(2, 5); this.sur = false; this.retour = false; }
  }
}

// ---------------- Événements : visites et appels à l'aide ----------------
const INVASIONS = { saules: { nom: 'Gobelins pillards', membres: ['gobelin', 'gobelin', 'sorcier', 'gobelin'], niv: 2 }, portlac: { nom: 'Pillards du lac', membres: ['bandit', 'bandit', 'bandit'], niv: 2 }, valcourt: { nom: 'Avant-garde de la Horde', membres: ['berserker', 'berserker', 'chamane'], niv: 3 } };
let tInv = 240, tVis = 90, inv = null;
function appelAide() {
  const Vg = pick(VILLAGES.filter(v => dist(v, C.joueur.pos) > 40)); if (!Vg) return; const I = INVASIONS[Vg.id];
  const membres = I.membres.map((type, i) => { const a = i / I.membres.length * 6.283, r = Vg.r * 0.45; return { type, x: Vg.x + Math.sin(a) * r, z: Vg.z + Math.cos(a) * r }; });
  inv = { Vg, t: 420 }; Vg.attaque = true;
  lancerInvasion({ id: 'inv', nom: `${I.nom} à ${Vg.nom}`, type: I.membres[0], centre: V(Vg.x, 0, Vg.z), r: Vg.r + 4, niv: I.niv, membres, fin: () => finAttaque(true) });
  // un messager part du bord de ton champ de vision et court vers toi
  const J = C.joueur.pos, a = Math.atan2(Vg.x - J.x, Vg.z - J.z), x = J.x + Math.sin(a) * 26, z = J.z + Math.cos(a) * 26, m = new Villageois(Vg, x, z); m.etat = 'messager'; m.messager = true;
  G.mission = { t: `À l’aide : ${Vg.nom}`, s: `${I.nom} attaquent le village. Repousse-les avant qu’ils ne repartent avec le butin.`, guide: () => V(Vg.x, 0, Vg.z) }; C.majQuete();
}
function finAttaque(victoire) {
  const Vg = inv.Vg; inv = null; Vg.attaque = false; G.mission = null; C.majQuete();
  if (victoire) { C.J.reputation = (C.J.reputation || 0) + 10; C.ajouter('bois', 80, V(Vg.x, 0, Vg.z)); C.ajouter('pierre', 50, V(Vg.x + 1, 0, Vg.z)); C.toast(`🙏 ${Vg.nom} te remercie ! Réputation +10 (${C.J.reputation})`); son('jingles_PIZZI03', 0.7); }
  else { finirInvasion('inv'); C.J.reputation = Math.max(0, (C.J.reputation || 0) - 5); C.toast(`😞 Personne n’est venu… ${Vg.nom} a été pillé. Réputation −5`); }
  C.sauver(); C.majHud();
}
function visite() {
  const Vg = pick(VILLAGES), h = habitants.filter(x => x.v === Vg && x.etat === 'faire' && !x.garde && !x.cache); if (!h.length || Vg.attaque) return;
  const o = pick(h); o.spot && (o.spot.pris = false); o.etat = 'visite'; o.dest = V(rnd(-6, 6), 0, rnd(4, 9)); o.sur = false; o.retour = false;
}

export function initHumains(ctx) {
  C = ctx; G.obstacleBat = bloqueHumain; // la caméra se rapproche au lieu de passer à travers les maisons
  for (const Vg of VILLAGES) {
    construire(Vg);
    if (Vg.pecheur) { const P = Vg.pecheur, h = new Villageois(Vg, P.x, P.z, { sexe: 'h' }); h.m.root.position.y = P.y; h.regard = P.regard; h.m.root.rotation.y = P.regard; h.cerveau = (h) => { h.m.root.position.y = P.y; h.m.jouer('Idle_FoldArms_Loop'); }; } // le pêcheur au bout du ponton
    const n = Vg.type === 'ville' ? 0 : 11; for (let i = 0; i < n; i++) { const s = pick(Vg.spots); new Villageois(Vg, s.x + rnd(-1, 1), s.z + rnd(-1, 1)); }
    if (Vg.type === 'ville') peuplerCapitale(Vg, C);
  }
}
function parlerRoi(roi) {
  roi.m.jouer('Idle_Talking_Loop', { forcer: true }); const rep = C.J.reputation || 0;
  const L = rep >= 30 ? ['Roi Aldric : « Souverain des Ombres… Mes villages chantent ton nom. »', 'Roi Aldric : « Valcourt te doit beaucoup. Sois le bienvenu à ma cour. »']
    : ['Roi Aldric : « Ainsi, c’est toi qu’on appelle le Souverain des Ombres. »', 'Roi Aldric : « Mes villages sont harcelés par les pillards et la Horde. »', 'Roi Aldric : « Protège-les, et Valcourt saura s’en souvenir. »'];
  L.forEach((t, i) => setTimeout(() => C.toast(t), i * 3200)); setTimeout(() => roi.m.jouer('Sitting_Idle_Loop', { forcer: true }), L.length * 3200);
  setTimeout(() => { roi.v.audience = false; }, 60000);
}
let lent = 0;
export function majHumains(dt) {
  for (const Vg of VILLAGES) if (Vg.palais) { const P = Vg.palais, J = C.joueur.pos, dedans = Math.abs(J.x - P.x) < P.w && Math.abs(J.z - P.z) < P.d; P.haut.visible = !dedans; } // dans le palais : on enlève le toit pour voir la salle du trône
  for (const Vg of VILLAGES) { const cam = G.camera.position; if (dist(Vg, cam) > 90) continue;
    for (const A of Vg.animes || []) { if (A.ax) A.o.rotation[A.ax] += dt * A.v; else { A.tangage += dt; A.o.rotation.z = Math.sin(A.tangage * 1.3) * 0.06; A.o.position.y += Math.sin(A.tangage * 1.7) * 0.002; } } // ailes du moulin, barques qui tanguent
    for (const f of Vg.fumees || []) if (Math.random() < dt * 2.2) emettre(tmp(f.x + rnd(-0.15, 0.15), f.y, f.z + rnd(-0.15, 0.15)), { n: 1, c1: '#d8d4cc', c2: '#8a8680', vit: 0.25, vie: 3.2, taille: 0.7, grav: -0.45 }); } // fumée des cheminées
  for (const Vg of VILLAGES) if (Vg.feu && dist(Vg.feu, G.camera.position) < 60 && Math.random() < dt * 30) emettre(tmp(Vg.feu.x + rnd(-0.3, 0.3), Vg.feu.y + 0.4, Vg.feu.z + rnd(-0.3, 0.3)), { n: 1, c1: '#ffd27a', c2: '#ff3a0a', vit: 0.6, vie: 0.8, taille: 0.3, grav: -2.5 }); // le feu de la place crépite
  for (const h of habitants) { const c = G.camera.position, loin = (h.pos.x - c.x) ** 2 + (h.pos.z - c.z) ** 2 > 14400; if (!loin || h.etat === 'messager' || h.etat === 'visite') h.maj(dt); else if ((h.lent = (h.lent || 0) + dt) > 0.5) { h.maj(h.lent); h.lent = 0; } } // loin de la caméra : vie au ralenti
  if ((lent += dt) < 1) return; const d = lent; lent = 0;
  for (const Vg of VILLAGES) if (Vg.g) { const dc = dist(Vg, G.camera.position); Vg.g.visible = dc < 280; }
  if (inv) { inv.t -= d; if (inv.t <= 0) finAttaque(false); return; }
  if ((tInv -= d) <= 0) { tInv = rnd(420, 660); appelAide(); }
  if ((tVis -= d) <= 0) { tVis = rnd(150, 240); visite(); }
}
export const humainsDebug = { appelAide, visite };
