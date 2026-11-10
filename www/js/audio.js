/* NOCTALIS — sons et musique procédurale */
import { S } from './core.js';
let ctx, master, musGain, bufs = {}, musTimer = null, musKind = '';
const NAMES = ['bell', 'boom', 'click', 'coins', 'ok', 'power', 'select', 'win', 'lose', 'ping', 'seal'];
export const SFX = {
  unlock() {
    if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain(); master.gain.value = 0.8; master.connect(ctx.destination);
    musGain = ctx.createGain(); musGain.gain.value = S.music ? 0.22 : 0; musGain.connect(master);
    for (const n of NAMES) fetch(`assets/s/${n}.ogg`).then(r => r.arrayBuffer()).then(b => ctx.decodeAudioData(b)).then(d => bufs[n] = d).catch(() => { });
    if (musKind) { const k = musKind; musKind = ''; SFX.music(k); }
  },
  play(n, v = 0.5) {
    if (!ctx || !S.sfx || !bufs[n]) return;
    const s = ctx.createBufferSource(); s.buffer = bufs[n]; const g = ctx.createGain(); g.gain.value = v; s.connect(g).connect(master); s.start();
  },
  hit() {
    if (!ctx || !S.sfx) return; const t = ctx.currentTime;
    const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sawtooth'; o.frequency.setValueAtTime(320 + Math.random() * 80, t); o.frequency.exponentialRampToValueAtTime(70, t + 0.09);
    g.gain.setValueAtTime(0.09, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.1); o.connect(g).connect(master); o.start(t); o.stop(t + 0.11);
  },
  setMusic(on) { S.music = on; if (musGain) musGain.gain.value = on ? 0.22 : 0; },
  music(kind) {
    if (kind === musKind) return; musKind = kind; if (!ctx) return;
    clearInterval(musTimer);
    const P = { hub: [[57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67], [52, 55, 59, 64]], zone0: [[57, 61, 64, 69], [54, 57, 61, 66], [50, 54, 57, 62], [52, 56, 59, 64]],
      zone1: [[50, 53, 57, 60], [46, 50, 53, 58], [48, 51, 55, 58], [45, 49, 52, 57]], zone2: [[52, 55, 59, 62], [48, 52, 55, 60], [50, 53, 57, 60], [47, 50, 54, 59]],
      dungeon: [[45, 48, 52, 55], [46, 49, 53, 56], [45, 48, 52, 55], [43, 47, 50, 55]] }[kind] || [[57, 60, 64]];
    const bpm = kind === 'dungeon' ? 132 : kind === 'hub' ? 84 : 108; const step = 60 / bpm / 2; let i = 0, nextT = ctx.currentTime + 0.1;
    const f = m => 440 * Math.pow(2, (m - 69) / 12);
    const note = (m, t, d, type, v) => { const o = ctx.createOscillator(), g = ctx.createGain(), fl = ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = 1600; o.type = type; o.frequency.value = f(m);
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + 0.02); g.gain.exponentialRampToValueAtTime(0.001, t + d); o.connect(fl).connect(g).connect(musGain); o.start(t); o.stop(t + d + 0.05); };
    musTimer = setInterval(() => {
      while (nextT < ctx.currentTime + 0.3) {
        const ch = P[Math.floor(i / 16) % P.length]; const k = i % 16;
        if (k === 0) { note(ch[0] - 24, nextT, step * 15, 'triangle', 0.5); for (const m of ch) note(m - 12, nextT, step * 16, 'sine', 0.06); }
        const arp = [0, 1, 2, 3, 2, 1, 3, 2]; note(ch[arp[k % 8]] + (k >= 8 ? 12 : 0), nextT, step * 1.6, 'square', 0.035);
        if (kind !== 'hub' && k % 4 === 0) { const t = nextT, o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.setValueAtTime(140, t); o.frequency.exponentialRampToValueAtTime(40, t + 0.15); g.gain.setValueAtTime(0.35, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18); o.connect(g).connect(musGain); o.start(t); o.stop(t + 0.2); }
        nextT += step; i++;
      }
    }, 100);
  },
};
