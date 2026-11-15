/* UMBRA — interface : HUD façon Arise, panneaux (inventaire, ombres, mondes, autel, quêtes, succès, stats) */
import { E, toScreen } from './engine.js';
import { RAR, WEAPONS, RELICS, ACCS, SLOTS, WORLDS, FOES, STAGES, SUMMON, QUESTS, ACH, STAT_NAMES, SRANKS, SRANK_COL, W_MAXLV, W_MAXSTAR, R_MAXLV, A_MAXLV, SH_MAXLV,
  wUpCost, wPower, aUpCost, aMult, mission, xpNeed, armyMax, shadowPow, shUpCost, relicSlots, fmt, fmtTime } from './data.js';
import { S, save, wipe, bonus, dirty, heroDmg, heroHp, shDmg, equipped, autoEquipShadows, power, owned } from './state.js';
import { UIC, relicIcon, accIcon, shadowIcon } from './icons.js';
import { SFX } from './audio.js';

const $ = id => document.getElementById(id);
const h = (t, c, html) => { const e = document.createElement(t); if (c) e.className = c; if (html != null) e.innerHTML = html; return e; };
export const UI = {};
let G = null, GM = null; // module de jeu (injecté pour éviter l'import circulaire)
UI.bind = (g, gm) => { G = g; GM = gm; };

const HEX = [['inv', 'Inventaire', '#7c3aed'], ['ombres', 'Ombres', '#9f1239'], ['mondes', 'Mondes', '#0369a1'], ['autel', 'Autel', '#a21caf'], ['quetes', 'Quêtes', '#b45309'], ['succes', 'Succès', '#a16207'], ['stats', 'Stats', '#047857'], ['reglages', 'Réglages', '#334155']];
const wImg = (w, cls = 'ic') => `<img class="${cls}" src="assets/i/${w.id}.png" alt="">`;

/* ---------- construction du HUD ---------- */
UI.build = () => {
  $('hud').innerHTML = `
  <div id="labels"></div><div id="dmgs"></div><div id="flash"></div><div id="fade"></div>
  <div id="hex"></div>
  <div id="mis"><div id="misI">${UIC.skull()}</div><div id="misT"><b id="misN"></b><small id="misS"></small><div class="pb2"><i id="misB"></i></div></div></div>
  <div id="rc"><div id="dmgbox"></div><div id="buffs"></div><div id="wprop"></div></div>
  <div id="lucky"></div><div id="toasts"></div><div id="loot"></div>
  <div id="zt"><div id="ztn"></div><div id="zts"></div></div>
  <div id="banner"><b></b><small></small></div>
  <div id="hpbar"><i></i></div>
  <div id="joy"><div id="knob"></div></div>
  <div id="bot">
    <div id="barRow">
      <div class="money" id="cash"></div>
      <div id="acts">
        <div class="ac ia" id="aAuto"><div class="tg">ON</div>${UIC.auto()}<span>AUTO</span></div>
        <div class="ac ia" id="aWpn"><img id="aWpnI" src=""><span>ARME</span></div>
        <div class="ac m1 ia" id="aPunch">${UIC.fist()}<span>FRAPPE</span></div>
        <div class="ac big ia" id="aArise">${UIC.arise()}<span>S'ÉLEVER</span><div class="ct" id="soulN" hidden>0</div></div>
        <div class="ac ia" id="aAA"><div class="tg">OFF</div>${UIC.arise()}<span>AUTO-ÉVEIL</span></div>
        <div class="ac ia" id="aArmy">${UIC.army()}<span id="armyN">0/0</span></div>
      </div>
      <div class="money" id="gems"></div>
    </div>
    <div id="lvbar"><i></i><span></span></div>
  </div>`;
  // grille hexagonale (2 colonnes en quinconce)
  const hx = $('hex');
  HEX.forEach(([id, label, col], i) => {
    const c = i % 2, r = Math.floor(i / 2); const b = h('div', 'hx ia');
    b.style.left = (c * 62) + 'px'; b.style.top = (r * 56 + c * 28) + 'px'; b.style.setProperty('--hc', col); b.dataset.id = id;
    b.innerHTML = `<div class="o"></div><div class="i">${UIC[id]()}<span>${label}</span></div>`;
    b.onclick = () => { SFX.play('click', 0.4); b.querySelector('.dot')?.remove(); UI.open(id); };
    hx.appendChild(b);
  });
  hx.style.height = (Math.ceil(HEX.length / 2) * 56 + 40) + 'px';
  $('aAuto').onclick = () => { S.auto = !S.auto; SFX.play('click', 0.4); syncToggles(); };
  $('aAA').onclick = () => { S.autoArise = !S.autoArise; SFX.play('click', 0.4); syncToggles(); };
  $('aPunch').onpointerdown = () => GM.punch();
  $('aArise').onclick = () => GM.arise();
  $('aWpn').onclick = () => UI.open('inv', 'armes');
  $('aArmy').onclick = () => UI.open('ombres');
  syncToggles(); setupInput();
};
function syncToggles() {
  $('aAuto').classList.toggle('on', S.auto); $('aAuto').querySelector('.tg').textContent = S.auto ? 'ON' : 'OFF';
  $('aAA').classList.toggle('on', S.autoArise); $('aAA').querySelector('.tg').textContent = S.autoArise ? 'ON' : 'OFF';
}
UI.dot = id => { const b = document.querySelector(`.hx[data-id="${id}"]`); if (b && !b.querySelector('.dot') && !$('panel')) b.appendChild(h('div', 'dot')); };

/* ---------- entrées : joystick à gauche, caméra à droite ---------- */
function setupInput() {
  const joy = $('joy'), knob = $('knob'); let jid = null, jx = 0, jy = 0, cid = null, cx = 0, cy = 0;
  const cv = $('c');
  cv.addEventListener('pointerdown', e => {
    if (e.clientX < innerWidth * 0.45 && jid === null) { jid = e.pointerId; jx = e.clientX; jy = e.clientY; joy.style.left = (jx - 60) + 'px'; joy.style.top = (jy - 60) + 'px'; joy.classList.add('on'); }
    else if (cid === null) { cid = e.pointerId; cx = e.clientX; cy = e.clientY; }
  });
  addEventListener('pointermove', e => {
    if (e.pointerId === jid) { let dx = e.clientX - jx, dy = e.clientY - jy; const d = Math.hypot(dx, dy), m = 50; if (d > m) { dx *= m / d; dy *= m / d; } knob.style.transform = `translate(${dx}px,${dy}px)`; G.joy.x = dx / m; G.joy.y = dy / m; }
    else if (e.pointerId === cid) { E.yaw -= (e.clientX - cx) * 0.008; E.pitch = Math.max(0.45, Math.min(1.25, E.pitch + (e.clientY - cy) * 0.004)); cx = e.clientX; cy = e.clientY; }
  });
  const up = e => { if (e.pointerId === jid) { jid = null; G.joy.x = G.joy.y = 0; knob.style.transform = ''; joy.classList.remove('on'); } if (e.pointerId === cid) cid = null; };
  addEventListener('pointerup', up); addEventListener('pointercancel', up);
  cv.addEventListener('wheel', e => { E.dist = Math.max(10, Math.min(30, E.dist + e.deltaY * 0.02)); });
}

/* ---------- mise à jour du HUD ---------- */
let hudT = 0; const labPool = [], dns = [];
UI.update = dt => {
  // nombres de dégâts
  for (let i = dns.length - 1; i >= 0; i--) {
    const d = dns[i]; d.t += dt; const p = toScreen(d.p); const k = d.t / d.life;
    if (k >= 1 || !p.vis) { d.el.remove(); dns.splice(i, 1); continue; }
    d.el.style.transform = `translate(${p.x + d.ox}px,${p.y - d.t * 60}px) translate(-50%,-50%) scale(${k < 0.15 ? 0.6 + k * 4 : 1})`; d.el.style.opacity = k > 0.7 ? (1 - k) / 0.3 : 1;
  }
  // étiquettes des ennemis
  let n = 0; const P = G.P;
  for (const f of G.foes) {
    if (f.dead || n >= 18) continue; if (f.kind < 2 && f.pos.distanceTo(P.pos) > 28) continue;
    const p = toScreen({ x: f.pos.x, y: f.pos.y + (f.kind === 2 ? 6.2 : f.kind === 1 ? 3.6 : 2.6), z: f.pos.z }); if (!p.vis) continue;
    let l = labPool[n]; if (!l) { l = labPool[n] = h('div', 'lab', '<div class="ln"></div><div class="lb"><i></i></div>'); $('labels').appendChild(l); }
    l.hidden = false; l.className = 'lab k' + f.kind; if (l._f !== f) { l._f = f; l.firstChild.textContent = f.kind ? f.n : ''; }
    l.style.transform = `translate(${p.x}px,${p.y}px) translate(-50%,-100%)`; l.lastChild.firstChild.style.width = (f.hp / f.max * 100) + '%'; n++;
  }
  for (let i = n; i < labPool.length; i++) labPool[i].hidden = true;
  hudT -= dt; if (hudT > 0) return; hudT = 0.2;
  const b = bonus(), W = WORLDS[S.world];
  $('cash').innerHTML = `${UIC.cash()}${fmt(S.cash)}`; $('gems').innerHTML = `${fmt(S.gems)}${UIC.gem()}`;
  const xn = xpNeed(S.lvl); $('lvbar').firstChild.style.width = (S.xp / xn * 100) + '%'; $('lvbar').lastChild.textContent = `Niveau : ${S.lvl}  ·  ${(S.xp / xn * 100).toFixed(1)} %  ·  Puissance ${fmt(power())}`;
  const hp = Math.max(0, P.hp / heroHp()); $('hpbar').firstChild.style.width = hp * 100 + '%'; $('hpbar').classList.toggle('low', hp < 0.3);
  $('aWpnI').src = `assets/i/${S.wEq}.png`;
  const ns = G.souls.filter(s => s.pos.distanceTo(P.pos) < 16).length; $('soulN').hidden = !ns; $('soulN').textContent = ns; $('aArise').classList.toggle('ready', ns > 0);
  $('armyN').textContent = `${equipped().length}/${armyMax(S.lvl)}`;
  // mission / boss
  const st = Math.min(S.stage[S.world], STAGES); const mis = $('mis');
  if (G.boss) {
    mis.classList.add('boss'); $('misN').textContent = `BOSS : ${G.boss.n}`; $('misS').textContent = `${fmt(G.boss.hp)} / ${fmt(G.boss.max)} PV`; $('misB').style.width = (G.boss.hp / G.boss.max * 100) + '%';
  } else {
    mis.classList.remove('boss'); const m = mission(S.world, Math.min(st, STAGES - 1));
    $('misN').textContent = `${W.n.toUpperCase()} · PALIER ${Math.min(st + 1, STAGES)}/${STAGES}${st >= STAGES ? ' ✓' : ''}`;
    const k = Math.min(S.prog.kills, m.kills), br = Math.min(S.prog.brutes, m.brutes);
    $('misS').textContent = G.bossPortal ? 'Le boss arrive…' : `Ennemis ${k}/${m.kills} · Brutes ${br}/${m.brutes} → boss`;
    $('misB').style.width = ((k + br * 5) / (m.kills + m.brutes * 5) * 100) + '%';
  }
  $('dmgbox').innerHTML = `Dégâts : <b>${fmt(heroDmg())}</b><br>DPS : <b style="color:#ffcc33">${fmt(G.dps)}</b>`;
  const bl = [['Chance d\'Éveil', b.arise + (W.prop.arise ? (W.prop.arise - 1) * 100 : 0), '#4ade80'], ['Butin rare', b.luck, '#38bdf8'], ['Dégâts ombres', b.sdmg, '#c26bff'], ['Dégâts arme', b.wdmg, '#ff3b5c'], ['Argent', b.cash + (W.prop.cash ? (W.prop.cash - 1) * 100 : 0), '#ffcc33'], ['Gemmes', b.gems, '#7dd3fc'], ['Tous dégâts', b.all, '#ff7aa8']];
  $('buffs').innerHTML = bl.filter(x => x[1] > 0).map(([n, v, c]) => `<div style="color:${c}">${n} : +${fmt(v)} %</div>`).join('');
  $('wprop').textContent = W.propTxt; $('wprop').style.borderColor = W.col; $('wprop').style.color = W.col;
  // pastilles
  if (questReady()) UI.dot('quetes'); if (achReady()) UI.dot('succes');
};

/* ---------- retours visuels ---------- */
UI.dn = (pos, v, cls) => {
  if (dns.length > 60) { dns[0].el.remove(); dns.shift(); }
  const el = h('div', 'dn ' + cls, typeof v === 'number' ? fmt(v) : v); $('dmgs').appendChild(el);
  dns.push({ el, p: { x: pos.x, y: pos.y + 2.2, z: pos.z }, t: 0, life: cls === 'arise' ? 1.4 : 0.9, ox: (Math.random() - 0.5) * 40 });
};
UI.toast = (t, c = '') => { const e = h('div', 'toast ' + c, t); $('toasts').appendChild(e); setTimeout(() => e.classList.add('out'), 2600); setTimeout(() => e.remove(), 3200); while ($('toasts').children.length > 3) $('toasts').firstChild.remove(); };
let banT = 0;
UI.banner = (t, s, c = '#a855f7') => { const b = $('banner'); b.querySelector('b').textContent = t; b.querySelector('small').textContent = s || ''; b.style.setProperty('--c', c); b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); clearTimeout(banT); banT = setTimeout(() => b.classList.remove('show'), 2400); };
UI.zoneTitle = (n, s, c) => { $('ztn').textContent = n; $('zts').textContent = s; $('zt').style.setProperty('--c', c); $('zt').classList.add('show'); $('fade').classList.remove('go'); void $('fade').offsetWidth; $('fade').classList.add('go'); setTimeout(() => $('zt').classList.remove('show'), 3200); };
UI.hurt = () => { const f = $('flash'); f.classList.remove('hit'); void f.offsetWidth; f.classList.add('hit'); };
UI.lucky = (name, ch, col) => {
  const e = h('div', 'lk', `LUCKY DROP ! <em>${name}</em> (${(ch * 100).toFixed(ch < 0.001 ? 3 : 2)} %)`); e.style.setProperty('--c', col); $('lucky').appendChild(e);
  while ($('lucky').children.length > 3) $('lucky').firstChild.remove(); setTimeout(() => e.classList.add('out'), 4000); setTimeout(() => e.remove(), 4600);
};
let cashCard = null, cashSum = 0, cashT = 0;
UI.loot = items => {
  const box = $('loot');
  const add = (html, rc, key) => { const e = h('div', 'lc', html); e.style.setProperty('--rc', rc); box.appendChild(e); while (box.children.length > 6) box.firstChild.remove(); setTimeout(() => e.classList.add('out'), 2200); setTimeout(() => { e.remove(); if (e === cashCard) cashCard = null; }, 2700); return e; };
  for (const [k, v] of items) {
    if (k === 'cash') {
      if (cashCard && performance.now() - cashT < 1500) { cashSum += v; cashCard.querySelector('b').textContent = '+' + fmt(cashSum); }
      else { cashSum = v; cashCard = add(`${UIC.cash()}<b>+${fmt(v)}</b><small>Argent</small>`, '#4ade80'); }
      cashT = performance.now();
    } else if (k === 'gems') add(`${UIC.gem()}<b>+${fmt(v)}</b><small>Gemmes</small>`, '#38bdf8');
    else if (k === 'w') { const w = WEAPONS.find(x => x.id === v); add(`${wImg(w, '')}<b style="color:${RAR[w.r].c}">${RAR[w.r].k}</b><small>${w.n}</small>`, RAR[w.r].c); SFX.play('ok', 0.5); }
    else if (k === 'rel') { const r = RELICS.find(x => x.id === v); add(`${relicIcon(r, '')}<b style="color:${RAR[r.r].c}">${RAR[r.r].k}</b><small>${r.n}</small>`, RAR[r.r].c); SFX.play('ok', 0.5); }
    else if (k === 'acc') { const a = ACCS.find(x => x.id === v); add(`${accIcon(a, '')}<b style="color:${RAR[a.r].c}">${RAR[a.r].k}</b><small>${a.n}</small>`, RAR[a.r].c); SFX.play('ok', 0.5); }
  }
};
const arcs = [];
UI.ariseCard = sh => {
  const c = SRANK_COL[sh.rk]; const F = FOES[sh.type];
  const e = h('div', 'arc', `${shadowIcon(F.model, c, '')}<div><small>ÉVEIL RÉUSSI</small><b><i style="background:${c}">${SRANKS[sh.rk]}</i>${F.n}</b><small style="letter-spacing:0">${sh.eq ? 'Rejoint ton armée' : 'Rangée (armée pleine)'}</small></div>`);
  e.style.setProperty('--c', c); document.body.appendChild(e); arcs.unshift(e); arcs.forEach((a, i) => a.style.setProperty('--i', i));
  setTimeout(() => e.classList.add('out'), 2300); setTimeout(() => { e.remove(); arcs.splice(arcs.indexOf(e), 1); }, 2800);
  while (arcs.length > 4) { arcs.pop().remove(); }
};

/* ---------- cartes de collection ---------- */
function card({ rar, icon, name, pw, lv, stars, eq, lock, sel, extra = '' }) {
  const R = RAR[rar];
  return `<div class="card${R.rainbow ? ' rb' : ''}${lock ? ' lock' : ''}${sel ? ' sel' : ''}" style="--rc:${R.c}"><div class="in">${icon}${lock ? '<div class="q">?</div>' : ''}
    ${stars != null && !lock ? `<div class="stars">${'★'.repeat(stars)}${'☆'.repeat(W_MAXSTAR - stars)}</div>` : ''}
    <div class="nm">${name}</div>${pw ? `<div class="pw2">${pw}</div>` : '<div class="pw2">&nbsp;</div>'}</div>
    <div class="rk">${R.k}</div>${eq ? '<div class="ck">✓</div>' : ''}${lv != null && !lock ? `<div class="lv">Nv.${lv}</div>` : ''}${extra}</div>`;
}
function srcOfWeapon(id) { if (id === 'w10') return 'Citadelle Abyssale — boss (très rare)'; const ws = WORLDS.filter(w => w.drops.includes(id)).map(w => w.n); return ws.join(' · '); }

/* ---------- panneaux ---------- */
let cur = null, tab = null, selId = null;
UI.open = (id, t) => {
  UI.close(); cur = id; tab = t || tab; selId = null;
  const p = h('div', 'panel'); p.id = 'panel'; p.onclick = e => { if (e.target === p) UI.close(); };
  document.body.appendChild(p); render();
};
UI.close = () => { $('panel')?.remove(); cur = null; save(); };
function frame(title, icon, sub, body, tabs) {
  const p = $('panel'); if (!p) return;
  p.innerHTML = `<div class="pw"><div class="pin"><div class="ph">${icon}<h2>${title}</h2><span class="sub">${sub || ''}</span><div class="x" id="px">✕</div></div><div class="pbody">${body}</div></div>${tabs ? `<div class="side">${tabs}</div>` : ''}</div>`;
  $('px').onclick = () => { SFX.play('click', 0.3); UI.close(); };
}
function rerender() { if (cur) render(); }
UI.refresh = rerender;
function render() {
  ({ inv: renderInv, ombres: renderShadows, mondes: renderWorlds, autel: renderAltar, quetes: renderQuests, succes: renderAch, stats: renderStats, reglages: renderSettings })[cur]();
}
const on = (sel, fn) => document.querySelectorAll(sel).forEach(e => e.onclick = ev => { SFX.play('select', 0.35); fn(e, ev); });
const kv = (k, v, c = '') => `<div class="kv"><span>${k}</span><b class="${c}">${v}</b></div>`;

/* --- inventaire : armes / reliques / accessoires --- */
function renderInv() {
  if (!['armes', 'reliques', 'acc'].includes(tab)) tab = 'armes';
  const tabs = [['armes', 'ARMES', UIC.sword()], ['reliques', 'RELIQUES', relicIcon(RELICS[6], '')], ['acc', 'ACCESSOIRES', accIcon(ACCS[2], '')]].map(([k, l, ic]) => `<div class="stab${tab === k ? ' on' : ''}" data-t="${k}">${ic}<span>${l}</span></div>`).join('');
  let body = '', sub = '';
  if (tab === 'armes') {
    const list = WEAPONS; selId = selId && list.find(x => x.id === selId) ? selId : S.wEq;
    sub = `${Object.keys(S.w).length}/10 armes`;
    body = `<div class="grid scroll" style="flex:1">${list.map(w => { const it = S.w[w.id]; return `<div data-id="${w.id}" class="ci">${card({ rar: w.r, icon: wImg(w), name: w.n, pw: it ? '⚔ ' + fmt(wPower(w, it)) : '', lv: it?.lv, stars: it ? it.st : null, eq: S.wEq === w.id, lock: !it, sel: selId === w.id })}</div>`; }).join('')}</div>${detWeapon(selId)}`;
  } else if (tab === 'reliques') {
    selId = selId || (S.relEq[0] || 'r1'); const slots = relicSlots(S.lvl);
    sub = `Emplacements ${S.relEq.length}/${slots} · ${Object.keys(S.rel).length}/10 reliques`;
    body = `<div class="grid scroll" style="flex:1">${RELICS.map(r => { const it = S.rel[r.id]; return `<div data-id="${r.id}" class="ci">${card({ rar: r.r, icon: relicIcon(r), name: r.n, pw: it ? `+${fmt(r.v * (1 + it.lv))} %` : '', lv: it?.lv, eq: S.relEq.includes(r.id), lock: !it, sel: selId === r.id })}</div>`; }).join('')}</div>${detRelic(selId)}`;
  } else {
    selId = selId || Object.values(S.accEq).find(Boolean) || 'a1';
    sub = `${Object.keys(S.acc).length}/10 accessoires`;
    const pos = { tete: [47, 14], cape: [6, 96], plastron: [88, 96], bottes: [47, 190] };
    const man = `<div class="man"><svg class="body" viewBox="0 0 40 100"><circle cx="20" cy="12" r="9" fill="#1e293b"/><path d="M8 24h24l3 34h-6l-1 40h-8l-1-30-1 30h-8l-1-40H5z" fill="#1e293b"/></svg>${SLOTS.map(([k, l]) => { const id = S.accEq[k]; const a = ACCS.find(x => x.id === id); return `<div class="slot${a ? '' : ' emp'}" style="left:${pos[k][0]}px;top:${pos[k][1]}px" data-slot="${k}"><div class="lab2">${l}</div>${a ? card({ rar: a.r, icon: accIcon(a), name: '', lv: S.acc[id].lv }) : ''}</div>`; }).join('')}</div>`;
    body = `${man}<div class="grid scroll" style="flex:1">${ACCS.map(a => { const it = S.acc[a.id]; return `<div data-id="${a.id}" class="ci">${card({ rar: a.r, icon: accIcon(a), name: a.n, pw: SLOTS.find(s => s[0] === a.slot)[1], lv: it?.lv, eq: S.accEq[a.slot] === a.id, lock: !it, sel: selId === a.id })}</div>`; }).join('')}</div>${detAcc(selId)}`;
  }
  frame('Inventaire', UIC.inv(), sub, body, tabs);
  on('.stab', e => { tab = e.dataset.t; selId = null; render(); });
  on('.ci', e => { selId = e.dataset.id; render(); });
  on('.slot', e => { const id = S.accEq[e.dataset.slot]; if (id) { selId = id; render(); } });
  on('[data-act]', e => actInv(e.dataset.act));
}
function detWeapon(id) {
  const w = WEAPONS.find(x => x.id === id), it = S.w[id], R = RAR[w.r];
  let h2 = `<div class="det scroll"><div class="big">${card({ rar: w.r, icon: wImg(w), name: '', lv: it?.lv, stars: it ? it.st : null, lock: !it })}</div><h3>${w.n}</h3><div class="rar" style="color:${R.c}">${R.k} — ${R.n}</div><p>${w.d}</p>`;
  if (!it) return h2 + kv('Dégâts de base', fmt(w.dmg), 'red') + `<p>Où le trouver : <b>${srcOfWeapon(id)}</b></p></div>`;
  const cost = wUpCost(w, it.lv);
  h2 += kv('Puissance', '⚔ ' + fmt(wPower(w, it)), 'red') + kv('Niveau', `${it.lv}/${W_MAXLV}`) + kv('Étoiles (doublons)', `${it.st}/${W_MAXSTAR}`, 'cy') + kv('Niveau suivant', it.lv < W_MAXLV ? '⚔ ' + fmt(wPower(w, { lv: it.lv + 1, st: it.st })) : 'MAX', 'red');
  h2 += `<div class="row"><button class="btn y" data-act="wup" ${it.lv >= W_MAXLV || S.cash < cost ? 'disabled' : ''}>${UIC.cash()} ${fmt(cost)}</button><button class="btn y" data-act="wup10" ${it.lv >= W_MAXLV || S.cash < cost ? 'disabled' : ''}>×10</button></div>`;
  h2 += `<button class="btn g" data-act="weq" ${S.wEq === id ? 'disabled' : ''}>${S.wEq === id ? 'ÉQUIPÉE' : 'ÉQUIPER'}</button><p style="font-size:10.5px">Doublon trouvé = +1 étoile (+35 % de puissance)</p></div>`;
  return h2;
}
function detRelic(id) {
  const r = RELICS.find(x => x.id === id), it = S.rel[id], R = RAR[r.r]; const eq = S.relEq.includes(id);
  let s = `<div class="det scroll"><div class="big">${card({ rar: r.r, icon: relicIcon(r), name: '', lv: it?.lv, lock: !it })}</div><h3>${r.n}</h3><div class="rar" style="color:${R.c}">${R.k} — ${R.n}</div><p>${r.d}</p>`;
  if (!it) return s + kv(STAT_NAMES[r.stat], `+${r.v} % par niveau`) + '<p>Obtenue à l\'<b>Autel</b> ou sur les brutes et les boss.</p></div>';
  s += kv(STAT_NAMES[r.stat], `+${fmt(r.v * (1 + it.lv))} %`) + kv('Niveau', `${it.lv}/${R_MAXLV}`) + kv('Prochain niveau', it.lv < R_MAXLV ? `+${fmt(r.v * (2 + it.lv))} %` : 'MAX', 'cy');
  s += `<button class="btn ${eq ? 'r' : 'g'}" data-act="req">${eq ? 'RETIRER' : 'ÉQUIPER'}</button><p style="font-size:10.5px">Chaque doublon fait monter la relique d'un niveau.</p></div>`;
  return s;
}
function detAcc(id) {
  const a = ACCS.find(x => x.id === id), it = S.acc[id], R = RAR[a.r]; const eq = S.accEq[a.slot] === id;
  let s = `<div class="det scroll"><div class="big">${card({ rar: a.r, icon: accIcon(a), name: '', lv: it?.lv, lock: !it })}</div><h3>${a.n}</h3><div class="rar" style="color:${R.c}">${R.k} — ${R.n} · ${SLOTS.find(x => x[0] === a.slot)[1]}</div>`;
  const m = it ? aMult(it.lv) : 1;
  for (const k in a.st) s += kv(STAT_NAMES[k], `+${fmt(a.st[k] * m)} %`);
  if (!it) return s + '<p>Tombe sur les brutes et les boss (plus rare dans les premiers mondes).</p></div>';
  const cost = aUpCost(a, it.lv);
  s += kv('Niveau', `${it.lv}/${A_MAXLV}`);
  s += `<button class="btn y" data-act="aup" ${it.lv >= A_MAXLV || S.cash < cost ? 'disabled' : ''}>Améliorer ${UIC.cash()} ${fmt(cost)}</button><button class="btn ${eq ? 'r' : 'g'}" data-act="aeq">${eq ? 'RETIRER' : 'ÉQUIPER'}</button></div>`;
  return s;
}
function actInv(a) {
  if (a === 'wup' || a === 'wup10') {
    const w = WEAPONS.find(x => x.id === selId), it = S.w[selId]; let n = a === 'wup' ? 1 : 10, done = 0;
    while (n-- > 0 && it.lv < W_MAXLV && S.cash >= wUpCost(w, it.lv)) { S.cash -= wUpCost(w, it.lv); it.lv++; done++; GM.bumpUpgrade(); }
    if (done) { SFX.play('coins', 0.5); UI.toast(`${w.n} → niveau ${it.lv}`, 'gold'); }
  } else if (a === 'weq') { S.wEq = selId; GM.refreshWeapon(); SFX.play('ok', 0.5); }
  else if (a === 'req') {
    const i = S.relEq.indexOf(selId);
    if (i >= 0) S.relEq.splice(i, 1); else if (S.relEq.length < relicSlots(S.lvl)) S.relEq.push(selId); else { UI.toast(`Emplacements pleins (${relicSlots(S.lvl)}) — retire une relique. +1 emplacement au niveau 20 et 40`, 'bad'); return; }
  } else if (a === 'aup') { const ac = ACCS.find(x => x.id === selId), it = S.acc[selId]; const c = aUpCost(ac, it.lv); if (S.cash >= c) { S.cash -= c; it.lv++; GM.bumpUpgrade(); SFX.play('coins', 0.5); } }
  else if (a === 'aeq') { const ac = ACCS.find(x => x.id === selId); S.accEq[ac.slot] = S.accEq[ac.slot] === selId ? null : selId; }
  dirty(); render();
}

/* --- ombres --- */
let shSort = 'pow';
function renderShadows() {
  const list = [...S.sh].sort((a, b) => shSort === 'pow' ? (b.eq - a.eq) || (shDmg(b) - shDmg(a)) : b.rk - a.rk || shDmg(b) - shDmg(a));
  const sel = S.sh.find(s => s.id === selId) || list[0]; selId = sel?.id;
  const cards = list.map(s => { const F = FOES[s.type]; return `<div class="ci" data-id="${s.id}">${shCard(s, F, sel === s)}</div>`; }).join('') || '<div class="empty">Aucune ombre. Abats un ennemi puis touche S\'ÉLEVER pour l\'éveiller.</div>';
  const body = `<div style="flex:1;display:flex;flex-direction:column;min-width:0"><div class="tools"><span class="chip">Armée ${equipped().length}/${armyMax(S.lvl)}</span><span class="chip">Total ${S.sh.length}</span><button class="btn g" data-a="best">Équiper le meilleur</button><button class="btn r" data-a="sell">Vendre les rangs E-D rangés</button><button class="btn b" data-a="sort">Tri : ${shSort === 'pow' ? 'Puissance' : 'Rang'}</button></div><div class="grid scroll" style="flex:1">${cards}</div></div>${sel ? detShadow(sel) : ''}`;
  frame('Ombres', UIC.ombres(), 'Ton armée te suit et combat pour toi', body);
  on('.ci', e => { selId = +e.dataset.id; render(); });
  on('[data-a]', e => {
    const a = e.dataset.a;
    if (a === 'best') { autoEquipShadows(); GM.syncArmy(); SFX.play('ok', 0.5); }
    else if (a === 'sell') { let v = 0, n = 0; S.sh = S.sh.filter(s => { if (!s.eq && s.rk <= 1) { v += shUpCost(s) * 0.4; n++; return false; } return true; }); S.cash += v; if (n) UI.toast(`${n} ombres vendues : +${fmt(v)}`, 'gold'); }
    else if (a === 'sort') shSort = shSort === 'pow' ? 'rank' : 'pow';
    else if (a === 'eq') { if (sel.eq) sel.eq = false; else if (equipped().length < armyMax(S.lvl)) sel.eq = true; else { UI.toast('Armée pleine — monte de niveau pour plus d\'ombres', 'bad'); return; } GM.syncArmy(); }
    else if (a === 'up') { const c = shUpCost(sel); if (S.cash >= c && sel.lv < SH_MAXLV) { S.cash -= c; sel.lv++; GM.bumpUpgrade(); SFX.play('coins', 0.5); } }
    else if (a === 'del') { if (sel.eq) return; S.cash += shUpCost(sel) * 0.4; S.sh.splice(S.sh.indexOf(sel), 1); selId = null; GM.syncArmy(); }
    render();
  });
}
function shCard(s, F, sel) {
  const c = SRANK_COL[s.rk];
  return `<div class="card${sel ? ' sel' : ''}" style="--rc:${c}"><div class="in">${shadowIcon(F.model, c)}<div class="nm">${s.k === 2 ? '★ ' : ''}${F.n}</div><div class="pw2">⚔ ${fmt(shDmg(s))}</div></div><div class="rk" style="font-size:15px">${SRANKS[s.rk]}</div>${s.eq ? '<div class="ck">✓</div>' : ''}<div class="lv">Nv.${s.lv}</div></div>`;
}
function detShadow(s) {
  const F = FOES[s.type], c = SRANK_COL[s.rk], cost = shUpCost(s);
  return `<div class="det scroll"><div class="big">${shCard(s, F)}</div><h3>${F.n}</h3><div class="rar" style="color:${c}">Rang ${SRANKS[s.rk]} · ${['Normal', 'Brute', 'Boss'][s.k]}</div>
  ${kv('Dégâts', '⚔ ' + fmt(shDmg(s)), 'red')}${kv('Niveau', `${s.lv}/${SH_MAXLV}`)}${kv('Origine', WORLDS.find(w => tierIn(w, s.t))?.n || '—')}
  <button class="btn y" data-a="up" ${S.cash < cost || s.lv >= SH_MAXLV ? 'disabled' : ''}>Améliorer ${UIC.cash()} ${fmt(cost)}</button>
  <button class="btn ${s.eq ? 'r' : 'g'}" data-a="eq">${s.eq ? 'RETIRER DE L\'ARMÉE' : 'AJOUTER À L\'ARMÉE'}</button>
  <button class="btn k" data-a="del" ${s.eq ? 'disabled' : ''}>Vendre (+${fmt(cost * 0.4)})</button></div>`;
}
const tierIn = (w, t) => t >= w.base && t < w.base + STAGES;

/* --- mondes --- */
function renderWorlds() {
  const body = `<div class="wgrid scroll" style="flex:1">${WORLDS.map((w, i) => {
    const st = S.stage[i], lock = i > S.maxWorld, here = i === S.world, m = mission(i, Math.min(st, STAGES - 1));
    return `<div class="wc${lock ? ' lockd' : ''}${here ? ' here' : ''}" style="--c:${w.col}"><div class="num">#${i + 1}</div><b>${w.n}</b><small>${w.sub}</small>
      <div class="prop">✦ ${w.propTxt}</div><div class="mi">Palier ${Math.min(st + 1, STAGES)}/${STAGES}${st >= STAGES ? ' — CONQUIS ✓' : ''} · Mission : ${m.kills} ennemis + ${m.brutes} brutes → ${w.bossN}</div>
      <div class="pb2"><i style="width:${Math.min(st, STAGES) / STAGES * 100}%"></i></div>
      <div class="mi">Armes : ${w.drops.map(id => WEAPONS.find(x => x.id === id).n).join(', ')}</div>
      ${here ? '<button class="btn k" disabled>VOUS ÊTES ICI</button>' : lock ? `<button class="btn k" disabled>🔒 Conquiers ${WORLDS[i - 1].n}</button>` : `<button class="btn b" data-w="${i}">TÉLÉPORTER</button>`}</div>`;
  }).join('')}</div>`;
  frame('Mondes', UIC.mondes(), `${S.maxWorld + 1}/4 débloqués`, body);
  on('[data-w]', e => { UI.close(); GM.enterWorld(+e.dataset.w); });
}

/* --- autel d'invocation des reliques --- */
let lastPulls = [];
function renderAltar() {
  const rates = SUMMON.rates.map((r, i) => `<div class="rate" style="--rc:${RAR[i].c}"><b>${RAR[i].k}</b>${RAR[i].n}<br>${(r * 100).toFixed(r < 0.01 ? 1 : 0)} %</div>`).join('');
  const body = `<div class="scroll" style="flex:1"><p style="font-size:12px;color:#c7d2fe;margin-bottom:4px">Invoque des reliques avec tes gemmes. Un doublon fait monter la relique d'un niveau (max ${R_MAXLV}).</p><div class="rates">${rates}</div>
   <div style="display:flex;gap:8px;justify-content:center;margin:8px 0"><button class="btn p" data-n="1" ${S.gems < SUMMON.cost ? 'disabled' : ''}>Invoquer ×1 · ${SUMMON.cost} ${UIC.gem()}</button><button class="btn y" data-n="10" ${S.gems < SUMMON.cost10 ? 'disabled' : ''}>Invoquer ×10 · ${SUMMON.cost10} ${UIC.gem()}</button></div>
   <div class="pulls">${lastPulls.map((id, i) => { const r = RELICS.find(x => x.id === id); return `<div style="width:74px;animation:pop .45s ${i * 0.08}s backwards">${card({ rar: r.r, icon: relicIcon(r), name: r.n, lv: S.rel[id].lv })}</div>`; }).join('')}</div></div>`;
  frame('Autel des Reliques', UIC.autel(), `${fmt(S.gems)} gemmes`, body);
  on('[data-n]', e => {
    const n = +e.dataset.n, c = n === 10 ? SUMMON.cost10 : SUMMON.cost; if (S.gems < c) return; S.gems -= c; lastPulls = [];
    let best = 0; for (let i = 0; i < n; i++) { const r = GM.rollRelic(5); lastPulls.push(r.id); best = Math.max(best, r.r); }
    SFX.play(best >= 3 ? 'win' : 'power', 0.6); if (best >= 4) UI.lucky(RELICS.find(x => x.id === lastPulls.find(id => RELICS.find(q => q.id === id).r === best)).n, SUMMON.rates[best], RAR[best].c); render();
  });
}

/* --- quêtes du jour --- */
function questReady() { return QUESTS.some(q => !S.q.done[q.id] && (S.q.p[q.k] || 0) >= q.need); }
function renderQuests() {
  const body = `<div class="scroll" style="flex:1"><p style="font-size:12px;color:#c7d2fe;margin-bottom:6px">Se réinitialisent chaque jour à minuit.</p>${QUESTS.map(q => {
    const p = Math.min(S.q.p[q.k] || 0, q.need), d = S.q.done[q.id];
    return `<div class="li${d ? ' done' : ''}"><div class="ico">${UIC.quetes()}</div><div class="tt"><b>${q.n}</b><small>${p}/${q.need}</small><div class="pb2"><i style="width:${p / q.need * 100}%;background:linear-gradient(90deg,#22c55e,#86efac)"></i></div></div><div class="rw">+${q.rw.gems} ${UIC.gem()}</div>
    <button class="btn g" data-q="${q.id}" ${d || p < q.need ? 'disabled' : ''}>${d ? 'FAIT' : 'RÉCLAMER'}</button></div>`;
  }).join('')}</div>`;
  frame('Quêtes', UIC.quetes(), 'Quotidiennes', body);
  on('[data-q]', e => { const q = QUESTS.find(x => x.id === e.dataset.q); S.q.done[q.id] = 1; S.gems += q.rw.gems; SFX.play('coins', 0.6); UI.toast(`+${q.rw.gems} gemmes`, 'gold'); render(); });
}

/* --- succès (bonus permanents) --- */
function achVal(h) { return h.k === 'collect' ? owned() : h.k === 'worlds' ? S.stage.filter(s => s >= STAGES).length : S.st[h.k] || 0; }
function achReady() { return ACH.some(h => { const t = S.ach[h.id] || 0; return t < h.tiers.length && achVal(h) >= h.tiers[t]; }); }
function renderAch() {
  const done = ACH.reduce((a, h2) => a + (S.ach[h2.id] || 0), 0), tot = ACH.reduce((a, h2) => a + h2.tiers.length, 0);
  const body = `<div class="scroll" style="flex:1"><div class="tools"><span class="chip">${done}/${tot}</span><button class="btn g" data-all="1" ${achReady() ? '' : 'disabled'}>TOUT RÉCLAMER</button></div>${ACH.map(h2 => {
    const t = S.ach[h2.id] || 0, max = t >= h2.tiers.length, need = h2.tiers[Math.min(t, h2.tiers.length - 1)], v = achVal(h2);
    return `<div class="li${max ? ' done' : ''}"><div class="ico">${UIC.succes()}</div><div class="tt"><b>${h2.n} ${'★'.repeat(t)}</b><small>${fmt(Math.min(v, need))}/${fmt(need)} — récompense : +${h2.v} % ${STAT_NAMES[h2.rw]} (permanent)</small><div class="pb2"><i style="width:${Math.min(1, v / need) * 100}%;background:linear-gradient(90deg,#f59e0b,#fde047)"></i></div></div>
    <button class="btn y" data-h="${h2.id}" ${max || v < need ? 'disabled' : ''}>${max ? 'MAX' : 'RÉCLAMER'}</button></div>`;
  }).join('')}</div>`;
  frame('Succès', UIC.succes(), 'Bonus permanents', body);
  const claim = h2 => { const t = S.ach[h2.id] || 0; if (t < h2.tiers.length && achVal(h2) >= h2.tiers[t]) { S.ach[h2.id] = t + 1; return 1; } return 0; };
  on('[data-h]', e => { if (claim(ACH.find(x => x.id === e.dataset.h))) { SFX.play('win', 0.5); dirty(); } render(); });
  on('[data-all]', () => { let n = 0; for (const h2 of ACH) while (claim(h2)) n++; if (n) { SFX.play('win', 0.5); dirty(); UI.toast(`${n} succès réclamés`, 'gold'); } render(); });
}

/* --- statistiques --- */
function renderStats() {
  const b = bonus();
  const left = [['Niveau', S.lvl], ['PV max', fmt(heroHp())], ['Dégâts héros', fmt(heroDmg())], ['Puissance totale', fmt(power())], ['Armée', `${equipped().length}/${armyMax(S.lvl)}`], ['Emplacements de reliques', relicSlots(S.lvl)]]
    .concat(Object.keys(STAT_NAMES).filter(k => b[k]).map(k => [STAT_NAMES[k], `+${fmt(b[k])} %`]));
  const right = [['Argent', fmt(S.cash)], ['Gemmes', fmt(S.gems)], ['Temps de jeu', fmtTime(S.st.play)], ['Ennemis vaincus', fmt(S.st.kills)], ['Brutes vaincues', fmt(S.st.brutes)], ['Boss vaincus', fmt(S.st.bosses)], ['Ombres éveillées', fmt(S.st.arises)], ['Lucky Drops', fmt(S.st.lucky)], ['Collection', `${owned()}/30`], ['Mondes conquis', `${S.stage.filter(s => s >= STAGES).length}/4`]];
  const body = `<div class="cols scroll" style="flex:1"><div class="stbox"><h4>Héros</h4>${left.map(([k, v]) => kv(k, v)).join('')}</div><div class="stbox"><h4>Statistiques globales</h4>${right.map(([k, v]) => kv(k, v)).join('')}</div></div>`;
  frame('Statistiques', UIC.stats(), '', body);
}

/* --- réglages --- */
let wipeArm = 0;
function renderSettings() {
  const body = `<div class="scroll" style="flex:1;display:flex;flex-direction:column;gap:8px;max-width:420px;margin:auto">
    <button class="btn ${S.sfx ? 'g' : 'k'}" data-s="sfx">Effets sonores : ${S.sfx ? 'ON' : 'OFF'}</button>
    <button class="btn ${S.music ? 'g' : 'k'}" data-s="music">Musique : ${S.music ? 'ON' : 'OFF'}</button>
    <button class="btn ${S.hq ? 'g' : 'k'}" data-s="hq">Qualité graphique : ${S.hq ? 'HAUTE' : 'ÉCONOMIE'}</button>
    <button class="btn r" data-s="wipe">${wipeArm ? 'Touche encore pour TOUT effacer' : 'Effacer la sauvegarde'}</button>
    <p style="font-size:11px;color:#93c5fd;text-align:center">UMBRA v1 — Glisse à droite de l'écran pour tourner la caméra.</p></div>`;
  frame('Réglages', UIC.reglages(), '', body);
  on('[data-s]', e => {
    const s = e.dataset.s;
    if (s === 'sfx') S.sfx = !S.sfx; else if (s === 'music') SFX.setMusic(!S.music); else if (s === 'hq') { S.hq = !S.hq; GM.setQuality(S.hq); }
    else if (s === 'wipe') { if (wipeArm) wipe(); wipeArm = 1; setTimeout(() => wipeArm = 0, 3000); }
    render();
  });
}
