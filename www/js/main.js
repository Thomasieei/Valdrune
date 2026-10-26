// FRACTURE : Lame Zéro — orchestration : boot, menus, boucle, présentation, replay, perfs.
import * as THREE from 'three';
import { R, initRenderer, buildEnv, loadModels, buildActor, attachWeapon, addBlob, setFraming, applyFraming, project, renderFrame, addShake, play, setPixelRatio, resize, outfitTexture } from './render.js';
import { WD, OUTFITS, ENEMY_INFO, initWorld, enterWorld, leaveWorld, updateWorld, killEnt, resetBoss, drawMinimap } from './world.js';
import { FX, initFX, resizeFX, Ribbon, Disc, Digit, burst, sparks, shock, flash, vignette, setVigTarget, setSlowFX, updateFX, setParticleScale } from './fx.js';
import { Sim, TICK, LAMES, ENEMIES, R_FAILLE, HERO_POS } from './sim.js';
import { unlockAudio, sfx, playMusic, musicIntensity, musicMuffle, audioSettings, haptic, hapticsEnabled } from './audio.js';

const $ = id => document.getElementById(id);
const store = {
  get(k, d) { try { const v = localStorage.getItem('fracture.' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem('fracture.' + k, JSON.stringify(v)); return true; } catch (e) { return false; } },
};
const settings = Object.assign({ music: true, sfx: true, haptics: true, perf: false, hq: true }, store.get('settings', {}));
let lameId = store.get('lame', 'braise'); if (!LAMES[lameId]) lameId = 'braise';
let tutoOn = store.get('tuto', true);
let best = store.get('best', null);

// ---------- Boot ----------
const canvas = $('gl');
initRenderer(canvas);
buildEnv();
initFX(R.A);
R.onResize = () => { resizeFX(R.logicCam.aspect); setParticleScale(R.H * R.dpr); };
R.onResize();
const W = { hero: null, enemies: {}, project, aspect: () => R.logicCam.aspect, setFraming, applyFraming };

let models;
const swords = {};
(async function boot() {
  try {
    models = await loadModels(p => { $('bootBar').style.width = (p * 100) + '%'; });
  } catch (e) { $('bootTxt').textContent = 'ERREUR DE CHARGEMENT : ' + e.message; return; }
  $('bootTxt').textContent = 'CALIBRAGE DES FAILLES…';
  // Tenues "normales" : on recolore l'atlas du Rogue KayKit (veste, chemise, jean, baskets)
  let baseTex = null; models.hero.scene.traverse(o => { if (!baseTex && o.isMesh && o.material.map) baseTex = o.material.map; });
  const outfitTex = {}; for (const k in OUTFITS) outfitTex[k] = outfitTexture(baseTex, OUTFITS[k]);
  models.weapons.scene.traverse(o => { if (o.isMesh && (o.name === '1H_Sword' || o.name === '2H_Sword')) swords[o.name === '1H_Sword' ? 's1' : 's2'] = { geometry: o.geometry, material: o.material }; });
  // Le monde clone les modèles intacts : à faire AVANT de construire les acteurs de l'arène
  initWorld({ models, ENEMIES, swords, outfitTex });
  const keep = new Set(['Rogue_ArmLeft', 'Rogue_ArmRight', 'Rogue_Body', 'Rogue_Head', 'Rogue_LegLeft', 'Rogue_LegRight']);
  W.hero = buildActor('hero', models.hero, { rim: 0x22f0ff, rimStr: 0.9, keep, outlineW: 0.02, scale: 1, map: outfitTex.hero });
  R.scene.add(W.hero.root); addBlob(W.hero, 1.6);
  W.hero.blade = attachWeapon(W.hero, swords.s1, 'handslot.r', { emissive: 0xff7a1a, scale: 0.85 });
  W.hero.blade.material.emissiveIntensity = 0.5;
  for (const id of ['minion', 'rogue', 'boss']) {
    const def = ENEMIES[id];
    const a = buildActor(id, models[id], { rim: def.rim, rimStr: 0.7, eyes: def.eyes, outlineW: 0.022, scale: def.scale, hide: /Helmet|Cloak|Hood|Cape/ });
    const src = def.weapon === '2H_Sword' ? swords.s2 : swords.s1;
    if (src) {
      attachWeapon(a, src, 'handslot.r', { scale: def.wScale, color: 0xb8a8d8, emissive: def.rim });
      if (def.dual) attachWeapon(a, src, 'handslot.l', { scale: def.wScale, color: 0xb8a8d8, emissive: def.rim });
    }
    a.root.visible = false; R.scene.add(a.root); addBlob(a, 1.6 * def.scale);
    W.enemies[id] = a;
  }
  applyLameLook();
  buildPresentation();
  await document.fonts.ready.catch(() => { });
  $('boot').hidden = true;
  showTitle();
  requestAnimationFrame(frame);
})();

// ---------- Lames : apparence ----------
function applyLameLook() {
  const L = LAMES[lameId], hex = '#' + L.col.toString(16).padStart(6, '0');
  document.documentElement.style.setProperty('--lame', hex);
  $('eqName').textContent = L.name; $('hLame').textContent = L.name; $('wLame').textContent = L.name;
  if (W.hero && W.hero.blade) W.hero.blade.material.emissive.set(L.col);
  if (pres.blades) pres.blades.forEach(b => b.r.color(L.col, L.core));
  if (pres.trace) pres.trace.color(L.col, 0xffffff);
}

// ---------- Présentation (pools d'objets FX) ----------
const pres = {};
function buildPresentation() {
  pres.failles = []; for (let i = 0; i < 4; i++) pres.failles.push({ d: new Disc(0, 0xffffff, 5), dg: new Digit(), ring: new Disc(1, 0xffffff, 5), ghost: new Disc(3, 0xb46bff, 4), pulse: 0, bad: 0 });
  pres.guides = []; for (let i = 0; i < 3; i++) pres.guides.push({ r: new Ribbon(40, { col: 0xffffff, core: 0xffffff, width: 0.006, glow: 0.6, dash: 14, order: 3 }), c: new Disc(0, 0xffd23f, 4) });
  pres.lines = []; for (let i = 0; i < 4; i++) pres.lines.push({ r: new Ribbon(24, { col: 0xff2040, core: 0xffd0d8, width: 0.02, glow: 1.2, order: 4, dark: 0.85 }), t: 0, fade: 0, state: '' });
  pres.trace = new Ribbon(256, { col: 0x22f0ff, core: 0xffffff, width: 0.009, glow: 0.9, order: 7, dark: 0.6 });
  pres.blades = []; for (let i = 0; i < 4; i++) pres.blades.push({ r: new Ribbon(256, { col: 0xff7a1a, core: 0xffffff, width: 0.02, glow: 1.3, order: 8 }), B: null, fade: 0 });
  pres.holdRing = new Disc(1, 0x22f0ff, 9); pres.holdCore = new Disc(2, 0xffd23f, 9);
  applyLameLook();
}

// ---------- État global ----------
let mode = 'boot'; // boot | title | world | play | replay | result | reward
let enc = null, backToWorld = false;
let sim = null, acc = 0, paused = false, replaySpeed = 1, lastRun = null, showcaseT = 0;
let pointerId = null;

// ---------- Entrées tactiles ----------
function toUnits(e) { return [e.clientX / R.H, e.clientY / R.H]; }
canvas.addEventListener('pointerdown', e => {
  unlockAudio(); if (settings.music) audioSettings(settings);
  if (mode === 'world' && !paused) { joyStart(e); return; }
  if (mode !== 'play' || paused || pointerId !== null) return;
  pointerId = e.pointerId; try { canvas.setPointerCapture(e.pointerId); } catch (err) { }
  const [x, y] = toUnits(e); sim.input('d', x, y);
});
canvas.addEventListener('pointermove', e => {
  if (mode === 'world') { joyMove(e); return; }
  if (mode !== 'play' || e.pointerId !== pointerId) return;
  const evs = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
  for (const c of (evs.length ? evs : [e])) { const [x, y] = toUnits(c); sim.input('m', x, y); }
});
const up = e => { if (mode === 'world' || joy.id === e.pointerId) { joyUp(e); if (mode === 'world') return; } if (e.pointerId !== pointerId) return; pointerId = null; if (mode !== 'play') return; const [x, y] = toUnits(e); sim.input('u', x, y); };
canvas.addEventListener('pointerup', up); canvas.addEventListener('pointercancel', up);
document.addEventListener('pointerdown', () => unlockAudio(), { once: true });

// ---------- Menus ----------
const SCREENS = ['title', 'lames', 'hud', 'pause', 'settings', 'result', 'whud', 'dialog', 'reward'];
function show(id) {
  const keep = id === 'pause' ? (mode === 'world' ? 'whud' : 'hud') : id === 'dialog' ? 'whud' : null;
  SCREENS.forEach(s => $(s).hidden = s !== id && s !== keep);
  $('bQuit').hidden = mode === 'world'; $('bToMenu').hidden = mode !== 'world';
}
function showTitle() {
  if (WD.active) { leaveWorld(W.hero); saveGame(); }
  mode = 'title'; sim = null; paused = false; enc = null; backToWorld = false; joyEnd();
  show('title'); $('tuto').hidden = true; $('rbar').hidden = true; $('finger').hidden = true;
  resize(); // aspect réel
  $('bestScore').textContent = best ? best.total.toLocaleString('fr-FR') : '—';
  $('bestRank').textContent = best ? best.rank : '—';
  $('bReplay').disabled = !store.get('replay', null); $('bReplay').style.opacity = $('bReplay').disabled ? 0.45 : 1;
  $('tutoState').textContent = tutoOn ? 'ACTIF' : 'DÉSACTIVÉ';
  $('saveInfo').textContent = save.lvl > 1 || save.xp > 0 ? 'NV ' + save.lvl : '';
  setupShowcase();
  playMusic('hub'); musicIntensity(1); musicMuffle(0);
  setVigTarget(0); setSlowFX(0);
}
function setupShowcase() {
  Object.values(W.enemies).forEach(a => a.root.visible = false);
  const b = W.enemies.boss; b.root.visible = true; b.mixer.stopAllAction(); b.cur = null; b.root.position.set(0.35, 0, -0.6); b.root.rotation.y = -0.75; play(b, 'Idle_Combat', { loop: true, fade: 0 });
  const h = W.hero; h.mixer.stopAllAction(); h.cur = null; h.root.position.set(-1.7, 0, 0.9); h.root.rotation.y = 1.9; play(h, '2H_Melee_Idle', { loop: true, fade: 0 });
  setFraming({ pos: [-1.0, 1.5, 9.6], look: [-0.7, 1.75, 0] }, 0);
  showcaseT = 0;
}
$('bPlay').onclick = () => { sfx('uiOk'); goWorld(); };
$('bArena').onclick = () => { sfx('uiOk'); enc = null; startRun(); };
$('bLames').onclick = () => { sfx('ui'); renderCards(); show('lames'); };
$('bLBack').onclick = () => { sfx('ui'); if (mode === 'world') { show('whud'); paused = false; } else show('title'); };
$('bReplay').onclick = () => { const r = store.get('replay', null); if (r) { sfx('uiOk'); startReplay(r); } };
$('bTuto').onclick = () => { tutoOn = !tutoOn; store.set('tuto', tutoOn); $('tutoState').textContent = tutoOn ? 'ACTIF' : 'DÉSACTIVÉ'; sfx('ui'); };
$('bSet').onclick = () => { sfx('ui'); syncToggles(); show('settings'); };
$('bSetBack').onclick = () => { sfx('ui'); show('title'); };
$('pauseBtn').onclick = () => { if (mode !== 'play') return; paused = true; sfx('ui'); syncToggles(); show('pause'); musicMuffle(0.85); };
$('bResume').onclick = () => { paused = false; sfx('ui'); show(mode === 'world' ? 'whud' : 'hud'); musicMuffle(0); };
$('bQuit').onclick = () => { sfx('ui'); paused = false; if (enc) { enc = null; save.hp = Math.max(1, Math.round(sim.hero.hp)); goWorld(true); } else showTitle(); };
$('bToMenu').onclick = () => { sfx('ui'); paused = false; showTitle(); };
$('bSkipTuto').onclick = e => { e.stopPropagation(); if (sim && sim.tuto) { tutoOn = false; store.set('tuto', false); sim.endTuto(); } };
$('rAgain').onclick = () => { sfx('uiOk'); startRun(); };
$('rMenu').onclick = () => { sfx('ui'); if (backToWorld) goWorld(true); else showTitle(); };
$('rReplay').onclick = () => { const r = lastRun || store.get('replay', null); if (r) { sfx('uiOk'); startReplay(r); } };
$('rbSpeed').onclick = () => { replaySpeed = replaySpeed === 1 ? 2 : replaySpeed === 2 ? 0.5 : 1; $('rbSpeed').textContent = replaySpeed === 0.5 ? '×½' : '×' + replaySpeed; };
$('rbQuit').onclick = () => { sfx('ui'); if (backToWorld) goWorld(true); else showTitle(); };
document.querySelectorAll('.tog').forEach(b => b.onclick = () => { const k = b.dataset.k; settings[k] = !settings[k]; store.set('settings', settings); syncToggles(); applySettings(); sfx('ui'); });
function syncToggles() { document.querySelectorAll('.tog').forEach(b => { const on = settings[b.dataset.k]; const t = b.querySelector('b'); t.textContent = on ? 'ON' : 'OFF'; t.className = on ? '' : 'off'; }); }
function applySettings() { audioSettings({ music: settings.music, sfx: settings.sfx }); hapticsEnabled(settings.haptics); $('perf').hidden = !settings.perf; }
applySettings();

function renderCards() {
  const el = $('cards'); el.innerHTML = '';
  Object.values(LAMES).forEach(L => {
    const c = document.createElement('button'); c.className = 'card' + (L.id === lameId ? ' on' : '');
    c.style.setProperty('--c', '#' + L.col.toString(16).padStart(6, '0'));
    c.innerHTML = `<i class="gem"></i><h3>${L.name}</h3><p>${L.pitch}</p><p class="tw">${L.twist}</p><p class="rs">${L.res}</p>`;
    c.onclick = () => { lameId = L.id; store.set('lame', lameId); applyLameLook(); sfx('uiOk'); renderCards(); };
    el.appendChild(c);
  });
}

// ---------- Lancement d'un run / d'un replay ----------
function newSim(opts) {
  resetPresentation();
  sim = new Sim(W, onEvent, opts);
  acc = 0; paused = false; hudCache = {};
  return sim;
}
function startRun() {
  resize(); if (WD.active) leaveWorld(W.hero);
  newSim({ seed: (Date.now() % 2147483000) | 0, lame: lameId, tuto: tutoOn });
  mode = 'play'; show('hud'); $('tuto').hidden = true; $('rbar').hidden = true;
  playMusic('combat'); musicIntensity(0.5);
}
function startReplay(rec) {
  if (WD.active) leaveWorld(W.hero);
  resize(rec.aspect); // même cadrage logique que lors de l'enregistrement
  const prevLame = lameId; lameId = rec.lame; applyLameLook();
  newSim({ seed: rec.seed, lame: rec.lame, replay: rec, fights: rec.fights });
  sim._restoreLame = prevLame;
  mode = 'replay'; replaySpeed = 1; $('rbSpeed').textContent = '×1';
  show('hud'); $('rbar').hidden = false; $('tuto').hidden = true; $('pauseBtn').hidden = true;
  playMusic('combat'); musicIntensity(0.5);
}
function endReplay() {
  if (sim && sim._restoreLame) { lameId = sim._restoreLame; applyLameLook(); }
  $('pauseBtn').hidden = false;
}
function resetPresentation() {
  if (!pres.failles) return;
  pres.failles.forEach(f => { f.d.hide(); f.dg.hide(); f.ring.hide(); f.ghost.hide(); });
  pres.guides.forEach(g => { g.r.hide(); g.c.hide(); });
  pres.lines.forEach(l => { l.r.hide(); l.L = null; });
  pres.trace.hide(); pres.blades.forEach(b => { b.r.hide(); b.B = null; });
  pres.holdRing.hide(); pres.holdCore.hide();
  $('pops').innerHTML = ''; $('banner').innerHTML = '';
}

// ---------- Événements de la simulation → son, image, vibration, texte ----------
const px = (x, y) => [x * R.H, y * R.H];
const popPool = []; let popI = 0;
function pop(text, x, y, cls) {
  let el = popPool[popI]; if (!el) { el = document.createElement('div'); $('pops').appendChild(el); popPool[popI] = el; }
  popI = (popI + 1) % 24;
  el.className = 'pop'; void el.offsetWidth; el.className = 'pop ' + cls; el.textContent = text;
  const [X, Y] = px(x, y); el.style.left = X + 'px'; el.style.top = Y + 'px';
}
function banner(t, sub = '', cls = '') {
  const b = $('banner'); b.innerHTML = `<div class="b ${cls}">${sub ? `<small>${sub}</small>` : ''}<strong>${t}</strong></div>`;
}
const lameCol = () => LAMES[lameId].col;
function onEvent(k, d = {}) {
  const live = mode === 'play' || mode === 'replay';
  if (!live) return;
  switch (k) {
    case 'traceStart': sfx('traceStart'); break;
    case 'touch': sfx(d.ok ? 'node' : 'nodeBad', d.n - 1); haptic(d.ok ? 8 : 25); { const f = pres.failles[d.i]; if (f) { if (d.ok) f.pulse = 1; else f.bad = 1; } } burst(d.x, d.y, d.ok ? 8 : 4, { col: d.ok ? lameCol() : 0xff2040, speed: 0.35, size: 0.016, life: 0.35 }); break;
    case 'curveOk': sfx('node', 4); burst(d.x, d.y, 10, { col: 0xffd23f, speed: 0.3, size: 0.014 }); break;
    case 'chainRe': sfx('chain'); pop('+LIEN', d.x, d.y - 0.05, 'txt cyan'); break;
    case 'blade': sfx('whoosh', d.len); break;
    case 'rupture': onRupture(d); break;
    case 'hit': onHit(d); break;
    case 'echo': sfx('chain'); pop('ÉCHO', sim.e.anchor.x, sim.e.anchor.y - 0.2, 'txt cyan'); break;
    case 'parry': {
      sfx('parry', d.perfect); haptic(d.perfect ? [0, 30, 40, 50] : 30);
      sparks(d.x, d.y, d.perfect ? 40 : 22, { col: d.perfect ? 0xffffff : 0xffd0a0, speed: d.perfect ? 2.2 : 1.4, len: 0.07 });
      burst(d.x, d.y, 14, { col: 0x22f0ff, speed: 0.6, size: 0.02 });
      shock(d.x, d.y, d.perfect ? 0.5 : 0.28, d.perfect ? 0xffffff : 0x22f0ff);
      flash(d.perfect ? 0.55 : 0.2, d.perfect ? 0xbff8ff : 0xffffff); addShake(d.perfect ? 0.08 : 0.04);
      if (d.perfect) { banner('PARADE PARFAITE', '+1 ENDURANCE · +RÉSONANCE', 'parr short'); R.env.floor.material.uniforms.uPulse.value = 0.001; }
      else pop('PARADE', d.x, d.y - 0.06, 'txt cyan');
      break;
    }
    case 'dodgeStart': sfx('dodge', false); haptic(12); break;
    case 'dodge': if (d.perfect) { sfx('dodge', true); banner('ESQUIVE PARFAITE', '', 'parr short'); haptic(20); } else pop('ESQUIVE', HERO_SCR().x, HERO_SCR().y - 0.25, 'txt vio'); break;
    case 'guard': if (d.broken) { sfx('guardBreak'); haptic([0, 60, 30, 60]); pop('GARDE BRISÉE', HERO_SCR().x, HERO_SCR().y - 0.3, 'txt bad'); addShake(0.12); } else { sfx('guard'); haptic(35); pop('GARDE', HERO_SCR().x, HERO_SCR().y - 0.3, 'txt cyan'); addShake(0.03); } break;
    case 'guardOn': break;
    case 'hurt': if (!d.guarded) { sfx('hurt'); haptic(70); vignette(0.75); addShake(0.14); flash(0.15, 0xff2040); if (d.dmg) pop('-' + d.dmg, HERO_SCR().x + 0.05, HERO_SCR().y - 0.35, 'dmg'); } break;
    case 'tele': sfx('telegraph', d.line.kind === 'purple' ? 'purple' : 'red'); if (d.line.kind === 'purple') pop('ESQUIVE !', (d.line.A.x + d.line.B.x) / 2, d.line.A.y - 0.07, 'txt vio'); break;
    case 'feint': pop('FEINTE', (d.line.A.x + d.line.B.x) / 2, (d.line.A.y + d.line.B.y) / 2, 'txt warn'); break;
    case 'open': sfx('open'); if (d.riposte) pop('RIPOSTE ×1.3', sim.e.anchor.x, sim.e.anchor.y - sim.e.H * 0.62, 'txt gold'); break;
    case 'close': if (d.reason === 'miss') sfx('close'); break;
    case 'whiff': break;
    case 'stamina': break;
    case 'resReady': sfx('resonanceReady'); haptic(20); pop('RÉSONANCE PRÊTE — MAINTIENS', HERO_SCR().x + 0.25, 0.2, 'txt gold'); break;
    case 'resArmed': sfx('resonanceCharge'); haptic([0, 40, 30, 40]); banner('RÉSONANCE', 'PROCHAINE RUPTURE ×1.8', 'perf short'); flash(0.3, 0xffd23f); break;
    case 'resUsed': break;
    case 'burnTick': sfx('burn'); pop(String(d.dmg), d.x + (Math.random() - 0.5) * 0.1, d.y - 0.05, 'dmg burn'); burst(d.x, d.y, 6, { col: 0xff7a1a, speed: 0.25, size: 0.02, grav: -0.4 }); break;
    case 'combo': break;
    case 'comboBreak': if (d.n >= 5) pop('COMBO ×' + d.n + ' PERDU', 0.5 * R.logicCam.aspect + 0.4, 0.22, 'txt bad'); break;
    case 'text': pop(d.t, d.x ?? (sim.e ? sim.e.anchor.x : 0.9), d.y ?? (sim.e ? sim.e.anchor.y - 0.25 : 0.3), 'txt ' + (d.cls || '')); if (d.cls === 'bad') sfx('nodeBad'); break;
    case 'chronoIn': sfx('chronoIn'); setSlowFX(0.7); break;
    case 'chronoOut': setSlowFX(0); break;
    case 'timeStop': banner('TEMPS FIGÉ', 'TRACE LIBREMENT', 'perf short'); flash(0.4, 0x7dffcf); break;
    case 'fightStart': {
      const def = d.def; $('eName').innerHTML = `<small>${def.title}</small>${def.name}`; $('eHp').querySelector('.mk').hidden = !def.p2;
      banner(def.name, def.title); musicIntensity(def.id === 'boss' ? 0.9 : 0.55);
      if (def.id === 'boss') { sfx('roar'); addShake(0.1); }
      R.env.floor.material.uniforms.uDanger.value = 0;
      break;
    }
    case 'fightGo': break;
    case 'phase2': sfx('roar'); banner('PHASE 2', 'LE GARDIEN SE FÊLE', ''); addShake(0.25); flash(0.4, 0xff2040); haptic([0, 80, 40, 120]); musicIntensity(1); R.env.floor.material.uniforms.uDanger.value = 1; break;
    case 'enemyDie': sfx('enemyDie'); sfx('shatter'); haptic([0, 50, 30, 90]); flash(0.6); addShake(0.2); banner('BRISÉ', '', 'perf');
      for (let i = 0; i < 4; i++) shock(d.x, d.y, 0.3 + i * 0.15, i % 2 ? 0xff2e88 : 0x22f0ff, 0.5 + i * 0.1);
      burst(d.x, d.y, 80, { col: 0xff2e88, speed: 1.2, size: 0.025, life: 0.9, drag: 2 }); sparks(d.x, d.y, 60, { col: 0xffffff, speed: 2.4, len: 0.09 }); break;
    case 'interlude': banner(d.next.name, d.next.title + ' · +35 PV'); sfx('uiOk'); break;
    case 'heroDie': sfx('lose'); haptic([0, 120, 60, 200]); banner('LAME BRISÉE', '', ''); vignette(1); break;
    case 'victory': case 'defeat': if (k === 'victory') play(W.hero, 'Cheer', { loop: true, fade: 0.3 }); setTimeout(() => (enc && mode === 'play') ? showReward(d) : showResult(d), mode === 'replay' ? 600 : 900); break;
    case 'tuto': $('tuto').hidden = false; $('tuto').className = ''; $('tutoH').textContent = d.t; $('tutoP').textContent = d.sub; $('tutoE').textContent = ''; break;
    case 'tutoRetry': $('tutoE').textContent = d.t; sfx('nodeBad'); break;
    case 'tutoOk': $('tuto').className = 'ok'; $('tutoE').textContent = 'PARFAIT !'; sfx('uiOk'); break;
    case 'tutoEnd': setTimeout(() => { $('tuto').hidden = true; }, 1800); tutoOn = false; store.set('tuto', false); break;
  }
}
const _hv = new THREE.Vector3(), _hs = { x: 0, y: 0 };
function HERO_SCR() { _hv.copy(W.hero.root.position); _hv.y += 1.2; return project(_hv, _hs); }
function onRupture(d) {
  const e = sim.e; if (!e) return;
  const x = e.anchor.x, y = e.anchor.y - e.H * 0.55;
  if (d.perfect) { sfx('perfect'); }
  if (d.timing === 'perfect' && !d.perfect) pop('TIMING PARFAIT', x, y + 0.06, 'txt gold');
  else if (d.timing === 'good') pop('BON TIMING', x, y + 0.06, 'txt ok');
  else if (d.timing === 'early') pop('TÔT', x, y + 0.06, 'txt warn');
  else if (d.timing === 'late') pop('TARD', x, y + 0.06, 'txt warn');
  if (d.allHit && !d.orderOK) pop('ORDRE ✗', x - 0.18, y + 0.12, 'txt bad');
  if (d.curves && d.curvesOK === d.curves) pop('COURBE ✓', x + 0.2, y + 0.12, 'txt gold');
  if (d.brasier) { pop('BRASIER ×1.6', x, y - 0.05, 'txt warn'); sfx('burn'); }
  if (d.ex) pop('ÉPUISÉ ×0.5', x, y - 0.1, 'txt bad');
  if (lameId === 'miroir' && d.hits.length) sfx('mirror');
}
function onHit(d) {
  const col = d.ghost ? 0xb46bff : d.chain ? 0x22f0ff : lameCol();
  sfx('hit', d.perfect ? 1.4 : 1); haptic(d.perfect ? [0, 25, 30, 60] : 18);
  sparks(d.x, d.y, d.perfect ? 34 : 16, { col: 0xffffff, speed: d.perfect ? 2.4 : 1.6, len: 0.06 });
  burst(d.x, d.y, d.perfect ? 26 : 12, { col, speed: 0.8, size: 0.022, life: 0.45 });
  shock(d.x, d.y, d.perfect ? 0.42 : 0.2, col);
  addShake(d.perfect ? 0.14 : 0.035);
  pop(String(d.dmg), d.x, d.y - 0.04, 'dmg' + (d.perfect || d.dmg >= 40 ? ' big' : ''));
  if (d.boom) { flash(0.5, 0xff7a1a); for (let i = 0; i < 3; i++) shock(d.x, d.y, 0.4 + i * 0.2, 0xff7a1a, 0.5); burst(d.x, d.y, 70, { col: 0xff7a1a, speed: 1.4, size: 0.03, life: 0.8 }); }
  if (d.perfect) {
    flash(0.7, 0xffffff); banner('RUPTURE PARFAITE', '×2.25 · RIPOSTE', 'perf');
    for (let i = 0; i < 3; i++) shock(d.x, d.y, 0.35 + i * 0.22, i ? lameCol() : 0xffffff, 0.45 + i * 0.12);
    sparks(d.x, d.y, 40, { col: lameCol(), speed: 3, len: 0.12, life: 0.4 }); sfx('shatter');
    R.env.floor.material.uniforms.uPulse.value = 0.001;
    R.punch.set(0, 0, -0.35);
  }
  const ac = W.enemies[sim.e.def.id]; ac.U.flash.value.setRGB(1, 1, 1);
}

// ---------- Résultats & sauvegarde ----------
function showResult(o) {
  if (mode === 'replay') { endReplay(); }
  const wasReplay = mode === 'replay';
  mode = 'result';
  const rec = sim.rec; lastRun = wasReplay ? sim.replay : { ...rec, events: rec.events.slice() };
  let isNew = false;
  if (!wasReplay && (!best || o.total > best.total)) {
    best = { total: o.total, rank: o.rank, lame: o.lame, date: Date.now() }; store.set('best', best);
    isNew = store.set('replay', lastRun);
  }
  show('result'); $('rbar').hidden = true; $('tuto').hidden = true;
  $('rTitle').textContent = wasReplay ? 'FIN DU REPLAY' : o.win ? 'FRACTURE SCELLÉE' : 'LAME BRISÉE'; $('rTitle').className = o.win ? 'win' : 'lose';
  const mm = s => Math.floor(s / 60) + ':' + String(Math.floor(s % 60)).padStart(2, '0');
  const rows = [['Dégâts & actions', '', o.base], ['Précision', Math.round(o.prec * 100) + ' %', o.bonus.prec], ['Combo max', '×' + o.maxCombo, o.bonus.combo], ['Temps', mm(o.time), o.bonus.time], ['Dégâts évités', Math.round(o.avoid * 100) + ' %', o.bonus.avoid], [o.win ? 'Victoire' : 'Défaite', '', o.bonus.win]];
  $('rBrk').innerHTML = rows.map(r => `<span>${r[0]}</span><span>${r[1]}</span><span>+0</span>`).join('');
  const cells = [...$('rBrk').children];
  const colors = { SS: '#ffd23f', S: '#ff2e88', A: '#22f0ff', B: '#7dffcf', C: '#b46bff', D: '#a99cc9' };
  const rk = $('rRank'); rk.textContent = o.rank; rk.dataset.r = o.rank; rk.style.setProperty('--c', colors[o.rank]); rk.style.setProperty('--fill', '100%'); rk.classList.remove('go');
  $('rTotal').textContent = '0'; $('rNew').hidden = true;
  let i = 0, shown = 0;
  const step = () => {
    if (mode !== 'result') return;
    if (i < rows.length) {
      const target = rows[i][2], el = cells[i * 3 + 2]; let v = 0; const t0 = performance.now();
      const anim = () => { const k = Math.min(1, (performance.now() - t0) / 380); v = Math.round(target * k); el.textContent = '+' + v.toLocaleString('fr-FR'); $('rTotal').textContent = (shown + v).toLocaleString('fr-FR'); if (k < 1) requestAnimationFrame(anim); else { shown += target; sfx('tick'); i++; setTimeout(step, 90); } };
      anim();
    } else {
      rk.classList.add('go'); rk.style.setProperty('--fill', '0%'); sfx('rank'); haptic([0, 40, 40, 80]);
      if (isNew) $('rNew').hidden = false;
      if (o.win && !wasReplay) sfx('win');
    }
  };
  setTimeout(step, 350);
  $('rReplay').style.display = lastRun ? '' : 'none';
  musicIntensity(0.3);
}

// ---------- Boucle ----------
let last = performance.now(), fpsS = 60, perfT = 0, lowT = 0, highT = 0, frameMs = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const dtR = Math.min(0.1, (now - last) / 1000); last = now;
  const t0 = performance.now();
  if ((mode === 'play' && !paused) || mode === 'replay') {
    acc += dtR * (mode === 'replay' ? replaySpeed : 1);
    let n = 0; while (acc >= TICK && n < 6) { sim.step(); acc -= TICK; n++; }
    if (n >= 6) acc = 0;
  } else if (mode === 'world' && !paused) {
    worldTick(dtR);
  } else if (mode === 'title') {
    showcase(dtR);
  } else if (mode === 'result' && W.hero) {
    W.hero.mixer.update(dtR); if (sim && sim.e) sim.e.a.mixer.update(dtR);
  }
  present(dtR);
  const ts = sim ? sim.ts : 1;
  updateFX(dtR * (ts === 0 ? 0.06 : Math.max(0.35, ts)), R.logicCam.aspect);
  // flash d'impact sur les matériaux des acteurs
  Object.values(W.enemies).forEach(a => a.U.flash.value.multiplyScalar(Math.pow(0.001, dtR)));
  if (W.hero) { const H = sim ? sim.hero : null; const gold = H && H.armed; W.hero.U.aura.value.setRGB(gold ? 0.9 : 0, gold ? 0.6 : 0, gold ? 0.1 : 0); }
  const fl = R.env.floor.material.uniforms.uPulse; if (fl.value > 0) { fl.value += dtR * 1.4; if (fl.value >= 1) fl.value = 0; }
  R.renderer.info.autoReset = false; R.renderer.info.reset();
  renderFrame(dtR, FX.scene, FX.cam);
  frameMs = frameMs * 0.9 + (performance.now() - t0) * 0.1;
  perfLoop(dtR);
}
function showcase(dt) {
  showcaseT += dt;
  W.hero.mixer.update(dt); W.enemies.boss.mixer.update(dt);
  const a = showcaseT * 0.08;
  R.logicCam.position.set(-1.0 + Math.sin(a) * 0.9, 1.5 + Math.sin(a * 1.3) * 0.12, 9.6 + Math.cos(a) * 0.4);
  R.logicCam.lookAt(-0.7, 1.75, 0); R.logicCam.updateMatrixWorld(true);
}
function perfLoop(dt) {
  fpsS = fpsS * 0.95 + (1 / Math.max(dt, 0.001)) * 0.05;
  perfT += dt;
  if (settings.hq && (mode === 'play' || mode === 'replay' || mode === 'world')) {
    if (fpsS < 47) { lowT += dt; highT = 0; } else if (fpsS > 58) { highT += dt; lowT = 0; } else { lowT = highT = 0; }
    if (lowT > 2.5 && R.dpr > 0.85) { setPixelRatio(Math.max(0.85, R.dpr - 0.2)); lowT = 0; }
    if (highT > 8 && R.dpr < Math.min(window.devicePixelRatio || 1, 1.6)) { setPixelRatio(Math.min(1.6, R.dpr + 0.1)); highT = 0; }
  }
  if (settings.perf && perfT > 0.25) {
    perfT = 0; const i = R.renderer.info;
    const mem = performance.memory ? ' · JS ' + Math.round(performance.memory.usedJSHeapSize / 1048576) + ' Mo' : '';
    $('perf').textContent = `${Math.round(fpsS)} fps · ${frameMs.toFixed(1)} ms CPU · ${i.render.calls} draw calls · ${Math.round(i.render.triangles / 1000)}k tris · géo ${i.memory.geometries} · tex ${i.memory.textures} · dpr ${R.dpr.toFixed(2)}${mem}`;
  }
}

// ---------- Présentation de l'état de la simulation ----------
let hudCache = {};
const tmpPts = [];
function setText(id, v) { if (hudCache[id] !== v) { hudCache[id] = v; $(id).textContent = v; } }
function present(dt) {
  if (!pres.failles) return;
  const live = sim && (mode === 'play' || mode === 'replay' || mode === 'result' || mode === 'reward');
  const S = sim, T = S ? S.T : 0;
  // --- failles + guides
  const win = live ? S.win : null;
  pres.failles.forEach((p, i) => {
    const f = win && win.f[i];
    if (!f) { p.d.hide(); p.dg.hide(); p.ring.hide(); p.ghost.hide(); return; }
    const touched = f.touchIdx >= 0;
    const col = touched ? 0xffffff : lameCol();
    p.pulse = Math.max(0, p.pulse - dt * 4); p.bad = Math.max(0, p.bad - dt * 3);
    const age = Math.min(1, (T - win.T0) / 0.18);
    const size = R_FAILLE * 3.1 * (0.4 + 0.6 * age) * (1 + p.pulse * 0.35);
    p.d.at(f.x, f.y, size); p.d.u('uCol', p.bad > 0 ? 0xff2040 : col); p.d.u('uT', R.time + i); p.d.u('uState', touched ? 1 : 0); p.d.u('uAlpha', 1);
    p.dg.set(f.n, f.x, f.y, R_FAILLE * 1.15, touched ? 0.35 : 1);
    // anneau d'approche sur la dernière faille
    if (!win.infinite && f.n === win.f.length) {
      const k = Math.max(0, (win.close - T) / win.D); const sc = 1 + 2.2 * k;
      const near = Math.abs(T - win.close) <= 0.09 * (lameId === 'chrono' ? 1.6 : 1);
      p.ring.at(f.x, f.y, R_FAILLE * 2.0 * sc * 1.25); p.ring.u('uRing', 0.8); p.ring.u('uCol', near ? 0xffd23f : (k < 0.2 ? 0xffffff : lameCol())); p.ring.u('uAlpha', T > win.close ? Math.max(0, 1 - (T - win.close) / 0.3) : 1);
    } else p.ring.hide();
    if (f.ghost) { p.ghost.at(f.ghost.x, f.ghost.y, size * 0.95); p.ghost.u('uT', R.time - i); p.ghost.u('uCol', touched ? 0xffffff : 0xb46bff); } else p.ghost.hide();
  });
  pres.guides.forEach((g, k) => {
    if (!win || k >= win.seg.length) { g.r.hide(); g.c.hide(); return; }
    const s = win.seg[k], A = win.f[win.order[k]], B = win.f[win.order[k + 1]];
    tmpPts.length = 0;
    if (s.curve) {
      const C = S.curveCtrl(A, B, s), qx = 2 * C.x - (A.x + B.x) / 2, qy = 2 * C.y - (A.y + B.y) / 2;
      for (let i = 0; i <= 20; i++) { const t = i / 20, u = 1 - t; tmpPts.push({ x: u * u * A.x + 2 * u * t * qx + t * t * B.x, y: u * u * A.y + 2 * u * t * qy + t * t * B.y }); }
      g.c.at(C.x, C.y, R_FAILLE * 1.0); g.c.u('uCol', s.ok ? 0x7dffcf : 0xffd23f); g.c.u('uT', R.time * 2);
    } else { for (let i = 0; i <= 8; i++) { const t = i / 8; tmpPts.push({ x: A.x + (B.x - A.x) * t, y: A.y + (B.y - A.y) * t }); } g.c.hide(); }
    g.r.set(tmpPts); g.r.u('uT', R.time); g.r.u('uAlpha', s.ok ? 0.9 : 0.5); g.r.color(s.curve ? 0xffd23f : 0xffffff, 0xffffff);
  });
  // --- lignes d'attaque ennemies
  const lines = live ? S.lines : [];
  pres.lines.forEach((p, i) => {
    const L = lines[i];
    if (!L || L.state === 'wait') { if (p.L && p.L.state === 'parried') { /* fondu après parade */ } p.r.hide(); p.L = null; return; }
    p.L = L;
    const pts = tmpPts; pts.length = 0; for (let j = 0; j <= 16; j++) { const t = j / 16; pts.push({ x: L.A.x + (L.B.x - L.A.x) * t, y: L.A.y + (L.B.y - L.A.y) * t }); }
    const total = L.impact - L.show, k = Math.min(1, Math.max(0, (T - L.show) / total));
    const inWin = T >= L.impact - 0.30 && T <= L.impact + 0.07;
    const purple = L.kind === 'purple', heavy = L.kind === 'heavy';
    let w = (purple ? 0.06 : heavy ? 0.036 : 0.03) * (0.6 + 0.55 * k);
    if (L.state === 'parried' || L.state === 'done' || L.state === 'feinted') { p.r.hide(); return; }
    p.r.width = w; p.r.set(pts, t => 0.6 + 0.4 * Math.sin(t * Math.PI));
    p.r.color(purple ? 0xa040ff : heavy ? 0xff3010 : 0xff1a3c, inWin ? 0xffffff : (purple ? 0xe0c0ff : 0xffb0b8));
    p.r.u('uProg', purple ? -1 : k); p.r.u('uAlpha', inWin ? 1.0 + 0.4 * Math.sin(R.time * 40) : 0.55 + 0.45 * k);
    p.r.u('uGlow', inWin ? 2.2 : 1.1);
  });
  // --- tracé en cours
  const g = live ? S.g : null;
  if (g && g.mode === 'trace' && g.pts.length > 1) {
    pres.trace.set(g.pts, t => 0.35 + 0.65 * t); pres.trace.u('uAlpha', g.ex ? 0.5 : 1); pres.trace.color(g.ex ? 0xff2040 : lameCol(), 0xffffff);
  } else pres.trace.hide();
  // --- maintien (garde / charge)
  if (g && g.mode === 'hold') {
    const H = S.hero; pres.holdRing.at(g.hx, g.hy, 0.16); pres.holdRing.u('uRing', 0.8); pres.holdRing.u('uCol', H.res >= 100 ? 0xffd23f : 0x22f0ff); pres.holdRing.u('uAlpha', 0.8);
    if (H.res >= 100 && !H.armed) { pres.holdCore.at(g.hx, g.hy, 0.2); pres.holdCore.u('uRing', Math.min(1, H.holdArm / 0.55)); pres.holdCore.u('uCol', 0xffd23f); } else pres.holdCore.hide();
  } else { pres.holdRing.hide(); pres.holdCore.hide(); }
  // --- lames (traînée qui suit le tracé)
  const blades = live ? S.blades : [];
  pres.blades.forEach((p, i) => {
    const B = blades[i];
    if (!B) { if (p.B) { p.fade -= dt * 3; if (p.fade <= 0) { p.r.hide(); p.B = null; } else p.r.u('uAlpha', p.fade); } return; }
    if (p.B !== B) { p.B = B; p.r.set(B.pts, t => Math.pow(t, 0.6) * 1.3 + 0.1); }
    const k = Math.min(1, B.t / B.dur);
    const perfect = B.o.perfect, res = B.o.res;
    p.r.color(perfect ? 0xffd23f : res ? 0xffd23f : B.o.echoOf ? 0x22f0ff : B.o.whiff ? 0x8a7cb0 : lameCol(), 0xffffff);
    p.r.u('uHead', k); p.r.u('uTail', Math.max(-0.3, k - (B.t > B.dur ? 1.2 : 0.55)));
    p.fade = B.t > B.dur ? Math.max(0, 1 - (B.t - B.dur) / 0.35) : 1; p.r.u('uAlpha', p.fade * (B.o.whiff ? 0.6 : 1));
    p.r.u('uGlow', perfect ? 2.0 : 1.3);
  });
  // doigt fantôme en replay
  if (mode === 'replay' && g) { const fp = g.pts[g.pts.length - 1]; const [X, Y] = px(fp.x, fp.y); const el = $('finger'); el.hidden = false; el.style.transform = `translate(${X}px,${Y}px)`; el.style.left = '0'; el.style.top = '0'; } else $('finger').hidden = true;
  // --- effets d'ambiance
  if (live) {
    musicMuffle(S.ts < 0.5 && !paused ? 0.6 : paused ? 0.85 : 0);
    setSlowFX(S.slow > 0 || S.chronoActive ? 0.8 : 0);
    setVigTarget(S.hero.hp < 30 ? 0.35 + 0.1 * Math.sin(R.time * 5) : 0);
    // lame du héros : couleur de la Résonance
    if (W.hero.blade) { W.hero.blade.material.emissive.set(S.hero.armed ? 0xffd23f : lameCol()); W.hero.blade.material.emissiveIntensity = S.hero.armed ? 1.6 : 0.45 + (S.g && S.g.mode === 'trace' ? 0.6 : 0); }
    updHUD();
  }
}
function updHUD() {
  const S = sim, H = S.hero, e = S.e;
  const hp = Math.max(0, H.hp / H.max);
  if (hudCache.hp !== hp) { hudCache.hp = hp; $('hHp').querySelector('i').style.transform = `scaleX(${hp})`; $('hHp').querySelector('u').style.transform = `scaleX(${hp})`; }
  const st = Math.round(H.st * 2) / 2;
  if (hudCache.st !== st) { hudCache.st = st; [...$('hSt').children].forEach((b, i) => { b.className = H.st >= i + 1 ? 'on' : H.st > i + 0.5 ? 'half' : ''; }); $('hSt').classList.toggle('ex', H.st < 1); }
  const res = H.armed ? 1 : H.res / 100;
  if (hudCache.res !== res || hudCache.armed !== H.armed) {
    hudCache.res = res; hudCache.armed = H.armed;
    $('hRes').querySelector('i').style.transform = `scaleX(${res})`; $('hRes').classList.toggle('full', H.res >= 100); $('hRes').classList.toggle('armed', H.armed);
    setText('hResLab', H.armed ? 'ARMÉE ×1.8' : H.res >= 100 ? 'MAINTIENS !' : 'RÉSONANCE');
  }
  if (e) {
    const eh = e.hp / e.max;
    if (hudCache.eh !== eh) { hudCache.eh = eh; $('eHp').querySelector('i').style.transform = `scaleX(${eh})`; $('eHp').querySelector('u').style.transform = `scaleX(${eh})`; }
    if (hudCache.burn !== e.burn) { hudCache.burn = e.burn; $('eBurn').innerHTML = '<b></b>'.repeat(e.burn); }
    $('eBox').style.visibility = S.state === 'interlude' ? 'hidden' : 'visible';
  }
  setText('sScore', S.score.toLocaleString('fr-FR'));
  if (hudCache.combo !== S.combo) { hudCache.combo = S.combo; const c = $('sCombo'); c.innerHTML = S.combo >= 2 ? `<b>×${S.combo}</b> COMBO` : ''; c.classList.remove('pop'); void c.offsetWidth; if (S.combo >= 2) c.classList.add('pop'); }
  const t = S.stats.time; setText('sTime', Math.floor(t / 60) + ':' + String(Math.floor(t % 60)).padStart(2, '0'));
}

// mise en pause automatique quand l'appli passe en arrière-plan
document.addEventListener('visibilitychange', () => { if (document.hidden && mode === 'play' && !paused) $('pauseBtn').onclick(); if (document.hidden) saveGame(); });
window.__fracture = { get sim() { return sim; }, get mode() { return mode; }, R, W, startRun, startReplay, store };

// =====================================================================
// MONDE RPG : sauvegarde, joystick, rencontres, PNJ, récompenses
// =====================================================================
const save = Object.assign({ lvl: 1, xp: 0, gold: 0, pots: 1, hp: 100, x: 0, z: 6, boss: 0 }, store.get('save', {}));
const maxHp = () => 100 + 12 * (save.lvl - 1);
const dmgMul = () => 1 + 0.07 * (save.lvl - 1);
const xpNext = () => 50 * save.lvl;
function saveGame() {
  if (WD.active && W.hero) { save.x = +W.hero.root.position.x.toFixed(2); save.z = +W.hero.root.position.z.toFixed(2); }
  save.hp = Math.min(maxHp(), Math.max(1, Math.round(save.hp))); store.set('save', save);
}
WD.heroPos.set(save.x, 0, save.z);

// --- joystick virtuel (moitié gauche de l'écran)
const joy = { id: null, cx: 0, cy: 0, x: 0, y: 0, m: 0 };
function joyStart(e) {
  if (joy.id !== null || e.clientX > R.W * 0.62) return;
  joy.id = e.pointerId; joy.cx = e.clientX; joy.cy = e.clientY; joy.x = joy.y = joy.m = 0;
  try { canvas.setPointerCapture(e.pointerId); } catch (err) { }
  const b = $('joyBase'); b.hidden = false; b.style.left = joy.cx + 'px'; b.style.top = joy.cy + 'px'; $('joyKnob').style.transform = '';
  $('wHint').hidden = true;
}
function joyMove(e) {
  if (e.pointerId !== joy.id) return;
  let dx = e.clientX - joy.cx, dy = e.clientY - joy.cy; const d = Math.hypot(dx, dy), R0 = 58;
  if (d > R0) { dx *= R0 / d; dy *= R0 / d; }
  joy.x = dx / R0; joy.y = dy / R0; joy.m = Math.min(1, d / R0);
  $('joyKnob').style.transform = `translate(${dx}px,${dy}px)`;
}
function joyUp(e) { if (e.pointerId !== joy.id) return; joyEnd(); }
function joyEnd() { joy.id = null; joy.m = 0; joy.x = joy.y = 0; $('joyBase').hidden = true; }

// --- entrer dans le monde
function goWorld(back) {
  mode = 'world'; sim = null; paused = false; enc = null; backToWorld = false; joyEnd();
  resetPresentation(); resize();
  Object.values(W.enemies).forEach(a => a.root.visible = false);
  if (save.hp <= 0) save.hp = maxHp();
  enterWorld(W.hero);
  show('whud'); $('tuto').hidden = true; $('rbar').hidden = true; $('pauseBtn').hidden = false;
  playMusic('hub'); musicIntensity(1); musicMuffle(0); setSlowFX(0); setVigTarget(0);
  if (!back) banner(WD.heroPos.z < -20 ? 'LES FRICHES' : 'QUARTIER ZÉRO', 'FRACTURE · LAME ZÉRO');
  hudW = {};
}
$('wMenu').onclick = () => { if (mode !== 'world') return; paused = true; joyEnd(); sfx('ui'); syncToggles(); show('pause'); };
$('wPotion').onclick = () => {
  if (mode !== 'world') return;
  if (save.pots <= 0) { sfx('nodeBad'); pop('PLUS DE FIOLE', 0.92 * R.A, 0.7, 'txt bad'); return; }
  if (save.hp >= maxHp()) { pop('PV AU MAX', 0.92 * R.A, 0.7, 'txt warn'); return; }
  save.pots--; save.hp = Math.min(maxHp(), save.hp + maxHp() * 0.4); sfx('resonanceReady'); haptic(20);
  flash(0.25, 0xff5a8a); pop('+' + Math.round(maxHp() * 0.4) + ' PV', 0.5 * R.A, 0.42, 'txt ok'); saveGame();
};
$('wAct').onclick = () => { if (mode === 'world' && WD.near) interact(WD.near); };

// --- boucle du monde
let regenAcc = 0, mmT = 0, hudW = {};
const worldHooks = {
  area(a) {
    banner(a === 'friches' ? 'LES FRICHES' : 'QUARTIER ZÉRO', a === 'friches' ? 'ZONE HOSTILE · LES SQUELETTES RÔDENT' : 'ZONE SÛRE');
    playMusic(a === 'friches' ? 'combat' : 'hub'); musicIntensity(a === 'friches' ? 0.35 : 1);
    if (a === 'hub') resetBoss();
    $('wZone').textContent = a === 'friches' ? 'LES FRICHES' : 'QUARTIER ZÉRO';
  },
  aggro(e) { sfx('telegraph', e.type === 'boss' ? 'purple' : 'red'); if (e.type === 'boss') { sfx('roar'); addShake(0.12); } },
};
function worldTick(dt) {
  const e = updateWorld(dt, W.hero, joy, worldHooks);
  regenAcc += dt; if (regenAcc > 1) { regenAcc = 0; if (save.hp < maxHp()) save.hp = Math.min(maxHp(), save.hp + (WD.area === 'hub' ? 4 : 1)); }
  if (e) startEncounter(e);
  mmT += dt; if (mmT > 0.1) { mmT = 0; drawMinimap($('minimap'), W.hero); }
  updWorldHUD();
}
function updWorldHUD() {
  const m = maxHp(), hp = Math.max(0, save.hp) / m;
  if (hudW.hp !== hp) { hudW.hp = hp; $('wHp').querySelector('i').style.transform = `scaleX(${hp})`; $('wHp').querySelector('u').style.transform = `scaleX(${hp})`; $('wHpTxt').textContent = Math.round(save.hp) + ' / ' + m; }
  if (hudW.lvl !== save.lvl) { hudW.lvl = save.lvl; $('wLvl').textContent = 'NV ' + save.lvl; }
  const xp = save.xp / xpNext(); if (hudW.xp !== xp) { hudW.xp = xp; $('wXp').querySelector('i').style.width = (xp * 100) + '%'; }
  if (hudW.gold !== save.gold) { hudW.gold = save.gold; $('wGold').textContent = save.gold.toLocaleString('fr-FR'); }
  if (hudW.pots !== save.pots) { hudW.pots = save.pots; $('wPot').textContent = '×' + save.pots; $('wPotion').style.opacity = save.pots ? 1 : 0.5; }
  const n = WD.near; const lab = n ? n.label : '';
  if (hudW.act !== lab) { hudW.act = lab; $('wAct').hidden = !n; $('wAct').textContent = lab; }
}

// --- rencontre : la Brèche aspire le héros dans l'arène de duel
function startEncounter(e, training) {
  joyEnd(); saveGame();
  enc = { e, training: !!training, type: e ? e.type : 'minion' };
  sfx('shatter'); haptic([0, 40, 30, 60]); flash(0.9, 0xff2e88); addShake(0.2);
  leaveWorld(W.hero);
  resize();
  newSim({ seed: (Date.now() % 2147483000) | 0, lame: lameId, tuto: tutoOn || !!training, fights: [enc.type], heroHp: training ? maxHp() : Math.max(1, save.hp), heroMax: maxHp(), dmgMul: dmgMul() });
  mode = 'play'; show('hud'); $('tuto').hidden = true; $('rbar').hidden = true;
  playMusic('combat'); musicIntensity(enc.type === 'boss' ? 0.9 : 0.55);
}
function showReward(o) {
  const wasEnc = enc; mode = 'reward';
  const rec = sim.rec; lastRun = { ...rec, events: rec.events.slice() };
  if (!best || o.total > best.total) { best = { total: o.total, rank: o.rank, lame: o.lame, date: Date.now() }; store.set('best', best); store.set('replay', lastRun); }
  const rows = []; let lvlUp = false;
  if (o.win && !wasEnc.training) {
    const info = ENEMY_INFO[wasEnc.type];
    const rankMul = { SS: 2, S: 1.5, A: 1.25, B: 1, C: 1, D: 1 }[o.rank];
    const gold = Math.round((info.gold[0] + Math.random() * (info.gold[1] - info.gold[0])) * rankMul);
    const xp = Math.round(info.xp * rankMul);
    save.gold += gold; save.xp += xp;
    while (save.xp >= xpNext()) { save.xp -= xpNext(); save.lvl++; lvlUp = true; }
    save.hp = Math.max(1, Math.round(sim.hero.hp)) + (lvlUp ? 12 : 0);
    if (wasEnc.e) killEnt(wasEnc.e);
    if (wasEnc.type === 'boss') save.boss++;
    rows.push(['Rang de style', o.rank + (rankMul > 1 ? ' (×' + rankMul + ')' : '')], ['Expérience', '+' + xp + ' XP'], ['Éclats', '+' + gold + ' ◆'], ['PV restants', Math.round(sim.hero.hp) + ' / ' + maxHp()]);
  } else if (o.win) {
    rows.push(['Rang de style', o.rank], ['Entraînement', 'aucune récompense']);
  } else {
    const lost = wasEnc.training ? 0 : Math.round(save.gold * 0.2); save.gold -= lost; save.hp = maxHp();
    if (!wasEnc.training) { WD.heroPos.set(0, 0, 6); WD.heroRot = Math.PI; }
    rows.push(['Rang de style', o.rank], ['Éclats perdus', '-' + lost + ' ◆'], ['Réveil', 'Quartier Zéro']);
  }
  saveGame();
  const colors = { SS: '#ffd23f', S: '#ff2e88', A: '#22f0ff', B: '#7dffcf', C: '#b46bff', D: '#a99cc9' };
  $('rwTitle').textContent = o.win ? (wasEnc.type === 'boss' ? 'GARDIEN BRISÉ' : 'VICTOIRE') : 'LAME BRISÉE';
  $('rwTitle').style.color = o.win ? 'var(--lime)' : 'var(--red)';
  const rk = $('rwRank'); rk.textContent = o.rank; rk.style.setProperty('--c', colors[o.rank]);
  $('rwRows').innerHTML = rows.map(r => `<span>${r[0]}</span><span>${r[1]}</span>`).join('');
  $('rwLvl').hidden = !lvlUp; if (lvlUp) $('rwLvl').textContent = 'NIVEAU ' + save.lvl + ' ! +12 PV MAX · +7 % DÉGÂTS';
  show('reward'); sfx(o.win ? 'win' : 'lose'); if (lvlUp) setTimeout(() => sfx('rank'), 500);
  musicIntensity(0.3);
}
$('rwGo').onclick = () => { sfx('uiOk'); const boss = $('rwTitle').textContent === 'GARDIEN BRISÉ'; goWorld(true); if (boss) banner('LES FRICHES RESPIRENT', 'LE GARDIEN REVIENDRA'); };
$('rwReplay').onclick = () => { if (!lastRun) return; sfx('uiOk'); backToWorld = true; const r = lastRun; startReplay(r); backToWorld = true; };

// --- PNJ & interactions
function dialog(name, role, color, text, buttons) {
  joyEnd(); paused = true;
  $('dName').textContent = name; $('dRole').textContent = role; $('dName').style.setProperty('--c', color); $('dText').textContent = text;
  const bx = $('dBtns'); bx.innerHTML = '';
  buttons.concat([['AU REVOIR', null]]).forEach(([lab, fn, c]) => {
    const b = document.createElement('button'); b.className = 'nb' + (fn && !c ? ' main' : ''); b.textContent = lab; if (c) b.style.setProperty('--c', c);
    b.onclick = () => { sfx('ui'); paused = false; show('whud'); if (fn) fn(); };
    bx.appendChild(b);
  });
  show('dialog'); sfx('uiOk');
}
function interact(it) {
  switch (it.kind) {
    case 'forge': dialog('KAÏ', 'FORGERON DE LAMES', '#ff7a1a', `Ta lame actuelle : ${LAMES[lameId].name}. Chaque Lame-Mémoire change ta façon de tracer. Choisis bien, gamin.`, [['CHOISIR UNE LAME', () => { paused = true; renderCards(); show('lames'); }]]); break;
    case 'archives': dialog('MIRA', 'ARCHIVISTE', '#b46bff', best ? `Ton meilleur combat : ${best.total.toLocaleString('fr-FR')} points, rang ${best.rank}. Je l'ai gravé dans les archives — tu veux le revoir ?` : `Aucun combat archivé pour l'instant. Va dans les Friches et reviens avec un rang qui en vaut la peine.`, best && store.get('replay', null) ? [['VOIR LE MEILLEUR REPLAY', () => { backToWorld = true; leaveWorld(W.hero); saveGame(); startReplay(store.get('replay', null)); backToWorld = true; }, 'var(--gold)']] : []); break;
    case 'dojo': dialog('SENSEI ODA', 'DOJO', '#22f0ff', `Le Tracé-Rupture, ça se travaille. Un duel d'entraînement avec tutoriel, ou l'Arène complète : trois adversaires d'affilée, score de style.`, [['ENTRAÎNEMENT', () => startEncounter(null, true)], ['MODE ARÈNE', () => { saveGame(); leaveWorld(W.hero); enc = null; backToWorld = true; startRun(); backToWorld = true; }, 'var(--pink)']]); break;
    case 'shop': dialog('NORI', 'MARCHANDE', '#ffd23f', `Fiole de soin : 15 éclats, rend 40 % des PV. Tu en portes ${save.pots} sur 3. Et toi, tu as ${save.gold} éclats.`, save.gold >= 15 && save.pots < 3 ? [['ACHETER UNE FIOLE (15 ◆)', () => { save.gold -= 15; save.pots++; sfx('uiOk'); pop('+1 FIOLE', 0.5 * R.A, 0.45, 'txt gold'); saveGame(); }]] : []); break;
    case 'fountain': save.hp = maxHp(); sfx('resonanceCharge'); flash(0.35, 0xff7ad0); pop('PV RESTAURÉS', 0.5 * R.A, 0.42, 'txt ok'); haptic(30); saveGame(); break;
    case 'chest': {
      const c = it.ref; c.open = true; const g = 25 + Math.round(Math.random() * 20); save.gold += g; save.xp += 15;
      while (save.xp >= xpNext()) { save.xp -= xpNext(); save.lvl++; banner('NIVEAU ' + save.lvl, '+12 PV MAX · +7 % DÉGÂTS', 'perf'); sfx('rank'); }
      if (Math.random() < 0.5 && save.pots < 3) { save.pots++; pop('+1 FIOLE', 0.5 * R.A, 0.36, 'txt gold'); }
      sfx('win'); flash(0.3, 0xffd23f); pop('+' + g + ' ◆  +15 XP', 0.5 * R.A, 0.42, 'txt gold'); haptic([0, 30, 30, 50]); saveGame(); break;
    }
  }
}
window.__fracture.goWorld = goWorld; window.__fracture.save = save; window.__fracture.WD = WD;
