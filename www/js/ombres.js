// Les ombres : relevées des morts, elles ont un rang (E → S), une maîtrise par métier qui grandit en travaillant,
// et on les voit vraiment travailler : bois (abattre, débiter, porter), pierre (tailler, porter), construction (marteler).
import { THREE, G, V, emettre, son, texteFlottant } from './moteur.js';
import { Perso } from './persos.js';
import { arbreProche, frapperArbre, debiter, buche, hauteur, filonProche, tailler } from './monde.js';
import { depotProche, chantierProche, marteler, enTravaux, bloque } from './batiments.js';

export const RANGS = {
  E: { c: '#a7b0bb', coupe: 1.0, charge: 4, vit: 3.2 },
  D: { c: '#5fd17a', coupe: 1.25, charge: 6, vit: 3.5 },
  C: { c: '#4aa8ff', coupe: 1.55, charge: 8, vit: 3.8 },
  B: { c: '#b36bff', coupe: 2.0, charge: 11, vit: 4.1 },
  A: { c: '#ff9a3a', coupe: 2.6, charge: 15, vit: 4.4 },
  S: { c: '#ff3a5a', coupe: 3.4, charge: 22, vit: 4.8 },
};
export const METIERS = { bois: { nom: 'Bûcheron', icone: '🪓' }, pierre: { nom: 'Tailleur', icone: '⛏️' }, construire: { nom: 'Bâtisseur', icone: '🔨' }, suivre: { nom: 'Te suit', icone: '👣' }, repos: { nom: 'Au repos', icone: '🔥' } };
export const NOMS = ['Kael', 'Vesna', 'Morrow', 'Ilyr', 'Dusk', 'Sabre', 'Nox', 'Varek', 'Thorne', 'Ashka', 'Grael', 'Myrr', 'Oswin', 'Selk', 'Raven', 'Corvin'];
export const xpNiveau = (n) => Math.round(12 * Math.pow(n, 1.45));
const PAROLES = {
  eveil: ['Maître… ordonne.', 'Je suis à toi, souverain.', 'Ta volonté sera la mienne.', 'Je me relève… pour toi.'],
  bois: ['La forêt ne résistera pas.', 'Je rapporte du bois, maître.', 'À la hache.'],
  pierre: ['La roche cédera.', 'Je taillerai la montagne s’il le faut.'],
  construire: ['Je bâtirai ton royaume.', 'Pierre après pierre, maître.'],
  suivre: ['Je te suis.', 'Derrière toi, toujours.'],
  repos: ['Je veille près du feu.', 'À tes ordres.'],
  niveau: ['Mes gestes deviennent plus sûrs.', 'Je sens ma force grandir.', 'Le travail m’obéit mieux.'],
};
export const parole = (k) => { const L = PAROLES[k] || PAROLES.repos; return L[Math.floor(Math.random() * L.length)]; };
export function teinteOmbre(d) {
  if (/eye/i.test(d.name || '')) { d.color.set('#c8a8ff'); d.emissive = new THREE.Color('#9a5aff'); d.emissiveIntensity = 2.2; d.map = null; return; }
  d.color.set('#1a1226'); d.emissive = new THREE.Color('#3a127a'); d.emissiveIntensity = 0.32; d.roughness = 0.55; d.envMapIntensity = 1.2; // noir d'encre, lueur violette discrète
}
// outils tenus en main (hache, pioche, marteau) : on voit ce que fait chaque ombre
const MBOIS = new THREE.MeshStandardMaterial({ color: '#6b4426', roughness: 0.9 }), MFER = new THREE.MeshStandardMaterial({ color: '#9aa0a8', metalness: 0.7, roughness: 0.35 });
function outil(type) {
  const g = new THREE.Group(), manche = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.03, 0.75, 6), MBOIS); manche.position.y = 0.3; g.add(manche);
  if (type === 'bois') { const t = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.14, 0.04), MFER); t.position.set(0.09, 0.62, 0); g.add(t); }
  if (type === 'pierre') { const t = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.06, 0.05), MFER); t.position.set(0, 0.64, 0); t.rotation.z = 0.12; g.add(t); }
  if (type === 'construire') { manche.scale.y = 0.6; manche.position.y = 0.2; const t = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.08, 0.08), MFER); t.position.set(0, 0.42, 0); g.add(t); }
  g.rotation.set(Math.PI / 2, 0, 0); g.position.set(0.02, 0.05, 0.02); g.visible = false; return g;
}
const PIERRE = new THREE.Mesh(new THREE.DodecahedronGeometry(0.28, 0), new THREE.MeshStandardMaterial({ color: '#9a9aa2', roughness: 0.9 }));
let bulleCb = null, signalCb = null; export function surParole(f) { bulleCb = f; } export function surSignal(f) { signalCb = f; }
export class Ombre {
  constructor(data, pos) {
    this.d = data;
    const m = data.maitrise; for (const k of ['bois', 'pierre', 'construire']) if (!m[k]) m[k] = { niv: 1, xp: 0 };
    this.p = new Perso({ sexe: data.sexe, tenue: 'paysan', cheveux: data.cheveux ?? 0, teinte: teinteOmbre });
    this.p.root.position.copy(pos); G.scene.add(this.p.root);
    this.etat = 'chercher'; this.cible = null; this.charge = 0; this.t = 0; this.but = V(); this.ph = 0;
    this.outils = { bois: outil('bois'), pierre: outil('pierre'), construire: outil('construire') }; for (const k in this.outils) this.p.tenir(this.outils[k], 'hand_r');
    this.port = { bois: buche(0.12, 0.9), pierre: PIERRE.clone() }; for (const k in this.port) { this.port[k].visible = false; this.port[k].position.set(0, 0.05, 0.14); this.p.tenir(this.port[k], 'hand_r'); }
    this.p.jouer('Idle_Loop');
  }
  get pos() { return this.p.root.position; }
  get R() { return RANGS[this.d.rang]; }
  mt(k = this.d.metier) { return this.d.maitrise[k] || { niv: 1, xp: 0 }; }
  vitesse(k) { return this.R.coupe * (1 + 0.04 * (this.mt(k).niv - 1)); }
  capacite(k) { return this.R.charge + Math.floor((this.mt(k).niv - 1) / 4) + ((G.chargeBonus || {})[k] || 0); }
  dire(t) { bulleCb && bulleCb(this, t); }
  montrer(outilK, portK) { for (const k in this.outils) this.outils[k].visible = k === outilK; for (const k in this.port) this.port[k].visible = k === portK; }
  aller(dest, dt, vit, anim = 'Walk_Loop') {
    const dx = dest.x - this.pos.x, dz = dest.z - this.pos.z, d = Math.hypot(dx, dz);
    if (d < 0.25) return true;
    const pas = Math.min(d, vit * dt); let a = Math.atan2(dx, dz);
    // contourne les murs : essaie de dévier de plus en plus, en gardant le côté choisi pour ne pas hésiter
    if (bloque(this.pos.x + Math.sin(a) * 0.5, this.pos.z + Math.cos(a) * 0.5, 0.3)) {
      this.cote ??= Math.random() < 0.5 ? 1 : -1;
      for (const k of [0.5, 0.9, 1.3, 1.7, 2.2]) { const b = a + k * this.cote; if (!bloque(this.pos.x + Math.sin(b) * 0.5, this.pos.z + Math.cos(b) * 0.5, 0.3)) { a = b; break; } }
    } else if (Math.random() < dt) this.cote = null;
    this.pos.x += Math.sin(a) * pas; this.pos.z += Math.cos(a) * pas; this.pos.y = hauteur(this.pos.x, this.pos.z);
    this.tourner(a, dt);
    this.p.jouer(anim, { vitesse: anim === 'Walk_Loop' ? vit / 1.6 : anim === 'Walk_Carry_Loop' ? vit / 1.5 : vit / 3.4 });
    return false;
  }
  tourner(a, dt) { let da = a - this.p.root.rotation.y; da = Math.atan2(Math.sin(da), Math.cos(da)); this.p.root.rotation.y += da * Math.min(1, dt * 9); }
  liberer() { if (this.cible && typeof this.cible.ouvriers === 'number') this.cible.ouvriers = Math.max(0, this.cible.ouvriers - 1); this.cible = null; }
  coup() { const ph = this.p.phase(), ok = this.ph < 0.5 && ph >= 0.5; this.ph = ph; return ok; } // l'instant où l'outil frappe
  // ---------- récolte (bois ou pierre), étape par étape ----------
  majRecolte(dt, j, res) {
    if (this.etat !== 'aller' && this.etat !== 'travail' && this.etat !== 'porter' && this.etat !== 'depose') this.etat = 'chercher';
    if (this.etat === 'chercher') {
      if (this.charge >= this.capacite(res)) { this.etat = 'porter'; return; }
      let c = null;
      if (this.force && !(res === 'bois' ? this.force.etat === 'souche' : this.force.pierre <= 0)) c = this.force; this.force = null;
      if (c) {} else if (res === 'bois') c = arbreProche(this.pos, x => x.etat === 'abattu' && x.bois > 0 && x.ouvriers < 3, 40) || arbreProche(this.pos, x => x.etat === 'debout' && x.ouvriers < 3, 70);
      else c = filonProche(this.pos);
      if (!c) { if (this.charge > 0) this.etat = 'porter'; else { this.montrer(null, null); this.p.jouer('Idle_Loop'); if (!this.oisif) { this.oisif = true; this.dire(res === 'bois' ? 'Plus aucun arbre à portée, maître.' : 'Les filons sont épuisés, maître.'); signalCb && signalCb(this, res === 'bois' ? `🪓 ${this.d.nom} n’a plus d’arbre à portée` : `⛏️ ${this.d.nom} attend que les filons repoussent`); } } return; }
      this.oisif = false; this.cible = c; c.ouvriers++; this.etat = 'aller'; this.angBut = Math.random() * 6.28;
    }
    const c = this.cible;
    const centre = () => res === 'bois' ? (c.etat === 'abattu' ? c.posTronc : c.pos) : c.pos;
    const epuise = () => res === 'bois' ? (c.etat === 'souche' || (c.etat === 'abattu' && c.bois <= 0)) : c.pierre <= 0;
    if (this.etat === 'aller') {
      if (!c || epuise()) { this.liberer(); this.etat = this.charge ? 'porter' : 'chercher'; return; }
      const k = centre(), r = res === 'pierre' ? 0.75 * c.e + 0.45 : c.etat === 'abattu' ? 1.25 : 1.05;
      this.but.set(k.x + Math.cos(this.angBut) * r, 0, k.z + Math.sin(this.angBut) * r);
      this.montrer(res, null);
      if (this.aller(this.but, dt, this.R.vit * 0.85)) { this.etat = 'travail'; this.ph = 0; }
      return;
    }
    if (this.etat === 'travail') {
      if (res === 'bois' && c.etat === 'tombe') { this.p.jouer('Idle_Loop'); return; } // il regarde l'arbre tomber
      if (!c || epuise()) { this.liberer(); this.etat = this.charge ? 'porter' : 'chercher'; return; }
      const k = centre(); if (Math.hypot(k.x - this.pos.x, k.z - this.pos.z) > 2.6) { this.etat = 'aller'; return; }
      this.tourner(Math.atan2(k.x - this.pos.x, k.z - this.pos.z), dt);
      this.p.jouer('TreeChopping_Loop', { vitesse: this.vitesse(res) });
      if (this.coup()) {
        const par = 1 + Math.floor('EDCBAS'.indexOf(this.d.rang) / 2), place = this.capacite(res) - this.charge;
        if (res === 'bois' && c.etat === 'debout') frapperArbre(c, this.pos, 1);
        else this.charge += res === 'bois' ? debiter(c, Math.min(place, par)) : tailler(c, Math.min(place, par), this.pos);
        if (this.charge >= this.capacite(res)) { this.liberer(); this.etat = 'porter'; }
      }
      return;
    }
    if (this.etat === 'porter') {
      const dep = depotProche(this.pos, res); this.montrer(null, res);
      const dest = V(dep.pos.x + Math.cos(this.d.id * 1.7) * dep.r, 0, dep.pos.z + Math.sin(this.d.id * 1.7) * dep.r);
      if (this.aller(dest, dt, this.R.vit * 0.75, 'Walk_Carry_Loop')) {
        this.montrer(null, null); const n = Math.round(this.charge * dep.bonus); this.charge = 0;
        j.ajouter(res, n, dep.pos); this.gagnerXp(res, n);
        this.p.jouer('PickUp_Table', { boucle: false, forcer: true, vitesse: 1.6 });
        this.etat = 'depose'; this.t = 0.8;
      }
      return;
    }
    if (this.etat === 'depose') { this.t -= dt; if (this.t <= 0) this.etat = 'chercher'; }
  }
  // ---------- construction : marteler le chantier le plus proche ----------
  majConstruire(dt, j) {
    if (this.force) { this.cible = enTravaux(this.force) ? this.force : null; this.force = null; this.angBut = Math.random() * 6.28; }
    let b = this.cible && this.cible.T && enTravaux(this.cible) ? this.cible : null;
    if (!b) { b = chantierProche(this.pos); this.cible = b; this.angBut = Math.random() * 6.28; }
    if (!b) { // plus de chantier : il retourne à son ancien métier au lieu de rester planté
      const av = this.d.avant; if (av === 'bois' || av === 'pierre') { this.changerMetier(av); this.dire(av === 'bois' ? 'Le chantier est fini. Je retourne au bois.' : 'Le chantier est fini. Je retourne à la carrière.'); return; }
      if (!this.oisif) { this.oisif = true; signalCb && signalCb(this, `🔨 ${this.d.nom} n’a plus de chantier`); } this.majRepos(dt); return; }
    this.oisif = false;
    const r = b.T.rayon * 0.9, k = b.g.position; this.but.set(k.x + Math.cos(this.angBut) * r, 0, k.z + Math.sin(this.angBut) * r);
    this.montrer('construire', null);
    if (Math.hypot(this.but.x - this.pos.x, this.but.z - this.pos.z) > 0.4) { this.aller(this.but, dt, this.R.vit); return; }
    this.tourner(Math.atan2(k.x - this.pos.x, k.z - this.pos.z), dt);
    this.p.jouer('Fixing_Kneeling', { vitesse: this.vitesse('construire') });
    this.t -= dt;
    if (this.t <= 0) {
      this.t = 0.9 / this.vitesse('construire');
      const fini = marteler(b, 1, V(this.pos.x + Math.sin(this.p.root.rotation.y) * 0.6, this.pos.y, this.pos.z + Math.cos(this.p.root.rotation.y) * 0.6));
      this.gagnerXp('construire', 1); if (fini) { j.batimentFini(b, this); this.cible = null; }
    }
  }
  gagnerXp(k, n) {
    const m = this.d.maitrise[k]; if (!m) return; m.xp += n;
    while (m.xp >= xpNiveau(m.niv)) { m.xp -= xpNiveau(m.niv); m.niv++; texteFlottant(V(this.pos.x, this.pos.y + 2.6, this.pos.z), `${METIERS[k].icone} Maîtrise ${m.niv} !`, 'niveau'); son('jingles_PIZZI01', 0.35); emettre(V(this.pos.x, this.pos.y + 1, this.pos.z), { n: 30, c1: '#ffe9a0', c2: '#b36bff', vit: 3, vie: 0.9, taille: 0.18, grav: -1 }); this.dire(parole('niveau')); }
  }
  majSuivre(dt, j, rang) {
    this.montrer(null, null);
    const ang = j.perso.root.rotation.y + Math.PI + (rang - 1.5) * 0.55, dist = 2.6 + Math.floor(rang / 4) * 1.4;
    const dest = V(j.pos.x + Math.sin(ang) * dist, 0, j.pos.z + Math.cos(ang) * dist);
    const d = Math.hypot(dest.x - this.pos.x, dest.z - this.pos.z);
    if (d > 30) { this.pos.set(dest.x, hauteur(dest.x, dest.z), dest.z); return; }
    if (d > 0.6) this.aller(dest, dt, d > 5 ? 6 : this.R.vit, d > 5 ? 'Jog_Fwd_Loop' : 'Walk_Loop');
    else { this.p.jouer('Idle_Loop'); this.tourner(j.perso.root.rotation.y, dt); }
  }
  majRepos(dt) { this.montrer(null, null); const dest = V(-1.5 + Math.cos(this.d.id * 1.3) * 3.2, 0, -1.5 + Math.sin(this.d.id * 1.3) * 3.2); if (this.aller(dest, dt, this.R.vit)) { this.p.jouer('Sitting_Idle_Loop'); this.tourner(Math.atan2(-1.5 - this.pos.x, -1.5 - this.pos.z), dt); } }
  ordonner(m, cible) { this.changerMetier(m); this.force = cible; }
  changerMetier(m) { if (m === 'construire' && this.d.metier !== 'construire') this.d.avant = this.d.metier; this.oisif = false; this.liberer(); this.charge = 0; this.etat = 'chercher'; this.d.metier = m; this.montrer(null, null); }
  maj(dt, j, rang) {
    this.p.maj(dt);
    if (this.scene) return this.scene(dt);
    const m = this.d.metier;
    if (m === 'bois' || m === 'pierre') this.majRecolte(dt, j, m);
    else if (m === 'construire') this.majConstruire(dt, j);
    else if (m === 'suivre') this.majSuivre(dt, j, rang);
    else this.majRepos(dt);
    if (Math.random() < dt * 6) emettre(V(this.pos.x + (Math.random() - 0.5) * 0.5, this.pos.y + 0.2, this.pos.z + (Math.random() - 0.5) * 0.5), { n: 1, c1: '#8a5aff', c2: '#1a0a30', vit: 0.3, vie: 0.8, taille: 0.22, grav: -1.2 });
  }
}
