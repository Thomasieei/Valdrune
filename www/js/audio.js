// FRACTURE — audio 100 % procédural (Web Audio). Aucun fichier, aucune licence tierce.
// SFX synthétisés + deux thèmes : combat (140 BPM, synthwave/électro) et hub (92 BPM, calme).

let ctx = null, master, sfxBus, musBus, musFilter, comp, noiseBuf, verb;
const S = { music: true, sfx: true, musVol: 0.55, sfxVol: 0.9 };

export function audioSettings(o) {
  Object.assign(S, o);
  if (!ctx) return;
  musBus.gain.setTargetAtTime(S.music ? S.musVol : 0, ctx.currentTime, 0.05);
  sfxBus.gain.setTargetAtTime(S.sfx ? S.sfxVol : 0, ctx.currentTime, 0.05);
}

export function unlockAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
  try { ctx = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: 'interactive' }); } catch (e) { return; }
  comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -14; comp.knee.value = 8; comp.ratio.value = 4; comp.attack.value = 0.003; comp.release.value = 0.15;
  master = ctx.createGain(); master.gain.value = 0.9;
  comp.connect(master); master.connect(ctx.destination);
  sfxBus = ctx.createGain(); sfxBus.gain.value = S.sfx ? S.sfxVol : 0; sfxBus.connect(comp);
  musFilter = ctx.createBiquadFilter(); musFilter.type = 'lowpass'; musFilter.frequency.value = 18000; musFilter.Q.value = 0.7;
  musBus = ctx.createGain(); musBus.gain.value = S.music ? S.musVol : 0;
  musBus.connect(musFilter); musFilter.connect(comp);
  // bruit blanc partagé
  noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 1.5, ctx.sampleRate);
  const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  // réverb courte synthétique (impulsion décroissante)
  verb = ctx.createConvolver();
  const ir = ctx.createBuffer(2, ctx.sampleRate * 1.6, ctx.sampleRate);
  for (let c = 0; c < 2; c++) { const x = ir.getChannelData(c); for (let i = 0; i < x.length; i++) x[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / x.length, 3.2); }
  verb.buffer = ir;
  const vg = ctx.createGain(); vg.gain.value = 0.22; verb.connect(vg); vg.connect(comp);
}

const now = () => ctx.currentTime;
function env(g, t, a, peak, dec, sus = 0.0001) {
  g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(Math.max(peak, 0.0002), t + a);
  g.gain.exponentialRampToValueAtTime(Math.max(sus, 0.0001), t + a + dec);
}
function noise(t, dur, { type = 'bandpass', f0 = 1200, f1 = f0, q = 1, vol = 0.5, a = 0.004, out = sfxBus, send = 0 } = {}) {
  const s = ctx.createBufferSource(); s.buffer = noiseBuf;
  const f = ctx.createBiquadFilter(); f.type = type; f.Q.value = q;
  f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(Math.max(f1, 30), t + dur);
  const g = ctx.createGain(); env(g, t, a, vol, dur);
  s.connect(f); f.connect(g); g.connect(out); if (send) { const sg = ctx.createGain(); sg.gain.value = send; g.connect(sg); sg.connect(verb); }
  s.start(t, Math.random() * 0.5); s.stop(t + dur + a + 0.05);
}
function tone(t, dur, { type = 'sine', f0 = 440, f1 = f0, vol = 0.3, a = 0.003, out = sfxBus, send = 0, detune = 0 } = {}) {
  const o = ctx.createOscillator(); o.type = type; o.detune.value = detune;
  o.frequency.setValueAtTime(f0, t); if (f1 !== f0) o.frequency.exponentialRampToValueAtTime(Math.max(f1, 20), t + dur);
  const g = ctx.createGain(); env(g, t, a, vol, dur);
  o.connect(g); g.connect(out); if (send) { const sg = ctx.createGain(); sg.gain.value = send; g.connect(sg); sg.connect(verb); }
  o.start(t); o.stop(t + dur + a + 0.05);
}

// ---------- SFX ----------
const SFX = {
  ui() { const t = now(); tone(t, 0.06, { type: 'square', f0: 1400, f1: 900, vol: 0.08 }); },
  uiOk() { const t = now(); tone(t, 0.08, { type: 'triangle', f0: 880, vol: 0.14 }); tone(t + 0.06, 0.12, { type: 'triangle', f0: 1320, vol: 0.12 }); },
  traceStart() { const t = now(); tone(t, 0.05, { type: 'sine', f0: 900, f1: 1500, vol: 0.06 }); },
  node(i = 0) { const t = now(); const f = 660 * Math.pow(1.122, i * 2); tone(t, 0.12, { type: 'triangle', f0: f, vol: 0.13, send: 0.3 }); tone(t, 0.05, { type: 'square', f0: f * 2, vol: 0.03 }); },
  nodeBad() { const t = now(); tone(t, 0.12, { type: 'sawtooth', f0: 220, f1: 150, vol: 0.08 }); },
  whoosh(len = 1) { const t = now(); noise(t, 0.16 + 0.1 * len, { type: 'bandpass', f0: 600, f1: 4200, q: 1.4, vol: 0.32, a: 0.02 }); },
  hit(power = 1) {
    const t = now();
    noise(t, 0.09, { type: 'highpass', f0: 2600, f1: 1800, vol: 0.35 * power });
    tone(t, 0.14, { type: 'sine', f0: 170, f1: 48, vol: 0.55 * power });
    noise(t + 0.005, 0.18, { type: 'lowpass', f0: 1800, f1: 200, vol: 0.4 * power });
    tone(t, 0.05, { type: 'square', f0: 1900, f1: 600, vol: 0.06 * power });
  },
  perfect() {
    const t = now();
    noise(t, 0.5, { type: 'bandpass', f0: 7000, f1: 300, q: 0.8, vol: 0.4, send: 0.6 });
    tone(t, 0.32, { type: 'sine', f0: 110, f1: 32, vol: 0.8 });
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => tone(t + 0.02 + i * 0.03, 0.9, { type: 'triangle', f0: f, vol: 0.09, send: 0.8 }));
    tone(t, 1.2, { type: 'sine', f0: 2093, vol: 0.05, send: 1 });
  },
  parry(perfect) {
    const t = now();
    [1, 2.76, 5.4, 8.93].forEach((m, i) => tone(t, perfect ? 0.9 : 0.45, { type: i ? 'sine' : 'triangle', f0: 620 * m, vol: (perfect ? 0.16 : 0.11) / (i + 1), send: 0.6 }));
    noise(t, 0.06, { type: 'highpass', f0: 5000, vol: 0.45 });
    tone(t, 0.1, { type: 'sine', f0: 240, f1: 80, vol: 0.4 });
    if (perfect) { tone(t + 0.05, 0.6, { type: 'sine', f0: 1567.98, vol: 0.09, send: 1 }); noise(t, 0.7, { type: 'bandpass', f0: 300, f1: 6000, vol: 0.18, a: 0.3 }); }
  },
  dodge(perfect) { const t = now(); noise(t, 0.22, { type: 'bandpass', f0: 3000, f1: 500, q: 2, vol: 0.28 }); if (perfect) tone(t, 0.5, { type: 'sine', f0: 1200, f1: 2400, vol: 0.08, send: 0.8 }); },
  guard() { const t = now(); tone(t, 0.2, { type: 'square', f0: 140, f1: 90, vol: 0.18 }); noise(t, 0.12, { type: 'lowpass', f0: 2500, f1: 400, vol: 0.4 }); tone(t, 0.25, { type: 'triangle', f0: 880, vol: 0.05 }); },
  guardBreak() { const t = now(); noise(t, 0.35, { type: 'lowpass', f0: 4000, f1: 120, vol: 0.6 }); tone(t, 0.4, { type: 'sawtooth', f0: 200, f1: 40, vol: 0.3 }); },
  hurt() { const t = now(); tone(t, 0.25, { type: 'sawtooth', f0: 260, f1: 60, vol: 0.28 }); noise(t, 0.2, { type: 'lowpass', f0: 1200, f1: 150, vol: 0.5 }); tone(t, 0.2, { type: 'sine', f0: 90, f1: 40, vol: 0.6 }); },
  telegraph(kind = 'red') {
    const t = now();
    if (kind === 'purple') { tone(t, 0.5, { type: 'sawtooth', f0: 90, f1: 260, vol: 0.12 }); tone(t, 0.5, { type: 'square', f0: 93, f1: 266, vol: 0.06 }); }
    else { tone(t, 0.22, { type: 'sawtooth', f0: 380, f1: 760, vol: 0.07 }); tone(t + 0.02, 0.18, { type: 'square', f0: 1520, vol: 0.03 }); }
  },
  open() { const t = now(); [880, 1174.66].forEach((f, i) => tone(t + i * 0.05, 0.25, { type: 'triangle', f0: f, vol: 0.08, send: 0.5 })); noise(t, 0.2, { type: 'highpass', f0: 6000, vol: 0.08 }); },
  close() { const t = now(); tone(t, 0.18, { type: 'triangle', f0: 600, f1: 300, vol: 0.07 }); },
  resonanceReady() { const t = now(); [440, 554.37, 659.25, 880].forEach((f, i) => tone(t + i * 0.06, 0.5, { type: 'sawtooth', f0: f, vol: 0.05, send: 0.6 })); },
  resonanceCharge() { const t = now(); tone(t, 0.6, { type: 'sawtooth', f0: 110, f1: 880, vol: 0.12, send: 0.4 }); tone(t, 0.6, { type: 'sine', f0: 220, f1: 1760, vol: 0.08 }); },
  burn() { const t = now(); noise(t, 0.3, { type: 'bandpass', f0: 900, f1: 300, q: 0.6, vol: 0.25 }); },
  chain() { const t = now(); for (let i = 0; i < 3; i++) tone(t + i * 0.035, 0.07, { type: 'square', f0: 1800 + i * 300, vol: 0.05 }); },
  mirror() { const t = now(); tone(t, 0.3, { type: 'sine', f0: 1300, f1: 2600, vol: 0.06, send: 0.8 }); tone(t, 0.3, { type: 'sine', f0: 1310, f1: 2620, vol: 0.06, send: 0.8 }); },
  chronoIn() { const t = now(); tone(t, 0.4, { type: 'sine', f0: 900, f1: 220, vol: 0.12, send: 0.5 }); },
  chronoOut() { const t = now(); tone(t, 0.25, { type: 'sine', f0: 220, f1: 900, vol: 0.08 }); },
  shatter() { const t = now(); for (let i = 0; i < 6; i++) tone(t + i * 0.02, 0.4, { type: 'triangle', f0: 2000 + Math.random() * 3000, vol: 0.05, send: 0.7 }); noise(t, 0.6, { type: 'highpass', f0: 3000, f1: 8000, vol: 0.3 }); tone(t, 0.6, { type: 'sine', f0: 80, f1: 30, vol: 0.7 }); },
  enemyDie() { const t = now(); noise(t, 0.9, { type: 'lowpass', f0: 3000, f1: 80, vol: 0.5, send: 0.4 }); for (let i = 0; i < 8; i++) tone(t + i * 0.04, 0.12, { type: 'square', f0: 300 + Math.random() * 900, vol: 0.04 }); },
  roar() { const t = now(); tone(t, 1.2, { type: 'sawtooth', f0: 70, f1: 45, vol: 0.3, send: 0.6 }); tone(t, 1.2, { type: 'sawtooth', f0: 72, f1: 47, vol: 0.25 }); noise(t, 1.2, { type: 'lowpass', f0: 600, f1: 200, vol: 0.4, a: 0.2 }); },
  win() { const t = now(); [523.25, 659.25, 783.99, 1046.5, 1318.5].forEach((f, i) => tone(t + i * 0.09, 0.8, { type: 'triangle', f0: f, vol: 0.12, send: 0.7 })); },
  lose() { const t = now(); [392, 349.23, 311.13, 261.63].forEach((f, i) => tone(t + i * 0.18, 0.7, { type: 'sawtooth', f0: f, vol: 0.07, send: 0.5 })); },
  tick() { const t = now(); tone(t, 0.04, { type: 'square', f0: 2400, vol: 0.04 }); },
  rank() { const t = now(); tone(t, 0.6, { type: 'sine', f0: 60, f1: 40, vol: 0.8 }); noise(t, 0.4, { type: 'lowpass', f0: 5000, f1: 300, vol: 0.4, send: 0.5 }); [1046.5, 1567.98].forEach((f, i) => tone(t + 0.05 * i, 1.1, { type: 'triangle', f0: f, vol: 0.08, send: 1 })); },
};
export function sfx(name, ...a) { if (!ctx || !S.sfx) return; try { SFX[name] && SFX[name](...a); } catch (e) { } }

// ---------- Musique ----------
// Patterns en 16e. Accords en demi-tons relatifs à la tonique.
const THEMES = {
  combat: {
    bpm: 140, root: 45, // La2
    prog: [[0, 3, 7], [-4, 0, 3], [-9, -5, -2], [-2, 2, 5]], // Am  F  C  G (relatifs)
    kick: 'x...x...x...x..x', snare: '....x.......x...', hat: '..x...x...x...x.', ohat: '.......x.......x',
    bass: [0, 0, 12, 0, 0, 12, 0, 7, 0, 0, 12, 0, 7, 0, 12, 10],
    arp: [0, 1, 2, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 2, 3], lead: true,
  },
  hub: {
    bpm: 92, root: 40, // Mi2
    prog: [[0, 3, 7, 10], [-4, 0, 3, 7], [5, 8, 12, 15], [-2, 2, 5, 9]],
    kick: 'x.........x.....', snare: '........x.......', hat: '....x.......x...', ohat: '................',
    bass: [0, -1, -1, -1, -1, -1, 7, -1, 0, -1, -1, -1, 12, -1, -1, -1],
    arp: [0, 2, 1, 3, 2, 1, 3, 0, 1, 2, 3, 2, 0, 3, 1, 2], lead: false,
  },
};
let mus = { theme: null, step: 0, bar: 0, next: 0, timer: 0, intensity: 1 };
const mtof = m => 440 * Math.pow(2, (m - 69) / 12);

function drum(t, kind, v = 1) {
  if (kind === 'kick') { tone(t, 0.32, { type: 'sine', f0: 150, f1: 42, vol: 0.85 * v, out: musBus }); noise(t, 0.02, { type: 'highpass', f0: 3000, vol: 0.12 * v, out: musBus }); }
  else if (kind === 'snare') { noise(t, 0.18, { type: 'bandpass', f0: 1900, f1: 1200, q: 0.7, vol: 0.38 * v, out: musBus, send: 0.35 }); tone(t, 0.08, { type: 'triangle', f0: 230, f1: 160, vol: 0.25 * v, out: musBus }); }
  else if (kind === 'hat') noise(t, 0.035, { type: 'highpass', f0: 8000, vol: 0.12 * v, out: musBus });
  else if (kind === 'ohat') noise(t, 0.16, { type: 'highpass', f0: 7000, vol: 0.1 * v, out: musBus });
}
function synth(t, dur, midi, { type = 'sawtooth', vol = 0.1, cut = 2000, cut1 = 600, q = 4, send = 0, detune = 7 } = {}) {
  const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.Q.value = q;
  f.frequency.setValueAtTime(cut, t); f.frequency.exponentialRampToValueAtTime(cut1, t + dur);
  const g = ctx.createGain(); env(g, t, 0.006, vol, dur);
  [-detune, detune].forEach(dt => { const o = ctx.createOscillator(); o.type = type; o.frequency.value = mtof(midi); o.detune.value = dt; o.connect(f); o.start(t); o.stop(t + dur + 0.05); });
  f.connect(g); g.connect(musBus); if (send) { const sg = ctx.createGain(); sg.gain.value = send; g.connect(sg); sg.connect(verb); }
}
function pad(t, dur, chord, root) {
  chord.forEach(n => synth(t, dur, root + 24 + n, { type: 'sawtooth', vol: 0.028, cut: 900, cut1: 1400, q: 1, send: 0.5, detune: 12 }));
}
function schedule() {
  const th = THEMES[mus.theme]; if (!th) return;
  const spb = 60 / th.bpm / 4;
  while (mus.next < ctx.currentTime + 0.14) {
    const s = mus.step % 16, t = mus.next, chord = th.prog[mus.bar % th.prog.length], I = mus.intensity;
    if (th.kick[s] === 'x') drum(t, 'kick');
    if (th.snare[s] === 'x' && I > 0.3) drum(t, 'snare');
    if (th.hat[s] === 'x') drum(t, 'hat', 0.8);
    if (th.ohat[s] === 'x' && I > 0.6) drum(t, 'ohat');
    if (mus.theme === 'combat' && I > 0.8 && s % 2 === 1) drum(t, 'hat', 0.4);
    const b = th.bass[s]; if (b >= 0) synth(t, spb * 1.8, th.root + chord[0] + b - (b >= 12 ? 0 : 0), { type: 'sawtooth', vol: mus.theme === 'combat' ? 0.11 : 0.09, cut: mus.theme === 'combat' ? 1400 : 700, cut1: 160, q: 6, detune: 4 });
    if (s === 0) pad(t, spb * 16, chord, th.root);
    const ai = th.arp[s] % chord.length;
    if (I > 0.45 || mus.theme === 'hub') synth(t, spb * 0.9, th.root + 36 + chord[ai] + (s >= 8 && mus.theme === 'combat' ? 12 : 0), { type: mus.theme === 'combat' ? 'square' : 'triangle', vol: mus.theme === 'combat' ? 0.03 : 0.04, cut: 4200, cut1: 900, q: 2, send: 0.4, detune: 3 });
    if (th.lead && I > 0.85 && (s === 0 || s === 6 || s === 10)) synth(t, spb * (s === 0 ? 5 : 3), th.root + 48 + chord[(mus.bar + s) % chord.length], { type: 'sawtooth', vol: 0.035, cut: 5000, cut1: 2000, q: 1, send: 0.6, detune: 9 });
    mus.next += spb; mus.step++; if (mus.step % 16 === 0) mus.bar++;
  }
}
export function playMusic(theme) {
  if (!ctx) return;
  if (mus.theme === theme) return;
  mus.theme = theme; mus.step = 0; mus.bar = 0; mus.next = ctx.currentTime + 0.08;
  if (!mus.timer) mus.timer = setInterval(() => { try { schedule(); } catch (e) { } }, 25);
}
export function stopMusic() { mus.theme = null; }
export function musicIntensity(v) { mus.intensity = v; }
// Filtre "ralenti" : la musique s'étouffe pendant les ralentis et les pauses.
export function musicMuffle(amount) {
  if (!ctx) return;
  const f = amount > 0 ? 18000 * Math.pow(1 - amount, 2) + 380 : 18000;
  musFilter.frequency.setTargetAtTime(f, ctx.currentTime, 0.04);
}

// ---------- Haptique ----------
let hapt = true;
export function hapticsEnabled(v) { hapt = v; }
export function haptic(ms) {
  if (!hapt) return;
  try {
    if (window.AndroidHaptics && window.AndroidHaptics.vibrate) { window.AndroidHaptics.vibrate(Array.isArray(ms) ? JSON.stringify(ms) : String(ms)); return; }
    if (navigator.vibrate) navigator.vibrate(ms);
  } catch (e) { }
}
