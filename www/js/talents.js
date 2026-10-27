// ===== Arbres de talents : 3 branches par classe, 1 point par niveau de maîtrise de l'arme =====
// Chaque nœud : id, nom, ic (glyphe), max (rangs), e (effet par rang), rang (ligne 0..5), col (0..1 dans la branche),
// req (points à dépenser dans la branche pour l'atteindre), dep (nœud parent à avoir au moins à 1).
// Les « competence » débloquent un sort que l'on peut placer sur Q, W ou E.

import { SORTS } from './data.js';
const P = (txt) => txt; // texte d'effet, {v} = valeur cumulée
// branche commune « Puissance »
const PUISSANCE = (sp) => ({
  id: 'puissance', nom: 'Puissance', couleur: '#ff6a4a', ic: 'epee',
  noeuds: [
    { id: 'force', nom: 'Force brute', ic: 'poing', max: 5, rang: 0, col: 0, e: { deg: 0.03 }, txt: P('+{deg} % de dégâts') },
    { id: 'precision', nom: 'Œil du prédateur', ic: 'oeil', max: 5, rang: 0, col: 1, e: { crit: 1 }, txt: P('+{crit} % de chances de critique') },
    { id: 'cadence', nom: 'Cadence', ic: 'eclair', max: 5, rang: 1, col: 0, dep: 'force', e: { vitAtk: 0.03 }, txt: P('+{vitAtk} % de vitesse d’attaque') },
    { id: 'arcane', nom: sp.nomPuiss, ic: 'etoile', max: 5, rang: 1, col: 1, dep: 'precision', e: { sorts: 0.04 }, txt: P('+{sorts} % de dégâts de tous tes sorts') },
    { id: 'feroce', nom: 'Coups féroces', ic: 'griffe', max: 3, rang: 2, col: 0, dep: 'cadence', e: { critDeg: 0.1 }, txt: P('+{critDeg} % de dégâts critiques') },
    { id: 'gladiateur', nom: 'Instinct du gladiateur', ic: 'epees', max: 3, rang: 2, col: 1, dep: 'arcane', e: { pvp: 4 }, txt: P('+{pvp} % de dégâts contre les joueurs') },
    { id: 'concentration', nom: 'Concentration', ic: 'sablier', max: 5, rang: 3, col: 0, dep: 'feroce', e: { rech: 3 }, txt: P('−{rech} % de temps de recharge') },
    { id: 'soif', nom: 'Soif de bataille', ic: 'goutte', max: 3, rang: 3, col: 1, dep: 'gladiateur', e: { volVie: 0.02 }, txt: P('Tes coups te rendent {volVie} % des dégâts') },
    { id: 'execution', nom: 'Achèvement', ic: 'crane', max: 3, rang: 4, col: 0, dep: 'concentration', e: { achev: 0.08 }, txt: P('+{achev} % de dégâts contre les cibles sous 35 % de vie') },
    { id: 'fureur', nom: 'Fureur ancestrale', ic: 'flamme', max: 1, rang: 5, col: 0, dep: 'execution', e: { deg: 0.12, sorts: 0.08 }, txt: P('Capacité ultime : +12 % de dégâts et +8 % de dégâts des sorts'), ultime: true },
  ],
});
// branche commune « Robustesse »
const ROBUSTESSE = {
  id: 'robustesse', nom: 'Robustesse', couleur: '#5ab0ff', ic: 'bouclier',
  noeuds: [
    { id: 'vitalite', nom: 'Vitalité', ic: 'coeur', max: 5, rang: 0, col: 0, e: { pv: 0.04 }, txt: P('+{pv} % de points de vie') },
    { id: 'endurance', nom: 'Endurance', ic: 'goutteB', max: 5, rang: 0, col: 1, e: { energie: 0.06 }, txt: P('+{energie} % d’énergie maximale') },
    { id: 'peau', nom: 'Peau de fer', ic: 'bouclier', max: 5, rang: 1, col: 0, dep: 'vitalite', e: { armure: 0.05 }, txt: P('+{armure} % d’armure') },
    { id: 'recup', nom: 'Récupération', ic: 'feuille', max: 5, rang: 1, col: 1, dep: 'endurance', e: { regen: 0.2 }, txt: P('+{regen} % de régénération de vie') },
    { id: 'pas', nom: 'Pas léger', ic: 'aile', max: 3, rang: 2, col: 0, dep: 'peau', e: { vit: 0.02 }, txt: P('+{vit} % de vitesse de déplacement') },
    { id: 'souffle', nom: 'Souffle profond', ic: 'spirale', max: 3, rang: 2, col: 1, dep: 'recup', e: { enRegen: 0.15 }, txt: P('+{enRegen} % de récupération d’énergie') },
    { id: 'inebranlable', nom: 'Inébranlable', ic: 'tour', max: 5, rang: 3, col: 0, dep: 'pas', e: { reduc: 0.02 }, txt: P('−{reduc} % de dégâts subis') },
    { id: 'survie', nom: 'Instinct de survie', ic: 'coeurB', max: 3, rang: 3, col: 1, dep: 'souffle', e: { survie: 0.06 }, txt: P('Sous 30 % de vie : −{survie} % de dégâts subis') },
    { id: 'potion', nom: 'Alchimiste', ic: 'fiole', max: 3, rang: 4, col: 1, dep: 'survie', e: { potion: 0.12 }, txt: P('Les potions soignent {potion} % de plus') },
    { id: 'colosse', nom: 'Colosse', ic: 'montagne', max: 1, rang: 5, col: 1, dep: 'potion', e: { pv: 0.15, armure: 0.1 }, txt: P('Capacité ultime : +15 % de vie et +10 % d’armure'), ultime: true },
  ],
};
// spécialisation propre à chaque classe : améliorations des 3 sorts + 2 compétences à débloquer
function spec(classe, nom, couleur, sorts, alts, extra = []) {
  const [a, b, c] = sorts;
  const n = [
    { id: 'p_' + a.id, nom: a.nom + ' renforcé', ic: 'etoile', max: 5, rang: 0, col: 0, e: { ['s_' + a.id]: 0.1 }, txt: P(`+{s_${a.id}} % de dégâts pour ${a.nom}`) },
    { id: 'p_' + b.id, nom: b.nom + ' renforcé', ic: 'etoile', max: 5, rang: 0, col: 1, e: { ['s_' + b.id]: 0.1 }, txt: P(`+{s_${b.id}} % de dégâts pour ${b.nom}`) },
    { id: 'c_' + a.id, nom: a.nom + ' affûté', ic: 'sablier', max: 3, rang: 1, col: 0, dep: 'p_' + a.id, e: { ['cd_' + a.id]: 0.08 }, txt: P(`−{cd_${a.id}} % de recharge pour ${a.nom}`) },
    { id: 'p_' + c.id, nom: c.nom + ' renforcé', ic: 'etoile', max: 5, rang: 1, col: 1, dep: 'p_' + b.id, e: { ['s_' + c.id]: 0.1 }, txt: P(`+{s_${c.id}} % d’efficacité pour ${c.nom}`) },
    { id: 'k_' + alts[0], nom: SORTS[alts[0]].nom, ic: 'livre', max: 1, rang: 2, col: 0, dep: 'c_' + a.id, competence: alts[0], txt: P('Débloque une nouvelle compétence à placer sur Q, W ou E') },
    { id: 'c_' + c.id, nom: c.nom + ' maîtrisé', ic: 'sablier', max: 3, rang: 2, col: 1, dep: 'p_' + c.id, e: { ['cd_' + c.id]: 0.08 }, txt: P(`−{cd_${c.id}} % de recharge pour ${c.nom}`) },
    ...extra,
    { id: 'k_' + alts[1], nom: SORTS[alts[1]].nom, ic: 'livre', max: 1, rang: 4, col: 1, dep: extra.length ? extra[extra.length - 1].id : 'c_' + c.id, competence: alts[1], txt: P('Débloque une nouvelle compétence à placer sur Q, W ou E') },
    { id: 'ult_' + classe, nom: 'Éveil du ' + nom.toLowerCase(), ic: 'couronne', max: 1, rang: 5, col: 0, dep: 'k_' + alts[0], e: { sorts: 0.15, rech: 8 }, txt: P('Capacité ultime : +15 % de dégâts des sorts et −8 % de recharge'), ultime: true },
  ];
  return { id: 'spec', nom, couleur, ic: 'couronne', noeuds: n };
}
const S = (id, nom) => ({ id, nom });
const SPEC_EXTRA = (cl) => [
  { id: 'x_' + cl + '1', nom: 'Élan', ic: 'eclair', max: 3, rang: 3, col: 0, dep: 'k_' + ALTS[cl][0], e: { deg: 0.03, vitAtk: 0.02 }, txt: P('+{deg} % de dégâts et +{vitAtk} % de vitesse d’attaque') },
  { id: 'x_' + cl + '2', nom: 'Volonté de fer', ic: 'tour', max: 3, rang: 3, col: 1, dep: 'c_' + SORTS_CL[cl][2].id, e: { pv: 0.03, reduc: 0.015 }, txt: P('+{pv} % de vie et −{reduc} % de dégâts subis') },
];
export const SORTS_CL = {
  epee: [S('fente', 'Fente sanglante'), S('charge', 'Charge héroïque'), S('tempete', 'Tempête d’acier')],
  arbalete: [S('perforant', 'Carreau perforant'), S('roulade', 'Roulade'), S('pluie', 'Pluie de carreaux')],
  baton: [S('bouleFeu', 'Boule de feu'), S('colonne', 'Colonne de flammes'), S('meteore', 'Météore')],
  arc: [S('tirArc', 'Flèche écarlate'), S('meute', 'Meute'), S('frenesie', 'Frénésie sauvage')],
  ombre: [S('legion', 'Légion d’ombres'), S('reflet', 'Reflet volé'), S('pasOmbre', 'Pas de l’ombre')],
  orage: [S('tornade', 'Œil du cyclone'), S('titan', 'Chute du Titan'), S('orage', 'Colère de l’Orage')],
  assassin: [S('triple', 'Triple entaille'), S('curee', 'Curée'), S('zephyr', 'Pas du zéphyr')],
  esprit: [S('emprise', 'Emprise'), S('lames', 'Trois lames'), S('onde', 'Onde de force')],
};
export const ALTS = {
  epee: ['execution', 'vampirisme'], arbalete: ['tirMultiple', 'purge'], baton: ['novaGivre', 'purge'], arc: ['pluieEcarlate', 'vampirisme'],
  ombre: ['execution', 'vampirisme'], orage: ['execution', 'purge'], assassin: ['vampirisme', 'purge'], esprit: ['purge', 'vampirisme'],
};
const NOMS_SPEC = { esprit: ['Télékinésiste', '#c08aff', 'Volonté pure'], epee: ['Champion', '#ffb04a', 'Puissance martiale'], arbalete: ['Tireur d’élite', '#7aff9a', 'Balistique'], baton: ['Pyromancien', '#ff7a2a', 'Puissance des flammes'], arc: ['Maître des bêtes', '#ff3a3a', 'Instinct sauvage'], ombre: ['Ombrelame', '#b07aff', 'Puissance des ombres'], orage: ['Seigneur de l’orage', '#7ab8ff', 'Puissance de la foudre'], assassin: ['Assassin', '#ff5a6a', 'Précision mortelle'] };

// spécialisation des trois lames (remplace les deux nœuds « extra » de l'Esprit)
const LAMES = [
  { id: 'tranchant', nom: 'Lames affûtées', ic: 'epees', max: 5, rang: 3, col: 0, dep: 'k_purge', e: { lameDeg: 0.12 }, txt: P('+{lameDeg} % de dégâts de tes lames') },
  { id: 'trempe', nom: 'Trempe spectrale', ic: 'bouclier', max: 5, rang: 3, col: 1, dep: 'c_onde', e: { lamePv: 0.15 }, txt: P('+{lamePv} % de solidité de tes lames (elles parent plus de coups)') },
  { id: 'vol', nom: 'Vol fulgurant', ic: 'aile', max: 3, rang: 4, col: 0, dep: 'tranchant', e: { lameVit: 0.1 }, txt: P('+{lameVit} % de vitesse de tes lames (assaut et exploration)') },
];
// spécialisation de la meute (remplace les deux nœuds « extra »)
const MEUTE = [
  { id: 'crocs', nom: 'Crocs aiguisés', ic: 'griffe', max: 5, rang: 3, col: 0, dep: 'k_pluieEcarlate', e: { loupDeg: 0.1 }, txt: P('+{loupDeg} % de dégâts de tes loups') },
  { id: 'fourrure', nom: 'Fourrure d’acier', ic: 'bouclier', max: 5, rang: 3, col: 1, dep: 'c_frenesie', e: { loupPv: 0.1, loupArm: 0.02 }, txt: P('+{loupPv} % de vie et +{loupArm} % de réduction de dégâts pour tes loups') },
  { id: 'chef', nom: 'Chef de meute', ic: 'loup', max: 3, rang: 4, col: 0, dep: 'crocs', e: { loupVit: 0.05, loupTaunt: 1.5 }, txt: P('+{loupVit} % de vitesse pour tes loups, rayon de provocation +{loupTaunt} m') },
];

const cache = {};
export function arbreDe(classe) {
  if (cache[classe]) return cache[classe];
  const cl = SORTS_CL[classe] ? classe : 'epee';
  const [nom, coul, nomPuiss] = NOMS_SPEC[cl];
  const branches = [PUISSANCE({ nomPuiss }), ROBUSTESSE, spec(cl, nom, coul, SORTS_CL[cl], ALTS[cl], cl === 'arc' ? MEUTE : cl === 'esprit' ? LAMES : SPEC_EXTRA(cl))];
  // exigence de points dans la branche : 3 par ligne
  for (const b of branches) for (const n of b.noeuds) n.req = n.rang * 3;
  return (cache[classe] = { classe: cl, branches });
}
export const pointsTotaux = (niv) => Math.max(0, niv); // 1 point par niveau de maîtrise
export function pointsDepenses(t) { return Object.values(t || {}).reduce((a, b) => a + b, 0); }
export function pointsBranche(t, branche) { let s = 0; for (const n of branche.noeuds) s += (t && t[n.id]) || 0; return s; }
// un nœud peut-il recevoir un point ?
export function peutMonter(t, arbre, branche, n, dispo) {
  const r = (t && t[n.id]) || 0;
  if (r >= n.max) return { ok: false, raison: 'Rang maximum' };
  if (dispo <= 0) return { ok: false, raison: 'Plus de points : monte ta maîtrise de niveau' };
  if (pointsBranche(t, branche) < n.req) return { ok: false, raison: `Dépense ${n.req} points dans « ${branche.nom} » pour débloquer cette ligne` };
  if (n.dep && !((t && t[n.dep]) > 0)) { const p = branche.noeuds.find(x => x.id === n.dep); return { ok: false, raison: `Nécessite « ${p ? p.nom : n.dep} »` }; }
  return { ok: true };
}
// cumul des effets : { deg, crit, vitAtk, sorts, ..., s_<sort>, cd_<sort>, competences: [] }
export function effetsTalents(t, classe) {
  const out = { competences: [] }; if (!t) return out;
  for (const b of arbreDe(classe).branches) for (const n of b.noeuds) {
    const r = t[n.id] || 0; if (!r) continue;
    if (n.competence) out.competences.push(n.competence);
    if (n.e) for (const k in n.e) out[k] = (out[k] || 0) + n.e[k] * r;
  }
  return out;
}
// texte d'un nœud au rang r (valeurs en %)
export function texteNoeud(n, r) {
  const pct = (k) => ['crit', 'pvp', 'rech', 'loupTaunt'].includes(k) ? 1 : 100;
  return n.txt.replace(/\{(\w+)\}/g, (_, k) => { const v = (n.e && n.e[k] || 0) * Math.max(1, r) * pct(k); return Number.isInteger(v) ? v : v.toFixed(1).replace('.', ','); });
}
