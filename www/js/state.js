/* UMBRA — état du joueur, sauvegarde, calcul des bonus */
import { WEAPONS, RELICS, ACCS, ACH, wPower, aMult, shadowPow, armyMax, relicSlots, FOES, ROLES } from './data.js';

const KEY = 'umbra_v3';
export function fresh() {
  return {
    lvl: 1, xp: 0, cash: 0, gems: 150,
    w: { w1: { lv: 0, st: 0 } }, wEq: 'w1',
    rel: {}, relEq: [],
    acc: {}, accEq: { tete: null, cape: null, plastron: null, bottes: null },
    sh: [], shN: 0, keys: [0, 0, 0, 0, 0, 0, 0], dgDone: [0, 0, 0, 0, 0, 0, 0],
    world: -1, tower: 0, spinT: 0, pts: 0, at: { for: 0, vit: 0, int: 0, agi: 0, per: 0 }, hunter: 0, armyB: 0, miles: {}, stage: [0, 0, 0, 0], maxWorld: 0, prog: { kills: 0, brutes: 0 },
    st: { legends: 0, chests: 0, kills: 0, brutes: 0, bosses: 0, arises: 0, lucky: 0, upgrades: 0, play: 0, best: 0 },
    q: { day: 0, p: {}, done: {} }, ach: {},
    auto: true, autoArise: false, sfx: true, music: true, hq: true, tuto: 0,
  };
}
export let S = fresh();
export function load() {
  try { const d = JSON.parse(localStorage.getItem(KEY)); if (d) { S = Object.assign(fresh(), d); S.st = Object.assign(fresh().st, d.st); if (d.pts == null) S.pts = 3 * (S.lvl - 1); } } catch (e) { }
  const day = Math.floor(Date.now() / 864e5); if (S.q.day !== day) S.q = { day, p: {}, done: {} };
}
export function save() { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { } }
export function wipe() { try { localStorage.removeItem(KEY); } catch (e) { } location.reload(); }

/* ---------- bonus cumulés (%) ---------- */
let cache = null, cacheT = 0;
export function dirty() { cache = null; }
export function bonus() {
  if (cache && performance.now() - cacheT < 500) return cache;
  const b = { cash: 0, gems: 0, crit: 5, hp: 0, aspd: 0, wdmg: 0, sdmg: 0, arise: 0, luck: 0, all: 0, speed: 0 };
  for (const id of S.relEq) { const r = RELICS.find(x => x.id === id), it = S.rel[id]; if (r && it) b[r.stat] += r.v * (1 + it.lv); }
  for (const k in S.accEq) { const id = S.accEq[k]; if (!id) continue; const a = ACCS.find(x => x.id === id), it = S.acc[id]; for (const s in a.st) b[s] += a.st[s] * aMult(it.lv); }
  const A = S.at; b.wdmg += A.for * 2; b.hp += A.vit * 2; b.sdmg += A.int * 1.5; b.aspd += A.agi * 0.5; b.speed += A.agi * 0.3; b.crit += A.per * 0.2; b.luck += A.per * 0.5;
  for (const sh of S.sh) if (sh.eq && sh.tr) for (const [k, v] of sh.tr) b[k] += v;
  for (const h of ACH) { const t = S.ach[h.id] || 0; b[h.rw] += h.v * t; }
  cache = b; cacheT = performance.now(); return b;
}
export const lvlMult = () => Math.pow(1.1, S.lvl - 1);
export function heroDmg() {
  const w = WEAPONS.find(x => x.id === S.wEq), it = S.w[S.wEq], b = bonus();
  return (8 + wPower(w, it)) * lvlMult() * (1 + b.wdmg / 100) * (1 + b.all / 100);
}
export const heroHp = () => 120 * Math.pow(1.16, S.lvl - 1) * (1 + bonus().hp / 100);
export const heroMp = () => 100 + 6 * (S.lvl - 1) + S.at.int * 3;
export const armyCap = () => armyMax(S.lvl) + S.armyB;
export const roleOf = sh => FOES[sh.type].role;
export const shDmg = sh => shadowPow(sh) * ROLES[roleOf(sh)].dmg * (1 + bonus().sdmg / 100) * (1 + bonus().all / 100);
export const equipped = () => S.sh.filter(s => s.eq);
export function power() { return heroDmg() * 3 + equipped().reduce((a, s) => a + shDmg(s), 0); }
export function autoEquipShadows() {
  const max = armyCap(); S.sh.forEach(x => x.eq = false); const by = [...S.sh].sort((a, b) => shadowPow(b) - shadowPow(a)); const q = Math.max(1, Math.round(max * 0.2)); let n = 0;
  for (const r of ['tank', 'heal']) for (const x of by.filter(y => roleOf(y) === r).slice(0, q)) { x.eq = true; n++; }
  for (const x of by) { if (n >= max) break; if (!x.eq && roleOf(x) === 'dps') { x.eq = true; n++; } }
  for (const x of by) { if (n >= max) break; if (!x.eq) { x.eq = true; n++; } }
}
export function relicSlotsN() { return relicSlots(S.lvl); }
export const owned = () => Object.keys(S.w).length + Object.keys(S.rel).length + Object.keys(S.acc).length;

/* ---------- licence de Chasseur : rang F → S, un examen par rang ---------- */
const done = w => S.stage[w] >= 10;
export const HUNTER = [
  { r: 1, c: [['Niveau 10', () => S.lvl >= 10], ['Cité Néon — palier 5', () => S.stage[0] >= 4], ['Éveiller 30 ombres', () => S.st.arises >= 30]] },
  { r: 2, c: [['Conquérir la Cité Néon', () => done(0)], ['Terminer un portail de rang E', () => S.dgDone[1] > 0], ['Tour — étage 8', () => S.tower >= 8]] },
  { r: 3, c: [['Conquérir la Forêt d\'Émeraude', () => done(1)], ['Terminer un portail de rang D', () => S.dgDone[2] > 0], ['Vaincre 2 boss légendaires', () => (S.st.legends || 0) >= 2]] },
  { r: 4, c: [['Conquérir la Nécropole Pâle', () => done(2)], ['Terminer un portail de rang C', () => S.dgDone[3] > 0], ['Tour — étage 24', () => S.tower >= 24]] },
  { r: 5, c: [['Citadelle Abyssale — palier 5', () => S.stage[3] >= 4], ['Terminer un portail de rang B', () => S.dgDone[4] > 0], ['Posséder 5 ombres uniques', () => S.sh.filter(x => x.u).length >= 5]] },
  { r: 6, c: [['Conquérir la Citadelle Abyssale', () => done(3)], ['Terminer un portail de rang A', () => S.dgDone[5] > 0], ['Tour — étage 48', () => S.tower >= 48]] },
];
export const examReady = () => S.hunter < 6 && HUNTER[S.hunter].c.every(x => x[1]());
export function promote() { if (!examReady()) return false; S.hunter++; S.pts += 5; S.armyB++; S.gems += 100 * S.hunter; dirty(); save(); return true; }
