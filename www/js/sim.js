// FRACTURE — simulation de combat DÉTERMINISTE (pas fixe 60 Hz, RNG seedée).
// Toute la logique de jeu vit ici. Rejouer les mêmes entrées avec la même graine = même combat (replay).
import * as THREE from 'three';
import { play } from './render.js';

export const TICK = 1 / 60;

// ---------- Données ----------
export const LAMES = {
  braise: {
    id: 'braise', name: 'BRAISE', col: 0xff7a1a, core: 0xfff1c0, base: 10,
    pitch: 'Chaque faille touchée s\'embrase (brûlure).',
    twist: 'GESTE : fais une BOUCLE autour d\'une faille → Brasier ×1.6.',
    res: 'Résonance : le tracé entier explose.',
  },
  chaine: {
    id: 'chaine', name: 'CHAÎNE', col: 0x22f0ff, core: 0xe8ffff, base: 9,
    pitch: 'Les liens s\'enchaînent : chaque bon lien rapporte plus.',
    twist: 'GESTE : repasse sur une faille déjà touchée → +1 coup (×2 max).',
    res: 'Résonance : un écho rejoue tous les coups.',
  },
  miroir: {
    id: 'miroir', name: 'MIROIR', col: 0xb46bff, core: 0xf3e6ff, base: 7.5,
    pitch: 'Une lame fantôme frappe les failles en symétrie.',
    twist: 'GESTE : trace un seul côté, le reflet frappe l\'autre.',
    res: 'Résonance : triple reflet.',
  },
  chrono: {
    id: 'chrono', name: 'CHRONO', col: 0x7dffcf, core: 0xf0fff8, base: 10,
    pitch: 'Le temps ralentit tant que ton doigt trace.',
    twist: 'GESTE : trace lentement et précis — mais tracer plus d\'1 s coûte plus d\'endurance. Fenêtres parfaites ×1.6.',
    res: 'Résonance : le temps s\'arrête, nouvelle fenêtre gratuite.',
  },
};

// Attaques : lignes en coordonnées relatives au torse de l'ennemi, en unités de "hauteur écran" de l'ennemi.
const A = (a, b, at = 0, anim = null) => ({ a, b, at, anim });
export const ATTACKS = {
  m_slash: { anim: '1H_Melee_Attack_Slice_Horizontal', tele: 0.95, dmg: 11, lines: [A([-0.55, 0.02], [0.55, -0.1])] },
  m_chop: { anim: '1H_Melee_Attack_Chop', tele: 0.9, dmg: 13, lines: [A([0.1, -0.55], [-0.06, 0.45])] },
  m_stab: { anim: '1H_Melee_Attack_Stab', tele: 0.8, dmg: 10, lines: [A([-0.42, -0.3], [0.38, 0.32])] },
  r_double: { anim: 'Dualwield_Melee_Attack_Slice', tele: 0.8, dmg: 9, lines: [A([-0.55, -0.32], [0.5, 0.26], 0), A([-0.55, 0.26], [0.5, -0.32], 0.36, 'Dualwield_Melee_Attack_Stab')] },
  r_jump: { anim: '1H_Melee_Attack_Jump_Chop', tele: 1.05, dmg: 16, lines: [A([0.02, -0.62], [-0.02, 0.5])], heavy: true },
  r_triple: { anim: 'Dualwield_Melee_Attack_Stab', tele: 0.75, dmg: 7, lines: [A([-0.5, 0.0], [0.5, 0.02], 0), A([-0.34, -0.38], [0.34, 0.36], 0.3, 'Dualwield_Melee_Attack_Slice'), A([0.34, -0.38], [-0.34, 0.36], 0.58, 'Dualwield_Melee_Attack_Stab')] },
  r_feint: { anim: 'Dualwield_Melee_Attack_Slice', tele: 0.75, dmg: 0, feint: true, follow: 'r_jump', lines: [A([-0.5, -0.3], [0.5, 0.3])] },
  b_chop: { anim: '2H_Melee_Attack_Chop', tele: 1.15, dmg: 22, lines: [A([0.06, -0.58], [-0.05, 0.5])], heavy: true },
  b_sweep: { anim: '2H_Melee_Attack_Slice', tele: 1.0, dmg: 18, lines: [A([-0.62, 0.16], [0.62, 0.06])], heavy: true },
  b_combo: { anim: '2H_Melee_Attack_Chop', tele: 0.9, dmg: 13, lines: [A([0.4, -0.45], [-0.4, 0.4], 0), A([-0.45, -0.3], [0.45, 0.32], 0.44, '2H_Melee_Attack_Slice'), A([-0.55, 0.02], [0.55, 0.0], 0.88, '2H_Melee_Attack_Stab')] },
  b_spin: { anim: '2H_Melee_Attack_Spin', tele: 1.1, dmg: 26, kind: 'purple', lines: [A([-0.8, 0.28], [0.8, 0.28])], heavy: true },
  b_leap: { anim: '1H_Melee_Attack_Jump_Chop', tele: 1.25, dmg: 24, lines: [A([0.0, -0.66], [0.0, 0.55])], heavy: true },
  b_cross: { anim: '2H_Melee_Attack_Slice', tele: 1.0, dmg: 15, lines: [A([-0.45, -0.42], [0.45, 0.42], 0), A([0.45, -0.42], [-0.45, 0.42], 0)], cross: true },
};
export const ENEMIES = {
  minion: { id: 'minion', name: 'GRUNT D\'OS', title: 'VAGUE 1', hp: 140, scale: 1.0, rim: 0xff2e88, eyes: 0x22f0ff, weapon: '1H_Sword', wScale: 1,
    intro: 'Spawn_Ground_Skeletons', idle: [0.6, 1.1], openP: 0.92, failles: 2, D: 1.5, curveP: 0, atk: [['m_slash', 3], ['m_chop', 2], ['m_stab', 2]],
    framing: { pos: [0.6, 1.45, 4.3], look: [-0.55, 1.05, 0] }, par: 35 },
  rogue: { id: 'rogue', name: 'LAME JUMELLE', title: 'VAGUE 2', hp: 190, scale: 1.0, rim: 0xb46bff, eyes: 0xff2e88, weapon: '1H_Sword', wScale: 0.75, dual: true,
    intro: 'Spawn_Ground_Skeletons', idle: [0.45, 0.9], openP: 0.8, failles: 3, D: 1.3, curveP: 0.35, atk: [['r_double', 3], ['r_jump', 2], ['r_triple', 2], ['r_feint', 1]],
    framing: { pos: [0.6, 1.45, 4.3], look: [-0.55, 1.05, 0] }, par: 45 },
  boss: { id: 'boss', name: 'LE GARDIEN FÊLÉ', title: 'BOSS', hp: 1250, scale: 1.75, rim: 0xff3030, eyes: 0xff2e88, weapon: '2H_Sword', wScale: 1.0,
    intro: 'Skeletons_Awaken_Standing', idle: [0.55, 1.0], openP: 0.75, failles: 3, D: 1.35, curveP: 0.35,
    atk: [['b_chop', 3], ['b_sweep', 3], ['b_combo', 2], ['b_spin', 2], ['b_leap', 2]],
    p2: { failles: 4, D: 1.15, curveP: 0.5, tele: 0.82, idle: [0.35, 0.75], atk: [['b_chop', 2], ['b_sweep', 2], ['b_combo', 3], ['b_spin', 2], ['b_leap', 2], ['b_cross', 3]] },
    framing: { pos: [1.0, 2.55, 9.4], look: [-0.7, 2.2, 0] }, par: 120 },
};
export const RUN = ['minion', 'rogue', 'boss'];
const FAILLE_BONES = ['head', 'chest', 'spine', 'hips', 'upperarm.l', 'upperarm.r', 'lowerarm.l', 'lowerarm.r', 'hand.l', 'hand.r', 'upperleg.l', 'upperleg.r', 'lowerleg.l', 'lowerleg.r'];
const MIRROR_SIDE = ['upperarm.l', 'lowerarm.l', 'upperleg.l', 'lowerleg.l', 'hand.l'];
const mirrorOf = b => b.replace('.l', '.r');

export const HERO_POS = new THREE.Vector3(-2.0, 0, -0.15);
const HERO_LUNGE = new THREE.Vector3(-1.45, 0, 0.0);
export const R_FAILLE = 0.058;       // rayon de touche (unités écran = fraction de la hauteur)
const PARRY_PRE = 0.30, PARRY_POST = 0.07, PERF_PRE = 0.09, PERF_POST = 0.05;

export function rng(seed) { let a = seed >>> 0; return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
function segDist(p, a, b) { const dx = b.x - a.x, dy = b.y - a.y; const l2 = dx * dx + dy * dy || 1e-9; let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2; t = Math.max(0, Math.min(1, t)); return Math.hypot(a.x + dx * t - p.x, a.y + dy * t - p.y); }
function segX(p1, p2, p3, p4) {
  const d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x); if (Math.abs(d) < 1e-9) return null;
  const t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d, u = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / d;
  if (t < 0 || t > 1 || u < 0 || u > 1) return null; return { x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t, t, u };
}
function pip(pt, poly) { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const a = poly[i], b = poly[j]; if ((a.y > pt.y) !== (b.y > pt.y) && pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x) c = !c; } return c; }
function wpick(r, list) { let s = 0; list.forEach(x => s += x[1]); let v = r() * s; for (const x of list) { v -= x[1]; if (v <= 0) return x[0]; } return list[0][0]; }

const _w = new THREE.Vector3();

export class Sim {
  // W = { hero, enemies:{minion,rogue,boss}, project(v,out), aspect(), setFraming(f,dur), applyFraming(dt) }
  constructor(W, emit, { seed = 1, lame = 'braise', tuto = false, replay = null, fights = RUN } = {}) {
    this.W = W; this.emit = emit; this.seed = seed; this.r = rng(seed); this.lame = LAMES[lame]; this.lameId = lame;
    this.fights = fights; this.replay = replay; this.rec = { v: 1, seed, lame, aspect: W.aspect(), fights, events: [] };
    this.tick = 0; this.T = 0; this.ts = 1; this.queue = [];
    this.hitstop = 0; this.slow = 0; this.slowF = 1;
    this.hero = { hp: 100, max: 100, st: 3, stMax: 3, stT: 0, res: 0, armed: false, ifr: -1, guard: false, guardT: 0, busy: -1, stag: -1, lungeT: 0, dodgeT: -1, dodgeDir: 0, dead: false, holdArm: 0 };
    this.g = null; this.blade = null; this.blades = []; this.pendingRelease = null;
    this.win = null; this.lines = []; this.e = null; this.fi = -1;
    this.state = 'start'; this.stT = 0; this.over = null;
    this.combo = 0; this.score = 0;
    this.stats = { faillesTot: 0, faillesHit: 0, qSum: 0, ruptures: 0, perfects: 0, parries: 0, pParries: 0, dodges: 0, guards: 0, atkTot: 0, atkAvoid: 0, dmgTaken: 0, dmgPot: 0, maxCombo: 0, time: 0, fightsWon: 0 };
    this.tutoOn = tuto; this.tuto = null; this.frozen = -1; this.chronoActive = false;
    this.recording = !tuto && !replay;
    this.tmp = { x: 0, y: 0 };
  }

  // ---------- Entrées ----------
  input(k, x, y) { this.queue.push([k, Math.round(x * 10000) / 10000, Math.round(y * 10000) / 10000]); }

  step() {
    let evs;
    if (this.replay) { evs = []; const R = this.replay.events; while (this.rp === undefined) this.rp = 0; while (this.rp < R.length && R[this.rp][0] <= this.tick) { evs.push(R[this.rp].slice(1)); this.rp++; } }
    else { evs = this.queue; this.queue = []; if (this.recording) evs.forEach(e => this.rec.events.push([this.tick, ...e])); }
    for (const [k, x, y] of evs) { if (k === 'd') this.onDown(x, y); else if (k === 'm') this.onMove(x, y); else if (k === 'u') this.onUp(x, y); }
    this.update();
    this.tick++;
  }

  // ---------- Temps ----------
  timeScale() {
    if (this.hitstop > 0) return 0;
    let s = 1;
    if (this.slow > 0) s = Math.min(s, this.slowF);
    if (this.chronoActive) s = Math.min(s, 0.4);
    if (this.tuto && this.tuto.slowWin) { const L = this.lines.find(l => l.state === 'live'); if (L && this.T > L.impact - PARRY_PRE - 0.25 && this.T < L.impact + 0.05) s = Math.min(s, 0.3); }
    return s;
  }
  addHitstop(ms) { this.hitstop = Math.max(this.hitstop, Math.round(ms / 1000 / TICK)); }
  addSlow(sec, f) { const active = this.slow > 0; this.slow = Math.max(this.slow, Math.round(sec / TICK)); this.slowF = active ? Math.min(this.slowF, f) : f; }

  // ---------- Geste : tracer / relâcher / tapoter / maintenir ----------
  onDown(x, y) {
    if (this.state !== 'fight' || this.hero.dead) return;
    this.g = { x0: x, y0: y, t0: this.tick, mode: 'pend', pts: [{ x, y }], maxD: 0, parried: false, touch: [], ex: false };
  }
  onMove(x, y) {
    const g = this.g; if (!g) return;
    const last = g.pts[g.pts.length - 1];
    if (Math.hypot(x - last.x, y - last.y) < 0.004) return;
    if (g.mode === 'hold') {
      if (Math.hypot(x - g.hx, y - g.hy) > 0.06) { this.endGuard(); g.pts = [{ x: g.hx, y: g.hy }]; this.startTrace(g); }
      else return;
    }
    g.pts.push({ x, y }); if (g.pts.length > 240) g.pts.splice(1, 1);
    g.maxD = Math.max(g.maxD, Math.hypot(x - g.x0, y - g.y0));
    if (g.mode === 'pend' && g.maxD > 0.028) this.startTrace(g);
    if (g.mode === 'trace') this.traceSeg(g, g.pts[g.pts.length - 2], g.pts[g.pts.length - 1]);
  }
  onUp(x, y) {
    const g = this.g; if (!g) return; this.g = null;
    if (g.mode === 'pend') this.dodge(x < this.W.aspect() / 2 ? -1 : 1);
    else if (g.mode === 'hold') this.endGuard();
    else if (g.mode === 'trace') {
      this.chronoActive = false; if (this.lameId === 'chrono') this.emit('chronoOut');
      this.emit('traceEnd');
      if (this.blade && this.blade.t < this.blade.dur) this.pendingRelease = g; // buffer d'entrée
      else this.release(g);
    }
  }
  startTrace(g) {
    g.mode = 'trace'; g.ex = this.hero.st < 1; g.tStart = this.T; g.realStart = this.tick;
    if (this.lameId === 'chrono') { this.chronoActive = true; this.emit('chronoIn'); }
    this.emit('traceStart', { ex: g.ex });
    if (this.win && !this.win.resolved) { this.win.f.forEach(f => { f.touchIdx = -1; f.q = 0; f.inside = false; f.extra = 0; f.s = 0; f.left = false; }); this.win.seg.forEach(s => s.ok = false); }
    g.len = 0; g.order = []; g.extras = 0; g.extraS = null;
    // le segment initial compte aussi (point de départ)
    if (g.pts.length > 1) for (let i = 1; i < g.pts.length; i++) this.traceSeg(g, g.pts[i - 1], g.pts[i]);
  }
  traceSeg(g, a, b) {
    g.len = (g.len || 0) + dist(a, b);
    // PARADE : le tracé traverse une ligne rouge pendant sa fenêtre
    for (const L of this.lines) {
      if (L.state !== 'live' || L.kind === 'purple') continue;
      const hit = segX(a, b, L.A, L.B); if (!hit) continue;
      const dt = this.T - L.impact;
      if (L.feint) { if (this.T >= L.feintAt - 0.28 && this.T <= L.feintAt) this.feintTrap(L, hit); continue; }
      if (dt >= -PARRY_PRE && dt <= PARRY_POST) {
        const perfWin = this.lameId === 'chrono' ? 1.6 : 1;
        this.parry(L, hit, dt >= -PERF_PRE * perfWin && dt <= PERF_POST * perfWin);
        g.parried = true;
      } else if (dt < -PARRY_PRE && !L.early) { L.early = true; this.emit('text', { t: 'TROP TÔT', cls: 'warn', x: hit.x, y: hit.y }); }
    }
    // FAILLES : ordre de passage, qualité, courbes, repasses (Chaîne)
    const W = this.win; if (!W || W.resolved) return;
    const r = R_FAILLE * (this.e && this.e.def.id === 'boss' ? 1.05 : 1);
    W.f.forEach((f, i) => {
      const d = segDist(f, a, b);
      if (d <= r) {
        const q = 1 - d / r;
        if (f.touchIdx < 0) {
          f.touchIdx = g.order.length; g.order.push(i); f.q = q; f.s = g.len; f.inside = true;
          const expected = g.order.length; const ok = f.n === expected;
          this.emit('touch', { i, ok, n: f.n, x: f.x, y: f.y });
        } else {
          f.q = Math.max(f.q, q);
          if (!f.inside && f.left && this.lameId === 'chaine' && f.extra < 2) { f.extra++; f.left = false; this.emit('chainRe', { x: f.x, y: f.y, n: f.extra }); g.extras = (g.extras || 0) + 1; (g.extraS || (g.extraS = [])).push({ i, s: g.len }); }
          f.inside = true;
        }
      } else if (d > r * 1.35) { if (f.inside) f.left = true; f.inside = false; }
    });
    // courbes : le tracé doit frôler le point de contrôle entre les failles k et k+1
    W.seg.forEach((s, k) => {
      if (!s.curve || s.ok) return;
      const fa = W.f[W.order[k]], fb = W.f[W.order[k + 1]];
      if (fa.touchIdx >= 0 && fb.touchIdx < 0) { const c = this.curveCtrl(fa, fb, s); if (segDist(c, a, b) <= r * 1.15) { s.ok = true; this.emit('curveOk', { x: c.x, y: c.y }); } }
    });
  }
  curveCtrl(fa, fb, s) { const mx = (fa.x + fb.x) / 2, my = (fa.y + fb.y) / 2, dx = fb.x - fa.x, dy = fb.y - fa.y; return { x: mx - dy * 0.42 * s.sign, y: my + dx * 0.42 * s.sign }; }

  // ---------- Relâcher : résolution de la Rupture ----------
  release(g) {
    const H = this.hero, W = this.win;
    const pts = g.pts.slice();
    if (pts.length < 2) return;
    const cost = (this.lameId === 'chrono' && (this.tick - (g.realStart || this.tick)) > 72) ? 2 : 1;
    if (g.parried && (!W || W.resolved)) { this.bladeFx(pts, [], { parryOnly: true }); return; }
    this.spend(cost);
    if (!W || W.resolved) { this.bladeFx(pts, [], { whiff: true }); this.emit('whiff'); return; }
    W.resolved = true;
    const n = W.f.length;
    const hitF = W.f.map((f, i) => ({ f, i })).filter(o => o.f.touchIdx >= 0).sort((a, b) => a.f.touchIdx - b.f.touchIdx);
    let links = 0; for (let k = 0; k < hitF.length; k++) { if (hitF[k].f.n === k + 1) links++; else break; }
    const allHit = hitF.length === n, orderOK = allHit && links === n;
    const curves = W.seg.filter(s => s.curve), curvesOK = curves.filter(s => s.ok).length;
    const allCurves = curvesOK === curves.length;
    // timing
    let timing = 'ok', tm = 1;
    if (!W.infinite) {
      const dt = this.T - W.close, k = this.lameId === 'chrono' ? 1.6 : 1;
      if (Math.abs(dt) <= 0.09 * k) { timing = 'perfect'; tm = 1.5; }
      else if (Math.abs(dt) <= 0.22 * k) { timing = 'good'; tm = 1.2; }
      else if (dt < 0) { timing = 'early'; tm = 0.92; }
      else { timing = 'late'; tm = 0.92; }
    }
    if (W.chronoFree) { timing = 'perfect'; tm = 1.5; }
    // Braise : boucles autour des failles
    const brasier = new Set();
    if (this.lameId === 'braise' && pts.length > 6) {
      for (let i = 1; i < pts.length; i++) for (let j = i + 2; j < pts.length; j++) {
        const x = segX(pts[i - 1], pts[i], pts[j - 1], pts[j]); if (!x) continue;
        const poly = [x, ...pts.slice(i, j)]; if (poly.length < 4) continue;
        W.f.forEach((f, fi) => { if (pip(f, poly)) brasier.add(fi); });
      }
    }
    const ex = g.ex;
    let mult = 1 + 0.15 * Math.max(0, links - 1) * (this.lameId === 'chaine' ? 2.2 : 1) + (orderOK ? 0.25 : 0) + 0.25 * curvesOK;
    mult *= tm; if (W.riposte) mult *= 1.3; if (ex) mult *= 0.5;
    const res = H.armed; if (res) { mult *= 1.8; H.armed = false; this.emit('resUsed'); }
    const perfect = allHit && orderOK && allCurves && timing === 'perfect' && !ex;
    if (perfect) mult *= 1.5;
    if (this.lameId === 'chaine' && g.extras) mult *= 1 + 0.2 * g.extras;
    const base = this.lame.base;
    const hits = [];
    hitF.forEach(({ f, i }) => {
      let d = base * (0.7 + 0.3 * f.q) * mult * (brasier.has(i) ? 1.6 : 1);
      hits.push({ s: f.s, i, dmg: d, x: f.x, y: f.y, burn: this.lameId === 'braise' ? (brasier.has(i) ? 2 : 1) : 0, brasier: brasier.has(i) });
      if (this.lameId === 'miroir' && f.ghost) hits.push({ s: f.s + 0.0001, i, dmg: d, x: f.ghost.x, y: f.ghost.y, ghost: true });
    });
    if (this.lameId === 'chaine' && g.extraS) g.extraS.forEach(e => hits.push({ s: e.s, i: e.i, dmg: base * 0.8 * mult, x: W.f[e.i].x, y: W.f[e.i].y, chain: true }));
    hits.sort((a, b) => a.s - b.s);
    // stats
    this.stats.ruptures++; this.stats.faillesTot += n; this.stats.faillesHit += hitF.length;
    this.stats.qSum += (hitF.reduce((s, o) => s + o.f.q, 0) / n) * 0.5 + (orderOK ? 0.2 : 0) + (timing === 'perfect' ? 0.3 : timing === 'good' ? 0.2 : 0.05);
    if (perfect) this.stats.perfects++;
    const result = { hits, links, n, allHit, orderOK, curvesOK, curves: curves.length, timing, perfect, brasier: brasier.size, res, ex, riposte: W.riposte, mult };
    this._lastRes = result; if (this.tuto) this._pendingTuto = 'rupture';
    this.emit('rupture', result);
    if (hitF.length === 0) { this.comboBreak(); this.emit('text', { t: 'RATÉ', cls: 'bad' }); }
    // résonance : effets de lame
    if (res) {
      if (this.lameId === 'braise') hits.push({ s: 9e9, i: -1, dmg: 40, x: this.e.anchor.x, y: this.e.anchor.y, boom: true, burn: 5 });
      if (this.lameId === 'miroir') hits.forEach(h => h.dmg *= 1.6);
    }
    this.bladeFx(pts, hits, { perfect, res, result });
    this.closeWindow(perfect ? 'perfect' : 'done', true);
    if (res && this.lameId === 'chrono') this.chronoStop = true;
  }
  bladeFx(pts, hits, o) {
    const len = pts.reduce((s, p, i) => i ? s + dist(p, pts[i - 1]) : 0, 0) || 0.001;
    const dur = Math.min(0.32, Math.max(0.13, 0.08 + len * 0.22));
    this.blade = { pts, len, dur, t: 0, hits, hi: 0, o, done: false, echo: o.res && this.lameId === 'chaine' };
    this.blades.push(this.blade);
    const H = this.hero; H.busy = this.T + dur + 0.12; H.lungeT = 0.001;
    // animation héros selon la direction dominante du tracé
    const a = pts[0], b = pts[pts.length - 1], ang = Math.abs(Math.atan2(b.y - a.y, b.x - a.x));
    const anim = len < 0.12 ? '1H_Melee_Attack_Stab' : (ang < 0.5 || ang > 2.6) ? '1H_Melee_Attack_Slice_Horizontal' : (ang > 1.2 && ang < 1.9) ? '1H_Melee_Attack_Chop' : '1H_Melee_Attack_Slice_Diagonal';
    play(this.W.hero, anim, { ts: 1.0 / Math.max(0.5, dur * 2.2), fade: 0.05 });
    this.emit('blade', { len, perfect: o.perfect, whiff: o.whiff });
  }
  updBlade(dt) {
    for (const B of this.blades) {
      if (B.done) continue;
      B.t += dt;
      const head = Math.min(1, B.t / B.dur) * B.len;
      while (B.hi < B.hits.length && (B.hits[B.hi].s <= head || B.t >= B.dur)) { this.applyHit(B.hits[B.hi], B, B.hi === B.hits.length - 1); B.hi++; }
      if (B.t >= B.dur + 0.35) {
        B.done = true;
        if (B.echo) { B.echo = false; const echo = B.hits.filter(h => !h.boom).map(h => ({ ...h, dmg: h.dmg * 0.6, echo: true })); if (echo.length) { this.emit('echo'); this.bladeFx(B.pts, echo, { echoOf: true }); } }
      }
    }
    this.blades = this.blades.filter(b => !b.done || b === this.blade);
    if (this.blade && this.blade.done) this.blade = null;
    if (this.pendingRelease && (!this.blade || this.blade.t >= this.blade.dur)) { const g = this.pendingRelease; this.pendingRelease = null; this.release(g); }
  }
  applyHit(h, B, last) {
    const e = this.e; if (!e || e.state === 'dying' || e.state === 'dead') return;
    const dmg = Math.round(h.dmg);
    if (!this.tuto) e.hp = Math.max(0, e.hp - dmg);
    if (h.burn) { e.burn = Math.min(6, e.burn + h.burn); e.burnT = 4; }
    this.combo++; this.stats.maxCombo = Math.max(this.stats.maxCombo, this.combo);
    this.addScore(dmg * 3);
    const perfect = B.o.perfect && last;
    this.addHitstop(perfect ? 120 : (h.boom ? 90 : 42));
    if (perfect) { this.addSlow(0.55, 0.18); this.gainRes(20); }
    this.gainRes(this.lameId === 'chrono' ? 6 : 8);
    e.flash = 1;
    if (e.state !== 'open' && e.state !== 'dying') { play(e.a, Math.floor(this.T * 10) % 2 ? 'Hit_A' : 'Hit_B', { ts: 1.3, fade: 0.04 }); e.hitT = 0.35; }
    this.emit('hit', { ...h, dmg, perfect, last, combo: this.combo });
    if (e.hp <= 0 && !this.tuto) this.killEnemy();
    else if (this.e.def.p2 && !e.p2 && e.hp <= e.max * 0.5) this.phase2();
  }

  // ---------- Défense ----------
  parry(L, hit, perfect) {
    L.state = 'parried'; L.parriedPerfect = perfect;
    this.stats.parries++; if (perfect) this.stats.pParries++;
    this.stats.atkAvoid++; this.stats.dmgPot += L.dmg;
    this.combo++; this.stats.maxCombo = Math.max(this.stats.maxCombo, this.combo);
    this.addScore(perfect ? 300 : 150);
    this.addHitstop(perfect ? 90 : 55);
    if (perfect) { this.addSlow(0.5, 0.15); this.gainRes(25); this.hero.st = Math.min(this.hero.stMax, this.hero.st + 1); }
    else this.gainRes(10);
    play(this.W.hero, 'Block_Attack', { ts: 1.6, fade: 0.04 }); this.hero.busy = this.T + 0.2;
    const e = this.e; if (e) { play(e.a, 'Block', { ts: 1.4, fade: 0.05 }); e.recoil = 0.25; }
    this.emit('parry', { x: hit.x, y: hit.y, perfect, line: L });
    if (this.tuto) this.tutoEvent('parry');
  }
  feintTrap(L, hit) { if (L.trapped) return; L.trapped = true; this.spend(1); this.comboBreak(); this.emit('text', { t: 'FEINTE !', cls: 'bad', x: hit.x, y: hit.y }); }
  dodge(dir) {
    const H = this.hero; if (H.dead) return;
    if (H.st < 1) { this.emit('text', { t: 'ÉPUISÉ', cls: 'warn' }); return; }
    this.spend(1);
    H.ifr = this.T + 0.32; H.dodgeT = 0; H.dodgeDir = dir; H.dodgeStart = this.T; H.busy = this.T + 0.3;
    play(this.W.hero, dir < 0 ? 'Dodge_Left' : 'Dodge_Right', { ts: 1.1, fade: 0.04 });
    this.emit('dodgeStart', { dir });
  }
  startGuard() { const H = this.hero; H.guard = true; H.guardT = 0; H.holdArm = 0; play(this.W.hero, 'Blocking', { loop: true, fade: 0.08 }); this.emit('guardOn'); }
  endGuard() { const H = this.hero; if (!H.guard) return; H.guard = false; this.emit('guardOff'); play(this.W.hero, '2H_Melee_Idle', { loop: true, fade: 0.15 }); }
  spend(n) { const H = this.hero; H.st = Math.max(0, H.st - n); H.stT = 0; this.emit('stamina'); }
  gainRes(v) { const H = this.hero; if (H.armed) return; const was = H.res; H.res = Math.min(100, H.res + v); if (was < 100 && H.res >= 100) this.emit('resReady'); }
  comboBreak() { if (this.combo >= 3) this.emit('comboBreak', { n: this.combo }); this.combo = 0; }
  addScore(v) { this.score += Math.round(v * (1 + Math.min(this.combo, 50) * 0.02)); }

  // ---------- Fenêtres de failles ----------
  openWindow({ n, D, curveP = 0, riposte = false, infinite = false, chronoFree = false } = {}) {
    const e = this.e; if (!e) return;
    const mirror = this.lameId === 'miroir';
    const avail = (mirror ? [...MIRROR_SIDE, 'head', 'chest', 'hips'] : FAILLE_BONES).filter(b => e.a.bones[b]);
    // positions courantes à l'écran
    const P = {}; avail.forEach(b => { e.a.bones[b].getWorldPosition(_w); P[b] = this.W.project(_w, { x: 0, y: 0 }); });
    // toujours n failles : on relâche l'écart minimal si l'ennemi est petit à l'écran
    let chosen = [], best = [];
    for (let tries = 0; tries < 60 && chosen.length < n; tries++) {
      const minD = Math.max(0.125, 0.16 - Math.floor(tries / 12) * 0.01);
      chosen = []; const pool = avail.slice();
      while (chosen.length < n && pool.length) {
        const b = pool.splice(Math.floor(this.r() * pool.length), 1)[0];
        if (chosen.every(c => dist(P[c], P[b]) > minD)) chosen.push(b);
      }
      if (chosen.length > best.length) best = chosen;
    }
    if (chosen.length < n) chosen = best;
    const f = chosen.map((b, k) => ({ bone: b, n: k + 1, x: P[b].x, y: P[b].y, touchIdx: -1, q: 0, inside: false, left: false, extra: 0, s: 0, ghostBone: mirror && MIRROR_SIDE.includes(b) && e.a.bones[mirrorOf(b)] ? mirrorOf(b) : null, ghost: null }));
    // ordre affiché = 1..n, on mélange l'attribution des numéros
    const nums = f.map((_, k) => k + 1); for (let i = nums.length - 1; i > 0; i--) { const j = Math.floor(this.r() * (i + 1)); [nums[i], nums[j]] = [nums[j], nums[i]]; }
    f.forEach((x, k) => x.n = nums[k]);
    const order = f.map((x, i) => i).sort((a, b) => f[a].n - f[b].n);
    const seg = []; for (let k = 0; k < f.length - 1; k++) seg.push({ curve: this.r() < curveP, sign: this.r() < 0.5 ? -1 : 1, ok: false });
    this.win = { f, order, seg, T0: this.T, close: this.T + D, D, riposte, infinite, resolved: false, chronoFree };
    this.updWindowPos();
    // si un tracé est déjà en cours, il démarre sur cette fenêtre
    if (this.g && this.g.mode === 'trace') { this.g.order = []; this.g.len = 0; }
    e.state = 'open'; e.stT = 0;
    play(e.a, 'Hit_B', { ts: 0.25, fade: 0.1, from: 0.3 });
    this.emit('open', { riposte, n });
  }
  updWindowPos() {
    const W = this.win; if (!W) return;
    W.f.forEach(f => {
      this.e.a.bones[f.bone].getWorldPosition(_w); this.W.project(_w, f);
      if (f.ghostBone) { this.e.a.bones[f.ghostBone].getWorldPosition(_w); f.ghost = this.W.project(_w, f.ghost || { x: 0, y: 0 }); }
    });
  }
  closeWindow(reason, keepState) {
    const W = this.win; if (!W) return;
    this.emit('close', { reason, win: W });
    this.win = null;
    const e = this.e;
    if (this.tuto || !keepState || reason !== 'perfect' || W.riposte) { if (e && e.state === 'open') { e.state = 'idle'; e.stT = 0; e.idleDur = 0.5 + this.r() * 0.4; play(e.a, 'Idle_Combat', { loop: true, fade: 0.2 }); } }
    else if (e && e.state === 'open') { e.state = 'stagger'; e.stT = 0; e.stagDur = 0.9; play(e.a, 'Hit_A', { ts: 0.8, fade: 0.05 }); }
  }

  // ---------- Attaques ennemies ----------
  startAttack(id, { teleMul = 1 } = {}) {
    const e = this.e, def = ATTACKS[id];
    const tele = def.tele * teleMul * (e.p2 ? e.def.p2.tele : 1);
    const H = e.H, c = e.anchor;
    e.state = 'attack'; e.stT = 0; e.atk = { id, def, end: 0 };
    this.lines = def.lines.map((l, i) => {
      const impact = this.T + tele + l.at * (e.p2 ? 0.85 : 1);
      const L = { A: { x: c.x + l.a[0] * H * 1.2, y: c.y + l.a[1] * H * 1.2 }, B: { x: c.x + l.b[0] * H * 1.2, y: c.y + l.b[1] * H * 1.2 }, impact, show: impact - Math.min(tele + l.at, Math.max(0.62, tele)), anim: l.anim || def.anim, animAt: impact - 0.38, animDone: false, state: 'wait', kind: def.kind || (def.heavy ? 'heavy' : 'red'), dmg: def.dmg, feint: !!def.feint, feintAt: impact - 0.3, i };
      return L;
    });
    e.atk.end = Math.max(...this.lines.map(l => l.impact)) + 0.45;
    // pose d'armement : on démarre l'animation très lentement
    const first = this.lines[0];
    const act = play(e.a, first.anim, { ts: 0.12, fade: 0.15 });
    e.windAct = act;
    this.stats.atkTot += def.feint ? 0 : this.lines.length;
  }
  updLines() {
    const e = this.e, H = this.hero;
    for (const L of this.lines) {
      if (L.state === 'wait' && this.T >= L.show) { L.state = 'live'; this.emit('tele', { line: L }); }
      if ((L.state === 'live' || L.state === 'parried') && !L.animDone && this.T >= L.animAt) {
        L.animDone = true;
        const act = e.a.actions[L.anim]; if (act) { const clip = act.getClip().duration; play(e.a, L.anim, { ts: (clip * 0.42) / 0.38, fade: 0.06, from: 0.04 }); }
      }
      if (L.state === 'live' && L.feint && this.T >= L.feintAt) { L.state = 'feinted'; this.emit('feint', { line: L }); play(e.a, 'Dodge_Left', { fade: 0.08 }); }
      if (L.state === 'live' && this.T >= L.impact + PARRY_POST) this.resolveImpact(L);
    }
    if (e.atk && this.T >= e.atk.end) this.endAttack();
  }
  resolveImpact(L) {
    const H = this.hero; L.state = 'done';
    this.stats.dmgPot += L.dmg;
    if (H.dead) return;
    if (this.T - PARRY_POST <= H.ifr + 0.0001 && H.ifr > 0) {
      const perfect = Math.abs(L.impact - (H.dodgeStart + 0.1)) <= 0.14;
      this.stats.dodges++; this.stats.atkAvoid++;
      this.combo++; this.stats.maxCombo = Math.max(this.stats.maxCombo, this.combo);
      this.addScore(perfect ? 160 : 80); if (perfect) { this.addSlow(0.35, 0.25); this.gainRes(12); }
      this.emit('dodge', { perfect, line: L }); if (this.tuto) this.tutoEvent('dodge');
      return;
    }
    if (H.guard) {
      const mul = L.kind === 'purple' ? 0.6 : 0.3;
      if (H.st >= 1) {
        this.spend(1); this.stats.guards++; this.stats.atkAvoid += 0.5; this.gainRes(6);
        this.damage(Math.round(L.dmg * mul), true); play(this.W.hero, 'Block_Hit', { ts: 1.4, fade: 0.04 });
        this.emit('guard', { broken: false, line: L }); if (this.tuto) this.tutoEvent('guard');
        return;
      }
      this.endGuard(); H.stag = this.T + 0.6;
      this.emit('guard', { broken: true, line: L });
      this.damage(Math.round(L.dmg * 0.6)); return;
    }
    this.damage(L.dmg);
  }
  damage(d, guarded = false) {
    const H = this.hero; if (this.tuto) { this.emit('hurt', { dmg: 0, guarded }); if (!guarded) { play(this.W.hero, 'Hit_A', { ts: 1.2, fade: 0.04 }); this.tutoEvent('hurt'); } return; }
    H.hp = Math.max(0, H.hp - d); this.stats.dmgTaken += d;
    if (!guarded) { this.comboBreak(); play(this.W.hero, 'Hit_A', { ts: 1.2, fade: 0.04 }); H.busy = this.T + 0.3; this.addHitstop(60); }
    this.emit('hurt', { dmg: d, guarded });
    if (H.hp <= 0) this.heroDie();
  }
  endAttack() {
    const e = this.e; const L = this.lines; const def = e.atk.def; e.atk = null;
    const allParried = L.length && L.every(l => l.state === 'parried');
    const anyPerfect = L.some(l => l.parriedPerfect);
    this.lines = [];
    if (this.tuto) { e.state = 'idle'; e.stT = 0; e.idleDur = 99; play(e.a, 'Idle_Combat', { loop: true, fade: 0.2 }); this.tutoEvent('atkEnd'); return; }
    if (def.follow && L.some(l => l.state === 'feinted')) { this.startAttack(def.follow, { teleMul: 0.9 }); return; }
    if (allParried && (anyPerfect || L.length > 1 || def.heavy)) { e.state = 'stagger'; e.stT = 0; e.stagDur = 0.45; e.riposte = true; play(e.a, 'Hit_B', { ts: 0.9, fade: 0.05 }); this.emit('text', { t: 'RIPOSTE !', cls: 'gold' }); return; }
    if (this.r() < this.openP()) { this.openFromDef(false); return; }
    e.state = 'idle'; e.stT = 0; e.idleDur = this.idleDur(); play(e.a, 'Idle_Combat', { loop: true, fade: 0.2 });
  }
  openP() { return this.e.def.openP; }
  idleDur() { const d = this.e.p2 ? this.e.def.p2.idle : this.e.def.idle; return d[0] + this.r() * (d[1] - d[0]); }
  openFromDef(riposte) {
    const e = this.e, d = e.p2 ? e.def.p2 : e.def;
    this.openWindow({ n: Math.min(4, d.failles + (riposte ? 1 : 0)), D: d.D + (riposte ? 0.35 : 0), curveP: d.curveP ?? e.def.curveP, riposte });
  }

  // ---------- Ennemis ----------
  startFight(i) {
    this.fi = i; const def = ENEMIES[this.fights[i]];
    const a = this.W.enemies[def.id];
    Object.values(this.W.enemies).forEach(x => x.root.visible = false);
    a.root.visible = true; a.root.position.set(0, 0, 0);
    a.root.rotation.y = Math.atan2(HERO_POS.x, HERO_POS.z) * 0.45;
    this.e = { def, a, hp: def.hp, max: def.hp, state: 'intro', stT: 0, idleDur: 1, burn: 0, burnT: 0, burnTick: 0, flash: 0, p2: false, H: 0.3, anchor: { x: 0, y: 0 }, riposte: false };
    play(a, def.intro, { ts: def.intro === 'Spawn_Ground_Skeletons' ? 2.2 : 1.0, fade: 0, from: 0 });
    this.W.setFraming(def.framing, i === 0 ? 0 : 1.2);
    this.state = 'fight'; this.stT = 0; this.fightT = 0;
    this.lines = []; this.win = null;
    this.emit('fightStart', { i, def });
  }
  updEnemy(dt) {
    const e = this.e; if (!e) return;
    e.stT += dt; e.flash = Math.max(0, e.flash - dt * 6);
    // ancre écran + taille pour poser les lignes
    if (e.a.bones.chest) { e.a.bones.chest.getWorldPosition(_w); this.W.project(_w, e.anchor); }
    if (e.a.bones.head) { e.a.bones.head.getWorldPosition(_w); _w.y += 0.25 * e.def.scale; const top = this.W.project(_w, this.tmp).y; e.H = Math.max(0.2, (e.anchor.y - top) * 2.4); }
    // brûlure
    if (e.burn > 0 && e.state !== 'dying' && e.state !== 'dead') {
      e.burnT -= dt; e.burnTick += dt;
      if (e.burnTick >= 0.5) { e.burnTick = 0; const d = Math.round(1.5 * e.burn); if (!this.tuto) e.hp = Math.max(0, e.hp - d); this.addScore(d * 2); this.emit('burnTick', { dmg: d, x: e.anchor.x, y: e.anchor.y }); if (e.hp <= 0 && !this.tuto) { this.killEnemy(); return; } }
      if (e.burnT <= 0) e.burn = 0;
    }
    if (e.state === 'idle' && e.a.cur && !e.a.cur.isRunning() && e.a.cur !== e.a.actions.Idle_Combat) play(e.a, 'Idle_Combat', { loop: true, fade: 0.2 });
    if (this.tuto) { this.updTuto(dt); if (e.state === 'attack') this.updLines(); if (e.state === 'open') this.updOpen(); return; }
    switch (e.state) {
      case 'intro': if (e.stT > (e.def.id === 'boss' ? 1.6 : 1.4)) { e.state = 'idle'; e.stT = 0; e.idleDur = 0.5; play(e.a, 'Idle_Combat', { loop: true, fade: 0.25 }); this.emit('fightGo'); } break;
      case 'idle': if (e.stT >= e.idleDur) this.startAttack(wpick(this.r, e.p2 ? e.def.p2.atk : e.def.atk)); break;
      case 'attack': this.updLines(); break;
      case 'stagger': if (e.stT >= e.stagDur) { const rip = e.riposte; e.riposte = false; this.openFromDef(rip || e.stagDur > 0.8); } break;
      case 'open': this.updOpen(); break;
      case 'roar': if (e.stT > 1.7) { e.state = 'idle'; e.stT = 0; e.idleDur = 0.3; play(e.a, 'Idle_Combat', { loop: true, fade: 0.2 }); } break;
      case 'dying': if (e.stT > 2.2) this.nextFight(); break;
    }
  }
  updOpen() {
    const W = this.win; if (!W) return;
    this.updWindowPos();
    if (!W.infinite && !W.resolved && this.T > W.close + 0.3) {
      if (this.g && this.g.mode === 'trace') { const g = this.g; this.g = null; this.chronoActive = false; this.emit('traceEnd'); this.release(g); return; }
      this.comboBreak(); this.emit('text', { t: 'FENÊTRE MANQUÉE', cls: 'bad' }); this.closeWindow('miss');
      if (this.tuto) this.tutoEvent('miss');
    }
  }
  phase2() {
    const e = this.e; e.p2 = true; this.win && this.closeWindow('phase'); this.lines = [];
    e.state = 'roar'; e.stT = 0; play(e.a, 'Taunt_Longer', { ts: 1.6, fade: 0.1 });
    this.addSlow(0.6, 0.35);
    this.emit('phase2');
  }
  killEnemy() {
    const e = this.e; e.state = 'dying'; e.stT = 0; this.lines = []; if (this.win) this.closeWindow('kill');
    play(e.a, 'Death_C_Skeletons', { fade: 0.05 });
    this.addSlow(0.7, 0.2); this.addHitstop(150);
    this.stats.fightsWon++;
    this.addScore(500 + Math.max(0, e.def.par - this.fightT) * 20);
    this.emit('enemyDie', { def: e.def, x: e.anchor.x, y: e.anchor.y });
  }
  nextFight() {
    if (this.fi + 1 >= this.fights.length) { this.finish(true); return; }
    this.state = 'interlude'; this.stT = 0; this.e.a.root.visible = false;
    const H = this.hero; H.hp = Math.min(H.max, H.hp + 35); H.st = H.stMax;
    this.emit('interlude', { next: ENEMIES[this.fights[this.fi + 1]] });
  }
  heroDie() {
    const H = this.hero; H.dead = true; this.g = null; this.endGuard();
    play(this.W.hero, 'Death_A', { fade: 0.05 }); this.addSlow(1.0, 0.25);
    this.state = 'dying'; this.stT = 0; this.emit('heroDie');
  }
  finish(win) {
    this.state = 'over';
    const s = this.stats;
    const prec = s.ruptures ? Math.min(1, s.qSum / s.ruptures) : 0;
    const avoid = s.dmgPot ? Math.max(0, 1 - s.dmgTaken / s.dmgPot) : (s.atkTot ? 0 : 1);
    const par = this.fights.reduce((t, f) => t + ENEMIES[f].par, 0);
    const bonus = { prec: Math.round(prec * 3000), combo: s.maxCombo * 40, time: win ? Math.round(Math.max(0, par - s.time) * 25) : 0, avoid: Math.round(avoid * 3000), win: win ? 2000 : 0 };
    const total = this.score + bonus.prec + bonus.combo + bonus.time + bonus.avoid + bonus.win;
    const rank = total >= 26000 ? 'SS' : total >= 20000 ? 'S' : total >= 14500 ? 'A' : total >= 9500 ? 'B' : total >= 5500 ? 'C' : 'D';
    this.over = { win, prec, avoid, time: s.time, maxCombo: s.maxCombo, bonus, base: this.score, total, rank, stats: { ...s }, lame: this.lameId };
    this.rec.endTick = this.tick; this.rec.score = total; this.rec.rank = rank;
    this.emit(win ? 'victory' : 'defeat', this.over);
  }

  // ---------- Héros ----------
  updHero(dt) {
    const H = this.hero, a = this.W.hero;
    // endurance
    H.stT += dt;
    if (H.st < H.stMax && H.stT > (H.st < 1 ? 1.25 : 0.45) && !(this.g && this.g.mode === 'trace')) { H.st = Math.min(H.stMax, H.st + dt / 0.9); if (Math.floor(H.st) !== Math.floor(H.st - dt / 0.9)) this.emit('stamina'); }
    // garde + charge de Résonance
    if (H.guard) {
      H.guardT += dt; if (!H.armed && H.res < 100) this.gainRes(12 * dt);
      if (H.res >= 100 && !H.armed) { H.holdArm += dt; if (H.holdArm > 0.55) { H.armed = true; H.res = 0; H.holdArm = 0; this.emit('resArmed'); } }
    }
    // retour à l'idle
    if (!H.dead && !H.guard && this.T > H.busy && a.cur && !a.cur.isRunning() && a.cur !== a.actions['2H_Melee_Idle']) play(a, '2H_Melee_Idle', { loop: true, fade: 0.18 });
    // déplacement : fente pendant la lame, esquive latérale
    const p = a.root.position;
    let tx = HERO_POS.x, tz = HERO_POS.z;
    if (this.blade && this.blade.t < this.blade.dur + 0.1) { tx = HERO_LUNGE.x; tz = HERO_LUNGE.z; }
    if (H.dodgeT >= 0) { H.dodgeT += dt; const k = H.dodgeT < 0.16 ? H.dodgeT / 0.16 : Math.max(0, 1 - (H.dodgeT - 0.16) / 0.3); tx += H.dodgeDir * 0.9 * k; tz += 0.25 * k; if (H.dodgeT > 0.46) H.dodgeT = -1; }
    const sp = (this.blade && this.blade.t < this.blade.dur) ? 18 : 9;
    p.x += (tx - p.x) * Math.min(1, dt * sp); p.z += (tz - p.z) * Math.min(1, dt * sp);
  }

  // ---------- Tutoriel (première minute) ----------
  startTuto() {
    this.tuto = { step: 0, t: 0, ok: 0, wait: 0.8, slowWin: false };
    this.startFight(0);
    this.e.state = 'intro';
  }
  tutoSay(t, sub) { this.emit('tuto', { t, sub, step: this.tuto.step }); }
  updTuto(dt) {
    const T = this.tuto, e = this.e; T.t += dt;
    if (e.state === 'intro' && e.stT > 1.4) { e.state = 'idle'; e.stT = 0; e.idleDur = 99; play(e.a, 'Idle_Combat', { loop: true, fade: 0.25 }); }
    if (e.state === 'intro') return;
    if (T.wait > 0) { T.wait -= dt; if (T.wait <= 0) this.tutoBegin(); }
  }
  tutoBegin() {
    const T = this.tuto;
    switch (T.step) {
      case 0: this.tutoSay('TRACE', 'Relie les failles 1 → 2 d\'un seul geste, puis relâche.'); this.openWindow({ n: 2, D: 99, infinite: true }); break;
      case 1: this.tutoSay('TIMING', 'Relâche quand l\'anneau se referme sur la dernière faille.'); this.openWindow({ n: 3, D: 2.2 }); break;
      case 2: T.slowWin = true; this.tutoSay('PARADE', 'Trace À TRAVERS la ligne rouge quand elle s\'illumine.'); this.startAttack('m_slash', { teleMul: 1.7 }); break;
      case 3: T.slowWin = false; this.tutoSay('ESQUIVE', 'Violet = imparable. TAPOTE l\'écran pour esquiver.'); this.startAttack('b_spin', { teleMul: 1.6 }); break;
      case 4: this.tutoSay('GARDE', 'MAINTIENS le doigt appuyé pour encaisser (et charger la Résonance).'); this.startAttack('m_chop', { teleMul: 1.8 }); break;
      case 5: this.tutoSay('À TOI !', 'Brise le Grunt. Ton score de style démarre.'); this.endTuto(); break;
    }
  }
  tutoEvent(kind) {
    const T = this.tuto; if (!T) return;
    const adv = () => { T.step++; T.wait = 1.0; this.emit('tutoOk', { step: T.step }); };
    if (T.step === 0 && kind === 'rupture') { if (this._lastRes && this._lastRes.orderOK) adv(); else { T.wait = 0.8; this.emit('tutoRetry', { t: 'Dans l\'ordre : 1 puis 2.' }); } }
    else if (T.step === 1 && (kind === 'rupture' || kind === 'miss')) {
      T.tries = (T.tries || 0) + 1;
      if (kind === 'rupture' && this._lastRes && (this._lastRes.timing === 'perfect' || this._lastRes.timing === 'good')) adv();
      else if (T.tries >= 3 && kind === 'rupture') { adv(); this.emit('tutoRetry', { t: 'Ça viendra : vise le flash doré de l\'anneau.' }); }
      else { T.wait = 0.8; const lr = this._lastRes; this.emit('tutoRetry', { t: kind === 'miss' ? 'Trop lent ! Relâche quand l\'anneau touche la faille.' : lr && lr.timing === 'early' ? 'Trop tôt : attends que l\'anneau se referme.' : 'Trop tard : relâche un poil avant.' }); }
    }
    else if (T.step === 2 && kind === 'parry') { T.parried = true; }
    else if (T.step === 2 && kind === 'atkEnd') { if (T.parried) adv(); else { T.wait = 0.6; this.emit('tutoRetry', { t: 'Trace en travers de la ligne quand elle flashe.' }); } T.parried = false; }
    else if (T.step === 3 && kind === 'dodge') T.dodged = true;
    else if (T.step === 3 && kind === 'atkEnd') { if (T.dodged) adv(); else { T.wait = 0.6; this.emit('tutoRetry', { t: 'Un simple tap, juste avant l\'impact.' }); } T.dodged = false; }
    else if (T.step === 4 && kind === 'guard') T.guarded = true;
    else if (T.step === 4 && kind === 'atkEnd') { if (T.guarded) adv(); else { T.wait = 0.6; this.emit('tutoRetry', { t: 'Garde le doigt posé sans bouger.' }); } T.guarded = false; }
  }
  endTuto() {
    // On repart d'un état propre au pas suivant : le vrai combat (enregistré pour le replay) commence là.
    this.tuto = null; this.emit('tutoEnd'); this._resetNext = true;
  }
  resetForRun() {
    this.r = rng(this.seed); this.tick = 0; this.T = 0; this.recording = !this.replay; this.rec.events = []; this.state = 'start';
    const H = this.hero; Object.assign(H, { hp: 100, st: 3, stT: 0, res: 0, armed: false, ifr: -1, guard: false, busy: -1, stag: -1, dodgeT: -1, dead: false });
    this.combo = 0; this.score = 0; Object.keys(this.stats).forEach(k => this.stats[k] = 0);
    this.win = null; this.lines = []; this.blade = null; this.blades = []; this.g = null; this.pendingRelease = null;
    this.hitstop = 0; this.slow = 0; this.chronoActive = false; this.chronoFreeze = 0; this.chronoStop = false;
  }
  // Remet les acteurs dans un état identique (indispensable au déterminisme du replay)
  resetActors() {
    const all = [this.W.hero, ...Object.values(this.W.enemies)];
    all.forEach(a => { a.mixer.stopAllAction(); a.mixer.time = 0; a.cur = null; a.root.position.set(0, 0, 0); a.U.flash.value.setRGB(0, 0, 0); });
    const h = this.W.hero; h.root.position.copy(HERO_POS); h.root.rotation.y = Math.atan2(-HERO_POS.x, -HERO_POS.z);
    play(h, '2H_Melee_Idle', { loop: true, fade: 0 });
  }
  begin() {
    this.resetActors();
    if (this.tutoOn && !this._tutoDone) { this._tutoDone = true; this.startTuto(); }
    else this.startFight(0);
  }

  // ---------- Mise à jour d'un pas ----------
  update() {
    if (this._resetNext) { this._resetNext = false; this.resetForRun(); }
    // pas réel
    if (this.hitstop > 0) this.hitstop--;
    if (this.slow > 0) { this.slow--; if (this.slow === 0) this.slowF = 1; }
    const ts = this.timeScale(); this.ts = ts;
    const dt = TICK * ts;
    // geste "maintenir" (en temps réel)
    if (this.g && this.g.mode === 'pend' && this.tick - this.g.t0 >= 13 && this.g.maxD < 0.028) { this.g.mode = 'hold'; this.g.hx = this.g.pts[this.g.pts.length - 1].x; this.g.hy = this.g.pts[this.g.pts.length - 1].y; this.startGuard(); }
    if (this.state === 'start') { this.begin(); }
    if (this.state === 'interlude') { this.stT += TICK; if (this.stT > 2.4) this.startFight(this.fi + 1); }
    if (this.state === 'dying') { this.stT += TICK; if (this.stT > 2.0) this.finish(false); }
    if (this.state === 'fight' && !this.tuto && this.e && this.e.state !== 'dying') { this.stats.time += dt; this.fightT = (this.fightT || 0) + dt; }
    this.T += dt;
    // animations (temps de jeu)
    this.W.hero.mixer.update(dt);
    if (this.e) {
      const freeze = this.chronoFreeze > 0;
      this.e.a.mixer.update(freeze ? 0 : dt);
    }
    this.W.applyFraming(TICK);
    this.W.hero.root.updateMatrixWorld(true); if (this.e) this.e.a.root.updateMatrixWorld(true);
    if (this.state === 'fight' || this.state === 'dying') {
      this.updHero(dt);
      if (this.chronoFreeze > 0) { this.chronoFreeze -= TICK; if (this.win) this.updWindowPos(); if (this.chronoFreeze <= 0 && this.win && this.win.chronoFree && !this.win.resolved) this.closeWindow('miss'); }
      else this.updEnemy(dt);
      this.updBlade(dt);
      if (this.chronoStop) { this.chronoStop = false; this.chronoFreeze = 2.2; this.emit('timeStop'); this.openFromDefFree(); }
    }
    // enchaînement Rupture → tutoriel
    if (this._pendingTuto) { const k = this._pendingTuto; this._pendingTuto = null; this.tutoEvent(k); }
  }
  openFromDefFree() { const e = this.e; if (!e || e.state === 'dying') return; const d = e.p2 ? e.def.p2 : e.def; this.openWindow({ n: d.failles, D: 2.2, curveP: d.curveP ?? e.def.curveP, chronoFree: true }); this.win.infinite = true; }
}

