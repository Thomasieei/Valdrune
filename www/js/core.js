/* NOCTALIS — données, formules, état et sauvegarde */
export const rnd = (a, b) => a + Math.random() * (b - a);
export const irnd = (a, b) => Math.floor(rnd(a, b + 1));
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const pick = a => a[Math.floor(Math.random() * a.length)];

/* ---------- grands nombres ---------- */
const SUF = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', 'UDc', 'DDc', 'TDc', 'QaDc', 'QiDc', 'SxDc', 'SpDc', 'OcDc', 'NoDc', 'Vg'];
export function fmt(n) {
  if (!isFinite(n)) return '∞';
  if (n < 0) return '-' + fmt(-n);
  if (n < 1000) return n < 10 && n % 1 ? n.toFixed(1) : Math.floor(n).toString();
  const e = Math.floor(Math.log10(n) / 3);
  if (e < SUF.length) { const v = n / Math.pow(1000, e); return (v < 100 ? v.toFixed(2) : v.toFixed(1)) + SUF[e]; }
  const ex = Math.floor(Math.log10(n)); return (n / Math.pow(10, ex)).toFixed(2) + 'e' + ex;
}
export const pct = v => fmt(v * 100) + '%';
export function fmtTime(s) { s = Math.max(0, Math.ceil(s)); const m = Math.floor(s / 60); return String(m).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0'); }

/* ---------- rangs ---------- */
export const RANKS = ['E', 'D', 'C', 'B', 'A', 'S', 'SS', 'SSS', 'Ω'];
export const RANK_COL = ['#a3acbf', '#4ade80', '#38bdf8', '#6d7cff', '#c26bff', '#ffcc33', '#ff7a45', '#ff3355', '#ffffff'];
export const RANK_MULT = [1, 3, 10, 32, 100, 320, 1000, 3200, 10000];
export const ARISE_BASE = [0.6, 0.45, 0.32, 0.22, 0.14, 0.08, 0.045, 0.025, 0.012];
export const SELL_VAL = [5, 15, 50, 160, 500, 1600, 5000, 16000, 50000];

/* statistiques d'ombre : grades F → M */
export const GRADES = ['F', 'E', 'D', 'C', 'B', 'A', 'S', 'M'];
export const GRADE_COL = ['#7d8597', '#a3acbf', '#4ade80', '#38bdf8', '#6d7cff', '#c26bff', '#ffcc33', '#ff3355'];
const GRADE_W = [30, 24, 18, 12, 8, 5, 2.4, 0.6];
export const SSTATS = [
  { id: 'force', name: 'Force', desc: 'Dégâts', col: '#ff4d6d', vals: [5, 10, 18, 28, 40, 55, 75, 100] },
  { id: 'fureur', name: 'Fureur', desc: "Vitesse d'attaque", col: '#ffcc33', vals: [3, 6, 10, 15, 22, 30, 40, 55] },
  { id: 'precision', name: 'Précision', desc: 'Critique', col: '#4ade80', vals: [2, 4, 7, 10, 14, 19, 25, 35] },
  { id: 'avidite', name: 'Avidité', desc: "Butin d'or", col: '#38bdf8', vals: [5, 10, 18, 28, 40, 55, 75, 100] },
];
export function rollGrade(bonus = 0) {
  let tot = 0; const w = GRADE_W.map((x, i) => x * (i >= 4 ? 1 + bonus : 1)); w.forEach(x => tot += x);
  let r = Math.random() * tot; for (let i = 0; i < w.length; i++) { r -= w[i]; if (r <= 0) return i; } return 0;
}

/* ---------- monde ---------- */
export const ZONES = [
  { id: 0, name: 'Bois des Crocs', sub: 'Lisière sauvage', req: 1, frag: 'Crocs', fragCol: '#ff9f43', ground: '#4f7d3c', ground2: '#3c6630', fog: 0x9fb6c9, sky: ['#2a3a6a', '#f39c6b'], light: 0xffe2c0,
    mobs: [
      { m: 'wolf', name: 'Loup Cendré', r: 0, s: 0.8, hp: 1, quad: 1 },
      { m: 'fox', name: 'Renard Braise', r: 0, s: 0.9, hp: 0.8, quad: 1 },
      { m: 'stag', name: 'Cerf Sylvain', r: 1, s: 0.8, hp: 1.6, quad: 1 },
    ], boss: { m: 'bull', name: 'Taureau Cornefer', r: 2, s: 0.95, hp: 25, quad: 1 } },
  { id: 1, name: "Nécropole d'Ébène", sub: 'Terres des morts', req: 12, frag: 'Ossements', fragCol: '#c9d6ff', ground: '#3a3646', ground2: '#2a2733', fog: 0x2b2340, sky: ['#0d0b1f', '#4b2a6b'], light: 0xb9a6ff,
    mobs: [
      { m: 'Skeleton_Minion', name: 'Squelette Errant', r: 2, s: 1, hp: 1 },
      { m: 'Skeleton_Rogue', name: 'Rôdeur Osseux', r: 2, s: 1, hp: 0.9, w: 'dagger_A' },
      { m: 'Skeleton_Warrior', name: 'Garde Ossuaire', r: 3, s: 1.05, hp: 1.6, w: 'axe_2handed' },
      { m: 'Skeleton_Mage', name: 'Nécromant', r: 3, s: 1, hp: 1.2, w: 'staff_A' },
    ], boss: { m: 'Skeleton_Warrior', name: 'Seigneur Ossaclame', r: 4, s: 2.3, hp: 25, w: 'sword_D' } },
  { id: 2, name: 'Bastion Déchu', sub: 'Royaume parjure', req: 28, frag: 'Couronnes', fragCol: '#ffcc33', ground: '#5a4a48', ground2: '#463836', fog: 0x5a2a2a, sky: ['#1a0a12', '#b8423a'], light: 0xffb38a,
    mobs: [
      { m: 'Knight', name: 'Chevalier Parjure', r: 4, s: 1, hp: 1.4, keep: ['1H_Sword', 'Round_Shield', 'Knight_'] },
      { m: 'Barbarian', name: 'Berserker Déchu', r: 4, s: 1.05, hp: 1.6, keep: ['2H_Axe', 'Barbarian_'] },
      { m: 'Rogue_Hooded', name: 'Lame Voilée', r: 5, s: 1, hp: 1, keep: ['Knife', 'Rogue_'] },
      { m: 'Mage', name: 'Pyromancien', r: 5, s: 1, hp: 1.1, keep: ['2H_Staff', 'Mage_'] },
    ], boss: { m: 'Knight', name: 'Roi sans Couronne', r: 6, s: 2.5, hp: 25, keep: ['2H_Sword', 'Knight_'], tint: 0xff5544 } },
];
export const ZK = 200;
export const zoneHp = z => 60 * Math.pow(ZK, z);
export const zoneDmg = z => 4 * Math.pow(15, z);
export const shadowBase = (z, boss) => Math.pow(ZK, z) * (boss ? 4 : 1);

/* ---------- armes ---------- */
export const WEAPONS = [
  ['Lame rouillée', 'sword_E', 0x9aa0a8], ['Épée de fer', 'sword_E', 0xcfd6df], ['Hachoir d’acier', 'axe_2handed', 0xd9e2ec], ['Croc d’argent', 'dagger_A', 0xe8f1ff],
  ['Lame runique', 'sword_D', 0x38bdf8], ['Faux du Crépuscule', 'staff_A', 0xff7a45], ['Brise-Âme', 'sword_D', 0xc26bff], ['Couperet abyssal', 'axe_2handed', 0x6d7cff],
  ['Lame céleste', 'sword_E', 0xffcc33], ['Croc du Néant', 'dagger_A', 0x8b5cf6], ['Éclat d’Éternité', 'sword_D', 0x22f0ff], ['Hache du Jugement', 'axe_2handed', 0xff3355],
  ['Sceptre des Ombres', 'staff_A', 0xa855f7], ['Lame du Monarque Noir', 'sword_D', 0xffffff],
].map(([name, model, col], t) => ({ t, name, model, col, mult: Math.pow(3, t), cost: t ? 400 * Math.pow(5.5, t) : 0, ore: t >= 3 ? Math.ceil(25 * Math.pow(2.6, t - 3)) : 0 }));

/* ---------- forge : 4 améliorations par zone ---------- */
export const FORGE = [
  { id: 'lame', name: "Dégâts d'arme", col: '#ff4d6d', per: 0.15 },
  { id: 'ombre', name: "Dégâts d'ombre", col: '#a855f7', per: 0.15 },
  { id: 'eveil', name: "Chance d'Éveil", col: '#4ade80', per: 0.06 },
  { id: 'butin', name: "Butin d'or", col: '#ffcc33', per: 0.12 },
];
export const FORGE_MAX = 50;
export const forgeCost = (z, lvl) => Math.ceil(4 * Math.pow(1.17, lvl) * (1 + z * 0.5));

/* ---------- reliques ---------- */
export const RELIC_RAR = [
  { n: 'Commune', c: '#a3acbf', w: 60, m: 1 }, { n: 'Rare', c: '#38bdf8', w: 26, m: 2.5 }, { n: 'Épique', c: '#c26bff', w: 10, m: 6 },
  { n: 'Légendaire', c: '#ffcc33', w: 3.4, m: 15 }, { n: 'Mythique', c: '#ff3355', w: 0.6, m: 40 },
];
export const RELICS = [
  { id: 'r_eveil', name: 'Œil du Néant', stat: 'eveil', per: 0.04, ico: 'eye' },
  { id: 'r_ombre', name: 'Cœur de Ténèbres', stat: 'ombre', per: 0.08, ico: 'heart' },
  { id: 'r_lame', name: 'Sceau du Bourreau', stat: 'lame', per: 0.08, ico: 'sword' },
  { id: 'r_or', name: 'Bourse du Spectre', stat: 'or', per: 0.08, ico: 'coin' },
  { id: 'r_xp', name: 'Grimoire Oublié', stat: 'xp', per: 0.06, ico: 'book' },
  { id: 'r_crit', name: 'Croc du Destin', stat: 'crit', per: 0.01, ico: 'fang' },
];
export const RELIC_COST = 60;

/* ---------- donjons ---------- */
export const DUNGEONS = [
  { z: 0, name: 'Terrier des Mille Crocs', rooms: 15, time: 360 },
  { z: 1, name: 'Catacombes Hurlantes', rooms: 25, time: 540 },
  { z: 2, name: 'Salle du Trône Brisé', rooms: 40, time: 780 },
];
export const KEY_MAX = 5, KEY_REGEN = 480;

/* ---------- état ---------- */
const SAVE_KEY = 'noctalis_v1';
export function freshState() {
  return {
    v: 1, created: Date.now(), last: Date.now(),
    lvl: 1, xp: 0, gold: 0, gems: 60, runes: 10, frags: [0, 0, 0], keys: 3, keyT: 0,
    weapon: 0, wOwned: 1, forge: [{}, {}, {}], relics: {},
    shadows: [], nextId: 1, invMax: 150,
    zone: 0, unlocked: 1, autoFarm: false, autoArise: true, autoDissolve: -1, harvest: true,
    kills: 0, arises: 0, dClears: 0, siegeBest: 0, siegeCk: 0, bossKills: 0,
    quests: null, qDay: '', music: true, sfx: true, hq: true, tuto: 0,
  };
}
export let S = freshState();
export function load() {
  try { const t = localStorage.getItem(SAVE_KEY); if (t) { const d = JSON.parse(t); S = Object.assign(freshState(), d); } } catch (e) { }
  return S;
}
export function save() { S.last = Date.now(); try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) { } }
export function wipe() { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } location.reload(); }

/* ---------- formules dérivées ---------- */
export const xpNeed = l => Math.floor(25 * l * Math.pow(1.12, l));
export const slotsMax = () => Math.min(55, 6 + Math.floor(S.lvl / 2));
function forgeMult(stat, mulAcross) {
  let m = 1; for (let z = 0; z < 3; z++) { const l = S.forge[z][stat] || 0; const f = FORGE.find(x => x.id === stat); m = mulAcross ? m * (1 + f.per * (z + 1) * l) : m + f.per * (z + 1) * l; } return m;
}
export function relicBonus(stat) {
  let b = 0; for (const r of RELICS) { if (r.stat !== stat) continue; const o = S.relics[r.id]; if (!o) continue; b += r.per * RELIC_RAR[o.rar].m * (1 + 0.25 * (o.lvl - 1)); } return b;
}
export function stats() {
  const lvlMul = 1 + 0.08 * (S.lvl - 1);
  const w = WEAPONS[S.weapon];
  const lame = forgeMult('lame', true) * (1 + relicBonus('lame'));
  const ombre = forgeMult('ombre', true) * (1 + relicBonus('ombre'));
  const db = S.dom || {};
  const eveil = (forgeMult('eveil', false) - 1) + relicBonus('eveil') + (db.bonusEveil || 0);
  const or = (forgeMult('butin', false) - 1) + relicBonus('or') + (db.flags && db.flags.sel ? 0.15 : 0);
  let shAvid = 0; for (const s of S.shadows) if (s.eq) shAvid += SSTATS[3].vals[s.st[3]] / 100 * 0.1;
  return {
    atk: 12 * w.mult * lame * lvlMul, hpMax: 120 * Math.pow(1.13, S.lvl - 1) * Math.pow(w.mult, 0.25),
    crit: 0.05 + relicBonus('crit'), shadowMul: ombre * lvlMul, eveil, gold: 1 + or + shAvid, xp: 1 + relicBonus('xp'),
    lame, ombre,
  };
}
export function shadowDmg(s, st = stats()) {
  return shadowBase(s.z, s.boss) * RANK_MULT[s.r] * (1 + 0.1 * (s.lvl - 1)) * (1 + SSTATS[0].vals[s.st[0]] / 100) * st.shadowMul;
}
export const shadowSpd = s => 1 + SSTATS[1].vals[s.st[1]] / 100;
export const shadowCrit = s => SSTATS[2].vals[s.st[2]] / 100;
export const shadowLvlCost = s => Math.ceil(12 * Math.pow(ZK, s.z) * RANK_MULT[s.r] * Math.pow(1.22, s.lvl));
export const shadowLvlMax = s => 20 + s.r * 15;
export function armyPower(st = stats()) {
  let p = 0; for (const s of S.shadows) if (s.eq) p += shadowDmg(s, st) * shadowSpd(s); return p;
}
export const power = () => { const st = stats(); return st.atk * 1.5 + armyPower(st); };

/* ---------- quêtes du jour ---------- */
const Q_DEFS = [
  { id: 'kill', name: 'Abattre des monstres', goal: 120, rew: { gems: 40, runes: 3 } },
  { id: 'arise', name: 'Éveiller des ombres', goal: 15, rew: { gems: 40, keys: 1 } },
  { id: 'boss', name: 'Vaincre des boss', goal: 3, rew: { gems: 60, runes: 5 } },
  { id: 'dungeon', name: 'Terminer un donjon', goal: 1, rew: { gems: 80, runes: 8 } },
  { id: 'siege', name: 'Atteindre la vague 20 du Siège', goal: 20, rew: { gems: 80, keys: 2 }, max: true },
];
export function checkQuests() {
  const d = new Date().toDateString();
  if (S.qDay !== d || !S.quests) { S.qDay = d; S.quests = Q_DEFS.map(q => ({ id: q.id, p: 0, done: false })); }
}
export const questDef = id => Q_DEFS.find(q => q.id === id);
export function questProg(id, n = 1) {
  checkQuests(); const q = S.quests.find(x => x.id === id); if (!q || q.done) return;
  const d = questDef(id); q.p = d.max ? Math.max(q.p, n) : q.p + n;
}
