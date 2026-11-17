// Les ombres : relevées des morts, elles ont un rang (E → S), une maîtrise qui grandit en travaillant,
// et on les voit vraiment travailler : marcher à l'arbre, l'abattre, débiter, porter le bois à la réserve.
import { THREE, G, V, emettre, son, texteFlottant } from './moteur.js';
import { Perso } from './persos.js';
import { arbres, arbreProche, frapperArbre, debiter, buche, RESERVE, hauteur } from './monde.js';

export const RANGS = {
  E: { c: '#a7b0bb', coupe: 1.0, charge: 4, vit: 3.2, nom: 'E' },
  D: { c: '#5fd17a', coupe: 1.25, charge: 6, vit: 3.5, nom: 'D' },
  C: { c: '#4aa8ff', coupe: 1.55, charge: 8, vit: 3.8, nom: 'C' },
  B: { c: '#b36bff', coupe: 2.0, charge: 11, vit: 4.1, nom: 'B' },
  A: { c: '#ff9a3a', coupe: 2.6, charge: 15, vit: 4.4, nom: 'A' },
  S: { c: '#ff3a5a', coupe: 3.4, charge: 22, vit: 4.8, nom: 'S' },
};
export const NOMS = ['Kael', 'Vesna', 'Morrow', 'Ilyr', 'Dusk', 'Sabre', 'Nox', 'Varek', 'Thorne', 'Ashka', 'Grael', 'Myrr', 'Oswin', 'Selk', 'Raven', 'Corvin'];
export const xpNiveau = (n) => Math.round(12 * Math.pow(n, 1.45));
const PAROLES = {
  eveil: ['Maître… ordonne.', 'Je suis à toi, souverain.', 'Ta volonté sera la mienne.', 'Je me relève… pour toi.'],
  bois: ['La forêt ne résistera pas.', 'Je rapporte du bois, maître.', 'À la hache.'],
  suivre: ['Je te suis.', 'Derrière toi, toujours.'],
  repos: ['Je veille près du feu.', 'À tes ordres.'],
  niveau: ['Ma hache s’alourdit… je deviens plus fort.', 'Je sens mes bras plus sûrs.', 'Le bois m’obéit mieux.'],
};
export const parole = (k) => PAROLES[k][Math.floor(Math.random() * PAROLES[k].length)];
// apparence d'ombre : noire et violette, yeux qui brillent
export function teinteOmbre(d) {
  if (/eye/i.test(d.name || '')) { d.color.set('#c8a8ff'); d.emissive = new THREE.Color('#9a5aff'); d.emissiveIntensity = 2.2; d.map = null; return; }
  d.color.set('#1a1226'); d.emissive = new THREE.Color('#3a127a'); d.emissiveIntensity = 0.32; d.roughness = 0.55; d.envMapIntensity = 1.2; // noir d'encre, lueur violette discrète
}
let bulleCb = null; export function surParole(f) { bulleCb = f; }
export class Ombre {
  constructor(data, pos) {
    this.d = data; // { id, nom, rang, metier, sexe, maitrise: { bois: { niv, xp } } }
    this.p = new Perso({ sexe: data.sexe, tenue: 'paysan', cheveux: data.cheveux ?? 0, teinte: teinteOmbre });
    this.p.root.position.copy(pos); G.scene.add(this.p.root);
    this.etat = 'idle'; this.cible = null; this.charge = 0; this.t = 0; this.but = null;
    const tronc = buche(0.12, 0.9);
    tronc.position.set(0, 0.05, 0.12); tronc.visible = false; this.fagot = tronc; this.p.tenir(tronc, 'hand_r');
    this.p.jouer('Idle_Loop');
  }
  get pos() { return this.p.root.position; }
  get R() { return RANGS[this.d.rang]; }
  get m() { return this.d.maitrise.bois; }
  vitesseCoupe() { return this.R.coupe * (1 + 0.04 * (this.m.niv - 1)); }
  capacite() { return this.R.charge + Math.floor((this.m.niv - 1) / 4); }
  dire(t) { bulleCb && bulleCb(this, t); }
  aller(dest, dt, vit, anim = 'Walk_Loop') {
    const dx = dest.x - this.pos.x, dz = dest.z - this.pos.z, d = Math.hypot(dx, dz);
    if (d < 0.25) return true;
    const pas = Math.min(d, vit * dt); this.pos.x += dx / d * pas; this.pos.z += dz / d * pas; this.pos.y = hauteur(this.pos.x, this.pos.z);
    this.tourner(Math.atan2(dx, dz), dt);
    this.p.jouer(anim, { vitesse: anim === 'Walk_Loop' ? vit / 1.6 : anim === 'Walk_Carry_Loop' ? vit / 1.5 : vit / 3.4 });
    return false;
  }
  tourner(a, dt) { let da = a - this.p.root.rotation.y; da = Math.atan2(Math.sin(da), Math.cos(da)); this.p.root.rotation.y += da * Math.min(1, dt * 9); }
  // ---------- le métier de bûcheron, étape par étape ----------
  majBois(dt, j) {
    if (this.etat === 'idle' || this.etat === 'chercher') {
      if (this.charge >= this.capacite()) { this.etat = 'porter'; return; }
      // d'abord les troncs déjà à terre (débiter), sinon l'arbre debout le plus proche ; 3 ombres max par arbre
      let a = arbreProche(this.pos, x => x.etat === 'abattu' && x.bois > 0 && x.ouvriers < 3, 40);
      if (!a) a = arbreProche(this.pos, x => x.etat === 'debout' && x.ouvriers < 3, 70);
      if (!a) { if (this.charge > 0) this.etat = 'porter'; else this.p.jouer('Idle_Loop'); return; }
      this.cible = a; a.ouvriers++; this.etat = 'aller';
      const ang = Math.random() * 6.28; this.but = V(0, 0, 0); this.angBut = ang;
    }
    const a = this.cible;
    if (this.etat === 'aller') {
      if (!a || (a.etat !== 'debout' && a.etat !== 'abattu') || (a.etat === 'abattu' && a.bois <= 0)) return this.lacher();
      const c = a.etat === 'abattu' ? a.posTronc : a.pos, r = a.etat === 'abattu' ? 1.25 : 1.05;
      this.but.set(c.x + Math.cos(this.angBut) * r, 0, c.z + Math.sin(this.angBut) * r);
      if (this.aller(this.but, dt, this.R.vit * 0.85)) { this.etat = 'couper'; this.ph = 0; }
      return;
    }
    if (this.etat === 'couper') {
      if (!a || a.etat === 'tombe') { this.p.jouer('Idle_Loop'); return; } // il regarde l'arbre tomber
      if (a.etat === 'souche' || (a.etat === 'abattu' && a.bois <= 0)) return this.lacher();
      const c = a.etat === 'abattu' ? a.posTronc : a.pos;
      if (a.etat === 'abattu' && Math.hypot(c.x - this.pos.x, c.z - this.pos.z) > 1.8) { this.etat = 'aller'; return; }
      this.tourner(Math.atan2(c.x - this.pos.x, c.z - this.pos.z), dt);
      const v = this.vitesseCoupe(); this.p.jouer('TreeChopping_Loop', { vitesse: v });
      const ph = this.p.phase(); if (this.ph < 0.5 && ph >= 0.5) { // l'instant où la hache frappe
        if (a.etat === 'debout') frapperArbre(a, this.pos, 1);
        else { this.charge += debiter(a, Math.min(this.capacite() - this.charge, 1 + Math.floor('EDCBAS'.indexOf(this.d.rang) / 2))); if (this.charge >= this.capacite() || a.bois <= 0) { this.etat = 'porter'; a.ouvriers = Math.max(0, a.ouvriers - 1); this.cible = null; } }
      }
      this.ph = ph; return;
    }
    if (this.etat === 'porter') {
      this.fagot.visible = true;
      const dest = V(RESERVE.x + Math.cos(this.d.id * 1.7) * 2.2, 0, RESERVE.z + Math.sin(this.d.id * 1.7) * 2.2);
      if (this.aller(dest, dt, this.R.vit * 0.75, 'Walk_Carry_Loop')) {
        this.fagot.visible = false; const n = this.charge; this.charge = 0; this.etat = 'chercher';
        j.ajouterBois(n, this); this.gagnerXp(n);
        this.p.jouer('PickUp_Table', { boucle: false, forcer: true, vitesse: 1.6, fin: () => { if (this.etat === 'chercher') this.p.jouer('Idle_Loop'); } });
        this.etat = 'depose'; this.t = 0.7;
      }
      return;
    }
    if (this.etat === 'depose') { this.t -= dt; if (this.t <= 0) this.etat = 'chercher'; }
  }
  lacher() { if (this.cible) this.cible.ouvriers = Math.max(0, this.cible.ouvriers - 1); this.cible = null; this.etat = this.charge > 0 ? 'porter' : 'chercher'; }
  gagnerXp(n) {
    const m = this.m; m.xp += n;
    while (m.xp >= xpNiveau(m.niv)) { m.xp -= xpNiveau(m.niv); m.niv++; texteFlottant(V(this.pos.x, this.pos.y + 2.6, this.pos.z), `Maîtrise du bois ${m.niv} !`, 'niveau'); son('jingles_PIZZI01', 0.35); emettre(V(this.pos.x, this.pos.y + 1, this.pos.z), { n: 30, c1: '#ffe9a0', c2: '#b36bff', vit: 3, vie: 0.9, taille: 0.18, grav: -1 }); this.dire(parole('niveau')); }
  }
  // ---------- suivre le souverain ----------
  majSuivre(dt, j, rang) {
    const ang = j.perso.root.rotation.y + Math.PI + (rang - 1.5) * 0.55, dist = 2.6 + Math.floor(rang / 4) * 1.4;
    const dest = V(j.pos.x + Math.sin(ang) * dist, 0, j.pos.z + Math.cos(ang) * dist);
    const d = Math.hypot(dest.x - this.pos.x, dest.z - this.pos.z);
    if (d > 30) { this.pos.set(dest.x, hauteur(dest.x, dest.z), dest.z); return; }
    if (d > 0.6) this.aller(dest, dt, d > 5 ? 6 : this.R.vit, d > 5 ? 'Jog_Fwd_Loop' : 'Walk_Loop');
    else { this.p.jouer('Idle_Loop'); this.tourner(j.perso.root.rotation.y, dt); }
  }
  majRepos(dt) { const dest = V(-1.5 + Math.cos(this.d.id * 1.3) * 3.2, 0, -1.5 + Math.sin(this.d.id * 1.3) * 3.2); if (this.aller(dest, dt, this.R.vit)) { this.p.jouer('Sitting_Idle_Loop'); this.tourner(Math.atan2(-1.5 - this.pos.x, -1.5 - this.pos.z), dt); } }
  maj(dt, j, rang) {
    this.p.maj(dt);
    if (this.scene) return this.scene(dt);
    if (this.d.metier !== 'bois') { if (this.cible) this.lacher(); this.charge = 0; this.fagot.visible = false; if (this.etat !== 'idle') this.etat = 'idle'; }
    if (this.d.metier === 'bois') this.majBois(dt, j);
    else if (this.d.metier === 'suivre') this.majSuivre(dt, j, rang);
    else this.majRepos(dt);
    if (Math.random() < dt * 6) emettre(V(this.pos.x + (Math.random() - 0.5) * 0.5, this.pos.y + 0.2, this.pos.z + (Math.random() - 0.5) * 0.5), { n: 1, c1: '#8a5aff', c2: '#1a0a30', vit: 0.3, vie: 0.8, taille: 0.22, grav: -1.2 });
  }
}
