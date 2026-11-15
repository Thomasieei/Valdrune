/* UMBRA — boucle de jeu : héros, ennemis, éveil des ombres, armée, butin, mondes, portails et donjons */
import { E, makeChar, attachWeapon, buildWorld, collide, burst, slash, shock, pillar, projectile, portalMesh } from './engine.js';
import { WEAPONS, RELICS, ACCS, WORLDS, FOES, STAGES, RAR, W_MAXSTAR, R_MAXLV, A_MAXLV, tierOf, foeHp, foeCash, mission, xpNeed, armyMax, SRANKS, SRANK_COL,
  rollRankW, WORLD_RW, dungeonRW, PORTAL_RW, DUNGEONS, DG_TIME, DG_WAVES, UNIQUES, TRAITS, TRAIT_N, traitVal, shadowName, SUMMON, rnd, pick, clamp } from './data.js';
import { S, save, bonus, dirty, heroDmg, heroHp, shDmg, equipped, relicSlotsN, power } from './state.js';
import { UI } from './ui.js';
import { SFX } from './audio.js';

const THREE = E.THREE; const V = (x, y, z) => new THREE.Vector3(x, y, z);
export const G = { foes: [], souls: [], army: [], joy: { x: 0, y: 0 }, info: null, boss: null, dps: 0, dmgWin: [], dead: 0, t: 0, dg: null, portal: null, portalT: 60 };
const W = () => WORLDS[S.world];
const tierNow = () => G.dg ? G.dg.tier : tierOf(S.world, Math.min(S.stage[S.world], STAGES - 1));
const prop = k => G.dg ? 1 : (W().prop[k] || 1);
const RANK_HEX = r => new THREE.Color(RAR[r].c).getHex();

/* ---------- héros ---------- */
function makeHero() {
  const w = WEAPONS.find(x => x.id === S.wEq);
  const ch = makeChar('Rogue_Hooded', { tint: '#8f80d8', eyeCol: 0x9ff3ff, weapon: w.model, wcol: w.glow });
  E.scene.add(ch.root);
  const aura = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.25, 40), new THREE.MeshBasicMaterial({ color: 0x8b5cf6, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false }));
  aura.rotation.x = -Math.PI / 2; aura.position.y = 0.05; ch.root.add(aura);
  return { ch, pos: V(0, 0, 0), hp: 1, ang: 0, atkCd: 0, moving: false, tgt: null, aura };
}
export function refreshWeapon() { const w = WEAPONS.find(x => x.id === S.wEq); attachWeapon(G.P.ch.mdl, w.model, w.glow); G.P.aura.material.color.set(w.glow || 0x8b5cf6); }

/* ---------- changement de lieu ---------- */
function clearScene() {
  for (const f of G.foes) f.ch.dispose(); for (const s of G.souls) s.obj.removeFromParent(); for (const a of G.army) a.ch.dispose();
  if (G.portal) { G.portal.obj.removeFromParent(); G.portal = null; }
  if (G.bossPortal) { G.bossPortal.obj.removeFromParent(); G.bossPortal = null; }
  G.foes = []; G.souls = []; G.army = []; G.boss = null;
}
export function enterWorld(i) {
  if (S.world !== i) S.prog = { kills: 0, brutes: 0 };
  S.world = i; G.dg = null; clearScene(); G.portalT = rnd(45, 90);
  G.info = buildWorld(W().env); G.P.pos.copy(G.info.spawn); G.P.hp = heroHp(); G.P.tgt = null; G.dead = 0;
  syncArmy(); SFX.music(W().music);
  UI.zoneTitle(W().n, `Palier ${Math.min(S.stage[i] + 1, STAGES)} / ${STAGES} — ${W().propTxt}`, W().col);
  for (let n = 0; n < 8; n++) spawnFoe(0);
  save();
}
export function initGame() { G.P = makeHero(); enterWorld(S.world); }

/* ---------- donjons ---------- */
export function enterDungeon(r, viaKey) {
  if (viaKey) { if (!S.keys[r]) return; S.keys[r]--; }
  const D = DUNGEONS[r]; clearScene();
  G.dg = { r, D, tier: D.tier, wave: -1, wait: 1.8, t: DG_TIME, phase: 'wave', end: 0, res: null };
  G.info = buildWorld('dungeon', { tint: RANK_HEX(r) }); G.P.pos.copy(G.info.spawn); G.P.hp = heroHp(); G.P.tgt = null; G.dead = 0;
  syncArmy(); SFX.music('dungeon');
  UI.zoneTitle(`Portail rang ${SRANKS[r]}`, `${D.n} — ${DG_WAVES.length} vagues puis le boss · ${Math.round(DG_TIME / 60)} min`, RAR[r].c);
}
function spawnWave() {
  const dg = G.dg; const n = DG_WAVES[dg.wave];
  UI.banner(`VAGUE ${dg.wave + 1} / ${DG_WAVES.length}`, dg.D.n, RAR[dg.r].c); SFX.play('bell', 0.5);
  for (let i = 0; i < n; i++) spawnFoe(Math.random() < 0.18 ? 1 : 0);
}
function dungeonTick(dt) {
  const dg = G.dg; if (dg.end) { dg.end -= dt; if (dg.end <= 0) { UI.close(); enterWorld(S.world); } return; }
  dg.t -= dt; if (dg.t <= 0) return dungeonFail('Le temps est écoulé');
  if (dg.phase === 'wave' && G.foes.length === 0 && (dg.wait -= dt) <= 0) {
    dg.wait = 1.2; dg.wave++;
    if (dg.wave < DG_WAVES.length) spawnWave();
    else { dg.phase = 'boss'; const p = V(0, 0, -6); const pm = portalMesh(RANK_HEX(dg.r), 1.8); pm.position.copy(p); E.scene.add(pm); G.bossPortal = { obj: pm, t: 2.2, p }; UI.banner('LE BOSS ARRIVE', `${UNIQUES[dg.D.boss].n}, ${UNIQUES[dg.D.boss].t}`, '#ff3355'); SFX.play('bell', 0.8); E.shake = 0.5; }
  }
}
function dungeonWin(f) {
  const dg = G.dg, r = dg.r; dg.phase = 'won'; dg.end = 25; S.dgDone[r]++;
  const b = bonus(), rw = dungeonRW(r), luck = b.luck;
  const res = { cash: foeCash(dg.tier) * 150 * (1 + b.cash / 100), gems: Math.ceil(30 * Math.pow(r + 1, 2) * (1 + b.gems / 100)), items: [] };
  S.cash += res.cash; S.gems += res.gems;
  const rel = rollItem(RELICS, rw, luck); giveRelic(rel.id); res.items.push(['rel', rel.id]);
  if (Math.random() < 0.45) { const a = rollItem(ACCS, rw, luck); giveAcc(a.id); res.items.push(['acc', a.id]); }
  if (Math.random() < 0.3) { const w = rollItem(WEAPONS, rw, luck); giveWeapon(w.id); res.items.push(['w', w.id]); }
  if (Math.random() < 0.35) { const kr = clamp(r + (Math.random() < 0.2 ? 1 : 0), 0, 6); S.keys[kr]++; res.key = kr; }
  for (const [k, id] of res.items) { const it = (k === 'w' ? WEAPONS : k === 'rel' ? RELICS : ACCS).find(x => x.id === id); if (it.r >= 4) lucky(it.n, 0.01, RAR[it.r].c); }
  dg.res = res; pillar(f.pos, 0xffcc33, 14); E.shake = 0.6; SFX.play('win', 0.8);
  UI.banner('DONJON TERMINÉ !', `Éveille ${UNIQUES[dg.D.boss].n} avant qu'il ne disparaisse`, RAR[r].c);
  setTimeout(() => G.dg === dg && UI.dungeonResult(dg), 2500);
  save();
}
function dungeonFail(why) {
  const dg = G.dg; if (!dg || dg.end) return; dg.phase = 'lost'; dg.end = 4;
  for (const f of G.foes) if (!f.dead) { f.dead = 1; f.deathT = 0.1; }
  UI.banner('ÉCHEC DU DONJON', why + ' — renforce-toi avant de revenir', '#ff3355'); SFX.play('lose', 0.7);
}
export function leaveDungeon() { if (G.dg) G.dg.end = 0.01; }

/* ---------- portails dans les mondes ---------- */
function portalTick(dt) {
  if (!G.portal) {
    G.portalT -= dt; if (G.portalT > 0) return;
    const r = rollRankW(PORTAL_RW[S.world]); const a = rnd(0, 6.28), d = rnd(22, 36);
    const p = G.P.pos.clone().add(V(Math.cos(a) * d, 0, Math.sin(a) * d)); collide(p, 3, G.info.R - 4);
    const obj = new THREE.Group(); const pm = portalMesh(RANK_HEX(r), 1.5); obj.add(pm);
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.9, 60, 16, 1, true), new THREE.MeshBasicMaterial({ color: RANK_HEX(r), transparent: true, opacity: 0.14, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    beam.position.y = 30; obj.add(beam); obj.position.copy(p); E.scene.add(obj);
    G.portal = { r, pos: p, obj, beam, life: 300 };
    UI.toast(`Un portail de rang ${SRANKS[r]} s'est ouvert !`, r >= 3 ? 'gold' : ''); SFX.play('ping', 0.6);
    return;
  }
  const P = G.portal; P.life -= dt; P.beam.material.opacity = 0.12 + Math.sin(G.t * 3) * 0.05;
  if (P.life <= 0) { P.obj.removeFromParent(); G.portal = null; G.portalT = rnd(120, 200); UI.toast('Le portail s\'est refermé…', 'bad'); }
}
export function enterPortal() { const P = G.portal; if (!P) return; P.obj.removeFromParent(); G.portal = null; G.portalT = rnd(120, 200); enterDungeon(P.r, false); }

/* ---------- ennemis ---------- */
function spawnFoe(kind, at) {
  const dg = G.dg; let type, n, u = null;
  if (kind === 2) { u = dg ? dg.D.boss : W().uq; type = UNIQUES[u].foe; n = `${UNIQUES[u].n}, ${UNIQUES[u].t}`; }
  else { type = dg ? pick(dg.D.foes) : kind === 1 ? W().brute : pick(W().foes); n = FOES[type].n; }
  const F = FOES[type]; const t = tierNow(); const mult = kind === 2 ? 40 : kind === 1 ? 6 : 1;
  const scale = (F.sc || 1) * (kind === 2 ? 2.4 : kind === 1 ? 1.55 : 1);
  const tint = dg ? new THREE.Color(F.tint).lerp(new THREE.Color(RAR[dg.r].c), 0.35).getStyle() : kind === 1 ? '#ff8a8a' : F.tint;
  const ch = makeChar(F.model, { tint, scale, eyeCol: kind ? 0xff3355 : 0xffd040 });
  let p = at ? at.clone() : null;
  if (!p) { const a = rnd(0, 6.28), r = dg ? rnd(6, 16) : rnd(11, 22); p = (dg ? V(0, 0, 0) : G.P.pos.clone()).add(V(Math.cos(a) * r, 0, Math.sin(a) * r)); collide(p, 1, G.info.R - 2); }
  ch.root.position.copy(p); E.scene.add(ch.root);
  const hp = foeHp(t) * mult * prop('hp');
  const f = { ch, pos: p, home: p.clone(), hp, max: hp, kind, type, u, n, t, cd: rnd(0.5, 1.5), dmgPct: (kind === 2 ? 0.14 : kind === 1 ? 0.07 : 0.03) * (dg ? 0.55 : 1), wander: rnd(1, 4), wt: null, dead: 0, r: kind === 2 ? 2.2 : kind === 1 ? 1 : 0.6, aggro: !!dg };
  G.foes.push(f); if (kind === 2) G.boss = f;
  if (kind) burst(p.clone().setY(1), kind === 2 ? 0xff3355 : 0xffaa33, 20, { spread: 1, speed: 4 });
  return f;
}
function nearestFoe(p, R) { let b = null, bd = R; for (const f of G.foes) { if (f.dead) continue; const d = f.pos.distanceTo(p) - f.r; if (d < bd) { bd = d; b = f; } } return b; }

function hitFoe(f, dmg, crit, src, who) {
  if (f.dead) return; f.hp -= dmg; G.dmgWin.push([G.t, dmg]);
  UI.dn(f.pos, dmg, crit ? 'crit' : src);
  if (f.hp <= 0) { if (who) who.kills = (who.kills || 0) + 1; killFoe(f); }
}
function killFoe(f) {
  f.dead = 1; f.hp = 0; f.ch.play('death', { once: true, restart: true }); f.deathT = 1.6;
  if (G.boss === f) G.boss = null;
  const b = bonus(), dg = G.dg;
  const km = f.kind === 2 ? 40 : f.kind === 1 ? 6 : 1;
  const cash = foeCash(f.t) * km * (1 + b.cash / 100) * prop('cash') * (dg ? 1.5 : 1);
  S.cash += cash; const loot = [['cash', cash]];
  const gch = f.kind === 2 ? 1 : f.kind === 1 ? 0.35 : 0.04;
  if (Math.random() < gch) { const g = Math.ceil((f.kind === 2 ? 40 : f.kind === 1 ? 6 : 1) * (1 + f.t * 0.08) * (1 + b.gems / 100) * prop('gems')); S.gems += g; loot.push(['gems', g]); }
  gainXp(Math.ceil(3 * Math.pow(1.35, f.t) * km * prop('xp') * (dg ? 1.5 : 1)));
  S.st.kills++; bumpQ('kills');
  if (f.kind === 1) { S.st.brutes++; bumpQ('brutes'); }
  rollDrops(f, loot);
  UI.loot(loot);
  addSoul(f);
  if (dg) { if (f.kind === 2) dungeonWin(f); }
  else {
    if (f.kind === 0) S.prog.kills++; else if (f.kind === 1) S.prog.brutes++;
    if (f.kind === 2) bossDown(f); else checkMission();
    if (f.kind === 0 && Math.random() < (W().prop.revive || 0)) setTimeout(() => { if (!G.dg && S.world === 2 && G.foes.length < 22) { const n = spawnFoe(0, f.pos); UI.dn(n.pos, 'SE RELÈVE !', 'fail'); burst(n.pos.clone().setY(0.5), 0xc26bff, 16); } }, 2200);
  }
  SFX.hit();
}

/* ---------- butin (rangs F → S selon la source) ---------- */
function luckMult() { return (1 + bonus().luck / 100) * prop('luck'); }
function lucky(name, chance, col) { S.st.lucky++; UI.lucky(name, chance, col); SFX.play('win', 0.5); }
const srcRW = () => G.dg ? dungeonRW(G.dg.r) : WORLD_RW[S.world];
export function rollItem(list, rw, luck = 0) {
  let r = rollRankW(rw, luck); let pool = list.filter(x => x.r === r);
  while (!pool.length && r > 0) { r--; pool = list.filter(x => x.r === r); }
  return pick(pool);
}
function rollDrops(f, loot) {
  const L = luckMult(), rw = srcRW(), luck = bonus().luck, dgm = G.dg ? 2.5 : 1;
  const tries = [[WEAPONS, f.kind === 2 ? 0.3 : f.kind === 1 ? 0.03 : 0.0025, 'w', giveWeapon], [RELICS, f.kind === 2 ? 0.18 : f.kind === 1 ? 0.015 : 0.001, 'rel', giveRelic], [ACCS, f.kind === 2 ? 0.14 : f.kind === 1 ? 0.01 : 0.0008, 'acc', giveAcc]];
  const tot = rw.reduce((a, x) => a + x, 0), top = rw.reduce((m, x, i) => x > 0 ? i : m, 0);
  for (const [list, base, k, give] of tries) {
    const ch = base * L * dgm; if (Math.random() >= ch) continue;
    const it = rollItem(list, rw, luck); give(it.id); loot.push([k, it.id]);
    if (it.r >= top || it.r >= 4) lucky(it.n, ch * (rw[it.r] || 1) / tot, RAR[it.r].c);
  }
  if (!G.dg && f.kind === 2 && Math.random() < 0.4) { const kr = rollRankW(PORTAL_RW[S.world]); S.keys[kr]++; UI.toast(`Clé de portail rang ${SRANKS[kr]} obtenue !`, 'gold'); UI.dot('donjons'); }
}
export function rollRelic() { const r = rollItem(RELICS, SUMMON.rates.map(x => x * 1000), 0); giveRelic(r.id); return r; }
export function giveWeapon(id) {
  const it = S.w[id]; if (it) { if (it.st < W_MAXSTAR) it.st++; else S.cash += foeCash(tierNow()) * 50; } else S.w[id] = { lv: 0, st: 0 };
  dirty(); UI.dot('inv');
}
export function giveRelic(id) {
  const it = S.rel[id]; if (it) { if (it.lv < R_MAXLV) it.lv++; } else { S.rel[id] = { lv: 0 }; if (S.relEq.length < relicSlotsN()) S.relEq.push(id); }
  dirty(); UI.dot('inv');
}
export function giveAcc(id) {
  const it = S.acc[id]; if (it) { if (it.lv < A_MAXLV) it.lv++; } else { S.acc[id] = { lv: 0 }; const a = ACCS.find(x => x.id === id); if (!S.accEq[a.slot]) S.accEq[a.slot] = id; }
  dirty(); UI.dot('inv');
}

/* ---------- XP / niveau ---------- */
function gainXp(x) {
  S.xp += x; let up = 0;
  while (S.xp >= xpNeed(S.lvl)) { S.xp -= xpNeed(S.lvl); S.lvl++; up = 1; }
  if (up) {
    G.P.hp = heroHp(); dirty(); pillar(G.P.pos, 0xffcc33, 10); SFX.play('power', 0.6);
    UI.banner('NIVEAU ' + S.lvl, `Armée max : ${armyMax(S.lvl)} ombres`, '#ffcc33');
    const free = armyMax(S.lvl) - equipped().length; if (free > 0) { S.sh.filter(s => !s.eq).sort((a, b) => shDmg(b) - shDmg(a)).slice(0, free).forEach(s => s.eq = true); syncArmy(); }
  }
}

/* ---------- missions et boss des mondes ---------- */
function checkMission() {
  const m = mission(S.world, S.stage[S.world]);
  if (!G.boss && !G.bossPortal && S.prog.kills >= m.kills && S.prog.brutes >= m.brutes) {
    const p = G.P.pos.clone().add(V(rnd(-8, 8), 0, rnd(-8, 8))); collide(p, 2, G.info.R - 8);
    const pm = portalMesh(0xff3355, 1.6); pm.position.copy(p); E.scene.add(pm); G.bossPortal = { obj: pm, t: 2.2, p };
    UI.banner('BOSS EN APPROCHE', `${UNIQUES[W().uq].n}, ${UNIQUES[W().uq].t}`, '#ff3355'); SFX.play('bell', 0.7); E.shake = 0.4;
  }
}
function bossDown(f) {
  S.st.bosses++; bumpQ('bosses'); S.prog = { kills: 0, brutes: 0 };
  const w = S.world;
  if (S.stage[w] < STAGES) {
    S.stage[w]++;
    if (S.stage[w] >= STAGES) {
      if (S.maxWorld < Math.min(3, w + 1)) S.maxWorld = Math.min(3, w + 1);
      UI.banner('MONDE CONQUIS !', w < 3 ? `${WORLDS[w + 1].n} est débloqué` : 'Tu règnes sur l\'Abysse', W().col); SFX.play('win', 0.8);
    } else { UI.banner(`PALIER ${S.stage[w] + 1}`, 'Les ennemis deviennent plus forts… et plus riches', W().col); SFX.play('win', 0.6); }
  }
  pillar(f.pos, 0xffcc33, 14); shock(f.pos, 0xffcc33, 10, 1); E.shake = 0.6;
  for (const x of G.foes) if (!x.dead && x !== f) { x.dead = 1; x.ch.play('death', { once: true }); x.deathT = 1.2; }
  save();
}

/* ---------- âmes et éveil ---------- */
function addSoul(f) {
  const col = f.kind === 2 ? 0xffcc33 : 0xc26bff;
  const g = new THREE.Group(); const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: E.glowTex, color: col, blending: THREE.AdditiveBlending, depthWrite: false }));
  s.scale.setScalar(f.kind === 2 ? 3.4 : f.kind === 1 ? 2.2 : 1.5); s.position.y = 1.2; g.add(s); g.position.copy(f.pos); E.scene.add(g);
  G.souls.push({ obj: g, s, pos: f.pos.clone(), type: f.type, u: f.u, t: f.t, k: f.kind, dg: G.dg ? G.dg.r : -1, life: f.kind === 2 ? 25 : 14 });
}
const ARISE_BASE = [0.5, 0.3, 0.15];
function soulRank(s) {
  const luck = bonus().luck;
  if (s.u) return UNIQUES[s.u].rk;
  if (s.dg >= 0) { const w = [0, 0, 0, 0, 0, 0, 0]; if (s.dg > 0) w[s.dg - 1] = 60; w[s.dg] += 40; if (s.k === 1) w[s.dg] += 40; return rollRankW(w, luck); }
  let r = rollRankW(WORLD_RW[S.world], luck); if (s.k === 1 && Math.random() < 0.5) r = Math.min(6, r + 1); return r;
}
function makeShadow(s) {
  const rk = soulRank(s); const U = s.u ? UNIQUES[s.u] : null;
  const keys = Object.keys(TRAITS).sort(() => Math.random() - 0.5);
  const tr = keys.slice(0, TRAIT_N[rk]).map(k => [k, traitVal(k, rk)]);
  if (U) tr.unshift([U.sig[0], U.sig[1]]);
  const d = new Date();
  const where = s.dg >= 0 ? `Portail rang ${SRANKS[s.dg]} — ${DUNGEONS[s.dg].n}` : `${W().n}, palier ${Math.min(S.stage[S.world] + 1, STAGES)}`;
  return { id: ++S.shN, type: s.type, u: s.u || null, n: U ? U.n : shadowName(), t: s.t, k: s.k, rk, lv: 0, eq: false, aw: 0, kills: 0, tr,
    born: `${d.toLocaleDateString('fr-FR')} à ${d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`, where };
}
export function arise() {
  const near = G.souls.filter(s => s.pos.distanceTo(G.P.pos) < 16); if (!near.length) { UI.toast('Aucune âme à portée — abats un ennemi d\'abord', 'bad'); return; }
  G.P.ch.play('cast', { once: true, restart: true, speed: 1.4 }); shock(G.P.pos, 0xc26bff, 7, 0.6); SFX.play('seal', 0.6);
  let ok = 0;
  for (const s of near) {
    const base = s.k === 2 && s.dg >= 0 ? 0.35 : ARISE_BASE[s.k];
    const ch = clamp(base * (1 + bonus().arise / 100) * prop('arise'), 0, 0.95);
    removeSoul(s);
    if (Math.random() < ch) {
      ok++;
      const dup = s.u && S.sh.find(x => x.u === s.u);
      if (dup) { dup.aw = Math.min(5, (dup.aw || 0) + 1); pillar(s.pos, 0xffcc33, 10); UI.banner(`${dup.n} S'ÉVEILLE`, `Éveil ${'★'.repeat(dup.aw)} — +25 % de puissance`, '#ffcc33'); S.st.arises++; continue; }
      const sh = makeShadow(s);
      S.sh.push(sh); S.st.arises++; bumpQ('arises');
      if (equipped().length < armyMax(S.lvl)) sh.eq = true;
      else if (sh.rk >= 3 || sh.u) { const weak = equipped().sort((a, b) => shDmg(a) - shDmg(b))[0]; if (weak && shDmg(weak) < shDmg(sh)) { weak.eq = false; sh.eq = true; syncArmy(); } }
      pillar(s.pos, SRANK_COL[sh.rk], 8); UI.dn(s.pos, 'ÉVEIL !', 'arise');
      if (sh.eq) addArmy(sh, s.pos);
      if (sh.rk >= 3 || sh.u) { UI.reveal(sh); if (sh.rk >= 5) lucky(`Ombre ${SRANKS[sh.rk]} — ${sh.n}`, 0.01, SRANK_COL[sh.rk]); } else UI.ariseCard(sh);
    } else { UI.dn(s.pos, 'ÉCHEC', 'fail'); burst(s.pos.clone().setY(1), 0x64748b, 10); }
  }
  if (ok) SFX.play('power', 0.6);
  if (S.sh.length > 400) { S.sh.sort((a, b) => (b.eq - a.eq) || ((b.u ? 1 : 0) - (a.u ? 1 : 0)) || (shDmg(b) - shDmg(a))); S.sh.length = 400; }
  dirty(); UI.dot('ombres');
}
function removeSoul(s) { s.obj.removeFromParent(); G.souls.splice(G.souls.indexOf(s), 1); }

/* ---------- armée d'ombres ---------- */
function addArmy(sh, at) {
  const F = FOES[sh.type];
  const ch = makeChar(F.model, { shadow: true, shadowCol: sh.u ? 0x7a3a10 : sh.rk >= 5 ? 0x7a2a9a : 0x3b1a8a, eyeCol: new THREE.Color(SRANK_COL[sh.rk]).getHex(), scale: (F.sc || 1) * (F.model === 'dragon' ? 0.7 : 1) * (sh.k === 2 ? 1.45 : sh.k === 1 ? 1.15 : 0.95), noShadow: true });
  const p = (at || G.P.pos).clone().add(V(rnd(-2, 2), 0, rnd(-2, 2))); ch.root.position.copy(p); E.scene.add(ch.root);
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.55, 0.75, 24), new THREE.MeshBasicMaterial({ color: sh.u ? 0xffcc33 : SRANK_COL[sh.rk], transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = 0.06; ch.root.add(ring);
  G.army.push({ ch, sh, pos: p, cd: rnd(0, 1), tgt: null, slot: G.army.length, ranged: /Mage/.test(F.model) });
}
export function syncArmy() {
  const want = new Set(equipped().map(s => s.id));
  for (let i = G.army.length - 1; i >= 0; i--) if (!want.has(G.army[i].sh.id)) { G.army[i].ch.dispose(); G.army.splice(i, 1); }
  const have = new Set(G.army.map(a => a.sh.id));
  for (const s of equipped()) if (!have.has(s.id)) addArmy(s);
  G.army.forEach((a, i) => a.slot = i);
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
export function update(dt) {
  G.t += dt; S.st.play += dt; const P = G.P, b = bonus();
  const aspd = 1 + b.aspd / 100, maxHp = heroHp();
  if (G.dg) dungeonTick(dt); else portalTick(dt);
  if (G.dead > 0) { G.dead -= dt; if (G.dead <= 0) { P.pos.copy(G.info.spawn); P.hp = maxHp; P.ch.play('idle'); UI.toast('Tu te relèves… l\'ombre ne meurt jamais', 'good'); } P.ch.update(dt); P.ch.root.position.copy(P.pos); return; }

  /* héros : joystick ou farm automatique */
  const speed = 9 * (1 + b.speed / 100); const jx = G.joy.x, jy = G.joy.y; P.moving = false;
  if (Math.hypot(jx, jy) > 0.15) {
    const s = Math.sin(E.yaw), c = Math.cos(E.yaw);
    const dx = jx * c + jy * s, dz = -jx * s + jy * c;
    P.pos.x += dx * speed * dt; P.pos.z += dz * speed * dt; P.ang = Math.atan2(dx, dz); P.moving = true; P.tgt = null;
  } else if (S.auto) {
    if (!P.tgt || P.tgt.dead) P.tgt = (G.boss && !G.boss.dead && G.boss.pos.distanceTo(P.pos) < 40) ? G.boss : nearestFoe(P.pos, 60);
    if (P.tgt) { const st = 1.6 + P.tgt.r; tv.subVectors(P.tgt.pos, P.pos); const d = tv.length(); if (d > st) { tv.multiplyScalar(Math.min(speed * dt, d - st) / d); P.pos.add(tv); P.ang = Math.atan2(tv.x, tv.z); P.moving = true; } }
  }
  collide(P.pos, 0.6, G.info.R); P.ch.root.position.copy(P.pos);
  const ra = P.ch.root.rotation; ra.y += (((P.ang - ra.y + Math.PI * 3) % (Math.PI * 2)) - Math.PI) * Math.min(1, dt * 14);
  P.ch.play(P.moving ? 'run' : (P.ch.lock > 0 ? P.ch.cur : 'idle'), { speed: P.moving ? 1.25 : 1 }); P.ch.lock -= dt;
  P.atkCd -= dt;
  if (P.atkCd <= 0) { const t = nearestFoe(P.pos, 2.6); if (t && (S.auto || G.punch > 0)) heroStrike(t, aspd); }
  G.punch = Math.max(0, (G.punch || 0) - dt);
  P.hp = Math.min(maxHp, P.hp + maxHp * 0.03 * dt);
  P.aura.rotation.z += dt; P.aura.material.opacity = 0.35 + Math.sin(G.t * 3) * 0.2;
  P.ch.update(dt);
  G.nearPortal = !!(G.portal && G.portal.pos.distanceTo(P.pos) < 4.5);

  /* armée */
  const fw = V(Math.sin(P.ch.root.rotation.y), 0, Math.cos(P.ch.root.rotation.y)), rt = V(fw.z, 0, -fw.x);
  for (const a of G.army) {
    if (!a.tgt || a.tgt.dead || a.tgt.pos.distanceTo(P.pos) > 22) a.tgt = nearestFoe(a.pos, 18);
    const range = (a.ranged ? 7 : 1.5) + (a.tgt ? a.tgt.r : 0);
    let mv = false;
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
      const row = Math.floor(a.slot / 5), col = (a.slot % 5) - 2;
      const want = P.pos.clone().addScaledVector(fw, -2.6 - row * 2).addScaledVector(rt, col * 1.9);
      mv = moveTo(a, want, speed * 1.15, dt, 0.4);
      if (!mv) a.ch.root.rotation.y += (P.ch.root.rotation.y - a.ch.root.rotation.y) * Math.min(1, dt * 5);
    }
    a.ch.lock -= dt; if (mv) a.ch.play('run'); else if (a.ch.lock <= 0) a.ch.play('idle');
    collide(a.pos, 0.4, G.info.R); a.ch.root.position.copy(a.pos); a.ch.update(dt);
  }

  /* ennemis */
  for (let i = G.foes.length - 1; i >= 0; i--) {
    const f = G.foes[i];
    if (f.dead) { f.deathT -= dt; f.ch.update(dt); if (f.deathT <= 0) { f.ch.dispose(); G.foes.splice(i, 1); } continue; }
    const d = f.pos.distanceTo(P.pos); let mv = false;
    if (f.aggro || d < (f.kind === 2 ? 40 : 12)) {
      mv = moveTo(f, P.pos, (f.kind === 2 ? 4.5 : 5.5), dt, 1.4 + f.r);
      if (!mv) {
        f.ch.root.rotation.y = Math.atan2(P.pos.x - f.pos.x, P.pos.z - f.pos.z); f.cd -= dt;
        if (f.cd <= 0) { f.cd = f.kind === 2 ? 2 : 1.6; f.ch.play('attack', { once: true, restart: true, speed: 1.4 }); f.ch.lock = 0.6; heroHurt(f); if (f.kind === 2) { shock(f.pos, 0xff3355, 5, 0.5); E.shake = 0.25; } }
      }
    } else {
      f.wander -= dt; if (f.wander <= 0) { f.wander = rnd(2, 5); f.wt = f.home.clone().add(V(rnd(-6, 6), 0, rnd(-6, 6))); }
      if (f.wt) mv = moveTo(f, f.wt, 2.2, dt, 0.3);
    }
    f.ch.lock -= dt; if (mv) f.ch.play(d < 12 ? 'run' : 'walk'); else if (f.ch.lock <= 0) f.ch.play('idle');
    collide(f.pos, f.r * 0.6 + 0.3, G.info.R); f.ch.root.position.copy(f.pos); f.ch.update(dt);
  }

  /* âmes */
  for (let i = G.souls.length - 1; i >= 0; i--) { const s = G.souls[i]; s.life -= dt; s.s.position.y = 1.2 + Math.sin(G.t * 3 + i) * 0.25; s.s.material.opacity = Math.min(1, s.life / 3); if (Math.random() < dt * 6) E.particles.emit({ x: s.pos.x, y: 0.6, z: s.pos.z }, s.k === 2 ? 0xffcc33 : 0xc26bff, { spread: 0.4, speed: 1, up: 1.5, grav: -2, life: 0.7, size: 0.5 }); if (s.life <= 0) removeSoul(s); }
  if (S.autoArise && G.souls.length && (G.ariseT = (G.ariseT || 0) - dt) <= 0) { G.ariseT = 1.5; if (G.souls.some(s => s.pos.distanceTo(P.pos) < 16)) arise(); }

  /* portail du boss */
  if (G.bossPortal) { G.bossPortal.t -= dt; if (G.bossPortal.t <= 0) { const p = G.bossPortal.p; G.bossPortal.obj.removeFromParent(); G.bossPortal = null; spawnFoe(2, p); pillar(p, 0xff3355, 12); E.shake = 0.5; SFX.play('boom', 0.7); } }

  /* population du monde */
  if (!G.dg) {
    const alive = G.foes.filter(f => !f.dead && f.kind < 2).length; const cap = Math.round(11 * (prop('pack') > 1 ? 1.5 : 1));
    if (alive < cap && (G.spT = (G.spT || 0) - dt) <= 0) {
      G.spT = 0.6; const k = Math.random() < 0.14 ? 1 : 0; const n = spawnFoe(k);
      if (prop('pack') > 1 && !k) spawnFoe(0, n.pos.clone().add(V(rnd(-2, 2), 0, rnd(-2, 2))));
    }
  }
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
export function punch() { G.punch = 0.6; const t = nearestFoe(G.P.pos, 3.2); if (t && G.P.atkCd <= 0) heroStrike(t, 1 + bonus().aspd / 100); }
function heroHurt(f) {
  const P = G.P; if (G.dead > 0) return;
  const ratio = clamp(f.max / (f.kind === 2 ? 40 : f.kind === 1 ? 6 : 1) / (power() * 1.5), 0.35, 8);
  const d = heroHp() * f.dmgPct * ratio * rnd(0.85, 1.15); P.hp -= d; UI.dn(P.pos, d, 'hurt'); UI.hurt();
  if (P.hp <= 0) {
    P.ch.play('death', { once: true, restart: true }); SFX.play('lose', 0.6);
    if (G.dg) { G.dead = 99; dungeonFail('Tu es tombé'); return; }
    G.dead = 2.5; UI.banner('VAINCU', 'Renforce ton arme et ton armée', '#ff3355'); S.prog.kills = Math.max(0, S.prog.kills - 5);
  }
}
export { spawnFoe };
