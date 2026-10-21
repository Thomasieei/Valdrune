import { TIERS, QUALITES, ARMES, ARMURES, BUTINS, SORTS, COFFRES, tf, NIVEAU_REQUIS, VARIANTES, PRIX_TROPHEES } from './data.js';

// maîtrise courante du joueur (niveaux par arme / pièce d'armure)
export const ETAT = { maitrise: null };

let uid = Date.now() % 100000;
const rnd = (a, b) => a + Math.random() * (b - a);
const ri = (a, b) => Math.floor(rnd(a, b + 1));

export function creerArme(type, tier, qualite = 0) {
  return { id: ++uid, cat: 'arme', type, tier, q: qualite };
}
export function creerArmure(slot, tier, qualite = 0) {
  return { id: ++uid, cat: 'armure', type: slot, tier, q: qualite };
}
export function creerButin(bid, n = 1) {
  return { id: ++uid, cat: 'butin', type: bid, tier: 0, q: 0, n };
}
export function creerPotion(n = 1) { return { id: ++uid, cat: 'potion', type: 'soin', tier: 0, q: 0, n }; }

export function nomObjet(it) {
  const suf = it.arene ? ' ' + VARIANTES[it.arene].suffixe : '';
  if (it.cat === 'arme') return ARMES[it.type].noms[it.tier] + suf;
  if (it.cat === 'armure') return ARMURES[it.type].noms[it.tier] + suf;
  if (it.cat === 'butin') return BUTINS.find(b => b.id === it.type).nom;
  if (it.cat === 'potion') return 'Potion de soin';
  return '?';
}
export function couleurObjet(it) {
  if (it.cat === 'butin') return BUTINS.find(b => b.id === it.type).color;
  if (it.cat === 'potion') return '#ff5a6a';
  return TIERS[it.tier].color;
}
export function categorieLabel(it) {
  if (it.cat === 'arme') return ARMES[it.type].label;
  if (it.cat === 'armure') return ARMURES[it.type].label;
  if (it.cat === 'butin') return 'Butin sans valeur';
  return 'Consommable';
}
export function puissanceObjet(it) {
  if (it.cat !== 'arme' && it.cat !== 'armure') return 0;
  return 300 + (it.tier - 1) * 100 + QUALITES[it.q].ip;
}
export function valeurObjet(it) {
  if (it.cat === 'butin') return BUTINS.find(b => b.id === it.type).valeur;
  if (it.cat === 'potion') return 60;
  const base = it.cat === 'arme' ? 180 : 120;
  return Math.round(base * Math.pow(2.6, it.tier - 1) * QUALITES[it.q].mult * (it.arene ? 1.2 : 1));
}
export const prixVente = (it) => Math.max(1, Math.round(valeurObjet(it) * (it.cat === 'butin' ? 1 : 0.35)));

// ---- Maîtrise ----
export const niveauRequis = (it) => NIVEAU_REQUIS[it.tier] || 1;
export function xpPour(n) {
  if (n >= 100) return Infinity;
  if (n < 50) return Math.round(25 * Math.pow(n, 1.4));
  return Math.round(25 * Math.pow(49, 1.4) * Math.pow(1.1, n - 49));
}
// +0,2 % de puissance brute par niveau, puis +2 % par niveau du 90 au 100
export const bonusMaitrise = (niv) => Math.max(0, niv - 1) * 0.002 + Math.max(0, niv - 90) * 0.02;
export function niveauDe(type) { return (ETAT.maitrise && ETAT.maitrise[type] && ETAT.maitrise[type].niv) || 1; }
export function peutPorter(it) { return it.cat !== 'arme' && it.cat !== 'armure' ? true : niveauDe(it.type) >= niveauRequis(it); }
export function tierMaxPour(niv) { let t = 1; for (let i = 1; i <= 8; i++) if (niv >= NIVEAU_REQUIS[i]) t = i; return t; }

export function statsObjet(it, niv = null) {
  const q = QUALITES[it.q]?.mult ?? 1;
  const n = niv ?? niveauDe(it.type);
  const bm = 1 + bonusMaitrise(n);
  const v = it.arene ? VARIANTES[it.arene] : null;
  if (it.cat === 'arme') {
    const a = ARMES[it.type]; const m = v ? v.arme : { degats: 1, crit: 0, vitesse: 1 };
    const degats = Math.round(a.base * tf(it.tier) * q * m.degats * bm);
    const crit = +(5 + it.tier * 0.75 + m.crit).toFixed(1);
    const vitesse = +(a.vitesse * m.vitesse).toFixed(2);
    const s = { degats, vitesse, crit, portee: a.portee, dps: Math.round(degats * vitesse * (1 + crit / 200)) };
    if (m.pv) s.pv = Math.round(m.pv * tf(it.tier));
    if (v) s.pvp = 10;
    return s;
  }
  if (it.cat === 'armure') {
    const a = ARMURES[it.type]; const m = v ? v.armure : { armure: 1, pv: 1 };
    const s = { armure: Math.round(a.armure * tf(it.tier) * q * m.armure * bm), pv: Math.round(a.pv * tf(it.tier) * q * m.pv * bm) };
    if (it.type === 'bottes') s.vitesse = +(2 + it.tier * 1.2).toFixed(1);
    if (it.type === 'casque') s.regen = +(0.4 + it.tier * 0.12).toFixed(2);
    if (m.bonusDeg) s.bonusDeg = m.bonusDeg;
    if (m.recharge) s.recharge = m.recharge;
    if (v) s.pvp = 10;
    return s;
  }
  return {};
}

export function sortsArme(it) {
  const ids = [...ARMES[it.type].sorts];
  if (it.arene) { const [t, id] = VARIANTES[it.arene].remplace[it.type]; ids['QWE'.indexOf(t)] = id; }
  return ids;
}
export function sortsObjet(it) {
  if (it.cat === 'arme') return sortsArme(it).map((s, i) => ({ touche: 'QWE'[i], ...SORTS[s], id: s }));
  if (it.cat === 'armure') {
    const s = ARMURES[it.type].sort; const touche = { plastron: 'R', casque: 'D', bottes: 'F' }[it.type];
    return [{ touche, ...SORTS[s], id: s }];
  }
  return [];
}

// ---- Statistiques du héros ----
export function statsHeros(equip, avecMaitrise = true) {
  const s = { pvMax: 650, energieMax: 220, armure: 0, degats: 12, vitesseAtk: 1, crit: 5, portee: 2.2, vitesse: 5.2, regen: 0.6, ip: 0, bonusDeg: 0, recharge: 0, pvp: 0 };
  let ipSum = 0, ipN = 0;
  for (const slot of ['arme', 'casque', 'plastron', 'bottes']) {
    const it = equip[slot]; if (!it) continue;
    const st = avecMaitrise ? statsObjet(it) : statsObjet(it, 1);
    ipSum += puissanceObjet(it) + (avecMaitrise ? Math.floor((niveauDe(it.type) - 1) / 2) + Math.max(0, niveauDe(it.type) - 90) * 10 : 0); ipN++;
    if (slot === 'arme') { s.degats = st.degats; s.vitesseAtk = st.vitesse; s.crit = st.crit; s.portee = st.portee; s.energieMax += it.tier * 15; if (st.pv) s.pvMax += st.pv; }
    else { s.armure += st.armure; s.pvMax += st.pv; if (st.vitesse) s.vitesse *= 1 + st.vitesse / 100; if (st.regen) s.regen += st.regen; }
    if (st.bonusDeg) s.bonusDeg += st.bonusDeg; if (st.recharge) s.recharge += st.recharge; if (st.pvp) s.pvp += st.pvp;
  }
  s.ip = ipN ? Math.round(ipSum / 4) : 0;
  s.degats = Math.round(s.degats * (1 + s.bonusDeg / 100));
  s.reduction = s.armure / (s.armure + 320);
  s.dps = Math.round(s.degats * s.vitesseAtk * (1 + s.crit / 200));
  return s;
}

// ---- Tirages de butin ----
function tirerQualite(bonus = 0) {
  const r = Math.random() * 100 - bonus;
  if (r < 2) return 4; if (r < 8) return 3; if (r < 22) return 2; if (r < 45) return 1; return 0;
}
function objetAleatoire(tier, bonusQ = 0) {
  const r = Math.random();
  const q = tirerQualite(bonusQ);
  if (r < 0.45) return creerArme(['epee', 'arbalete', 'baton'][ri(0, 2)], tier, q);
  return creerArmure(['casque', 'plastron', 'bottes'][ri(0, 2)], tier, q);
}
export function tirerCouleurCoffre() {
  let r = Math.random() * 100;
  for (const c of COFFRES) { if ((r -= c.chance) < 0) return c.id; }
  return 'vert';
}
export function lootCoffre(couleur, mode, idxBoss) {
  const [tMin, tMax] = mode.tiers;
  const out = { argent: 0, objets: [] };
  const tierSelon = (biais) => {
    const span = tMax - tMin; let t = tMin + Math.floor(Math.pow(Math.random(), 1 / (1 + biais)) * (span + 1));
    return Math.min(tMax, Math.max(tMin, t));
  };
  const scale = (mode.argent || 1) * (1 + idxBoss * 0.15);
  if (couleur === 'vert') {
    out.argent = Math.round(rnd(10, 22) * scale);
    for (let i = 0; i < ri(2, 3); i++) out.objets.push(creerButin(BUTINS[ri(0, 2)].id, ri(1, 3)));
    if (Math.random() < 0.18) out.objets.push(objetAleatoire(tMin, -10));
  } else if (couleur === 'bleu') {
    out.argent = Math.round(rnd(28, 50) * scale);
    out.objets.push(objetAleatoire(tierSelon(0), 0));
    if (Math.random() < 0.5) out.objets.push(objetAleatoire(tMin, 0));
    out.objets.push(creerButin(BUTINS[ri(1, 3)].id, ri(1, 2)));
    if (Math.random() < 0.4) out.objets.push(creerPotion(1));
  } else if (couleur === 'violet') {
    out.argent = Math.round(rnd(70, 120) * scale);
    out.objets.push(objetAleatoire(tierSelon(0.8), 12));
    out.objets.push(objetAleatoire(tierSelon(0.4), 8));
    if (Math.random() < 0.45) out.objets.push(objetAleatoire(tierSelon(0.4), 8));
    out.objets.push(creerButin(BUTINS[ri(3, 4)].id, 1));
    out.objets.push(creerPotion(ri(1, 2)));
  } else {
    out.argent = Math.round(rnd(180, 300) * scale);
    out.objets.push(objetAleatoire(tMax, 30));
    out.objets.push(objetAleatoire(tierSelon(1.5), 25));
    out.objets.push(objetAleatoire(tierSelon(1.0), 20));
    if (Math.random() < 0.5) out.objets.push(objetAleatoire(tierSelon(1.0), 20));
    out.objets.push(creerButin('rune', ri(1, 3)));
    out.objets.push(creerPotion(2));
  }
  return out;
}
export function lootMonstre(mode) {
  const out = { argent: Math.round(rnd(1, 3) * (mode.argent || 1)), objets: [] };
  if (Math.random() < 0.22) out.objets.push(creerButin(BUTINS[ri(0, 2)].id, 1));
  if (Math.random() < 0.035) out.objets.push(objetAleatoire(mode.tiers[0], -15));
  return out;
}

// ---- Stock du marchand ----
export function stockMarchand() {
  const out = [];
  for (let t = 1; t <= 4; t++) {
    for (const ty of ['epee', 'arbalete', 'baton']) out.push(creerArme(ty, t, 0));
    for (const s of ['casque', 'plastron', 'bottes']) out.push(creerArmure(s, t, 0));
    if (t <= 3) { out.push(creerArme(['epee', 'arbalete', 'baton'][t - 1], t, 1)); }
  }
  out.push(creerPotion(1));
  return out;
}

// ---- Boutique de l'arène ----
export function stockArene() {
  const out = [];
  for (const v of Object.keys(VARIANTES)) for (let t = 5; t <= 8; t++) {
    for (const ty of ['epee', 'arbalete', 'baton']) out.push({ ...creerArme(ty, t, 2), arene: v });
    for (const sl of ['casque', 'plastron', 'bottes']) out.push({ ...creerArmure(sl, t, 2), arene: v });
  }
  return out;
}
export const prixTrophees = (it) => PRIX_TROPHEES[it.tier] * (it.cat === 'arme' ? 1.4 : 1);
