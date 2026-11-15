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

/* ---------- rangs F → S (raretés des objets ET des ombres) ---------- */
export const RAR = [
  { k: 'F', n: 'Commun', c: '#9ca3af', c2: '#374151' },
  { k: 'E', n: 'Peu commun', c: '#4ade80', c2: '#14532d' },
  { k: 'D', n: 'Rare', c: '#38bdf8', c2: '#0c4a6e' },
  { k: 'C', n: 'Épique', c: '#c26bff', c2: '#4c1d95' },
  { k: 'B', n: 'Légendaire', c: '#ffcc33', c2: '#92400e' },
  { k: 'A', n: 'Mythique', c: '#ff3b5c', c2: '#7f1d1d' },
  { k: 'S', n: 'Suprême', c: '#ff7ad9', c2: '#4a044e', rainbow: 1 },
];
export const RK = RAR.map(r => r.k);

/* ---------- 10 armes ---------- */
export const WEAPONS = [
  { id: 'w1', n: 'Lame Rouillée', r: 0, dmg: 12, model: 'sword_E', glow: 0, d: 'Une vieille lame de garde. Mieux que les poings.' },
  { id: 'w2', n: 'Hachette du Pilleur', r: 0, dmg: 20, model: 'dagger_A', glow: 0, d: 'Volée sur un pilleur de la Cité Néon.' },
  { id: 'w3', n: 'Dague Murmure', r: 1, dmg: 60, model: 'dagger_A', glow: 0x4ade80, d: 'Frappe si vite qu\'on n\'entend qu\'un souffle.' },
  { id: 'w4', n: 'Bâton de Sève', r: 1, dmg: 110, model: 'staff_A', glow: 0x4ade80, d: 'Taillé dans un arbre-ancêtre de la Forêt.' },
  { id: 'w5', n: 'Marteau Brise-Os', r: 2, dmg: 480, model: 'axe_2handed', glow: 0x38bdf8, d: 'Chaque coup fait trembler les tombes.' },
  { id: 'w6', n: 'Hache Sanglante', r: 3, dmg: 2600, model: 'axe_2handed', glow: 0xc26bff, d: 'Elle a soif. Elle a toujours soif.' },
  { id: 'w7', n: 'Épée du Chevalier Pâle', r: 4, dmg: 14000, model: 'sword_D', glow: 0xffcc33, d: 'Portée par le gardien de la Nécropole.' },
  { id: 'w8', n: 'Faux d\'Os Royale', r: 5, dmg: 70000, model: 'sword_E', glow: 0xff3b5c, d: 'Forgée dans la colonne d\'un roi oublié.' },
  { id: 'w9', n: 'Sceptre du Néant', r: 5, dmg: 120000, model: 'staff_A', glow: 0xff3b5c, d: 'Le vide lui-même obéit à ce sceptre.' },
  { id: 'w10', n: 'Lame du Monarque d\'Ombre', r: 6, dmg: 1500000, model: 'sword_D', glow: 0xff7ad9, d: 'L\'arme suprême. Seuls les portails de rang S la recèlent.' },
];
export const W_MAXLV = 60, W_MAXSTAR = 5;
export const wUpCost = (w, lv) => Math.ceil(w.dmg * 6 * Math.pow(1.16, lv));
export const wPower = (w, it) => w.dmg * (1 + it.lv * 0.12) * (1 + it.st * 0.35);

/* ---------- 10 reliques (icônes 3D rendues) ---------- */
export const RELICS = [
  { id: 'r1', n: 'Trésor du Roi Avare', r: 0, stat: 'cash', v: 10, d: 'Les pièces d\'un roi qui n\'a jamais rien partagé.' },
  { id: 'r2', n: 'Os du Premier Loup', r: 0, stat: 'crit', v: 1.5, d: 'Le premier chasseur. Sa morsure guide la tienne.' },
  { id: 'r3', n: 'Pépite de Vie', r: 1, stat: 'hp', v: 12, d: 'Elle bat comme un cœur quand on la serre.' },
  { id: 'r4', n: 'Boussole du Temps', r: 1, stat: 'aspd', v: 4, d: 'Son aiguille avance plus vite que les secondes.' },
  { id: 'r5', n: 'Œuf de Braise', r: 2, stat: 'wdmg', v: 18, d: 'Il brûle de l\'intérieur. Ton arme aussi.' },
  { id: 'r6', n: 'Œuf de Givre', r: 3, stat: 'gems', v: 15, d: 'Des cristaux poussent sur sa coquille.' },
  { id: 'r7', n: 'Crâne du Nécromancien', r: 4, stat: 'arise', v: 8, d: 'Il murmure aux morts de se relever pour toi.' },
  { id: 'r8', n: 'Grimoire des Ombres', r: 5, stat: 'sdmg', v: 30, d: 'Chaque page est le nom d\'une ombre soumise.' },
  { id: 'r9', n: 'Coffre du Roi-Liche', r: 5, stat: 'luck', v: 12, d: 'Il ne s\'ouvre que pour les chanceux.' },
  { id: 'r10', n: 'Œuf du Dragon Primordial', r: 6, stat: 'all', v: 40, d: 'Ce qui dort dedans est plus vieux que les mondes.' },
];
export const R_MAXLV = 10;
export const relicSlots = lvl => lvl >= 40 ? 5 : lvl >= 20 ? 4 : 3;
export const SUMMON = { cost: 120, cost10: 1080, rates: [0.55, 0.28, 0.11, 0.045, 0.012, 0.0027, 0.0003] };

/* ---------- 10 accessoires (Tête, Cape, Plastron, Bottes) ---------- */
export const SLOTS = [['tete', 'Tête'], ['cape', 'Cape'], ['plastron', 'Plastron'], ['bottes', 'Bottes']];
export const ACCS = [
  { id: 'a1', n: 'Capuche du Rôdeur', slot: 'tete', r: 0, st: { hp: 15, crit: 1 } },
  { id: 'a6', n: 'Cuirasse de Cuir', slot: 'plastron', r: 0, st: { hp: 25 } },
  { id: 'a4', n: 'Cape Déchirée', slot: 'cape', r: 1, st: { aspd: 6, cash: 15 } },
  { id: 'a9', n: 'Bottes de Voyage', slot: 'bottes', r: 1, st: { speed: 12, gems: 10 } },
  { id: 'a2', n: 'Heaume du Gardien', slot: 'tete', r: 2, st: { hp: 60, wdmg: 30 } },
  { id: 'a7', n: 'Plastron d\'Os', slot: 'plastron', r: 3, st: { hp: 100, crit: 4 } },
  { id: 'a5', n: 'Manteau de Nuit Éternelle', slot: 'cape', r: 4, st: { all: 50, luck: 15 } },
  { id: 'a10', n: 'Bottes du Pas d\'Ombre', slot: 'bottes', r: 5, st: { speed: 30, arise: 15, sdmg: 80 } },
  { id: 'a3', n: 'Couronne du Monarque', slot: 'tete', r: 5, st: { sdmg: 150, arise: 20 } },
  { id: 'a8', n: 'Armure Abyssale', slot: 'plastron', r: 6, st: { hp: 400, all: 120 } },
];
export const A_MAXLV = 20;
export const aUpCost = (a, lv) => Math.ceil(300 * Math.pow(5, a.r) * Math.pow(1.2, lv));
export const aMult = lv => 1 + lv * 0.15;

/* ---------- tirage d'un rang (pondéré, la chance pousse vers le haut) ---------- */
export function rollRankW(weights, luck = 0) {
  const w = weights.map((x, i) => x * Math.pow(1 + luck / 200, i)); const tot = w.reduce((a, b) => a + b, 0);
  let x = Math.random() * tot; for (let i = 0; i < w.length; i++) { if (x < w[i]) return i; x -= w[i]; } return 0;
}
// rangs des objets et des ombres selon la source  [F,E,D,C,B,A,S]
export const WORLD_RW = [[70, 27, 3, 0, 0, 0, 0], [0, 60, 33, 7, 0, 0, 0], [0, 0, 55, 35, 10, 0, 0], [0, 0, 0, 55, 37, 8, 0]];
export function dungeonRW(r) { const w = [0, 0, 0, 0, 0, 0, 0]; if (r > 0) w[r - 1] = 45; w[r] += r === 0 ? 90 : 45; if (r < 6) w[r + 1] = r >= 4 ? 4 : 10; if (r === 6) { w[5] = 70; w[6] = 30; } return w; }

export const STAT_NAMES = { cash: 'Argent', gems: 'Gemmes', crit: 'Critique', hp: 'PV', aspd: 'Vitesse d\'attaque', wdmg: 'Dégâts d\'arme', sdmg: 'Dégâts des ombres', arise: 'Chance d\'Éveil', luck: 'Chance de butin', all: 'Tous dégâts', speed: 'Vitesse' };

/* ---------- ennemis ---------- */
// model : personnage KayKit ; anim quadrupède gérée par le moteur
export const FOES = {
  voyou: { n: 'Voyou des Ruelles', model: 'Rogue_Hooded', tint: '#7c86a8' },
  rodeur: { n: 'Rôdeur des Toits', model: 'Rogue', tint: '#a0a8c8' },
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
  { n: 'Cité Néon', sub: 'Les ruelles de la ville basse', env: 'city', col: '#38bdf8', foes: ['voyou', 'cogneur'], brute: 'cogneur', boss: 'cogneur', uq: 'vex',
    prop: { cash: 1.5 }, propTxt: 'Ville riche : +50 % d\'argent', music: 'hub', base: 0 },
  { n: 'Forêt d\'Émeraude', sub: 'La meute ne dort jamais', env: 'forest', col: '#4ade80', foes: ['loup', 'renard', 'cerf'], brute: 'taureau', boss: 'taureau', uq: 'ghorn',
    prop: { pack: 2, xp: 2 }, propTxt: 'Meutes : ennemis par deux, XP ×2', music: 'zone0', base: 10 },
  { n: 'Nécropole Pâle', sub: 'Ici, les morts écoutent', env: 'necro', col: '#c26bff', foes: ['sbire', 'guerrier', 'sorcier'], brute: 'guerrier', boss: 'guerrier', uq: 'aldric',
    prop: { arise: 1.6, revive: 0.15 }, propTxt: 'Terre des âmes : Éveil ×1,6 · les morts se relèvent', music: 'zone1', base: 20 },
  { n: 'Citadelle Abyssale', sub: 'Le trône du Néant', env: 'abyss', col: '#ff3b5c', foes: ['chevalier', 'mage', 'sorcier'], brute: 'chevalier', boss: 'dragon', uq: 'nyx',
    prop: { gems: 2, luck: 2, hp: 1.6 }, propTxt: 'Abysse : gemmes ×2, Lucky ×2, ennemis +60 % PV', music: 'dungeon', base: 30 },
];
export const STAGES = 10;
export const tierOf = (w, s) => WORLDS[w].base + s;
export const foeHp = t => 40 * Math.pow(1.62, t);
export const foeDmg = t => 4 * Math.pow(1.5, t);
export const foeCash = t => 6 * Math.pow(1.6, t);
export const mission = (w, s) => ({ kills: 25 + s * 4, brutes: 3 + Math.floor(s / 3) });

/* ---------- ombres : rangs, traits, identité ---------- */
export const SRANKS = RK;
export const SRANK_COL = RAR.map(r => r.c);
export const SRANK_MULT = [1, 1.7, 2.9, 5, 8.5, 15, 28];
export const armyMax = lvl => Math.min(30, 3 + Math.floor(lvl / 3));
export const shadowPow = sh => foeHp(sh.t) * 0.06 * (sh.k === 2 ? 6 : sh.k === 1 ? 2.2 : 1) * SRANK_MULT[sh.rk] * (1 + sh.lv * 0.1) * (1 + (sh.aw || 0) * 0.25) * (sh.u ? 1.5 : 1);
export const shUpCost = sh => Math.ceil(foeCash(sh.t) * 8 * Math.pow(1.25, sh.lv) * (1 + sh.rk * 0.5));
export const SH_MAXLV = 30;
export const TRAITS = {
  sdmg: { n: 'Vorace', v: 3 }, aspd: { n: 'Frénétique', v: 1.5 }, cash: { n: 'Moissonneur', v: 4 }, luck: { n: 'Chanceux', v: 1.5 }, arise: { n: 'Chasseur d\'âmes', v: 1.2 },
  hp: { n: 'Garde du corps', v: 4 }, crit: { n: 'Lame vive', v: 0.6 }, all: { n: 'Écraseur', v: 2 }, gems: { n: 'Collecteur', v: 2.5 }, wdmg: { n: 'Maître d\'armes', v: 3 },
};
export const TRAIT_N = [0, 1, 1, 2, 2, 3, 3];
export const traitVal = (k, rk) => Math.round(TRAITS[k].v * (1 + rk * 0.6) * rnd(0.8, 1.25) * 10) / 10;
const FIRST = ['Varn', 'Kael', 'Mora', 'Thrax', 'Isel', 'Grom', 'Nyra', 'Orven', 'Sable', 'Dravik', 'Ysra', 'Korr', 'Lysa', 'Bram', 'Vesh', 'Zora', 'Hald', 'Mirek', 'Tess', 'Ulric', 'Néva', 'Rask', 'Ilda', 'Fenn', 'Corvin', 'Ashka', 'Tyr', 'Selk', 'Wren', 'Druv', 'Elka', 'Morgh', 'Siv', 'Jarl', 'Okra', 'Vale', 'Rhun', 'Kesh', 'Lorn', 'Faye'];
const EPI = ['Croc-Noir', 'Œil-de-Givre', 'Main-Rouge', 'Sans-Visage', 'Pas-de-Velours', 'Crâne-Fendu', 'Vent-Noir', 'Cendre', 'Mille-Lames', 'Brise-Os', 'Sang-Froid', 'Dent-d\'Acier', 'Ombre-Longue', 'Cœur-Vide', 'Murmure', 'Sombre-Écaille', 'Griffe-Lune', 'Tison', 'Nuit-Blanche', 'Écho', 'Balafre', 'Fer-Mort', 'Larme-Sèche', 'Silence'];
export const shadowName = () => `${pick(FIRST)} ${pick(EPI)}`;
export const KILL_TITLES = [[0, 'Recrue'], [100, 'Vétéran'], [1000, 'Élite'], [10000, 'Légende vivante']];
// ombres uniques : les boss qu'on éveille gardent leur nom et un trait signature
export const UNIQUES = {
  vex: { n: 'Baron Vex', t: 'Seigneur du Port', foe: 'cogneur', model: 'Barbarian', rk: 2, sig: ['cash', 25], q: 'Tout s\'achète. Même ma loyauté… et c\'est toi qui l\'as.' },
  ghorn: { n: 'Ghorn', t: 'Roi-Taureau Sylvestre', foe: 'taureau', model: 'bull', rk: 3, sig: ['all', 20], q: 'La forêt s\'incline. Moi aussi, désormais.' },
  aldric: { n: 'Sire Aldric', t: 'Chevalier Pâle', foe: 'guerrier', model: 'Skeleton_Warrior', rk: 4, sig: ['arise', 15], q: 'J\'ai gardé ces tombes mille ans. Je garderai ton dos.' },
  nyx: { n: 'Nyx\'thar', t: 'Dragon de l\'Abysse', foe: 'dragon', model: 'dragon', rk: 5, sig: ['sdmg', 60], q: 'Mes ailes couvraient le ciel. Elles couvrent ton armée.' },
  skrag: { n: 'Skrag', t: 'le Rançonneur', foe: 'rodeur', model: 'Rogue', rk: 0, sig: ['cash', 15], q: 'Je rançonnais les faibles. Tu ne l\'es pas.' },
  osrouge: { n: 'Os-Rouge', t: 'Sbire Primordial', foe: 'sbire', model: 'Skeleton_Minion', rk: 1, sig: ['aspd', 8], q: 'Clac. Clac-clac.' },
  fenrak: { n: 'Fenrak', t: 'Loup-Spectre', foe: 'loup', model: 'wolf', rk: 2, sig: ['crit', 5], q: 'La meute suit le plus fort. Je te suis.' },
  morvhen: { n: 'Morvhen', t: 'la Liche', foe: 'sorcier', model: 'Skeleton_Mage', rk: 3, sig: ['arise', 10], q: 'La mort m\'a refusée. Toi, tu m\'as prise.' },
  gael: { n: 'Sire Gaël', t: 'le Déchu', foe: 'chevalier', model: 'Knight', rk: 4, sig: ['wdmg', 40], q: 'J\'ai trahi un roi. Je ne trahirai pas un monarque.' },
  ysolde: { n: 'Ysolde', t: 'Mage du Néant', foe: 'mage', model: 'Mage', rk: 5, sig: ['luck', 20], q: 'Le vide m\'a appris à attendre. Je t\'attendais.' },
  rex: { n: 'Umbra-Rex', t: 'Monarque Primordial', foe: 'dragon', model: 'dragon', rk: 6, sig: ['all', 120], q: 'Avant les mondes, il y avait l\'ombre. Et l\'ombre, c\'était moi.' },
};

/* ---------- portails et donjons (rangs F → S) ---------- */
export const DUNGEONS = [
  { r: 0, n: 'Repaire des Rançonneurs', tier: 3, foes: ['voyou', 'rodeur'], boss: 'skrag' },
  { r: 1, n: 'Ossuaire Oublié', tier: 9, foes: ['sbire', 'voyou'], boss: 'osrouge' },
  { r: 2, n: 'Tanière Spectrale', tier: 15, foes: ['loup', 'sbire'], boss: 'fenrak' },
  { r: 3, n: 'Crypte de la Liche', tier: 21, foes: ['guerrier', 'sorcier'], boss: 'morvhen' },
  { r: 4, n: 'Bastion du Déchu', tier: 27, foes: ['chevalier', 'guerrier'], boss: 'gael' },
  { r: 5, n: 'Sanctuaire du Néant', tier: 33, foes: ['mage', 'chevalier'], boss: 'ysolde' },
  { r: 6, n: 'Trône Primordial', tier: 40, foes: ['chevalier', 'mage'], boss: 'rex' },
];
export const DG_TIME = 180, DG_WAVES = [10, 12, 14];
export const PORTAL_RW = [[65, 30, 5, 0, 0, 0, 0], [0, 50, 38, 12, 0, 0, 0], [0, 0, 45, 40, 15, 0, 0], [0, 0, 0, 40, 40, 17, 3]];
export const recoPower = r => foeHp(DUNGEONS[r].tier) * 1.8;

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
