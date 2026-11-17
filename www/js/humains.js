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
function construire(Vg) {
  const brut = new THREE.Group(), cx = Vg.x, cz = Vg.z, ville = Vg.type === 'ville', spots = [], portes = [];
  const pose = (o, x, z, r = 0, e = 1) => { o.position.set(x, hauteur(x, z), z); o.rotation.y = r; o.scale.multiplyScalar(e); brut.add(o); return o; };
  // maisons en cercle autour de la place, portes tournées vers le centre
  const n = ville ? 10 : 5, R = ville ? Vg.r * 0.68 : Vg.r * 0.62;
  for (let i = 0; i < n; i++) {
    const a = i / n * 6.283 + (ville ? 0.31 : 0.6), x = cx + Math.sin(a) * R * (ville && i % 2 ? 1.25 : 1), z = cz + Math.cos(a) * R * (ville && i % 2 ? 1.25 : 1);
    if (Math.abs(Math.atan2(Math.sin(a - Vg.entree), Math.cos(a - Vg.entree))) < (ville ? 0.35 : 0.5)) continue; // on laisse l'entrée libre
    const r = Math.atan2(cx - x, cz - z), type = !ville && i === 2 ? 'scierie' : 'maison', niv = ville ? (i % 3 ? 2 : 3) : (i % 2 ? 1 : 2);
    pose(plan3D(type, niv), x, z, r); blocs.push({ x, z, r: type === 'scierie' ? 3.6 : 3.1 });
    const f = 3.4, px = x + Math.sin(r) * f, pz = z + Math.cos(r) * f; portes.push(V(px, 0, pz)); spots.push({ x: px, z: pz, anim: 'Interact', dur: [2, 4], regard: r + Math.PI });
    spots.push({ x: x + Math.sin(r + 1.2) * 3.6, z: z + Math.cos(r + 1.2) * 3.6, anim: pick(['Fixing_Kneeling', 'Farm_Harvest']), dur: [6, 12], regard: r + Math.PI });
  }
  // la place : puits, étals, feu, tonneaux
  pose(modele('well_01'), cx, cz, 0, 1.15); blocs.push({ x: cx, z: cz, r: 1.3 });
  for (let k = 0; k < 3; k++) { const a = k * 2.1 + 0.4; spots.push({ x: cx + Math.sin(a) * 2.4, z: cz + Math.cos(a) * 2.4, anim: 'Idle_Talking_Loop', dur: [8, 16], regard: a + Math.PI, place: true }); }
  const etals = ville ? 4 : 1; for (let k = 0; k < etals; k++) { const a = k / etals * 6.283 + 1, x = cx + Math.sin(a) * (ville ? 8 : 6), z = cz + Math.cos(a) * (ville ? 8 : 6), r = Math.atan2(cx - x, cz - z) + Math.PI; pose(modele('stall_01'), x, z, r, 1.1); spots.push({ x: x + Math.sin(r + Math.PI) * 1.7, z: z + Math.cos(r + Math.PI) * 1.7, anim: 'Idle_Talking_Loop', dur: [6, 14], regard: r }); spots.push({ x: x + Math.sin(r) * 1.1, z: z + Math.cos(r) * 1.1, anim: 'PickUp_Table', dur: [5, 10], regard: r + Math.PI }); }
  { const x = cx + Math.sin(Vg.entree + 2.4) * 5, z = cz + Math.cos(Vg.entree + 2.4) * 5; pose(modele('fire_01'), x, z); spots.push({ x: x + 1.4, z, anim: 'Idle_Talking_Loop', dur: [8, 15], regard: -Math.PI / 2 }); }
  pose(prop('Barrel'), cx + 3.2, cz - 2.5, 0.4); pose(prop('Crate_Wooden'), cx - 3.4, cz + 2.2, 0.8, 0.8);
  // la ville : une enceinte de pieux avec deux portes, et la bannière bleu et or de Valcourt
  if (ville) {
    for (let a = 0; a < 6.283; a += 2.1 / (Vg.r + 6)) { const d1 = Math.abs(Math.atan2(Math.sin(a - Vg.entree), Math.cos(a - Vg.entree))), d2 = Math.abs(Math.atan2(Math.sin(a - Vg.entree - Math.PI), Math.cos(a - Vg.entree - Math.PI))); if (d1 < 0.16 || d2 < 0.16) continue; const R2 = Vg.r + 6, x = cx + Math.sin(a) * R2, z = cz + Math.cos(a) * R2; pose(modele('Prop_WoodenFence_Single'), x, z, a + Math.PI / 2, 1.5); }
    for (const sx of [-1, 1]) { const a = Vg.entree + sx * 0.22, x = cx + Math.sin(a) * (Vg.r + 6), z = cz + Math.cos(a) * (Vg.r + 6), b = pose(prop('Banner_1'), x, z, a + Math.PI / 2, 1); b.position.y += 1.8; b.add(prop('Banner_1_Cloth')); }
  }
  const g = new THREE.Group(); fusionner(brut, g); G.scene.add(g); Vg.g = g; Vg.spots = spots; Vg.portes = portes;
}

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
    Vg.entree = Vg.id === 'valcourt' ? Math.atan2(158 - Vg.x, 128 - Vg.z) : Vg.id === 'saules' ? Math.atan2(-52 - Vg.x, -75 - Vg.z) : Math.atan2(88 - Vg.x, 66 - Vg.z);
    construire(Vg);
    const n = Vg.type === 'ville' ? 12 : 6; for (let i = 0; i < n; i++) { const s = pick(Vg.spots); new Villageois(Vg, s.x + rnd(-1, 1), s.z + rnd(-1, 1)); }
    if (Vg.type === 'ville') for (const sx of [-1, 1]) { const a = Vg.entree + sx * 0.12, R = Vg.r + 7.5, g = new Villageois(Vg, Vg.x + Math.sin(a) * R, Vg.z + Math.cos(a) * R, { garde: true }); g.regard = Vg.entree; g.m.root.rotation.y = Vg.entree; }
  }
}
let lent = 0;
export function majHumains(dt) {
  for (const h of habitants) { const c = G.camera.position, loin = (h.pos.x - c.x) ** 2 + (h.pos.z - c.z) ** 2 > 14400; if (!loin || h.etat === 'messager' || h.etat === 'visite') h.maj(dt); else if ((h.lent = (h.lent || 0) + dt) > 0.5) { h.maj(h.lent); h.lent = 0; } } // loin de la caméra : vie au ralenti
  if ((lent += dt) < 1) return; const d = lent; lent = 0;
  for (const Vg of VILLAGES) if (Vg.g) Vg.g.visible = dist(Vg, G.camera.position) < 260;
  if (inv) { inv.t -= d; if (inv.t <= 0) finAttaque(false); return; }
  if ((tInv -= d) <= 0) { tInv = rnd(420, 660); appelAide(); }
  if ((tVis -= d) <= 0) { tVis = rnd(150, 240); visite(); }
}
export const humainsDebug = { appelAide, visite };
