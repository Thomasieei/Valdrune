// =================== Sanctuaire d'Émeraude : donjon de groupe à 5 ===================
let sylveMeterT = 0;
let sylve = null, compteur = null, dangers = [], zonesSol = [], orbes = [], rayons = [];
const MOBS_PACKS = [['moussu', 'moussu', 'ronce'], ['moussu', 'ecorce', 'ronce', 'druide'], ['ecorce', 'ronce', 'druide', 'moussu'], ['ecorce', 'ecorce', 'druide', 'ronce']];
function tierJoueur() { return Math.max(1, Math.min(8, Math.round((statsHeros(J.equip).ip - 320) / 100) + 1)); }
function modeSylve() {
  const t = tierJoueur();
  const argent = t <= 2 ? 1.6 : t <= 5 ? 12 : 58, xp = t <= 2 ? 1.4 : t <= 5 ? 6 : 16;
  return { id: 'sylve', sylve: true, nom: 'Groupe de 5', lieu: 'Sanctuaire d’Émeraude', argent, xp, tiers: [t, Math.min(8, t + 1)], mobTier: t + 0.4, bossTier: [t + 0.7, t + 0.9, t + 1.1, t + 1.4], couleur: '#3affa0', tier: t };
}
// le groupe : un épéiste, un arbalétrier, un mage, et un 4e au hasard (plus l'ami du joueur s'il en a un)
function preparerGroupeSylve() {
  const ip = statsHeros(J.equip).ip; const pris = [];
  const types = ['epee', 'arbalete', 'baton', hasard(['epee', 'arbalete', 'baton'])];
  return types.map((type, i) => {
    if (i === 0 && groupe) { pris.push(groupe.nom); groupe.trait = groupe.trait || hasard(Object.keys(TRAITS)); return groupe; }
    const d = donneesBot(ip + rnd(-50, 60), pris); pris.push(d.nom);
    d.equip = genererEquipRival(ip + rnd(-50, 60), type); d.niv = nivBot(d.equip); d.ip = statsHeros(d.equip, d.niv).ip; d.modele = type === 'arbalete' && Math.random() < 0.5 ? 'Rogue' : ARMES[type].model;
    d.trait = hasard(Object.keys(TRAITS).filter(t => !pris.includes('trait:' + t))); pris.push('trait:' + d.trait);
    return d;
  });
}
let assetsSylvePrets = false;
async function entrerSylve(membres = null) {
  memoriserMode('Sanctuaire d’Émeraude', () => entrerSylve());
  membres = membres || preparerGroupeSylve();
  if (!assetsSylvePrets) {
    UI.toast('Ouverture du Sanctuaire…');
    await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {});
    assetsSylvePrets = true;
  }
  fondu(() => {
    viderMonde();
    modeActuel = modeSylve(); bossVaincus = 0; invasion = null;
    monde = construireSylve();
    G.scene.background.set('#4a7a6a'); G.scene.fog.color.set('#3f6a5a'); G.scene.fog.density = 0.014;
    G.hemi.color.set('#d8ffe8'); G.hemi.groundColor.set('#2a4a22'); G.hemi.intensity = 1.25; G.sun.intensity = 1.55; G.sun.color.set('#fff0c8');
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    for (const d of membres) { const a = creerCombattant(pointLibrePres(monde.spawn, 1.5, 3.5), d, 'allie'); a.membreSylve = true; appliquerTrait(a, d.trait || 'bavard'); }
    monde.packs.forEach((pk, i) => { const types = MOBS_PACKS[pk.troncon]; pk.pts.forEach((p, k) => { const e = creerEnnemi(MOBS_SYLVE[types[k % types.length]], p, modeActuel.mobTier, 100 + i); e.angle = Math.atan2(-pk.dir.x, -pk.dir.z); e.root.rotation.y = e.angle; }); });
    monde.salles.forEach((s, k) => { const b = creerBoss(BOSS_SYLVE[k], s.c.clone(), modeActuel.bossTier[k], { id: 'S' + s.id }); b.pvMax = b.pv = Math.round(b.pvMax * 1.0); b.idxSylve = k; });
    creerSortie(monde.sortie);
    sylve = { debut: G.t, segDebut: G.t, butinJoueur: { argent: 0, objets: [] } };
    compteur = { total: new Map(), seg: new Map(), noms: [J.nom, ...allies.filter(a => a.membreSylve).map(a => a.nom)] };
    UI.journal('Sanctuaire d’Émeraude', 'Suivez le chemin à travers la forêt. Gardiens vaincus : 0 / 4', 0);
    UI.boutonDegats(true);
    UI.zone('Sanctuaire d’Émeraude', `Groupe de 5 · T${modeActuel.tiers[0]}–T${modeActuel.tiers[1]}`);
    $('#btnQuitter').hidden = false;
    setTimeout(() => { UI.toast('Sanctuaire d’Émeraude', true); UI.toast('Un seul chemin. Quatre gardiens. Restez groupés.'); for (const a of allies) emoteBot(a, ['salut', 'feu', 'diable', 'gg'], 0.5, rnd(1, 3)); }, 700);
    son('forceField_000', 0.6, 0.9);
    G.renderer.compile(G.scene, G.camera);
  });
}
function objetSylve(t, qMin) {
  const q = Math.min(4, qMin + (Math.random() < 0.35 ? 1 : 0) + (Math.random() < 0.08 ? 1 : 0));
  return Math.random() < 0.4 ? creerArme(hasard(CLASSES_BASE), t, q) : creerArmure(hasard(['casque', 'plastron', 'bottes']), t, q);
}
function noterDegats(src, d) {
  if (!compteur || !(d > 0)) return;
  const nom = !src || src === joueur || src.invoc ? J.nom : src.nom; if (!nom) return;
  compteur.total.set(nom, (compteur.total.get(nom) || 0) + d); compteur.seg.set(nom, (compteur.seg.get(nom) || 0) + d);
}
// zones dangereuses connues des alliés (pour qu'ils esquivent comme de vrais joueurs)
function dangerSur(p) { for (const z of dangers) { const dx = p.x - z.p.x, dz = p.z - z.p.z; if (dx * dx + dz * dz < (z.r + 0.8) ** 2) return z; } return null; }
function teleC(src, pos, r, duree, couleur, cb, opts = {}) { opts.camp = src.camp; return tele(pos, r, duree, couleur, cb, opts); }
function tele(pos, r, duree, couleur, cb, opts = {}) {
  const p = pos.clone(); const n0 = dangers.length;
  if (opts.ligne) { const a = opts.angle - Math.PI; for (let d = 0; d < r; d += 2) dangers.push({ p: V(p.x + Math.sin(a) * d, 0, p.z + Math.cos(a) * d), r: opts.largeur / 2 + 0.4, t: duree + 0.1 }); }
  else if (opts.cone) { const a = opts.angle + Math.PI / 2; for (let d = 2; d < r; d += 3) dangers.push({ p: V(p.x + Math.sin(a) * d, 0, p.z + Math.cos(a) * d), r: d * Math.tan(opts.cone / 2) + 0.5, t: duree + 0.1 }); }
  else dangers.push({ p, r, t: duree + 0.1 });
  for (let i = n0; i < dangers.length; i++) dangers[i].camp = opts.camp || 'ennemi';
  return telegraphe(pos, r, duree, couleur, cb, opts);
}
function zoneSol(p, r, duree, dps, src, couleur = '#5aff6a', opts = {}) {
  const g = new THREE.Group(); g.position.set(p.x, 0.08, p.z);
  const disque = new THREE.Mesh(new THREE.CircleGeometry(r, 36), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.32, blending: THREE.AdditiveBlending, depthWrite: false }));
  disque.rotation.x = -Math.PI / 2; g.add(disque);
  const bord = new THREE.Mesh(new THREE.RingGeometry(r - 0.18, r, 48), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
  bord.rotation.x = -Math.PI / 2; bord.position.y = 0.01; g.add(bord);
  G.scene.add(g);
  const z = { p: p.clone(), r, fin: duree, t: 0, dps, src, g, disque, tick: 0, couleur, piege: opts.piege };
  zonesSol.push(z); dangers.push({ p: z.p, r, t: duree, zone: z });
  return z;
}
function orbe(src, cible, dmg) {
  const mesh = meshBoule('#ff7ae8', 0.55); const p = V(src.pos.x, 1.4, src.pos.z); mesh.position.copy(p); G.scene.add(mesh);
  const o = { src, cible, dmg, mesh, pos: mesh.position, vie: 7.5 };
  orbes.push(o); return o;
}
function exploserOrbe(o) {
  onde(o.pos, '#ff7ae8', 3, 0.45); emettre(V(o.pos.x, 1, o.pos.z), { n: 36, c1: '#ffd0ff', c2: '#c01aff', vit: 6, vie: 0.6, taille: 0.5 }); son('explosionCrunch_000', 0.35, 1.3);
  toucherZone(o.src, V(o.pos.x, 0, o.pos.z), 2.6, o.dmg);
  G.scene.remove(o.mesh);
}
function rayonsEmeraude(e, n, duree, vit) {
  const g = new THREE.Group(); G.scene.add(g);
  const mat = new THREE.MeshBasicMaterial({ color: '#4affa8', transparent: true, opacity: 0.25, blending: THREE.AdditiveBlending, depthWrite: false });
  for (let i = 0; i < n; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 24), mat); b.position.set(Math.sin(i / n * 6.283) * 12, 1.3, Math.cos(i / n * 6.283) * 12); b.rotation.y = i / n * 6.283; g.add(b); }
  rayons.push({ src: e, n, duree, vit: vit * (Math.random() < 0.5 ? 1 : -1), angle: Math.random() * 6.28, t: 0, avert: 1.6, tick: 0, g, mat });
  UI.toast('Rayons d’émeraude : tournez autour de lui !');
}
function majSylve(dt) {
  for (let i = zonesSol.length - 1; i >= 0; i--) {
    const z = zonesSol[i]; z.t += dt; z.tick -= dt;
    z.disque.material.opacity = 0.22 + 0.12 * Math.sin(z.t * 5);
    if (Math.random() < dt * 6) emettre(V(z.p.x + rnd(-z.r, z.r) * 0.7, 0.3, z.p.z + rnd(-z.r, z.r) * 0.7), { n: 1, c1: '#d0ffb0', c2: z.couleur, dir: V(0, 1, 0), vit: 1.5, vie: 0.8, taille: 0.3 });
    if (z.tick <= 0) { z.tick = 0.5; toucherZone(z.src, z.p, z.r, z.dps * 0.5, z.piege ? { stun: 1.0 } : { slow: 1 }); }
    if (z.t >= z.fin || (z.src && z.src.mort && !z.piege)) { G.scene.remove(z.g); zonesSol.splice(i, 1); }
  }
  for (let i = orbes.length - 1; i >= 0; i--) {
    const o = orbes[i]; o.vie -= dt;
    if (!o.cible || o.cible.mort) { const l = equipeJoueur(); o.cible = l.length ? l.reduce((m, c) => dist2D(c.pos, o.pos) < dist2D(m.pos, o.pos) ? c : m) : null; }
    if (o.cible) { const d = V(o.cible.pos.x - o.pos.x, 0, o.cible.pos.z - o.pos.z); const l = d.length(); if (l > 0.01) o.pos.addScaledVector(d.multiplyScalar(1 / l), 3.6 * dt); o.pos.y = 1.3 + Math.sin(G.t * 6 + i) * 0.2; if (l < 1.2) o.vie = 0; }
    if (Math.random() < 0.6) emettre(o.pos, { n: 1, c1: '#ffd0ff', c2: '#a01aff', vit: 0.6, vie: 0.5, taille: 0.35 });
    // les alliés fuient les spores
    dangers.push({ p: o.pos.clone(), r: 2.4, t: dt * 1.5 });
    if (o.vie <= 0 || (o.src && o.src.mort)) { exploserOrbe(o); orbes.splice(i, 1); }
  }
  for (let i = rayons.length - 1; i >= 0; i--) {
    const r = rayons[i]; r.t += dt;
    if (r.src.mort) { G.scene.remove(r.g); rayons.splice(i, 1); continue; }
    r.g.position.set(r.src.pos.x, 0, r.src.pos.z);
    if (r.t > r.avert) { r.angle += r.vit * dt * (r.src.pv < r.src.pvMax * 0.33 ? 1.3 : 1); r.mat.opacity = 0.75 + 0.2 * Math.sin(r.t * 20); }
    else r.mat.opacity = 0.12 + 0.15 * (r.t / r.avert);
    r.g.rotation.y = r.angle;
    r.tick -= dt;
    if (r.t > r.avert && r.tick <= 0) {
      r.tick = 0.25;
      for (const c of adversaires(r.src)) {
        const dx = c.pos.x - r.src.pos.x, dz = c.pos.z - r.src.pos.z, d = Math.hypot(dx, dz); if (d > 24.5 || d < 1) continue;
        const a = Math.atan2(dx, dz);
        for (let k = 0; k < r.n; k++) { let diff = a - (r.angle + k / r.n * 6.283); diff = Math.atan2(Math.sin(diff), Math.cos(diff)); if (Math.abs(diff) < Math.PI / 2 && Math.abs(Math.sin(diff) * d) < 1.1) { infliger(r.src, c, r.src.dmg * (c === joueur ? 0.7 : 0.3)); break; } }
      }
    }
    if (r.t > r.avert + r.duree) { G.scene.remove(r.g); rayons.splice(i, 1); }
  }
  // phases du dernier boss
  const v = ennemis.find(e => e.boss && e.boss.id === 'verdanthos' && !e.mort && e.etat === 'chasse');
  if (v) {
    const ph = v.pv < v.pvMax * 0.33 ? 3 : v.pv < v.pvMax * 0.66 ? 2 : 1;
    if (ph > (v.phase || 1)) { v.phase = ph; transitionVerdanthos(v, ph); }
  }
}
function viderSylve() {
  for (const z of zonesSol) G.scene.remove(z.g); for (const o of orbes) G.scene.remove(o.mesh); for (const r of rayons) G.scene.remove(r.g);
  zonesSol = []; orbes = []; rayons = []; dangers = [];
  if (!modeActuel || !modeActuel.sylve) { sylve = null; compteur = null; }
}
function debutBossSylve(e) {
  const b = e.boss; sylve.bossT = G.t; if (b.id === 'verdanthos') G.camDist = 31;
  UI.introBoss(b.nom, b.titre, b.couleur);
  son('lowFrequency_explosion_000', 0.8, 0.6); G.shake = 0.6;
  onde(e.pos, b.couleur, 10, 1.2);
  for (const a of allies) if (!a.mort && a.membreSylve) emoteBot(a, ['diable', 'feu', 'toi'], 0.35, rnd(0.5, 2));
}
function finBossSylve(e) {
  bossVaincus++; G.shake = 1.1; son('jingle_win', 0.65); G.camDist = 25;
  gagnerXPRelatif(0.03 + e.idxSylve * 0.01); setTimeout(() => montrerXP(e.boss.nom), 9000);
  onde(e.pos, e.boss.couleur, 12, 1.4); emettre(V(e.pos.x, 2, e.pos.z), { n: 160, c1: '#eaffd0', c2: e.boss.couleur, vit: 10, vie: 1.6, taille: 0.55, grav: 2 });
  for (const o of ennemis) if (!o.mort && o.invoque) { o.pv = 0; tuer(o); }
  for (const z of zonesSol) z.fin = 0;
  const k = e.idxSylve; const derniere = k === 3;
  if (derniere) exploit('sanctuaire');
  // butin du gardien (le joueur le voit dans le tableau des scores)
  // le coffre du gardien est commun : sa valeur est partagée entre les 5 joueurs, où qu'ils soient
  const nb = 1 + allies.filter(a => a.membreSylve).length;
  const pool = Math.round(lootCoffre(k >= 2 ? 'violet' : 'bleu', modeActuel, k).argent * 5 * (1 + k * 0.35));
  const butin = { argent: Math.round(pool / nb), pool, nb, objets: [objetSylve(modeActuel.tier, k >= 2 ? 3 : 2)] };
  if (Math.random() < 0.35) butin.objets.push(objetSylve(modeActuel.tier, 2));
  if (Math.random() < 0.12 + k * 0.05) butin.objets.push(objetSylve(Math.min(8, modeActuel.tier + 1), 2));
  const lignes = classement(compteur.seg, G.t - (sylve.bossT || sylve.segDebut), G.t - sylve.segDebut);
  if (!derniere) {
    const bar = monde.barrieres[k];
    if (bar) {
      monde.collisions = monde.collisions.filter(c => c.barriere !== k); monde._cg = null;
      son('forceField_000', 0.7, 0.5);
      ajouterVfx(new THREE.Group(), (t) => { bar.groupe.position.y = -t * 2.2; bar.groupe.scale.x = Math.max(0.01, 1 - t * 0.3); if (Math.random() < 0.6) emettre(V(bar.pt.x + rnd(-5, 5), 1, bar.pt.z + rnd(-5, 5)), { n: 2, c1: '#bfffc0', c2: '#2aff6a', vit: 3, vie: 0.8, taille: 0.4 }); if (t > 2.5) { bar.groupe.visible = false; return false; } });
    }
    UI.journal('Sanctuaire d’Émeraude', `Gardiens vaincus : ${bossVaincus} / 4 — les ronces s’ouvrent, continuez le chemin.`, bossVaincus / 4);
  } else {
    const s = monde.salles[3];
    const pos = s.c.clone().add(V(-4, 0, 0));
    const c = COFFRES.find(x => x.id === 'legendaire');
    const obj = cloner('chest_gold', pos.x, 0, pos.z, Math.PI / 4, 2.2); obj.traverse(o => { if (o.isMesh) o.castShadow = true; });
    G.scene.add(obj); const beam = faisceau(V(pos.x, 0, pos.z), '#3affa0', 22, 1.3); G.scene.add(beam);
    setTimeout(() => { const cf = coffres.find(x => x.final); if (cf) for (const a of allies) if (a.membreSylve && !a.mort) a.lootCible = cf; }, 4000);
    coffres.push({ obj, beam, couleur: 'legendaire', def: { ...c, nom: 'Coffre du Sanctuaire', color: '#3affa0' }, boss: { mort: true, boss: e.boss }, pos, ouvert: false, lid: obj.getObjectByName('chest_lid'), final: true });
    if (sortie) { G.scene.remove(sortie.groupe); } creerSortie(s.c.clone().add(V(6, 0, 5)));
    UI.journal('Sanctuaire purifié !', 'Ouvrez le Coffre du Sanctuaire pour voir les dégâts totaux et le butin de chacun.', 1);
  }
  setTimeout(() => {
    // plus de grand panneau qui bloque : le butin tombe directement, un petit résumé s'affiche, les dégâts restent consultables (bouton à gauche)
    J.argent += butin.argent; for (const it of butin.objets) ajouterSac(it, true); son('handleCoins', 0.6); sauver();
    sylve.butinJoueur.argent += butin.argent; sylve.butinJoueur.objets.push(...butin.objets);
    const moi = lignes.findIndex(l => l.moi);
    UI.resumeBoss({ nom: e.boss.nom, couleur: e.boss.couleur, rang: moi + 1, nb: lignes.length, argent: butin.argent, pool: butin.pool, objets: butin.objets });
    if (!derniere) UI.toast('Le chemin est ouvert : en avant !', true);
    compteur.seg = new Map(); sylve.segDebut = G.t; sylve.bossT = null;
  }, 2600);
}
function classement(map, dureeBoss, dureeSeg) {
  const total = [...map.values()].reduce((a, b) => a + b, 0) || 1;
  return compteur.noms.map(nom => {
    const a = nom === J.nom ? null : allies.find(x => x.nom === nom);
    const type = nom === J.nom ? J.equip.arme.type : a ? a.equip.arme.type : 'epee';
    const d = map.get(nom) || 0;
    return { nom, type, ip: nom === J.nom ? statsHeros(J.equip).ip : a ? a.ip : 0, degats: d, part: d / total, dps: d / Math.max(1, dureeSeg), moi: nom === J.nom };
  }).sort((x, y) => y.degats - x.degats);
}
function ouvrirCoffreFinal(c) {
  c.ouvert = true; UI.action(null); if (c.couleur === 'legendaire') exploit('coffre_legende');
  son('creak1', 0.7); son('jingle_legend', 0.7);
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.4, c.pos.z), { n: 160, c1: '#eaffd0', c2: '#3affa0', vit: 9, vie: 1.5, taille: 0.5, grav: 4, monte: 5 }); onde(c.pos, '#3affa0', 7, 1);
  const t = modeActuel.tier;
  const lignes = classement(compteur.total, 0, G.t - sylve.debut);
  // 2 pièces à ton tier (belle qualité) + 1 pièce du tier suivant, à viser pour plus tard
  const objetsPour = () => { const o = [objetSylve(t, 3), objetSylve(t, 2), objetSylve(Math.min(8, t + 1), 2)]; if (Math.random() < 0.25) o.push(objetSylve(Math.min(8, t + 1), 3)); return o; };
  const pool = Math.round(lootCoffre('violet', modeActuel, 3).argent * 5 * 2);
  const part = Math.round(pool / lignes.length);
  for (const l of lignes) l.butin = { argent: part, objets: objetsPour() };
  const moi = lignes.find(l => l.moi);
  setTimeout(() => UI.recapFinal({ duree: G.t - sylve.debut, total: lignes.reduce((a, l) => a + l.degats, 0), lignes, pool, precedents: sylve.butinJoueur }, () => {
    J.argent += moi.butin.argent; for (const it of moi.butin.objets) ajouterSac(it, true); son('handleCoins', 0.7); sauver(); c.beam.visible = false;
    for (const a of allies) if (!a.mort) emoteBot(a, ['gg', 'merci', 'feu', 'ez'], 0.8, rnd(0.3, 2));
    proposerRefaire();
  }), 900);
}
function mortSylve() {
  son('lowFrequency_explosion_000', 0.7, 0.5);
  const vivants = allies.filter(a => !a.mort && a.membreSylve);
  if (!vivants.length) { const perte = Math.round(J.argent * 0.05); J.argent -= perte; sauver(); setTimeout(() => UI.mort(`Tout le groupe est tombé. Tu perds ${perte.toLocaleString('fr-FR')} pièces d’argent.`, () => fondu(() => lancerHub())), 1600); return; }
  UI.toast('Tu es tombé… un allié va te relever', true);
  emoteBot(hasard(vivants), ['oups', 'rip', 'toi'], 0.8, 1);
  programmer(9, () => {
    if (!joueur.mort || !modeActuel || !modeActuel.sylve) return;
    const a = allies.find(x => !x.mort && x.membreSylve) || null;
    if (!a) return mortSylve();
    joueur.mort = false; joueur.pv = joueur.st.pvMax * 0.5; joueur.invuln = 2; joueur.pos.copy(pointLibrePres(a.pos, 1, 2.5)); joueur.jouer(joueur.def.idle);
    onde(joueur.pos, '#9dff8a', 4, 0.7); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 50, c1: '#eaffd0', c2: '#3aff6a', vit: 4, vie: 1, taille: 0.4, monte: 3 });
    UI.toast(`${a.nom} t’a relevé`);
  });
}
// ---- capacités des gardiens du Sanctuaire ----
function capaciteSylve(e) {
  const b = e.boss; const cibles = adversaires(e).filter(c => dist2D(c.pos, e.pos) < 30);
  if (!cibles.length) return;
  const pj = (e.tc || cibles[0]).pos.clone();
  const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
  const rouge = '#ff2a2a';
  if (b.id === 'ronces') {
    const r = e.cycle % 3;
    if (r === 1) { // ronces jaillissantes vers 3 joueurs, laissent des épines au sol
      e.attaqueT = 1.4; e.jouer('2H_Melee_Attack_Spinning', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      for (const c of [...cibles].sort(() => Math.random() - 0.5).slice(0, 3)) {
        const a = Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z); const o = e.pos.clone();
        tele(o, 17, 1.15, rouge, () => {
          for (let d = 2; d < 17; d += 1.4) emettre(V(o.x + Math.sin(a) * d, 0.4, o.z + Math.cos(a) * d), { n: 4, c1: '#bfffa0', c2: '#2a6a1a', dir: V(0, 1, 0), vit: 7, disp: 0.6, vie: 0.6, taille: 0.5, grav: 8 });
          son('impactPlank_medium_000', 0.6, 0.7); G.shake = 0.4;
          for (const cc of adversaires(e)) { const dx = cc.pos.x - o.x, dz = cc.pos.z - o.z; const along = dx * Math.sin(a) + dz * Math.cos(a), perp = Math.abs(dx * Math.cos(a) - dz * Math.sin(a)); if (along > 0 && along < 17 && perp < 1.5) infliger(e, cc, e.dmg * 2.6, { slow: 2 }); }
          for (let d = 5; d < 17; d += 5.5) zoneSol(V(o.x + Math.sin(a) * d, 0, o.z + Math.cos(a) * d), 1.9, 6, e.dmg * 0.55, e, '#5aff4a');
        }, { ligne: true, largeur: 3, angle: a + Math.PI });
      }
    } else if (r === 2) { // étreinte : tout le monde doit s'éloigner, puis les ronces poursuivent
      e.attaqueT = 2.2; e.jouer('Spellcast_Summon' in e.actions ? 'Spellcast_Summon' : 'Idle_Combat', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      const c0 = e.pos.clone();
      tele(c0, 8, 1.5, rouge, () => { G.shake = 0.9; onde(c0, '#7dff6a', 9, 0.6); emettre(V(c0.x, 0.4, c0.z), { n: 80, c1: '#d0ffb0', c2: '#2a8a1a', vit: 10, vie: 0.8, taille: 0.6, hemi: true }); son('impactPlate_heavy_000', 0.8, 0.5); toucherZone(e, c0, 8, e.dmg * 3.2); });
      programmer(1.6, () => { if (e.mort) return; for (const c of adversaires(e)) { const p = c.pos.clone(); tele(p, 3, 1.1, rouge, () => { emettre(V(p.x, 0.4, p.z), { n: 25, c1: '#bfffa0', c2: '#2a6a1a', dir: V(0, 1, 0), vit: 8, disp: 1, vie: 0.6, taille: 0.5 }); toucherZone(e, p, 3, e.dmg * 2.2, { slow: 2 }); }); } });
      if (e.pv < e.pvMax * 0.5 && !e.renforts) { e.renforts = true; for (let i = 0; i < 3; i++) { const p = pointLibrePres(e.pos, 4, 7); const m2 = creerEnnemi(MOBS_SYLVE.moussu, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); } UI.toast('Le Tisserand appelle la forêt !'); }
    } else { // bond fracassant sur le plus éloigné
      const loin = cibles.reduce((m, c) => dist2D(c.pos, e.pos) > dist2D(m.pos, e.pos) ? c : m); const p = loin.pos.clone();
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pointLibrePres(p, 0, 1.2, 1.2); e.sautD = e.sautT = 1.25; e.sautH = 5; e.attaqueT = 1.7;
      tele(p, 4.5, 1.25, rouge, () => { G.shake = 1; onde(p, '#9aff6a', 7, 0.6); emettre(V(p.x, 0.3, p.z), { n: 60, c1: '#d8c8a8', c2: '#3a6a2a', vit: 9, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); toucherZone(e, p, 4.5, e.dmg * 3.6, { slow: 2.5 }); });
    }
  } else if (b.id === 'sylphe') {
    const r = e.cycle % 3;
    if (r === 1) { // spores traqueuses : il faut les promener
      e.attaqueT = 1.2; e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      UI.toast('Spores traqueuses : fuyez-les !');
      for (const c of [...cibles].sort(() => Math.random() - 0.5).slice(0, e.pv < e.pvMax * 0.4 ? 4 : 3)) programmer(0.5, () => { if (!e.mort) orbe(e, c, e.dmg * 2.6); });
    } else if (r === 2) { // pluie de pétales
      e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.0;
      for (const c of cibles) for (let i = 0; i < 2; i++) {
        const p = i ? c.pos.clone().add(V(rnd(-4, 4), 0, rnd(-4, 4))) : c.pos.clone();
        tele(p, 2.8, 1.2 + i * 0.35, rouge, () => { emettre(V(p.x, 3, p.z), { n: 30, c1: '#ffd0f0', c2: '#ff5ab8', vit: 5, vie: 0.8, taille: 0.45, grav: 6 }); onde(p, '#ff7ae8', 3, 0.4); son('impactGeneric_light_000', 0.4, 1.3); toucherZone(e, p, 2.8, e.dmg * 2.3); });
      }
    } else { // floraison : elle disparaît, réapparaît ailleurs et explose ; du pollen reste derrière elle
      const s = monde.salles[1]; const avant = e.pos.clone();
      fumeeOmbre(avant); zoneSol(avant, 4.2, 9, e.dmg * 0.6, e, '#ff7ae8');
      const a = Math.random() * 6.28; const np = pointLibrePres(V(s.c.x + Math.cos(a) * 9, 0, s.c.z + Math.sin(a) * 9), 0, 2, 1.2);
      e.pos.copy(np); fumeeOmbre(np); e.attaqueT = 1.6; e.jouer('Spellcast_Long' in e.actions ? 'Spellcast_Long' : 'Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      tele(np, 6.5, 1.3, rouge, () => { G.shake = 0.7; onde(np, '#ff9aff', 8, 0.6); emettre(V(np.x, 1, np.z), { n: 90, c1: '#ffe0ff', c2: '#c01aff', vit: 9, vie: 0.8, taille: 0.6 }); son('explosionCrunch_000', 0.6, 0.9); toucherZone(e, np, 6.5, e.dmg * 3.0); });
      if (e.pv < e.pvMax * 0.5 && !e.renforts) { e.renforts = true; for (let i = 0; i < 2; i++) { const p = pointLibrePres(e.pos, 4, 8); const m2 = creerEnnemi(MOBS_SYLVE.druide, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); } UI.toast('La Reine appelle ses druides !'); }
    }
  } else if (b.id === 'chasseur') {
    const r = e.cycle % 3;
    if (r === 1) { // tir de traque : la ligne suit la cible, puis le carreau part
      const c = hasard(cibles); e.attaqueT = 2.1; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, vitesse: 0.45, fin: () => e.jouer('Idle_Combat') });
      if (c === joueur) UI.toast('Le Chasseur te vise : écarte-toi de la ligne !');
      const ligneM = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 30).translate(0, 15, 0), new THREE.MeshBasicMaterial({ color: '#ff3a2a', transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending, depthWrite: false }));
      ligneM.rotation.x = -Math.PI / 2; let ang = 0;
      ajouterVfx(ligneM, (t) => {
        if (e.mort) return false;
        if (t < 1.5) { ang = Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z); e.angle = ang; e.root.rotation.y = ang; dangers.push({ p: c.pos.clone(), r: 1.4, t: 0.05 }); }
        ligneM.position.set(e.pos.x, 0.1, e.pos.z); ligneM.rotation.z = ang + Math.PI; ligneM.material.opacity = t < 1.5 ? 0.25 + 0.4 * (t / 1.5) : 0.9;
        if (t >= 1.75) { tirEnnemi(e, 'carreau', e.dmg * 4.2, V(Math.sin(ang), 0, Math.cos(ang)), 42); son('drawKnife2', 0.8, 0.6); G.shake = 0.3; return false; }
      });
    } else if (r === 2) { // éventail + bond en arrière
      e.attaqueT = 1.4; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, vitesse: 0.7, fin: () => e.jouer('Idle_Combat') });
      tele(e.pos, 15, 0.9, rouge, () => { for (let i = -4; i <= 4; i++) { const a = base + i * 0.14; tirEnnemi(e, 'carreau', e.dmg * 1.6, V(Math.sin(a), 0, Math.cos(a)), 20); } }, { cone: 1.3, angle: base - Math.PI / 2 });
      programmer(1.0, () => { if (e.mort) return; const arr = V(-Math.sin(base), 0, -Math.cos(base)); e.sautA = e.pos.clone(); e.sautB = pointLibrePres(e.pos.clone().addScaledVector(arr, 8), 0, 2, 1.2); e.sautD = e.sautT = 0.6; e.sautH = 2.5; e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 1.4, fin: () => e.jouer('Idle_Combat') }); });
    } else { // pièges de ronces
      e.attaqueT = 1.0; e.jouer('Spellcast_Shoot' in e.actions ? 'Spellcast_Shoot' : '2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      for (const c of cibles) { const p = c.pos.clone().add(V(rnd(-3, 3), 0, rnd(-3, 3))); zoneSol(p, 1.7, 14, e.dmg * 1.2, e, '#ffb02a', { piege: true }); }
      UI.toast('Pièges de ronces : regarde où tu marches');
      if (e.cycle % 6 === 0) for (let i = 0; i < 2; i++) { const p = pointLibrePres(e.pos, 5, 9); const m2 = creerEnnemi(MOBS_SYLVE.ronce, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); }
    }
  } else if (b.id === 'verdanthos') {
    const ph = e.phase || 1; const r = e.cycle % (ph >= 2 ? 4 : 3);
    if (r === 0) { // souffle d'émeraude
      e.attaqueT = 1.9; e.jouer('Headbutt', { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Flying_Idle') }); e.angle = base; e.root.rotation.y = base;
      const c0 = e.pos.clone();
      tele(c0, 14, 1.3, rouge, () => { son('thrusterFire_000', 0.9, 0.5); G.shake = 0.7;
        for (let i = 0; i < 90; i++) { const a = base + rnd(-0.6, 0.6); emettre(V(c0.x, 3, c0.z), { n: 1, c1: '#eaffb0', c2: '#1aff6a', dir: V(Math.sin(a), -0.08, Math.cos(a)), vit: 18, disp: 1, vie: 0.8, taille: 1.1, frein: 1 }); }
        toucherZone(e, c0, 14, e.dmg * 3.4, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.62) } });
        zoneSol(c0.clone().add(V(Math.sin(base) * 8, 0, Math.cos(base) * 8)), 3.2, 7, e.dmg * 0.7, e); }, { cone: 1.25, angle: base - Math.PI / 2 });
    } else if (r === 1) { // pluie de graines : chaque graine laisse une zone toxique
      e.attaqueT = 1.1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      const n = ph === 3 ? 10 : 7;
      for (let i = 0; i < n; i++) {
        const c = cibles[i % cibles.length]; const p = i < cibles.length ? c.pos.clone() : c.pos.clone().add(V(rnd(-7, 7), 0, rnd(-7, 7)));
        const dur = 1.5 + i * 0.12;
        tele(p, 3, dur, rouge, () => { G.shake = 0.45; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#eaffb0', c2: '#1a8a2a', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#5aff8a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); toucherZone(e, p, 3, e.dmg * 2.6); if (Math.random() < 0.5) zoneSol(p, 2.6, 7, e.dmg * 0.6, e); });
        const graine = meshBoule('#5aff6a', 0.7); graine.position.set(p.x + 6, 20, p.z - 6); G.scene.add(graine);
        ajouterVfx(graine, (t) => { const k = t / dur; if (k >= 1) return false; graine.position.set(p.x + 6 * (1 - k), 20 * (1 - k), p.z - 6 * (1 - k)); if (Math.random() < 0.5) emettre(graine.position, { n: 1, c1: '#eaffb0', c2: '#1aff6a', vit: 0.5, vie: 0.4, taille: 0.5 }); });
      }
    } else if (r === 2) { // charge
      e.attaqueT = 1.3; const dir = V(Math.sin(base), 0, Math.cos(base));
      tele(e.pos, 20, 1.1, rouge, () => { e.chargeT = 0.65; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouches = new Set(); e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 4.2, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else { // rayons tournants (phases 2 et 3)
      e.attaqueT = 2.5; e.figeT = ph === 3 ? 7.5 : 6.5; e.jouer('Flying_Idle');
      rayonsEmeraude(e, ph === 3 ? 4 : 3, ph === 3 ? 6.5 : 5.5, ph === 3 ? 0.75 : 0.6);
    }
  }
}
function transitionVerdanthos(e, ph) {
  G.shake = 1.2; son('lowFrequency_explosion_000', 0.9, 0.5);
  onde(e.pos, '#3affa0', 14, 1.4); emettre(V(e.pos.x, 3, e.pos.z), { n: 140, c1: '#eaffd0', c2: '#1aff6a', vit: 12, vie: 1.2, taille: 0.7 });
  UI.introBoss(ph === 2 ? 'Verdanthos s’éveille' : 'Fureur de l’Ancien', ph === 2 ? 'Les rayons d’émeraude balaient la clairière' : 'Tout s’accélère : tenez bon !', '#3affa0');
  // onde de choc qui repousse
  for (const c of adversaires(e)) { const d = V(c.pos.x - e.pos.x, 0, c.pos.z - e.pos.z); const l = d.length() || 1; if (l < 10) { if (c === joueur) { joueur.dashT = 0.3; joueur.dashV = d.multiplyScalar(14 / l); } else { c.dashT = 0.3; c.dashV = d.multiplyScalar(14 / l); } infliger(e, c, e.dmg * 1.2); } }
  const n = ph === 2 ? 4 : 5;
  for (let i = 0; i < n; i++) { const p = pointLibrePres(e.pos, 7, 13); const m2 = creerEnnemi(MOBS_SYLVE[hasard(['moussu', 'ecorce', 'druide'])], p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); }
  e.specT = 2.5; e.cycle = 2;
  if (ph === 3) for (const mt of e.mats) if (mt.emissive) { mt.emissive.set('#2aff6a').multiplyScalar(0.35); mt.userData.baseEmissive = mt.emissive.clone(); }
}



