/* UMBRA — boucle de jeu : héros (vie/mana), camps de monstres, armée mortelle, butin, sanctuaire, îles, portails, tour, événements */
import { E, makeChar, attachWeapon, buildWorld, collide, burst, slash, shock, pillar, projectile, portalMesh } from './engine.js';
import { WEAPONS, RELICS, ACCS, WORLDS, FOES, STAGES, RAR, W_MAXSTAR, R_MAXLV, A_MAXLV, tierOf, foeHp, foeCash, mission, xpNeed, armyMax, SRANKS, SRANK_COL, shadowPow,
  rollRankW, WORLD_RW, rkMin, rkMax, dungeonRW, PORTAL_RW, DUNGEONS, DG_TIME, DG_WAVES, UNIQUES, TRAITS, TRAIT_N, traitVal, shadowName, SUMMON, NPCS,
  TW_TIME, twTier, twRank, twCount, SPIN_CD, MANA_WAVE, MANA_RECALL, rnd, pick, clamp } from './data.js';
import { S, save, bonus, dirty, heroDmg, heroHp, heroMp, shDmg, equipped, relicSlotsN, power, armyCap } from './state.js';
import { UI } from './ui.js';
import { SFX } from './audio.js';

const THREE = E.THREE; const V = (x, y, z) => new THREE.Vector3(x, y, z);
export const G = { foes: [], souls: [], army: [], fallen: [], camps: [], chests: [], npcs: [], joy: { x: 0, y: 0 }, info: null, boss: null, legend: null, horde: null, buff: null,
  dps: 0, dmgWin: [], dead: 0, t: 0, dg: null, portal: null, portalT: 60, evT: 120, near: null, waveCd: 0, combat: false };
const W = () => WORLDS[Math.max(0, S.world)];
const inWorld = () => S.world >= 0 && !G.dg;
const tierNow = () => G.dg ? G.dg.tier : S.world < 0 ? tierOf(S.maxWorld, 0) : tierOf(S.world, Math.min(S.stage[S.world], STAGES - 1));
const prop = k => (inWorld() ? (W().prop[k] || 1) : 1) * (G.buff && G.buff[k] || 1);
const RANK_HEX = r => new THREE.Color(RAR[r].c).getHex();
const srcRW = () => G.dg ? G.dg.rw : WORLD_RW[Math.max(0, S.world)];

/* ---------- héros ---------- */
function makeHero() {
  const w = WEAPONS.find(x => x.id === S.wEq);
  const ch = makeChar('Rogue_Hooded', { tint: '#8f80d8', eyeCol: 0x9ff3ff, weapon: w.model, wcol: w.glow });
  E.scene.add(ch.root);
  const aura = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.25, 40), new THREE.MeshBasicMaterial({ color: 0x8b5cf6, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false }));
  aura.rotation.x = -Math.PI / 2; aura.position.y = 0.05; ch.root.add(aura);
  return { ch, pos: V(0, 0, 0), hp: 1, mp: 0, ang: 0, atkCd: 0, moving: false, tgt: null, aura, stuck: 0, lastD: 0, det: 0, detDir: 1 };
}
export function refreshWeapon() { const w = WEAPONS.find(x => x.id === S.wEq); attachWeapon(G.P.ch.mdl, w.model, w.glow); G.P.aura.material.color.set(w.glow || 0x8b5cf6); }

/* ---------- changement de lieu ---------- */
function clearScene() {
  for (const f of G.foes) f.ch.dispose(); for (const s of G.souls) s.obj.removeFromParent(); for (const a of G.army) a.ch.dispose(); for (const n of G.npcs) n.ch.dispose();
  for (const c of G.chests) c.obj?.removeFromParent();
  if (G.portal) G.portal.obj.removeFromParent(); if (G.bossPortal) G.bossPortal.obj.removeFromParent();
  Object.assign(G, { foes: [], souls: [], army: [], fallen: [], camps: [], chests: [], npcs: [], boss: null, legend: null, horde: null, portal: null, bossPortal: null, near: null, dead: 0, bossSkip: 0 });
  if (G.buff) { G.buff = null; UI.moon(false); }
}
function arrive(full = true) { const P = G.P; P.pos.copy(G.info.spawn); P.tgt = null; if (full) { P.hp = heroHp(); P.mp = heroMp(); } syncArmy(); }
export function enterHub() {
  S.world = -1; G.dg = null; clearScene(); G.info = buildWorld('hub', { npcs: NPCS }); arrive(); E.pitch = 0.5; E.dist = 32; E.yaw = 0.42; SFX.music('hub');
  for (const n of G.info.npcs) { const ch = makeChar(n.model, { tint: n.tint, eyeCol: 0xffffff }); ch.root.position.set(n.x, 0, n.z); ch.root.rotation.y = Math.atan2(-n.x, -n.z); E.scene.add(ch.root); G.npcs.push({ ...n, ch, pos: V(n.x, 0, n.z) }); }
  UI.zoneTitle('Sanctuaire des Ombres', 'Le refuge des éveillés — parle aux habitants', '#c26bff'); save();
}
export function enterWorld(i) {
  if (i < 0) return enterHub();
  if (S.world !== i) S.prog = { kills: 0, brutes: 0 };
  S.world = i; G.dg = null; clearScene(); G.portalT = rnd(50, 90); G.evT = rnd(90, 150);
  G.info = buildWorld(W().env); arrive(); E.pitch = 0.88; E.dist = 25; SFX.music(W().music);
  for (const c of G.info.sites.camps) {
    const camp = { id: G.camps.length, slots: [] }; const n = (c.k ? 2 : 4) + (W().prop.pack ? 2 : 0);
    if (c.k) camp.slots.push({ home: V(c.x, 0, c.z), kind: 1, f: null, t: 0, camp });
    for (let j = 0; j < n; j++) { const a = j / n * 6.28 + rnd(0, 0.5), r = rnd(4, 8); camp.slots.push({ home: V(c.x + Math.cos(a) * r, 0, c.z + Math.sin(a) * r), kind: 0, f: null, t: 0, camp }); }
    G.camps.push(camp);
  }
  for (const c of G.info.sites.chests) G.chests.push({ pos: V(c.x, 0, c.z), obj: null, t: 0 });
  const rw = WORLD_RW[i];
  UI.zoneTitle(W().n, `Île de rang ${SRANKS[rkMin(rw)]} à ${SRANKS[rkMax(rw)]} — palier ${Math.min(S.stage[i] + 1, STAGES)}/${STAGES}`, W().col);
  checkMission(); save();
}
export function initGame() { G.P = makeHero(); enterWorld(S.world); }

/* ---------- donjons (portails) et Tour de l'Ascension ---------- */
function startDg(dg) { const back = G.dg ? G.dg.back : S.world; clearScene(); G.dg = Object.assign({ wave: -1, wait: 1.8, phase: 'wave', end: 0, res: null, back }, dg); G.info = buildWorld('dungeon', { tint: dg.tint }); arrive(); E.pitch = 0.92; E.dist = 22; SFX.music('dungeon'); }
export function enterDungeon(r, viaKey) {
  if (viaKey) { if (!S.keys[r]) return; S.keys[r]--; }
  const D = DUNGEONS[r];
  startDg({ r, D, tier: D.tier, t: DG_TIME, foes: D.foes, rw: dungeonRW(r), tint: RANK_HEX(r) });
  UI.zoneTitle(`Portail rang ${SRANKS[r]}`, `${D.n} — ${DG_WAVES.length} vagues puis le boss · ${Math.round(DG_TIME / 60)} min`, RAR[r].c);
}
export function enterTower() {
  const f = Math.max(1, S.tower - 1);
  startDg({ tower: true, floor: f - 1, r: twRank(f), tier: twTier(f), t: TW_TIME, foes: DUNGEONS[twRank(f)].foes, rw: dungeonRW(twRank(f)), tint: 0xc26bff });
  UI.zoneTitle('Tour de l\'Ascension', `Départ à l'étage ${f} — chaque étage est plus dur que le précédent`, '#c26bff');
}
const dgRank = k => { const r = G.dg.r; return k || r === 0 ? r : Math.random() < 0.6 ? r - 1 : r; };
function nextWave() {
  const dg = G.dg;
  if (dg.tower) {
    if (dg.wave >= 0) towerReward(dg.floor);
    dg.wave++; dg.floor++; const f = dg.floor; Object.assign(dg, { r: twRank(f), tier: twTier(f), t: TW_TIME, foes: DUNGEONS[twRank(f)].foes, rw: dungeonRW(twRank(f)) });
    UI.banner(`ÉTAGE ${f}`, f % 5 === 0 ? 'Étage de gardien !' : `Rang ${SRANKS[dg.r]}`, f % 5 === 0 ? '#ff3355' : '#c26bff'); SFX.play('bell', 0.5);
    for (let i = 0; i < twCount(f); i++) spawnFoe(Math.random() < 0.15 ? 1 : 0);
    if (f % 5 === 0) spawnFoe(2, V(0, 0, -6), { type: DUNGEONS[dg.r].foes[0], n: `Gardien de l'étage ${f}` });
    G.P.hp = Math.min(heroHp(), G.P.hp + heroHp() * 0.3); G.P.mp = Math.min(heroMp(), G.P.mp + heroMp() * 0.3);
    return;
  }
  dg.wave++;
  if (dg.wave < DG_WAVES.length) { UI.banner(`VAGUE ${dg.wave + 1} / ${DG_WAVES.length}`, dg.D.n, RAR[dg.r].c); SFX.play('bell', 0.5); for (let i = 0; i < DG_WAVES[dg.wave]; i++) spawnFoe(Math.random() < 0.18 ? 1 : 0); }
  else { dg.phase = 'boss'; const p = V(0, 0, -6); const pm = portalMesh(RANK_HEX(dg.r), 1.8); pm.position.copy(p); E.scene.add(pm); G.bossPortal = { obj: pm, t: 2.2, p, u: dg.D.boss }; UI.banner('LE BOSS ARRIVE', `${UNIQUES[dg.D.boss].n}, ${UNIQUES[dg.D.boss].t}`, '#ff3355'); SFX.play('bell', 0.8); E.shake = 0.5; }
}
function towerReward(f) {
  const b = bonus(); const g = Math.ceil((4 + f) * (1 + b.gems / 100)), c = foeCash(twTier(f)) * 40 * (1 + b.cash / 100); S.gems += g; S.cash += c;
  const loot = [['cash', c], ['gems', g]];
  if (f > S.tower) { S.tower = f; if (f % 5 === 0) { const it = rollItem(RELICS, dungeonRW(twRank(f)), b.luck); giveRelic(it.id); loot.push(['rel', it.id]); if (Math.random() < 0.5) { const kr = Math.min(6, twRank(f)); S.keys[kr]++; UI.toast(`Clé de portail rang ${SRANKS[kr]} !`, 'gold'); } } }
  UI.loot(loot);
}
function dgTick(dt) {
  const dg = G.dg; if (dg.end) { dg.end -= dt; if (dg.end <= 0) { UI.close(); enterWorld(dg.back); } return; }
  dg.t -= dt; if (dg.t <= 0) return dgFail('Le temps est écoulé');
  if (dg.phase === 'wave' && G.foes.length === 0 && (dg.wait -= dt) <= 0) { dg.wait = 1.5; nextWave(); }
}
function dungeonWin(f) {
  const dg = G.dg, r = dg.r; dg.phase = 'won'; dg.end = 25; S.dgDone[r]++;
  const b = bonus(), rw = dg.rw, luck = b.luck;
  const res = { cash: foeCash(dg.tier) * 150 * (1 + b.cash / 100), gems: Math.ceil(30 * Math.pow(r + 1, 2) * (1 + b.gems / 100)), items: [] };
  S.cash += res.cash; S.gems += res.gems;
  const rel = rollItem(RELICS, rw, luck); giveRelic(rel.id); res.items.push(['rel', rel.id]);
  if (Math.random() < 0.45) { const a = rollItem(ACCS, rw, luck); giveAcc(a.id); res.items.push(['acc', a.id]); }
  if (Math.random() < 0.3) { const w = rollItem(WEAPONS, rw, luck); giveWeapon(w.id); res.items.push(['w', w.id]); }
  if (Math.random() < 0.35) { S.keys[r]++; res.key = r; }
  dg.res = res; pillar(f.pos, 0xffcc33, 14); E.shake = 0.6; SFX.play('win', 0.8);
  UI.banner('DONJON TERMINÉ !', `Éveille ${UNIQUES[dg.D.boss].n} avant qu'il ne disparaisse`, RAR[r].c);
  setTimeout(() => G.dg === dg && UI.dungeonResult(dg), 2500); save();
}
function dgFail(why) {
  const dg = G.dg; if (!dg || dg.end) return; dg.phase = 'lost'; dg.end = 4;
  for (const f of G.foes) if (!f.dead) { f.dead = 1; f.deathT = 0.1; }
  if (dg.tower) UI.banner('FIN DE L\'ASCENSION', `Étage atteint : ${dg.floor} · record : ${S.tower}`, '#c26bff'); else UI.banner('ÉCHEC DU DONJON', why + ' — renforce-toi avant de revenir', '#ff3355');
  SFX.play('lose', 0.7); save();
}
export function leaveDungeon() { if (G.dg) G.dg.end = 0.01; }

/* ---------- portails, coffres, événements des îles ---------- */
function worldTick(dt) {
  const P = G.P, S0 = G.info.sites;
  // camps : réapparition à place fixe
  for (const c of G.camps) for (const s of c.slots) if (!s.f && (s.t -= dt) <= 0) { s.f = spawnFoe(s.kind, s.home, { slot: s }); }
  // coffres
  for (const c of G.chests) {
    if (!c.obj) { if ((c.t -= dt) <= 0) { const g = new THREE.Group(); const m = E.gltf['d:chest_gold'].scene.clone(true); m.scale.setScalar(1.3); g.add(m); const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: E.glowTex, color: 0xffcc33, blending: THREE.AdditiveBlending, depthWrite: false })); s.scale.setScalar(4); s.position.y = 1; g.add(s); g.position.copy(c.pos); E.scene.add(g); c.obj = g; c.s = s; } }
    else { c.s.material.opacity = 0.6 + Math.sin(G.t * 4) * 0.3; if (c.pos.distanceTo(P.pos) < 2.8 && !G.dead) openChest(c); }
  }
  // portail
  if (!G.portal) {
    if ((G.portalT -= dt) <= 0) {
      const r = rollRankW(PORTAL_RW[S.world]); const nd = pick(S0.nodes.filter(n => Math.hypot(n.x - P.pos.x, n.z - P.pos.z) > 20)); const p = V(nd.x, 0, nd.z);
      const obj = new THREE.Group(); obj.add(portalMesh(RANK_HEX(r), 1.5));
      const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.9, 60, 16, 1, true), new THREE.MeshBasicMaterial({ color: RANK_HEX(r), transparent: true, opacity: 0.14, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
      beam.position.y = 30; obj.add(beam); obj.position.copy(p); E.scene.add(obj);
      G.portal = { r, pos: p, obj, beam, life: 300 }; UI.toast(`Un portail de rang ${SRANKS[r]} s'est ouvert !`, r >= 3 ? 'gold' : ''); SFX.play('ping', 0.6);
    }
  } else { const pt = G.portal; pt.life -= dt; pt.beam.material.opacity = 0.12 + Math.sin(G.t * 3) * 0.05; if (pt.life <= 0) { pt.obj.removeFromParent(); G.portal = null; G.portalT = rnd(120, 200); UI.toast('Le portail s\'est refermé…', 'bad'); } }
  // événements
  if (G.buff && (G.buff.t -= dt) <= 0) { G.buff = null; UI.moon(false); UI.toast('La Lune de sang se couche.'); }
  if (G.legend && !G.legend.dead && !G.legend.aggro && (G.legend.life -= dt) <= 0) { G.legend.dead = 1; G.legend.deathT = 0.1; G.legend = null; UI.toast('Le boss légendaire s\'est retiré dans l\'ombre…', 'bad'); }
  if (G.horde && (G.horde.t -= dt) <= 0) { for (const f of G.foes) if (f.horde && !f.dead) { f.dead = 1; f.deathT = 0.1; } G.horde = null; UI.toast('L\'invasion s\'est dispersée.', 'bad'); }
  if ((G.evT -= dt) > 0) return; G.evT = rnd(150, 230);
  const o = []; if (!G.legend) o.push('legend', 'legend'); if (!G.horde) o.push('horde', 'horde'); if (!G.buff) o.push('lune'); const ev = pick(o);
  if (ev === 'legend') { const u = W().leg; const f = spawnFoe(2, V(S0.lair.x, 0, S0.lair.z), { u, leg: true, mult: 6 }); f.life = 360; UI.banner('BOSS LÉGENDAIRE', `${UNIQUES[u].n}, ${UNIQUES[u].t} est apparu — suis la flèche dorée`, '#ffcc33'); SFX.play('bell', 0.9); E.shake = 0.4; }
  else if (ev === 'horde') {
    const nd = pick(S0.nodes.filter(n => Math.hypot(n.x - P.pos.x, n.z - P.pos.z) > 30)); const camp = { id: 'horde' };
    for (let i = 0; i < 10; i++) { const a = i / 10 * 6.28; const f = spawnFoe(i ? 0 : 1, V(nd.x + Math.cos(a) * (i ? 4 : 0), 0, nd.z + Math.sin(a) * (i ? 4 : 0)), { camp }); f.horde = 1; }
    G.horde = { pos: V(nd.x, 0, nd.z), t: 180, left: 10 }; UI.banner('INVASION !', 'Une horde bloque un carrefour — repousse-la pour un trésor', '#ff7a45'); SFX.play('bell', 0.7);
  } else { G.buff = { luck: 2, arise: 1.5, t: 120 }; UI.moon(true); UI.banner('LUNE DE SANG', 'Butin rare ×2 et Éveil ×1,5 pendant 2 minutes', '#ff3355'); SFX.play('seal', 0.7); }
}
function openChest(c) {
  c.obj.removeFromParent(); c.obj = null; c.t = rnd(180, 260); S.st.chests++; const b = bonus(), w = S.world;
  const cash = foeCash(tierNow()) * 60 * (1 + b.cash / 100), gems = Math.ceil(rnd(6, 14) * (w + 1) * (1 + b.gems / 100)); S.cash += cash; S.gems += gems; const loot = [['cash', cash], ['gems', gems]];
  if (Math.random() < 0.3) dropItem(loot, pick([0, 1, 2]));
  if (Math.random() < 0.12) { const kr = rollRankW(PORTAL_RW[w]); S.keys[kr]++; UI.toast(`Clé de portail rang ${SRANKS[kr]} !`, 'gold'); }
  UI.loot(loot); UI.dn(c.pos, 'COFFRE !', 'arise'); pillar(c.pos, 0xffcc33, 7); SFX.play('coins', 0.7);
}
export function enterPortal() { const pt = G.portal; if (!pt) return; G.portalT = rnd(120, 200); enterDungeon(pt.r, false); }
export function markers() {
  const m = []; if (!inWorld()) return m;
  if (G.boss && !G.boss.dead && !G.boss.aggro) m.push({ pos: G.boss.pos, n: 'BOSS DE L\'ÎLE', s: G.boss.n, c: '#ff3355' });
  if (G.legend && !G.legend.dead) m.push({ pos: G.legend.pos, n: 'BOSS LÉGENDAIRE', s: G.legend.n, c: '#ffcc33', t: G.legend.life });
  if (G.horde) m.push({ pos: G.horde.pos, n: 'INVASION', s: `${G.horde.left} ennemis`, c: '#ff7a45', t: G.horde.t });
  if (G.portal) m.push({ pos: G.portal.pos, n: `PORTAIL · RANG ${SRANKS[G.portal.r]}`, s: DUNGEONS[G.portal.r].n, c: RAR[G.portal.r].c, t: G.portal.life, portal: 1 });
  return m;
}
export function interact() { const n = G.near; if (!n) return; if (n.type === 'npc') { SFX.play('select', 0.5); UI.open(n.npc.panel); } else UI.open('donjons', 'portal'); }

/* ---------- ennemis ---------- */
let fid = 0;
function spawnFoe(kind, at, o = {}) {
  const dg = G.dg; const u = o.u || null; const type = u ? UNIQUES[u].foe : o.type || (dg ? pick(dg.foes) : kind === 1 ? W().brute : pick(W().foes));
  const F = FOES[type]; const n = u ? `${UNIQUES[u].n}, ${UNIQUES[u].t}` : o.n || F.n; const t = tierNow();
  const rw = srcRW(), r0 = rkMin(rw); let rk;
  if (u) rk = UNIQUES[u].rk; else if (dg) rk = dgRank(kind); else { rk = rollRankW(rw); if (kind === 1) rk = Math.min(rkMax(rw), rk + 1); }
  const unit = foeHp(t) * prop('hp') * (u ? 1 : 1 + 0.5 * Math.max(0, rk - r0));
  const hp = unit * (kind === 2 ? 40 : kind === 1 ? 6 : 1) * (o.mult || 1);
  const scale = (F.sc || 1) * (kind === 2 ? (o.leg ? 3 : 2.4) : kind === 1 ? 1.55 : 1);
  const tint = o.leg ? '#ffd27a' : dg ? new THREE.Color(F.tint).lerp(new THREE.Color(RAR[dg.r].c), 0.35).getStyle() : kind === 1 ? '#ff8a8a' : F.tint;
  const ch = makeChar(F.model, { tint, scale, eyeCol: kind ? 0xff3355 : 0xffd040 });
  let p = at ? at.clone() : null;
  if (!p) { const a = rnd(0, 6.28), r = rnd(6, 16); p = V(Math.cos(a) * r, 0, Math.sin(a) * r); collide(p, 1, G.info.R - 2); }
  ch.root.position.copy(p); ch.root.rotation.y = rnd(0, 6.28); E.scene.add(ch.root);
  const f = { id: ++fid, ch, pos: p, home: p.clone(), hp, max: hp, unit: unit * (o.leg ? 3 : 1), kind, type, u, n, t, rk, cd: rnd(0.5, 1.5), dmgPct: (kind === 2 ? 0.14 : kind === 1 ? 0.07 : 0.03) * (dg ? 0.55 : 1), wander: rnd(1, 4), wt: null, dead: 0,
    r: kind === 2 ? 2.2 : kind === 1 ? 1 : 0.6, aggro: !!dg, free: !!dg, ret: false, ar: kind === 2 ? 11 : kind === 1 ? 9 : 7.5, leash: kind === 2 ? 45 : 28, camp: o.camp || (o.slot && o.slot.camp) || null, slot: o.slot || null, leg: !!o.leg, tg: null, tgT: 0 };
  G.foes.push(f); if (kind === 2) { if (o.leg) G.legend = f; else G.boss = f; }
  if (kind && !o.slot) burst(p.clone().setY(1), kind === 2 ? 0xff3355 : 0xffaa33, 20, { spread: 1, speed: 4 });
  return f;
}
function nearestFoe(p, R, pred) { let b = null, bd = R; for (const f of G.foes) { if (f.dead || f.ret || (pred && !pred(f))) continue; const d = f.pos.distanceTo(p) - f.r; if (d < bd) { bd = d; b = f; } } return b; }
function aggro(f) { if (f.aggro || f.dead || f.ret) return; f.aggro = true; if (f.camp) for (const o of G.foes) if (o.camp === f.camp && !o.aggro && !o.dead && !o.ret && o.pos.distanceTo(f.pos) < 16) o.aggro = true; }
function hitFoe(f, dmg, crit, src, who) {
  if (f.dead || f.ret) return; aggro(f); f.hp -= dmg; G.dmgWin.push([G.t, dmg]);
  UI.dn(f.pos, dmg, crit ? 'crit' : src);
  if (f.hp <= 0) { if (who) who.kills = (who.kills || 0) + 1; killFoe(f); }
}
function killFoe(f) {
  f.dead = 1; f.hp = 0; f.ch.play('death', { once: true, restart: true }); f.deathT = 1.6;
  if (G.boss === f) G.boss = null; if (G.legend === f) G.legend = null;
  if (f.slot) { f.slot.f = null; f.slot.t = (S.world === 2 && !f.kind && Math.random() < 0.15) ? 2.5 : f.kind ? 32 : 18; }
  const b = bonus(), dg = G.dg;
  const km = (f.kind === 2 ? 40 : f.kind === 1 ? 6 : 1) * (f.leg ? 5 : 1);
  const cash = foeCash(f.t) * km * (1 + b.cash / 100) * prop('cash') * (dg ? 1.5 : 1);
  S.cash += cash; const loot = [['cash', cash]];
  const gch = f.kind === 2 ? 1 : f.kind === 1 ? 0.35 : 0.04;
  if (Math.random() < gch) { const g = Math.ceil((f.kind === 2 ? 40 : f.kind === 1 ? 6 : 1) * (f.leg ? 3 : 1) * (1 + f.t * 0.08) * (1 + b.gems / 100) * prop('gems')); S.gems += g; loot.push(['gems', g]); }
  gainXp(Math.ceil(3 * Math.pow(1.35, f.t) * km * prop('xp') * (dg ? 1.5 : 1)));
  S.st.kills++; bumpQ('kills'); if (f.kind === 1) { S.st.brutes++; bumpQ('brutes'); }
  rollDrops(f, loot); UI.loot(loot); addSoul(f);
  if (f.horde && G.horde && --G.horde.left <= 0) hordeWin();
  if (dg) { if (f.kind === 2 && !dg.tower) dungeonWin(f); }
  else if (f.leg) legendDown(f);
  else { if (f.kind === 0) S.prog.kills++; else if (f.kind === 1) S.prog.brutes++; if (f.kind === 2) bossDown(f); else checkMission(); }
  SFX.hit();
}
function hordeWin() {
  const h = G.horde; G.horde = null; const b = bonus(), w = S.world; const cash = foeCash(tierNow()) * 90 * (1 + b.cash / 100), gems = Math.ceil(20 * (w + 1) * (1 + b.gems / 100)); S.cash += cash; S.gems += gems;
  const loot = [['cash', cash], ['gems', gems]]; if (Math.random() < 0.6) dropItem(loot, pick([0, 1, 2])); UI.loot(loot); UI.banner('INVASION REPOUSSÉE', 'Le carrefour est libre', '#4ade80'); pillar(h.pos, 0x4ade80, 10); SFX.play('win', 0.6);
}
function legendDown(f) {
  S.st.bosses++; S.st.legends++; bumpQ('bosses'); const w = S.world, rw = WORLD_RW[w], top = rkMax(rw); const loot = [];
  const tw = [0, 0, 0, 0, 0, 0, 0]; tw[top] = 70; tw[Math.max(0, top - 1)] += 30; for (const k of [0, 1]) dropItem(loot, k, tw);
  const kr = rkMax(PORTAL_RW[w]); S.keys[kr]++; const g = Math.ceil(80 * (w + 1) * (1 + bonus().gems / 100)); S.gems += g; loot.push(['gems', g]); UI.loot(loot);
  UI.banner('LÉGENDE VAINCUE !', `Clé de rang ${SRANKS[kr]} obtenue — éveille son âme (25 %)`, '#ffcc33'); pillar(f.pos, 0xffcc33, 16); shock(f.pos, 0xffcc33, 12, 1); E.shake = 0.7; SFX.play('win', 0.9); save();
}

/* ---------- butin (rangs selon l'île ou le portail) ---------- */
function lucky(name, chance, col) { S.st.lucky++; UI.lucky(name, chance, col); SFX.play('win', 0.5); }
export function rollItem(list, rw, luck = 0) {
  let r = rollRankW(rw, luck); let pool = list.filter(x => x.r === r);
  while (!pool.length && r > 0) { r--; pool = list.filter(x => x.r === r); }
  return pick(pool);
}
const KINDS = [[WEAPONS, 'w', id => giveWeapon(id)], [RELICS, 'rel', id => giveRelic(id)], [ACCS, 'acc', id => giveAcc(id)]];
function dropItem(loot, k, rw = srcRW()) { const [list, key, give] = KINDS[k]; const it = rollItem(list, rw, bonus().luck); give(it.id); loot.push([key, it.id]); return it; }
function rollDrops(f, loot) {
  const L = (1 + bonus().luck / 100) * prop('luck'), rw = srcRW(), dgm = G.dg ? 2.5 : 1; const tot = rw.reduce((a, x) => a + x, 0), top = rkMax(rw);
  const base = [f.kind === 2 ? 0.3 : f.kind === 1 ? 0.03 : 0.0025, f.kind === 2 ? 0.18 : f.kind === 1 ? 0.015 : 0.001, f.kind === 2 ? 0.14 : f.kind === 1 ? 0.01 : 0.0008];
  for (let k = 0; k < 3; k++) { const ch = base[k] * L * dgm; if (Math.random() >= ch) continue; const it = dropItem(loot, k, rw); if (it.r >= top || it.r >= 4) lucky(it.n, ch * (rw[it.r] || 1) / tot, RAR[it.r].c); }
  if (inWorld() && f.kind === 2 && !f.leg && Math.random() < 0.4) { const kr = rollRankW(PORTAL_RW[S.world]); S.keys[kr]++; UI.toast(`Clé de portail rang ${SRANKS[kr]} obtenue !`, 'gold'); UI.dot('donjons'); }
}
export function rollRelic() { const r = rollItem(RELICS, SUMMON.rates.map(x => x * 1000), 0); giveRelic(r.id); return r; }
export function giveWeapon(id) { const it = S.w[id]; if (it) { if (it.st < W_MAXSTAR) it.st++; else S.cash += foeCash(tierNow()) * 50; } else S.w[id] = { lv: 0, st: 0 }; dirty(); UI.dot('inv'); }
export function giveRelic(id) { const it = S.rel[id]; if (it) { if (it.lv < R_MAXLV) it.lv++; } else { S.rel[id] = { lv: 0 }; if (S.relEq.length < relicSlotsN()) S.relEq.push(id); } dirty(); UI.dot('inv'); }
export function giveAcc(id) { const it = S.acc[id]; if (it) { if (it.lv < A_MAXLV) it.lv++; } else { S.acc[id] = { lv: 0 }; const a = ACCS.find(x => x.id === id); if (!S.accEq[a.slot]) S.accEq[a.slot] = id; } dirty(); UI.dot('inv'); }
export function spin() {
  if (Date.now() - S.spinT < SPIN_CD) return null; S.spinT = Date.now(); const mw = S.maxWorld, t = tierOf(mw, S.stage[mw] % STAGES); const x = Math.random(); let res;
  if (x < 0.3) { const c = foeCash(t) * 120; S.cash += c; res = ['Argent', '#4ade80', 0]; UI.loot([['cash', c]]); }
  else if (x < 0.6) { const g = Math.ceil(rnd(25, 60) * (mw + 1)); S.gems += g; res = [`${g} gemmes`, '#38bdf8', 1]; }
  else if (x < 0.75) { const kr = rollRankW(PORTAL_RW[mw]); S.keys[kr]++; res = [`Clé de portail rang ${SRANKS[kr]}`, '#fcd34d', 2]; }
  else if (x < 0.97) { const loot = []; const it = dropItem(loot, pick([0, 1, 2]), WORLD_RW[mw]); UI.loot(loot); res = [it.n, RAR[it.r].c, 3]; }
  else { const g = 300 * (mw + 1); S.gems += g; res = [`JACKPOT : ${g} gemmes`, '#ff7ad9', 4]; }
  SFX.play('win', 0.6); save(); return res;
}

/* ---------- XP / niveau ---------- */
function gainXp(x) {
  S.xp += x; let up = 0;
  while (S.xp >= xpNeed(S.lvl)) { S.xp -= xpNeed(S.lvl); S.lvl++; S.pts += 3; up = 1; }
  if (up) {
    G.P.hp = heroHp(); G.P.mp = heroMp(); dirty(); pillar(G.P.pos, 0xffcc33, 10); SFX.play('power', 0.6);
    UI.banner('NIVEAU ' + S.lvl, '+3 points d\'attributs à répartir (menu Chasseur)', '#ffcc33'); UI.dot('stats');
    const free = armyCap() - equipped().length; if (free > 0) { S.sh.filter(s => !s.eq).sort((a, b) => shDmg(b) - shDmg(a)).slice(0, free).forEach(s => s.eq = true); syncArmy(); }
  }
}

/* ---------- mission de l'île : le boss attend dans son arène ---------- */
function checkMission() {
  if (!inWorld() || G.boss || S.stage[S.world] >= STAGES && false) return;
  const m = mission(S.world, Math.min(S.stage[S.world], STAGES - 1));
  if (S.prog.kills >= m.kills && S.prog.brutes >= m.brutes) {
    const a = G.info.sites.boss; spawnFoe(2, V(a.x, 0, a.z), { u: W().uq }); pillar(V(a.x, 0, a.z), 0xff3355, 14);
    UI.banner('LE BOSS T\'ATTEND', `${UNIQUES[W().uq].n} est entré dans l'arène — suis la flèche rouge`, '#ff3355'); SFX.play('bell', 0.7);
  }
}
function bossDown(f) {
  S.st.bosses++; bumpQ('bosses'); S.prog = { kills: 0, brutes: 0 }; const w = S.world;
  if (S.stage[w] < STAGES) {
    S.stage[w]++;
    if (S.stage[w] >= STAGES) { if (S.maxWorld < Math.min(3, w + 1)) S.maxWorld = Math.min(3, w + 1); UI.banner('ÎLE CONQUISE !', w < 3 ? `${WORLDS[w + 1].n} est débloquée — parle à Lyra` : 'Tu règnes sur l\'Abysse', W().col); SFX.play('win', 0.8); }
    else { UI.banner(`PALIER ${S.stage[w] + 1}`, 'Les monstres qui réapparaissent seront plus forts… et plus riches', W().col); SFX.play('win', 0.6); }
    const st = S.stage[w], mk = w + '-' + st;
    if (!S.miles[mk]) {
      if (st === 3) { const gm = 80 * (w + 1); S.gems += gm; S.miles[mk] = 1; UI.toast(`Récompense de palier : +${gm} gemmes`, 'gold'); }
      else if (st === 5) { const kr = rkMax(PORTAL_RW[w]); S.keys[kr]++; S.miles[mk] = 1; UI.toast(`Récompense de palier : clé de portail rang ${SRANKS[kr]}`, 'gold'); }
      else if (st === 7) { S.armyB++; S.miles[mk] = 1; UI.toast('Récompense de palier : +1 ombre dans ton armée', 'gold'); }
    }
  }
  pillar(f.pos, 0xffcc33, 14); shock(f.pos, 0xffcc33, 10, 1); E.shake = 0.6; save();
}

/* ---------- âmes et éveil ---------- */
function addSoul(f) {
  const col = f.kind === 2 ? 0xffcc33 : RANK_HEX(f.rk);
  const g = new THREE.Group(); const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: E.glowTex, color: col, blending: THREE.AdditiveBlending, depthWrite: false }));
  s.scale.setScalar(f.kind === 2 ? 3.4 : f.kind === 1 ? 2.2 : 1.5); s.position.y = 1.2; g.add(s); g.position.copy(f.pos); E.scene.add(g);
  const dg = G.dg;
  G.souls.push({ obj: g, s, pos: f.pos.clone(), type: f.type, u: f.u, rk: f.rk, t: f.t, k: f.kind, base: f.leg ? 0.25 : f.kind === 2 ? (dg ? 0.35 : 0.15) : f.kind === 1 ? 0.3 : 0.5,
    where: dg ? (dg.tower ? `Tour de l'Ascension, étage ${dg.floor}` : `Portail rang ${SRANKS[dg.r]} — ${dg.D.n}`) : `${W().n}, palier ${Math.min(S.stage[S.world] + 1, STAGES)}`, life: f.kind === 2 ? 30 : 16 });
}
function makeShadow(s) {
  const rk = s.rk; const U = s.u ? UNIQUES[s.u] : null;
  const keys = Object.keys(TRAITS).sort(() => Math.random() - 0.5);
  const tr = keys.slice(0, TRAIT_N[rk]).map(k => [k, traitVal(k, rk)]);
  if (U) tr.unshift([U.sig[0], U.sig[1]]);
  const d = new Date();
  return { id: ++S.shN, type: s.type, u: s.u || null, n: U ? U.n : shadowName(), t: s.t, k: s.k, rk, lv: 0, eq: false, aw: 0, kills: 0, tr,
    born: `${d.toLocaleDateString('fr-FR')} à ${d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`, where: s.where };
}
export function arise() {
  const near = G.souls.filter(s => s.pos.distanceTo(G.P.pos) < 16); if (!near.length) { UI.toast('Aucune âme à portée — abats un ennemi d\'abord', 'bad'); return; }
  G.P.ch.play('cast', { once: true, restart: true, speed: 1.4 }); shock(G.P.pos, 0xc26bff, 7, 0.6); SFX.play('seal', 0.6);
  let ok = 0;
  for (const s of near) {
    const ch = clamp(s.base * (1 + bonus().arise / 100) * prop('arise'), 0, 0.95);
    removeSoul(s);
    if (Math.random() < ch) {
      ok++;
      const dup = s.u && S.sh.find(x => x.u === s.u);
      if (dup) { dup.aw = Math.min(5, (dup.aw || 0) + 1); pillar(s.pos, 0xffcc33, 10); UI.banner(`${dup.n} S'ÉVEILLE`, `Éveil ${'★'.repeat(dup.aw)} — +25 % de puissance`, '#ffcc33'); S.st.arises++; continue; }
      const sh = makeShadow(s);
      S.sh.push(sh); S.st.arises++; bumpQ('arises');
      if (equipped().length < armyCap()) sh.eq = true;
      else { const weak = equipped().sort((a, b) => shDmg(a) - shDmg(b))[0]; if (weak && shDmg(weak) * 1.3 < shDmg(sh)) { weak.eq = false; sh.eq = true; } }
      pillar(s.pos, SRANK_COL[sh.rk], 8); UI.dn(s.pos, 'ÉVEIL !', 'arise');
      if (sh.eq) syncArmy();
      if (sh.rk >= 3 || sh.u) { UI.reveal(sh); if (sh.rk >= 5) lucky(`Ombre ${SRANKS[sh.rk]} — ${sh.n}`, 0.01, SRANK_COL[sh.rk]); } else UI.ariseCard(sh);
    } else { UI.dn(s.pos, 'ÉCHEC', 'fail'); burst(s.pos.clone().setY(1), 0x64748b, 10); }
  }
  if (ok) SFX.play('power', 0.6);
  if (S.sh.length > 400) { S.sh.sort((a, b) => (b.eq - a.eq) || ((b.u ? 1 : 0) - (a.u ? 1 : 0)) || (shDmg(b) - shDmg(a))); S.sh.length = 400; }
  dirty(); UI.dot('ombres');
}
function removeSoul(s) { s.obj.removeFromParent(); G.souls.splice(G.souls.indexOf(s), 1); }

/* ---------- armée d'ombres : elles ont des PV, tombent, et se rappellent contre du mana ---------- */
function addArmy(sh, at) {
  const F = FOES[sh.type];
  const ch = makeChar(F.model, { shadow: true, shadowCol: sh.u ? 0x7a3a10 : sh.rk >= 5 ? 0x7a2a9a : 0x3b1a8a, eyeCol: RANK_HEX(sh.rk), scale: (F.sc || 1) * (F.model === 'dragon' ? 0.7 : 1) * (sh.k === 2 ? 1.45 : sh.k === 1 ? 1.15 : 0.95), noShadow: true });
  const p = (at || G.P.pos).clone().add(V(rnd(-2, 2), 0, rnd(-2, 2))); ch.root.position.copy(p); E.scene.add(ch.root);
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.55, 0.75, 24), new THREE.MeshBasicMaterial({ color: sh.u ? 0xffcc33 : RANK_HEX(sh.rk), transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.06; ch.root.add(ring);
  G.army.push({ ch, sh, pos: p, hp: 100, cd: rnd(0, 1), tgt: null, slot: G.army.length, ranged: /Mage/.test(F.model), r: 0.5 });
}
export function syncArmy() {
  const eq = equipped(); G.fallen = G.fallen.filter(id => eq.some(s => s.id === id));
  const want = new Set(eq.filter(s => !G.fallen.includes(s.id)).map(s => s.id));
  for (let i = G.army.length - 1; i >= 0; i--) if (!want.has(G.army[i].sh.id)) { G.army[i].ch.dispose(); G.army.splice(i, 1); }
  const have = new Set(G.army.map(a => a.sh.id));
  for (const s of eq) if (want.has(s.id) && !have.has(s.id)) addArmy(s);
  G.army.forEach((a, i) => a.slot = i);
}
function unitDie(a) { UI.dn(a.pos, `${a.sh.n} tombe`, 'fail'); burst(a.pos.clone().setY(1), 0x7c3aed, 16, { speed: 3 }); a.ch.dispose(); G.army.splice(G.army.indexOf(a), 1); G.fallen.push(a.sh.id); G.army.forEach((x, i) => x.slot = i); }
export function recall(silent) {
  let n = 0; const P = G.P;
  while (G.fallen.length && P.mp >= MANA_RECALL) { const id = G.fallen.shift(); const sh = S.sh.find(s => s.id === id); if (!sh || !sh.eq) continue; P.mp -= MANA_RECALL; addArmy(sh); pillar(G.army[G.army.length - 1].pos, RANK_HEX(sh.rk), 5); n++; }
  if (n) { SFX.play('seal', 0.5); G.army.forEach((x, i) => x.slot = i); } else if (!silent) UI.toast(G.fallen.length ? `Mana insuffisant (${MANA_RECALL} par ombre)` : 'Aucune ombre à rappeler', 'bad');
  return n;
}
/* compétence : Onde d'ombre (mana) */
export function wave() {
  const P = G.P; if (G.dead > 0 || G.waveCd > 0) return;
  if (P.mp < MANA_WAVE) { UI.toast(`Mana insuffisant (${MANA_WAVE})`, 'bad'); return; }
  P.mp -= MANA_WAVE; G.waveCd = 3; P.ch.play('cast', { once: true, restart: true, speed: 1.8 }); P.ch.lock = 0.4;
  shock(P.pos, 0xc26bff, 9, 0.5); shock(P.pos, 0xffffff, 6, 0.35); burst(P.pos.clone().setY(1), 0xc26bff, 26, { speed: 7 }); E.shake = 0.25; SFX.play('boom', 0.5);
  const b = bonus(); for (const f of [...G.foes]) if (!f.dead && !f.ret && f.pos.distanceTo(P.pos) < 8 + f.r) { const crit = Math.random() < b.crit / 100; hitFoe(f, heroDmg() * 3.2 * (crit ? 2.5 : 1), crit, 'pl'); }
}

/* ---------- quêtes ---------- */
function bumpQ(k) { S.q.p[k] = (S.q.p[k] || 0) + 1; }
export function bumpUpgrade() { S.st.upgrades++; bumpQ('upgrades'); }

/* ---------- mise à jour ---------- */
const tv = V(0, 0, 0);
function moveTo(obj, target, speed, dt, stop = 0) {
  tv.subVectors(target, obj.pos); tv.y = 0; const d = tv.length(); if (d <= stop + 0.05) return false;
  tv.multiplyScalar(Math.min(speed * dt, d - stop) / d); obj.pos.add(tv); obj.ch.root.rotation.y = Math.atan2(tv.x, tv.z); return true;
}
function foeHurt(f, tg) {
  if (tg === G.P) return heroHurt(f);
  const ref = shadowPow(tg.sh) / 0.06; tg.hp -= 100 * (f.kind === 2 ? 0.45 : f.kind === 1 ? 0.22 : 0.11) * clamp(Math.sqrt(f.unit / ref), 0.4, 6) * rnd(0.85, 1.15);
  burst(tg.pos.clone().setY(1), 0xff4d6d, 4, { speed: 2 }); if (tg.hp <= 0) unitDie(tg);
}
export function update(dt) {
  G.t += dt; S.st.play += dt; const P = G.P, b = bonus();
  const aspd = 1 + b.aspd / 100, maxHp = heroHp(), maxMp = heroMp();
  if (G.dg) dgTick(dt); else if (S.world >= 0) worldTick(dt);
  G.waveCd = Math.max(0, G.waveCd - dt); G.bossSkip = Math.max(0, (G.bossSkip || 0) - dt);
  if (G.dead > 0) { G.dead -= dt; if (G.dead <= 0) { P.pos.copy(G.info.spawn); P.hp = maxHp; P.mp = maxMp * 0.5; P.ch.play('idle'); recall(true); UI.toast('Tu te relèves… l\'ombre ne meurt jamais', 'good'); } P.ch.update(dt); P.ch.root.position.copy(P.pos); }
  const alive = G.dead <= 0; let combat = false; for (const f of G.foes) if (f.aggro && !f.dead) { combat = true; break; } G.combat = combat;

  if (alive) {
    /* héros : joystick ou farm automatique */
    const speed = 9 * (1 + b.speed / 100); const jx = G.joy.x, jy = G.joy.y; P.moving = false;
    if (Math.hypot(jx, jy) > 0.15) {
      const s = Math.sin(E.yaw), c = Math.cos(E.yaw); const dx = jx * c + jy * s, dz = -jx * s + jy * c;
      P.pos.x += dx * speed * dt; P.pos.z += dz * speed * dt; P.ang = Math.atan2(dx, dz); P.moving = true; P.tgt = null;
    } else if (S.auto && G.foes.length) {
      if (!P.tgt || P.tgt.dead || P.tgt.ret || (combat && !P.tgt.aggro)) P.tgt = nearestFoe(P.pos, 999, f => f.aggro) || (G.boss && !G.bossSkip && inWorld() ? G.boss : nearestFoe(P.pos, 999, f => !f.leg && (f.kind < 2 || !inWorld())));
      if (P.tgt) {
        const st = 1.6 + P.tgt.r; tv.subVectors(P.tgt.pos, P.pos); const d = tv.length();
        if (d > st) {
          if (P.det > 0) { P.det -= dt; const px = tv.z * P.detDir, pz = -tv.x * P.detDir; tv.set(px + tv.x * 0.2, 0, pz + tv.z * 0.2); }
          tv.multiplyScalar(Math.min(speed * dt, d - st) / tv.length()); P.pos.add(tv); P.ang = Math.atan2(tv.x, tv.z); P.moving = true;
          if ((P.stuck += dt) > 0.7) { if (P.lastD - d < 1.2 && P.det <= 0) { P.det = 1.6; P.detDir = Math.random() < 0.5 ? 1 : -1; } P.stuck = 0; P.lastD = d; }
        }
      }
    }
    collide(P.pos, 0.6, G.info.R); P.ch.root.position.copy(P.pos);
    const ra = P.ch.root.rotation; ra.y += (((P.ang - ra.y + Math.PI * 3) % (Math.PI * 2)) - Math.PI) * Math.min(1, dt * 14);
    P.ch.play(P.moving ? 'run' : (P.ch.lock > 0 ? P.ch.cur : 'idle'), { speed: P.moving ? 1.25 : 1 }); P.ch.lock -= dt;
    P.atkCd -= dt;
    if (P.atkCd <= 0) { const t = nearestFoe(P.pos, 2.6, f => f.aggro || S.auto); if (t) heroStrike(t, aspd); }
    if (S.auto && combat && G.waveCd <= 0 && P.mp >= maxMp * 0.5 && G.foes.filter(f => f.aggro && !f.dead && f.pos.distanceTo(P.pos) < 7).length >= 3) wave();
    if (S.auto && !combat && G.fallen.length && P.mp >= MANA_RECALL) recall(true);
    P.hp = Math.min(maxHp, P.hp + maxHp * (combat ? 0.008 : 0.07) * dt); P.mp = Math.min(maxMp, P.mp + maxMp * (combat ? 0.02 : 0.06) * dt);
    P.aura.rotation.z += dt; P.aura.material.opacity = 0.35 + Math.sin(G.t * 3) * 0.2;
    P.ch.update(dt);
    /* armée */
    const fw = V(Math.sin(P.ch.root.rotation.y), 0, Math.cos(P.ch.root.rotation.y)), rt = V(fw.z, 0, -fw.x);
    for (const a of [...G.army]) {
      if (!a.tgt || a.tgt.dead || !a.tgt.aggro || a.tgt.pos.distanceTo(P.pos) > 26) a.tgt = nearestFoe(a.pos, 22, f => f.aggro);
      const range = (a.ranged ? 7 : 1.5) + (a.tgt ? a.tgt.r : 0); let mv = false;
      if (a.tgt) {
        mv = moveTo(a, a.tgt.pos, speed * 1.1, dt, range);
        if (!mv) {
          a.ch.root.rotation.y = Math.atan2(a.tgt.pos.x - a.pos.x, a.tgt.pos.z - a.pos.z); a.cd -= dt;
          if (a.cd <= 0) {
            a.cd = 1.1 / aspd * rnd(0.85, 1.15); const t = a.tgt; const crit = Math.random() < b.crit / 100; const dmg = shDmg(a.sh) * (crit ? 2.5 : 1) * rnd(0.9, 1.1); const sh = a.sh;
            if (a.ranged) { a.ch.play('cast', { once: true, restart: true, speed: 1.8 }); projectile(a.pos, t.pos, 0xc26bff, 0.3, () => { hitFoe(t, dmg, crit, 'sh', sh); burst(t.pos.clone().setY(1), 0xc26bff, 5); }); }
            else { a.ch.play('attack', { once: true, restart: true, speed: 1.8 }); hitFoe(t, dmg, crit, 'sh', sh); burst(t.pos.clone().setY(1), 0x7c3aed, 5, { speed: 2 }); }
            a.ch.lock = 0.5;
          }
        }
      } else {
        if (a.pos.distanceTo(P.pos) > 34) a.pos.copy(P.pos);
        const row = Math.floor(a.slot / 5), col = (a.slot % 5) - 2;
        const want = P.pos.clone().addScaledVector(fw, -2.6 - row * 2).addScaledVector(rt, col * 1.9);
        mv = moveTo(a, want, speed * 1.15, dt, 0.4);
        if (!mv) a.ch.root.rotation.y += (P.ch.root.rotation.y - a.ch.root.rotation.y) * Math.min(1, dt * 5);
        if (!combat) a.hp = Math.min(100, a.hp + 12 * dt);
      }
      a.ch.lock -= dt; if (mv) a.ch.play('run'); else if (a.ch.lock <= 0) a.ch.play('idle');
      collide(a.pos, 0.4, G.info.R); a.ch.root.position.copy(a.pos); a.ch.update(dt);
    }
  }

  /* ennemis : gardent leur camp, attaquent si on approche, abandonnent si on s'éloigne */
  for (let i = G.foes.length - 1; i >= 0; i--) {
    const f = G.foes[i];
    if (f.dead) { f.deathT -= dt; f.ch.update(dt); if (f.deathT <= 0) { f.ch.dispose(); G.foes.splice(i, 1); } continue; }
    const d = f.pos.distanceTo(P.pos); let mv = false, run = false;
    if (!f.aggro && !f.ret && d > 55) { f.ch.root.visible = false; continue; } f.ch.root.visible = true;
    if (f.ret) { mv = run = moveTo(f, f.home, 8, dt, 0.5); f.hp = Math.min(f.max, f.hp + f.max * 0.5 * dt); if (!mv) f.ret = false; }
    else if (!f.aggro) {
      if (alive && d < f.ar + f.r) aggro(f);
      else { f.wander -= dt; if (f.wander <= 0) { f.wander = rnd(3, 7); f.wt = f.home.clone().add(V(rnd(-3, 3), 0, rnd(-3, 3))); } if (f.wt) mv = moveTo(f, f.wt, 1.8, dt, 0.3); }
    } else if (!alive || (!f.free && f.pos.distanceTo(f.home) > f.leash)) { f.aggro = false; f.tg = null; if (!f.free) f.ret = true; }
    else {
      if ((f.tgT -= dt) <= 0 || !f.tg || (f.tg !== P && !G.army.includes(f.tg))) { f.tgT = 1.5; let best = P, bd = d; for (const a of G.army) { const x = a.pos.distanceTo(f.pos); if (x < bd - 1.5 && x < 7) { bd = x; best = a; } } f.tg = best; }
      const tg = f.tg; mv = run = moveTo(f, tg.pos, f.kind === 2 ? 4.8 : 5.6, dt, 1.4 + f.r);
      if (!mv) {
        f.ch.root.rotation.y = Math.atan2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z); f.cd -= dt;
        if (f.cd <= 0) { f.cd = f.kind === 2 ? 2 : 1.7; f.ch.play('attack', { once: true, restart: true, speed: 1.4 }); f.ch.lock = 0.6; foeHurt(f, tg); if (f.kind === 2) { shock(f.pos, 0xff3355, 5, 0.5); E.shake = 0.25; if (f.leg) for (const a of [...G.army]) if (a.pos.distanceTo(f.pos) < 6) foeHurt(f, a); } }
      }
    }
    f.ch.lock -= dt; if (mv) f.ch.play(run ? 'run' : 'walk'); else if (f.ch.lock <= 0) f.ch.play('idle');
    collide(f.pos, f.r * 0.6 + 0.3, G.info.R); f.ch.root.position.copy(f.pos); f.ch.update(dt);
  }

  /* habitants du Sanctuaire, interaction de proximité */
  G.near = null;
  for (const n of G.npcs) { n.ch.update(dt); const d = n.pos.distanceTo(P.pos); if (d < 5) { G.near = { type: 'npc', npc: n }; n.ch.root.rotation.y = Math.atan2(P.pos.x - n.pos.x, P.pos.z - n.pos.z); } }
  if (G.portal && G.portal.pos.distanceTo(P.pos) < 4.5) G.near = { type: 'portal' };

  /* âmes */
  for (let i = G.souls.length - 1; i >= 0; i--) { const s = G.souls[i]; s.life -= dt; s.s.position.y = 1.2 + Math.sin(G.t * 3 + i) * 0.25; s.s.material.opacity = Math.min(1, s.life / 3); if (Math.random() < dt * 6) E.particles.emit({ x: s.pos.x, y: 0.6, z: s.pos.z }, 0xc26bff, { spread: 0.4, speed: 1, up: 1.5, grav: -2, life: 0.7, size: 0.5 }); if (s.life <= 0) removeSoul(s); }
  if (alive && S.autoArise && G.souls.length && (G.ariseT = (G.ariseT || 0) - dt) <= 0) { G.ariseT = 1.5; if (G.souls.some(s => s.pos.distanceTo(P.pos) < 16)) arise(); }
  if (G.bossPortal) { G.bossPortal.t -= dt; if (G.bossPortal.t <= 0) { const bp = G.bossPortal; bp.obj.removeFromParent(); G.bossPortal = null; spawnFoe(2, bp.p, { u: bp.u }); pillar(bp.p, 0xff3355, 12); E.shake = 0.5; SFX.play('boom', 0.7); } }
  while (G.dmgWin.length && G.dmgWin[0][0] < G.t - 4) G.dmgWin.shift();
  G.dps = G.dmgWin.reduce((a, x) => a + x[1], 0) / 4;
}
function heroStrike(t, aspd) {
  const P = G.P; P.atkCd = 0.55 / aspd; const b = bonus(); const crit = Math.random() < b.crit / 100;
  const dmg = heroDmg() * (crit ? 2.5 : 1) * rnd(0.9, 1.1);
  P.ang = Math.atan2(t.pos.x - P.pos.x, t.pos.z - P.pos.z); P.ch.root.rotation.y = P.ang;
  if (!P.moving) { P.ch.play('attack', { once: true, restart: true, speed: 2.2 }); P.ch.lock = 0.35; }
  const w = WEAPONS.find(x => x.id === S.wEq);
  slash(P.pos, P.ang, w.glow || 0xc9b6ff, crit); hitFoe(t, dmg, crit, 'pl'); burst(t.pos.clone().setY(1), w.glow || 0xffffff, crit ? 10 : 5, { speed: 3 });
}
function heroHurt(f) {
  const P = G.P; if (G.dead > 0) return;
  const d = heroHp() * f.dmgPct * clamp(f.unit / (power() * 1.5), 0.35, 8) * rnd(0.85, 1.15); P.hp -= d; UI.dn(P.pos, d, 'hurt'); UI.hurt();
  if (P.hp <= 0) {
    P.hp = 0; P.ch.play('death', { once: true, restart: true }); SFX.play('lose', 0.6);
    if (G.dg) { G.dead = 99; dgFail('Tu es tombé'); return; }
    G.dead = 3; if (f.kind === 2) G.bossSkip = 90; UI.banner('VAINCU', f.kind === 2 ? 'Ce boss est trop fort — renforce ton armée' : 'Renforce ton arme et ton armée', '#ff3355');
  }
}
export { spawnFoe };
