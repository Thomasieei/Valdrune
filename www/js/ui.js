/* NOCTALIS — interface */
import * as THREE from 'three';
import { E, toScreen, makeChar, setQuality } from './engine.js';
import { S, save, wipe, stats, fmt, fmtTime, RANKS, RANK_COL, GRADES, GRADE_COL, SSTATS, ZONES, WEAPONS, FORGE, FORGE_MAX, forgeCost, RELICS, RELIC_RAR, RELIC_COST,
  DUNGEONS, KEY_MAX, KEY_REGEN, shadowDmg, shadowSpd, shadowLvlCost, shadowLvlMax, slotsMax, xpNeed, power, armyPower, rollGrade, checkQuests, questDef, relicBonus, SELL_VAL } from './core.js';
import { G, enterHub, enterZone, startDungeon, startSiege, skill, ariseNear, autoEquip, syncArmy, sellValue, refreshWeapon, enterBreach } from './game.js';
import { SFX } from './audio.js';
import * as DM from './domain.js';
import { startAssault, domainApi } from './game.js';

const $ = id => document.getElementById(id);
const h = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const ICO = {
  ombres: '<path d="M12 2C7 2 4 6 4 10c0 3 1.5 4.5 2 6v3h3v-2h2v2h2v-2h2v2h3v-3c.5-1.5 2-3 2-6 0-4-3-8-8-8zM9 13a2 2 0 110-4 2 2 0 010 4zm6 0a2 2 0 110-4 2 2 0 010 4z"/>',
  forge: '<path d="M3 8h13c3 0 5 1 5 3h-5l-1 2h-2v3l3 4H6l3-4v-3H7C5 13 3 11 3 8z"/>',
  arme: '<path d="M20 2l-9 9-2-2-2 2 2 2-5 5 2 2 5-5 2 2 2-2-2-2 9-9V2h-2z"/>',
  autel: '<path d="M12 2l3 6 6 1-4.5 4 1 6.5L12 16l-5.5 3.5 1-6.5L3 9l6-1z"/>',
  donjons: '<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm0 4a6 6 0 110 12 6 6 0 010-12zm0 3a3 3 0 100 6 3 3 0 000-6z"/>',
  siege: '<path d="M12 1l4 7-4 15L8 8z M3 21h18v2H3z"/>',
  monde: '<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm6.9 6h-3a15 15 0 00-1.4-4A8 8 0 0118.9 8zM12 4c.9 1.2 1.6 2.6 2 4h-4c.4-1.4 1.1-2.8 2-4zM4.3 14a8 8 0 010-4h3.4a16 16 0 000 4H4.3zm.8 2h3a15 15 0 001.4 4A8 8 0 015.1 16zM8 8H5.1a8 8 0 014.4-4A15 15 0 008 8zm4 12c-.9-1.2-1.6-2.6-2-4h4c-.4 1.4-1.1 2.8-2 4zm2.3-6H9.7a14 14 0 010-4h4.6a14 14 0 010 4z"/>',
  quetes: '<path d="M6 2h10l4 4v16H6a3 3 0 01-3-3V5a3 3 0 013-3zm2 6v2h8V8H8zm0 4v2h8v-2H8zm0 4v2h5v-2H8z"/>',
  reglages: '<path d="M19.4 13a7.6 7.6 0 000-2l2.1-1.6-2-3.5-2.5 1a7.4 7.4 0 00-1.7-1L15 3h-4l-.4 2.9a7.4 7.4 0 00-1.7 1l-2.5-1-2 3.5L6.6 11a7.6 7.6 0 000 2l-2.1 1.6 2 3.5 2.5-1c.5.4 1.1.7 1.7 1L11 21h4l.4-2.9c.6-.3 1.2-.6 1.7-1l2.5 1 2-3.5-2.2-1.6zM13 15.5a3.5 3.5 0 110-7 3.5 3.5 0 010 7z"/>',
  gold: '<circle cx="12" cy="12" r="9" fill="#ffcc33" stroke="#a86b00" stroke-width="2"/><text x="12" y="16.5" text-anchor="middle" font-size="12" font-weight="900" fill="#a86b00">N</text>',
  gem: '<path d="M6 3h12l4 6-10 13L2 9z" fill="#7dd3fc" stroke="#0369a1" stroke-width="1.5"/><path d="M2 9h20M9 3l3 6 3-6M12 9v13" stroke="#e0f2fe" stroke-width="1" fill="none"/>',
  rune: '<path d="M12 2l8 5v10l-8 5-8-5V7z" fill="#a855f7" stroke="#4c1d95" stroke-width="1.5"/><path d="M12 7v10M9 9l6 6" stroke="#f3e8ff" stroke-width="2"/>',
  key: '<circle cx="8" cy="12" r="5" fill="none" stroke="#38bdf8" stroke-width="3"/><path d="M13 12h9v3h-3v3h-3v-3h-3" fill="#38bdf8"/>',
  frag: '<path d="M12 2l4 8-4 12-4-12z" fill="currentColor" stroke="#000" stroke-width="1"/>',
  ore: '<path d="M4 16l3-9 6-3 6 5 1 8-7 4z" fill="#38bdf8" stroke="#0c4a6e" stroke-width="1.5"/><path d="M7 7l6 5 7-3M13 12l0 11" stroke="#e0f2fe" fill="none"/>',
  wood: '<rect x="3" y="8" width="18" height="9" rx="4.5" fill="#b45309" stroke="#451a03" stroke-width="1.5"/><circle cx="17" cy="12.5" r="3" fill="#fcd34d" stroke="#451a03"/>',
  soul: '<path d="M12 2c3 4 7 7 7 12a7 7 0 01-14 0c0-3 2-5 3-6 0 2 1 3 2 3 0-4 1-7 2-9z" fill="#e879f9" stroke="#701a75" stroke-width="1.5"/>',
  domaine: '<path d="M3 20h18v2H3zM4 10l4 3 4-7 4 7 4-3-2 9H6z"/>',
  scroll: '<path d="M6 3h11a3 3 0 013 3v1h-3v12a3 3 0 01-3 3H5a3 3 0 01-3-3v-2h3V6a3 3 0 013-3zm2 5v2h7V8zm0 4v2h7v-2z"/>',
};
const svg = (k, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24">${ICO[k]}</svg>`;
export const UI = {};

/* ---------- construction du HUD ---------- */
const DOCK = [['domaine', 'Domaine'], ['ombres', 'Ombres'], ['forge', 'Forge'], ['arme', 'Armurerie'], ['autel', 'Reliques'], ['donjons', 'Brèches'], ['siege', 'Siège'], ['monde', 'Monde'], ['quetes', 'Quêtes'], ['reglages', 'Options']];
UI.build = () => {
  const hud = $('hud');
  hud.innerHTML = `
  <div id="pcard"><div id="plvl">1</div><div><div id="pname">Le Veilleur</div><div id="ppow">Puissance 0</div></div></div>
  <div id="cur"></div>
  <div id="dock"></div>
  <div id="zt"><div id="ztn"></div><div id="zts"></div></div>
  <div id="dhud" hidden><div class="dh-top"><div id="dhicon">${svg('donjons')}</div><div><div id="dhk">Brèche</div><div id="dhr">Chambre 1 / 15</div><div class="bar"><i id="dhb"></i></div></div><div id="dht"><small>TEMPS</small><b>00:00</b></div></div><div id="dhl">Ennemis restants</div></div>
  <div id="rt"><canvas id="mm" width="150" height="150"></canvas><div id="breach" hidden></div><div id="buffs"></div></div>
  <div id="joy"><div id="knob"></div></div>
  <div id="bars"><div id="hpb"><i></i><span></span></div><div id="xpb"><i></i><span></span></div></div>
  <div id="army"></div>
  <div id="acts">
    <div class="tog" id="tAuto"><b>FARM</b><small>AUTO</small></div>
    <div class="tog" id="tArise"><b>ÉVEIL</b><small>AUTO</small></div>
    <div class="tog" id="tHarv"><b>RÉCOLTE</b><small>AUTO</small></div>
    <div class="sk" id="kDash"><div class="cd"></div><span>RUÉE</span></div>
    <div class="sk" id="kStrike"><div class="cd"></div><span>FRAPPE</span></div>
    <div class="sk big" id="kArise"><span>ÉVEIL</span><small id="ariseN"></small></div>
    <div class="sk ult" id="kUlt"><svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="17" class="ring"/><circle cx="20" cy="20" r="17" class="prog" id="ultp"/></svg><span>DOMAINE</span></div>
  </div>
  <div id="station" hidden></div><div id="msg" hidden>${svg('scroll')}<b>MESSAGER</b><i></i></div><div id="says"></div>
  <div id="toasts"></div><div id="banner" hidden><b></b><small></small></div><div id="flash"></div><div id="fade"></div><div id="labels"></div><div id="dmgs"></div>`;
  const dock = $('dock');
  for (const [id, name] of DOCK) { const b = h('div', 'dk', `${svg(id)}<span>${name}</span><i class="dot" hidden></i>`); b.dataset.id = id; b.onclick = () => { SFX.play('click', 0.4); open(id); }; dock.appendChild(b); }
  $('tAuto').onclick = () => { S.autoFarm = !S.autoFarm; SFX.play('click', 0.4); };
  $('tArise').onclick = () => { S.autoArise = !S.autoArise; SFX.play('click', 0.4); };
  $('tHarv').onclick = () => { S.harvest = !S.harvest; SFX.play('click', 0.4); };
  $('msg').onclick = () => { SFX.play('click', 0.4); UI.openDialogue(); };
  bindHold($('kStrike'), () => skill('strike')); bindHold($('kDash'), () => skill('dash')); bindHold($('kUlt'), () => skill('ult'));
  $('kArise').onclick = () => ariseNear(true);
  $('breach').onclick = () => { if (G.breach) { G.goTo = G.breach.pos.clone(); UI.toast('En route vers la brèche…', ''); } };
  joystick(); camDrag(); keys();
  for (let i = 0; i < 46; i++) { const d = h('div', 'dn'); d.style.display = 'none'; $('dmgs').appendChild(d); dmgPool.push({ el: d, t: 0 }); }
};
function bindHold(el, fn) { el.addEventListener('pointerdown', e => { e.stopPropagation(); fn(); }); }

/* ---------- entrées ---------- */
function joystick() {
  const joy = $('joy'), knob = $('knob'); let id = null, cx = 0, cy = 0;
  addEventListener('pointerdown', e => {
    if (id !== null || e.target.closest('.panel,#dock,#acts,#rt,#cur,#pcard,#station,#result,#arisec,#msg,#dlg')) return;
    if (e.clientX > innerWidth * 0.45) return;
    id = e.pointerId; cx = e.clientX; cy = e.clientY; joy.style.left = cx - 60 + 'px'; joy.style.top = cy - 60 + 'px'; joy.classList.add('on'); SFX.unlock();
  });
  addEventListener('pointermove', e => { if (e.pointerId !== id) return; let dx = e.clientX - cx, dy = e.clientY - cy; const d = Math.hypot(dx, dy), m = 50; if (d > m) { dx *= m / d; dy *= m / d; } knob.style.transform = `translate(${dx}px,${dy}px)`; G.input.x = dx / m; G.input.z = dy / m; });
  const up = e => { if (e.pointerId !== id) return; id = null; G.input.x = G.input.z = 0; knob.style.transform = ''; joy.classList.remove('on'); };
  addEventListener('pointerup', up); addEventListener('pointercancel', up);
}
function camDrag() {
  let id = null, lx = 0, ly = 0;
  addEventListener('pointerdown', e => { if (id !== null || e.target.id !== 'c' || e.clientX <= innerWidth * 0.45) return; id = e.pointerId; lx = e.clientX; ly = e.clientY; SFX.unlock(); });
  addEventListener('pointermove', e => { if (e.pointerId !== id) return; E.yaw -= (e.clientX - lx) * 0.006; E.pitch = Math.max(0.35, Math.min(1.25, E.pitch + (e.clientY - ly) * 0.004)); lx = e.clientX; ly = e.clientY; });
  addEventListener('pointerup', e => { if (e.pointerId === id) id = null; });
  addEventListener('wheel', e => { E.dist = Math.max(9, Math.min(28, E.dist + e.deltaY * 0.01)); });
}
function keys() {
  const k = {}; const upd = () => { G.input.x = (k.KeyD ? 1 : 0) - (k.KeyA || k.KeyQ ? 1 : 0); G.input.z = (k.KeyS ? 1 : 0) - (k.KeyW || k.KeyZ ? 1 : 0); };
  addEventListener('keydown', e => { k[e.code] = 1; upd(); SFX.unlock(); if (e.code === 'Space') skill('strike'); if (e.code === 'KeyE') ariseNear(true); if (e.code === 'ShiftLeft') skill('dash'); if (e.code === 'KeyR') skill('ult'); });
  addEventListener('keyup', e => { k[e.code] = 0; upd(); });
}

/* ---------- textes flottants ---------- */
const dmgPool = []; let dmgI = 0; const sp = {};
function spawnText(pos, txt, cls, scale = 1) {
  const d = dmgPool[dmgI = (dmgI + 1) % dmgPool.length];
  d.el.className = 'dn ' + cls; d.el.textContent = txt; d.el.style.display = 'block';
  d.p = new THREE.Vector3(pos.x + (Math.random() - 0.5) * 1.2, pos.y + 1.8 * scale + Math.random() * 0.6, pos.z + (Math.random() - 0.5) * 1.2); d.t = cls === 'arise' || cls === 'fail' ? 1.4 : 0.9; d.max = d.t;
}
UI.dmg = (pos, n, cls, scale) => spawnText(pos, (cls === 'hurt' ? '-' : '') + fmt(n), cls, scale);
UI.dmgText = (pos, t, cls) => spawnText(pos, t, cls, 1.2);
UI.floatIco = (pos) => spawnText(pos, '+1 ◆', 'gemf', 1);
UI.coins = (pos, gold, fr, col) => {
  toScreen({ x: pos.x, y: pos.y + 1, z: pos.z }, sp); if (!sp.vis) return;
  const tgt = $('cur').getBoundingClientRect();
  for (let i = 0; i < 3; i++) {
    const c = h('div', 'coin', svg('gold')); c.style.left = sp.x + 'px'; c.style.top = sp.y + 'px'; document.body.appendChild(c);
    const dx = (Math.random() - 0.5) * 60, dy = -30 - Math.random() * 40;
    c.animate([{ transform: 'translate(0,0) scale(.6)' }, { transform: `translate(${dx}px,${dy}px) scale(1)`, offset: 0.35 }, { transform: `translate(${tgt.left + 20 - sp.x}px,${tgt.top + 12 - sp.y}px) scale(.5)`, opacity: 0.7 }], { duration: 750 + i * 90, easing: 'ease-in' }).onfinish = () => c.remove();
  }
};

/* ---------- étiquettes des monstres ---------- */
UI.addLabel = e => {
  const l = h('div', 'lab' + (e.boss ? ' boss' : e.elite ? ' elite' : ''), `<div class="ln"><b style="background:${RANK_COL[e.r]}">${RANKS[e.r]}</b>${e.name}</div><div class="lb"><i></i></div>`);
  $('labels').appendChild(l); e.lab = l; e.labBar = l.querySelector('i');
};
UI.dropLabel = e => { e.lab?.remove(); };

/* ---------- messages ---------- */
UI.toast = (t, cls = '') => { const d = h('div', 'toast ' + cls, t); $('toasts').appendChild(d); setTimeout(() => d.classList.add('out'), 2600); setTimeout(() => d.remove(), 3100); while ($('toasts').children.length > 4) $('toasts').firstChild.remove(); };
let banT = 0;
UI.banner = (t, s, col) => { const b = $('banner'); b.hidden = false; b.querySelector('b').textContent = t; b.querySelector('small').textContent = s || ''; b.style.setProperty('--c', col || '#c26bff'); b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); banT = 2.6; };
let ztT = 0; UI.zoneTitle = (n, s) => { $('ztn').textContent = n; $('zts').textContent = s; $('zt').classList.remove('show'); void $('zt').offsetWidth; $('zt').classList.add('show'); ztT = 3.5; };
UI.hurtFlash = () => { const f = $('flash'); f.classList.remove('hit'); void f.offsetWidth; f.classList.add('hit'); };
UI.fade = () => { const f = $('fade'); f.classList.remove('go'); void f.offsetWidth; f.classList.add('go'); };
UI.shakeCrystal = () => { };
UI.station = s => {
  const el = $('station'); if (!s) { el.hidden = true; return; }
  const key = s.id + (s.did || ''); if (el.dataset.id !== key) { el.dataset.id = key; const own = s.did && DM.dom().d[s.did].owner === 'joueur'; el.innerHTML = `<b style="color:${s.col}">${s.label}</b><span>${s.did ? (own ? 'GÉRER' : 'ATTAQUER') : 'OUVRIR'}</span>`; el.onclick = () => s.did ? (own ? (DSEL = s.did, open('domaine')) : startAssault(s.did, 'conquete')) : open({ forge: 'forge', armurerie: 'arme', autel: 'autel', donjons: 'donjons' }[s.id]); }
  el.hidden = false;
};
UI.ariseCard = (s, big) => {
  const c = h('div', 'arisec' + (big ? ' big' : ''), `<img src="${portrait(s.m, true, s.keep)}"><div><small>OMBRE ÉVEILLÉE</small><b><i style="background:${RANK_COL[s.r]}">${RANKS[s.r]}</i>${s.name}</b><span>${s.st.map(g => `<em style="color:${GRADE_COL[g]}">${GRADES[g]}</em>`).join('')} · ${fmt(shadowDmg(s))} dgt</span></div>`);
  const old = document.querySelectorAll('.arisec'); if (old.length >= 4) old[0].remove();
  document.body.appendChild(c); setTimeout(() => c.classList.add('out'), big ? 2600 : 1600); setTimeout(() => c.remove(), big ? 3100 : 2100);
  const all = document.querySelectorAll('.arisec'); all.forEach((x, i) => x.style.setProperty('--i', all.length - 1 - i));
};
UI.result = (title, col, rows, cb) => {
  const m = h('div', 'panel result', `<div class="pin" style="--c:${col}"><h2>${title}</h2><div class="rows">${rows.map(([a, b]) => `<div><span>${a}</span><b>${b}</b></div>`).join('')}</div><button class="btn gold">CONTINUER</button></div>`);
  m.id = 'result'; document.body.appendChild(m); m.querySelector('button').onclick = () => { m.remove(); SFX.play('click', 0.4); cb && cb(); };
};

/* ---------- portraits 3D ---------- */
const portraits = {}; let pScene, pCam, pRT;
export function portrait(model, shadow, keep) {
  const key = model + (shadow ? 'S' : '') + (keep ? keep.join() : ''); if (portraits[key]) return portraits[key];
  if (!pScene) { pScene = new THREE.Scene(); pCam = new THREE.PerspectiveCamera(32, 1, 0.1, 50); pRT = new THREE.WebGLRenderTarget(160, 160); pRT.texture.colorSpace = THREE.SRGBColorSpace; pScene.add(new THREE.HemisphereLight(0xffffff, 0x553388, 2.2)); const d = new THREE.DirectionalLight(0xffffff, 2); d.position.set(2, 4, 5); pScene.add(d); }
  const ch = makeChar(model, { shadow, keep, noShadow: true, eyeCol: shadow ? 0x9ff3ff : 0xff4040 });
  pScene.add(ch.root); ch.update(0.4); ch.root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(ch.root); const c = box.getCenter(new THREE.Vector3()); const sz = box.getSize(new THREE.Vector3());
  const hgt = Math.max(sz.y, sz.x * 0.9, sz.z * 0.9); pCam.position.set(c.x + hgt * 0.5, c.y + hgt * 0.15, c.z + hgt * 2.2); pCam.lookAt(c);
  const r = E.renderer; const prevT = r.getRenderTarget(); const prevC = new THREE.Color(); r.getClearColor(prevC); const prevA = r.getClearAlpha();
  r.setRenderTarget(pRT); r.setClearColor(0x000000, 0); r.clear(); r.render(pScene, pCam);
  const px = new Uint8Array(160 * 160 * 4); r.readRenderTargetPixels(pRT, 0, 0, 160, 160, px); r.setRenderTarget(prevT); r.setClearColor(prevC, prevA);
  const cv = document.createElement('canvas'); cv.width = cv.height = 160; const cx = cv.getContext('2d'); const id = cx.createImageData(160, 160);
  for (let y = 0; y < 160; y++) id.data.set(px.subarray((159 - y) * 640, (160 - y) * 640), y * 640); cx.putImageData(id, 0, 0);
  ch.dispose(); return portraits[key] = cv.toDataURL();
}

/* ---------- panneaux ---------- */
let cur = null; let DSEL = 'hameau';
function open(id, arg) {
  close(); const p = h('div', 'panel'); p.id = 'pn'; document.body.appendChild(p); cur = { id, el: p, arg };
  p.addEventListener('pointerdown', e => { if (e.target === p) close(); });
  render();
}
function close() { $('pn')?.remove(); cur = null; save(); }
UI.close = close;
function frame(title, col, body, wide) { return `<div class="pin ${wide ? 'wide' : ''}" style="--c:${col}"><div class="ph"><h2>${title}</h2><div class="x" data-a="close">✕</div></div><div class="pb">${body}</div></div>`; }
function render() {
  if (!cur) return; const f = PANELS[cur.id]; const sc = cur.el.querySelector('.pb')?.scrollTop || 0;
  cur.el.innerHTML = f(cur.arg); const pb = cur.el.querySelector('.pb'); if (pb) pb.scrollTop = sc;
  cur.el.querySelectorAll('[data-a]').forEach(b => b.onclick = ev => { ev.stopPropagation(); act(b.dataset.a, b.dataset.v); });
}
function act(a, v) {
  SFX.play('click', 0.35);
  const s = cur?.arg && S.shadows.find(x => x.id === cur.arg);
  switch (a) {
    case 'close': return cur?.id === 'shadow' ? open('ombres') : close();
    case 'sh': return open('shadow', +v);
    case 'sort': S.sort = v; break;
    case 'eqbest': autoEquip(true); UI.toast('Meilleures ombres équipées', 'good'); break;
    case 'dissolve': { const r = +v; let g = 0, n = 0; S.shadows = S.shadows.filter(x => { if (!x.eq && !x.lock && x.r <= r) { g += sellValue(x); n++; return false; } return true; }); S.gold += g; UI.toast(n ? `${n} ombres dissoutes : +${fmt(g)} or` : 'Rien à dissoudre', n ? 'gold' : 'bad'); if (n) SFX.play('coins', 0.6); break; }
    case 'autod': S.autoDissolve = +v; break;
    case 'inv': { const c = 100; if (S.gems < c) return UI.toast('Pas assez d’Éclats', 'bad'); S.gems -= c; S.invMax += 50; break; }
    case 'eq': if (!s) break; if (s.eq) { s.eq = false; } else { const n = S.shadows.filter(x => x.eq).length; if (n >= slotsMax()) { UI.toast('Emplacements pleins', 'bad'); break; } s.eq = true; } syncArmy(); break;
    case 'lock': if (s) s.lock = !s.lock; break;
    case 'slock': if (s) { s.sl = s.sl || [0, 0, 0, 0]; s.sl[+v] ^= 1; } break;
    case 'roll': case 'rollall': {
      if (!s) break; const idx = a === 'roll' ? [+v] : [0, 1, 2, 3].filter(i => !(s.sl && s.sl[i]));
      const cost = a === 'roll' ? 1 : 3; if (!idx.length) break; if (S.runes < cost) return UI.toast('Pas assez de runes', 'bad');
      S.runes -= cost; for (const i of idx) s.st[i] = Math.max(rollGrade(0.15), a === 'roll' ? 0 : 0); SFX.play('seal', 0.5);
      if (idx.some(i => s.st[i] === 7)) UI.toast('Grade M obtenu !', 'gold'); syncArmy(); break;
    }
    case 'lvl': {
      if (!s) break; let n = +v, done = 0;
      while (n-- > 0 && s.lvl < shadowLvlMax(s)) { const c = shadowLvlCost(s); if (S.gold < c) break; S.gold -= c; s.lvl++; done++; }
      if (!done) UI.toast(s.lvl >= shadowLvlMax(s) ? 'Niveau maximum' : 'Pas assez d’or', 'bad'); else { SFX.play('ok', 0.5); syncArmy(); } break;
    }
    case 'sell': if (!s || s.lock) break; S.gold += sellValue(s); S.shadows.splice(S.shadows.indexOf(s), 1); syncArmy(); UI.toast('Ombre dissoute', 'gold'); return open('ombres');
    case 'ftab': cur.ftab = +v; break;
    case 'forge': { const [z, id] = v.split(':'); const l = S.forge[z][id] || 0; if (l >= FORGE_MAX) break; const c = forgeCost(+z, l); if (S.frags[z] < c) return UI.toast(`Pas assez de ${ZONES[z].frag}`, 'bad'); S.frags[z] -= c; S.forge[z][id] = l + 1; SFX.play('ok', 0.5); syncArmy(); break; }
    case 'buyw': { const w = WEAPONS[+v]; if (+v < S.wOwned) { S.weapon = +v; refreshWeapon(); break; } const wc = w.cost * (1 - DM.discount()); if (S.gold < wc) return UI.toast('Pas assez d’or', 'bad'); if (DM.dom().res.minerai < w.ore) return UI.toast('Pas assez d’Ombracier — mine des filons !', 'bad'); S.gold -= wc; DM.dom().res.minerai -= w.ore; S.wOwned = +v + 1; S.weapon = +v; refreshWeapon(); SFX.play('win', 0.5); UI.banner(w.name, 'Arme forgée · dégâts ×' + fmt(w.mult), '#ffcc33'); break; }
    case 'pull': return pull(+v);
    case 'dj': close(); return startDungeon(+v);
    case 'siege': close(); return startSiege();
    case 'go': close(); return v === 'hub' ? enterHub() : enterZone(+v);
    case 'claim': { const q = S.quests.find(x => x.id === v); const d = questDef(v); if (!q || q.done || q.p < d.goal) break; q.done = true; const r = d.rew; S.gems += r.gems || 0; S.runes += r.runes || 0; S.keys += r.keys || 0; UI.toast('Récompense réclamée !', 'gold'); SFX.play('win', 0.5); break; }
    case 'dtab': cur.dtab = v; break;
    case 'dsel': DSEL = v; break;
    case 'dtax': DM.dom().d[DSEL].tax = +v; break;
    case 'dwork': { const st = DM.dom().d[DSEL]; const n = +v; if (n > 0 && DM.freeWorkers() <= 0) return UI.toast('Aucune ombre libre (non équipée) à affecter', 'bad'); st.workers = Math.max(0, Math.min(12, st.workers + n)); break; }
    case 'dgov': { const D = DM.dom(); const l = DM.lieutenant(v); if (!l) break; for (const x of Object.values(D.d)) if (x.gov === v) x.gov = null; const prev = D.d[DSEL].gov && DM.lieutenant(D.d[DSEL].gov); if (prev) prev.gov = null; D.d[DSEL].gov = v; l.gov = DSEL; UI.toast(`${l.name} gouverne ${DM.DISTRICTS.find(d => d.id === DSEL).name}`, 'good'); break; }
    case 'dungov': { const D = DM.dom(); const l = DM.lieutenant(D.d[DSEL].gov); if (l) l.gov = null; D.d[DSEL].gov = null; break; }
    case 'dtower': { const D = DM.dom(); const st = D.d[DSEL]; const l = st.towers[v] || 0; if (!l && Object.keys(st.towers).length >= 3) return UI.toast('3 tours maximum par quartier', 'bad'); if (l >= 5) break; const c = DM.towerCost(DSEL, v, l); if (!DM.canPay(c)) return UI.toast('Ressources insuffisantes : ' + DM.costTxt(c), 'bad'); DM.pay(c); st.towers[v] = l + 1; SFX.play('ok', 0.6); UI.toast(`${DM.TOWERS[v].name} niveau ${l + 1} construite`, 'gold'); DM.addRenom(5); break; }
    case 'dattack': close(); return startAssault(DSEL, 'conquete');
    case 'gift': { const c = { bois: 60, minerai: 60 }; if (!DM.canPay(c)) return UI.toast('Il faut 60 Bois et 60 Ombracier', 'bad'); DM.pay(c); DM.dom().att[v] = Math.min(100, DM.dom().att[v] + 15); UI.toast('Présent accepté : relations améliorées', 'good'); break; }
    case 'recruit': { const cost = 5000 * Math.pow(3, DM.dom().lts.length); if (S.gold < cost) return UI.toast('Pas assez d’or', 'bad'); S.gold -= cost; const names = ['Brannoc l’Ours', 'Ilsa Main-Froide', 'Thadeus le Gris', 'Mira des Cendres', 'Corvin Sans-Nom', 'Edda la Rousse']; const tr = ['loyal', 'ruse', 'mystique', 'avare', 'ambitieux']; const n = names.find(x => !DM.dom().lts.some(l => l.name === x)) || 'Mercenaire'; DM.dom().lts.push({ id: 'm' + Date.now(), name: n, trait: tr[Math.floor(Math.random() * tr.length)], model: ['Knight', 'Barbarian', 'Rogue_Hooded', 'Mage'][Math.floor(Math.random() * 4)], loy: 45, gov: null }); UI.toast(n + ' rejoint ta guilde', 'gold'); break; }
    case 'tmus': SFX.setMusic(!S.music); break;
    case 'tsfx': S.sfx = !S.sfx; break;
    case 'thq': S.hq = !S.hq; setQuality(S.hq); break;
    case 'wipe': if (cur.wipe) wipe(); cur.wipe = 1; UI.toast('Appuie encore pour tout effacer', 'bad'); break;
  }
  render();
}
function pull(n) {
  const cost = n === 10 ? RELIC_COST * 9 : RELIC_COST; if (S.gems < cost) return UI.toast('Pas assez d’Éclats', 'bad');
  S.gems -= cost; const res = [];
  for (let i = 0; i < n; i++) {
    let r = Math.random() * 100, rar = 0; for (let k = RELIC_RAR.length - 1; k >= 0; k--) { const cum = RELIC_RAR.slice(k).reduce((a, b) => a + b.w, 0); if (r < cum) { rar = k; break; } }
    const rel = RELICS[Math.floor(Math.random() * RELICS.length)]; const o = S.relics[rel.id];
    if (!o || rar > o.rar) S.relics[rel.id] = { rar, lvl: o ? o.lvl : 1 }; else o.lvl++;
    res.push({ rel, rar });
  }
  SFX.play('power', 0.6); syncArmy();
  cur.pulls = res; render();
}

const PANELS = {
  ombres() {
    const st = stats(); const eqN = S.shadows.filter(s => s.eq).length; const sort = S.sort || 'pow';
    const list = [...S.shadows].sort(sort === 'rank' ? (a, b) => b.r - a.r || shadowDmg(b, st) - shadowDmg(a, st) : sort === 'new' ? (a, b) => b.id - a.id : (a, b) => (b.eq - a.eq) || shadowDmg(b, st) - shadowDmg(a, st));
    const cards = list.map(s => `<div class="sc ${s.eq ? 'eq' : ''}" data-a="sh" data-v="${s.id}" style="--rc:${RANK_COL[s.r]}"><img src="${portrait(s.m, true, s.keep)}" loading="lazy"><b class="rk">${RANKS[s.r]}</b>${s.lock ? '<i class="lk">🔒</i>' : ''}${s.eq ? '<i class="ck">✓</i>' : ''}<span class="nm">${s.name}</span><span class="dg">${fmt(shadowDmg(s, st))}</span><span class="lv">Nv ${s.lvl}</span></div>`).join('');
    const body = `<div class="bar2"><div class="chip">${S.shadows.length}/${S.invMax}</div><div class="chip ${eqN >= slotsMax() ? 'full' : ''}">Équipées <b>${eqN}/${slotsMax()}</b></div><div class="chip">DPS armée <b>${fmt(armyPower(st))}</b></div>
      <div class="seg">${[['pow', 'Puissance'], ['rank', 'Rang'], ['new', 'Récentes']].map(([k, n]) => `<span class="${sort === k ? 'on' : ''}" data-a="sort" data-v="${k}">${n}</span>`).join('')}</div></div>
      <div class="grid">${cards || '<p class="empty">Aucune ombre. Abats un monstre et appuie sur <b>ÉVEIL</b> pour le relever.</p>'}</div>
      <div class="foot"><button class="btn green" data-a="eqbest">Équiper le meilleur</button>
      <button class="btn red" data-a="dissolve" data-v="1">Dissoudre E-D</button><button class="btn red" data-a="dissolve" data-v="3">Dissoudre ≤ B</button>
      <div class="seg small"><em>Auto-dissolution</em>${[[-1, 'Off'], [0, 'E'], [1, '≤D'], [2, '≤C'], [3, '≤B']].map(([k, n]) => `<span class="${S.autoDissolve === k ? 'on' : ''}" data-a="autod" data-v="${k}">${n}</span>`).join('')}</div>
      <button class="btn blue" data-a="inv">+50 places (100 ◆)</button></div>`;
    return frame('Ombres', '#c26bff', body, true);
  },
  shadow(id) {
    const s = S.shadows.find(x => x.id === id); if (!s) return frame('Ombre', '#c26bff', '');
    const st = stats(); const c1 = shadowLvlCost(s); const mx = s.lvl >= shadowLvlMax(s);
    const rows = SSTATS.map((d, i) => `<div class="srow"><span class="sn" style="color:${d.col}">${d.name}<small>${d.desc}</small></span><b class="gv">+${d.vals[s.st[i]]}%</b><b class="gr" style="background:${GRADE_COL[s.st[i]]}">${GRADES[s.st[i]]}</b><span class="sl ${s.sl && s.sl[i] ? 'on' : ''}" data-a="slock" data-v="${i}">${s.sl && s.sl[i] ? '🔒' : '🔓'}</span><button class="btn small purple" data-a="roll" data-v="${i}" ${s.sl && s.sl[i] ? 'disabled' : ''}>Relancer · 1 ${svg('rune', 'ii')}</button></div>`).join('');
    const body = `<div class="sdet"><div class="sp" style="--rc:${RANK_COL[s.r]}"><img src="${portrait(s.m, true, s.keep)}"><b class="rk big">${RANKS[s.r]}</b><h3>${s.name}</h3><div class="kv"><span>Niveau</span><b>${s.lvl} / ${shadowLvlMax(s)}</b></div><div class="kv"><span>Dégâts</span><b class="red">${fmt(shadowDmg(s, st))}</b></div><div class="kv"><span>Vitesse</span><b>×${shadowSpd(s).toFixed(2)}</b></div><div class="kv"><span>Origine</span><b>${ZONES[s.z].name}${s.boss ? ' · Boss' : ''}</b></div></div>
      <div class="sr"><h4>Statistiques d'ombre <small>(M = rang maximal)</small></h4>${rows}<button class="btn purple wide" data-a="rollall">Relancer tout (non verrouillées) · 3 ${svg('rune', 'ii')}</button>
      <div class="lvlrow"><button class="btn gold" data-a="lvl" data-v="1" ${mx ? 'disabled' : ''}>${mx ? 'NIVEAU MAX' : `Renforcer · ${fmt(c1)} ${svg('gold', 'ii')}`}</button><button class="btn gold" data-a="lvl" data-v="10" ${mx ? 'disabled' : ''}>×10</button></div>
      <div class="lvlrow"><button class="btn ${s.eq ? 'grey' : 'green'}" data-a="eq">${s.eq ? 'Retirer' : 'Équiper'}</button><button class="btn blue" data-a="lock">${s.lock ? 'Déverrouiller' : 'Verrouiller'}</button><button class="btn red" data-a="sell" ${s.lock ? 'disabled' : ''}>Dissoudre · ${fmt(sellValue(s))}</button></div></div></div>`;
    return frame('Ombre', RANK_COL[s.r], body, true);
  },
  forge() {
    const t = cur.ftab ?? Math.max(0, G.zone); const Z = ZONES[t]; const ok = S.lvl >= Z.req;
    const tabs = ZONES.map((z, i) => `<span class="${i === t ? 'on' : ''} ${S.lvl < z.req ? 'locked' : ''}" data-a="ftab" data-v="${i}" style="--c:${z.fragCol}">${z.name}</span>`).join('');
    const rows = FORGE.map(f => { const l = S.forge[t][f.id] || 0, mx = l >= FORGE_MAX, c = forgeCost(t, l);
      const val = f.id === 'eveil' || f.id === 'butin' ? '+' + Math.round(f.per * (t + 1) * l * 100) + '%' : '×' + (1 + f.per * (t + 1) * l).toFixed(2);
      return `<div class="frow"><div class="fi" style="--c:${f.col}">${svg(f.id === 'lame' ? 'arme' : f.id === 'ombre' ? 'ombres' : f.id === 'eveil' ? 'autel' : 'gold')}</div><div class="ft"><b>${f.name}</b><small>${mx ? '<em>Niveau maximum</em>' : `Niveau ${l} / ${FORGE_MAX}`}</small><div class="bar"><i style="width:${l / FORGE_MAX * 100}%;background:${f.col}"></i></div></div><b class="fv">${val}</b>
      <button class="btn gold" data-a="forge" data-v="${t}:${f.id}" ${mx || !ok ? 'disabled' : ''}>${mx ? 'MAX' : `${fmt(c)} <i class="fr" style="color:${Z.fragCol}">${svg('frag')}</i>`}</button></div>`; }).join('');
    const st = stats();
    return frame('Forge des Ombres', '#ff7a45', `<div class="seg tabs">${tabs}</div><div class="fh"><span style="color:${Z.fragCol}">${svg('frag', 'ii')} ${Z.frag} : <b>${fmt(S.frags[t])}</b></span><small>${ok ? 'Les fragments tombent des monstres de cette zone.' : `Débloquée au niveau ${Z.req}`}</small></div>${rows}
      <div class="tot"><span>Total arme <b>×${fmt(st.lame)}</b></span><span>Total ombres <b>×${fmt(st.ombre)}</b></span><span>Éveil <b>+${Math.round(st.eveil * 100)}%</b></span><span>Or <b>+${Math.round((st.gold - 1) * 100)}%</b></span></div>`);
  },
  arme() {
    const rows = WEAPONS.map((w, i) => { const own = i < S.wOwned, eq = S.weapon === i, next = i === S.wOwned;
      return `<div class="wrow ${eq ? 'eq' : ''} ${!own && !next ? 'dim' : ''}"><i class="wc" style="background:#${w.col.toString(16).padStart(6, '0')}"></i><div><b>${w.name}</b><small>Tier ${i + 1} · dégâts ×${fmt(w.mult)}</small></div>
      ${eq ? '<span class="tag">ÉQUIPÉE</span>' : own ? `<button class="btn blue" data-a="buyw" data-v="${i}">Équiper</button>` : next ? `<button class="btn gold" data-a="buyw" data-v="${i}">${fmt(w.cost * (1 - DM.discount()))} ${svg('gold', 'ii')}${w.ore ? ` · ${fmt(w.ore)} ${svg('ore', 'ii')}` : ''}</button>` : '<span class="tag dim">🔒</span>'}</div>`; }).join('');
    return frame('Armurerie', '#ffcc33', `<p class="hint">Chaque arme multiplie tes dégâts et ta vie. Les lames supérieures exigent de l’Ombracier.${DM.discount() ? ` <b style="color:#4ade80">Remise de renommée : -${Math.round(DM.discount() * 100)}%</b>` : ''}</p>${rows}`);
  },
  autel() {
    const owned = RELICS.map(r => { const o = S.relics[r.id]; const rr = o ? RELIC_RAR[o.rar] : null;
      return `<div class="rel ${o ? '' : 'none'}" style="--c:${rr ? rr.c : '#444'}"><div class="ri">${svg({ eye: 'autel', heart: 'ombres', sword: 'arme', coin: 'gold', book: 'quetes', fang: 'siege' }[r.ico])}</div><b>${r.name}</b><small>${o ? `${rr.n} · Nv ${o.lvl}` : 'Non obtenue'}</small><em>${{ eveil: "Chance d'Éveil", ombre: "Dégâts d'ombre", lame: "Dégâts d'arme", or: 'Or', xp: 'XP', crit: 'Critique' }[r.stat]} +${o ? Math.round(r.per * rr.m * (1 + 0.25 * (o.lvl - 1)) * 100) : 0}%</em></div>`; }).join('');
    const pulls = cur.pulls ? `<div class="pulls">${cur.pulls.map((p, i) => `<div class="pr" style="--c:${RELIC_RAR[p.rar].c};animation-delay:${i * 0.08}s"><b>${RELIC_RAR[p.rar].n}</b><span>${p.rel.name}</span></div>`).join('')}</div>` : '';
    return frame('Autel des Reliques', '#c26bff', `<p class="hint">Invoque des reliques avec tes Éclats. Les doublons renforcent la relique, une rareté supérieure la remplace.</p><div class="rels">${owned}</div>${pulls}
      <div class="foot center"><button class="btn purple big" data-a="pull" data-v="1">Invoquer ×1 · ${RELIC_COST} ${svg('gem', 'ii')}</button><button class="btn gold big" data-a="pull" data-v="10">Invoquer ×10 · ${RELIC_COST * 9} ${svg('gem', 'ii')}</button></div>
      <div class="odds">${RELIC_RAR.map(r => `<span style="color:${r.c}">${r.n} ${r.w}%</span>`).join('')}</div>`);
  },
  donjons() {
    const kt = S.keys >= KEY_MAX ? 'max' : fmtTime(KEY_REGEN - S.keyT);
    const rows = DUNGEONS.map((d, i) => { const Z = ZONES[d.z]; const ok = S.lvl >= Z.req;
      return `<div class="djr ${ok ? '' : 'dim'}" style="--c:${Z.fragCol}"><div class="dji">${svg('donjons')}</div><div><b>${d.name}</b><small>${Z.name} · ${d.rooms} chambres · ${fmtTime(d.time)} · rang ${RANKS[Z.mobs[0].r + 1]}+</small><small class="rw">Récompenses : Éclats, Runes, ${Z.frag} ×2, chance de clé</small></div>
      <button class="btn ${ok ? 'gold' : 'grey'}" data-a="dj" data-v="${i}" ${ok ? '' : 'disabled'}>${ok ? `Entrer · 1 ${svg('key', 'ii')}` : 'Niv. ' + Z.req}</button></div>`; }).join('');
    return frame('Salle des Brèches', '#38bdf8', `<div class="fh"><span>${svg('key', 'ii')} Clés : <b>${S.keys}/${KEY_MAX}</b></span><small>Prochaine clé : ${kt}</small></div>${rows}
      <p class="hint">Des brèches gratuites s'ouvrent aussi au hasard dans les zones de chasse : repère-les sur la carte.</p>`);
  },
  siege() {
    return frame('Siège sans fin', '#38bdf8', `<div class="sgb"><div><small>Record</small><b>Vague ${S.siegeBest}</b></div><div><small>Point de contrôle</small><b>Vague ${S.siegeCk}</b></div></div>
      <p class="hint">Les ennemis marchent vers le Cristal. S'il se brise, la partie s'arrête. Un point de contrôle toutes les 25 vagues. Chaque vague rapporte des Éclats, et des Runes toutes les 5 vagues. Un champion attaque toutes les 10 vagues.</p>
      <div class="foot center"><button class="btn gold big" data-a="siege" ${S.lvl < 8 ? 'disabled' : ''}>${S.lvl < 8 ? 'Niveau 8 requis' : `Lancer · départ vague ${S.siegeCk + 1}`}</button></div>`);
  },
  monde() {
    const cards = [`<div class="wc2" style="--c:#8b5cf6" data-a="go" data-v="hub"><b>Citadelle Noctalis</b><small>Refuge · Forge · Reliques</small></div>`,
      ...ZONES.map((z, i) => `<div class="wc2 ${S.lvl < z.req ? 'locked' : ''}" style="--c:${z.fragCol};--g1:${z.sky[1]};--g2:${z.sky[0]}" ${S.lvl >= z.req ? `data-a="go" data-v="${i}"` : ''}><b>${z.name}</b><small>${S.lvl < z.req ? '🔒 Niveau ' + z.req : `Rangs ${RANKS[z.mobs[0].r]}–${RANKS[z.boss.r]} · ${z.frag}`}</small>${G.zone === i && G.mode === 'zone' ? '<em>ICI</em>' : ''}</div>`)].join('');
    return frame('Monde', '#8b5cf6', `<div class="wgrid">${cards}<div class="wc2" style="--c:#38bdf8" data-a="siege"><b>Siège sans fin</b><small>Record vague ${S.siegeBest}</small></div></div>`);
  },
  quetes() {
    checkQuests();
    const rows = S.quests.map(q => { const d = questDef(q.id); const p = Math.min(q.p, d.goal); const ok = p >= d.goal;
      return `<div class="qr ${q.done ? 'done' : ''}"><div><b>${d.name}</b><div class="bar"><i style="width:${p / d.goal * 100}%"></i></div><small>${fmt(p)} / ${d.goal}</small></div><span class="qrw">${d.rew.gems ? d.rew.gems + ' ' + svg('gem', 'ii') : ''} ${d.rew.runes ? d.rew.runes + ' ' + svg('rune', 'ii') : ''} ${d.rew.keys ? d.rew.keys + ' ' + svg('key', 'ii') : ''}</span>
      <button class="btn ${ok && !q.done ? 'gold' : 'grey'}" data-a="claim" data-v="${q.id}" ${ok && !q.done ? '' : 'disabled'}>${q.done ? 'Réclamé' : 'Réclamer'}</button></div>`; }).join('');
    return frame('Quêtes du jour', '#4ade80', rows + `<div class="tot"><span>Monstres abattus <b>${fmt(S.kills)}</b></span><span>Ombres éveillées <b>${fmt(S.arises)}</b></span><span>Boss vaincus <b>${S.bossKills}</b></span><span>Brèches scellées <b>${S.dClears}</b></span></div>`);
  },
  reglages() {
    const t = (a, on, n) => `<div class="qr"><b>${n}</b><button class="btn ${on ? 'green' : 'grey'}" data-a="${a}">${on ? 'Activé' : 'Désactivé'}</button></div>`;
    return frame('Options', '#a3acbf', t('tmus', S.music, 'Musique') + t('tsfx', S.sfx, 'Effets sonores') + t('thq', S.hq, 'Haute qualité (ombres portées)') +
      `<p class="hint">Contrôles : joystick à gauche, glisse à droite pour tourner la caméra. Les attaques sont automatiques au contact.</p><div class="foot center"><button class="btn red" data-a="wipe">Effacer la sauvegarde</button></div>`);
  },
};


PANELS.domaine = () => {
  const D = DM.dom(); const tab = cur.dtab || 'carte'; const inc = DM.incomeTotal(); const pw = power();
  const head = `<div class="dmh"><div class="ttl"><small>Renommée ${fmt(D.renom)}</small><b>${DM.titleName()}</b></div>${DM.RES.map(r => `<span style="color:${r.col}">${svg(r.ico, 'ii')} <b>${fmt(D.res[r.id])}</b> <small>+${fmt(inc[r.id] || 0)}/min</small></span>`).join('')}<span>${svg('gold', 'ii')} <small>+${fmt(inc.or || 0)}/min</small></span></div>
    <div class="seg tabs">${[['carte', 'Carte des quartiers'], ['guilde', 'Guilde'], ['factions', 'Factions']].map(([k, n]) => `<span class="${tab === k ? 'on' : ''}" data-a="dtab" data-v="${k}" style="--c:#c26bff">${n}</span>`).join('')}</div>`;
  let body = '';
  if (tab === 'carte') {
    const hex = (x, y, r) => Array.from({ length: 6 }, (_, i) => `${x + r * Math.cos(i * Math.PI / 3 + Math.PI / 6)},${y + r * Math.sin(i * Math.PI / 3 + Math.PI / 6)}`).join(' ');
    const map = `<svg class="dmap" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
      <defs><radialGradient id="rg0"><stop offset="0" stop-color="#3f6b35"/><stop offset="1" stop-color="#1b2e17"/></radialGradient><radialGradient id="rg1"><stop offset="0" stop-color="#3b2f55"/><stop offset="1" stop-color="#16112a"/></radialGradient><radialGradient id="rg2"><stop offset="0" stop-color="#6b2f2a"/><stop offset="1" stop-color="#2a0f0d"/></radialGradient></defs>
      <ellipse cx="20" cy="76" rx="22" ry="22" fill="url(#rg0)"/><ellipse cx="50" cy="42" rx="20" ry="22" fill="url(#rg1)"/><ellipse cx="84" cy="46" rx="18" ry="28" fill="url(#rg2)"/>
      <text x="20" y="54" class="rl">BOIS DES CROCS</text><text x="50" y="18" class="rl">NÉCROPOLE</text><text x="84" y="16" class="rl">BASTION</text>
      <path d="M18 64 L30 82 M18 64 L8 84 M30 82 L40 50 M40 50 L46 30 M40 50 L58 52 M58 52 L78 26 M78 26 L90 46 M90 46 L80 66" stroke="rgba(255,255,255,.18)" stroke-width=".6" stroke-dasharray="1.5 1.2" fill="none"/>
      ${DM.DISTRICTS.map(d => { const st = D.d[d.id]; const F = DM.FACTIONS[st.owner]; const own = st.owner === 'joueur'; const lock = S.lvl < ZONES[d.z].req; const ev = D.pending.some(p => p.d === d.id);
        return `<g data-a="dsel" data-v="${d.id}" class="dh ${DSEL === d.id ? 'sel' : ''} ${lock ? 'lk' : ''}"><polygon points="${hex(d.x, d.y, 6.2)}" fill="${F.col}" fill-opacity="${own ? 0.9 : 0.45}" stroke="${DSEL === d.id ? '#fff' : own ? '#f5d0fe' : '#000'}" stroke-width="${DSEL === d.id ? 1 : 0.5}"/>
        ${own ? `<circle cx="${d.x}" cy="${d.y}" r="7.4" fill="none" stroke="${st.loy < 25 ? '#ff3355' : '#4ade80'}" stroke-width=".7" stroke-dasharray="${st.loy / 100 * 46.5} 46.5" transform="rotate(-90 ${d.x} ${d.y})"/>` : ''}
        <text x="${d.x}" y="${d.y + 1.3}" class="hi">${{ minerai: '⛏', bois: '🌲', essence: '✦', or: '¤' }[d.res]}</text>${ev ? `<circle cx="${d.x + 5}" cy="${d.y - 5}" r="1.6" fill="#ff3355" class="pul"/>` : ''}${lock ? `<text x="${d.x}" y="${d.y + 9.5}" class="lt">Niv ${ZONES[d.z].req}</text>` : ''}</g>`; }).join('')}</svg>`;
    const d = DM.DISTRICTS.find(x => x.id === DSEL), st = D.d[DSEL], own = st.owner === 'joueur'; const F = DM.FACTIONS[st.owner];
    const def = DM.defPower(DSEL); const ratio = pw / def;
    let det = `<h3 style="color:${F.col}">${d.name}</h3><div class="kv"><span>Contrôle</span><b style="color:${F.col}">${F.name}</b></div><div class="kv"><span>Ressource</span><b>${d.res === 'or' ? 'Or (impôts)' : DM.RES.find(r => r.id === d.res).name}</b></div><div class="kv"><span>Défense</span><b>${fmt(def)}</b></div>`;
    if (!own) {
      det += `<div class="kv"><span>Ta puissance</span><b style="color:${ratio >= 1 ? '#4ade80' : ratio > 0.4 ? '#ffcc33' : '#ff3355'}">${fmt(pw)}</b></div><p class="hint">${ratio >= 1 ? 'Tes ombres peuvent prendre ce quartier.' : ratio > 0.4 ? 'Assaut risqué. Renforce ton armée ou attaque quand même.' : 'Ils vont t’écraser. Reviens plus fort.'}</p>
        <div class="kv"><span>Relation avec ${F.name}</span><b>${D.att[st.owner] ?? 0}</b></div><button class="btn red wide" data-a="dattack" ${S.lvl < ZONES[d.z].req ? 'disabled' : ''}>⚔ LANCER L’ASSAUT</button>`;
    } else {
      const y = DM.yieldOf(DSEL); const lt = st.gov && DM.lieutenant(st.gov);
      det += `<div class="kv"><span>Loyauté</span><b style="color:${st.loy < 25 ? '#ff3355' : st.loy < 50 ? '#ffcc33' : '#4ade80'}">${Math.round(st.loy)} / 100</b></div><div class="bar"><i style="width:${st.loy}%;background:${st.loy < 25 ? '#ff3355' : '#4ade80'}"></i></div>
        <div class="kv"><span>Production</span><b>${Object.entries(y).map(([k, v]) => `${fmt(v)} ${k === 'or' ? svg('gold', 'ii') : svg(DM.RES.find(r => r.id === k).ico, 'ii')}`).join(' ')} /min</b></div>
        <div class="row2"><span>Impôts</span><div class="seg small">${DM.TAX.map((t, i) => `<span class="${st.tax === i ? 'on' : ''}" data-a="dtax" data-v="${i}">${t.n}</span>`).join('')}</div></div>
        <div class="row2"><span>Ouvriers (ombres libres : ${DM.freeWorkers()})</span><div><button class="btn small grey" data-a="dwork" data-v="-1">−</button> <b>${st.workers}</b> <button class="btn small purple" data-a="dwork" data-v="1">+</button></div></div>
        <div class="row2"><span>Gouverneur</span><b>${lt ? `${lt.name} <small>(${DM.TRAITS[lt.trait].n})</small> <button class="btn small grey" data-a="dungov">Retirer</button>` : '<small>aucun</small>'}</b></div>
        ${D.lts.filter(l => l.gov !== DSEL).length ? `<div class="ltpick">${D.lts.filter(l => l.gov !== DSEL).map(l => `<span data-a="dgov" data-v="${l.id}">${l.name}${l.gov ? ' ↺' : ''}</span>`).join('')}</div>` : ''}
        <h4>Tours</h4><div class="towers">${Object.keys(DM.TOWERS).map(k => { const l = st.towers[k] || 0; const can = l || Object.keys(st.towers).length < 3; const c = DM.towerCost(DSEL, k, l);
          return `<div class="tw ${l ? 'built' : ''} ${can ? '' : 'dim'}"><b>${DM.TOWERS[k].name}${l ? ' · Nv ' + l : ''}</b><small>${DM.TOWERS[k].d}</small>${l >= 5 ? '<em>MAX</em>' : can ? `<button class="btn small ${DM.canPay(c) ? 'gold' : 'grey'}" data-a="dtower" data-v="${k}">${l ? 'Améliorer' : 'Construire'}</button><small class="cst">${DM.costTxt(c)}</small>` : ''}</div>`; }).join('')}</div>`;
    }
    body = `<div class="dwrap">${map}<div class="ddet">${det}</div></div>`;
  } else if (tab === 'guilde') {
    const cost = 5000 * Math.pow(3, D.lts.length);
    body = `<p class="hint">Tes lieutenants gouvernent tes quartiers. Épargne les capitaines vaincus pour les recruter, ou engage des mercenaires. Surveille leur loyauté : un lieutenant négligé peut te trahir.</p>` +
      (D.lts.length ? D.lts.map(l => `<div class="qr"><img class="lp" src="${portrait(l.model, false, [l.model === 'Rogue_Hooded' ? 'Rogue_' : l.model + '_'])}"><div><b>${l.name}</b><small>${DM.TRAITS[l.trait].n} — ${DM.TRAITS[l.trait].d}</small><div class="bar"><i style="width:${l.loy}%;background:${l.loy < 25 ? '#ff3355' : '#c26bff'}"></i></div><small>Loyauté ${Math.round(l.loy)} · ${l.gov ? 'Gouverne ' + DM.DISTRICTS.find(d => d.id === l.gov).name : 'Sans affectation'}</small></div></div>`).join('') : '<p class="empty">Ta guilde est vide.</p>') +
      `<div class="foot center"><button class="btn gold" data-a="recruit">Engager un mercenaire · ${fmt(cost)} ${svg('gold', 'ii')}</button></div>`;
  } else {
    body = Object.entries(DM.FACTIONS).filter(([k]) => k !== 'joueur').map(([k, f]) => { const a = D.att[k]; const own = DM.owned().filter(d => d.fac === k).length; const tot = DM.DISTRICTS.filter(d => d.fac === k).length;
      return `<div class="qr"><div><b style="color:${f.col}">${f.name}</b><small>${f.desc}</small><div class="att"><i style="left:${(a + 100) / 2}%"></i></div><small>${a <= -40 ? '⚠ Hostile — risque d’ultimatum' : a < 0 ? 'Méfiante' : a < 40 ? 'Neutre' : 'Amicale'} (${a}) · Quartiers pris : ${own}/${tot}</small></div><button class="btn blue" data-a="gift" data-v="${k}">Présent (60 Bois, 60 Ombracier)</button></div>`; }).join('');
  }
  return frame('Domaine', '#c26bff', head + body, true);
};

/* ---------- dialogues à choix ---------- */
UI.openDialogue = () => {
  const D = DM.dom(); if ($('dlg')) return;
  let ev = D.pending.shift(); let dl = null;
  while (ev && !(dl = DM.dialogue(ev, domainApi))) ev = D.pending.shift();
  if (!dl) return;
  close();
  const F = DM.FACTIONS[dl.fac] || DM.FACTIONS.joueur;
  const el = h('div', '', `<div class="dbox" style="--c:${F.col}"><img src="${portrait(dl.model, false, [dl.model === 'Rogue_Hooded' ? 'Rogue_' : dl.model + '_'])}"><div class="dtx"><b>${dl.who}</b><small>${F.name}</small><p></p><div class="dch"></div></div></div>`);
  el.id = 'dlg'; document.body.appendChild(el); SFX.play('select', 0.5);
  const p = el.querySelector('p'), ch = el.querySelector('.dch'); let i = 0; const txt = dl.text;
  const typer = setInterval(() => { i += 2; p.textContent = txt.slice(0, i); if (i >= txt.length) { clearInterval(typer); showChoices(); } }, 16);
  el.onclick = e => { if (i < txt.length) { i = txt.length; p.textContent = txt; clearInterval(typer); showChoices(); } };
  function showChoices() {
    if (ch.children.length) return;
    dl.choices.forEach(c => { const ok = !c.req || c.req(); const b = h('button', 'btn ' + (ok ? 'purple' : 'grey'), c.t + (c.reqTxt ? ` <small>[${c.reqTxt}]</small>` : '')); if (!ok) b.disabled = true;
      b.onclick = ev2 => { ev2.stopPropagation(); SFX.play('click', 0.5); const res = c.eff(); save();
        if (res == null) { el.remove(); return; }
        ch.innerHTML = ''; p.innerHTML = `<em>${res}</em>`; const nx = h('button', 'btn gold', D.pending.length ? 'Suivant' : 'Fermer'); nx.onclick = e3 => { e3.stopPropagation(); el.remove(); if (D.pending.length) setTimeout(UI.openDialogue, 150); }; ch.appendChild(nx); };
      ch.appendChild(b); });
  }
};

/* ---------- bulles de dialogue des PNJ ---------- */
const says = [];
UI.say = (pos, t) => { const d = h('div', 'say', t); $('says').appendChild(d); says.push({ el: d, pos, t: 3 }); };
function updSays(dt) { for (let i = says.length - 1; i >= 0; i--) { const s = says[i]; s.t -= dt; if (s.t <= 0) { s.el.remove(); says.splice(i, 1); continue; } toScreen({ x: s.pos.x, y: s.pos.y + 2.6, z: s.pos.z }, sp); s.el.style.display = sp.vis ? 'block' : 'none'; s.el.style.transform = `translate(${sp.x}px,${sp.y}px) translate(-50%,-100%)`; s.el.style.opacity = Math.min(1, s.t * 2); } }

/* ---------- mise à jour par image ---------- */
let slow = 0; const mm = { ctx: null };
UI.update = dt => {
  // textes flottants
  for (const d of dmgPool) { if (d.t <= 0) continue; d.t -= dt; if (d.t <= 0) { d.el.style.display = 'none'; continue; } d.p.y += dt * 1.6; toScreen(d.p, sp); const k = d.t / d.max; d.el.style.transform = `translate(${sp.x}px,${sp.y}px) translate(-50%,-50%) scale(${0.7 + Math.min(1, (1 - k) * 8) * 0.5})`; d.el.style.opacity = Math.min(1, k * 2.5); }
  // étiquettes
  for (const e of G.enemies) {
    if (!e.lab) continue; const d = e.pos.distanceTo(G.P.pos);
    if (d > 30 || e.dead) { e.lab.style.display = 'none'; continue; }
    toScreen({ x: e.pos.x, y: e.pos.y + 2.2 * e.scale + 0.3, z: e.pos.z }, sp); if (!sp.vis) { e.lab.style.display = 'none'; continue; }
    e.lab.style.display = 'block'; e.lab.style.transform = `translate(${sp.x}px,${sp.y}px) translate(-50%,-100%)`; e.labBar.style.width = (e.hp / e.max * 100) + '%';
    e.lab.classList.toggle('tgt', e === G.P.target);
  }
  if (banT > 0) { banT -= dt; if (banT <= 0) $('banner').classList.remove('show'); }
  if (ztT > 0) { ztT -= dt; if (ztT <= 0) $('zt').classList.remove('show'); }
  // compétences
  cdEl('kStrike', G.cds.strike, 3.5); cdEl('kDash', G.cds.dash, 5);
  $('ultp').style.strokeDashoffset = 106.8 * (1 - G.ult / 100); $('kUlt').classList.toggle('ready', G.ult >= 100);
  const corpses = G.enemies.filter(e => e.dead && e.tries > 0 && e.pos.distanceTo(G.P.pos) < 9).length;
  $('ariseN').textContent = corpses ? corpses : ''; $('kArise').classList.toggle('ready', corpses > 0);
  $('tAuto').classList.toggle('on', S.autoFarm); $('tArise').classList.toggle('on', S.autoArise); $('tHarv').classList.toggle('on', S.harvest);
  const pend = DM.dom().pending.length; $('msg').hidden = !pend || !!$('dlg') || G.mode === 'assault' || G.mode === 'dungeon' || G.mode === 'siege'; $('msg').lastElementChild.textContent = pend;
  updSays(dt);
  const st = stats();
  $('hpb').firstElementChild.style.width = (G.P.hp / st.hpMax * 100) + '%'; $('xpb').firstElementChild.style.width = (S.xp / xpNeed(S.lvl) * 100) + '%';
  slow -= dt; if (slow > 0) return; slow = 0.25;
  $('hpb').lastElementChild.textContent = `${fmt(G.P.hp)} / ${fmt(st.hpMax)}`;
  $('xpb').lastElementChild.textContent = `Niveau ${S.lvl}  ·  ${fmt(S.xp)} / ${fmt(xpNeed(S.lvl))}`;
  $('plvl').textContent = S.lvl; $('ppow').innerHTML = `Puissance <b>${fmt(power())}</b> · <em>${DM.titleName()}</em>`;
  const zf = G.zone >= 0 ? G.zone : 0;
  $('cur').innerHTML = `<span>${svg('gold', 'ci')}<b>${fmt(S.gold)}</b></span><span>${svg('gem', 'ci')}<b>${fmt(S.gems)}</b></span><span>${svg('rune', 'ci')}<b>${fmt(S.runes)}</b></span><span>${svg('key', 'ci')}<b>${S.keys}</b></span><span style="color:${ZONES[zf].fragCol}">${svg('frag', 'ci')}<b>${fmt(S.frags[zf])}</b></span>` + DM.RES.map(r => `<span>${svg(r.ico, 'ci')}<b>${fmt(DM.dom().res[r.id])}</b></span>`).join('');
  const eqN = S.shadows.filter(s => s.eq).length;
  $('army').innerHTML = `<b>Armée</b> ${eqN}/${slotsMax()} <span>·</span> <b>${fmt(G.armyDps || 0)}</b>/s${G.frenzy > 0 ? ' <em>×3</em>' : ''}`;
  $('buffs').innerHTML = `<div style="color:#4ade80">Chance d'Éveil +${fmt(st.eveil * 100)}%</div><div style="color:#c26bff">Dégâts d'ombre ×${fmt(st.ombre)}</div><div style="color:#ff4d6d">Dégâts d'arme ×${fmt(st.lame)}</div><div style="color:#ffcc33">Butin d'or +${fmt((st.gold - 1) * 100)}%</div><div style="color:#7dd3fc">Or/s ${fmt(G.goldRate)}</div>`;
  // HUD donjon / siège
  const dh = $('dhud');
  if (G.A) { dh.hidden = false; $('dht').firstElementChild.textContent = 'TEMPS'; $('dhk').textContent = (G.A.kind === 'conquete' ? 'Assaut · ' : G.A.kind === 'defense' ? 'Défense · ' : 'Révolte · ') + G.A.d.name; $('dhr').textContent = `Vague ${G.A.wave} / ${G.A.waves}`; $('dhb').style.width = (G.A.wave / G.A.waves * 100) + '%'; $('dht').lastElementChild.textContent = fmtTime(G.A.time); $('dht').classList.toggle('low', G.A.time < 30); $('dhl').textContent = `Ennemis restants ${G.A.left} / ${G.A.tot}`; }
  else if (G.D) { dh.hidden = false; $('dht').firstElementChild.textContent = 'TEMPS'; $('dhk').textContent = G.D.d.name; $('dhr').textContent = `Chambre ${G.D.room} / ${G.D.rooms}`; $('dhb').style.width = (G.D.room / G.D.rooms * 100) + '%'; $('dht').lastElementChild.textContent = fmtTime(G.D.time); $('dht').classList.toggle('low', G.D.time < 30); $('dhl').textContent = G.D.left ? `Ennemis restants ${G.D.left} / ${G.D.tot}` : 'Chambre nettoyée !'; }
  else if (G.SG) { dh.hidden = false; $('dhk').textContent = 'Siège sans fin'; $('dhr').textContent = `Vague ${G.SG.wave}`; $('dhb').style.width = Math.max(0, G.SG.crystal) + '%'; $('dht').lastElementChild.textContent = Math.max(0, G.SG.crystal) + '%'; $('dht').firstElementChild.textContent = 'CRISTAL'; $('dhl').textContent = `Record ${S.siegeBest} · Contrôle ${S.siegeCk}`; }
  else { dh.hidden = true; $('dht').firstElementChild.textContent = 'TEMPS'; }
  // brèche
  const b = $('breach');
  if (G.breach && G.mode === 'zone') { b.hidden = false; b.style.setProperty('--c', RANK_COL[G.breach.r]); b.innerHTML = `<b>BRÈCHE · RANG ${RANKS[G.breach.r]}</b><small>${fmtTime(G.breach.t)} · ${Math.round(G.breach.pos.distanceTo(G.P.pos))} m · toucher pour y aller</small>`; } else b.hidden = true;
  // pastilles
  checkQuests(); const qd = S.quests.some(q => !q.done && q.p >= questDef(q.id).goal);
  document.querySelector('.dk[data-id="quetes"] .dot').hidden = !qd;
  document.querySelector('.dk[data-id="autel"] .dot').hidden = S.gems < RELIC_COST;
  document.querySelector('.dk[data-id="donjons"] .dot').hidden = S.keys <= 0;
  document.querySelector('.dk[data-id="domaine"] .dot').hidden = !DM.dom().pending.length;
  drawMinimap();
  if (cur && ['donjons', 'ombres'].includes(cur.id) && Math.random() < 0.1) render();
};
function cdEl(id, v, max) { const el = $(id); el.firstElementChild.style.height = (v / max * 100) + '%'; el.classList.toggle('cool', v > 0); }
function drawMinimap() {
  const c = $('mm'), x = c.getContext('2d'), W = 150, R = 42, k = W / 2 / R;
  x.clearRect(0, 0, W, W); x.save(); x.beginPath(); x.arc(75, 75, 74, 0, 7); x.clip();
  x.fillStyle = 'rgba(12,8,30,.75)'; x.fillRect(0, 0, W, W);
  const P = G.P.pos, cs = Math.cos(E.yaw), sn = Math.sin(E.yaw);
  const to = (px, pz) => { const dx = px - P.x, dz = pz - P.z; return [75 + (dx * cs - dz * sn) * k, 75 + (dx * sn + dz * cs) * k]; };
  x.strokeStyle = 'rgba(160,130,255,.25)'; x.lineWidth = 1; for (let r = 10; r < 50; r += 10) { x.beginPath(); x.arc(75, 75, r * k, 0, 7); x.stroke(); }
  for (const p of (G.info?.portals || [])) { const [a, b] = to(p.x, p.z); x.fillStyle = p.zone >= 0 ? ZONES[p.zone].fragCol : '#8b5cf6'; x.beginPath(); x.arc(a, b, 5, 0, 7); x.fill(); }
  for (const s of (G.info?.stations || [])) { const [a, b] = to(s.x, s.z); x.fillStyle = s.col; x.fillRect(a - 3, b - 3, 6, 6); }
  if (G.breach) { const [a, b] = to(G.breach.pos.x, G.breach.pos.z); x.fillStyle = RANK_COL[G.breach.r]; x.beginPath(); x.arc(a, b, 6 + Math.sin(E.t * 6) * 2, 0, 7); x.fill(); }
  for (const e of G.enemies) { const [a, b] = to(e.pos.x, e.pos.z); x.fillStyle = e.dead ? '#8b5cf6' : e.boss ? '#ff3355' : e.elite ? '#ffcc33' : '#ff7a6a'; x.beginPath(); x.arc(a, b, e.boss ? 4.5 : 2.5, 0, 7); x.fill(); }
  for (const a of G.army) { const [p, q] = to(a.pos.x, a.pos.z); x.fillStyle = '#9ff3ff'; x.fillRect(p - 1.5, q - 1.5, 3, 3); }
  x.restore(); x.fillStyle = '#fff'; x.beginPath(); x.moveTo(75, 68); x.lineTo(70, 80); x.lineTo(80, 80); x.fill();
  x.strokeStyle = 'rgba(194,107,255,.8)'; x.lineWidth = 2; x.beginPath(); x.arc(75, 75, 73, 0, 7); x.stroke();
}
