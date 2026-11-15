/* UMBRA — contenu du jeu : raretés, armes, reliques, accessoires, mondes, ennemis */
export const rnd = (a, b) => a + Math.random() * (b - a);
export const irnd = (a, b) => Math.floor(rnd(a, b + 1));
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const pick = a => a[Math.floor(Math.random() * a.length)];

const SUF = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', 'UDc', 'DDc', 'TDc'];
export function fmt(n) {
  if (!isFinite(n)) return '∞'; if (n < 0) return '-' + fmt(-n);
  if (n < 1000) return n < 10 && n % 1 ? n.toFixed(1) : Math.floor(n).toString();
  const e = Math.floor(Math.log10(n) / 3);
  if (e < SUF.length) { const v = n / Math.pow(1000, e); return (v < 100 ? v.toFixed(2) : v.toFixed(1)) + SUF[e]; }
  const ex = Math.floor(Math.log10(n)); return (n / Math.pow(10, ex)).toFixed(2) + 'e' + ex;
}
export function fmtTime(s) { s = Math.max(0, Math.floor(s)); const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60; return h ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}m ${String(s % 60).padStart(2, '0')}s`; }

/* ---------- raretés (cadres, couleurs, badges) ---------- */
export const RAR = [
  { k: 'C', n: 'Commun', c: '#a3acbf', c2: '#4b5563' },
  { k: 'R', n: 'Rare', c: '#38bdf8', c2: '#0c4a6e' },
  { k: 'SR', n: 'Épique', c: '#c26bff', c2: '#4c1d95' },
  { k: 'UR', n: 'Légendaire', c: '#ffcc33', c2: '#92400e' },
  { k: 'LR', n: 'Mythique', c: '#ff3b5c', c2: '#7f1d1d' },
  { k: 'MSR', n: 'Divin', c: '#5eead4', c2: '#134e4a', rainbow: 1 },
];

/* ---------- 10 armes ---------- */
// dmg = dégâts de base ; model = arme 3D tenue en main ; glow = lueur de l'arme
export const WEAPONS = [
  { id: 'w1', n: 'Lame Rouillée', r: 0, dmg: 12, model: 'sword_E', glow: 0, d: 'Une vieille lame de garde. Mieux que les poings.' },
  { id: 'w2', n: 'Hachette du Pilleur', r: 0, dmg: 22, model: 'dagger_A', glow: 0, d: 'Volée sur un pilleur de la Cité Néon.' },
  { id: 'w3', n: 'Dague Murmure', r: 1, dmg: 70, model: 'dagger_A', glow: 0x38bdf8, d: 'Frappe si vite qu\'on n\'entend qu\'un souffle.' },
  { id: 'w4', n: 'Bâton de Sève', r: 1, dmg: 130, model: 'staff_A', glow: 0x4ade80, d: 'Taillé dans un arbre-ancêtre de la Forêt.' },
  { id: 'w5', n: 'Marteau Brise-Os', r: 2, dmg: 520, model: 'axe_2handed', glow: 0xc26bff, d: 'Chaque coup fait trembler les tombes.' },
  { id: 'w6', n: 'Hache Sanglante', r: 2, dmg: 1100, model: 'axe_2handed', glow: 0xff3b5c, d: 'Elle a soif. Elle a toujours soif.' },
  { id: 'w7', n: 'Épée du Chevalier Pâle', r: 3, dmg: 6200, model: 'sword_D', glow: 0xffcc33, d: 'Portée par le gardien de la Nécropole.' },
  { id: 'w8', n: 'Faux d\'Os Royale', r: 3, dmg: 14000, model: 'sword_E', glow: 0xffd166, d: 'Forgée dans la colonne d\'un roi oublié.' },
  { id: 'w9', n: 'Sceptre du Néant', r: 4, dmg: 90000, model: 'staff_A', glow: 0xff3b5c, d: 'Le vide lui-même obéit à ce sceptre.' },
  { id: 'w10', n: 'Lame du Monarque d\'Ombre', r: 5, dmg: 700000, model: 'sword_D', glow: 0x5eead4, d: 'L\'arme ultime. Une chance sur des milliers.' },
];
export const W_MAXLV = 60, W_MAXSTAR = 5;
export const wUpCost = (w, lv) => Math.ceil(w.dmg * 6 * Math.pow(1.16, lv));
export const wPower = (w, it) => w.dmg * (1 + it.lv * 0.12) * (1 + it.st * 0.35);

/* ---------- 10 reliques ---------- */
// stat : clé de bonus ; v = bonus par niveau (en %), max niveau 10
export const RELICS = [
  { id: 'r1', n: 'Pièce du Roi Avare', r: 0, stat: 'cash', v: 12, ic: 'coin', d: 'Plus d\'argent sur chaque ennemi.' },
  { id: 'r2', n: 'Croc de l\'Alpha', r: 0, stat: 'crit', v: 2, ic: 'fang', d: 'Chance de coup critique.' },
  { id: 'r3', n: 'Plume du Phénix', r: 1, stat: 'hp', v: 15, ic: 'feather', d: 'Plus de points de vie.' },
  { id: 'r4', n: 'Sablier Brisé', r: 1, stat: 'aspd', v: 5, ic: 'hourglass', d: 'Vitesse d\'attaque du héros et des ombres.' },
  { id: 'r5', n: 'Cœur de Braise', r: 2, stat: 'wdmg', v: 20, ic: 'heart', d: 'Dégâts d\'arme.' },
  { id: 'r6', n: 'Larme de Cristal', r: 2, stat: 'gems', v: 15, ic: 'tear', d: 'Plus de gemmes.' },
  { id: 'r7', n: 'Œil du Néant', r: 3, stat: 'arise', v: 10, ic: 'eye', d: 'Chance d\'Éveil des ombres.' },
  { id: 'r8', n: 'Couronne Spectrale', r: 3, stat: 'sdmg', v: 25, ic: 'crown', d: 'Dégâts des ombres.' },
  { id: 'r9', n: 'Sceau de l\'Abysse', r: 4, stat: 'luck', v: 12, ic: 'seal', d: 'Chance de butin rare (Lucky Drop).' },
  { id: 'r10', n: 'Étoile Noire', r: 5, stat: 'all', v: 30, ic: 'star', d: 'Tous les dégâts.' },
];
export const R_MAXLV = 10;
export const relicSlots = lvl => lvl >= 40 ? 5 : lvl >= 20 ? 4 : 3;
export const SUMMON = { cost: 120, cost10: 1080, rates: [0.46, 0.30, 0.15, 0.065, 0.022, 0.003] };

/* ---------- 10 accessoires (Tête, Cape, Plastron, Bottes) ---------- */
export const SLOTS = [['tete', 'Tête'], ['cape', 'Cape'], ['plastron', 'Plastron'], ['bottes', 'Bottes']];
export const ACCS = [
  { id: 'a1', n: 'Capuche du Rôdeur', slot: 'tete', r: 0, st: { hp: 20, crit: 2 } },
  { id: 'a2', n: 'Heaume du Gardien', slot: 'tete', r: 2, st: { hp: 80, wdmg: 40 } },
  { id: 'a3', n: 'Couronne du Monarque', slot: 'tete', r: 4, st: { sdmg: 150, arise: 25 } },
  { id: 'a4', n: 'Cape Déchirée', slot: 'cape', r: 1, st: { aspd: 10, cash: 25 } },
  { id: 'a5', n: 'Manteau de Nuit Éternelle', slot: 'cape', r: 3, st: { all: 60, luck: 20 } },
  { id: 'a6', n: 'Cuirasse de Cuir', slot: 'plastron', r: 0, st: { hp: 35 } },
  { id: 'a7', n: 'Plastron d\'Os', slot: 'plastron', r: 2, st: { hp: 120, crit: 6 } },
  { id: 'a8', n: 'Armure Abyssale', slot: 'plastron', r: 4, st: { hp: 400, all: 80 } },
  { id: 'a9', n: 'Bottes de Voyage', slot: 'bottes', r: 1, st: { speed: 15, gems: 20 } },
  { id: 'a10', n: 'Bottes du Pas d\'Ombre', slot: 'bottes', r: 3, st: { speed: 30, arise: 15, sdmg: 60 } },
];
export const A_MAXLV = 20;
export const aUpCost = (a, lv) => Math.ceil(400 * Math.pow(6, a.r) * Math.pow(1.2, lv));
export const aMult = lv => 1 + lv * 0.15;

export const STAT_NAMES = { cash: 'Argent', gems: 'Gemmes', crit: 'Critique', hp: 'PV', aspd: 'Vitesse d\'attaque', wdmg: 'Dégâts d\'arme', sdmg: 'Dégâts des ombres', arise: 'Chance d\'Éveil', luck: 'Chance de butin', all: 'Tous dégâts', speed: 'Vitesse' };

/* ---------- ennemis ---------- */
// model : personnage KayKit ; anim quadrupède gérée par le moteur
export const FOES = {
  voyou: { n: 'Voyou des Ruelles', model: 'Rogue_Hooded', tint: '#7c86a8' },
  cogneur: { n: 'Cogneur du Port', model: 'Barbarian', tint: '#9aa3c7' },
  loup: { n: 'Loup Sylvestre', model: 'wolf', sc: 0.6, tint: '#9fb39a' },
  renard: { n: 'Renard Écarlate', model: 'fox', sc: 0.62, tint: '#ffb38a' },
  cerf: { n: 'Cerf Ancien', model: 'stag', sc: 0.55, tint: '#c9b48a' },
  taureau: { n: 'Taureau Furieux', model: 'bull', sc: 0.55, tint: '#c98a7a' },
  sbire: { n: 'Sbire Squelette', model: 'Skeleton_Minion', tint: '#e8e4d8' },
  guerrier: { n: 'Guerrier d\'Os', model: 'Skeleton_Warrior', tint: '#d9d2c0' },
  sorcier: { n: 'Sorcier d\'Os', model: 'Skeleton_Mage', tint: '#c7b8ff' },
  chevalier: { n: 'Chevalier Abyssal', model: 'Knight', tint: '#7a5cff' },
  mage: { n: 'Mage du Néant', model: 'Mage', tint: '#c26bff' },
  dragon: { n: 'Dragon de l\'Abysse', model: 'dragon', sc: 1.1, tint: '#9b5cff' },
};

/* ---------- 4 mondes évolutifs (10 paliers chacun) ---------- */
// prop : la propriété unique du monde, appliquée par le moteur de jeu
export const WORLDS = [
  { n: 'Cité Néon', sub: 'Les ruelles de la ville basse', env: 'city', col: '#38bdf8', foes: ['voyou', 'cogneur'], brute: 'cogneur', boss: 'cogneur', bossN: 'Baron du Port',
    prop: { cash: 1.5 }, propTxt: 'Ville riche : +50 % d\'argent', drops: ['w1', 'w2', 'w3'], music: 'hub', base: 0 },
  { n: 'Forêt d\'Émeraude', sub: 'La meute ne dort jamais', env: 'forest', col: '#4ade80', foes: ['loup', 'renard', 'cerf'], brute: 'taureau', boss: 'taureau', bossN: 'Roi-Taureau Sylvestre',
    prop: { pack: 2, xp: 2 }, propTxt: 'Meutes : ennemis par deux, XP ×2', drops: ['w3', 'w4', 'w5'], music: 'zone0', base: 10 },
  { n: 'Nécropole Pâle', sub: 'Ici, les morts écoutent', env: 'necro', col: '#c26bff', foes: ['sbire', 'guerrier', 'sorcier'], brute: 'guerrier', boss: 'guerrier', bossN: 'Chevalier Pâle',
    prop: { arise: 1.6, revive: 0.15 }, propTxt: 'Terre des âmes : Éveil ×1,6 · les morts se relèvent', drops: ['w5', 'w6', 'w7'], music: 'zone1', base: 20 },
  { n: 'Citadelle Abyssale', sub: 'Le trône du Néant', env: 'abyss', col: '#ff3b5c', foes: ['chevalier', 'mage', 'sorcier'], brute: 'chevalier', boss: 'dragon', bossN: 'Dragon de l\'Abysse',
    prop: { gems: 2, luck: 2, hp: 1.6 }, propTxt: 'Abysse : gemmes ×2, Lucky ×2, ennemis +60 % PV', drops: ['w7', 'w8', 'w9'], music: 'dungeon', base: 30 },
];
export const STAGES = 10;
export const tierOf = (w, s) => WORLDS[w].base + s;
export const foeHp = t => 40 * Math.pow(1.62, t);
export const foeDmg = t => 4 * Math.pow(1.5, t);
export const foeCash = t => 6 * Math.pow(1.6, t);
export const mission = (w, s) => ({ kills: 25 + s * 4, brutes: 3 + Math.floor(s / 3) });

/* ---------- ombres ---------- */
export const SRANKS = ['E', 'D', 'C', 'B', 'A', 'S', 'SS'];
export const SRANK_COL = ['#a3acbf', '#4ade80', '#38bdf8', '#6d7cff', '#c26bff', '#ffcc33', '#ff3b5c'];
export const SRANK_MULT = [1, 1.6, 2.6, 4.2, 7, 12, 22];
export const armyMax = lvl => Math.min(30, 3 + Math.floor(lvl / 3));
export const shadowPow = sh => foeHp(sh.t) * 0.06 * (sh.k === 2 ? 6 : sh.k === 1 ? 2.2 : 1) * SRANK_MULT[sh.rk] * (1 + sh.lv * 0.1);
export const shUpCost = sh => Math.ceil(foeCash(sh.t) * 8 * Math.pow(1.25, sh.lv) * (1 + sh.rk * 0.5));
export const SH_MAXLV = 30;

/* ---------- joueur ---------- */
export const xpNeed = l => Math.floor(40 * l * Math.pow(1.13, l));

/* ---------- quêtes et succès ---------- */
export const QUESTS = [
  { id: 'q1', n: 'Nettoyage des rues', k: 'kills', need: 150, rw: { gems: 60 } },
  { id: 'q2', n: 'Brise les brutes', k: 'brutes', need: 15, rw: { gems: 80 } },
  { id: 'q3', n: 'Lève une armée', k: 'arises', need: 25, rw: { gems: 100 } },
  { id: 'q4', n: 'Chasseur de rois', k: 'bosses', need: 3, rw: { gems: 150 } },
  { id: 'q5', n: 'Forgeron assidu', k: 'upgrades', need: 10, rw: { gems: 80 } },
];
export const ACH = [
  { id: 'h1', n: 'Premier sang', k: 'kills', tiers: [100, 1000, 10000, 50000], rw: 'wdmg', v: 10 },
  { id: 'h2', n: 'Marée d\'ombres', k: 'arises', tiers: [10, 100, 500, 2000], rw: 'sdmg', v: 15 },
  { id: 'h3', n: 'Régicide', k: 'bosses', tiers: [1, 10, 25, 40], rw: 'all', v: 10 },
  { id: 'h4', n: 'Main chanceuse', k: 'lucky', tiers: [1, 10, 50, 200], rw: 'luck', v: 10 },
  { id: 'h5', n: 'Collectionneur', k: 'collect', tiers: [5, 12, 20, 30], rw: 'cash', v: 25 },
  { id: 'h6', n: 'Voyageur des mondes', k: 'worlds', tiers: [1, 2, 3, 4], rw: 'arise', v: 8 },
];
