/* UMBRA — état du joueur, sauvegarde, calcul des bonus */
import { WEAPONS, RELICS, ACCS, ACH, wPower, aMult, shadowPow, armyMax, relicSlots } from './data.js';

const KEY = 'umbra_v3';
export function fresh() {
  return {
    lvl: 1, xp: 0, cash: 0, gems: 150,
    w: { w1: { lv: 0, st: 0 } }, wEq: 'w1',
    rel: {}, relEq: [],
    acc: {}, accEq: { tete: null, cape: null, plastron: null, bottes: null },
    sh: [], shN: 0, keys: [0, 0, 0, 0, 0, 0, 0], dgDone: [0, 0, 0, 0, 0, 0, 0],
    world: -1, tower: 0, spinT: 0, stage: [0, 0, 0, 0], maxWorld: 0, prog: { kills: 0, brutes: 0 },
    st: { legends: 0, chests: 0, kills: 0, brutes: 0, bosses: 0, arises: 0, lucky: 0, upgrades: 0, play: 0, best: 0 },
    q: { day: 0, p: {}, done: {} }, ach: {},
    auto: true, autoArise: false, sfx: true, music: true, hq: true, tuto: 0,
  };
}
export let S = fresh();
export function load() {
  try { const d = JSON.parse(localStorage.getItem(KEY)); if (d) S = Object.assign(fresh(), d); } catch (e) { }
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
export const heroMp = () => 100 + 6 * (S.lvl - 1);
export const shDmg = sh => shadowPow(sh) * (1 + bonus().sdmg / 100) * (1 + bonus().all / 100);
export const equipped = () => S.sh.filter(s => s.eq);
export function power() { return heroDmg() * 3 + equipped().reduce((a, s) => a + shDmg(s), 0); }
export function autoEquipShadows() {
  const max = armyMax(S.lvl); S.sh.forEach(s => s.eq = false);
  [...S.sh].sort((a, b) => shadowPow(b) - shadowPow(a)).slice(0, max).forEach(s => s.eq = true);
}
export function relicSlotsN() { return relicSlots(S.lvl); }
export const owned = () => Object.keys(S.w).length + Object.keys(S.rel).length + Object.keys(S.acc).length;
