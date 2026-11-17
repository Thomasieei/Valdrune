// Combat : camps de monstres gardiens (zone rouge), héros avec attaque + 4 pouvoirs (Lame rapide, Télékinésie, Parade, ARISE),
// ombres de combat relevées sur les ennemis vaincus.
import { THREE, G, V, emettre, son, texteFlottant, projeter } from './moteur.js';
import { Monstre, Perso } from './persos.js';
import { modele } from './batiments.js';
import { hauteur } from './monde.js';

export const TYPES_M = {
  imp: { nom: 'Diablotin', h: 1.85, pv: 55, deg: 5, vit: 3.3, portee: 2.5, xp: 30, butin: { pierre: [6, 12] }, ech: 1.35, cadence: 2.1, attaque: ['Zombie_Scratch'], course: 'Jog_Fwd_Loop' },
  bandit: { nom: 'Pillard', h: 2.05, pv: 60, deg: 6, vit: 3.5, portee: 2.1, xp: 35, butin: { bois: [3, 6] }, ech: 1, cadence: 1.9, humain: true, attaque: ['Sword_Regular_A', 'Sword_Regular_B', 'Melee_Hook'], course: 'Jog_Fwd_Loop' },
  puglin: { nom: 'Puglin', h: 1.0, pv: 35, deg: 4, vit: 3.9, portee: 2.0, xp: 18, butin: { bois: [6, 12] }, ech: 1.55, cadence: 1.8, attaque: ['Punch_Jab', 'Punch_Cross'], course: 'Jog_Fwd_Loop' },
};
export const CAMPS = [
  { id: 'carriere', nom: 'Diablotins de la carrière', type: 'imp', centre: V(21, 0, -19), r: 10, niv: 1, retour: 300, postes: [[17.5, -14.5], [25.5, -15], [21.5, -24]] },
  { id: 'bandits', nom: 'Camp des pillards', type: 'bandit', centre: V(38, 0, 30), r: 12, niv: 2, retour: 420, decor: true,
    // une vraie scène : un guetteur, deux joueurs de cartes, un dormeur sous la tente, un qui mange près du feu
    membres: [
      { x: 31.5, z: 25.5, role: 'guet', regard: -2.3, sexe: 'h', cheveux: 2, couleur: '#c8a080' },
      { x: 38.9, z: 31.2, role: 'cartes', regard: -Math.PI / 2, sexe: 'h', cheveux: 0, couleur: '#c07a70' },
      { x: 37.1, z: 31.2, role: 'cartes', regard: Math.PI / 2, sexe: 'f', cheveux: 1, couleur: '#8a92b8' },
      { x: 43.2, z: 34.6, role: 'dort', regard: 0.4, sexe: 'h', cheveux: 1, couleur: '#a8a888' },
      { x: 35.2, z: 27.6, role: 'feu', regard: 0.9, sexe: 'f', cheveux: 0, couleur: '#b8889a' },
    ] },
  { id: 'clairiere', nom: 'Puglins de la clairière', type: 'puglin', centre: V(-34, 0, 30), r: 9, niv: 1, retour: 240, postes: [[-34, 26], [-30, 31], [-38, 33], [-33, 34], [-36, 29]] },
];
export const POUVOIRS = {
  lame: { nom: 'Lame rapide', cd: 9, effet: (n) => `Fond sur ${Math.min(4, 1 + n)} ennemis d'affilée · ${Math.round(180 + 15 * (n - 1))} % de dégâts`, },
  tele: { nom: 'Télékinésie', cd: 12, mana: 15, effet: (n) => `Soulève ${2 + n} ennemis ${(2.2 + 0.4 * n).toFixed(1)} s puis les écrase (${20 + 10 * n} dégâts)` },
  parade: { nom: 'Parade', cd: 0, effet: (n) => `Maintenir : −${Math.min(60, 15 + 5 * (n - 1))} % de dégâts · au bon moment : 0 dégât + contre-attaque ×3` },
  arise: { nom: 'ARISE', cd: 3, mana: 25, effet: (n) => `Relève un ennemi vaincu en ombre de combat · ${9 + n} % de réussite` },
};
let C = null; // contexte fourni par main : { J, joueur, jeu, toast, sauver, majQuete, majHud }
const ennemis = [], allies = [], camps = {};
export const heros = { action: null, parade: null, cds: { lame: 0, tele: 0, parade: 0, arise: 0, dash: 0 }, combo: 0, comboT: 0, mortT: 0, horsCombat: 0 };
const teinteAllie = (d) => { d.color.set('#1a1226'); d.emissive = new THREE.Color('#5a1aff'); d.emissiveIntensity = 0.45; d.map = null; };
const teinteAllieP = function teinteAllieP(d) { if (/eye/i.test(d.name || '')) { d.color.set('#c8a8ff'); d.emissive = new THREE.Color('#9a5aff'); d.emissiveIntensity = 2; d.map = null; return; } d.color.set('#1a1226'); d.emissive = new THREE.Color('#4a14a0'); d.emissiveIntensity = 0.4; };
function epee() { const g = new THREE.Group(), fer = new THREE.MeshStandardMaterial({ color: '#b8bcc8', metalness: 0.8, roughness: 0.3 }); const l = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.75, 0.012), fer); l.position.y = 0.5; const gd = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.04, 0.05), new THREE.MeshStandardMaterial({ color: '#4a3020' })); gd.position.y = 0.12; g.add(l, gd); g.rotation.set(Math.PI / 2, 0, 0); return g; }
// tout le camp se réveille : le guetteur crie, les joueurs lâchent leurs cartes, le dormeur se lève
function alerteCamp(c, cible) {
  c.alerte = true; const g = c.membres.find(m => m.role === 'guet' && m.vivant) || c.membres.find(m => m.vivant);
  if (g) { texteFlottant(V(g.pos.x, g.pos.y + 2.6, g.pos.z), 'Intrus !', 'alerte'); son('sov_onde', 0.4, 1.6, g.pos); }
  for (const m of c.membres) { if (!m.vivant || m.etat !== 'garde') continue; m.ronde = false;
    if (m.role === 'dort') { m.alerteD = true; m.role = 'dort'; Ennemi.prototype.alerte.call(Object.assign(m, {}), cible); continue; }
    m.etat = 'attendre'; m.cible = cible; m.reveil = m.role === 'guet' ? 0 : m.role === 'feu' ? 0.5 : 0.9; texteFlottant(V(m.pos.x, m.pos.y + 2.3, m.pos.z), '!', 'alerte'); m.m.jouer('Idle_Loop', { forcer: true, fondu: 0.4 }); }
}
// décor du camp des pillards : feu, tente, abri, table de cartes, tabourets, tonneaux, coffre du butin
function decorBandits(def) {
  const g = new THREE.Group(), pose = (o, x, z, r = 0, e = 1, y = 0) => { o.position.set(x - def.centre.x, hauteur(x, z) + y, z - def.centre.z); o.rotation.y = r; o.scale.setScalar(e); o.traverse(m => { if (m.isMesh) { m.castShadow = m.receiveShadow = true; } }); g.add(o); return o; };
  g.position.set(def.centre.x, 0, def.centre.z);
  pose(modele('fire_01'), 35.9, 26.4, 0, 1);
  const feu = new THREE.PointLight('#ff9a4a', 6, 9, 1.6); feu.position.set(35.9 - def.centre.x, hauteur(35.9, 26.4) + 1, 26.4 - def.centre.z); g.add(feu); def._feu = feu;
  pose(modele('stall_01'), 30.5, 33.5, 0.9, 1.2);
  // tente de toile (deux pans + mât)
  const toile = new THREE.MeshStandardMaterial({ color: '#c8b48a', roughness: 0.95, flatShading: true }), tente = new THREE.Group();
  const corps = new THREE.Mesh(new THREE.CylinderGeometry(1.35, 1.35, 3, 3, 1, true), toile); corps.rotation.set(-Math.PI / 2, 0, 0); corps.position.y = 0.675; tente.add(corps); // prisme triangulaire : une vraie tente en A
  const fond = new THREE.Mesh(new THREE.CircleGeometry(1.35, 3), new THREE.MeshStandardMaterial({ color: '#8a7454', roughness: 1, flatShading: true })); fond.rotation.z = Math.PI / 2; fond.position.set(0, 0.675, -1.5); tente.add(fond);
  const porte = new THREE.Mesh(new THREE.CircleGeometry(0.75, 3), new THREE.MeshBasicMaterial({ color: '#1a120a' })); porte.rotation.z = Math.PI / 2; porte.position.set(0, 0.38, 1.49); tente.add(porte);
  for (const z of [-1.52, 1.52]) { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 2.3, 6), new THREE.MeshStandardMaterial({ color: '#5a3a20' })); m.position.set(0, 1.15, z); tente.add(m); }
  const sol = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 3).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ color: '#6a5a40', roughness: 1 })); sol.position.y = 0.02; tente.add(sol);
  pose(tente, 43.4, 34.2, 0.4);
  pose(modele('Table_Small'), 38, 31.2, Math.PI / 2, 0.42);
  pose(modele('Stool_round'), 39.2, 31.2, 0, 0.9); pose(modele('Stool_round'), 36.8, 31.2, 0, 0.9);
  const cm = new THREE.MeshStandardMaterial({ color: '#f4eee0' }), cr = new THREE.MeshStandardMaterial({ color: '#c03040' });
  for (let i = 0; i < 7; i++) { const c = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.005, 0.13), i % 3 ? cm : cr); c.position.set(38 - def.centre.x + rnd(-0.35, 0.35), hauteur(38, 31.2) + 0.37, 31.2 - def.centre.z + rnd(-0.2, 0.2)); c.rotation.y = rnd(0, 3); g.add(c); }
  pose(modele('Barrel_Closed'), 32, 31.5, 0, 0.9); pose(modele('Barrel_Closed'), 32.6, 32.4, 1, 0.8); pose(modele('Prop_Crate'), 41.5, 27.5, 0.3, 0.7);
  // coffre du butin : s'ouvre quand le camp est vaincu
  const coffre = pose(modele('Chest'), 41.5, 30, -1.2, 1.1), piv = new THREE.Group(); piv.position.set(0, 0.47, -0.28); const lid = modele('Chest_Lid'); lid.position.set(0, 0, 0.28); piv.add(lid); coffre.add(piv); def._couvercle = piv; def._coffre = coffre;
  G.scene.add(g);
}
// ---------------- utilitaires ----------------
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const rnd = (a, b) => a + Math.random() * (b - a);
export const xpHeros = (n) => Math.round(60 * Math.pow(n, 1.4));
export const pvMaxHeros = () => 100 + 15 * ((C.J.heros.niv || 1) - 1);
const degHeros = () => 14 + 3 * ((C.J.heros.niv || 1) - 1);
const nivP = (k) => C.J.heros.pw[k] || 1;
// ---------------- zone rouge au sol ----------------
function zone(c) {
  const g = new THREE.Group(), y = hauteur(c.centre.x, c.centre.z) + 0.07;
  const mat = new THREE.MeshBasicMaterial({ color: '#ff2a3a', transparent: true, opacity: 0.5, depthWrite: false });
  const bord = new THREE.Mesh(new THREE.RingGeometry(c.r - 0.25, c.r, 64).rotateX(-Math.PI / 2), mat);
  const fond = new THREE.Mesh(new THREE.CircleGeometry(c.r - 0.25, 64).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#ff2a3a', transparent: true, opacity: 0.07, depthWrite: false }));
  for (const m of [bord, fond]) { const P = m.geometry.attributes.position; for (let i = 0; i < P.count; i++) P.setY(i, hauteur(c.centre.x + P.getX(i), c.centre.z + P.getZ(i)) + 0.09 - y + 0.07); P.needsUpdate = true; } // la zone épouse le relief : visible partout
  mat.opacity = 0.7; g.add(bord, fond); g.position.set(c.centre.x, y - 0.07, c.centre.z); G.scene.add(g); return { g, mat };
}
// ---------------- Ennemis (et alliés : même corps, autre camp) ----------------
class Ennemi {
  constructor(type, pos, opts = {}) {
    const { allie = false, niv = 1, camp = null } = opts;
    const T = TYPES_M[type]; this.T = T; this.type = type; this.niv = niv; this.allie = allie; this.camp = camp;
    this.m = T.humain ? new Perso({ sexe: opts.sexe || 'h', tenue: 'rodeur', cheveux: opts.cheveux ?? 0, couleurTenue: allie ? null : opts.couleur || '#6a3a3a', teinte: allie ? teinteAllieP : null }) : new Monstre(type, { teinte: allie ? teinteAllie : null, echelle: T.ech });
    if (T.humain) this.m.tenir(epee(), 'hand_r');
    this.role = opts.role || null; this.regard = opts.regard ?? null; this.reveil = 0;
    this.m.root.position.set(pos.x, hauteur(pos.x, pos.z), pos.z); this.m.root.rotation.y = rnd(0, 6.28);
    this.poste = this.m.root.position.clone(); G.scene.add(this.m.root);
    this.pvMax = Math.round(T.pv * (1 + 0.25 * (niv - 1))); this.pv = this.pvMax; this.deg = T.deg * (1 + 0.2 * (niv - 1));
    this.etat = 'garde'; this.t = rnd(1, 5); this.cible = null; this.cd = rnd(0.3, 1); this.lev = null; this.etourdi = 0; this.vu = 0;
    this.m.jouer('Idle_Loop', { vitesse: rnd(0.85, 1.1) }); if (this.regard != null) this.m.root.rotation.y = this.regard;
    if (this.role) this.poser();
    (allie ? allies : ennemis).push(this);
  }
  get pos() { return this.m.root.position; }
  get vivant() { return this.pv > 0; }
  tourner(a, dt) { let da = a - this.m.root.rotation.y; da = Math.atan2(Math.sin(da), Math.cos(da)); this.m.root.rotation.y += da * Math.min(1, dt * 10); }
  marcher(dest, dt, vit, anim) {
    const dx = dest.x - this.pos.x, dz = dest.z - this.pos.z, d = Math.hypot(dx, dz); if (d < 0.2) return true;
    let vx = dx / d, vz = dz / d;
    for (const o of this.allie ? allies : ennemis) if (o !== this && o.vivant) { const ox = this.pos.x - o.pos.x, oz = this.pos.z - o.pos.z, od = Math.hypot(ox, oz); if (od < 1.2 && od > 0.01) { vx += ox / od * 0.8; vz += oz / od * 0.8; } } // ne pas s'empiler
    const l = Math.hypot(vx, vz) || 1, pas = Math.min(d, vit * dt); this.pos.x += vx / l * pas; this.pos.z += vz / l * pas; this.pos.y = hauteur(this.pos.x, this.pos.z);
    this.tourner(Math.atan2(vx, vz), dt); this.m.jouer(anim, { vitesse: anim === 'Walk_Loop' ? vit / 1.6 : vit / 3.6 }); return false;
  }
  subir(n, src, { recul = 0.5, crit = false } = {}) {
    if (!this.vivant) return;
    if (this.lev) n *= 1.5; // soulevé = sans défense
    if (src && src.isHeros) { G.ralenti = 0.06; G.ralentiT = crit ? 0.09 : 0.05; } // micro-arrêt à l'impact : on sent le coup
    this.pv -= n; this.vu = 4; if (this.etat === 'garde') this.alerte(src && src.isHeros ? 'heros' : src);
    texteFlottant(V(this.pos.x, this.pos.y + 2.2, this.pos.z), `${crit ? '💥' : ''}${Math.round(n)}`, crit ? 'crit' : 'degat');
    emettre(V(this.pos.x, this.pos.y + 1.1, this.pos.z), { n: crit ? 22 : 10, c1: this.allie ? '#c8a8ff' : '#ff6a5a', c2: '#3a0a10', vit: 3.5, vie: 0.5, taille: 0.16, grav: 7 });
    son(crit ? 'impactPunch_medium_001' : 'impactPunch_medium_000', 0.45, rnd(0.9, 1.15), this.pos);
    if (src && recul && !this.lev) { const a = Math.atan2(this.pos.x - src.pos.x, this.pos.z - src.pos.z); this.kb = { x: Math.sin(a) * recul * 7, z: Math.cos(a) * recul * 7 }; }
    if (this.pv <= 0) return this.mourir(src);
    if (!this.lev && (this.etat !== 'attaque' || crit)) { if (this.etat === 'attaque') { this.etat = 'poursuite'; finTelegraphe(this); this.cd = 0.6; } this.m.jouer(crit ? 'Hit_Knockback' : Math.random() < 0.5 ? 'Hit_Chest' : 'Hit_Head', { boucle: false, forcer: true, vitesse: crit ? 1.2 : 1.5 }); this.etourdi = Math.max(this.etourdi, crit ? 0.7 : 0.35); }
  }
  poser() { // la pose de son rôle dans la scène du camp
    const r = this.role;
    if (r === 'cartes') this.m.jouer('Sitting_Idle_Loop', { forcer: true });
    else if (r === 'dort') { const a = this.m.jouer('LayToIdle', { boucle: false, forcer: true }); if (a) { a.time = 0; a.paused = true; } }
    else if (r === 'feu') this.m.jouer('Consume', { forcer: true, vitesse: 0.7 });
    else if (r === 'guet') this.m.jouer('Idle_FoldArms_Loop', { forcer: true });
  }
  alerte(cible) {
    if (this.role && camps[this.camp] && !camps[this.camp].alerte) return alerteCamp(camps[this.camp], cible);
    if (this.role === 'dort' && this.etat === 'garde') { const a = this.actions && this.m.actions.LayToIdle; this.m.jouer('LayToIdle', { boucle: false, forcer: true, vitesse: 1.3 }); this.etat = 'reveil'; this.reveil = this.m.duree('LayToIdle') / 1.3; this.cibleA = cible; this.role = 'feu'; return; }
    this.etat = 'poursuite'; this.cible = cible; texteFlottant(V(this.pos.x, this.pos.y + 2.4, this.pos.z), '!', 'alerte'); }
  mourir(src) {
    this.pv = 0; this.etat = 'mort'; this.lev = null; finTelegraphe(this); this.corpsT = 40; this.m.jouer('Death01', { boucle: false, forcer: true }); son('impactSoft_heavy_000', 0.5, 0.8, this.pos);
    if (this.allie) { this.corpsT = 2; this.reforme = 40; texteFlottant(V(this.pos.x, this.pos.y + 2, this.pos.z), 'Dissipée… revient dans 40 s', 'info'); return; }
    // butin et expérience
    const gain = []; for (const [r, [a, b]] of Object.entries(this.T.butin)) { const n = Math.round(rnd(a, b) * (1 + 0.3 * (this.niv - 1))); C.jeu.ajouter(r, n, this.pos); gain.push(n); }
    gagnerXp(Math.round(this.T.xp * (1 + 0.3 * (this.niv - 1))), this.pos);
    if (this.camp) verifierCamp(this.camp);
  }
  maj(dt) {
    this.m.maj(dt); if (this.vu > 0) this.vu -= dt;
    if (this.kb) { this.pos.x += this.kb.x * dt; this.pos.z += this.kb.z * dt; this.pos.y = this.lev ? this.pos.y : hauteur(this.pos.x, this.pos.z); const k = Math.exp(-dt * 9); this.kb.x *= k; this.kb.z *= k; if (Math.abs(this.kb.x) + Math.abs(this.kb.z) < 0.05) this.kb = null; }
    if (this.etat === 'mort') {
      this.corpsT -= dt;
      if (this.corpsT < 1.5) { this.m.root.position.y -= dt * 0.6; } // le corps s'enfonce puis disparaît
      if (this.corpsT <= 0 && this.m.root.parent) { G.scene.remove(this.m.root); if (this.allie && this.reforme == null) { /* rien */ } }
      if (this.allie && this.reforme != null) { this.reforme -= dt; if (this.reforme <= 0) this.revenir(); }
      return;
    }
    if (this.lev) return this.majLev(dt);
    if (this.etourdi > 0) { this.etourdi -= dt; return; }
    if (this.cd > 0) this.cd -= dt;
    return this.allie ? this.majAllie(dt) : this.majEnnemi(dt);
  }
  majLev(dt) { // soulevé par la télékinésie : il flotte, se débat, puis retombe lourdement
    const L = this.lev; L.t += dt; const sol = hauteur(this.pos.x, this.pos.z);
    if (L.t < 0.45) { const k = L.t / 0.45; this.pos.y = sol + L.h * (1 - (1 - k) * (1 - k)); }
    else if (L.t < L.dur) { this.pos.y = sol + L.h + Math.sin(L.t * 5) * 0.15; this.m.root.rotation.y += dt * 1.5; if (Math.random() < dt * 14) emettre(V(this.pos.x, this.pos.y + 0.8, this.pos.z), { n: 1, c1: '#c8a8ff', c2: '#5a1aff', vit: 0.6, vie: 0.7, taille: 0.22, grav: -0.5 }); }
    else { L.vy = (L.vy || 0) + dt * 60; this.pos.y = Math.max(sol, this.pos.y - L.vy * dt); if (this.pos.y <= sol + 0.01) { this.lev = null; G.shake = Math.max(G.shake, 0.55); onde(this.pos, { r: 3.5, couleur: '#e8d8ff' }); { const a = Math.atan2(this.pos.x - L.src.x, this.pos.z - L.src.z); this.kb = { x: Math.sin(a) * 9, z: Math.cos(a) * 9 }; } emettre(V(this.pos.x, sol + 0.2, this.pos.z), { n: 40, c1: '#d8c8a8', c2: '#6a5a4a', vit: 5, vie: 0.7, taille: 0.3, grav: 6 }); son('impactSoft_heavy_000', 0.7, 0.6, this.pos); this.subir(L.deg, { pos: L.src, isHeros: true }, { recul: 0, crit: true }); if (this.vivant) this.etourdi = 0.8; } }
    if (this.m.anim !== 'Hit_Knockback') this.m.jouer('Hit_Knockback', { vitesse: 0.5 });
  }
  majEnnemi(dt) {
    const c = camps[this.camp], J = C.joueur, enZone = (p) => dist(p, c.def.centre) < c.def.r;
    // cibles possibles : le héros ou une ombre de combat qui entre dans la zone rouge
    if (this.etat === 'garde' || this.etat === 'flane') {
      this.t -= dt;
      if (this.role) { // scène du camp : seul le guetteur surveille vraiment, les autres ne voient que de près
        const portee = this.role === 'guet' ? 9 : this.role === 'dort' ? 2 : 4;
        if (!heros.mortT && dist(J.pos, this.pos) < portee) { this.alerte('heros'); return; }
        const al = allies.find(a => a.vivant && dist(a.pos, this.pos) < portee); if (al) { this.alerte(al); return; }
        if (this.role === 'guet') { this.t -= dt; if (this.t <= 0) { this.t = rnd(5, 9); this.but = V(this.poste.x + rnd(-3, 3), 0, this.poste.z + rnd(-3, 3)); this.ronde = true; } if (this.ronde) { if (this.marcher(this.but, dt, 1.3, 'Walk_Loop')) { this.ronde = false; this.m.jouer('Idle_FoldArms_Loop'); } } else this.tourner(this.regard + Math.sin(G.t * 0.4 + this.poste.x) * 0.9, dt * 0.3); }
        if (this.role === 'dort' && Math.random() < dt * 0.4) texteFlottant(V(this.pos.x, this.pos.y + 0.8, this.pos.z), 'z', 'info');
        return;
      }
      if (!heros.mortT && enZone(J.pos)) { this.alerte('heros'); return; }
      const al = allies.find(a => a.vivant && enZone(a.pos)); if (al) { this.alerte(al); return; }
      if (this.etat === 'garde') { this.m.jouer('Idle_Loop'); if (this.t <= 0) { this.etat = 'flane'; this.but = V(this.poste.x + rnd(-2.5, 2.5), 0, this.poste.z + rnd(-2.5, 2.5)); } }
      else if (this.marcher(this.but, dt, 1.4, 'Walk_Loop')) { this.etat = 'garde'; this.t = rnd(3, 8); }
      return;
    }
    if (this.etat === 'reveil') { this.reveil -= dt; if (this.reveil <= 0) { this.etat = 'poursuite'; this.cible = this.cibleA; } return; }
    if (this.etat === 'attendre') { this.reveil -= dt; if (this.reveil <= 0) { this.etat = 'poursuite'; } return; }
    if (this.etat === 'retour') { if (this.marcher(this.poste, dt, this.T.vit, 'Jog_Fwd_Loop')) { this.etat = 'garde'; this.t = rnd(2, 5); if (this.role) { if (this.regard != null) this.m.root.rotation.y = this.regard; this.poser(); } if (c.alerte && c.membres.every(m => !m.vivant || m.etat === 'garde')) c.alerte = false; } this.pv = Math.min(this.pvMax, this.pv + dt * this.pvMax * 0.25); return; }
    const cib = this.cible === 'heros' ? (heros.mortT ? null : { pos: J.pos, heros: true }) : (this.cible && this.cible.vivant ? this.cible : null);
    if (!cib || dist(cib.pos, c.def.centre) > c.def.r + 7) { this.etat = 'retour'; this.cible = null; return; }
    const d = dist(cib.pos, this.pos);
    if (this.etat === 'attaque') { // préparation visible (cercle rouge), puis le coup
      this.tourner(Math.atan2(cib.pos.x - this.pos.x, cib.pos.z - this.pos.z), dt); this.at -= dt; majTelegraphe(this);
      if (this.at <= 0) { finTelegraphe(this); this.etat = 'poursuite'; this.cd = this.T.cadence; if (d < this.T.portee + 0.5) { if (cib.heros) subirHeros(this.deg, this); else cib.subir(this.deg, this); } }
      return;
    }
    if (d > this.T.portee) { this.marcher(cib.pos, dt, this.T.vit, this.T.course || 'Jog_Fwd_Loop'); return; }
    this.tourner(Math.atan2(cib.pos.x - this.pos.x, cib.pos.z - this.pos.z), dt);
    if (this.cd <= 0) { this.etat = 'attaque'; this.at = 0.75; const A = this.T.attaque || ['Sword_Attack'], an = A[Math.floor(Math.random() * A.length)]; this.m.jouer(an, { boucle: false, forcer: true, vitesse: this.m.duree(an) * 0.55 / 0.75 }); debutTelegraphe(this); son('knifeSlice', 0.3, 0.7, this.pos); }
    else this.m.jouer(this.T.humain ? 'Sword_Idle' : 'Idle_Loop'); /* entre deux coups il tourne autour de toi */ if (this.cd > 0.3 && !this.T.humain) { const a = Math.atan2(this.pos.x - cib.pos.x, this.pos.z - cib.pos.z) + dt * 0.5 * (this.niv % 2 ? 1 : -1); this.pos.x = cib.pos.x + Math.sin(a) * d; this.pos.z = cib.pos.z + Math.cos(a) * d; }
  }
  majAllie(dt) { // ombre de combat : suit le héros, se jette sur l'ennemi le plus proche
    const J = C.joueur;
    let e = this.cible && this.cible.vivant && dist(this.cible.pos, J.pos) < 18 ? this.cible : null;
    if (!e) { let bd = 12; for (const x of ennemis) if (x.vivant && !x.lev && (x.etat !== 'garde' && x.etat !== 'flane' || dist(x.pos, J.pos) < 8)) { const d = dist(x.pos, this.pos); if (d < bd) { bd = d; e = x; } } this.cible = e; }
    if (e) {
      const d = dist(e.pos, this.pos);
      if (this.etat === 'attaque') { this.at -= dt; this.tourner(Math.atan2(e.pos.x - this.pos.x, e.pos.z - this.pos.z), dt); if (this.at <= 0) { this.etat = 'suit'; this.cd = this.T.cadence * 0.9; if (d < this.T.portee + 0.6) e.subir(this.deg, this, { recul: 0.3 }); } return; }
      if (d > this.T.portee) { this.marcher(e.pos, dt, this.T.vit * 1.1, 'Jog_Fwd_Loop'); return; }
      if (this.cd <= 0) { this.etat = 'attaque'; this.at = 0.45; this.m.jouer('Sword_Attack', { boucle: false, forcer: true, vitesse: 1.4 }); } else this.m.jouer('Sword_Idle');
      if (e.etat === 'garde' || e.etat === 'flane') e.alerte(this);
      return;
    }
    const k = allies.indexOf(this), ang = J.perso.root.rotation.y + Math.PI + (k % 2 ? 1 : -1) * (0.7 + Math.floor(k / 2) * 0.35), dd = 2.4 + Math.floor(k / 2) * 0.9;
    const dest = V(J.pos.x + Math.sin(ang) * dd, 0, J.pos.z + Math.cos(ang) * dd), d = dist(dest, this.pos);
    if (d > 25) { this.pos.set(dest.x, hauteur(dest.x, dest.z), dest.z); return; }
    if (d > 0.5) this.marcher(dest, dt, d > 4 ? this.T.vit * 1.3 : 2.2, d > 4 ? 'Jog_Fwd_Loop' : 'Walk_Loop'); else { this.m.jouer('Idle_Loop'); this.tourner(J.perso.root.rotation.y, dt); }
    if (Math.random() < dt * 4) emettre(V(this.pos.x + rnd(-0.3, 0.3), this.pos.y + 0.2, this.pos.z + rnd(-0.3, 0.3)), { n: 1, c1: '#8a5aff', c2: '#1a0a30', vit: 0.3, vie: 0.8, taille: 0.22, grav: -1.2 });
  }
  revenir() { // une ombre ne meurt pas vraiment : elle se reforme près du souverain
    const J = C.joueur; this.reforme = null; this.pv = this.pvMax; this.etat = 'suit'; this.cible = null;
    this.pos.set(J.pos.x + rnd(-2, 2), hauteur(J.pos.x, J.pos.z), J.pos.z + rnd(-2, 2)); if (!this.m.root.parent) G.scene.add(this.m.root);
    this.m.jouer('Idle_Loop', { forcer: true }); emettre(V(this.pos.x, this.pos.y + 1, this.pos.z), { n: 40, c1: '#c8a8ff', c2: '#2a0a5a', vit: 2.5, vie: 1, taille: 0.3, grav: -2 });
  }
}
// cercle rouge qui se remplit : le joueur voit le coup arriver et peut parer au bon moment
const telM = new THREE.MeshBasicMaterial({ color: '#ff3040', transparent: true, opacity: 0.45, depthWrite: false });
// zone d'impact en éventail : le contour montre la portée, le remplissage montre quand le coup tombe (blanc = maintenant, PARE !)
function debutTelegraphe(e) {
  const r = e.T.portee + 0.4, g = new THREE.Group(), bord = new THREE.Mesh(new THREE.RingGeometry(r - 0.12, r, 24, 1, -Math.PI / 2 - 0.9, 1.8).rotateX(-Math.PI / 2), telM.clone()), fond = new THREE.Mesh(new THREE.CircleGeometry(r, 24, -Math.PI / 2 - 0.9, 1.8).rotateX(-Math.PI / 2), telM.clone());
  bord.material.opacity = 0.8; g.add(bord, fond); g.userData.fond = fond; G.scene.add(g); e.tel = g; e.atMax = e.at; majTelegraphe(e);
}
function majTelegraphe(e) { if (!e.tel) return; const k = 1 - e.at / e.atMax, f = e.tel.userData.fond; e.tel.position.set(e.pos.x, e.pos.y + 0.1, e.pos.z); e.tel.rotation.y = e.m.root.rotation.y; f.scale.setScalar(Math.max(0.05, k)); const blanc = e.at < 0.3; f.material.color.set(blanc ? '#ffffff' : '#ff3040'); f.material.opacity = blanc ? 0.75 : 0.3 + 0.25 * k; }
function finTelegraphe(e) { if (e.tel) { G.scene.remove(e.tel); e.tel = null; } }
// ---------------- Camps ----------------
function creerCamp(def) {
  const c = camps[def.id] = { def, membres: [], zone: zone(def), mortT: 0 }; if (def.decor) decorBandits(def);
  const fin = (C.J.camps || {})[def.id] || 0, reste = (fin - Date.now()) / 1000;
  if (reste > 0) { c.mortT = reste; c.zone.g.visible = false; return; }
  peupler(c);
}
function peupler(c) { c.alerte = false; c.membres = c.def.membres ? c.def.membres.map(m => new Ennemi(c.def.type, V(m.x, 0, m.z), { ...m, niv: c.def.niv, camp: c.def.id })) : c.def.postes.map(([x, z]) => new Ennemi(c.def.type, V(x, 0, z), { niv: c.def.niv, camp: c.def.id })); c.zone.g.visible = true; c.mortT = 0; if (c.def._couvercle) { c.def._couvercle.rotation.x = 0; c.ouvert = false; } }
function verifierCamp(id) {
  const c = camps[id]; if (c.membres.some(m => m.vivant)) return;
  c.mortT = c.def.retour; (C.J.camps ||= {})[id] = Date.now() + c.def.retour * 1000; C.sauver();
  son('jingles_PIZZI03', 0.6); C.toast(`🏆 ${c.def.nom} : zone libérée !`); C.majQuete();
  if (c.def._couvercle) { // le coffre des pillards s'ouvre : gros butin
    const lid = c.def._couvercle, p = c.def._coffre.getWorldPosition(V()); let t = 0; const iv = setInterval(() => { t += 0.05; lid.rotation.x = -Math.min(1.9, t * 3); if (t > 0.7) clearInterval(iv); }, 50);
    son('handleCoins2', 0.7); emettre(V(p.x, p.y + 0.8, p.z), { n: 80, c1: '#ffe9a0', c2: '#c8902a', vit: 4, vie: 1.2, taille: 0.22, grav: 4 });
    setTimeout(() => { C.jeu.ajouter('bois', 60, p); C.jeu.ajouter('pierre', 40, V(p.x + 0.5, p.y, p.z)); }, 600);
  }
  setTimeout(() => { c.zone.g.visible = false; }, 1500);
}
export const campLibre = (id) => !!camps[id] && camps[id].mortT > 0;
export function zoneDangereuse(p) { for (const c of Object.values(camps)) if (!c.mortT && dist(p, c.def.centre) < c.def.r + 1) return c; return null; }
// ---------------- Héros ----------------
function gagnerXp(n, pos) {
  const h = C.J.heros; h.xp += n; texteFlottant(V(pos.x, pos.y + 2.8, pos.z), `+${n} XP`, 'xp');
  while (h.xp >= xpHeros(h.niv)) { h.xp -= xpHeros(h.niv); h.niv++; h.pts = (h.pts || 0) + 1; C.joueur.pv = pvMaxHeros(); son('jingles_PIZZI01', 0.6); C.toast(`⭐ Niveau ${h.niv} ! +1 point de pouvoir (touche ton portrait)`); emettre(V(C.joueur.pos.x, C.joueur.pos.y + 1, C.joueur.pos.z), { n: 60, c1: '#ffe9a0', c2: '#b36bff', vit: 4, vie: 1.1, taille: 0.25, grav: -1 }); }
  C.majHud(); C.sauver();
}
export function subirHeros(n, src) {
  const J = C.joueur; if (heros.mortT || (heros.action && heros.action.invul)) return;
  heros.horsCombat = 0;
  if (heros.parade) {
    const fen = 0.4 + 0.03 * (nivP('parade') - 1);
    if (G.t - heros.parade.debut < fen && !heros.parade.utilisee) return parfaite(src);
    n *= 1 - Math.min(0.6, 0.15 + 0.05 * (nivP('parade') - 1)); emettre(V(J.pos.x, J.pos.y + 1.2, J.pos.z), { n: 10, c1: '#c8a8ff', c2: '#5a1aff', vit: 3, vie: 0.4, taille: 0.15, grav: 2 }); son('impactMetal_light_000', 0.6, 0.8, J.pos);
  }
  J.pv -= n; G.shake = Math.max(G.shake, 0.3); texteFlottant(V(J.pos.x, J.pos.y + 2.2, J.pos.z), `-${Math.round(n)}`, 'mal');
  document.body.classList.remove('touche'); void document.body.offsetWidth; document.body.classList.add('touche');
  if (!heros.action && !heros.parade) J.perso.jouer('Hit_Chest', { boucle: false, forcer: true, vitesse: 1.5 });
  if (J.pv <= 0) { J.pv = 0; heros.mortT = 4; heros.action = null; heros.parade = null; J.perso.jouer('Death01', { boucle: false, forcer: true }); C.toast('💀 Tu es tombé… tu te relèves au camp'); }
  C.majHud();
}
function parfaite(src) { // parade parfaite : aucun dégât, le temps ralentit, le héros passe derrière et frappe fort
  const J = C.joueur; heros.parade.utilisee = true; G.ralenti = 0.25; G.ralentiT = 0.45;
  texteFlottant(V(J.pos.x, J.pos.y + 2.4, J.pos.z), 'PARADE !', 'parade'); son('impactMetal_light_000', 0.9, 1.4, J.pos); emettre(V(J.pos.x, J.pos.y + 1.2, J.pos.z), { n: 40, c1: '#ffffff', c2: '#b36bff', vit: 5, vie: 0.5, taille: 0.2, grav: 0 });
  if (src && src.vivant) { const a = src.m.root.rotation.y; J.pos.set(src.pos.x - Math.sin(a) * 1.3, J.pos.y, src.pos.z - Math.cos(a) * 1.3); J.perso.root.rotation.y = a; heros.action = { k: 'coup', t: 0, dur: 0.5, frappe: 0.15, cibles: [src], mult: 3, crit: true, invul: true, anim: 'Sword_Regular_C' }; J.perso.jouer('Sword_Regular_C', { boucle: false, forcer: true, vitesse: 1.8 }); src.etourdi = 1.2; }
}
const plusProches = (p, r, n) => ennemis.filter(e => e.vivant && dist(e.pos, p) < r).sort((a, b) => dist(a.pos, p) - dist(b.pos, p)).slice(0, n);
export function attaquer() {
  const J = C.joueur; if (heros.mortT || heros.action || G.mode === 'souverain') return;
  const e = plusProches(J.pos, 5, 1)[0]; if (e) J.perso.root.rotation.y = Math.atan2(e.pos.x - J.pos.x, e.pos.z - J.pos.z);
  const elan = e ? Math.max(0.4, Math.min(2.6, dist(e.pos, J.pos) - 1.5)) : 0.5; // on fond vers la cible : le coup porte
  heros.combo = heros.comboT > 0 ? (heros.combo + 1) % 3 : 0; heros.comboT = 1.1;
  const anim = ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C'][heros.combo], dur = J.perso.duree(anim) / 1.6;
  heros.action = { k: 'coup', t: 0, dur: dur * 0.7, frappe: dur * 0.42, mult: heros.combo === 2 ? 1.6 : 1, anim, elan, coupe: true };
  J.perso.jouer(anim, { boucle: false, forcer: true, vitesse: 1.6 }); son('knifeSlice', 0.4, rnd(1, 1.2), J.pos);
}
export function dash() {
  const J = C.joueur; if (heros.mortT || G.mode === 'souverain' || heros.cds.dash > 0 || (heros.action && heros.action.k !== 'coup')) return;
  const v = J.vel && J.vel.length() > 0.5 ? Math.atan2(J.vel.x, J.vel.z) : J.perso.root.rotation.y;
  heros.parade = null; bouclier.visible = false; heros.action = { k: 'dash', t: 0, dur: 0.24, a: v, invul: true }; heros.cds.dash = 1.1;
  J.perso.root.rotation.y = v; J.perso.jouer('Sword_Dash', { boucle: false, forcer: true, vitesse: 2.6 }); son('sov_onde', 0.35, 2); G.shake = Math.max(G.shake, 0.08);
}
export function pouvoir(k, appui = true) {
  const J = C.joueur, P = POUVOIRS[k];
  if (k === 'parade') { if (appui && !heros.mortT && (!heros.action || heros.action.k === 'coup')) { heros.action = null; heros.parade = { debut: G.t }; J.perso.jouer('Sword_Block', { boucle: false, forcer: true, vitesse: 2 }); bouclier.visible = true; } else if (!appui) { heros.parade = null; bouclier.visible = false; if (!heros.action) J.perso.jouer('Idle_Loop', { forcer: true }); } document.getElementById('pw-parade').classList.toggle('garde', !!heros.parade); return; }
  if (!appui || heros.mortT || heros.action || G.mode === 'souverain') return;
  if (heros.cds[k] > 0) { son('error_004', 0.3); return; }
  if (P.mana && C.J.mana < P.mana) { C.toast(`Pas assez de mana (${P.mana})`); son('error_004', 0.4); return; }
  const n = nivP(k);
  if (k === 'lame') {
    const cibles = plusProches(J.pos, 11, Math.min(4, 1 + n)); if (!cibles.length) { C.toast('Aucun ennemi à portée'); return; }
    heros.action = { k: 'lame', cibles, i: 0, t: 0, invul: true, mult: 1.8 + 0.15 * (n - 1) }; heros.cds.lame = P.cd; son('sov_onde', 0.5, 1.4);
  } else if (k === 'tele') { // la main se lève, des chaînes violettes saisissent les ennemis, ils montent… puis s'écrasent et sont projetés
    const cibles = plusProches(J.pos, 13, 2 + n).filter(e => !e.lev); if (!cibles.length) { C.toast('Aucun ennemi à portée'); return; }
    C.J.mana -= P.mana; heros.cds.tele = P.cd; heros.action = { k: 'sort', t: 0, dur: 0.7 };
    J.perso.root.rotation.y = Math.atan2(cibles[0].pos.x - J.pos.x, cibles[0].pos.z - J.pos.z);
    J.perso.jouer('Spell_Simple_Shoot', { boucle: false, forcer: true, vitesse: 1.3 }); son('sov_possession', 0.6, 1.2); onde(J.pos, { r: 3, vie: 0.5 });
    for (const e of cibles) {
      e.lev = { t: 0, dur: 2.2 + 0.4 * n, h: 3.2, deg: 20 + 10 * n, src: J.pos.clone() }; e.kb = null; finTelegraphe(e); if (e.etat === 'attaque') e.etat = 'poursuite'; if (e.etat === 'garde' || e.etat === 'flane') e.alerte('heros');
      const pts = new THREE.BufferGeometry().setFromPoints([V(), V()]), ray = new THREE.Line(pts, new THREE.LineBasicMaterial({ color: '#d0b0ff', transparent: true, opacity: 1, blending: THREE.AdditiveBlending })); G.scene.add(ray);
      const aura = new THREE.Mesh(new THREE.RingGeometry(0.7, 1.05, 24).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#b98aff', transparent: true, opacity: 0.8, depthWrite: false, blending: THREE.AdditiveBlending })); G.scene.add(aura);
      const L = e.lev; fx.push({ o: ray, m: ray.material, t: 0, vie: L.dur, maj: (q) => { const main = J.perso.os.hand_r ? J.perso.os.hand_r.getWorldPosition(V()) : V(J.pos.x, J.pos.y + 1.5, J.pos.z), P2 = pts.attributes.position; P2.setXYZ(0, main.x, main.y, main.z); P2.setXYZ(1, e.pos.x, e.pos.y + 1, e.pos.z); P2.needsUpdate = true; if (q < 0.35) for (let i = 0; i < 3; i++) { const u = Math.random(); emettre(V(main.x + (e.pos.x - main.x) * u, main.y + (e.pos.y + 1 - main.y) * u, main.z + (e.pos.z - main.z) * u), { n: 1, c1: '#e0c8ff', c2: '#6a2aff', vit: 0.2, vie: 0.3, taille: 0.22, grav: 0 }); } /* chaîne d'énergie visible */ ray.material.opacity = q < 0.3 ? 1 : Math.max(0, 1 - (q - 0.3) * 4); aura.position.set(e.pos.x, hauteur(e.pos.x, e.pos.z) + 0.1, e.pos.z); aura.rotation.y += 0.08; aura.material.opacity = 0.8 * (1 - q); if (q >= 1) G.scene.remove(aura); } });
    }
  } else if (k === 'arise') {
    let corps = null, bd = 9; for (const e of ennemis) if (e.etat === 'mort' && e.corpsT > 2 && !e.leve) { const d = dist(e.pos, J.pos); if (d < bd) { bd = d; corps = e; } }
    if (!corps) { C.toast('Approche-toi d’un ennemi vaincu'); son('error_004', 0.3); return; }
    C.J.mana -= P.mana; heros.cds.arise = P.cd; corps.leve = true; arise(corps, n);
  }
  C.majHud();
}
function arise(corps, n) {
  const J = C.joueur; heros.action = { k: 'sort', t: 0, dur: 1.3, invul: true }; J.perso.root.rotation.y = Math.atan2(corps.pos.x - J.pos.x, corps.pos.z - J.pos.z);
  J.perso.jouer('Spell_Simple_Enter', { boucle: false, forcer: true }); son('sov_possession', 0.7, 0.9);
  texteFlottant(V(corps.pos.x, corps.pos.y + 2.6, corps.pos.z), 'LÈVE-TOI', 'arise');
  let t = 0; const iv = setInterval(() => { t += 0.1; emettre(V(corps.pos.x + rnd(-0.6, 0.6), corps.pos.y + 0.1, corps.pos.z + rnd(-0.6, 0.6)), { n: 4, c1: '#c8a8ff', c2: '#3a0a7a', vit: 1.5, vie: 1, taille: 0.3, grav: -5 }); if (t > 1.2) clearInterval(iv); }, 100);
  setTimeout(() => {
    const chance = (9 + n) / 100;
    if (Math.random() < chance) {
      G.scene.remove(corps.m.root); corps.corpsT = 0;
      const a = new Ennemi(corps.type, corps.pos, { allie: true, niv: corps.niv }); a.etat = 'suit';
      (C.J.armee ||= []).push({ type: corps.type, niv: corps.niv }); C.sauver(); C.majQuete();
      son('sov_onde', 0.8, 0.8); G.shake = 0.5; emettre(V(a.pos.x, a.pos.y + 1, a.pos.z), { n: 120, c1: '#c8a8ff', c2: '#2a0a5a', vit: 6, vie: 1.3, taille: 0.35, grav: -3 });
      texteFlottant(V(a.pos.x, a.pos.y + 3, a.pos.z), 'ARISE !', 'arise'); C.toast(`🜏 ${TYPES_M[corps.type].nom} rejoint ton armée d'ombres !`);
    } else {
      corps.corpsT = Math.min(corps.corpsT, 1.4); emettre(V(corps.pos.x, corps.pos.y + 0.6, corps.pos.z), { n: 30, c1: '#4a4a5a', c2: '#101018', vit: 2, vie: 1, taille: 0.3, grav: -2 });
      texteFlottant(V(corps.pos.x, corps.pos.y + 2.4, corps.pos.z), `Échec… (${Math.round(chance * 100)} %)`, 'info'); son('error_004', 0.4, 0.8);
    }
  }, 1250);
}
let bouclier = null, dague = null;
// effets : arcs de lame, ondes de choc, rayons de télékinésie (durée courte, mis à jour chaque image)
const fx = [];
function arc(pos, angle, { r = 1.6, couleur = '#e8dcff', large = 2.2, y = 1.05, vie = 0.2 } = {}) {
  const m = new THREE.Mesh(new THREE.RingGeometry(r * 0.55, r, 20, 1, -large / 2, large), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.85, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending }));
  m.rotation.set(-Math.PI / 2 + 0.25, 0, 0); const g = new THREE.Group(); g.add(m); g.position.set(pos.x, pos.y + y, pos.z); g.rotation.y = angle - Math.PI / 2; G.scene.add(g);
  fx.push({ o: g, m: m.material, t: 0, vie, maj: (k) => { m.material.opacity = 0.85 * (1 - k); g.scale.setScalar(1 + k * 0.25); } });
}
function onde(pos, { r = 4, couleur = '#c8a8ff', vie = 0.45 } = {}) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 40).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.9, depthWrite: false, blending: THREE.AdditiveBlending }));
  m.position.set(pos.x, pos.y + 0.12, pos.z); G.scene.add(m); fx.push({ o: m, m: m.material, t: 0, vie, maj: (k) => { m.scale.setScalar(0.3 + k * r); m.material.opacity = 0.9 * (1 - k); } });
}
function majFx(dt) { for (let i = fx.length - 1; i >= 0; i--) { const f = fx[i]; f.t += dt; const k = Math.min(1, f.t / f.vie); f.maj(k, dt); if (k >= 1) { G.scene.remove(f.o); f.m.dispose(); fx.splice(i, 1); } } }
function majHeros(dt) {
  const J = C.joueur, p = J.perso;
  for (const k in heros.cds) if (heros.cds[k] > 0) heros.cds[k] -= dt;
  if (heros.comboT > 0) heros.comboT -= dt;
  heros.horsCombat += dt; if (heros.horsCombat > 5 && J.pv < pvMaxHeros() && !heros.mortT) J.pv = Math.min(pvMaxHeros(), J.pv + dt * 6);
  if (heros.mortT) { heros.mortT -= dt; if (heros.mortT <= 0) { heros.mortT = 0; J.pos.set(2, 0, 6); J.pv = pvMaxHeros(); p.jouer('Idle_Loop', { forcer: true }); emettre(V(2, 1, 6), { n: 50, c1: '#c8a8ff', c2: '#2a0a5a', vit: 3, vie: 1, taille: 0.3, grav: -2 }); C.majHud(); } return; }
  if (bouclier.visible) bouclier.rotation.z += dt * 2;
  const A = heros.action; if (!A) return;
  A.t += dt; heros.horsCombat = 0;
  if (A.k === 'coup') {
    if (A.elan && A.t < A.frappe) { const v = A.elan / A.frappe * dt, a = p.root.rotation.y, nx = J.pos.x + Math.sin(a) * v, nz = J.pos.z + Math.cos(a) * v; if (!ennemis.some(e => e.vivant && dist(e.pos, { x: nx, z: nz }) < 1.1)) { J.pos.x = nx; J.pos.z = nz; } }
    if (!A.fait && A.t >= A.frappe) {
      A.fait = true; const devant = p.root.rotation.y; arc(J.pos, devant, { couleur: A.crit ? '#ffd27a' : '#e8dcff', r: A.mult > 1.4 ? 2.2 : 1.8, large: A.mult > 1.4 ? 3 : 2.2 }); son('knifeSlice', 0.5, rnd(0.9, 1.1), J.pos);
      const cibles = A.cibles || ennemis.filter(e => e.vivant && dist(e.pos, J.pos) < 2.6 && Math.abs(Math.atan2(Math.sin(Math.atan2(e.pos.x - J.pos.x, e.pos.z - J.pos.z) - devant), Math.cos(Math.atan2(e.pos.x - J.pos.x, e.pos.z - J.pos.z) - devant))) < 1);
      const crit = A.crit || Math.random() < 0.12;
      for (const e of cibles) e.subir(degHeros() * A.mult * (crit && !A.crit ? 1.5 : 1), { pos: J.pos, isHeros: true }, { crit });
      if (cibles.length) G.shake = Math.max(G.shake, 0.15);
    }
    if (A.t >= A.dur) heros.action = null;
  } else if (A.k === 'lame') { // fond sur chaque cible : élan, coup, suivante
    const e = A.cibles[A.i];
    if (!e || !e.vivant) { A.i++; A.t = 0; if (A.i >= A.cibles.length) { heros.action = null; p.jouer('Idle_Loop'); } return; }
    if (A.t < 0.14) { const a = Math.atan2(e.pos.x - J.pos.x, e.pos.z - J.pos.z), d = dist(e.pos, J.pos); if (d > 1.1) { const k = Math.min(1, dt / Math.max(0.01, 0.14 - A.t + dt)); J.pos.x += (e.pos.x - Math.sin(a) * 1.1 - J.pos.x) * k; J.pos.z += (e.pos.z - Math.cos(a) * 1.1 - J.pos.z) * k; J.pos.y = hauteur(J.pos.x, J.pos.z); } p.root.rotation.y = a; emettre(V(J.pos.x, J.pos.y + 1, J.pos.z), { n: 4, c1: '#c8a8ff', c2: '#3a0a7a', vit: 0.5, vie: 0.35, taille: 0.3, grav: 0 }); if (!A.joue) { A.joue = true; p.jouer('Sword_Dash', { boucle: false, forcer: true, vitesse: 2.4 }); } }
    else if (!A.frappe) { A.frappe = true; arc(J.pos, p.root.rotation.y, { couleur: '#b98aff', r: 2.2, large: 2.8 }); e.subir(degHeros() * A.mult, { pos: J.pos, isHeros: true }, { crit: true, recul: 0.8 }); son('knifeSlice', 0.6, 1.3, J.pos); G.shake = Math.max(G.shake, 0.2); }
    if (A.t > 0.34) { A.i++; A.t = 0; A.joue = false; A.frappe = false; if (A.i >= A.cibles.length) { heros.action = null; p.jouer('Idle_Loop'); } }
  } else if (A.k === 'dash') { // élan foudroyant : traînée d'ombre, invulnérable
    const v = 30 * (1 - A.t / A.dur) + 6, nx = J.pos.x + Math.sin(A.a) * v * dt, nz = J.pos.z + Math.cos(A.a) * v * dt; if (Math.hypot(nx, nz) < 78) { J.pos.x = nx; J.pos.z = nz; }
    for (let i = 0; i < 3; i++) emettre(V(J.pos.x + rnd(-0.3, 0.3), J.pos.y + rnd(0.3, 1.6), J.pos.z + rnd(-0.3, 0.3)), { n: 1, c1: '#c8a8ff', c2: '#2a0a5a', vit: 0.3, vie: 0.45, taille: 0.35, grav: 0 });
    if (A.t >= A.dur) { heros.action = null; if (J.vel) J.vel.set(Math.sin(A.a) * 5, 0, Math.cos(A.a) * 5); }
  } else if (A.k === 'sort') { if (A.t >= A.dur) { heros.action = null; p.jouer('Idle_Loop'); } }
}
export const heroOccupe = () => !!(heros.action || heros.mortT || heros.parade);
// ---------------- Barres de vie ----------------
const barres = new Map();
function majBarres() {
  const hote = document.getElementById('bulles');
  for (const e of [...ennemis, ...allies]) {
    let b = barres.get(e); const montre = e.vivant && e.m.root.parent && (e.allie || e.vu > 0 || e.etat !== 'garde' && e.etat !== 'flane' || e.pv < e.pvMax);
    if (!montre) { if (b) b.style.display = 'none'; continue; }
    if (!b) { b = document.createElement('div'); b.className = 'vie' + (e.allie ? ' allie' : ''); b.innerHTML = `<small>${e.allie ? '🜏 ' : ''}${e.T.nom} <em>Nv ${e.niv}</em></small><i><u></u></i>`; hote.appendChild(b); barres.set(e, b); }
    const s = projeter(V(e.pos.x, e.pos.y + e.T.h * e.T.ech, e.pos.z)); b.style.display = s.devant ? '' : 'none';
    b.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-100%)`; b.querySelector('u').style.width = (100 * e.pv / e.pvMax) + '%';
  }
}
// ---------------- Boutons : attaque + cercle de pouvoirs ----------------
function initBoutons() {
  const at = document.getElementById('btnAttaque');
  at.addEventListener('pointerdown', (e) => { e.preventDefault(); attaquer(); at.classList.add('presse'); });
  at.addEventListener('pointerup', () => at.classList.remove('presse'));
  for (const [id, f] of [['pw-saut', () => C.sauter()], ['pw-dash', dash]]) { const b = document.getElementById(id); b.addEventListener('pointerdown', (e) => { e.preventDefault(); f(); b.classList.add('presse'); }); b.addEventListener('pointerup', () => b.classList.remove('presse')); b.addEventListener('pointercancel', () => b.classList.remove('presse')); }
  for (const k of Object.keys(POUVOIRS)) {
    const b = document.getElementById('pw-' + k);
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); b.setPointerCapture(e.pointerId); pouvoir(k, true); b.classList.add('presse'); });
    const fin = () => { b.classList.remove('presse'); if (k === 'parade') pouvoir(k, false); };
    b.addEventListener('pointerup', fin); b.addEventListener('pointercancel', fin);
  }
}
let cdT = 0;
function majBoutons(dt) {
  if ((cdT -= dt) > 0) return; cdT = 0.08;
  for (const k of Object.keys(POUVOIRS)) {
    const b = document.getElementById('pw-' + k), P = POUVOIRS[k], r = P.cd ? Math.max(0, heros.cds[k]) / P.cd : 0;
    b.style.setProperty('--cd', r.toFixed(3)); b.classList.toggle('pret', r <= 0 && (!P.mana || C.J.mana >= P.mana));
    const t = b.querySelector('em'); const txt = r > 0 ? Math.ceil(heros.cds[k]) : ''; if (t.textContent !== String(txt)) t.textContent = txt;
  }
  { const b = document.getElementById('pw-dash'), r = Math.max(0, heros.cds.dash) / 1.1; b.style.setProperty('--cd', r.toFixed(3)); }
  const lvl = document.getElementById('pw-arise'); lvl.classList.toggle('dispo', ennemis.some(e => e.etat === 'mort' && e.corpsT > 2 && !e.leve && dist(e.pos, C.joueur.pos) < 9));
}
// ---------------- Entrée ----------------
export function initCombat(ctx) {
  C = ctx; const h = C.J.heros ||= { niv: 1, xp: 0, pts: 0, pw: {} }; h.pw = Object.assign({ lame: 1, tele: 1, parade: 1, arise: 1 }, h.pw);
  C.joueur.pv = pvMaxHeros(); C.joueur.isHeros = true;
  // dague du héros et bouclier d'ombre (parade)
  const g = new THREE.Group(), lame = new THREE.Mesh(new THREE.ConeGeometry(0.035, 0.42, 4), new THREE.MeshStandardMaterial({ color: '#d8d8f0', metalness: 0.8, roughness: 0.25, emissive: '#3a1a8a', emissiveIntensity: 0.6 }));
  lame.position.y = 0.3; const garde = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.025, 0.04), new THREE.MeshStandardMaterial({ color: '#2a1a3a' })); garde.position.y = 0.08; g.add(lame, garde); g.rotation.set(Math.PI / 2, 0, 0); dague = C.joueur.perso.tenir(g, 'hand_r');
  bouclier = new THREE.Mesh(new THREE.RingGeometry(0.55, 0.75, 6), new THREE.MeshBasicMaterial({ color: '#b98aff', transparent: true, opacity: 0.55, side: THREE.DoubleSide, depthWrite: false }));
  bouclier.position.set(0, 1.15, 0.7); bouclier.visible = false; C.joueur.perso.root.add(bouclier);
  for (const d of CAMPS) creerCamp(d);
  for (const a of C.J.armee || []) { const x = new Ennemi(a.type, V(C.joueur.pos.x + rnd(-3, 3), 0, C.joueur.pos.z + rnd(-3, 3)), { allie: true, niv: a.niv }); x.etat = 'suit'; }
  G.danger = zoneDangereuse; initBoutons();
}
export function majCombat(dt) {
  if (G.ralentiT > 0) { G.ralentiT -= dt / Math.max(0.05, G.ralenti); if (G.ralentiT <= 0) G.ralenti = 1; }
  majHeros(dt); majFx(dt);
  for (const e of ennemis) e.maj(dt); for (const a of allies) a.maj(dt);
  for (let i = ennemis.length - 1; i >= 0; i--) if (ennemis[i].etat === 'mort' && ennemis[i].corpsT <= 0 && !ennemis[i].m.root.parent) { const b = barres.get(ennemis[i]); if (b) { b.remove(); barres.delete(ennemis[i]); } ennemis.splice(i, 1); }
  for (const c of Object.values(camps)) if (c.mortT > 0) { c.mortT -= dt; if (c.mortT <= 0) { peupler(c); delete (C.J.camps || {})[c.def.id]; } }
  majBarres(); majBoutons(dt);
}
export const armee = () => allies;
