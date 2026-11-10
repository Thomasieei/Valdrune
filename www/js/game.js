/* NOCTALIS — logique de jeu : joueur, monstres, Éveil, armée, donjons, siège */
import * as THREE from 'three';
import { E, makeChar, attachWeapon, buildWorld, collide, burst, slash, shock, pillar, projectile, portalMesh } from './engine.js';
import { S, save, stats, power, shadowDmg, shadowSpd, shadowCrit, armyPower, slotsMax, xpNeed, questProg, checkQuests,
  ZONES, zoneHp, zoneDmg, RANKS, RANK_COL, RANK_MULT, ARISE_BASE, SELL_VAL, shadowBase, rollGrade, DUNGEONS, KEY_MAX, KEY_REGEN, WEAPONS,
  rnd, irnd, pick, clamp, fmt } from './core.js';
import { UI } from './ui.js';
import { SFX } from './audio.js';
import * as DM from './domain.js';

export const G = { mode: 'hub', zone: -1, enemies: [], army: [], nodes: [], cits: [], A: null, info: null, input: { x: 0, z: 0 }, P: null, breach: null, D: null, SG: null,
  ult: 0, frenzy: 0, cds: { strike: 0, dash: 0 }, goldRate: 0, gr: [], bossT: 60, breachT: 70, time: 0 };
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const MAX_VIS = 12;

/* ---------- joueur ---------- */
function makePlayer() {
  const w = WEAPONS[S.weapon];
  const ch = makeChar('Rogue_Hooded', { keep: ['Rogue_'], weapon: w.model, wcol: w.col, eyeCol: 0x9ff3ff });
  const aura = new THREE.Mesh(new THREE.CircleGeometry(1.4, 32), new THREE.MeshBasicMaterial({ map: E.glowTex, color: 0x7c3aed, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false }));
  aura.rotation.x = -Math.PI / 2; aura.position.y = 0.06; ch.root.add(aura);
  E.scene.add(ch.root);
  return { ch, pos: ch.root.position, ang: 0, hp: stats().hpMax, atkCd: 0, combo: 0, target: null, dead: 0, hurtT: 0, moving: false, dashT: 0, dashDir: V() };
}
export function refreshWeapon() { const w = WEAPONS[S.weapon]; attachWeapon(G.P.ch.mdl, w.model, w.col); }

/* ---------- monde ---------- */
function clearEntities() {
  for (const e of G.enemies) { e.ch.dispose(); UI.dropLabel(e); }
  for (const a of G.army) a.ch.dispose();
  for (const c of G.cits) c.ch.dispose();
  G.enemies = []; G.army = []; G.nodes = []; G.cits = []; G.P.target = null; G.P.node = null;
}
function enter(kind, opt) {
  clearEntities();
  if (G.breach) { G.breach.mesh?.removeFromParent(); G.breach = null; }
  G.info = buildWorld(kind, opt);
  G.P.pos.copy(G.info.spawn); G.P.hp = stats().hpMax; G.P.dead = 0;
  E.cam.position.set(G.P.pos.x, 20, G.P.pos.z + 18);
  syncArmy(true);
}
export function enterHub() {
  G.mode = 'hub'; G.zone = -1; G.D = null; G.SG = null; G.A = null; enter('hub'); spawnCitizens();
  UI.zoneTitle('Citadelle Noctalis', 'Refuge du Veilleur'); SFX.music('hub');
}
export function enterZone(z) {
  if (S.lvl < ZONES[z].req) { UI.toast(`Niveau ${ZONES[z].req} requis pour ${ZONES[z].name}`, 'bad'); return; }
  G.mode = 'zone'; G.zone = z; S.zone = z; G.D = null; G.SG = null; G.A = null; enter(z);
  for (let i = 0; i < 9; i++) spawnNode(z); buildOutposts(z);
  G.bossT = 45; G.breachT = 60;
  for (let i = 0; i < 10; i++) spawnZoneMob();
  UI.zoneTitle(ZONES[z].name, ZONES[z].sub); SFX.music('zone' + z);
}

/* ---------- monstres ---------- */
function mobDef(d) { return { ...d }; }
function spawnEnemy(def, z, r, hp, pos, o = {}) {
  const scale = def.s * (o.elite ? 1.25 : 1) * (o.scale || 1);
  const ch = makeChar(def.m, { scale, keep: def.keep, weapon: def.w, tint: def.tint || (o.elite ? 0xffd27a : 0), eyeCol: o.boss ? 0xff2020 : 0xff6a3d });
  ch.root.position.copy(pos); ch.root.rotation.y = rnd(0, 6.28); E.scene.add(ch.root);
  if (o.boss || o.elite) { const ring = new THREE.Mesh(new THREE.RingGeometry(1.2 * scale, 1.45 * scale, 40), new THREE.MeshBasicMaterial({ color: o.boss ? 0xff3355 : 0xffcc33, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.07; ch.root.add(ring); }
  const e = { ch, pos: ch.root.position, def, z, r: clamp(r, 0, 8), hp, max: hp, boss: !!o.boss, elite: !!o.elite, home: pos.clone(), st: 'idle', cd: rnd(0.5, 1.5), wt: rnd(1, 4), wdir: V(), dead: false, corpse: 0, tries: 3, flash: 0,
    dmgMul: o.dmgMul || 1, siege: !!o.siege, scale, ranged: /Mage|Pyro|Nécro/.test(def.name), speed: (def.quad ? 6.2 : 4.6) * (o.boss ? 0.85 : 1) };
  e.name = (o.boss ? '★ ' : o.elite ? 'Élite · ' : '') + def.name;
  G.enemies.push(e); UI.addLabel(e); return e;
}
function spawnZoneMob(boss) {
  const z = G.zone, Z = ZONES[z];
  const def = boss ? Z.boss : pick(Z.mobs);
  const elite = !boss && Math.random() < 0.1;
  const r = def.r + (elite ? 1 : 0);
  const sp = pick(G.info.spots).clone().add(V(rnd(-6, 6), 0, rnd(-6, 6)));
  if (sp.distanceTo(G.P.pos) < 14) sp.add(V(rnd(-1, 1), 0, rnd(-1, 1)).normalize().multiplyScalar(16));
  collide(sp, 0.6, 55);
  const hp = zoneHp(z) * def.hp * Math.pow(2.4, r - Z.mobs[0].r) * (elite ? 4 : 1);
  const e = spawnEnemy(def, z, r, hp, sp, { boss, elite });
  if (boss) { UI.banner(`${def.name} est apparu !`, 'Boss · rang ' + RANKS[r], '#ff3355'); SFX.play('bell'); E.shake = 0.4; pillar(sp, 0xff3355, 7); }
  return e;
}
function nearestEnemy(p, maxD = 999, alive = true) {
  let best = null, bd = maxD; for (const e of G.enemies) { if (alive && e.dead) continue; const d = e.pos.distanceTo(p); if (d < bd) { bd = d; best = e; } } return best;
}
export function hitEnemy(e, dmg, crit, src) {
  if (e.dead) return;
  e.hp -= dmg; e.flash = 0.12; UI.dmg(e.pos, dmg, crit ? 'crit' : src === 'sh' ? 'sh' : 'pl', e.scale);
  if (!e.boss && Math.random() < 0.25 && e.st !== 'atk') e.ch.play('hit', { once: true, restart: true, speed: 1.6 });
  if (e.st === 'idle') e.st = 'chase';
  if (e.hp <= 0) killEnemy(e);
}
function killEnemy(e) {
  e.dead = true; e.hp = 0; e.st = 'dead'; e.corpse = G.mode === 'siege' ? 6 : 12; e.tries = e.boss ? 4 : 3;
  e.ch.play('death', { once: true, restart: true });
  const st = stats();
  const dm = G.mode === 'dungeon' ? 2.5 : G.mode === 'siege' ? 1.5 : 1;
  const gold = e.max * st.gold * dm; S.gold += gold; G.gr.push([G.time, gold]);
  const xp = 18 * Math.pow(3.1, e.z) * (1 + 0.5 * (e.r - ZONES[e.z].mobs[0].r)) * (e.boss ? 25 : e.elite ? 4 : 1) * st.xp * dm;
  addXp(xp);
  const fr = (e.boss ? 25 : e.elite ? 4 : 1) * (Math.random() < 0.5 ? 1 : 2) * (G.mode === 'dungeon' ? 2 : 1); S.frags[e.z] += fr;
  if (e.boss) DM.addRenom(4 + e.z * 4);
  if (G.A) G.A.left = G.enemies.filter(x => !x.dead).length;
  if (e.boss) { const gm = 8 + e.z * 6; S.gems += gm; S.bossKills++; questProg('boss'); UI.toast(`Boss vaincu ! +${gm} Éclats`, 'gold'); }
  else if (Math.random() < 0.04) { S.gems += 1; UI.floatIco(e.pos, 'gem'); }
  S.kills++; questProg('kill'); G.ult = Math.min(100, G.ult + (e.boss ? 25 : e.elite ? 6 : 2.2));
  UI.coins(e.pos, gold, fr, ZONES[e.z].fragCol);
  burst(e.pos.clone().setY(1), 0xff6a3d, 10, { speed: 3 });
  SFX.play('coins', 0.25);
  if (G.P.target === e) G.P.target = null;
  if (G.D) G.D.left = G.enemies.filter(x => !x.dead).length;
  if (G.SG) G.SG.killed++;
}
function removeEnemy(e) { e.ch.dispose(); UI.dropLabel(e); G.enemies.splice(G.enemies.indexOf(e), 1); }

/* ---------- XP / niveaux ---------- */
function addXp(x) {
  S.xp += x; let up = false;
  while (S.xp >= xpNeed(S.lvl)) { S.xp -= xpNeed(S.lvl); S.lvl++; S.gems += 10; up = true; }
  if (up) {
    G.P.hp = stats().hpMax; pillar(G.P.pos, 0xffcc33, 6); SFX.play('win', 0.6);
    UI.banner(`NIVEAU ${S.lvl}`, `+10 Éclats · ${slotsMax()} emplacements d'ombre`, '#ffcc33');
    const z = ZONES.find(z => z.req === S.lvl); if (z) UI.toast(`Nouvelle zone débloquée : ${z.name} !`, 'gold');
    autoEquip();
  }
}

/* ---------- ÉVEIL ---------- */
export function ariseNear(manual) {
  let n = 0; const st = stats();
  for (const e of G.enemies) {
    if (!e.dead || e.tries <= 0 || e.arising) continue;
    if (manual && e.pos.distanceTo(G.P.pos) > 9) continue;
    n++; attemptArise(e, st, manual);
  }
  if (manual && !n) UI.toast('Aucun corps à éveiller à proximité', 'bad');
  return n;
}
function attemptArise(e, st, manual) {
  e.tries--; const ch = Math.min(0.98, ARISE_BASE[e.r] * (1 + st.eveil) * (e.boss ? 0.6 : 1));
  e.arising = 0.6; e.ach = ch; e.aman = manual;
  burst(e.pos.clone().setY(0.5), 0x8b5cf6, 16, { speed: 2, up: 1.5, grav: -1 });
}
function resolveArise(e) {
  const manual = e.aman;
  if (Math.random() < e.ach) {
      const big = e.boss || e.r >= 2 || manual;
      if (big) { pillar(e.pos.clone(), e.r >= 5 ? 0xffcc33 : 0x8b5cf6, e.boss ? 12 : 8); E.shake = e.boss ? 0.5 : 0.15; SFX.play('power', 0.6); }
      else { shock(e.pos, 0x8b5cf6, 3, 0.5); burst(e.pos.clone().setY(1), 0xb38cff, 14, { speed: 2, up: 2, grav: -2 }); SFX.play('seal', 0.3); }
      UI.dmgText(e.pos, 'ÉVEIL !', 'arise');
      const s = newShadow(e); S.arises++; questProg('arise');
      if (s && (big || S.arises < 25)) UI.ariseCard(s, e.r >= 4);
      removeEnemy(e);
  } else {
      if (manual || e.r >= 3 || e.boss) { UI.dmgText(e.pos, e.tries > 0 ? `ÉCHEC (${e.tries})` : 'ÉCHEC', 'fail'); SFX.play('lose', 0.25); }
      if (e.tries <= 0) e.corpse = Math.min(e.corpse, 1.2);
  }
}
export function newShadow(e) {
  const dis = S.autoDissolve;
  const s = { id: S.nextId++, m: e.def.m, name: e.def.name, z: e.z, boss: e.boss, r: e.r, lvl: 1, st: [rollGrade(), rollGrade(), rollGrade(), rollGrade()], eq: false, lock: false,
    w: e.def.w, keep: e.def.keep, sc: e.boss ? Math.min(1.5, e.def.s * 0.65) : e.def.s * (e.def.quad ? 1 : 1), quad: e.def.quad };
  if (dis >= 0 && s.r <= dis && !e.boss) { const g = sellValue(s); S.gold += g; UI.toast(`${s.name} dissous : +${fmt(g)} or`, ''); return null; }
  if (S.shadows.length >= S.invMax) {
    const st = stats(); let worst = null; for (const x of S.shadows) if (!x.eq && !x.lock && (!worst || shadowDmg(x, st) < shadowDmg(worst, st))) worst = x;
    if (worst && shadowDmg(worst, st) < shadowDmg(s, st)) { S.gold += sellValue(worst); S.shadows.splice(S.shadows.indexOf(worst), 1); }
    else { S.gold += sellValue(s); if (G.time - (G.invWarn || -99) > 30) { G.invWarn = G.time; UI.toast('Inventaire plein — les ombres faibles sont dissoutes en or', 'bad'); } return null; }
  }
  S.shadows.push(s); autoEquip(); return s;
}
export const sellValue = s => SELL_VAL[s.r] * shadowBase(s.z, s.boss) * 4 * (1 + 0.1 * s.lvl);
export function autoEquip(force) {
  const st = stats(); const max = slotsMax();
  const sorted = [...S.shadows].sort((a, b) => shadowDmg(b, st) * shadowSpd(b) - shadowDmg(a, st) * shadowSpd(a));
  const before = S.shadows.filter(s => s.eq).map(s => s.id).join();
  S.shadows.forEach(s => s.eq = false); sorted.slice(0, max).forEach(s => s.eq = true);
  if (force || before !== S.shadows.filter(s => s.eq).map(s => s.id).join()) syncArmy();
}

/* ---------- armée visible ---------- */
export function syncArmy(reset) {
  const st = stats();
  const eq = S.shadows.filter(s => s.eq).sort((a, b) => shadowDmg(b, st) - shadowDmg(a, st));
  const vis = eq.slice(0, MAX_VIS); const keep = new Set(vis.map(s => s.id));
  for (let i = G.army.length - 1; i >= 0; i--) { const a = G.army[i]; if (!keep.has(a.s.id) || reset) { a.ch.dispose(); G.army.splice(i, 1); } }
  for (const s of vis) {
    if (G.army.find(a => a.s.id === s.id)) continue;
    const gen = s === vis[0];
    const ch = makeChar(s.m, { shadow: true, keep: s.keep, weapon: s.w, scale: s.sc * (gen ? 1.25 : 1), shadowCol: s.r >= 5 ? 0x7c3aed : 0x4c1d95, eyeCol: s.r >= 5 ? 0xffd75e : 0x9ff3ff });
    const aura = new THREE.Mesh(new THREE.CircleGeometry(gen ? 1.3 : 0.9, 24), new THREE.MeshBasicMaterial({ map: E.glowTex, color: s.r >= 5 ? 0xffb020 : 0x6d28d9, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    aura.rotation.x = -Math.PI / 2; aura.position.y = 0.05; ch.root.add(aura);
    const p = G.P.pos.clone().add(V(rnd(-3, 3), 0, rnd(-3, 3))); ch.root.position.copy(p); E.scene.add(ch.root);
    if (!reset) pillar(p, 0x8b5cf6, 4);
    G.army.push({ s, ch, pos: ch.root.position, cd: rnd(0, 1), target: null, slot: 0, ranged: /Mage/.test(s.m), gen });
  }
  G.army.forEach((a, i) => a.slot = i);
  G.armyDps = armyPower(st);
}

/* ---------- compétences ---------- */
export function skill(id) {
  const P = G.P; if (P.dead) return;
  const st = stats();
  if (id === 'strike' && G.cds.strike <= 0) {
    G.cds.strike = 3.5; P.ch.play('cast', { once: true, restart: true, speed: 1.6 }); P.lockT = 0.4;
    slash(P.pos, P.ang, 0xb38cff, true); slash(P.pos, P.ang + Math.PI, 0xb38cff, true); shock(P.pos, 0x8b5cf6, 5);
    burst(P.pos.clone().setY(1), 0xb38cff, 24, { speed: 6 }); E.shake = 0.2; SFX.play('boom', 0.4);
    for (const e of G.enemies) if (!e.dead && e.pos.distanceTo(P.pos) < 5.5 + e.scale) { const c = Math.random() < st.crit * 2; hitEnemy(e, st.atk * 6 * (c ? 3 : 1), c); }
  } else if (id === 'dash' && G.cds.dash <= 0) {
    G.cds.dash = 5; P.dashT = 0.22; P.dashDir.set(Math.sin(P.ang), 0, Math.cos(P.ang)); SFX.play('select', 0.4);
    const hit = new Set(); P.dashHit = hit;
  } else if (id === 'ult' && G.ult >= 100) {
    G.ult = 0; G.frenzy = 8; P.ch.play('cheer', { once: true, restart: true, speed: 1.3 }); P.lockT = 0.8;
    pillar(P.pos.clone(), 0x7c3aed, 14); shock(P.pos, 0xffcc33, 12, 1); shock(P.pos, 0x8b5cf6, 9, 0.8); E.shake = 0.7; SFX.play('boom', 0.8); SFX.play('power', 0.8);
    UI.banner('DOMAINE DU MONARQUE', 'Ombres déchaînées ×3 pendant 8 s', '#c26bff');
    for (const e of G.enemies) if (!e.dead && e.pos.distanceTo(P.pos) < 14) hitEnemy(e, st.atk * 30 + G.armyDps * 4, true);
  }
}

/* ---------- donjons ---------- */
export function startDungeon(i, breach) {
  const d = breach ? { z: breach.z, name: `Brèche de rang ${RANKS[breach.r]}`, rooms: 6, time: 240 } : DUNGEONS[i];
  if (!breach) { if (S.lvl < ZONES[d.z].req) return UI.toast('Zone non débloquée', 'bad'); if (S.keys <= 0) return UI.toast('Plus de clés de brèche', 'bad'); S.keys--; }
  G.mode = 'dungeon'; G.zone = d.z;
  const tint = new THREE.Color(breach ? RANK_COL[breach.r] : ZONES[d.z].fragCol).getHex();
  enter('dungeon', { tint });
  G.D = { d, z: d.z, room: 0, rooms: d.rooms, time: d.time, left: 0, tot: 0, mul: breach ? Math.pow(2.4, breach.r - ZONES[d.z].mobs[0].r) : 3, clearT: 0, gold0: S.gold, gems: 0, runes: 0, breach: !!breach, rBonus: breach ? breach.r - ZONES[d.z].mobs[0].r : 1 };
  UI.zoneTitle(d.name, `${d.rooms} chambres`); SFX.music('dungeon'); nextRoom();
}
function nextRoom() {
  const D = G.D; D.room++;
  for (const e of [...G.enemies]) removeEnemy(e);
  G.P.pos.copy(G.info.spawn); G.army.forEach(a => a.pos.copy(G.P.pos).add(V(rnd(-3, 3), 0, rnd(-2, 2))));
  const Z = ZONES[D.z]; const last = D.room === D.rooms; const mini = !last && D.room % 5 === 0;
  const n = last ? 4 : 5 + Math.min(7, Math.floor(D.room / 3));
  const hpm = D.mul * Math.pow(1.07, D.room);
  for (let i = 0; i < n; i++) {
    const a = rnd(0, 6.28), r = rnd(4, G.info.R - 4); const def = pick(Z.mobs); const rr = def.r + D.rBonus;
    const e = spawnEnemy(def, D.z, rr, zoneHp(D.z) * def.hp * hpm * Math.pow(2.4, rr - Z.mobs[0].r - D.rBonus), V(Math.cos(a) * r, 0, Math.sin(a) * r * 0.6 - 4), { dmgMul: 1.4 });
    e.st = 'chase';
  }
  if (last || mini) {
    const def = Z.boss; const rr = def.r + D.rBonus + (last ? 1 : 0);
    const e = spawnEnemy(def, D.z, rr, zoneHp(D.z) * def.hp * hpm * (last ? 2 : 0.6), V(0, 0, -8), { boss: true, dmgMul: 1.6, scale: last ? 1.15 : 0.9 });
    e.st = 'chase'; UI.banner(last ? 'GARDIEN DE LA BRÈCHE' : 'Sentinelle', `${def.name} · rang ${RANKS[rr]}`, '#ff3355'); SFX.play('bell');
  }
  D.tot = G.enemies.length; D.left = D.tot; D.clearT = 0;
  UI.fade();
}
function dungeonEnd(win) {
  const D = G.D; if (!D) return; G.D = null;
  const gold = S.gold - D.gold0;
  let gems = 0, runes = 0, keys = 0;
  if (win) { gems = Math.round((20 + D.rooms * 2) * (1 + D.z)); runes = Math.round((2 + D.rooms / 4) * (1 + D.z)); if (!D.breach && Math.random() < 0.4) keys = 1; S.dClears++; questProg('dungeon'); }
  else { gems = Math.round(D.room * (1 + D.z)); runes = Math.floor(D.room / 5); }
  S.gems += gems; S.runes += runes; S.keys = Math.min(KEY_MAX + 3, S.keys + keys);
  UI.result(win ? 'BRÈCHE SCELLÉE' : 'TEMPS ÉCOULÉ', win ? '#4ade80' : '#ff3355', [[`Chambres`, `${win ? D.rooms : D.room - 1} / ${D.rooms}`], ['Or', fmt(gold)], ['Éclats', '+' + gems], ['Runes', '+' + runes], ...(keys ? [['Clé de brèche', '+1']] : [])], () => G.zone >= 0 && D.breach ? enterZone(D.z) : enterHub());
  SFX.play(win ? 'win' : 'lose', 0.7); save();
}

/* ---------- siège sans fin ---------- */
export function startSiege() {
  if (S.lvl < 8) return UI.toast('Niveau 8 requis pour le Siège', 'bad');
  G.mode = 'siege'; G.zone = 0;
  enter('siege');
  G.SG = { wave: S.siegeCk, crystal: 100, spawnLeft: 0, spawnT: 0, gold0: S.gold, gems: 0, runes: 0, killed: 0, pause: 2 };
  UI.zoneTitle('Siège sans fin', `Protège le Cristal · départ vague ${S.siegeCk + 1}`); SFX.music('dungeon'); nextWave();
}
const zMaxUnlocked = () => ZONES.filter(z => S.lvl >= z.req).length - 1;
function nextWave() {
  const SG = G.SG; SG.wave++; SG.spawnLeft = Math.min(30, 6 + Math.floor(SG.wave / 2)); SG.spawnT = 0;
  SG.boss = SG.wave % 10 === 0;
  if (SG.wave > 1) { SG.gems += 2; S.gems += 2; if (SG.wave % 5 === 0) { SG.runes++; S.runes++; } }
  if ((SG.wave - 1) % 25 === 0 && SG.wave > 1) { S.siegeCk = Math.max(S.siegeCk, SG.wave - 1); UI.toast(`Point de contrôle : vague ${SG.wave - 1}`, 'gold'); }
  S.siegeBest = Math.max(S.siegeBest, SG.wave - 1); questProg('siege', SG.wave - 1);
  UI.banner(`VAGUE ${SG.wave}`, SG.boss ? 'Un champion mène l’assaut !' : 'Défends le cristal', SG.boss ? '#ff3355' : '#38bdf8');
}
function siegeSpawn() {
  const SG = G.SG, z = Math.min(zMaxUnlocked(), Math.floor(SG.wave / 40)), Z = ZONES[z];
  const a = pick([0, 1.57, 3.14, 4.71]) + rnd(-0.3, 0.3); const R = G.info.R - 2;
  const boss = SG.boss && SG.spawnLeft === 1; const def = boss ? Z.boss : pick(Z.mobs);
  const hp = 30 * Math.pow(1.21, SG.wave) * def.hp * (boss ? 0.5 : 1);
  const e = spawnEnemy(def, z, def.r + Math.floor(SG.wave / 30), hp, V(Math.cos(a) * R, 0, Math.sin(a) * R), { boss, siege: true, scale: boss ? 0.8 : 1 });
  e.st = 'siege';
}
function siegeEnd() {
  const SG = G.SG; G.SG = null; const gold = S.gold - SG.gold0; save();
  UI.result('LE CRISTAL S’EST BRISÉ', '#38bdf8', [['Vague atteinte', SG.wave - 1], ['Record', S.siegeBest], ['Point de contrôle', S.siegeCk], ['Or', fmt(gold)], ['Éclats', '+' + SG.gems], ['Runes', '+' + SG.runes]], enterHub);
  SFX.play('lose', 0.7);
}

/* ---------- brèches dans les zones ---------- */
function spawnBreach() {
  const Z = ZONES[G.zone]; const r = clamp(Z.mobs[0].r + irnd(1, 2) + (Math.random() < 0.12 ? 1 : 0), 0, 8);
  const p = pick(G.info.spots).clone(); const mesh = portalMesh(new THREE.Color(RANK_COL[r]).getHex(), 1.1); mesh.position.copy(p); E.world.add(mesh);
  G.breach = { r, z: G.zone, pos: p, t: 120, mesh };
  UI.toast(`Une brèche de rang ${RANKS[r]} s'est ouverte !`, 'gold'); SFX.play('ping', 0.5);
}

/* ---------- mise à jour ---------- */
const tmp = V(), tmp2 = V();
export function update(dt) {
  G.time += dt; const P = G.P, st = stats();
  for (const k in G.cds) G.cds[k] = Math.max(0, G.cds[k] - dt);
  if (G.frenzy > 0) G.frenzy -= dt;
  // clés
  if (S.keys < KEY_MAX) { S.keyT += dt; if (S.keyT >= KEY_REGEN) { S.keyT = 0; S.keys++; } } else S.keyT = 0;

  /* joueur */
  if (P.dead > 0) { P.dead -= dt; if (P.dead <= 0) { P.pos.copy(G.info.spawn); P.hp = st.hpMax; P.ch.play('idle'); if (G.D) G.D.time = Math.max(5, G.D.time - 15); UI.toast('Les ombres t’ont relevé', ''); } }
  else {
    P.hurtT -= dt; P.hp = Math.min(st.hpMax, P.hp + st.hpMax * (P.hurtT > 0 ? 0.01 : 0.05) * dt);
    let mx = G.input.x, mz = G.input.z; const manual = Math.hypot(mx, mz) > 0.1;
    let mv = V();
    if (manual) { const c = Math.cos(E.yaw), s = Math.sin(E.yaw); mv.set(mx * c + mz * s, 0, -mx * s + mz * c); }
    // ciblage
    if (!P.target || P.target.dead || P.target.pos.distanceTo(P.pos) > 20) P.target = nearestEnemy(P.pos, manual ? 7 : (S.autoFarm ? (S.harvest && G.mode === 'zone' ? 22 : 60) : 9));
    const T = P.target;
    if (!T && G.mode === 'zone') { if (!P.node || P.node.hp <= 0 || P.node.pos.distanceTo(P.pos) > 30) P.node = nearestNode(P.pos, S.autoFarm && S.harvest && !manual ? 60 : 3.2); } else P.node = null;
    if (!manual && S.autoFarm && G.mode !== 'hub') {
      if (T && T.pos.distanceTo(P.pos) > 2.2 + T.scale * 0.6) mv.subVectors(T.pos, P.pos).setY(0).normalize();
      else if (!T && G.breach && G.mode === 'zone') { mv.subVectors(G.breach.pos, P.pos).setY(0); if (mv.length() < 1.5) { enterBreach(); return; } mv.normalize(); }
      else if (!T && P.node && P.node.pos.distanceTo(P.pos) > 2.4) mv.subVectors(P.node.pos, P.pos).setY(0).normalize();
      else if (!T && !P.node && G.mode === 'zone') { const c = G.enemies.find(e => e.dead && e.tries > 0); if (c && c.pos.distanceTo(P.pos) > 3) mv.subVectors(c.pos, P.pos).setY(0).normalize(); }
    }
    if (G.goTo) { if (manual) G.goTo = null; else { mv.subVectors(G.goTo, P.pos).setY(0); if (mv.length() < 1.2) G.goTo = null; mv.normalize(); } }
    P.lockT = (P.lockT || 0) - dt;
    if (P.dashT > 0) { P.dashT -= dt; P.pos.addScaledVector(P.dashDir, dt * 34); E.particles.emit(P.pos.clone().setY(1), 0x8b5cf6, { speed: 1, life: 0.35, size: 1, grav: 0 });
      for (const e of G.enemies) if (!e.dead && !P.dashHit.has(e) && e.pos.distanceTo(P.pos) < 2.5) { P.dashHit.add(e); hitEnemy(e, st.atk * 3, true); } }
    else if (mv.lengthSq() > 0.01 && P.lockT <= 0) {
      const sp = 9 * (manual ? Math.min(1, Math.hypot(mx, mz)) : 1);
      if (P.sideT > 0) { P.sideT -= dt; mv.set(mv.x * 0.3 - mv.z * P.side, 0, mv.z * 0.3 + mv.x * P.side).normalize(); }
      const ox = P.pos.x, oz = P.pos.z;
      P.pos.addScaledVector(mv, sp * dt); collide(P.pos, 0.5, G.info.R);
      const moved = Math.hypot(P.pos.x - ox, P.pos.z - oz) / (sp * dt);
      if (moved < 0.35 && !manual) { P.stuckT = (P.stuckT || 0) + dt; if (P.stuckT > 0.25) { P.stuckT = 0; P.side = Math.random() < 0.5 ? 1 : -1; P.sideT = 0.7; } } else P.stuckT = 0;
      P.ang = Math.atan2(mv.x, mv.z); P.ch.play('run', { speed: 1.1 }); P.moving = true;
    } else { if (P.moving || !P.ch.cur || P.ch.cur === 'Running_A') P.ch.play('idle'); P.moving = false; }
    collide(P.pos, 0.5, G.info.R);
    P.ch.root.rotation.y = lerpAng(P.ch.root.rotation.y, P.ang, dt * 14);
    // attaque auto
    P.atkCd -= dt;
    if (T && !T.dead && T.pos.distanceTo(P.pos) < 2.6 + T.scale * 0.7 && P.atkCd <= 0 && P.dashT <= 0) {
      P.atkCd = 0.5; P.combo++; P.ang = Math.atan2(T.pos.x - P.pos.x, T.pos.z - P.pos.z);
      if (!P.moving) P.ch.play('attack', { once: true, restart: true, speed: 2 });
      const big = P.combo % 4 === 0; const c = Math.random() < st.crit;
      slash(P.pos, P.ang, big ? 0xffcc33 : 0xc9b6ff, big); SFX.hit();
      if (big) { for (const e of G.enemies) if (!e.dead && e.pos.distanceTo(P.pos) < 4 + e.scale) hitEnemy(e, st.atk * 2.5 * (c ? 2.5 : 1), c); }
      else hitEnemy(T, st.atk * (c ? 2.5 : 1), c);
    } else if (!T && P.node && P.node.pos.distanceTo(P.pos) < 2.8 && P.atkCd <= 0 && P.dashT <= 0) {
      P.atkCd = 0.6; P.ang = Math.atan2(P.node.pos.x - P.pos.x, P.node.pos.z - P.pos.z); if (!P.moving) P.ch.play('attack', { once: true, restart: true, speed: 2 }); mineNode(P.node, 1);
    }
  }
  P.ch.update(dt);

  /* ombres */
  const n = G.army.length; const dpsPer = n ? (G.armyDps || 0) / n : 0; const fr = G.frenzy > 0 ? 3 : 1;
  G.army.forEach((a, i) => {
    let tgt = a.target;
    const worker = S.harvest && G.mode === 'zone' && i % 2 === 1 && G.nodes.some(n => n.hp > 0 && n.pos.distanceTo(P.pos) < 35);
    if (worker) { const th = nearestEnemy(a.pos, 4); tgt = a.target = th && !th.dead && th.st !== 'idle' ? th : null; }
    else if (!tgt || tgt.dead || !G.enemies.includes(tgt)) tgt = a.target = (P.target && !P.target.dead ? (i % 3 === 0 ? nearestEnemy(a.pos, 12) || P.target : P.target) : nearestEnemy(P.pos, 16));
    const reach = a.ranged ? 7 : 1.8 + (tgt ? tgt.scale * 0.6 : 0);
    if (tgt) {
      const d = a.pos.distanceTo(tgt.pos);
      if (d > reach) { const ang = i * 2.39996; tmp.set(tgt.pos.x + Math.cos(ang) * reach * 0.8 - a.pos.x, 0, tgt.pos.z + Math.sin(ang) * reach * 0.8 - a.pos.z); const L = tmp.length(); if (L > 0.3) { tmp.multiplyScalar(1 / L); a.pos.addScaledVector(tmp, Math.min(L, 10.5 * dt)); a.ch.root.rotation.y = Math.atan2(tmp.x, tmp.z); a.ch.play('run'); } }
      else {
        a.ch.root.rotation.y = Math.atan2(tgt.pos.x - a.pos.x, tgt.pos.z - a.pos.z);
        a.cd -= dt * shadowSpd(a.s) * fr;
        if (a.cd <= 0) {
          a.cd = 1; const c = Math.random() < shadowCrit(a.s); const dmg = dpsPer * (c ? 2 : 1) * fr;
          if (a.ranged) { a.ch.play('cast', { once: true, restart: true, speed: 1.8 }); const t = tgt; projectile(a.pos, t.pos, 0x9b6bff, 0.3, () => { hitEnemy(t, dmg, c, 'sh'); burst(t.pos.clone().setY(1), 0x9b6bff, 6); }); }
          else { a.ch.play('attack', { once: true, restart: true, speed: 1.8 }); hitEnemy(tgt, dmg, c, 'sh'); burst(tgt.pos.clone().setY(1), 0x7c3aed, 5, { speed: 2 }); }
        } else if (a.ch.cur === 'Running_A' || a.ch.cur === 'Gallop') a.ch.play('idle');
      }
    } else if (S.harvest && G.mode === 'zone' && (a.node = (a.node && a.node.hp > 0 ? a.node : nearestNode(worker ? a.pos : P.pos, worker ? 40 : 24, i)))) {
      const nd = a.node; tmp.subVectors(nd.pos, a.pos).setY(0); const L = tmp.length(); const ang = i * 2.39996;
      if (L > 2.2) { tmp.set(nd.pos.x + Math.cos(ang) * 1.6 - a.pos.x, 0, nd.pos.z + Math.sin(ang) * 1.6 - a.pos.z).normalize(); a.pos.addScaledVector(tmp, Math.min(L, 10 * dt)); a.ch.root.rotation.y = Math.atan2(tmp.x, tmp.z); a.ch.play('run'); }
      else { a.ch.root.rotation.y = Math.atan2(nd.pos.x - a.pos.x, nd.pos.z - a.pos.z); a.cd -= dt; if (a.cd <= 0) { a.cd = 1.4; a.ch.play('attack', { once: true, restart: true, speed: 1.6 }); mineNode(nd, 0.5); } }
    } else {
      // formation derrière le joueur
      const row = Math.floor(i / 4), col = i % 4; const bx = (col - 1.5) * 1.8, bz = -2.2 - row * 1.8;
      const s = Math.sin(P.ang), c = Math.cos(P.ang);
      tmp2.set(P.pos.x + bx * c + bz * s, 0, P.pos.z - bx * s + bz * c);
      tmp.subVectors(tmp2, a.pos).setY(0); const L = tmp.length();
      if (L > 0.5) { tmp.multiplyScalar(1 / L); a.pos.addScaledVector(tmp, Math.min(L, (L > 8 ? 16 : 9) * dt)); a.ch.root.rotation.y = lerpAng(a.ch.root.rotation.y, Math.atan2(tmp.x, tmp.z), dt * 10); a.ch.play('run'); }
      else { a.ch.play('idle'); a.ch.root.rotation.y = lerpAng(a.ch.root.rotation.y, P.ang, dt * 5); }
      if (L > 30) a.pos.copy(tmp2);
    }
    collide(a.pos, 0.45, G.info.R);
    a.ch.update(dt);
    if (G.frenzy > 0 && Math.random() < 0.15) E.particles.emit(a.pos.clone().setY(1), 0xc26bff, { speed: 1, up: 1.5, grav: -1, life: 0.5 });
  });

  /* monstres */
  for (let i = G.enemies.length - 1; i >= 0; i--) {
    const e = G.enemies[i];
    if (e.dead) { if (e.arising > 0) { e.arising -= dt; if (e.arising <= 0) { e.arising = 0; resolveArise(e); if (!G.enemies.includes(e)) continue; } }
      e.corpse -= dt; if (S.autoArise && e.tries > 0 && !e.arising && e.corpse < (G.mode === 'siege' ? 5.6 : 11.4)) attemptArise(e, st);
      if (Math.random() < 0.08 && e.tries > 0) E.particles.emit(e.pos.clone().setY(0.6), 0x8b5cf6, { speed: 0.5, up: 1, grav: -1.5, life: 0.8 });
      if (e.corpse <= 0 && !e.arising) removeEnemy(e); e.ch.update(dt); continue; }
    e.flash -= dt;
    if (e.pendHit > 0) { e.pendHit -= dt; if (e.pendHit <= 0 && e.pos.distanceTo(P.pos) < (e.ranged ? 7 : 1.7 + e.scale * 0.7) + 1) hurtPlayer(e); }
    let goal = null;
    if (e.st === 'siege' && !G.SG) { e.ch.play('idle'); e.ch.update(dt); continue; }
    if (e.st === 'siege') {
      const d = e.pos.length();
      if (d > 2.8) { goal = V(0, 0, 0); }
      else { e.cd -= dt; if (e.cd <= 0) { e.cd = 1.4; e.ch.play('attack', { once: true, restart: true }); G.SG.crystal -= e.boss ? 6 : 1; burst(V(0, 3, 0), 0xff3355, 6); UI.shakeCrystal(); } }
      const near = P.dead > 0 ? null : (P.pos.distanceTo(e.pos) < 3 ? P : null);
      if (near && e.cd <= 0) { e.cd = 1.2; hurtPlayer(e); }
    } else {
      const dp = P.dead > 0 ? 999 : e.pos.distanceTo(P.pos);
      const aggro = e.boss ? 13 : 9;
      if (e.st === 'idle' && dp < aggro) e.st = 'chase';
      if (e.st === 'chase') {
        if (dp > 34 && G.mode === 'zone') { e.st = 'idle'; }
        else {
          const rng = e.ranged ? 7 : 1.7 + e.scale * 0.7;
          if (dp > rng) goal = P.pos;
          else { e.ch.root.rotation.y = lerpAng(e.ch.root.rotation.y, Math.atan2(P.pos.x - e.pos.x, P.pos.z - e.pos.z), dt * 10); e.cd -= dt;
            if (e.cd <= 0) { e.cd = e.boss ? 1.6 : 1.3; e.ch.play(e.ranged ? 'cast' : 'attack', { once: true, restart: true, speed: 1.3 });
              if (e.ranged) projectile(e.pos, P.pos, 0xff6a3d, 0.4, () => hurtPlayer(e)); else e.pendHit = 0.25;
              if (e.boss) shock(e.pos, 0xff3355, 3, 0.4); } }
        }
      } else if (e.st === 'idle') {
        e.wt -= dt; if (e.wt <= 0) { e.wt = rnd(2, 5); e.wdir.set(rnd(-1, 1), 0, rnd(-1, 1)).normalize(); if (Math.random() < 0.4 || e.pos.distanceTo(e.home) > 8) e.wdir.subVectors(e.home, e.pos).setY(0).normalize(); e.wander = rnd(0.8, 1.8); }
        if (e.wander > 0) { e.wander -= dt; e.pos.addScaledVector(e.wdir, dt * 1.8); e.ch.root.rotation.y = lerpAng(e.ch.root.rotation.y, Math.atan2(e.wdir.x, e.wdir.z), dt * 6); e.ch.play('walk'); } else e.ch.play('idle');
      }
    }
    if (goal) { tmp.subVectors(goal, e.pos).setY(0); const L = tmp.length(); if (L > 0.1) { tmp.multiplyScalar(1 / L); e.pos.addScaledVector(tmp, e.speed * dt); e.ch.root.rotation.y = lerpAng(e.ch.root.rotation.y, Math.atan2(tmp.x, tmp.z), dt * 8); e.ch.play('run'); } }
    // séparation
    for (const o of G.enemies) { if (o === e || o.dead) continue; tmp.subVectors(e.pos, o.pos).setY(0); const d = tmp.length(), m = 0.9 * (e.scale + o.scale) * 0.6; if (d < m && d > 0.01) e.pos.addScaledVector(tmp, (m - d) / d * 0.5); }
    collide(e.pos, 0.5 * e.scale, G.info.R);
    e.ch.update(dt);
  }

  /* domaine, filons, citoyens */
  DM.tick(dt, G.mode !== 'zone' && G.mode !== 'hub', () => { UI.toast('Un messager t’attend : touche le parchemin', 'gold'); SFX.play('ping', 0.5); });
  for (const n of G.nodes) { if (n.hp <= 0) { n.respawn -= dt; if (n.respawn <= 0) relocateNode(n); } else n.gem.rotation.y += dt; }
  if (G.mode === 'hub') updateCitizens(dt);
  if (G.mode === 'assault' && G.A) { updateAssault(dt); return; }
  /* modes */
  if (G.mode === 'zone') {
    const alive = G.enemies.filter(e => !e.dead && !e.boss).length;
    if (alive < 10 && Math.random() < dt * 1.2) spawnZoneMob();
    G.bossT -= dt; if (G.bossT <= 0 && !G.enemies.some(e => e.boss && !e.dead)) { G.bossT = 90; spawnZoneMob(true); }
    if (!G.breach) { G.breachT -= dt; if (G.breachT <= 0) { G.breachT = 150; spawnBreach(); } }
    else { G.breach.t -= dt; if (G.breach.t <= 0) { G.breach.mesh.removeFromParent(); G.breach = null; } else if (G.breach.pos.distanceTo(P.pos) < 1.8 && !P.dead) enterBreach(); }
    for (const p of G.info.portals) if (p.zone === -1 && Math.hypot(P.pos.x - p.x, P.pos.z - p.z) < 1.8 && !S.autoFarm) { enterHub(); return; }
    let nearO = null; for (const s of G.info.stations) if (Math.hypot(P.pos.x - s.x, P.pos.z - s.z) < 5) nearO = s; UI.station(nearO);
  } else if (G.mode === 'hub') {
    for (const p of G.info.portals) if (Math.hypot(P.pos.x - p.x, P.pos.z - p.z) < 1.9) { if (S.lvl >= ZONES[p.zone].req) { enterZone(p.zone); return; } else if (!G.hubWarn) { G.hubWarn = 2; UI.toast(`Niveau ${ZONES[p.zone].req} requis`, 'bad'); } }
    G.hubWarn = Math.max(0, (G.hubWarn || 0) - dt);
    let near = null; for (const s of G.info.stations) if (Math.hypot(P.pos.x - s.x, P.pos.z - s.z) < 4) near = s;
    UI.station(near);
  } else if (G.mode === 'dungeon' && G.D) {
    const D = G.D; D.time -= dt; D.left = G.enemies.filter(e => !e.dead).length;
    if (D.time <= 0) { dungeonEnd(false); return; }
    if (D.left === 0) { D.clearT += dt; if (D.clearT > (S.autoArise ? 1.8 : 3)) { if (D.room >= D.rooms) { dungeonEnd(true); return; } nextRoom(); } }
  } else if (G.mode === 'siege' && G.SG) {
    const SG = G.SG;
    if (SG.spawnLeft > 0) { SG.spawnT -= dt; if (SG.spawnT <= 0 && G.enemies.filter(e => !e.dead).length < 22) { SG.spawnT = 0.5; SG.spawnLeft--; siegeSpawn(); } }
    else if (!G.enemies.some(e => !e.dead)) { SG.pause -= dt; if (SG.pause <= 0) { SG.pause = 2; nextWave(); } }
    if (SG.crystal <= 0) { siegeEnd(); return; }
  }
  // taux d'or (60 s glissantes)
  while (G.gr.length && G.gr[0][0] < G.time - 60) G.gr.shift();
  G.goldRate = G.gr.reduce((a, b) => a + b[1], 0) / Math.min(60, Math.max(10, G.time));
}
function hurtPlayer(e) {
  const P = G.P; if (P.dead > 0 || G.mode === 'hub' || !G.enemies.includes(e) || e.dead) return;
  const st = stats(); const dmg = zoneDmg(e.z) * Math.pow(RANK_MULT[e.r], 0.55) * (e.boss ? 3 : 1) * e.dmgMul;
  const dmgS = G.mode === 'siege' ? 3 * Math.pow(1.19, G.SG?.wave || 1) * (e.boss ? 3 : 1) : dmg;
  const real = dmgS / (1 + G.army.length * 0.04);
  P.hp -= real; P.hurtT = 3; UI.dmg(P.pos, real, 'hurt', 1); UI.hurtFlash();
  if (P.hp <= 0) { P.hp = 0; P.dead = 3; P.ch.play('death', { once: true, restart: true }); UI.banner('TU ES TOMBÉ', 'Tes ombres te relèvent…', '#ff3355'); P.target = null; }
}
export function enterBreach() { if (!G.breach) return; const b = G.breach; startDungeon(-1, b); }
function lerpAng(a, b, t) { let d = ((b - a + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI; return a + d * Math.min(1, t); }

export function initGame() {
  checkQuests(); G.P = makePlayer();
  // gains hors-ligne
  const away = (Date.now() - S.last) / 1000;
  if (S.shadows.length && away > 120) {
    const t = Math.min(away, 8 * 3600); const st = stats();
    const g = zoneHp(Math.max(0, zMaxUnlocked())) * st.gold * t / 6 * 0.3;
    S.gold += g; S.keys = Math.min(KEY_MAX, S.keys + Math.floor(t / KEY_REGEN));
    setTimeout(() => UI.result('TES OMBRES ONT CHASSÉ', '#c26bff', [['Absence', Math.floor(t / 60) + ' min'], ['Or récolté', fmt(g)]], null), 900);
  }
  enterHub();
}

/* =========================================================
   FILONS DE RESSOURCES
   ========================================================= */
const NODE_T = { minerai: { col: 0x38bdf8, prop: 'n:Rock_Medium_2', name: 'Ombracier' }, bois: { col: 0xf59e0b, prop: 'n:TwistedTree_1', name: 'Bois-de-nuit' }, essence: { col: 0xe879f9, prop: 'h:gravestone', name: 'Essence' } };
const ZONE_RES = [['minerai', 'bois', 'bois'], ['minerai', 'essence', 'essence'], ['minerai', 'bois', 'essence']];
function spawnNode(z) {
  const type = pick(ZONE_RES[z]); const T = NODE_T[type];
  const g = new THREE.Group(); const src = E.gltf[T.prop];
  if (src) { const m = src.scene.clone(true); m.scale.setScalar(type === 'bois' ? 0.55 : type === 'minerai' ? 0.9 : 1.3); m.traverse(o => { if (o.isMesh) { o.castShadow = true; o.material = new THREE.MeshLambertMaterial({ map: o.material.map, color: type === 'minerai' ? 0x5a6a80 : 0xffffff }); } }); g.add(m); }
  const gem = new THREE.Group();
  for (let i = 0; i < 4; i++) { const c = new THREE.Mesh(new THREE.OctahedronGeometry(0.35 + Math.random() * 0.25, 0), new THREE.MeshLambertMaterial({ color: T.col, emissive: T.col, emissiveIntensity: 0.9 })); c.scale.y = 1.8; c.position.set(Math.cos(i * 1.7) * 0.6, 1 + Math.random() * 0.6, Math.sin(i * 1.7) * 0.6); c.rotation.z = (Math.random() - 0.5) * 0.8; gem.add(c); }
  g.add(gem);
  const glow = new THREE.Mesh(new THREE.CircleGeometry(1.8, 24), new THREE.MeshBasicMaterial({ map: E.glowTex, color: T.col, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false })); glow.rotation.x = -Math.PI / 2; glow.position.y = 0.06; g.add(glow);
  E.world.add(g);
  const n = { type, z, g, gem, pos: g.position, hp: 0, max: 8, respawn: 0 }; relocateNode(n); G.nodes.push(n); return n;
}
function relocateNode(n) {
  const a = rnd(0, 6.28), r = rnd(10, 46); n.pos.set(Math.cos(a) * r, 0, Math.sin(a) * r); collide(n.pos, 1, 50);
  n.hp = n.max; n.g.visible = true; n.g.scale.setScalar(1);
}
function nearestNode(p, maxD, skew = 0) {
  let best = null, bd = maxD; for (const n of G.nodes) { if (n.hp <= 0) continue; const d = n.pos.distanceTo(p) + (skew % 3) * 0.01; if (d < bd) { bd = d; best = n; } } return best;
}
function mineNode(n, k) {
  if (n.hp <= 0) return;
  n.hp -= k; const amt = Math.max(1, Math.round(rnd(1, 2.2) * Math.pow(3, n.z) * k * 2));
  DM.dom().res[n.type] += amt; UI.dmgText(n.pos.clone().setY(0.6), `+${fmt(amt)} ${NODE_T[n.type].name}`, 'res res-' + n.type);
  burst(n.pos.clone().setY(1.2), NODE_T[n.type].col, 7, { speed: 3 }); SFX.hit();
  n.g.scale.setScalar(0.85 + 0.15 * (n.hp / n.max));
  if (n.hp <= 0) { n.g.visible = false; n.respawn = 25; shock(n.pos, NODE_T[n.type].col, 3, 0.5); const bonus = amt * 4; DM.dom().res[n.type] += bonus; UI.dmgText(n.pos, `Filon épuisé +${fmt(bonus)}`, 'res'); SFX.play('coins', 0.3); }
}

/* =========================================================
   AVANT-POSTES DES QUARTIERS (dans les zones)
   ========================================================= */
function buildOutposts(z) {
  const ds = DM.DISTRICTS.filter(d => d.z === z);
  ds.forEach((d, i) => {
    const a = -0.95 + i * 0.95; const x = Math.sin(a) * 40, zz = -Math.cos(a) * 40;
    const st = DM.dom().d[d.id]; const own = st.owner === 'joueur'; const col = new THREE.Color(DM.FACTIONS[st.owner].col).getHex();
    const g = new THREE.Group(); g.position.set(x, 0, zz);
    const src = E.gltf['x:building_tower_B_blue']; if (src) { const t = src.scene.clone(true); t.scale.setScalar(4.5); t.traverse(o => { if (o.isMesh) { o.castShadow = true; o.material = new THREE.MeshLambertMaterial({ map: o.material.map, color: own ? 0xc9b6ff : 0xffffff, emissive: own ? 0x2a0a5a : 0, emissiveIntensity: 0.6 }); } }); g.add(t); }
    for (const s of [-1, 1]) { const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 6), new THREE.MeshLambertMaterial({ color: 0x333333 })); pole.position.set(s * 3.4, 3, 2); g.add(pole);
      const fl = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 2.4), new THREE.MeshLambertMaterial({ color: col, emissive: col, emissiveIntensity: 0.35, side: THREE.DoubleSide })); fl.position.set(s * 3.4 + 0.85, 4.6, 2); g.add(fl);
      E.anim.push(() => { fl.rotation.y = Math.sin(E.t * 2 + s) * 0.25; }); }
    const ring = new THREE.Mesh(new THREE.RingGeometry(5.6, 6.1, 48), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.06; g.add(ring);
    E.world.add(g); E.colliders.push({ x, z: zz, r: 2.4 });
    G.info.stations.push({ id: 'district', did: d.id, x: x * 0.86, z: zz * 0.86, label: `${d.name} · ${own ? 'ton quartier' : DM.FACTIONS[st.owner].name}`, col: DM.FACTIONS[st.owner].col });
    // garde de faction devant les quartiers ennemis
    if (!own) for (let k = 0; k < 2; k++) {
      const def = factionSoldier(st.owner === 'joueur' ? d.fac : st.owner, d); const p = V(x * 0.8 + (k ? 2.5 : -2.5), 0, zz * 0.8);
      const e = spawnEnemy(def, z, ZONES[z].mobs[0].r + 1, zoneHp(z) * 2 * d.diff, p, { dmgMul: 1.2 }); e.home = p.clone(); e.guard = true;
    }
  });
}
const KEEP = { Knight: ['1H_Sword', 'Round_Shield', 'Knight_'], Barbarian: ['2H_Axe', 'Barbarian_'], Mage: ['2H_Staff', 'Mage_'], Rogue_Hooded: ['Knife', 'Rogue_'] };
const SOLDIERS = { lames: ['Knight', 'Barbarian'], bandits: ['Rogue_Hooded', 'Barbarian'], culte: ['Mage', 'Rogue_Hooded'], sel: ['Barbarian', 'Knight'], couronne: ['Knight', 'Mage'] };
function factionSoldier(fac, d, cap) {
  const F = DM.FACTIONS[fac]; const m = cap ? cap.model : pick(SOLDIERS[fac] || ['Knight']);
  return { m, name: cap ? cap.name : ({ lames: 'Lame Grise', bandits: 'Pillard', culte: 'Acolyte', sel: 'Garde du Sel', couronne: 'Chevalier Déchu' }[fac] || 'Soldat'), s: cap ? 1.35 : 1, hp: 1, keep: KEEP[m], tint: new THREE.Color(F.col).getHex() };
}

/* =========================================================
   ASSAUTS DE QUARTIER (conquête, révolte, défense)
   ========================================================= */
export function startAssault(did, kind = 'conquete') {
  const d = DM.DISTRICTS.find(x => x.id === did), st = DM.dom().d[did];
  if (kind === 'conquete' && S.lvl < ZONES[d.z].req) return UI.toast('Zone non débloquée', 'bad');
  const fac = kind === 'conquete' ? st.owner : d.fac;
  G.mode = 'assault'; G.zone = d.z; G.D = null; G.SG = null;
  enter('dungeon', { tint: new THREE.Color(DM.FACTIONS[fac].col).getHex() });
  const base = kind === 'conquete' ? DM.defPower(did) : 60 * Math.pow(200, d.z) * d.diff * (kind === 'revolte' ? 0.8 : 1.2);
  G.A = { did, d, kind, fac, wave: 0, waves: 3, time: 200, base, left: 0, tot: 0, pause: 0, gold0: S.gold };
  UI.zoneTitle(kind === 'conquete' ? `Assaut : ${d.name}` : kind === 'defense' ? `Défense : ${d.name}` : `Révolte : ${d.name}`, DM.FACTIONS[fac].name); SFX.music('dungeon');
  nextAssaultWave();
}
function nextAssaultWave() {
  const A = G.A; A.wave++; const last = A.wave === A.waves; const z = A.d.z;
  const n = (kind => kind === 'conquete' ? 5 : 6)(A.kind) + A.wave * 2;
  for (let i = 0; i < n; i++) { const a = rnd(Math.PI * 1.1, Math.PI * 1.9); const r = rnd(8, G.info.R - 3);
    const e = spawnEnemy(factionSoldier(A.fac, A.d), z, ZONES[z].mobs[0].r + 1, A.base * Math.pow(1.25, A.wave), V(Math.cos(a) * r, 0, Math.sin(a) * r), { dmgMul: 1.3 }); e.st = 'chase'; }
  if (last) { const cap = A.d.cap && A.kind === 'conquete' ? DM.CAPTAINS[A.d.cap] : null;
    const e = spawnEnemy(factionSoldier(A.fac, A.d, cap || { name: 'Capitaine', model: DM.FACTIONS[A.fac].model }), z, ZONES[z].boss.r, A.base * 14, V(0, 0, -10), { boss: true, dmgMul: 1.5 }); e.st = 'chase'; e.captain = true;
    UI.banner(cap ? cap.name : 'LE CAPITAINE', 'défend ' + A.d.name, DM.FACTIONS[A.fac].col); SFX.play('bell'); }
  else UI.banner(`VAGUE ${A.wave} / ${A.waves}`, DM.FACTIONS[A.fac].name, DM.FACTIONS[A.fac].col);
  A.tot = G.enemies.filter(e => !e.dead).length; A.left = A.tot;
}
function updateAssault(dt) {
  const A = G.A; A.time -= dt; A.left = G.enemies.filter(e => !e.dead).length;
  if (A.time <= 0) return assaultEnd(false);
  if (A.left === 0) { A.pause += dt; if (A.pause > 2) { A.pause = 0; if (A.wave >= A.waves) return assaultEnd(true); nextAssaultWave(); } }
}
function assaultEnd(win) {
  const A = G.A; G.A = null; const D = DM.dom(), st = D.d[A.did]; const z = A.d.z;
  const loot = { minerai: Math.round(60 * Math.pow(3, z) * A.d.diff), bois: Math.round(60 * Math.pow(3, z) * A.d.diff), essence: Math.round(15 * Math.pow(3, z)) };
  let lines = [];
  if (win) {
    for (const k in loot) D.res[k] += loot[k];
    if (A.kind === 'conquete') { st.owner = 'joueur'; st.loy = 35; st.held = 0; st.workers = 0; D.att[A.fac] = Math.max(-100, D.att[A.fac] - 20); DM.addRenom(80 * (z + 1)); D.pending.unshift({ id: 'capture', d: A.did, cap: A.d.cap }); }
    else { st.owner = 'joueur'; st.loy = Math.max(st.loy, 50); st.calm = 1; DM.addRenom(30 * (z + 1)); }
    lines = [['Quartier', A.d.name], ['Ombracier', '+' + fmt(loot.minerai)], ['Bois-de-nuit', '+' + fmt(loot.bois)], ['Essence', '+' + fmt(loot.essence)], ['Or', fmt(S.gold - A.gold0)], ['Renommée', fmt(D.renom) + ' · ' + DM.titleName()]];
  } else {
    if (A.kind !== 'conquete') { st.owner = A.fac; st.gov = null; DM.addRenom(-40); }
    lines = [['Quartier', A.d.name], ['Résultat', A.kind === 'conquete' ? 'L’ennemi tient bon' : 'Quartier perdu']];
  }
  SFX.play(win ? 'win' : 'lose', 0.7); save();
  UI.result(win ? (A.kind === 'conquete' ? 'QUARTIER CONQUIS' : 'ORDRE RÉTABLI') : 'ASSAUT REPOUSSÉ', win ? '#c26bff' : '#ff3355', lines, () => { enterZone(z); if (win && A.kind === 'conquete') setTimeout(() => UI.openDialogue(), 400); });
}
export const domainApi = {
  power: () => power(), zMax: () => zMaxUnlocked(),
  assault: (did, kind) => { UI.close(); startAssault(did, kind); },
  captainShadow(d, cap) {
    const z = d.z ?? 0; const m = cap?.model || 'Knight';
    const s = { id: S.nextId++, m, name: (cap?.name || 'Capitaine') + ' (Ombre)', z, boss: true, r: Math.min(8, ZONES[z].boss.r + 1), lvl: 1, st: [rollGrade(0.5), rollGrade(0.5), rollGrade(0.5), rollGrade(0.5)], eq: false, lock: true, keep: KEEP[m], sc: 1.15 };
    S.shadows.push(s); autoEquip(); UI.ariseCard(s, true); S.arises++;
  },
};

/* =========================================================
   CITOYENS DE LA CITADELLE — ils reconnaissent ta puissance
   ========================================================= */
const SAY = [
  ['Encore un chasseur…', 'Tu crois faire peur à qui ?', 'Pousse-toi, gamin.'],
  ["C'est le chasseur d'ombres !", 'On dit que tu relèves les morts…', 'Bonne chasse, Veilleur.'],
  ['Place ! Le Seigneur de guerre passe !', 'Mes respects, seigneur.', 'Mon fils veut rejoindre vos ombres !'],
  ['Gloire au Souverain !', 'Votre Domaine nous protège, majesté.', 'Nous vous devons tout.'],
  ['À genoux… le Monarque des Ombres.', 'Les morts eux-mêmes vous obéissent…', 'Monarque ! Monarque !'],
];
function spawnCitizens() {
  const models = ['Knight', 'Barbarian', 'Mage', 'Rogue_Hooded', 'Barbarian', 'Knight', 'Mage'];
  const tints = [0xd6c7a8, 0xb8d0e8, 0xe8c8d8, 0xc8e8c0, 0xe0d0b0, 0xd0d0ff, 0xffe0c0];
  models.forEach((m, i) => {
    const ch = makeChar(m, { keep: [m === 'Rogue_Hooded' ? 'Rogue_' : m + '_'], tint: tints[i] });
    const a = rnd(0, 6.28), r = rnd(9, 15); ch.root.position.set(Math.cos(a) * r, 0, Math.sin(a) * r); E.scene.add(ch.root);
    G.cits.push({ ch, pos: ch.root.position, t: rnd(0, 3), dir: V(), cd: 0, guard: i < 2 });
  });
}
function updateCitizens(dt) {
  const t = DM.title(); const P = G.P;
  for (const c of G.cits) {
    c.cd -= dt; const d = c.pos.distanceTo(P.pos);
    if (d < 6 && c.cd <= 0) {
      c.cd = 14; c.hold = 2.2; c.ch.root.rotation.y = Math.atan2(P.pos.x - c.pos.x, P.pos.z - c.pos.z);
      c.ch.play(t >= 2 ? 'cheer' : t >= 1 ? 'idle' : 'idle', { once: t >= 2, restart: true });
      UI.say(c.pos, pick(SAY[t]));
    }
    if (c.hold > 0) { c.hold -= dt; c.ch.update(dt); continue; }
    c.t -= dt; if (c.t <= 0) { c.t = rnd(2, 5); c.dir.set(rnd(-1, 1), 0, rnd(-1, 1)).normalize(); if (c.pos.length() > 16) c.dir.set(-c.pos.x, 0, -c.pos.z).normalize(); c.walk = rnd(1, 2.5); }
    if (c.walk > 0) { c.walk -= dt; c.pos.addScaledVector(c.dir, dt * 1.8); c.ch.root.rotation.y = Math.atan2(c.dir.x, c.dir.z); c.ch.play('walk'); } else c.ch.play('idle');
    collide(c.pos, 0.4, 30); c.ch.update(dt);
  }
}
