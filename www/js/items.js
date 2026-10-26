import { CLASSES_BASE, VALEUR_MAT, TIERS, QUALITES, ARMES, ARMURES, BUTINS, SORTS, COFFRES, tf, NIVEAU_REQUIS, VARIANTES, PRIX_TROPHEES, PARCHEMINS, COULEURS_PARCH } from './data.js';

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
export function creerButin(bid, n = 1, tier = 0) {
  return { id: ++uid, cat: 'butin', type: bid, tier, q: 0, n };
}
export function creerParchemin(id, n = 1) { return { id: ++uid, cat: 'parchemin', type: id, tier: 0, q: 0, n }; }
export function creerPotion(n = 1) { return { id: ++uid, cat: 'potion', type: 'soin', tier: 0, q: 0, n }; }

export function nomObjet(it) {
  const suf = it.arene ? ' ' + VARIANTES[it.arene].suffixe : '';
  const en = it.ench ? ' +' + it.ench : '';
  if (it.cat === 'arme') return ARMES[it.type].noms[it.tier] + suf + en;
  if (it.cat === 'armure') return ARMURES[it.type].noms[it.tier] + suf + en;
  if (it.cat === 'butin') return BUTINS.find(b => b.id === it.type).nom;
  if (it.cat === 'potion') return 'Potion de soin';
  if (it.cat === 'parchemin') { const p = PARCHEMINS[it.type]; return `Parchemin de ${COULEURS_PARCH[p.couleur].nom} +${Math.round(p.bonus * 100)} %`; }
  return '?';
}
export function couleurObjet(it) {
  if (it.cat === 'butin') return it.tier ? TIERS[it.tier].color : BUTINS.find(b => b.id === it.type).color;
  if (it.cat === 'potion') return '#ff5a6a';
  if (it.cat === 'parchemin') return COULEURS_PARCH[PARCHEMINS[it.type].couleur].c2;
  return TIERS[it.tier].color;
}
export function categorieLabel(it) {
  if (it.cat === 'arme') return ARMES[it.type].label + (ARMES[it.type].rare ? (it.beta ? ' · ✦ Bêta' : it.type === 'orage' ? ' · ⚡ Classe légendaire (1 % en Cauchemar)' : it.type === 'assassin' ? ' · 🗡 Classe d’élite' : ' · ✦ Classe rare (0,1 %)') : '');
  if (it.cat === 'armure') return ARMURES[it.type].label;
  if (it.cat === 'parchemin') return 'Parchemin · Brèche uniquement';
  if (it.cat === 'butin') return it.type === 'rune' ? 'Matériau d’enchantement' : BUTINS.find(b => b.id === it.type).mat ? 'Marchandise · se revend au marché' : 'Butin sans valeur';
  return 'Consommable';
}
export function puissanceObjet(it) {
  if (it.cat !== 'arme' && it.cat !== 'armure') return 0;
  return 300 + (it.tier - 1) * 100 + QUALITES[it.q].ip + (it.ench || 0) * 50;
}
// prix de marché par tier (fourchettes voulues) : la qualité, l'enchantement et la rareté placent l'objet dans la fourchette
// en haut, chaque tier coûte environ le double du précédent : un T8 se mérite
export const PRIX_TIER = [null, [2000, 10000], [50000, 100000], [100000, 250000], [250000, 600000], [600000, 1000000], [1000000, 1800000], [1800000, 3500000], [3500000, 10000000]];
export function valeurObjet(it) {
  if (it.cat === 'butin') { const b = BUTINS.find(x => x.id === it.type); return b.mat ? Math.round(VALEUR_MAT[it.tier || 1] * b.mat) : b.valeur; }
  if (it.cat === 'potion') return 2500;
  if (it.cat === 'parchemin') return PARCHEMINS[it.type].prix;
  const [mn, mx] = PRIX_TIER[it.tier];
  const rare = ARMES[it.type] && ARMES[it.type].rare ? (it.type === 'orage' ? 0.3 : 0.2) : 0;
  let f = 0.12 + (it.q || 0) / 4 * 0.4 + (it.ench || 0) / 6 * 0.38 + rare + (it.arene ? 0.08 : 0) + (it.cat === 'arme' ? 0.04 : 0);
  f = Math.max(0, Math.min(1, f));
  const v = it.tier === 8 ? mn * Math.pow(mx / mn, f * f) : mn + (mx - mn) * f; // en T8 les meilleures pièces montent jusqu'à 10 M
  return Math.round(v / 100) * 100;
}
// revente : marchandises au prix plein, équipement à 20 % (le butin rapporte surtout via l'argent des coffres)
export const prixVente = (it) => Math.max(1, Math.round(valeurObjet(it) * (it.cat === 'butin' ? 1 : it.cat === 'arme' || it.cat === 'armure' ? 0.2 : 0.35)));

// ---- Maîtrise ----
export const niveauRequis = (it) => NIVEAU_REQUIS[it.tier] || 1;
// courbe d'expérience calée sur le temps de jeu : niv. 29 ≈ 7 h, niv. 60 ≈ 105 h, niv. 70 ≈ 240 h,
// niv. 90 (T8) ≈ 1 200 h, soit 4 mois à 10 h par jour. Heures par niveau × XP gagnée par heure dans la zone adaptée.
const XP_HEURE = (n) => n < 40 ? 9000 : n < 70 ? 45000 : 125000;
export function xpPour(n) {
  if (n >= 100) return Infinity;
  return Math.round(0.06 * Math.exp(0.083914 * (n - 1)) * XP_HEURE(n));
}
// +0,2 % de puissance brute par niveau, puis +2 % par niveau du 90 au 100
// le niveau compte vraiment : +3,5 % de puissance par niveau (+3 % de plus après 90). Niv. 29 ≈ +98 %, niv. 10 ≈ +31 %
export const bonusMaitrise = (niv) => Math.max(0, niv - 1) * 0.035 + Math.max(0, niv - 90) * 0.03;
// niveau du héros affiché : moyenne des maîtrises de ce qu'il porte
export function niveauHeros(equip) { const l = ['arme', 'casque', 'plastron', 'bottes'].map(s => equip[s]).filter(Boolean).map(it => niveauDe(it.type)); return l.length ? Math.round(l.reduce((a, b) => a + b, 0) / l.length) : 1; }
export function niveauDe(type) { return (ETAT.maitrise && ETAT.maitrise[type] && ETAT.maitrise[type].niv) || 1; }
export function peutPorter(it) { return it.cat !== 'arme' && it.cat !== 'armure' ? true : niveauDe(it.type) >= niveauRequis(it); }
export function tierMaxPour(niv) { let t = 1; for (let i = 1; i <= 8; i++) if (niv >= NIVEAU_REQUIS[i]) t = i; return t; }

export function statsObjet(it, niv = null) {
  const q = QUALITES[it.q]?.mult ?? 1;
  const n = niv ?? niveauDe(it.type);
  const bm = 1 + bonusMaitrise(n);
  const v = it.arene ? VARIANTES[it.arene] : null;
  const te = it.tier + (it.ench || 0) * 0.5; // 2 enchantements = 1 tier
  if (it.cat === 'arme') {
    const a = ARMES[it.type]; const m = v ? v.arme : { degats: 1, crit: 0, vitesse: 1 };
    const degats = Math.round(a.base * tf(te) * q * m.degats * bm);
    const crit = +(5 + te * 0.75 + m.crit).toFixed(1);
    const vitesse = +(a.vitesse * m.vitesse).toFixed(2);
    const s = { degats, vitesse, crit, portee: a.portee, dps: Math.round(degats * vitesse * (1 + crit / 200)) };
    if (m.pv) s.pv = Math.round(m.pv * tf(te));
    if (v) s.pvp = 10;
    return s;
  }
  if (it.cat === 'armure') {
    const a = ARMURES[it.type]; const m = v ? v.armure : { armure: 1, pv: 1 };
    const s = { armure: Math.round(a.armure * tf(te) * q * m.armure * bm), pv: Math.round(a.pv * tf(te) * q * m.pv * bm) };
    if (it.type === 'bottes') s.vitesse = +(2 + te * 1.2).toFixed(1);
    if (it.type === 'casque') s.regen = +(0.4 + te * 0.12).toFixed(2);
    if (m.bonusDeg) s.bonusDeg = m.bonusDeg;
    if (m.recharge) s.recharge = m.recharge;
    if (v) s.pvp = 10;
    return s;
  }
  return {};
}

export function sortsArme(it) {
  const ids = [...ARMES[it.type].sorts];
  if (it.arene) { const r = VARIANTES[it.arene].remplace[it.type]; if (r) ids['QWE'.indexOf(r[0])] = r[1]; }
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
    const nv = typeof avecMaitrise === 'number' ? avecMaitrise : avecMaitrise ? niveauDe(it.type) : 1;
    const st = statsObjet(it, nv);
    ipSum += puissanceObjet(it) + Math.floor((nv - 1) * 3) + Math.max(0, nv - 90) * 10; ipN++;
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
  if (r < 0.45) return creerArme(CLASSES_BASE[ri(0, 3)], tier, q);
  return creerArmure(['casque', 'plastron', 'bottes'][ri(0, 2)], tier, q);
}
export function tirerCouleurCoffre() {
  let r = Math.random() * 100;
  for (const c of COFFRES) { if ((r -= c.chance) < 0) return c.id; }
  return 'vert';
}
export function lootCoffre(couleur, mode, idxBoss, rang = 0) {
  const [tMin, tMax] = mode.tiers;
  const out = { argent: 0, objets: [] };
  const tierSelon = (biais) => {
    const span = tMax - tMin; let t = tMin + Math.floor(Math.pow(Math.random(), 1 / (1 + biais + rang * 0.2)) * (span + 1));
    return Math.min(tMax, Math.max(tMin, t));
  };
  // argent des coffres : zone 1 (T1-T2) ×1, zone 2 (T3-T5) ×2, zone 3 (T6-T8) ×3
  const zone = tMax <= 2 ? 1 : tMax <= 5 ? 2 : 3;
  const scale = zone * (1 + idxBoss * 0.05) * (mode.mult || 1);
  if (couleur === 'vert') {
    out.argent = Math.round(rnd(9000, 25000) * scale);
    if (Math.random() < 0.18) out.objets.push(objetAleatoire(tMin, -10));
  } else if (couleur === 'bleu') {
    out.argent = Math.round(rnd(25000, 50000) * scale);
    out.objets.push(objetAleatoire(tierSelon(0), 0));
    if (Math.random() < 0.5) out.objets.push(objetAleatoire(tMin, 0));
    if (Math.random() < 0.4) out.objets.push(creerPotion(1));
  } else if (couleur === 'violet') {
    out.argent = Math.round(rnd(100000, 200000) * scale);
    out.objets.push(objetAleatoire(tierSelon(0.8), 12));
    out.objets.push(objetAleatoire(tierSelon(0.4), 8));
    if (Math.random() < 0.45) out.objets.push(objetAleatoire(tierSelon(0.4), 8));
    out.objets.push(creerButin('rune', 1));
    out.objets.push(creerPotion(ri(1, 2)));
  } else {
    out.argent = Math.round(rnd(285000, 330000) * scale);
    out.objets.push(objetAleatoire(tMax, 30));
    out.objets.push(objetAleatoire(tierSelon(1.5), 25));
    out.objets.push(objetAleatoire(tierSelon(1.0), 20));
    if (Math.random() < 0.5) out.objets.push(objetAleatoire(tierSelon(1.0), 20));
    out.objets.push(creerButin('rune', ri(1, 3)));
    out.objets.push(creerPotion(2));
  }
  // zone 3 : moins de pièces d'équipement par coffre (elles valent très cher)
  if (zone >= 2) out.objets = out.objets.filter(it => !(it.cat === 'arme' || it.cat === 'armure') || Math.random() < (zone === 3 ? 0.35 : 0.7));
  // marchandises : des piles d'éclats, sceaux, amulettes et tomes (valeur ≈ 40 à 90 % de l'argent du coffre)
  {
    const budget = out.argent * rnd(0.4, 0.9) * (couleur === 'legendaire' ? 1.4 : 1);
    const nPiles = couleur === 'vert' ? ri(2, 3) : couleur === 'bleu' ? ri(3, 4) : ri(4, 6);
    const sortes = ['eclat', 'sceau', 'eclat', 'sceau', 'relique', 'tome'];
    const piles = new Map();
    for (let k = 0; k < nPiles; k++) {
      const sorte = couleur === 'vert' ? sortes[ri(0, 3)] : sortes[ri(0, 5)];
      const t = tierSelon(couleur === 'legendaire' ? 1.2 : couleur === 'violet' ? 0.6 : 0);
      const unite = VALEUR_MAT[t] * BUTINS.find(b => b.id === sorte).mat;
      const n = Math.max(1, Math.round(budget / nPiles / unite));
      const cle = sorte + t; if (piles.has(cle)) piles.get(cle).n += n; else piles.set(cle, creerButin(sorte, n, t));
    }
    out.objets.push(...piles.values());
  }
  // rang (Argent, Or…) : objets de meilleure qualité et chance d'objet bonus
  if (rang > 0) {
    for (const it of out.objets) if (it.q !== undefined && Math.random() < 0.06 * rang) it.q = Math.min(QUALITES.length - 1, it.q + 1);
    if (couleur !== 'vert' && Math.random() < 0.08 * rang) out.objets.push(objetAleatoire(tierSelon(rang * 0.3), 6 * rang));
    if (Math.random() < 0.05 * rang) out.objets.push(creerButin('rune', 1));
  }
  return out;
}
export function lootMonstre(mode) {
  const zone = mode.tiers[1] <= 2 ? 1 : mode.tiers[1] <= 5 ? 2 : 3;
  const out = { argent: Math.round(rnd(80, 250) * zone * (mode.mult || 1)), objets: [] };
  if (Math.random() < 0.22) out.objets.push(creerButin(Math.random() < 0.6 ? 'eclat' : 'sceau', ri(1, 3), mode.tiers[0]));
  if (Math.random() < 0.035) out.objets.push(objetAleatoire(mode.tiers[0], -15));
  return out;
}

// ---- Stock du marchand ----
// toutes les armes et armures, du T1 au T8 (les Dagues des Ombres seulement pour ceux qui ont débloqué la classe)
export function stockMarchand(rares = []) {
  const out = [];
  for (let t = 1; t <= 8; t++) {
    for (const ty of [...CLASSES_BASE, ...rares]) out.push(creerArme(ty, t, 0));
    for (const s of ['casque', 'plastron', 'bottes']) out.push(creerArmure(s, t, 0));
  }
  out.push(creerPotion(1), creerButin('rune', 1));
  return out;
}
// ---- Enchantement (runes) : jusqu'à +6, deux enchantements valent un tier ----
export const ENCH_MAX = 6;
export function coutEnchant(it) {
  const e = it.ench || 0; if (e >= ENCH_MAX) return null;
  // de plus en plus ruineux : ×3,2 à chaque palier
  // le prix suit la valeur de l'objet : enchanter coûte une part de ce qu'il vaut, puis de plus en plus
  const base = valeurObjet({ ...it, ench: 0 });
  return { runes: (e + 1) * (e + 1) * (1 + Math.ceil(it.tier / 2)), argent: Math.round(base * [0.25, 0.4, 0.6, 0.9, 1.3, 1.8][e] / 100) * 100, chance: [1, 0.85, 0.7, 0.55, 0.4, 0.28][e] };
}

// ---- Boutique de l'arène ----
export function stockArene() {
  const out = [];
  for (const v of Object.keys(VARIANTES)) for (let t = 5; t <= 8; t++) {
    for (const ty of CLASSES_BASE) out.push({ ...creerArme(ty, t, 2), arene: v });
    for (const sl of ['casque', 'plastron', 'bottes']) out.push({ ...creerArmure(sl, t, 2), arene: v });
  }
  return out;
}
export const prixTrophees = (it) => PRIX_TROPHEES[it.tier] * (it.cat === 'arme' ? 1.4 : 1);
