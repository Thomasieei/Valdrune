// Les humains : deux villages et une ville, qui vivent sans toi (travail, discussions, allées et venues).
// De temps en temps, l'un d'eux vient jusqu'à ton camp ; et quand un village est attaqué, un messager court te chercher.
import { THREE, G, V, tmp, texteFlottant, son, emettre } from './moteur.js';
import { Perso } from './persos.js';
import { hauteur, VILLAGES } from './monde.js';
import { plan3D, modele } from './batiments.js';
import { lancerInvasion, finirInvasion, epee } from './combat.js';
import { prop } from './persos.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

let C = null; // { J, joueur, toast, sauver, majHud, ajouter }
const rnd = (a, b) => a + Math.random() * (b - a), pick = (L) => L[Math.floor(Math.random() * L.length)];
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const TENUES = ['#c8a070', '#8aa0c0', '#b07a6a', '#9ab07a', '#c8b890', '#a08ab8', '#d0c0a0', '#7a9a9a'];
export const habitants = [];
const blocs = []; // maisons : on ne traverse pas les murs
export const bloqueHumain = (x, z) => { for (const b of blocs) if (Math.abs(b.x - x) < b.r && Math.abs(b.z - z) < b.r && Math.hypot(b.x - x, b.z - z) < b.r) return true; return false; };

// ---------------- Construction : toutes les maisons d'un village fusionnées par matière (une dizaine d'appels de dessin) ----------------
function fusionner(groupe, parent) {
  groupe.updateMatrixWorld(true); const parMat = new Map(), seuls = [];
  groupe.traverse(o => { if (!o.isMesh) return; if (Array.isArray(o.material)) { seuls.push(o); return; } const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone(); g.applyMatrix4(o.matrixWorld); for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k); if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2)); if (!parMat.has(o.material)) parMat.set(o.material, []); parMat.get(o.material).push(g); });
  for (const [mat, L] of parMat) { const m = new THREE.Mesh(mergeGeometries(L), mat); m.castShadow = m.receiveShadow = true; parent.add(m); L.forEach(g => g.dispose()); }
  for (const o of seuls) { const c = o.clone(); o.matrixWorld.decompose(c.position, c.quaternion, c.scale); parent.add(c); }
}
// ---- un champ : terre labourée en sillons et rangs de blé ou de choux (2 appels de dessin) ----
const MAT_TERRE = new THREE.MeshStandardMaterial({ color: '#6e5236', roughness: 1 }), MAT_BLE = new THREE.MeshStandardMaterial({ color: '#d8b850', roughness: 0.9, flatShading: true }), MAT_CHOU = new THREE.MeshStandardMaterial({ color: '#6aa040', roughness: 0.9, flatShading: true });
function champ(x, z, r, L, W, ble) {
  const g = new THREE.Group(), sol = [], pl = [];
  for (let i = 0; i < Math.floor(W / 1.1); i++) { const ox = -W / 2 + 0.55 + i * 1.1; const s = new THREE.BoxGeometry(0.6, 0.18, L).translate(ox, 0.05, 0); sol.push(s);
    for (let k = 0; k < L / 0.7; k++) { const oz = -L / 2 + 0.35 + k * 0.7, h = ble ? rnd(0.6, 0.9) : 0.3; const p = ble ? new THREE.ConeGeometry(0.16, h, 4).translate(ox, 0.15 + h / 2, oz) : new THREE.IcosahedronGeometry(0.24, 0).translate(ox, 0.25, oz); pl.push(p); } }
  const m1 = new THREE.Mesh(mergeGeometries(sol), MAT_TERRE), m2 = new THREE.Mesh(mergeGeometries(pl), ble ? MAT_BLE : MAT_CHOU); m1.receiveShadow = true; m2.castShadow = true; g.add(m1, m2);
  g.position.set(x, hauteur(x, z) - 0.02, z); g.rotation.y = r; return g;
}
// ---- un village organique : une rue qui serpente, des maisons de part et d'autre (portes sur la rue),
// jardins clôturés, champs derrière, puits sur la place, étal, lanternes, tas de bois, tonneaux ----
function construire(Vg) {
  if (Vg.type === 'ville') return construireVille(Vg);
  const brut = new THREE.Group(), autres = new THREE.Group(), cx = Vg.x, cz = Vg.z, spots = [], portes = [], e = Vg.entree;
  const pose = (o, x, z, r = 0, k = 1, dy = 0) => { o.position.set(x, hauteur(x, z) + dy, z); o.rotation.y = r; o.scale.multiplyScalar(k); brut.add(o); return o; };
  const surRue = (t) => { const x = cx + Math.sin(e) * t + Math.cos(e) * Math.sin(t * 0.11) * 3, z = cz + Math.cos(e) * t - Math.sin(e) * Math.sin(t * 0.11) * 3; return [x, z]; };
  // maisons le long de la rue, en quinconce, chacune un peu différente
  let cote = 1, n = 0;
  for (let t = Vg.r - 3; t > -Vg.r + 2; t -= rnd(7.5, 9.5)) {
    if (Math.abs(t) < 5) continue; // la place du village
    const [rx, rz] = surRue(t), off = rnd(7.2, 8.4), x = rx + Math.cos(e) * off * cote, z = rz - Math.sin(e) * off * cote;
    const versRue = Math.atan2(rx - x, rz - z) + rnd(-0.2, 0.2), grange = n === 2, niv = grange ? 1 : Math.random() < 0.45 ? 2 : 1;
    pose(plan3D(grange ? 'scierie' : 'maison', niv), x, z, versRue); blocs.push({ x, z, r: grange ? 3.8 : 3.2 });
    const fx = Math.sin(versRue), fz = Math.cos(versRue), lx = Math.cos(versRue), lz = -Math.sin(versRue);
    const px = x + fx * 3.6, pz = z + fz * 3.6; portes.push(V(px, 0, pz)); spots.push({ x: px, z: pz, anim: 'Interact', dur: [2, 4], regard: versRue + Math.PI });
    // jardin clôturé sur le côté, avec un potager
    const gx = x + lx * 5.2 - fx * 0.5, gz = z + lz * 5.2 - fz * 0.5;
    autres.add(champ(gx - fx * 0.2, gz - fz * 0.2, versRue, 3.2, 3.3, false));
    spots.push({ x: gx + fx * 1.2, z: gz + fz * 1.2, anim: 'Farm_Harvest', dur: [8, 16], regard: versRue + Math.PI });
    // devant la porte : tonneaux, caisses, banc, tas de bois — jamais deux maisons pareilles
    const deco = [['Barrel', 0.9], ['Crate_Wooden', 0.7], ['Cauldron', 0.7]]; const [dn, dk] = deco[n % 3];
    pose(prop(dn), x + fx * 3.2 - lx * 2.4, z + fz * 3.2 - lz * 2.4, rnd(0, 6), dk);
    if (n % 2) pose(modele('Bench'), x + fx * 3.4 + lx * 2, z + fz * 3.4 + lz * 2, versRue + Math.PI / 2, 0.85);
    else { for (let k = 0; k < 3; k++) { const b = modele('Barrel_Closed'); pose(b, x - lx * 3.2 + fx * (k - 1) * 0.8, z - lz * 3.2 + fz * (k - 1) * 0.8, 0, 0.7); } spots.push({ x: x - lx * 4.2, z: z - lz * 4.2, anim: 'PickUp_Table', dur: [5, 9], regard: versRue - Math.PI / 2 }); }
    cote = -cote; n++;
  }
  // grands champs derrière le village (blé), où l'on travaille
  for (const s of [1, -1]) { const x = cx + Math.cos(e) * 19 * s - Math.sin(e) * 4, z = cz - Math.sin(e) * 19 * s - Math.cos(e) * 4; autres.add(champ(x, z, e, 14, 8, true)); for (let k = 0; k < 2; k++) spots.push({ x: x + Math.sin(e) * (k * 6 - 3), z: z + Math.cos(e) * (k * 6 - 3), anim: 'Farm_Harvest', dur: [10, 20], regard: e + Math.PI / 2 * s }); }
  // la place : puits, un étal, un feu, des lanternes le long de la rue
  pose(modele('well_01'), cx, cz, 0, 1.15); blocs.push({ x: cx, z: cz, r: 1.3 });
  for (let k = 0; k < 3; k++) { const a = k * 2.1 + 0.4; spots.push({ x: cx + Math.sin(a) * 2.4, z: cz + Math.cos(a) * 2.4, anim: 'Idle_Talking_Loop', dur: [8, 16], regard: a + Math.PI, place: true }); }
  { const x = cx + Math.cos(e) * 4.5, z = cz - Math.sin(e) * 4.5, r = e + Math.PI / 2; pose(modele('stall_01'), x, z, r, 1.1); spots.push({ x: x - Math.cos(e) * -1.8, z: z + Math.sin(e) * -1.8, anim: 'Idle_Talking_Loop', dur: [6, 14], regard: r + Math.PI }); spots.push({ x: x + Math.cos(e) * 1.1, z: z - Math.sin(e) * 1.1, anim: 'PickUp_Table', dur: [5, 10], regard: r }); }
  { const x = cx - Math.cos(e) * 4.5 - Math.sin(e) * 2, z = cz + Math.sin(e) * 4.5 - Math.cos(e) * 2; pose(modele('fire_01'), x, z); Vg.feu = V(x, hauteur(x, z), z); spots.push({ x: x + 1.4, z, anim: 'Idle_Talking_Loop', dur: [8, 15], regard: -Math.PI / 2 }); }
  for (const t of [Vg.r + 2, Vg.r * 0.45, -Vg.r * 0.45]) { const [rx, rz] = surRue(t); for (const s of t > Vg.r ? [1, -1] : [1]) { const x = rx + Math.cos(e) * 2.4 * s, z = rz - Math.sin(e) * 2.4 * s, poteau = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.1, 2.4, 6), MAT_POTEAU); poteau.position.y = 1.2; const gp = new THREE.Group(); gp.add(poteau); const tq = prop('Torch_Metal'); tq.position.set(0, 1.5, -0.15); gp.add(tq); pose(gp, x, z, Math.atan2(rx - x, rz - z) + Math.PI); } }
  // le nom du village sur un panneau à l'entrée
  { const [rx, rz] = surRue(Vg.r + 4), x = rx + Math.cos(e) * 2.6, z = rz - Math.sin(e) * 2.6; pose(modele('sign_inn_01'), x, z, e + Math.PI / 2, 1); }
  const g = new THREE.Group(); fusionner(brut, g); g.add(autres); G.scene.add(g); Vg.g = g; Vg.spots = spots; Vg.portes = portes;
}
const MAT_POTEAU = new THREE.MeshStandardMaterial({ color: '#4a3524', roughness: 0.9 });
// ---- Valcourt : une ville bâtie avec les mêmes pièces que le reste du jeu (style cohérent), rues larges pour la caméra :
// rempart de briques avec porte au nord, grand-rue nord-sud et rue est-ouest, place du marché au carrefour ----
function construireVille(Vg) {
  const brut = new THREE.Group(), cx = Vg.x, cz = Vg.z, spots = [], portes = [], H = 30;
  const pose = (o, x, z, r = 0, k = 1, dy = 0) => { o.position.set(x, hauteur(x, z) + dy, z); o.rotation.y = r; o.scale.multiplyScalar(k); brut.add(o); return o; };
  // rempart : modules de 2 m × 2 niveaux, créneaux de pierre, porte de 8 m face à la route
  for (const [sx, sz, r] of [[0, -1, 0], [0, 1, Math.PI], [-1, 0, Math.PI / 2], [1, 0, -Math.PI / 2]]) for (let t = -H; t < H; t += 2.6) {
    const x = cx + (sz ? t + 1.3 : sx * H), z = cz + (sz ? sz * H : t + 1.3); if (sz === -1 && Math.abs(x - cx) < 4) continue;
    for (let k = 0; k < 2; k++) pose(modele(k ? 'Wall_UnevenBrick_Window_Wide_Round' : 'Wall_UnevenBrick_Straight'), x, z, r, 1.3, k * HE * 1.3 * 0.98).visible = true;
    blocs.push({ x, z, r: 1.6 });
  }
  for (const sx of [-1, 1]) { const x = cx + sx * 4.6, z = cz - H; const t = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.9, 9, 8), MAT_PIERRE); t.position.y = 4.5; const g = new THREE.Group(); g.add(t); const c = new THREE.Mesh(new THREE.ConeGeometry(2.3, 3, 8), MAT_TOIT); c.position.y = 10.5; g.add(c); pose(g, x, z); blocs.push({ x, z, r: 2 }); const b = pose(prop('Banner_1'), x + sx * -1.7, z - 0.4, sx < 0 ? Math.PI : 0, 1.1, 4.5); b.add(prop('Banner_1_Cloth')); }
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) { const x = cx + sx * H, z = cz + sz * H; const t = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 2.6, 10, 8), MAT_PIERRE); t.position.y = 5; const g = new THREE.Group(); g.add(t); const c = new THREE.Mesh(new THREE.ConeGeometry(3, 4, 8), MAT_TOIT); c.position.y = 12; g.add(c); pose(g, x, z); blocs.push({ x, z, r: 2.6 }); }
  // maisons le long des deux rues (portes sur la rue), plus hautes et plus riches qu'au village
  const rues = [[0, 1], [1, 0]]; let n = 0;
  for (const [dx, dz] of rues) for (let t = -H + 6; t <= H - 6; t += 9) {
    if (Math.abs(t) < 10) continue; // la place
    for (const s of [-1, 1]) {
      if (dz && t < -H + 9) continue; // dégagement derrière la porte
      const off = 8.2 + (n % 3) * 0.4, x = cx + dx * t + dz * off * s, z = cz + dz * t + dx * off * s, r = Math.atan2(cx + dx * t - x, cz + dz * t - z);
      if (Math.abs(x - cx) > H - 4 || Math.abs(z - cz) > H - 4) continue;
      const niv = n % 3 === 0 ? 3 : 2; pose(plan3D('maison', niv), x, z, r); blocs.push({ x, z, r: 3.2 });
      const fx = Math.sin(r), fz = Math.cos(r), px = x + fx * 3.6 - fz * 1.3, pz = z + fz * 3.6 + fx * 1.3; portes.push(V(px, 0, pz)); spots.push({ x: px, z: pz, anim: 'Interact', dur: [2, 4], regard: r + Math.PI });
      if (n % 2) pose(prop(n % 4 === 1 ? 'Barrel' : 'Crate_Wooden'), x + fx * 3.3 + fz * 2.2, z + fz * 3.3 - fx * 2.2, n, 0.85); else pose(modele('Bench'), x + fx * 3.5 + fz * 2.1, z + fz * 3.5 - fx * 2.1, r + Math.PI / 2, 0.85);
      n++;
    }
  }
  // la place du marché : puits, 4 étals, feu, lanternes
  pose(modele('well_01'), cx, cz, 0, 1.3); blocs.push({ x: cx, z: cz, r: 1.5 });
  for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + Math.PI / 4, x = cx + Math.sin(a) * 6.5, z = cz + Math.cos(a) * 6.5, r = a + Math.PI; pose(modele('stall_01'), x, z, r, 1.15); blocs.push({ x, z, r: 1.1 }); spots.push({ x: x + Math.sin(r + Math.PI) * -1.9, z: z + Math.cos(r + Math.PI) * -1.9, anim: 'Idle_Talking_Loop', dur: [6, 14], regard: r + Math.PI }); spots.push({ x: x + Math.sin(r) * -1.1, z: z + Math.cos(r) * -1.1, anim: 'PickUp_Table', dur: [5, 10], regard: r }); }
  for (let k = 0; k < 4; k++) { const a = k * 1.57 + 0.2; spots.push({ x: cx + Math.sin(a) * 2.6, z: cz + Math.cos(a) * 2.6, anim: 'Idle_Talking_Loop', dur: [8, 18], regard: a + Math.PI, place: true }); }
  for (const [x, z] of [[cx + 3.5, cz - 16], [cx - 3.5, cz - 16], [cx + 3.5, cz + 16], [cx - 3.5, cz + 16], [cx + 16, cz + 3.5], [cx - 16, cz - 3.5]]) { const g = new THREE.Group(), p0 = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.11, 2.6, 6), MAT_POTEAU); p0.position.y = 1.3; g.add(p0); const tq = prop('Torch_Metal'); tq.position.set(0, 1.7, -0.15); g.add(tq); pose(g, x, z, Math.atan2(cx - x, cz - z)); }
  { const x = cx - 10, z = cz + 10; pose(modele('fire_01'), x, z, 0, 1.2); Vg.feu = V(x, hauteur(x, z), z); spots.push({ x: x + 1.5, z, anim: 'Idle_Talking_Loop', dur: [8, 15], regard: -Math.PI / 2 }); }
  { const x = cx + 4.5, z = cz - H - 3; pose(modele('sign_inn_01'), x, z, 0, 1.2); }
  // champs hors les murs
  for (const s of [-1, 1]) { const x = cx + s * (H + 12), z = cz + 6; const g = champ(x, z, 0, 18, 9, true); brut.parent; spots.push({ x: x - s * 5, z: z - 4, anim: 'Farm_Harvest', dur: [10, 20], regard: s * Math.PI / 2 }); Vg.champs ||= []; Vg.champs.push(g); }
  const g = new THREE.Group(); fusionner(brut, g); for (const c of Vg.champs) g.add(c); G.scene.add(g); Vg.g = g; Vg.spots = spots; Vg.portes = portes;
}
const HE = 3.12;
const MAT_PIERRE = new THREE.MeshStandardMaterial({ color: '#9a9488', roughness: 0.95, flatShading: true }), MAT_TOIT = new THREE.MeshStandardMaterial({ color: '#8a3a2a', roughness: 0.9, flatShading: true });
export async function chargerValcourt() {}

// ---------------- Les habitants ----------------
class Villageois {
  constructor(Vg, x, z, { garde = false, visiteur = false } = {}) {
    this.v = Vg; this.garde = garde;
    this.m = new Perso({ sexe: Math.random() < 0.5 ? 'h' : 'f', tenue: garde ? 'rodeur' : 'paysan', cheveux: Math.floor(rnd(0, 3)), couleurTenue: garde ? '#5a7ab8' : pick(TENUES) });
    if (garde) this.m.tenir(epee(), 'hand_r');
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
  C = ctx;
  for (const Vg of VILLAGES) {
    construire(Vg);
    const n = Vg.type === 'ville' ? 16 : 8; for (let i = 0; i < n; i++) { const s = pick(Vg.spots); new Villageois(Vg, s.x + rnd(-1, 1), s.z + rnd(-1, 1)); }
    if (Vg.type === 'ville') for (const sx of [-1, 1]) { const g = new Villageois(Vg, Vg.x + sx * 2.6, Vg.z - 32.5, { garde: true }); g.regard = Math.PI; g.m.root.rotation.y = Math.PI; } // deux gardes devant la porte nord
  }
}
let lent = 0;
export function majHumains(dt) {
  for (const Vg of VILLAGES) if (Vg.feu && dist(Vg.feu, G.camera.position) < 60 && Math.random() < dt * 30) emettre(tmp(Vg.feu.x + rnd(-0.3, 0.3), Vg.feu.y + 0.4, Vg.feu.z + rnd(-0.3, 0.3)), { n: 1, c1: '#ffd27a', c2: '#ff3a0a', vit: 0.6, vie: 0.8, taille: 0.3, grav: -2.5 }); // le feu de la place crépite
  for (const h of habitants) { const c = G.camera.position, loin = (h.pos.x - c.x) ** 2 + (h.pos.z - c.z) ** 2 > 14400; if (!loin || h.etat === 'messager' || h.etat === 'visite') h.maj(dt); else if ((h.lent = (h.lent || 0) + dt) > 0.5) { h.maj(h.lent); h.lent = 0; } } // loin de la caméra : vie au ralenti
  if ((lent += dt) < 1) return; const d = lent; lent = 0;
  for (const Vg of VILLAGES) if (Vg.g) { const dc = dist(Vg, G.camera.position); Vg.g.visible = dc < 280; }
  if (inv) { inv.t -= d; if (inv.t <= 0) finAttaque(false); return; }
  if ((tInv -= d) <= 0) { tInv = rnd(420, 660); appelAide(); }
  if ((tVis -= d) <= 0) { tVis = rnd(150, 240); visite(); }
}
export const humainsDebug = { appelAide, visite };
