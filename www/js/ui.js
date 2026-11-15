/* UMBRA — interface : HUD façon Arise, panneaux (inventaire, ombres, mondes, autel, quêtes, succès, stats) */
import { E, toScreen } from './engine.js';
import { RAR, WEAPONS, RELICS, ACCS, SLOTS, WORLDS, FOES, STAGES, SUMMON, QUESTS, ACH, STAT_NAMES, SRANKS, SRANK_COL, W_MAXLV, W_MAXSTAR, R_MAXLV, A_MAXLV, SH_MAXLV,
  wUpCost, wPower, aUpCost, aMult, mission, xpNeed, armyMax, shadowPow, shUpCost, relicSlots, fmt, fmtTime, TRAITS, UNIQUES, KILL_TITLES, DUNGEONS, DG_WAVES, DG_TIME, WORLD_RW, PORTAL_RW, dungeonRW, recoPower, rkMin, rkMax, foeHp, MANA_WAVE, MANA_RECALL, ATTRS, MILES, ROLES, MECHS, TW_TIME, twTier, twRank, twCount, SPIN_CD } from './data.js';
import { S, save, wipe, bonus, dirty, heroDmg, heroHp, heroMp, shDmg, equipped, autoEquipShadows, power, owned, armyCap, HUNTER, examReady, promote, roleOf } from './state.js';
import { UIC, relicIcon, accIcon, shadowIcon } from './icons.js';
import { SFX } from './audio.js';

const $ = id => document.getElementById(id);
const h = (t, c, html) => { const e = document.createElement(t); if (c) e.className = c; if (html != null) e.innerHTML = html; return e; };
export const UI = {};
let G = null, GM = null; // module de jeu (injecté pour éviter l'import circulaire)
UI.bind = (g, gm) => { G = g; GM = gm; };

const HEX = [['inv', 'Inventaire', '#7c3aed'], ['ombres', 'Ombres', '#9f1239'], ['mondes', 'Îles', '#0369a1'], ['donjons', 'Portails', '#6d28d9'], ['quetes', 'Quêtes', '#b45309'], ['succes', 'Succès', '#a16207'], ['stats', 'Chasseur', '#047857'], ['reglages', 'Réglages', '#334155']];
const wImg = (w, cls = 'ic') => `<img class="${cls}" src="assets/i/${w.id}.png" alt="">`;

/* ---------- construction du HUD ---------- */
UI.build = () => {
  $('hud').innerHTML = `
  <div id="labels"></div><div id="dmgs"></div><div id="flash"></div><div id="fade"></div>
  <div id="hex"></div>
  <div id="mis"><div id="misI">${UIC.skull()}</div><div id="misT"><b id="misN"></b><small id="misS"></small><div class="pb2"><i id="misB"></i></div></div></div>
  <div id="marks"></div>
  <div id="rc"><div id="dmgbox"></div><div id="buffs"></div><div id="wprop"></div></div>
  <div id="penter" class="ia" hidden></div><div id="warn" hidden>⚠ SORS DE LA ZONE ROUGE !</div>
  <div id="lucky"></div><div id="toasts"></div><div id="loot"></div>
  <div id="zt"><div id="ztn"></div><div id="zts"></div></div>
  <div id="banner"><b></b><small></small></div>
  <div id="joy"><div id="knob"></div></div>
  <div id="bot">
    <div id="vit"><div class="vb hp"><i></i><span></span></div><div class="vb mp"><i></i><span></span></div></div>
    <div id="barRow">
      <div class="money" id="cash"></div>
      <div id="acts">
        <div class="ac ia" id="aAuto"><div class="tg">ON</div>${UIC.auto()}<span>AUTO</span></div>
        <div class="ac m1 ia" id="aWave">${UIC.fist()}<span>ONDE · ${MANA_WAVE}</span><div class="cdv"></div></div>
        <div class="ac big ia" id="aArise">${UIC.arise()}<span>S'ÉLEVER</span><div class="ct" id="soulN" hidden>0</div></div>
        <div class="ac rc ia" id="aRecall">${UIC.ombres()}<span>RAPPEL · ${MANA_RECALL}</span><div class="ct" id="fallN" hidden>0</div></div>
        <div class="ac ia" id="aAA"><div class="tg">OFF</div>${UIC.arise()}<span>AUTO-ÉVEIL</span></div>
        <div class="ac ia" id="aArmy">${UIC.army()}<span id="armyN">0/0</span></div>
      </div>
      <div class="money" id="gems"></div>
    </div>
    <div id="lvbar"><i></i><span></span></div>
  </div>`;
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
  $('aWave').onpointerdown = () => GM.wave();
  $('aArise').onclick = () => GM.arise();
  $('aRecall').onclick = () => GM.recall();
  $('aArmy').onclick = () => UI.open('ombres');
  $('penter').onclick = () => GM.interact();
  syncToggles(); setupInput();
};
UI.moon = on => document.body.classList.toggle('moon', !!on);
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
    else if (e.pointerId === cid) { E.yaw -= (e.clientX - cx) * 0.008; E.pitch = Math.max(0.35, Math.min(1.25, E.pitch + (e.clientY - cy) * 0.004)); cx = e.clientX; cy = e.clientY; }
  });
  const up = e => { if (e.pointerId === jid) { jid = null; G.joy.x = G.joy.y = 0; knob.style.transform = ''; joy.classList.remove('on'); } if (e.pointerId === cid) cid = null; };
  addEventListener('pointerup', up); addEventListener('pointercancel', up);
  cv.addEventListener('wheel', e => { E.dist = Math.max(10, Math.min(40, E.dist + e.deltaY * 0.02)); });
}

/* ---------- mise à jour du HUD ---------- */
let hudT = 0; const labPool = [], dns = [];
const mmss = t => `${Math.max(0, Math.floor(t / 60))}:${String(Math.max(0, Math.floor(t % 60))).padStart(2, '0')}`;
UI.update = dt => {
  for (let i = dns.length - 1; i >= 0; i--) {
    const d = dns[i]; d.t += dt; const p = toScreen(d.p); const k = d.t / d.life;
    if (k >= 1 || !p.vis) { d.el.remove(); dns.splice(i, 1); continue; }
    d.el.style.transform = `translate(${p.x + d.ox}px,${p.y - d.t * 60}px) translate(-50%,-50%) scale(${k < 0.15 ? 0.6 + k * 4 : 1})`; d.el.style.opacity = k > 0.7 ? (1 - k) / 0.3 : 1;
  }
  let n = 0; const P = G.P;
  const lab = (pos, y, cls, key, html, hpk) => {
    const p = toScreen({ x: pos.x, y: pos.y + y, z: pos.z }); if (!p.vis || n >= 26) return;
    let l = labPool[n]; if (!l) { l = labPool[n] = h('div', 'lab', '<div class="ln"></div><div class="lb"><i></i></div>'); $('labels').appendChild(l); }
    l.hidden = false; if (l._k !== key) { l._k = key; l.className = 'lab ' + cls; l.firstChild.innerHTML = html; }
    l.style.transform = `translate(${p.x}px,${p.y}px) translate(-50%,-100%)`; l.lastChild.style.visibility = hpk == null ? 'hidden' : 'visible'; if (hpk != null) l.lastChild.firstChild.style.width = (hpk * 100) + '%'; n++;
  };
  for (const f of G.foes) {
    if (f.dead) continue; const d = f.pos.distanceTo(P.pos); if (d > (f.kind === 2 ? 70 : 32)) continue;
    const nm = f.kind || f.aggro || d < 15; const c = f.leg ? '#ffcc33' : RAR[f.rk].c;
    lab(f.pos, f.kind === 2 ? (f.leg ? 7.6 : 6.2) : f.kind === 1 ? 3.6 : 2.6, 'k' + f.kind + (f.leg ? ' leg' : ''), f.id + (nm ? 'n' : ''), `<i style="background:${c}">${SRANKS[f.rk]}</i>${nm ? f.n : ''}`, f.aggro || f.hp < f.max ? f.hp / f.max : null);
  }
  for (const a of G.army) if (a.hp < 99) lab(a.pos, 2.4, 'ally', 'a' + a.sh.id, '', a.hp / 100);
  for (const np of G.npcs) lab(np.pos, 3, 'npc', np.id, `<b>${np.n}</b><br>${np.role}`, null);
  for (let i = n; i < labPool.length; i++) labPool[i].hidden = true;
  hudT -= dt; if (hudT > 0) return; hudT = 0.2;
  const b = bonus(), hub = S.world < 0, dg = G.dg, W = WORLDS[Math.max(0, S.world)];
  $('cash').innerHTML = `${UIC.cash()}${fmt(S.cash)}`; $('gems').innerHTML = `${fmt(S.gems)}${UIC.gem()}`;
  const xn = xpNeed(S.lvl); $('lvbar').firstChild.style.width = (S.xp / xn * 100) + '%'; $('lvbar').lastChild.textContent = `Chasseur rang ${SRANKS[S.hunter]}  ·  Niveau ${S.lvl}  ·  ${(S.xp / xn * 100).toFixed(1)} %  ·  Puissance ${fmt(power())}`;
  const hpM = heroHp(), mpM = heroMp(), vb = $('vit').children;
  vb[0].firstChild.style.width = Math.max(0, P.hp / hpM * 100) + '%'; vb[0].lastChild.textContent = `PV ${fmt(Math.max(0, P.hp))} / ${fmt(hpM)}`;
  vb[1].firstChild.style.width = Math.max(0, P.mp / mpM * 100) + '%'; vb[1].lastChild.textContent = `MANA ${Math.floor(P.mp)} / ${mpM}`;
  const ns = G.souls.filter(s => s.pos.distanceTo(P.pos) < 16).length; $('soulN').hidden = !ns; $('soulN').textContent = ns; $('aArise').classList.toggle('ready', ns > 0);
  $('fallN').hidden = !G.fallen.length; $('fallN').textContent = G.fallen.length; $('aRecall').classList.toggle('ready', G.fallen.length > 0 && P.mp >= MANA_RECALL);
  $('aWave').classList.toggle('off', P.mp < MANA_WAVE || G.waveCd > 0); $('aWave').querySelector('.cdv').style.height = (G.waveCd / 3 * 100) + '%';
  const rc = { tank: 0, heal: 0, dps: 0 }; for (const a of G.army) rc[a.role]++; $('armyN').innerHTML = `${G.army.length}/${armyCap()}<br><i>🛡${rc.tank} ✚${rc.heal} ⚔${rc.dps}</i>`;
  const mis = $('mis'), big = (G.boss && G.boss.aggro && G.boss) || (G.legend && G.legend.aggro && G.legend) || (dg && G.boss);
  mis.classList.toggle('boss', !!big);
  if (big) { $('misN').textContent = `${big.leg ? 'LÉGENDAIRE' : 'BOSS'} : ${big.n}`; $('misS').textContent = `${fmt(big.hp)} / ${fmt(big.max)} PV${dg ? ` · ⏱ ${mmss(dg.t)}` : ''}`; $('misB').style.width = (big.hp / big.max * 100) + '%'; }
  else if (dg) {
    const left = G.foes.filter(f => !f.dead).length;
    $('misN').textContent = dg.tower ? `TOUR DE L'ASCENSION · ÉTAGE ${Math.max(1, dg.floor)}` : `PORTAIL RANG ${SRANKS[dg.r]} · ${dg.D.n.toUpperCase()}`;
    $('misS').textContent = dg.phase === 'won' ? 'Terminé — éveille le boss puis sors' : dg.phase === 'lost' ? 'Retour…' : dg.phase === 'boss' ? `Le boss arrive… · ⏱ ${mmss(dg.t)}` : `${dg.tower ? `Record ${S.tower}` : `Vague ${Math.max(1, dg.wave + 1)}/${DG_WAVES.length}`} · ${left} ennemis · ⏱ ${mmss(dg.t)}`;
    $('misB').style.width = (dg.t / (dg.tower ? TW_TIME : DG_TIME) * 100) + '%';
  } else if (hub) { $('misN').textContent = 'SANCTUAIRE DES OMBRES'; $('misS').textContent = 'Approche un habitant pour lui parler — Lyra t\'emmène sur les îles'; $('misB').style.width = '100%'; }
  else {
    const st = Math.min(S.stage[S.world], STAGES), m = mission(S.world, Math.min(st, STAGES - 1));
    $('misN').textContent = `${W.n.toUpperCase()} · PALIER ${Math.min(st + 1, STAGES)}/${STAGES}${st >= STAGES ? ' ✓' : ''}`;
    const k = Math.min(S.prog.kills, m.kills), br = Math.min(S.prog.brutes, m.brutes);
    $('misS').textContent = G.boss ? 'Le boss t\'attend dans son arène — suis la flèche rouge' : `Ennemis ${k}/${m.kills} · Brutes ${br}/${m.brutes} → boss`;
    $('misB').style.width = ((k + br * 5) / (m.kills + m.brutes * 5) * 100) + '%';
  }
  $('dmgbox').innerHTML = `Dégâts : <b>${fmt(heroDmg())}</b><br>DPS : <b style="color:#ffcc33">${fmt(G.dps)}</b>`;
  const wp = !hub && !dg ? W.prop : {};
  const bl = [['Chance d\'Éveil', b.arise + (wp.arise ? (wp.arise - 1) * 100 : 0), '#4ade80'], ['Butin rare', b.luck, '#38bdf8'], ['Dégâts ombres', b.sdmg, '#c26bff'], ['Dégâts arme', b.wdmg, '#ff3b5c'], ['Argent', b.cash + (wp.cash ? (wp.cash - 1) * 100 : 0), '#ffcc33'], ['Gemmes', b.gems, '#7dd3fc'], ['Tous dégâts', b.all, '#ff7aa8']];
  $('buffs').innerHTML = (G.buff ? `<div style="color:#ff3355">🌙 Lune de sang ${mmss(G.buff.t)}</div>` : '') + bl.filter(x => x[1] > 0).map(([nn, v, c]) => `<div style="color:${c}">${nn} : +${fmt(v)} %</div>`).join('');
  const rw = WORLD_RW[Math.max(0, S.world)];
  $('wprop').hidden = hub; $('wprop').innerHTML = dg ? `Rang ${SRANKS[dg.r]} — puissance conseillée ${fmt(foeHp(dg.tier) * 1.8)}` : `Île de rang <b>${SRANKS[rkMin(rw)]} → ${SRANKS[rkMax(rw)]}</b><br>${W.propTxt}`; const wc = dg ? RAR[dg.r].c : W.col; $('wprop').style.borderColor = wc; $('wprop').style.color = wc;
  // repères fléchés
  const s = Math.sin(E.yaw), c = Math.cos(E.yaw);
  $('marks').innerHTML = GM.markers().slice(0, 3).map(m => { const vx = m.pos.x - P.pos.x, vz = m.pos.z - P.pos.z; const ang = Math.atan2(vx * s + vz * c, vx * c - vz * s) * 180 / Math.PI; return `<div class="mk" style="--c:${m.c}"><div class="arr" style="transform:rotate(${ang}deg)">➤</div><div><b>${m.n}</b><small>${m.s} — ${Math.round(Math.hypot(vx, vz))} m${m.t ? ' · ' + mmss(m.t) : ''}</small></div></div>`; }).join('');
  $('warn').hidden = !G.warn;
  const nr = G.near, pe = $('penter'); pe.hidden = !nr || !!$('panel') || !!document.querySelector('.reveal');
  if (nr) { const col = nr.type === 'npc' ? '#ffcc33' : RAR[G.portal.r].c; pe.style.setProperty('--c', col); pe.innerHTML = nr.type === 'npc' ? `PARLER — <b>${nr.npc.n}</b>` : `ENTRER — PORTAIL RANG <b>${SRANKS[G.portal.r]}</b>`; }
  if (S.pts > 0 || examReady()) UI.dot('stats'); if (questReady()) UI.dot('quetes'); if (achReady()) UI.dot('succes'); if (S.keys.some(k => k > 0) && !dg) UI.dot('donjons');
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
  const e = h('div', 'arc', `${shadowIcon(F.model, c, '')}<div><small>ÉVEIL RÉUSSI</small><b><i style="background:${c}">${SRANKS[sh.rk]}</i>${sh.n}</b><small style="letter-spacing:0">${ROLES[roleOf(sh)].ic} ${ROLES[roleOf(sh)].n} · ${sh.eq ? 'rejoint ton armée' : 'rangée (armée pleine)'}</small></div>`);
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
function srcOf(r) {
  const ws = WORLDS.filter((w, i) => WORLD_RW[i][r] > 0).map(w => w.n); const ds = DUNGEONS.filter(d => dungeonRW(d.r)[r] > 0).map(d => SRANKS[d.r]);
  return `${ws.length ? ws.join(' · ') : 'aucun monde'}${ds.length ? ` — portails rang ${ds.join(', ')}` : ''}`;
}

/* ---------- panneaux ---------- */
let cur = null, tab = null, selId = null;
UI.open = (id, t) => {
  UI.close(); cur = id; selId = null; if (id === 'donjons') selId = t === 'portal' ? 'portal' : null; else tab = t || tab;
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
  ({ inv: renderInv, ombres: renderShadows, mondes: renderWorlds, donjons: renderDungeons, tour: renderTower, roue: renderWheel, autel: renderAltar, quetes: renderQuests, succes: renderAch, stats: renderStats, reglages: renderSettings })[cur]();
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
  let h2 = `<div class="det scroll"><div class="big">${card({ rar: w.r, icon: wImg(w), name: '', lv: it?.lv, stars: it ? it.st : null, lock: !it })}</div><h3>${w.n}</h3><div class="rar" style="color:${R.c}">Rang ${R.k} — ${R.n}</div><p>${w.d}</p>`;
  if (!it) return h2 + kv('Dégâts de base', fmt(w.dmg), 'red') + `<p>Où la trouver : <b>${srcOf(w.r)}</b></p></div>`;
  const cost = wUpCost(w, it.lv);
  h2 += kv('Puissance', '⚔ ' + fmt(wPower(w, it)), 'red') + kv('Niveau', `${it.lv}/${W_MAXLV}`) + kv('Étoiles (doublons)', `${it.st}/${W_MAXSTAR}`, 'cy') + kv('Niveau suivant', it.lv < W_MAXLV ? '⚔ ' + fmt(wPower(w, { lv: it.lv + 1, st: it.st })) : 'MAX', 'red');
  h2 += `<div class="row"><button class="btn y" data-act="wup" ${it.lv >= W_MAXLV || S.cash < cost ? 'disabled' : ''}>${UIC.cash()} ${fmt(cost)}</button><button class="btn y" data-act="wup10" ${it.lv >= W_MAXLV || S.cash < cost ? 'disabled' : ''}>×10</button></div>`;
  h2 += `<button class="btn g" data-act="weq" ${S.wEq === id ? 'disabled' : ''}>${S.wEq === id ? 'ÉQUIPÉE' : 'ÉQUIPER'}</button><p style="font-size:10.5px">Doublon trouvé = +1 étoile (+35 % de puissance)</p></div>`;
  return h2;
}
function detRelic(id) {
  const r = RELICS.find(x => x.id === id), it = S.rel[id], R = RAR[r.r]; const eq = S.relEq.includes(id);
  let s = `<div class="det scroll"><div class="big">${card({ rar: r.r, icon: relicIcon(r), name: '', lv: it?.lv, lock: !it })}</div><h3>${r.n}</h3><div class="rar" style="color:${R.c}">Rang ${R.k} — ${R.n}</div><p>${r.d}</p>`;
  if (!it) return s + kv(STAT_NAMES[r.stat], `+${r.v} % par niveau`) + `<p>Où la trouver : <b>${srcOf(r.r)}</b>, ou à l'Autel.</p></div>`;
  s += kv(STAT_NAMES[r.stat], `+${fmt(r.v * (1 + it.lv))} %`) + kv('Niveau', `${it.lv}/${R_MAXLV}`) + kv('Prochain niveau', it.lv < R_MAXLV ? `+${fmt(r.v * (2 + it.lv))} %` : 'MAX', 'cy');
  s += `<button class="btn ${eq ? 'r' : 'g'}" data-act="req">${eq ? 'RETIRER' : 'ÉQUIPER'}</button><p style="font-size:10.5px">Chaque doublon fait monter la relique d'un niveau.</p></div>`;
  return s;
}
function detAcc(id) {
  const a = ACCS.find(x => x.id === id), it = S.acc[id], R = RAR[a.r]; const eq = S.accEq[a.slot] === id;
  let s = `<div class="det scroll"><div class="big">${card({ rar: a.r, icon: accIcon(a), name: '', lv: it?.lv, lock: !it })}</div><h3>${a.n}</h3><div class="rar" style="color:${R.c}">Rang ${R.k} — ${R.n} · ${SLOTS.find(x => x[0] === a.slot)[1]}</div>`;
  const m = it ? aMult(it.lv) : 1;
  for (const k in a.st) s += kv(STAT_NAMES[k], `+${fmt(a.st[k] * m)} %`);
  if (!it) return s + `<p>Où le trouver : <b>${srcOf(a.r)}</b></p></div>`;
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
  const body = `<div style="flex:1;display:flex;flex-direction:column;min-width:0"><div class="tools"><span class="chip">Armée ${equipped().length}/${armyCap()}</span><span class="chip">Total ${S.sh.length}</span><span class="chip">${['tank', 'heal', 'dps'].map(r => `<b style="color:${ROLES[r].c}">${ROLES[r].ic} ${equipped().filter(x => roleOf(x) === r).length}</b>`).join(' · ')}</span><button class="btn g" data-a="best">Équipe équilibrée</button><button class="btn r" data-a="sell">Vendre les rangs F-E rangés</button><button class="btn b" data-a="sort">Tri : ${shSort === 'pow' ? 'Puissance' : 'Rang'}</button></div><div class="grid scroll" style="flex:1">${cards}</div></div>${sel ? detShadow(sel) : ''}`;
  frame('Ombres', UIC.ombres(), '🛡 Tank : encaisse · ✚ Soigneur : soigne · ⚔ Dégâts : frappe fort', body);
  on('.ci', e => { selId = +e.dataset.id; render(); });
  on('[data-a]', e => {
    const a = e.dataset.a;
    if (a === 'best') { autoEquipShadows(); GM.syncArmy(); SFX.play('ok', 0.5); }
    else if (a === 'sell') { let v = 0, n = 0; S.sh = S.sh.filter(s => { if (!s.eq && s.rk <= 1 && !s.u) { v += shUpCost(s) * 0.4; n++; return false; } return true; }); S.cash += v; if (n) UI.toast(`${n} ombres vendues : +${fmt(v)}`, 'gold'); }
    else if (a === 'sort') shSort = shSort === 'pow' ? 'rank' : 'pow';
    else if (a === 'eq') { if (sel.eq) sel.eq = false; else if (equipped().length < armyCap()) sel.eq = true; else { UI.toast('Armée pleine — monte de niveau pour plus d\'ombres', 'bad'); return; } GM.syncArmy(); }
    else if (a === 'up') { const c = shUpCost(sel); if (S.cash >= c && sel.lv < SH_MAXLV) { S.cash -= c; sel.lv++; GM.bumpUpgrade(); SFX.play('coins', 0.5); } }
    else if (a === 'del') { if (sel.eq || sel.u) return; S.cash += shUpCost(sel) * 0.4; S.sh.splice(S.sh.indexOf(sel), 1); selId = null; GM.syncArmy(); }
    render();
  });
}
function shCard(s, F, sel, noName) {
  const c = SRANK_COL[s.rk]; const R2 = RAR[s.rk];
  return `<div class="card shc${sel ? ' sel' : ''}${R2.rainbow ? ' rb' : ''}${s.u ? ' uq' : ''}" style="--rc:${c}"><div class="in">${shadowIcon(F.model, c)}${noName ? '' : `<div class="nm">${s.n}</div><div class="pw2">⚔ ${fmt(shDmg(s))}</div>`}</div><div class="rk big">${SRANKS[s.rk]}</div>${s.eq ? '<div class="ck">✓</div>' : ''}${s.u ? '<div class="utag">UNIQUE</div>' : ''}<div class="role" style="background:${ROLES[roleOf(s)].c}">${ROLES[roleOf(s)].ic}</div>${noName ? '' : `<div class="lv">Nv.${s.lv}</div>`}${s.aw ? `<div class="aw">${'★'.repeat(s.aw)}</div>` : ''}</div>`;
}
const killTitle = k => [...KILL_TITLES].reverse().find(t => (k || 0) >= t[0])[1];
const traitHtml = s => (s.tr || []).map(([k, v], i) => `<div class="trait${s.u && i === 0 ? ' sig' : ''}"><b>${s.u && i === 0 ? '✦ ' : ''}${TRAITS[k].n}</b><span>+${fmt(v)} % ${STAT_NAMES[k]}</span></div>`).join('') || '<div class="trait none"><span>Aucun trait — les rangs D et plus en possèdent</span></div>';
function detShadow(s) {
  const F = FOES[s.type], c = SRANK_COL[s.rk], cost = shUpCost(s), U = s.u && UNIQUES[s.u];
  return `<div class="det scroll"><div class="big">${shCard(s, F, false, true)}</div><h3>${s.n}</h3><div class="rar" style="color:${c}">Rang ${SRANKS[s.rk]} · ${U ? U.t : F.n}</div>
  <div class="rolebox" style="--c:${ROLES[roleOf(s)].c}"><b>${ROLES[roleOf(s)].ic} ${ROLES[roleOf(s)].n}</b><span>${ROLES[roleOf(s)].d}</span></div>
  ${U ? `<p class="quote">« ${U.q} »</p>` : ''}
  ${kv('Dégâts', '⚔ ' + fmt(shDmg(s)), 'red')}${kv('Niveau', `${s.lv}/${SH_MAXLV}`)}${U ? kv('Éveil (doublons)', `${'★'.repeat(s.aw || 0) || '—'} ${s.aw || 0}/5`, 'cy') : ''}
  <div class="traits">${traitHtml(s)}</div>
  ${G.fallen.includes(s.id) ? '<div class="verdict" style="color:#ff3355;border-color:#ff3355;font-size:12px">Tombée au combat — RAPPEL</div>' : ''}${kv('Grade', killTitle(s.kills))}${kv('Ennemis abattus', fmt(s.kills || 0), 'cy')}
  <p class="born">Éveillée le ${s.born || '—'}<br>${s.where || ''}</p>
  <button class="btn y" data-a="up" ${S.cash < cost || s.lv >= SH_MAXLV ? 'disabled' : ''}>Améliorer ${UIC.cash()} ${fmt(cost)}</button>
  <button class="btn ${s.eq ? 'r' : 'g'}" data-a="eq">${s.eq ? 'RETIRER DE L\'ARMÉE' : 'AJOUTER À L\'ARMÉE'}</button>
  ${s.u ? '' : `<button class="btn k" data-a="del" ${s.eq ? 'disabled' : ''}>Libérer (+${fmt(cost * 0.4)})</button>`}</div>`;
}
/* révélation plein écran d'une ombre marquante */
UI.reveal = sh => {
  document.querySelector('.reveal')?.remove();
  const F = FOES[sh.type], c = SRANK_COL[sh.rk], U = sh.u && UNIQUES[sh.u];
  const e = h('div', 'reveal', `<div class="rays"></div><div class="rv"><div class="rvk">${U ? 'OMBRE UNIQUE' : 'NOUVELLE OMBRE'}</div><div class="rvp">${shadowIcon(F.model, c, '')}<div class="rvr">${SRANKS[sh.rk]}</div></div>
    <h2>${sh.n}</h2><div class="rvt">${U ? U.t : F.n} · <span style="color:${ROLES[roleOf(sh)].c}">${ROLES[roleOf(sh)].ic} ${ROLES[roleOf(sh)].n}</span></div>${U ? `<p class="quote">« ${U.q} »</p>` : ''}<div class="traits">${traitHtml(sh)}</div><div class="rvd">⚔ ${fmt(shDmg(sh))} · ${sh.eq ? 'rejoint ton armée' : 'rangée — armée pleine'}</div><small>Touche pour continuer</small></div>`);
  e.style.setProperty('--c', c); document.body.appendChild(e); SFX.play('win', 0.7);
  const close = () => e.remove(); e.onclick = close; setTimeout(close, 7000);
};
const tierIn = (w, t) => t >= w.base && t < w.base + STAGES;

/* --- mondes --- */
function renderWorlds() {
  const hubCard = `<div class="wc hubc${S.world < 0 && !G.dg ? ' here' : ''}" style="--c:#c26bff"><b>Sanctuaire des Ombres</b><small>Le hub : Tour de l'Ascension, Autel des Reliques, Gardien des Portails, Roue de la Fortune</small>${S.world < 0 && !G.dg ? '<button class="btn k" disabled>VOUS ÊTES ICI</button>' : '<button class="btn p" data-w="-1">RETOURNER AU SANCTUAIRE</button>'}</div>`;
  const body = `<div class="wgrid scroll" style="flex:1">${hubCard}${WORLDS.map((w, i) => {
    const st = S.stage[i], lock = i > S.maxWorld, here = i === S.world && !G.dg, m = mission(i, Math.min(st, STAGES - 1));
    return `<div class="wc${lock ? ' lockd' : ''}${here ? ' here' : ''}" style="--c:${w.col}"><div class="num">#${i + 1}</div><b>${w.n}</b><small>${w.sub}</small>
      <div class="prop">✦ ${w.propTxt}</div><div class="mi">Palier ${Math.min(st + 1, STAGES)}/${STAGES}${st >= STAGES ? ' — CONQUIS ✓' : ''} · Mission : ${m.kills} ennemis + ${m.brutes} brutes → ${UNIQUES[w.uq].n}</div>
      <div class="pb2"><i style="width:${Math.min(st, STAGES) / STAGES * 100}%"></i></div><div class="miles">${MILES.map(([p, t]) => `<span class="${st >= p ? 'ok' : ''}">P${p} · ${t}</span>`).join('')}</div>
      <div class="mi">Butin et ombres : rangs ${WORLD_RW[i].map((x, r) => x > 0 ? `<b style="color:${RAR[r].c}">${SRANKS[r]}</b>` : '').filter(Boolean).join(' ')} · Portails : ${PORTAL_RW[i].map((x, r) => x > 0 ? `<b style="color:${RAR[r].c}">${SRANKS[r]}</b>` : '').filter(Boolean).join(' ')}</div>
      ${here ? '<button class="btn k" disabled>VOUS ÊTES ICI</button>' : lock ? `<button class="btn k" disabled>🔒 Conquiers ${WORLDS[i - 1].n} (10 paliers)</button>` : `<button class="btn b" data-w="${i}">TÉLÉPORTER</button>`}</div>`;
  }).join('')}</div>`;
  frame('Îles', UIC.mondes(), `${S.maxWorld + 1}/4 débloquées — chaque île a ses propres rangs`, body);
  on('[data-w]', e => { UI.close(); GM.enterWorld(+e.dataset.w); });
}

/* --- portails et donjons (rangs F → S) --- */
function verdict(r) {
  const k = power() / recoPower(r);
  return k >= 1 ? ['À ta portée', '#4ade80'] : k >= 0.45 ? ['Risqué', '#ffcc33'] : k >= 0.12 ? ['Très dangereux', '#ff7a45'] : ['Mort certaine', '#ff3355'];
}
function renderDungeons() {
  const pt = G.portal; if (selId !== 'portal' && !(typeof selId === 'number' && selId >= 0 && selId <= 6)) selId = pt ? 'portal' : 0;
  if (selId === 'portal' && !pt) selId = 0;
  const r = selId === 'portal' ? pt.r : selId;
  const D = DUNGEONS[r], U = UNIQUES[D.boss], [vt, vc] = verdict(r), rw = dungeonRW(r);
  const list = `<div class="scroll dgl">${pt ? `<div class="dgr${selId === 'portal' ? ' on' : ''}" data-d="portal" style="--c:${RAR[pt.r].c}"><b class="rkb">${SRANKS[pt.r]}</b><div><b>Portail ouvert</b><small>${Math.round(pt.pos.distanceTo(G.P.pos))} m — gratuit</small></div></div>` : ''}
    ${DUNGEONS.map(d => { const [t, c] = verdict(d.r); return `<div class="dgr${selId === d.r ? ' on' : ''}" data-d="${d.r}" style="--c:${RAR[d.r].c}"><b class="rkb">${SRANKS[d.r]}</b><div><b>${d.n}</b><small style="color:${c}">${t}</small></div><span class="keyn">${UIC.key()} ${S.keys[d.r]}</span></div>`; }).join('')}</div>`;
  const near = selId === 'portal' && G.near && G.near.type === 'portal';
  const det = `<div class="scroll dgd" style="--c:${RAR[r].c}"><div class="dgh"><div class="dgk">${SRANKS[r]}</div><div><h3>${D.n}</h3><small>${DG_WAVES.length} vagues (${DG_WAVES.join(' + ')} ennemis) puis le boss · ${Math.round(DG_TIME / 60)} minutes · un seul essai</small></div></div>
    ${kv('Puissance conseillée', fmt(recoPower(r)), 'red')}${kv('Ta puissance', fmt(power()))}<div class="verdict" style="color:${vc};border-color:${vc}">${vt}</div>
    <div class="bossrow"><img src="assets/i/p_${U.model}.png"><div><small>BOSS — OMBRE UNIQUE À ÉVEILLER (35 %)</small><b>${U.n}, ${U.t}</b><span style="color:${RAR[U.rk].c}">Rang ${SRANKS[U.rk]} · ${ROLES[FOES[U.foe].role].ic} ${ROLES[FOES[U.foe].role].n} · ✦ ${TRAITS[U.sig[0]].n} +${U.sig[1]} %</span></div></div>
    <div class="mechs">${[...U.mech, 'enrage'].map(m => `<div><b>${MECHS[m][0]}</b> — ${MECHS[m][1]}</div>`).join('')}</div>
    <div class="mi2">Butin et ombres : ${rw.map((x, i) => x > 0 ? `<b style="color:${RAR[i].c}">${SRANKS[i]} ${Math.round(x / rw.reduce((a, b) => a + b, 0) * 100)} %</b>` : '').filter(Boolean).join(' · ')} — 1 relique garantie</div>
    ${G.dg ? '<button class="btn k" disabled>Déjà dans un donjon</button>' : selId === 'portal' ? `<button class="btn p" data-go="portal" ${near ? '' : 'disabled'}>${near ? 'ENTRER DANS LE PORTAIL' : 'Rejoins le portail pour entrer (suis la flèche)'}</button>` : `<button class="btn p" data-go="${r}" ${S.keys[r] ? '' : 'disabled'}>${S.keys[r] ? `OUVRIR AVEC UNE CLÉ ${UIC.key()}` : 'Aucune clé de ce rang'}</button>`}
    <p class="mi2">Les portails s'ouvrent au hasard dans les mondes. Les clés tombent sur les boss des mondes et dans les donjons. Terminés : ${S.dgDone[r]}</p></div>`;
  frame('Portails', UIC.donjons(), 'Rang F → S : plus le rang est haut, plus le butin est rare', list + det);
  on('[data-d]', e => { selId = e.dataset.d === 'portal' ? 'portal' : +e.dataset.d; render(); });
  on('[data-go]', e => { const g = e.dataset.go; UI.close(); if (g === 'portal') GM.enterPortal(); else GM.enterDungeon(+g, true); });
}
UI.dungeonResult = dg => {
  UI.open('reglages'); cur = null; const res = dg.res, r = dg.r;
  const items = res.items.map(([k, id]) => { const it = (k === 'w' ? WEAPONS : k === 'rel' ? RELICS : ACCS).find(x => x.id === id); return `<div style="width:84px">${card({ rar: it.r, icon: k === 'w' ? wImg(it) : k === 'rel' ? relicIcon(it) : accIcon(it), name: it.n })}</div>`; }).join('');
  frame(`Portail rang ${SRANKS[r]} terminé`, UIC.donjons(), dg.D.n, `<div class="scroll" style="flex:1;text-align:center"><div class="tools" style="justify-content:center"><span class="chip">${UIC.cash()} +${fmt(res.cash)}</span><span class="chip">${UIC.gem()} +${fmt(res.gems)}</span>${res.key != null ? `<span class="chip">${UIC.key()} Clé rang ${SRANKS[res.key]}</span>` : ''}</div>
    <div class="pulls" style="margin:10px 0">${items}</div><p class="mi2">L'âme de <b>${UNIQUES[dg.D.boss].n}</b> flotte encore : ferme ce panneau et touche S'ÉLEVER pour tenter de l'éveiller (35 %).</p>
    <div style="display:flex;gap:8px;justify-content:center;margin-top:10px"><button class="btn b" id="dgStay">RESTER (éveiller le boss)</button><button class="btn g" id="dgOut">SORTIR DU DONJON</button></div></div>`);
  $('dgStay').onclick = () => $('panel')?.remove(); $('dgOut').onclick = () => { $('panel')?.remove(); GM.leaveDungeon(); };
  $('px').onclick = () => $('panel')?.remove();
};

/* --- Tour de l'Ascension --- */
function renderTower() {
  const f = Math.max(1, S.tower - 1), need = foeHp(twTier(f)) * 1.8, k = power() / need; const [vt, vc] = k >= 1 ? ['À ta portée', '#4ade80'] : k >= 0.45 ? ['Risqué', '#ffcc33'] : ['Trop dur pour l\'instant', '#ff3355'];
  const body = `<div class="scroll dgd" style="--c:#c26bff;max-width:560px;margin:auto"><div class="dgh"><div class="dgk">${S.tower}</div><div><h3>Tour de l'Ascension</h3><small>Des étages sans fin. ${TW_TIME} s par étage, de plus en plus durs. Tu repars deux étages sous ton record.</small></div></div>
    ${kv('Record', `Étage ${S.tower}`, 'cy')}${kv('Départ', `Étage ${f} — rang ${SRANKS[twRank(f)]}`)}${kv('Puissance conseillée', fmt(need), 'red')}${kv('Ta puissance', fmt(power()))}<div class="verdict" style="color:${vc};border-color:${vc}">${vt}</div>
    <div class="mi2">• Chaque étage : gemmes et argent.<br>• Tous les 5 étages : un <b>Gardien</b>, et au premier passage une <b>relique</b> + 50 % de chance de <b>clé de portail</b>.<br>• Les âmes des ennemis sont éveillables : étage 8+ rang E, 16+ rang D, 24+ rang C… jusqu'au rang S à l'étage 48.</div>
    <button class="btn p" data-tw="1" ${G.dg ? 'disabled' : ''}>ENTRER DANS LA TOUR</button></div>`;
  frame('Tour de l\'Ascension', UIC.succes(), 'L\'Archiviste', body);
  on('[data-tw]', () => { UI.close(); GM.enterTower(); });
}
/* --- Roue de la Fortune --- */
let spinRes = null;
function renderWheel() {
  const left = SPIN_CD - (Date.now() - S.spinT), ready = left <= 0;
  const body = `<div class="scroll" style="flex:1;text-align:center"><div class="wheel${spinRes ? ' spun' : ''}" style="--to:${spinRes ? 1440 + spinRes[2] * 72 + 36 : 0}deg"><div class="wpin">▼</div><div class="wdisc"></div></div>
    <div class="tools" style="justify-content:center;margin-top:8px"><span class="chip" style="color:#4ade80">Argent</span><span class="chip" style="color:#38bdf8">Gemmes</span><span class="chip" style="color:#fcd34d">Clé de portail</span><span class="chip" style="color:#c26bff">Objet de ton île</span><span class="chip" style="color:#ff7ad9">Jackpot</span></div>
    ${spinRes ? `<div class="verdict" style="color:${spinRes[1]};border-color:${spinRes[1]};max-width:420px;margin:8px auto">${spinRes[0]}</div>` : ''}
    <button class="btn y" data-spin="1" ${ready ? '' : 'disabled'} style="margin-top:8px;font-size:15px;padding:10px 26px">${ready ? 'TOURNER LA ROUE (gratuit)' : `Prochain tour dans ${fmtTime(left / 1000)}`}</button><p class="mi2" style="margin-top:6px">Un tour gratuit toutes les 4 heures.</p></div>`;
  frame('Roue de la Fortune', UIC.autel(), 'Pip', body);
  on('[data-spin]', () => { spinRes = GM.spin(); render(); });
}

/* --- autel d'invocation des reliques --- */
let lastPulls = [];
function renderAltar() {
  const rates = SUMMON.rates.map((r, i) => `<div class="rate" style="--rc:${RAR[i].c}"><b>${RAR[i].k}</b>${(r * 100).toFixed(r < 0.001 ? 2 : r < 0.02 ? 1 : 0)} %</div>`).join('');
  const body = `<div class="scroll" style="flex:1"><p style="font-size:12px;color:#c7d2fe;margin-bottom:4px">Invoque des reliques avec tes gemmes. Un doublon fait monter la relique d'un niveau (max ${R_MAXLV}).</p><div class="rates">${rates}</div>
   <div style="display:flex;gap:8px;justify-content:center;margin:8px 0"><button class="btn p" data-n="1" ${S.gems < SUMMON.cost ? 'disabled' : ''}>Invoquer ×1 · ${SUMMON.cost} ${UIC.gem()}</button><button class="btn y" data-n="10" ${S.gems < SUMMON.cost10 ? 'disabled' : ''}>Invoquer ×10 · ${SUMMON.cost10} ${UIC.gem()}</button></div>
   <div class="pulls">${lastPulls.map((id, i) => { const r = RELICS.find(x => x.id === id); return `<div style="width:74px;animation:pop .45s ${i * 0.08}s backwards">${card({ rar: r.r, icon: relicIcon(r), name: r.n, lv: S.rel[id].lv })}</div>`; }).join('')}</div></div>`;
  frame('Autel des Reliques', UIC.autel(), `${fmt(S.gems)} gemmes`, body);
  on('[data-n]', e => {
    const n = +e.dataset.n, c = n === 10 ? SUMMON.cost10 : SUMMON.cost; if (S.gems < c) return; S.gems -= c; lastPulls = [];
    let best = 0; for (let i = 0; i < n; i++) { const r = GM.rollRelic(); lastPulls.push(r.id); best = Math.max(best, r.r); }
    SFX.play(best >= 3 ? 'win' : 'power', 0.6); if (best >= 3) UI.lucky(RELICS.find(x => x.id === lastPulls.find(id => RELICS.find(q => q.id === id).r === best)).n, SUMMON.rates[best], RAR[best].c); render();
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
  const b = bonus(), hr = S.hunter, max = hr >= 6, H = max ? null : HUNTER[hr], col = RAR[hr].c;
  const lic = `<div class="stbox lic" style="--c:${col}"><div class="licr">${SRANKS[hr]}</div><h4>Licence de Chasseur</h4><p class="mi2">${max ? 'Rang S — tu es au sommet de l\'Association.' : `Examen du rang <b style="color:${RAR[hr + 1].c}">${SRANKS[hr + 1]}</b> :`}</p>
    ${H ? H.c.map(([t, f]) => `<div class="cond${f() ? ' ok' : ''}">${f() ? '✓' : '○'} ${t}</div>`).join('') + `<p class="mi2">Récompense : +5 points d'attributs, +1 ombre dans l'armée, ${100 * (hr + 1)} gemmes.</p><button class="btn y" data-exam="1" ${examReady() ? '' : 'disabled'}>PASSER AU RANG ${SRANKS[hr + 1]}</button>` : ''}</div>`;
  const att = `<div class="stbox"><h4>Attributs — ${S.pts} point${S.pts > 1 ? 's' : ''} à répartir</h4>${ATTRS.map(a2 => `<div class="attr"><div><b style="color:${a2.c}">${a2.n} ${S.at[a2.k]}</b><small>${a2.d}</small></div><button class="btn g" data-at="${a2.k}" data-n="1" ${S.pts ? '' : 'disabled'}>+1</button><button class="btn g" data-at="${a2.k}" data-n="5" ${S.pts >= 5 ? '' : 'disabled'}>+5</button></div>`).join('')}<p class="mi2">+3 points à chaque niveau, +5 à chaque rang de Chasseur.</p></div>`;
  const left = [['Niveau', S.lvl], ['PV max', fmt(heroHp())], ['Mana max', heroMp()], ['Dégâts héros', fmt(heroDmg())], ['Puissance totale', fmt(power())], ['Armée', `${equipped().length}/${armyCap()}`], ['Emplacements de reliques', relicSlots(S.lvl)]]
    .concat(Object.keys(STAT_NAMES).filter(k => b[k]).map(k => [STAT_NAMES[k], `+${fmt(b[k])} %`]));
  const right = [['Temps de jeu', fmtTime(S.st.play)], ['Ennemis vaincus', fmt(S.st.kills)], ['Boss vaincus', fmt(S.st.bosses)], ['Boss légendaires', fmt(S.st.legends || 0)], ['Ombres éveillées', fmt(S.st.arises)], ['Lucky Drops', fmt(S.st.lucky)], ['Coffres ouverts', fmt(S.st.chests || 0)], ['Record de la Tour', `Étage ${S.tower}`], ['Collection', `${owned()}/30`], ['Îles conquises', `${S.stage.filter(x => x >= STAGES).length}/4`]];
  const body = `<div class="cols3 scroll" style="flex:1">${lic}${att}<div class="stbox"><h4>Héros</h4>${left.map(([k, v]) => kv(k, v)).join('')}<h4 style="margin-top:6px">Carrière</h4>${right.map(([k, v]) => kv(k, v)).join('')}</div></div>`;
  frame('Chasseur', UIC.stats(), `Rang ${SRANKS[hr]} · niveau ${S.lvl}`, body);
  on('[data-at]', e => { const n = Math.min(+e.dataset.n, S.pts); if (n > 0) { S.at[e.dataset.at] += n; S.pts -= n; dirty(); G.P.hp = Math.min(heroHp(), G.P.hp); } render(); });
  on('[data-exam]', () => { if (promote()) { GM.syncArmy(); UI.close(); UI.banner(`CHASSEUR DE RANG ${SRANKS[S.hunter]}`, 'L\'Association reconnaît ta puissance', RAR[S.hunter].c); SFX.play('win', 0.9); } });
}

/* --- réglages --- */
let wipeArm = 0;
function renderSettings() {
  const body = `<div class="scroll" style="flex:1;display:flex;flex-direction:column;gap:8px;max-width:420px;margin:auto">
    <button class="btn ${S.sfx ? 'g' : 'k'}" data-s="sfx">Effets sonores : ${S.sfx ? 'ON' : 'OFF'}</button>
    <button class="btn ${S.music ? 'g' : 'k'}" data-s="music">Musique : ${S.music ? 'ON' : 'OFF'}</button>
    <button class="btn ${S.hq ? 'g' : 'k'}" data-s="hq">Qualité graphique : ${S.hq ? 'HAUTE' : 'ÉCONOMIE'}</button>
    <button class="btn r" data-s="wipe">${wipeArm ? 'Touche encore pour TOUT effacer' : 'Effacer la sauvegarde'}</button>
    <p style="font-size:11px;color:#93c5fd;text-align:center">UMBRA v6 — Glisse à droite de l'écran pour tourner la caméra.</p></div>`;
  frame('Réglages', UIC.reglages(), '', body);
  on('[data-s]', e => {
    const s = e.dataset.s;
    if (s === 'sfx') S.sfx = !S.sfx; else if (s === 'music') SFX.setMusic(!S.music); else if (s === 'hq') { S.hq = !S.hq; GM.setQuality(S.hq); }
    else if (s === 'wipe') { if (wipeArm) wipe(); wipeArm = 1; setTimeout(() => wipeArm = 0, 3000); }
    render();
  });
}
