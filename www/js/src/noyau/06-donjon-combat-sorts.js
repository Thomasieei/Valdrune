// ---------------- Donjon ----------------
let modeHard = false;
async function entrerDonjon(id, opts = {}) {
  const M = MODES[id];
  if (M.nivMin && niveauHeros(J.equip) < M.nivMin && !opts.forcer) { UI.toast(`${M.lieu} : niveau ${M.nivMin} minimum (tu es niveau ${niveauHeros(J.equip)})`, true); son('error_001', 0.4); return; }
  // roches, stalagmites et feux de camp viennent du pack nature : chargés une fois
  if (!assetsSylvePrets) { UI.toast('Descente dans les profondeurs…'); try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (e) {} }
  if (!opts.errant) memoriserMode(M.lieu + ' · ' + M.nom + (opts.hard ? ' · HARD' : '') + (opts.envahir ? ' · invasion' : ''), () => entrerDonjon(id, { envahir: opts.envahir, hard: opts.hard }));
  fondu(() => {
    viderMonde();
    modeActuel = MODES[id]; bossVaincus = 0; modeHard = !!opts.hard; G.abimeT = 2;
    invasion = opts.envahir ? { mode: 'menee', t: 4, rival: null } : (J.accepteInvasion && Math.random() < 0.8 ? { mode: 'subie', t: rnd(40, 100), rival: null } : null);
    monde = construireDonjon(modeActuel); G.solH = monde.solH; G.murs = true;
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.024; G.hemi.intensity = 1.0; G.sun.intensity = 0.9;
    { const th = monde.theme; G.scene.fog.color.set(th.brume); G.scene.background.set(th.brume); G.hemi.color.set(th.hemi); G.sun.color.set(th.lueur); }
    if (modeActuel.abime) { G.scene.fog.color.set('#2a0408'); G.scene.background.set('#1a0206'); G.hemi.color.set('#ff6a7a'); G.sun.color.set('#ff8a8a'); UI.toast('L’ABÎME VOUS OBSERVE', true); }
    else if (modeHard) { G.scene.fog.color.set('#1a0810'); G.hemi.color.set('#c87a9a'); UI.toast('MODE HARD', true); }
    if (groupe) { const a = creerCombattant(pointLibrePres(monde.spawn, 1.5, 3), groupe, 'allie'); const p = Math.random(); Object.assign(a, { autonome: true, perso: p < 0.6 ? 'loyal' : p < 0.85 ? 'solo' : 'traitre', modeA: 'explorer', modeT: rnd(14, 24) }); groupe.trait = groupe.trait || hasard(Object.keys(TRAITS)); appliquerTrait(a, groupe.trait); if (a.trait === 'protecteur') a.modeA = 'suivre'; }
    // monstres
    const types = id === 0 ? ['minion', 'minion', 'minion', 'guerrier', 'archer'] : id === 1 ? ['minion', 'guerrier', 'guerrier', 'archer', 'mage'] : ['guerrier', 'guerrier', 'archer', 'mage', 'mage', 'minion'];
    peuplerDonjon(types);
    // boss dans leur repaire (endormi, à son bureau, en ronde…) et coffres
    if (!opts.envahir) monde.bossSalles.forEach((s, k) => {
      const b = creerBoss(BOSS[k], s.centre.clone().add(V(2, 0, 2)), modeActuel.bossTier[k], s);
      installerRepaire(b, s);
      creerCoffre(monde.coffresPos[k], couleurSelonRang(tirerCouleurCoffre()), b);
    });
    if (!opts.envahir) preparerCrypte();
    creerSortie(monde.sortie);
    if (V1 && !opts.envahir) { placerCaptif(id); deployerCompagnons(true); }
    if (!opts.envahir && !G.sansErrant && (Math.random() < 0.1 || opts.errant)) apparitionErrant();
    UI.journal(modeActuel.lieu, 'Gardiens vaincus : 0 / 4', 0);
    UI.zone(modeActuel.lieu, `${modeActuel.nom} · T${modeActuel.tiers[0]}–T${modeActuel.tiers[1]}`);
    $('#btnQuitter').hidden = false;
    if (opts.envahir) { UI.journal('Invasion', 'Tu entres dans le monde d’un autre joueur…', null); setTimeout(() => UI.toast('Invasion en cours', true), 600); }
    else setTimeout(() => { UI.toast(modeActuel.lieu, true); UI.toast('Trouve les 4 gardiens. Les coffres brillent de leur couleur.'); }, 600);
    son('forceField_000', 0.6, 0.7);
    G.renderer.compile(G.scene, G.camera);
  });
}

function creerEnnemi(def, pos, tierMob, pack, boss = null) {
  const a = new Acteur(def.model, { hauteur: boss ? (boss.hauteur || (boss.model === 'Dragon_Evolved' ? 4.6 : 2.0)) : 2.0, echelle: boss ? (boss.model === 'Dragon_Evolved' ? 1 : boss.scale) : 1 });
  const teinte = (boss && boss.teinte) || def.teinte;
  if (teinte) { const c = new THREE.Color(teinte); for (const mt of a.mats) { mt.color.lerp(c, boss && boss.model === 'Dragon_Evolved' ? 0.55 : 0.4); if (mt.emissive && boss) { mt.emissive.copy(c).multiplyScalar(0.12); mt.userData.baseEmissive = mt.emissive.clone(); } } }
  if (def.humain) { // cultistes : on ne garde que leur arme, cape teinte aux couleurs du culte
    a.montrerSeul(def.noeuds, Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n)));
    if (def.cape) a.teinter(def.cape, '#6a0a1a', 0.75, 0.12);
    a.tenueCouleur && a.tenueCouleur('#5a1018');
    a.armeMesh = a.nodes[def.noeuds[0]];
  }
  if (def.arme) a.armeMesh = a.attacher(def.arme, 'handslot.r');
  if (def.model === 'Skeleton_Warrior' && !boss) a.attacher('Skeleton_Shield_Large_A', 'handslot.l');
  a.root.position.copy(pos); a.root.rotation.y = rnd(0, 6.28);
  G.scene.add(a.root);
  const f = tf(tierMob);
  const kr = (modeHard ? 3 : 1) * (1 + 0.15 * rangK()) * (1 + bonusMaitrise(NIVEAU_REQUIS[Math.max(1, Math.min(8, Math.round(tierMob)))]) * 0.8); // les monstres suivent le niveau attendu de leur zone
  const pvMax = Math.round(160 * f * (def.hp || 1) * (boss ? boss.hpMult : 1) * kr);
  Object.assign(a, {
    def, boss, pos: a.root.position, pv: pvMax, pvMax, dmg: 15 * f * (def.dmg || 1) * (boss ? boss.dmgMult : 1) * kr * (boss ? 1.8 : 2.4) * (MODES.includes(modeActuel) ? [1, 0.62, 2.5, 1.5][modeActuel.id] : 1), // équilibrage : à niveau égal, un monstre seul te tue en ~25 coups, un gardien en ~12
    etat: boss ? 'dormant' : 'idle', atkT: rnd(0.5, 1.5), stunT: 0, slowT: 0, dots: [], pack, angle: a.root.rotation.y, mort: false,
    hauteurPlaque: boss ? (boss.hauteur ? boss.hauteur + 0.8 : boss.model === 'Dragon_Evolved' ? 5.2 : 2.6 * boss.scale) : 2.55, rayon: boss ? (boss.rayon || (boss.model === 'Dragon_Evolved' ? 2.4 : 0.6 * boss.scale)) : 0.55,
    specT: 3, cycle: 0, hover: (boss && boss.hover) || (def.model === 'Dragon_Evolved' ? 0.8 : 0), tierMob,
  });
  a.root.position.y = a.hover;
  if (def.model === 'Dragon_Evolved') a.jouer('Flying_Idle'); else a.jouer(boss ? 'Idle' : 'Idle_Combat', { vitesse: rnd(0.85, 1.1) });
  if (!boss) UI.plaque(a, { nom: def.nom, classe: 'ennemi', lettre: false });
  ennemis.push(a);
  return a;
}
function creerBoss(bdef, pos, tierB, salle) {
  const def = bdef.model === 'Dragon_Evolved'
    ? { nom: bdef.nom, model: 'Dragon_Evolved', arme: null, hp: 1, dmg: 1, vitesse: 4.2, portee: 3.8, type: 'melee', atk: 'Punch' }
    : { ...Object.values(MOBS).find(m => m.model === bdef.model), nom: bdef.nom, arme: bdef.arme, vitesse: 3.4, hp: 1, dmg: 1 };
  const b = creerEnnemi(def, pos, tierB, -1, bdef); b.contour = true; b.contourK = 0.008;
  b.salle = salle; b.idx = BOSS.indexOf(bdef);
  b.root.rotation.y = Math.PI * 0.25; b.angle = b.root.rotation.y;
  UI.plaque(b, { nom: bdef.nom, classe: 'ennemi', lettre: false });
  return b;
}
// chaque rareté a sa propre identité : taille, bois ou or, hauteur du faisceau, cercle runique, étincelles, son d'apparition
const ALLURE_COFFRE = {
  vert: { echelle: 1.25, faisceau: 5, larg: 0.55, op: 0.45, lumiere: 0, runes: false, terne: true },
  bleu: { echelle: 1.5, faisceau: 12, larg: 0.85, op: 1, lumiere: 18, runes: false },
  violet: { echelle: 1.75, faisceau: 20, larg: 1.05, op: 1, lumiere: 30, runes: true, etincelles: 0.25 },
  legendaire: { echelle: 2.05, faisceau: 34, larg: 1.1, op: 0.8, lumiere: 32, runes: true, etincelles: 0.6, pieces: true },
};
function creerCoffre(pos, couleur, boss) {
  const c = COFFRES.find(x => x.id === couleur), A = ALLURE_COFFRE[couleur] || ALLURE_COFFRE.bleu;
  const obj = cloner(couleur === 'legendaire' ? 'chest_gold' : 'chest', pos.x, 0, pos.z, Math.PI / 4, A.echelle);
  obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone();
    if (A.terne) { o.material.color = new THREE.Color('#9a8a6a'); o.material.emissive = new THREE.Color('#1a2a10'); o.material.emissiveIntensity = 0.3; } // vieux coffre de bois, un peu moisi
    else if (couleur !== 'legendaire') { o.material.color = new THREE.Color('#ffffff').lerp(new THREE.Color(c.color), 0.55); o.material.emissive = new THREE.Color(c.color); o.material.emissiveIntensity = couleur === 'violet' ? 0.45 : 0.25; }
    else { o.material.emissive = new THREE.Color('#ffb43a'); o.material.emissiveIntensity = 0.35; o.material.metalness = Math.max(o.material.metalness || 0, 0.6); }
    o.castShadow = true; } });
  G.scene.add(obj);
  const beam = faisceau(V(pos.x, 0, pos.z), c.color, A.faisceau, A.larg); G.scene.add(beam);
  if (A.op < 1) beam.traverse(o => { if (o.material) { o.material = o.material.clone(); o.material.opacity = (o.material.opacity ?? 1) * A.op; } });
  const sol = new THREE.Mesh(new THREE.CircleGeometry(1.4 + A.echelle * 0.6, 32), new THREE.MeshBasicMaterial({ color: c.color, map: texRond(), transparent: true, opacity: A.terne ? 0.35 : 1, blending: THREE.AdditiveBlending, depthWrite: false }));
  sol.rotation.x = -Math.PI / 2; sol.position.y = 0.1; beam.add(sol);
  let runes = null;
  if (A.runes) {
    runes = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: texRunes(c.color), color: c.color, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false }));
    runes.rotation.x = -Math.PI / 2; runes.position.y = 0.13; runes.scale.setScalar(couleur === 'legendaire' ? 6.2 : 4.6); beam.add(runes);
  }
  if (A.lumiere) G.torches.push({ pos: V(pos.x, 2.5, pos.z), color: c.color, int: A.lumiere, dist: 10 + A.echelle * 2 });
  const lid = obj.getObjectByName('chest_lid');
  const C = { obj, beam, couleur, def: c, boss, pos: pos.clone(), ouvert: false, lid, runes, allure: A };
  coffres.push(C);
  // vie du coffre : cercle qui tourne, étincelles qui montent, pièces d'or qui jaillissent du coffre légendaire
  ajouterVfx(new THREE.Group(), (t, dt) => {
    if (!coffres.includes(C) || !obj.parent) return false;
    if (C.ouvert && !C.ceremonie) { if (!runes) return false; runes.material.opacity *= 0.96; return runes.material.opacity > 0.02; }
    if (runes) { runes.rotation.z += (dt || 0.016) * (couleur === 'legendaire' ? 0.6 : 0.35); runes.material.opacity = 0.65 + 0.25 * Math.sin(t * 2.4); }
    if (A.etincelles && Math.random() < A.etincelles) emettre(V(pos.x + rnd(-1, 1), 0.6, pos.z + rnd(-1, 1)), { n: 1, c1: '#ffffff', c2: c.color, dir: V(0, 1, 0), vit: 1.6 + Math.random(), vie: 1.4, taille: 0.22 });
    if (A.pieces && Math.random() < 0.08) emettre(V(pos.x, 1.4, pos.z), { n: 3, c1: '#fff2b0', c2: '#ffb42a', vit: 3.5, vie: 1, taille: 0.3, grav: 9, monte: 4 });
    if (couleur === 'legendaire' && !C.ouvert) { obj.position.y = Math.max(0, Math.sin(t * 2.2)) * 0.06; }
  });
  if (couleur === 'legendaire') { son('jingle_legend', 0.35, 1.25); onde(pos, '#ffc23a', 9, 1.2); G.shake = Math.max(G.shake || 0, 0.25); UI.toast('Un COFFRE LÉGENDAIRE vient d’apparaître !', true); }
  else if (couleur === 'violet') { son('forceField_000', 0.25, 1.3); onde(pos, c.color, 6, 0.8); }
}
// l'ouverture est une petite cérémonie qui grandit avec la rareté (le coffre pourri s'ouvre en un clin d'œil, le légendaire fait trembler la salle)
function ceremonieCoffre(c, fin) {
  const k = c.couleur, col = c.def.color, p = c.pos;
  const ouvrirCouvercle = (vit = 0.6) => { if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / vit) * 1.9; if (t > vit + 0.1) return false; }); };
  if (k === 'vert') { son('creak1', 0.6, 1.1); ouvrirCouvercle(0.35); emettre(V(p.x, 1, p.z), { n: 18, c1: '#d8d0b0', c2: '#6a7a4a', vit: 3, vie: 0.8, taille: 0.35, grav: 5 }); programmer(0.35, fin); return; }
  if (k === 'bleu') { son('creak1', 0.7); son('jingle_loot', 0.45); ouvrirCouvercle(0.5); emettre(V(p.x, 1.2, p.z), { n: 60, c1: '#e8f4ff', c2: col, vit: 6, vie: 1.1, taille: 0.42, grav: 4, monte: 3 }); onde(p, col, 5, 0.7); programmer(0.55, fin); return; }
  // rare et légendaire : le coffre tremble, la lumière monte… puis explose
  c.ceremonie = true; const leg = k === 'legendaire', duree = leg ? 1.5 : 0.8, o = c.obj, x0 = o.position.x, z0 = o.position.z;
  son('forceField_000', leg ? 0.5 : 0.35, leg ? 0.8 : 1.1); if (leg) { ralenti(duree + 0.3, 0.55); G.camZoom0 = G.camZoom || 1; G.camZoom = Math.max(0.62, (G.camZoom || 1) * 0.72); }
  ajouterVfx(new THREE.Group(), (t) => {
    const e = Math.min(1, t / duree);
    o.position.x = x0 + Math.sin(t * 60) * 0.05 * e; o.position.z = z0 + Math.cos(t * 53) * 0.05 * e; o.position.y = leg ? e * e * 0.5 : 0;
    if (Math.random() < 0.5 + e) emettre(V(p.x + rnd(-1.4, 1.4), 0.4, p.z + rnd(-1.4, 1.4)), { n: 1, c1: '#ffffff', c2: col, dir: V(0, 1, 0), vit: 2 + 6 * e, vie: 0.6, taille: 0.25 + 0.2 * e });
    if (c.runes) { c.runes.scale.setScalar((leg ? 6.2 : 4.6) * (1 - e * 0.5)); c.runes.rotation.z += 0.02 + e * 0.25; }
    if (t < duree) return;
    o.position.set(x0, 0, z0); ouvrirCouvercle(0.25); c.ceremonie = false;
    son('explosionCrunch_000', leg ? 0.6 : 0.4, leg ? 0.7 : 1); son(leg ? 'jingle_legend' : 'jingle_loot', 0.6);
    emettre(V(p.x, 1.2, p.z), { n: leg ? 220 : 110, c1: '#ffffff', c2: col, vit: leg ? 13 : 9, vie: 1.4, taille: 0.5, grav: 3, monte: 5 });
    onde(p, col, leg ? 12 : 7, 1); if (leg) { onde(p, '#ffffff', 8, 0.6); G.shake = 0.6; UI.flash && UI.flash('#ffe8a8'); pluiePieces(p, 40); G.camZoom = G.camZoom0 || 1; UI.titreManga('LÉGENDAIRE', 'Le coffre s’ouvre…'); } else G.shake = 0.3;
    programmer(leg ? 0.9 : 0.5, fin); return false;
  });
}
// une gerbe de vraies pièces d'or qui retombent et rebondissent
function pluiePieces(p, n) {
  if (!G.assets.d_coin) return;
  for (let i = 0; i < n; i++) {
    const m = cloner('d_coin', p.x, 1.4, p.z, 0, 1.6 + Math.random() * 0.6); m.traverse(o => { if (o.geometry) o.geometry.userData.partage = true; });
    const a = Math.random() * 6.283, v = 2 + Math.random() * 5; let vx = Math.cos(a) * v, vz = Math.sin(a) * v, vy = 6 + Math.random() * 6, rebonds = 0;
    const spin = V(rnd(-12, 12), rnd(-12, 12), rnd(-12, 12));
    ajouterVfx(m, (t, dt) => {
      dt = Math.min(dt || 0.016, 0.05); vy -= 22 * dt; m.position.x += vx * dt; m.position.y += vy * dt; m.position.z += vz * dt;
      m.rotation.x += spin.x * dt; m.rotation.y += spin.y * dt; m.rotation.z += spin.z * dt;
      if (m.position.y < 0.08) { m.position.y = 0.08; if (rebonds++ < 2 && vy < -2) { vy = -vy * 0.35; vx *= 0.6; vz *= 0.6; spin.multiplyScalar(0.5); if (rebonds === 1 && Math.random() < 0.15) son('handleCoins', 0.12, 1.5); } else { vy = 0; vx *= 0.9; vz *= 0.9; spin.multiplyScalar(0.85); m.rotation.x = Math.PI / 2 * Math.round(m.rotation.x / (Math.PI / 2)); } }
      if (t > 3.5) { m.scale.multiplyScalar(0.9); if (m.scale.x < 0.05) return false; }
    });
  }
}
function creerSortie(pos) {
  const g = new THREE.Group(); g.position.copy(pos); g.rotation.y = Math.PI / 4;
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.12, 10, 48), new THREE.MeshStandardMaterial({ color: '#9a7aff', emissive: '#6a3cff', emissiveIntensity: 2.6 }));
  anneau.position.y = 2; g.add(anneau);
  const disque = new THREE.Mesh(new THREE.CircleGeometry(1.55, 40), new THREE.MeshBasicMaterial({ color: '#6a3cff', map: texRond(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  disque.position.y = 2; g.add(disque);
  G.scene.add(g);
  G.torches.push({ pos: V(pos.x, 2, pos.z), color: '#8a5cff', int: 24, dist: 10 });
  G.anims.push((t) => { anneau.rotation.z = t; disque.material.opacity = 0.6 + 0.3 * Math.sin(t * 3); if (Math.random() < 0.3) emettre(V(pos.x, 2, pos.z), { n: 1, c1: '#b49cff', c2: '#5a2cff', rayon: 1.4, vit: 0.4, vie: 1, taille: 0.25 }); });
  sortie = { groupe: g, pos };
}

// ---------------- Collisions ----------------
// collisions rangées dans une grille : on ne teste que les obstacles voisins (avant : tous, à chaque pas de chaque personnage)
function grilleCollisions() {
  const cs = monde.collisions;
  if (monde._cg && monde._cgN === cs.length) return monde._cg;
  const g = new Map(); let maxR = 0;
  for (const c of cs) { maxR = Math.max(maxR, c.r); const k = Math.floor(c.x / 4) * 4096 + Math.floor(c.z / 4); let l = g.get(k); if (!l) g.set(k, (l = [])); l.push(c); }
  monde._cg = g; monde._cgN = cs.length; monde._cgK = Math.max(1, Math.ceil((maxR + 1) / 4));
  return g;
}
function libre(x, z, r = 0.5) {
  if (!monde.marche(x, z)) return false;
  const g = grilleCollisions(), K = monde._cgK, ix = Math.floor(x / 4), iz = Math.floor(z / 4);
  for (let a = -K; a <= K; a++) for (let b = -K; b <= K; b++) {
    const l = g.get((ix + a) * 4096 + (iz + b)); if (!l) continue; // clé numérique : aucune chaîne créée (moins de ramasse-miettes, moins d'à-coups)
    for (const c of l) { const dx = x - c.x, dz = z - c.z, rr = c.r + r; if (dx * dx + dz * dz < rr * rr) return false; }
  }
  return true;
}
function pointLibreProche(p, r) {
  if (libre(p.x, p.z, r)) return p;
  for (let d = 0.5; d <= 6; d += 0.5) for (let k = 0; k < 16; k++) { const a = k / 16 * 6.283; const x = p.x + Math.cos(a) * d, z = p.z + Math.sin(a) * d; if (libre(x, z, r)) return V(x, 0, z); }
  return null;
}
function deplacer(ent, dx, dz, r = 0.5) {
  const p = ent.pos;
  if (!libre(p.x, p.z, r * 0.6)) { const q = pointLibreProche(p, r); if (q) { p.x = q.x; p.z = q.z; } return true; }
  if (libre(p.x + dx, p.z + dz, r)) { p.x += dx; p.z += dz; return true; }
  if (libre(p.x + dx, p.z, r)) { p.x += dx; return true; }
  if (libre(p.x, p.z + dz, r)) { p.z += dz; return true; }
  // contourner l'obstacle : on essaie des directions voisines
  const l = Math.hypot(dx, dz); if (l < 1e-5) return false;
  const a0 = Math.atan2(dx, dz);
  for (const k of [0.6, -0.6, 1.1, -1.1, 1.57, -1.57]) {
    const a = a0 + k * (ent.contour || 1);
    const nx = Math.sin(a) * l, nz = Math.cos(a) * l;
    if (libre(p.x + nx, p.z + nz, r)) { p.x += nx; p.z += nz; if (k < 0) ent.contour = -(ent.contour || 1); return true; }
  }
  return false;
}
function tourner(a, cible, k) { let d = cible - a; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return a + d * Math.min(1, k); }

// ---------------- Combat : outils ----------------
const vivants = () => ennemis.filter(e => !e.mort && e.etat !== 'dormantCache');
function choisirCible(portee) {
  if (joueur.cibleVerrou && !joueur.cibleVerrou.mort && dist2D(joueur.cibleVerrou.pos, joueur.pos) < portee + 8) return joueur.cibleVerrou;
  const c = joueur.cible; // on garde la cible tant qu'elle reste à portée : plus de demi-tours entre deux ennemis
  if (c && !c.mort && (ennemis.includes(c) || G.agression && estPassant(c)) && dist2D(c.pos, joueur.pos) - c.rayon < portee + 4) return c;
  let best = null, bd = portee + 3;
  for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos) - e.rayon; if (d < bd) { bd = d; best = e; } }
  if (!best && G.agression) for (const e of passantsProches()) { const d = dist2D(e.pos, joueur.pos) - 0.5; if (d < bd) { bd = d; best = e; e.rayon = e.rayon || 0.5; e.hauteurPlaque = e.hauteurPlaque || 2.5; } }
  return best;
}
function directionVisee(portee) {
  if (viseeForcee) { const v = viseeForcee; return v.cible ? { dir: V(v.cible.pos.x - joueur.pos.x, 0, v.cible.pos.z - joueur.pos.z).normalize(), cible: v.cible, point: v.cible.pos.clone() } : { dir: v.dir.clone(), cible: null, point: joueur.pos.clone().addScaledVector(v.dir, Math.min(portee, v.portee * 0.85)) }; }
  const c = choisirCible(portee);
  if (c) return { dir: V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize(), cible: c, point: c.pos.clone() };
  const d = V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle));
  return { dir: d, cible: null, point: joueur.pos.clone().addScaledVector(d, Math.min(portee, 8)) };
}
function faireFace(dir) { joueur.angle = Math.atan2(dir.x, dir.z); joueur.root.rotation.y = joueur.angle; }
function degatsJoueur(mult) {
  const st = joueur.st; const crit = Math.random() * 100 < st.crit;
  let d = st.degats * mult * (crit ? 1.6 + (st.tal && st.tal.critDeg || 0) : 1) * rnd(0.92, 1.08) * (joueur.eveilT > 0 ? 1.3 : 1);
  return { d, crit };
}
function blesser(e, mult, opts = {}) {
  if (e.mort) return;
  if (estPassant(e)) { if (G.agression) blesserPassant(e, opts.fixe || degatsJoueur(mult || 1).d); return; }
  e.coupJoueurT = G.t;
  let { d, crit } = degatsJoueur(mult);
  if (opts.fixe) { d = opts.fixe; crit = false; }
  if (e.reduction) d *= 1 - e.reduction * 0.6;
  if (e.combattant) d = facteurJcJ(auteurCoup || joueur, e, d); // résilience JcJ (avant les vols de vie)
  if (e.bouclierIA > 0) { const a = Math.min(e.bouclierIA, d); e.bouclierIA -= a; d -= a; emettre(V(e.pos.x, 1.2, e.pos.z), { n: 5, c1: '#bfe6ff', c2: '#4a9aff', vit: 3, vie: 0.4, taille: 0.3 }); if (d <= 0) { UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.8, e.pos.z), 'Absorbé', 'info'); return; } }
  if (e.combattant && !opts.fixe && joueur.st.pvp) d *= 1 + joueur.st.pvp / 200;
  if (!opts.fixe && joueur.vampT > 0 && !joueur.mort) { joueur.pv = Math.min(joueur.st.pvMax, joueur.pv + d * (e.combattant ? 0.12 : 0.35)); if (Math.random() < 0.5) emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 4, c1: '#ff8aa0', c2: '#c0103a', vit: 1.5, vie: 0.5, taille: 0.3 }); }
  if (goulet && e.bg) d = modBG(auteurCoup || joueur, e, d);
  const T = joueur.st.tal || {};
  if (T.achev && e.pv < e.pvMax * 0.35) d *= 1 + T.achev;
  if (T.volVie && !joueur.mort && (!auteurCoup || auteurCoup === joueur)) joueur.pv = Math.min(joueur.st.pvMax, joueur.pv + d * T.volVie * (e.combattant ? 0.4 : 1));
  if (auteurCoup && auteurCoup.loup && auteurCoup.frenesieT > 0) auteurCoup.pv = Math.min(auteurCoup.pvMax, auteurCoup.pv + d * 0.2);
  e.pv -= d; e.frapper();
  if (compteur) noterDegats(auteurCoup || joueur, Math.min(d, d + e.pv));
  UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.8, e.pos.z), Math.round(d), crit ? 'crit' : '');
  if (!opts.silence) emettre(V(e.pos.x, 1.2 * (e.boss ? e.boss.scale * 0.7 : 1), e.pos.z), { n: crit ? 14 : 7, c1: opts.c1 || '#fff2d0', c2: opts.c2 || '#d8c8a0', vit: 4, vie: 0.35, taille: 0.25, grav: 6 });
  if (crit) son('impactPlate_heavy_000', 0.35);
  if (e.etat === 'idle' || e.etat === 'dormant') reveiller(e); else if (e.etat !== 'chasse') frappeVivant(e);
  if (joueur.ailesT > 0 && !opts.dot && !opts.silence && !e.mort) e.dots.push({ dps: joueur.st.degats * 0.3 * (joueur.ailesK || 1), t: 2, c: '#ff8a2a' });
  if (opts.stun) {
    let st = e.boss ? opts.stun * 0.35 : opts.stun;
    if (e.combattant) { // rendements décroissants en JcJ : chaque contrôle dans les 12 s dure moitié moins, puis immunité
      if (G.t > (e.drT || 0)) e.drN = 0;
      st *= [1, 0.5, 0.25, 0][Math.min(3, e.drN || 0)]; e.drN = (e.drN || 0) + 1; e.drT = G.t + 12;
    }
    if (st > 0) e.stunT = Math.max(e.stunT, st);
  }
  if (opts.slow) e.slowT = Math.max(e.slowT, opts.slow);
  if (opts.dot) e.dots.push({ ...opts.dot });
  if (opts.air && !e.boss && !(e.combattant && G.t < (e.airCd || 0))) { e.airT = 0.6; if (e.combattant) e.airCd = G.t + 6; }
  joueur.combatT = 4;
  if (e.pv <= 0) tuer(e);
}
function zoneDegats(centre, rayon, mult, opts = {}) {
  let n = 0;
  for (const e of vivants()) {
    const d = dist2D(e.pos, centre);
    if (d > rayon + e.rayon) continue;
    if (opts.cone) { const v = V(e.pos.x - centre.x, 0, e.pos.z - centre.z).normalize(); if (v.dot(opts.dir) < Math.cos(opts.cone / 2) && d > 1.2) continue; }
    blesser(e, mult, opts); n++;
  }
  return n;
}
function reveiller(e) {
  if (e.boss) { if (e.etat === 'dormant' && e.repaire) { eveilBoss(e); e.eveilT = 0.5; return; } if (e.etat === 'dormant') { e.etat = 'chasse'; son('lowFrequency_explosion_000', 0.6, 0.7); if (modeActuel && modeActuel.sylve) debutBossSylve(e); else UI.toast(e.boss.nom + ' se réveille !'); } return; }
  e.etat = 'chasse';
  for (const o of ennemis) if (o.pack === e.pack && o.etat === 'idle' && dist2D(o.pos, e.pos) < 14) o.etat = 'chasse';
}
function tuer(e) {
  if (goulet && e.bg) { mortGoulet(e); return; }
  e.mort = true; e.pv = 0;
  if (e.raidV) { finPillard(e); if (e.champion && !e.issueNotee) noterRival(e, 'tue'); if (duelV === e) { finDuel(); UI.toast('Duel remporté ! Ton peuple t’a vu.', true); moralVille(10); } }
  const anim = e.def.model === 'Dragon_Evolved' ? 'Death' : (e.actions.Death_C_Skeletons ? 'Death_C_Skeletons' : 'Death_A');
  e.jouer(anim, { boucle: false, fondu: 0.1 });
  son('impactGeneric_light_000', 0.5, 0.7);
  emettre(V(e.pos.x, 1, e.pos.z), { n: 22, c1: '#e9e0c8', c2: '#9a8a70', vit: 5, vie: 0.7, taille: 0.3, grav: 9 });
  if (joueur.cibleVerrou === e) joueur.cibleVerrou = null;
  if (e.mission) { mortEnnemiMission(e); return; }
  if (e.rival && e.gardienCrypte) { mortGardienCrypte(e); return; }
  if (e.rival && e.voleur) { finVoleur(e); return; }
  if (e.rival && e.chasseur) { finChasseur(e); return; }
  if (e.rival) { if (arene) { setTimeout(() => { e.descendre = true; }, 4000); verifierArene(); } else if (e.bandit || e.gardeIle) finCombatIle(e); else victoireRival(e); return; }
  if (e.campA && terres) { if (terres.anc) terres.anc.kills++; else compterQueteAnc(e); }
  const part = coequipiers().length && !modeActuel.sylve ? 0.5 : 1;
  const loot = lootMonstre(modeActuel);
  const gain = Math.max(1, Math.round(loot.argent * (e.boss ? 25 : 1) * (modeHard ? 3 : 1) * part * (1 + bonusParch('argent')) * (MODES.includes(modeActuel) ? 1 + 0.25 * rangDe('donjon').i : 1)));
  J.argent += gain;
  const xp = Math.round(10 * (modeActuel.xp || 1) * (e.boss ? 18 : 1) * part * (modeHard ? 3 : 1));
  UI.nombre(V(e.pos.x, 2.2, e.pos.z), `+${gain} ¤`, 'info');
  gagnerXP(xp);
  for (const it of loot.objets) ajouterSac(it, true);
  if (e.boss && e.boss.errant) { mortErrant(e); }
  else if (e.boss && modeActuel.sylve) {
    tirageOmbre(modeActuel.tiers[0], modeActuel.tiers[1], 'boss');
    for (const a of allies) if (!a.mort && !a.invoc && !a.garde) emoteBot(a, ['gg', 'feu', 'merci'], 0.6, 1);
    finBossSylve(e);
  } else if (e.boss) {
    ralenti(0.9, 0.28); // ralenti sur le coup fatal du gardien
    tirageOmbre(modeActuel.tiers[0], modeActuel.tiers[1], 'boss');
    if (modeActuel.id >= 2) tirageOrage(Math.random() < 0.5 ? 7 : 8);
    for (const a of allies) if (!a.mort && !a.invoc && !a.garde) emoteBot(a, ['gg', 'feu', 'merci'], 0.6, 1);
    bossVaincus++; UI.boss(null); G.shake = 1;
    exploit('premier_boss'); if (bossVaincus >= 4 && MODES.includes(modeActuel)) exploitDonjon();
    if (MODES.includes(modeActuel)) changerRang('donjon', 5, 'Gardien vaincu');
    gagnerXPRelatif(0.02); setTimeout(() => montrerXP(e.boss.nom), 1500);
    { const cf = coffres.find(c => c.boss === e); if (cf) for (const a of allies) if (a.autonome && !a.mort && !a.lootCible && dist2D(a.pos, cf.pos) < 45) a.lootCible = cf; }
    for (const a of allies) if (a.autonome && !a.mort) reactionApresBoss(a);
    onde(e.pos, e.boss.couleur, 10, 1.2);
    emettre(V(e.pos.x, 2, e.pos.z), { n: 120, c1: '#ffd27a', c2: e.boss.couleur, vit: 9, vie: 1.4, taille: 0.5, grav: 3 });
    son('jingle_win', 0.6);
    UI.toast(e.boss.nom + ' est vaincu !', true);
    UI.toast('Son coffre peut maintenant être ouvert.');
    UI.journal(modeActuel.lieu, `Gardiens vaincus : ${bossVaincus} / 4`, bossVaincus / 4);
    if (bossVaincus === 4) setTimeout(() => { proposerRefaire(); UI.toast('Donjon nettoyé !', true); UI.journal(modeActuel.lieu, 'Les 4 gardiens sont tombés. Ouvre les coffres puis rentre par le portail violet.', 1); }, 2800);
    // les sbires restants s'effondrent
    for (const o of ennemis) if (!o.mort && o.invoque && o.maitre === e) { o.pv = 0; tuer(o); }
  }
  sauver();
  setTimeout(() => { e.descendre = true; }, e.boss ? 6000 : 2600);
}

function blesserJoueur(d, source = null) {
  if (joueur.mort || joueur.invuln > 0) { if (joueur.invuln > 0) UI.nombre(V(joueur.pos.x, 2.4, joueur.pos.z), 'Esquive', 'info'); return; }
  d = d * (1 - joueur.st.reduction) * rnd(0.92, 1.08);
  if (source && source.combattant && joueur.st.pvp) d *= 1 - joueur.st.pvp / 200;
  if (joueur.bouclier > 0) { const a = Math.min(joueur.bouclier, d); joueur.bouclier -= a; d -= a; emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 6, c1: '#bfe6ff', c2: '#4a9aff', vit: 3, vie: 0.4, taille: 0.3 }); }
  if (d <= 0) return;
  if (source) dernierAgresseur = source;
  if (source && source.combattant) d = facteurJcJ(source, joueur, d);
  if (goulet) d = modBG(source, joueur, d);
  { const T = joueur.st.tal || {}; if (T.reduc) d *= 1 - Math.min(0.5, T.reduc); if (T.survie && joueur.pv < joueur.st.pvMax * 0.3) d *= 1 - T.survie; }
  if (lames.length) d = pareLame(d);
  joueur.pv -= d; joueur.frapper(); joueur.combatT = 4;
  UI.nombre(V(joueur.pos.x, 2.2, joueur.pos.z), Math.round(d), 'joueur');
  G.shake = Math.min(1, G.shake + d / joueur.st.pvMax * 3);
  son('impactMetal_medium_001', 0.35);
  if (joueur.pv <= 0) mourirJoueur();
}
let dernierAgresseur = null;
function mourirJoueur() {
  joueur.pv = 0; joueur.mort = true; joueur.jouer('Death_A', { boucle: false });
  if (goulet) return mortGoulet(joueur);
  if (modeActuel && modeActuel.mission) return echecMission();
  if (modeActuel && modeActuel.id === 'terres' && terres) return mortTerres();
  // le « joueur » qui t'a tué te nargue
  const k = dernierAgresseur;
  if (k && k.combattant && !k.mort && k.camp === 'ennemi') { emoteBot(k, ['ez', 'mdr', 'clown', 'rip', 'toi', 'bof'], 1, 0.7); emoteBot(k, ['mdr', 'clown', 'diable'], 0.4, 3.2); }
  for (const a of allies.filter(x => x.invoc)) dissiper(a);
  if (assaut && !assaut.fini) { // les bandits pillent 70 % du coffre
    assaut.fini = true; const ile = assaut.ile; const pertes = [];
    for (const k in ile.coffre) { const p = Math.floor(ile.coffre[k] * 0.7); if (p) { ile.coffre[k] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[k]}`); } }
    sauver(); son('lowFrequency_explosion_000', 0.7, 0.5);
    setTimeout(() => UI.mort(`Les bandits ont vidé ton coffre : ${pertes.join(', ') || 'il était vide'}. Recrute des gardes chez Oswin pour la prochaine fois.`, () => fondu(() => lancerHub())), 1600);
    return;
  }
  if (arene) { son('lowFrequency_explosion_000', 0.6, 0.6); if (allies.some(a => !a.mort)) UI.toast('Ton coéquipier continue le combat…'); verifierArene(); return; }
  if (invasion && rivauxVivants().length) { invasion.rival = rivauxVivants()[0]; return defaiteRival(); }
  if (modeActuel && modeActuel.sylve) return mortSylve();
  if (MODES.includes(modeActuel)) changerRang('donjon', -PERTE_RANG, 'Mort dans la Brèche');
  son('lowFrequency_explosion_000', 0.7, 0.5);
  const perte = Math.round(J.argent * 0.05); J.argent -= perte; sauver();
  setTimeout(() => UI.mort(`Tu perds ${perte.toLocaleString('fr-FR')} pièces d’argent. Ton équipement reste sur toi.`, () => fondu(() => lancerHub())), 1600);
}

// ---------------- Attaque de base ----------------
function attaquer(dt) {
  if (joueur.verrouT > 0 || joueur.mort || joueur.spinT > 0 || joueur.tornadeT > 0) return;
  const def = joueur.def, st = joueur.st, mains = joueur.rangee && !def.projectile, portee = mains ? 9 : st.portee;
  const c = choisirCible(portee);
  if (!c) return;
  joueur.cible = c;
  const d = dist2D(c.pos, joueur.pos) - c.rayon;
  const dir = V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize();
  const ang = Math.atan2(dir.x, dir.z);
  if (d > portee) {
    if (Math.abs(entree.jx) + Math.abs(entree.jy) < 0.1) { // s'approche tout seul
      deplacer(joueur, dir.x * st.vitesse * dt, dir.z * st.vitesse * dt);
      joueur.angle = tourner(joueur.angle, ang, dt * 12); joueur.root.rotation.y = joueur.angle; joueur.jouer(def.run);
    }
    return;
  }
  if (joueur.atkT > 0) { joueur.angle = tourner(joueur.angle, ang, dt * 14); joueur.root.rotation.y = joueur.angle; return; }
  faireFace(dir);
  joueur.atkT = 1 / st.vitesseAtk / (joueur.orageT > 0 ? 1.7 : 1) / (joueur.frenesieT > 0 ? 1.3 : 1); joueur.debutAtk = G.t;
  if (mains) { // armes rangées : on frappe à mains nues… avec de la magie pure
    joueur.atkT *= 1.15;
    joueur.jouer(Math.random() < 0.5 ? 'Spellcast_Shoot' : 'Spellcast_Raise', { boucle: false, vitesse: 1.7, forcer: true, fondu: 0.08, fin: () => joueur.jouer(joueur.rangee ? 'Idle' : def.idle) });
    joueur.verrouT = 0.22;
    programmer(0.2, () => { if (c.mort) return; tirerProjectile('feu', '#c08aff', c, 24, 0.8); son('forceField_000', 0.15, 1.9); });
    return;
  }
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  const vit = Math.max(1, st.vitesseAtk * joueur.duree(anim) * 0.95);
  joueur.jouer(anim, { boucle: false, vitesse: vit, forcer: true, fondu: 0.08, fin: () => joueur.jouer(def.idle) });
  joueur.verrouT = 0.28; joueur.verrouAtk = true; // l'attaque de base ralentit fortement le joueur (sans le figer net : plus de saccades)
  const couleur = TIERS[J.equip.arme.tier].color;
  if (def.assassin) { attaqueAssassin(c, vit); return; }
  if (!def.projectile) {
    programmer((def.ombre ? 0.22 : 0.3) / vit * 1.4, () => {
      if (c.mort) return;
      arcTaille(joueur.pos, joueur.angle - Math.PI / 2, def.ombre ? 2.6 : 2.9, def.ombre ? '#9a5aff' : couleur, Math.PI * 0.7, 0.22);
      if (def.ombre) emettre(V(c.pos.x, 1.1, c.pos.z), { n: 6, c1: '#c9a0ff', c2: '#1a0630', vit: 3, vie: 0.4, taille: 0.3 });
      if (dist2D(c.pos, joueur.pos) - c.rayon < st.portee + 1) { blesser(c, 1); son(Math.random() < 0.5 ? 'knifeSlice' : 'knifeSlice2', 0.45); if (def.orage) chaineEclair(c, 3, 0.55); }
    });
  } else {
    const mult = joueur.bonusTir ? 2 : 1; joueur.bonusTir = false;
    programmer(0.22, () => {
      if (joueur.armeType === 'arbalete') { tirerProjectile('carreau', couleur, c, 32, mult); son('drawKnife2', 0.35, 1.3); }
      else if (joueur.armeType === 'arc') { tirerProjectile('carreau', '#ff4a3a', c, 38, mult, { trainee: '#ff3a2a' }); son('drawKnife2', 0.35, 1.6); }
      else if (joueur.armeType === 'esprit') { tirerProjectile('feu', '#c08aff', c, 24, mult); son('forceField_000', 0.15, 1.8); if (!c.boss) { const v = V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize(); programmer(0.3, () => { if (!c.mort) c.pousse = { vx: v.x * 5, vz: v.z * 5, t: 0.2 }; }); } }
      else { tirerProjectile('feu', '#ff8a2a', c, 20, mult); son('thrusterFire_000', 0.18, 1.6); }
    });
  }
}
function pointArme() {
  const n = joueur.nodes[joueur.def.node]; const p = V();
  if (n) n.getWorldPosition(p); else p.copy(joueur.pos).setY(1.3);
  if (p.y < 0.8) p.y = 1.3;
  return p;
}
function tirerProjectile(type, couleur, cible, vitesse, mult, opts = {}) {
  const depart = pointArme();
  const dest = cible ? V(cible.pos.x, (cible.hover || 0) + 1.1 * (cible.boss ? Math.min(2, cible.boss.scale) * 0.8 : 1) + solY(cible.pos.x, cible.pos.z), cible.pos.z) : depart.clone().addScaledVector(V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle)), 14);
  const dir = dest.clone().sub(depart).normalize();
  const mesh = type === 'carreau' ? meshCarreau(couleur) : meshBoule(couleur, opts.taille || 0.4);
  mesh.position.copy(depart); mesh.lookAt(dest); G.scene.add(mesh);
  projectiles.push({ mesh, pos: mesh.position, vel: dir.multiplyScalar(vitesse), vie: (opts.portee || 18) / vitesse, camp: 'joueur', type, mult, couleur, perce: opts.perce, touches: new Set(), largeur: opts.largeur || 0.7, onHit: opts.onHit, cible });
}

// ---------------- Sorts ----------------
function lancerSort(k) {
  const s = joueur && joueur.sorts[k];
  if (!s || joueur.mort) return;
  if (arene && arene.t > 0) { UI.toast('Attends la fin du décompte'); return; }
  if ((joueur.cds[k] || 0) > 0) { son('error_001', 0.25); return; }
  if (joueur.energie < s.energie) { UI.toast('Pas assez d’énergie'); son('error_001', 0.25); return; }
  joueur.sortAttente = null;
  if (joueur.verrouAtk) { joueur.verrouT = 0; joueur.verrouAtk = false; } // un sort peut couper la petite pause de l'attaque de base
  if (joueur.verrouT > 0.15 && !['rempart', 'souffle', 'ruee', 'purge', 'vampirisme', 'orage'].includes(s.id)) { joueur.sortAttente = { k, t: 0.7, force: viseeForcee }; return; }
  joueur.energie -= s.energie; joueur.cds[k] = joueur.cdMax[k] || s.cd; joueur.combatT = 4; joueur.debutAtk = G.t; joueur.animT = 0.5; // laisse l'animation du sort se jouer même en courant
  if (s.relique) { pouvoirRelique(s); return; }
  const def = joueur.def;
  const fin = () => joueur.jouer(def.idle);
  switch (s.id) {
    case 'emprise': lancerEmprise(s); break;
    case 'lames': ordreLames(); break;
    case 'onde': ondeForce(s); break;
    case 'possession': lancerPossession(s); break;
    case 'demon': basculerDemon(); break;
    case 'transfert': transfert(); break;
    case 'gacha': if (!pacteInvocation()) joueur.cds.W = 0.5; break;
    case 'fente': {
      const { dir } = directionVisee(5); faireFace(dir);
      joueur.jouer('2H_Melee_Attack_Slice', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.42;
      programmer(0.2, () => {
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, s.portee, '#ff3a2a', Math.PI * 0.8, 0.32);
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, s.portee * 0.8, '#ffd0a0', Math.PI * 0.6, 0.25);
        const n = zoneDegats(joueur.pos, s.portee, s.mult, { cone: Math.PI * 0.8, dir, c1: '#ff4a3a', c2: '#7a0a0a', dot: { dps: joueur.st.degats * 0.18, t: 3, c: '#ff3a2a' } });
        son('knifeSlice', 0.55, 0.85); if (n) G.shake = 0.35;
      });
      break;
    }
    case 'charge': {
      const { dir, cible, point } = directionVisee(s.portee); faireFace(dir);
      const dmax = cible ? Math.max(0, Math.min(s.portee, dist2D(point, joueur.pos) - cible.rayon - 0.8)) : 7;
      joueur.jouer('Dodge_Forward', { boucle: false, vitesse: 1.6, forcer: true });
      joueur.dashT = 0.26; joueur.dashV = dir.clone().multiplyScalar(dmax / 0.26); joueur.verrouT = 0.55;
      son('cloth1', 0.6, 0.8);
      programmer(0.27, () => {
        joueur.jouer('2H_Melee_Attack_Chop', { boucle: false, vitesse: 1.7, forcer: true, fin });
        onde(joueur.pos, '#ffd36b', 4, 0.45); lueurSol(joueur.pos, '#ffb84a', 3.2, 0.5, 0.8);
        emettre(V(joueur.pos.x, 0.3, joueur.pos.z), { n: 30, c1: '#d8c8a8', c2: '#7a6a5a', vit: 6, vie: 0.6, taille: 0.5, hemi: true, grav: 4 });
        zoneDegats(joueur.pos, 3.2, s.mult, { stun: 1.2, c1: '#ffd36b' }); son('impactPlate_heavy_000', 0.6, 0.8); G.shake = 0.5;
      });
      break;
    }
    case 'tempete': {
      joueur.spinT = 2.4; joueur.spinTick = 0;
      joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.25, forcer: true });
      const anneaux = new THREE.Group();
      for (let i = 0; i < 3; i++) { const m = new THREE.Mesh(new THREE.RingGeometry(1.6 + i * 1.1, 2.2 + i * 1.1, 48, 1, 0, Math.PI * 1.2), new THREE.MeshBasicMaterial({ color: i === 1 ? '#ffffff' : '#9ab8ff', transparent: true, opacity: 0.55 - i * 0.12, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); m.rotation.x = -Math.PI / 2; m.position.y = 0.9 + i * 0.1; m.userData.v = 9 - i * 2; anneaux.add(m); }
      ajouterVfx(anneaux, (t, dt) => { anneaux.position.copy(joueur.pos); anneaux.children.forEach(m => (m.rotation.z -= m.userData.v * dt)); if (joueur.spinT <= 0) return false; });
      break;
    }
    case 'perforant': {
      const { dir, cible } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Shoot', { boucle: false, vitesse: 1.4, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.2, () => { tirerProjectile('carreau', '#7dffb0', cible, 40, s.mult, { perce: true, portee: 17, largeur: 1.3 }); son('drawKnife2', 0.6, 0.8); });
      break;
    }
    case 'roulade': {
      const c = choisirCible(14);
      const arr = c ? V(joueur.pos.x - c.pos.x, 0, joueur.pos.z - c.pos.z).normalize() : V(-Math.sin(joueur.angle), 0, -Math.cos(joueur.angle));
      faireFace(arr.clone().negate());
      joueur.jouer('Dodge_Backward', { boucle: false, vitesse: 1.5, forcer: true, fin });
      joueur.dashT = 0.35; joueur.dashV = arr.multiplyScalar(s.portee / 0.35); joueur.invuln = 0.45; joueur.verrouT = 0.4; joueur.bonusTir = true;
      emettre(V(joueur.pos.x, 0.3, joueur.pos.z), { n: 16, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.5, taille: 0.4 }); son('cloth1', 0.6, 1.2);
      break;
    }
    case 'tirArc': {
      const { dir, cible } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Aiming', { boucle: false, vitesse: 1.6, forcer: true }); joueur.verrouT = 0.6;
      const p0 = pointArme(); emettre(p0, { n: 26, c1: '#ffd0c0', c2: '#ff1a0a', vit: 2, vie: 0.5, taille: 0.35, rayon: 0.6 }); son('forceField_000', 0.4, 1.8);
      programmer(0.42, () => {
        joueur.jouer('2H_Ranged_Shoot', { boucle: false, vitesse: 1.4, forcer: true, fin });
        tirerProjectile('carreau', '#ff2a1a', cible, 58, s.mult, { perce: true, portee: 22, largeur: 1.7 });
        son('drawKnife2', 0.8, 0.6); son('lowFrequency_explosion_000', 0.3, 1.8); G.shake = 0.35;
        const p = pointArme(); for (let k = 0; k < 12; k++) emettre(p.clone().addScaledVector(dir, k * 1.6), { n: 2, c1: '#ffe0d0', c2: '#ff1a0a', vit: 0.5, vie: 0.45, taille: 0.35 });
      });
      break;
    }
    case 'meute': {
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.5;
      son('forceField_000', 0.5, 0.5); onde(joueur.pos, '#ff2a1a', 6, 0.7);
      programmer(0.35, () => { let n = 0; for (let i = 0; i < 3; i++) if (!meute[i] || meute[i].mort || !allies.includes(meute[i])) { creerLoup(i, pointLibrePres(joueur.pos, 1.5, 3.2)); n++; } joueur.comboMeute = 1; majSortMeute(); if (n) UI.toast(n === 3 ? 'La meute répond à ton appel !' : `${n} loup${n > 1 ? 's' : ''} rappelé${n > 1 ? 's' : ''}`); });
      break;
    }
    case 'entrave': case 'rugissement': case 'bondMeurtrier': {
      const loups = meuteVivante();
      const c = choisirCible(s.portee);
      if (!c || !loups.length) { joueur.energie += s.energie; joueur.cds[k] = 0; UI.toast(loups.length ? 'Aucune cible pour la meute' : 'Tes loups sont tombés'); return; }
      joueur.jouer('Spellcast_Shoot', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.25;
      if (s.id === 'entrave') {
        loups.forEach((l, i) => programmer(i * 0.08, () => bondLoup(l, c, s.mult / 2, { stun: 0.3 })));
        programmer(0.5, () => { if (c.mort) return; c.racineT = Math.max(c.racineT || 0, 2.6); UI.nombre(V(c.pos.x, (c.hauteurPlaque || 2.4) + 0.3, c.pos.z), 'Entravé', 'crit');
          const anneau = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.25, 32), new THREE.MeshBasicMaterial({ color: '#ff3a1a', transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
          anneau.rotation.x = -Math.PI / 2; ajouterVfx(anneau, (t) => { anneau.position.set(c.pos.x, 0.08, c.pos.z); anneau.material.opacity = 0.9 * Math.min(1, (2.6 - t) * 2); anneau.rotation.z = t * 3; if (t > 2.6 || c.mort) return false; });
          for (let q = 0; q < 4; q++) emettre(V(c.pos.x, 0.3, c.pos.z), { n: 8, c1: '#ffb08a', c2: '#ff1a0a', vit: 2.5, vie: 0.6, taille: 0.3, hemi: true });
          son('impactPlate_heavy_000', 0.5, 0.7); });
        joueur.comboMeute = 2;
      } else if (s.id === 'rugissement') {
        for (const l of loups) { l.actionT = 0.9; l.jouer('hurle', { forcer: true }); }
        son('lowFrequency_explosion_000', 0.7, 0.55);
        programmer(0.45, () => {
          G.shake = 0.9; ralenti(0.18, 0.35);
          for (const l of meuteVivante()) { onde(l.pos, '#ff3a1a', 7.5, 0.7); onde(l.pos, '#ffd0a0', 5, 0.45); emettre(V(l.pos.x, 0.4, l.pos.z), { n: 40, c1: '#ffd0b0', c2: '#ff1a0a', vit: 9, vie: 0.6, taille: 0.5, hemi: true, rayon: 1 }); lueurSol(l.pos, '#ff2a0a', 6.5, 0.6, 0.9); }
          for (const e of vivants()) { const l = meuteVivante().find(w => dist2D(w.pos, e.pos) < 6.8 + e.rayon); if (!l) continue; auteurCoup = l; blesser(e, s.mult, { stun: 0.6, c1: '#ff4a2a' }); auteurCoup = null; }
          son('explosionCrunch_000', 0.7, 0.6);
        });
        joueur.comboMeute = 3;
      } else {
        const proies = vivants().filter(e => dist2D(e.pos, joueur.pos) < s.portee).sort((a, b) => dist2D(a.pos, joueur.pos) - dist2D(b.pos, joueur.pos));
        loups.forEach((l, i) => { const e = proies[i] || proies[0]; if (e) programmer(i * 0.12, () => bondLoup(l, e, s.mult, { teleport: true, dot: { dps: joueur.st.degats * 0.35, t: 4, c: '#ff2a1a' } })); });
        joueur.comboMeute = 1; son('forceField_000', 0.5, 1.4);
      }
      joueur.comboT = 9; majSortMeute();
      if (s.id === 'bondMeurtrier') joueur.cds[k] = joueur.cdMax[k] = +(SORTS.bondMeurtrier.cd * (1 - joueur.st.recharge / 100) * (1 - ((joueur.st.tal || {}).cd_meute || 0))).toFixed(2);
      break;
    }
    case 'frenesie': {
      const duree = 8 * (1 + ((joueur.st.tal || {}).s_frenesie || 0));
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.4, forcer: true, fin }); joueur.verrouT = 0.3;
      joueur.frenesieT = duree; for (const l of meuteVivante()) { l.frenesieT = duree; l.jouer('hurle', { forcer: true }); l.actionT = 0.7; emettre(V(l.pos.x, 1, l.pos.z), { n: 24, c1: '#ffd0b0', c2: '#ff1a0a', vit: 4, vie: 0.6, taille: 0.4 }); }
      onde(joueur.pos, '#ff6a3a', 4, 0.5); son('lowFrequency_explosion_000', 0.45, 0.9); UI.toast(`Frénésie sauvage : ${Math.round(duree)} s`);
      break;
    }
    case 'tirMultiple': {
      const { dir } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Shoot', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.3;
      programmer(0.18, () => { const a0 = joueur.angle; for (let i = -3; i <= 3; i++) { joueur.angle = a0 + i * 0.13; tirerProjectile('carreau', s.couleur[0], null, 36, s.mult, { portee: s.portee }); } joueur.angle = a0; son('drawKnife2', 0.6, 1.1); });
      break;
    }
    case 'novaGivre': {
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.6, forcer: true, fin }); joueur.verrouT = 0.3;
      programmer(0.2, () => {
        onde(joueur.pos, '#bfe8ff', s.portee + 1, 0.6); lueurSol(joueur.pos, '#7ab8ff', s.portee, 0.7, 0.9);
        emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 60, c1: '#ffffff', c2: '#5ab0ff', vit: 10, vie: 0.6, taille: 0.45, hemi: true });
        for (const e of vivants()) if (dist2D(e.pos, joueur.pos) < s.portee + e.rayon) { blesser(e, s.mult, { slow: 3, c1: '#bfe8ff' }); e.racineT = Math.max(e.racineT || 0, 2); }
        son('impactMining_000', 0.6, 0.8); G.shake = 0.3;
      });
      break;
    }
    case 'pluie': case 'pluieEcarlate': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin }); joueur.verrouT = 0.3;
      const centre = point.clone();
      const cercle = new THREE.Mesh(new THREE.RingGeometry(4.3, 4.5, 48), new THREE.MeshBasicMaterial({ color: s.couleur[0], transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
      cercle.rotation.x = -Math.PI / 2; cercle.position.set(centre.x, 0.1, centre.z);
      ajouterVfx(cercle, (t) => { cercle.material.opacity = 0.8 * (1 - t / 2.4); if (t > 2.4) return false; });
      for (let w = 0; w < 5; w++) programmer(0.3 + w * 0.4, () => {
        for (let i = 0; i < 9; i++) { const a = Math.random() * 6.28, r = Math.sqrt(Math.random()) * 4.2; emettre(V(centre.x + Math.cos(a) * r, 7, centre.z + Math.sin(a) * r), { n: 1, c1: '#ffffff', c2: s.couleur[0], dir: V(0, -1, 0), vit: 22, disp: 0, vie: 0.3, taille: 0.35, frein: 0 }); }
        programmer(0.3, () => { zoneDegats(centre, 4.4, s.mult, { slow: 2, c1: s.couleur[0], silence: true }); emettre(V(centre.x, 0.2, centre.z), { n: 14, c1: '#bfffd8', c2: '#3a9a6a', rayon: 3.8, vit: 2, vie: 0.4, taille: 0.3, hemi: true }); son('impactGeneric_light_000', 0.3, 1.3); });
      });
      break;
    }
    case 'bouleFeu': {
      const { dir, cible } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Shoot', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.32;
      programmer(0.22, () => {
        son('thrusterFire_000', 0.5, 0.9);
        tirerProjectile('feu', '#ff7a1a', cible, 21, 0, { taille: 0.7, portee: 15, onHit: (p) => {
          onde(p, '#ff8a2a', 3, 0.4); lueurSol(p, '#ff5a1a', 2.6, 0.5);
          emettre(p, { n: 40, c1: '#ffe08a', c2: '#ff3a00', vit: 7, vie: 0.6, taille: 0.6, grav: -1 });
          zoneDegats(p, 2.6, s.mult, { dot: { dps: joueur.st.degats * 0.22, t: 3, c: '#ff7a1a' }, c1: '#ffb84a', c2: '#ff3a00' });
          son('explosionCrunch_000', 0.45); G.shake = 0.3;
        } });
      });
      break;
    }
    case 'colonne': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.5;
      const c = point.clone();
      telegraphe(c, 3.5, 0.8, '#ff8a2a', () => {
        const pil = new THREE.Group();
        for (let i = 0; i < 2; i++) { const m = new THREE.Mesh(new THREE.CylinderGeometry(i ? 1.2 : 2.2, i ? 1.6 : 3.2, 9, 24, 1, true), new THREE.MeshBasicMaterial({ color: i ? '#ffe0a0' : '#ff4a10', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, map: texRond() })); m.position.y = 4.5; pil.add(m); }
        pil.position.copy(c);
        ajouterVfx(pil, (t) => { const k = t / 0.7; if (k >= 1) return false; pil.scale.set(1 - k * 0.5, 0.3 + k, 1 - k * 0.5); pil.children.forEach(m => (m.material.opacity = 0.8 * (1 - k))); });
        emettre(V(c.x, 0.3, c.z), { n: 60, c1: '#ffe08a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 14, disp: 2.5, rayon: 1.8, vie: 0.8, taille: 0.7, frein: 2 });
        zoneDegats(c, 3.5, s.mult, { stun: 0.8, air: true, dot: { dps: joueur.st.degats * 0.15, t: 2, c: '#ff7a1a' }, c1: '#ffb84a', c2: '#ff3a00' });
        son('explosionCrunch_000', 0.6, 0.8); G.shake = 0.5;
      });
      break;
    }
    case 'meteore': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Long', { boucle: false, vitesse: 1.2, forcer: true, fin }); joueur.verrouT = 1.1;
      const c = point.clone();
      telegraphe(c, 6, 1.5, '#ffb030', () => {
        G.shake = 1.1; son('lowFrequency_explosion_000', 0.8); son('explosionCrunch_000', 0.6, 0.6);
        onde(c, '#ffd27a', 9, 0.7); onde(c, '#ff5a1a', 7, 0.9);
        emettre(V(c.x, 0.5, c.z), { n: 160, c1: '#fff0b0', c2: '#ff2a00', vit: 14, vie: 1.0, taille: 0.9, grav: 4, hemi: true });
        zoneDegats(c, 6, s.mult, { stun: 0.6, c1: '#ffe08a', c2: '#ff3a00' });
        const brule = lueurSol(c, '#ff4a10', 5.5, 3, 0.9);
        let tick = 0; ajouterVfx(new THREE.Group(), (t, dt) => { tick += dt; if (tick > 0.5) { tick = 0; zoneDegats(c, 5.5, 0.3, { silence: true }); } if (Math.random() < 0.6) emettre(V(c.x + rnd(-5, 5), 0.2, c.z + rnd(-5, 5)), { n: 1, c1: '#ffb84a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 2.5, disp: 0.3, vie: 0.7, taille: 0.5 }); if (t > 3) return false; });
      });
      // le météore tombe
      const m = meshBoule('#ff6a1a', 1.6); m.position.set(c.x + 9, 22, c.z - 9); G.scene.add(m);
      ajouterVfx(m, (t) => { const k = Math.min(1, (t - 0.3) / 1.2); if (t < 0.3) return; m.position.set(c.x + 9 * (1 - k), 22 * (1 - k) + 0.5, c.z - 9 * (1 - k)); emettre(m.position, { n: 4, c1: '#ffe08a', c2: '#ff3a00', vit: 1, vie: 0.6, taille: 1.0, rayon: 0.8 }); if (k >= 1) return false; });
      break;
    }
    case 'rempart': {
      joueur.bouclier = joueur.st.pvMax * 0.25; joueur.bouclierT = 4;
      bulle(joueur, () => joueur.bouclier <= 0 || joueur.bouclierT <= 0);
      onde(joueur.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.5, 1.4);
      break;
    }
    case 'execution': {
      const portee = Math.max(s.portee, joueur.st.portee);
      const { dir, cible } = directionVisee(portee); faireFace(dir);
      const anim = joueur.armeType === 'ombre' ? '1H_Melee_Attack_Chop' : joueur.armeType === 'epee' ? '2H_Melee_Attack_Chop' : (joueur.armeType === 'arbalete' || joueur.armeType === 'arc') ? '2H_Ranged_Shoot' : 'Spellcast_Shoot';
      joueur.jouer(anim, { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.4;
      const bas = cible && cible.pv / cible.pvMax < 0.35; const mult = s.mult * (bas ? 3 : 1);
      programmer(0.25, () => {
        if (!cible || cible.mort) return;
        if (!joueur.def.projectile) { if (dist2D(cible.pos, joueur.pos) - cible.rayon < portee + 1) { arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3.6, '#ff2a3a', Math.PI * 0.5, 0.35); blesser(cible, mult, { c1: '#ff3a4a', c2: '#5a0008' }); son('impactPlate_heavy_000', 0.6, 0.7); } }
        else tirerProjectile(joueur.armeType === 'arbalete' || joueur.armeType === 'arc' ? 'carreau' : 'feu', '#ff2a3a', cible, 34, mult, { taille: 0.6 });
        if (bas) { G.shake = 0.5; UI.nombre(V(cible.pos.x, 3, cible.pos.z), 'EXÉCUTION', 'crit'); }
      });
      break;
    }
    case 'legion': {
      if (!modeActuel) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast('Tes ombres ne répondent qu’au combat'); break; }
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.45;
      programmer(0.3, () => invoquerOmbres(Math.min(8, J.equip.arme.tier + ((J.equip.arme.ench || 0) >= 4 ? 1 : 0))));
      break;
    }
    case 'reflet': {
      const { dir, cible } = directionVisee(s.portee);
      if (!modeActuel || !cible) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast(!modeActuel ? 'Tes ombres ne répondent qu’au combat' : 'Aucune cible à refléter'); break; }
      faireFace(dir); joueur.jouer('Spellcast_Shoot', { boucle: false, vitesse: 1.2, forcer: true, fin }); joueur.verrouT = 0.4;
      programmer(0.25, () => { if (!cible.mort) invoquerReflet(cible); });
      break;
    }
    case 'pasOmbre': {
      const { cible } = directionVisee(s.portee);
      if (!cible) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast('Aucune cible'); break; }
      const ang = Math.atan2(cible.pos.x - joueur.pos.x, cible.pos.z - joueur.pos.z);
      const dos = V(cible.pos.x + Math.sin(ang) * (cible.rayon + 1.0), 0, cible.pos.z + Math.cos(ang) * (cible.rayon + 1.0));
      fumeeOmbre(joueur.pos); son('cloth1', 0.6, 0.6);
      const p = monde.marche && !monde.marche(dos.x, dos.z) ? cible.pos.clone().add(V(-Math.sin(ang), 0, -Math.cos(ang))) : dos;
      joueur.pos.set(p.x, 0, p.z); joueur.invuln = Math.max(joueur.invuln, 0.35);
      faireFace(V(cible.pos.x - joueur.pos.x, 0, cible.pos.z - joueur.pos.z).normalize()); fumeeOmbre(joueur.pos);
      for (const a of allies) if (a.invoc === 'ombre' && !a.mort) { a.pos.copy(pointLibrePres(cible.pos, cible.rayon + 1, cible.rayon + 2.4)); fumeeOmbre(a.pos); a.tc = cible; }
      joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, vitesse: 1.7, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.15, () => {
        if (cible.mort) return;
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3, '#b07aff', Math.PI * 0.8, 0.3); arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, '#ffffff', Math.PI * 0.5, 0.2);
        blesser(cible, s.mult, { stun: 0.8, c1: '#c9a0ff', c2: '#2a0a4a' }); son('knifeSlice2', 0.6, 0.7); G.shake = 0.35;
      });
      break;
    }
    case 'tornade': {
      joueur.spinT = 0; joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.5, forcer: true });
      joueur.tornadeT = 4; let tick = 0;
      const g = new THREE.Group();
      for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(new THREE.RingGeometry(1.2 + i * 1.3, 1.6 + i * 1.3, 40, 1, 0, Math.PI * 1.3), new THREE.MeshBasicMaterial({ color: i % 2 ? '#ffffff' : '#7ac8ff', transparent: true, opacity: 0.5 - i * 0.08, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); m.rotation.x = -Math.PI / 2; m.position.y = 0.4 + i * 0.5; m.userData.v = 10 - i * 1.5; g.add(m); }
      son('thrusterFire_000', 0.5, 0.6);
      const jT = joueur;
      ajouterVfx(g, (t, dt) => {
        if (joueur !== jT || !(joueur.tornadeT > 0)) { if (joueur === jT) joueur.jouer(def.idle); return false; }
        g.position.copy(joueur.pos); g.children.forEach(m => (m.rotation.z -= m.userData.v * dt));
        if (joueur.courante && joueur.courante.getClip().name !== '2H_Melee_Attack_Spinning') joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.5 });
        joueur.tornadeT -= dt; if (joueur.mort) joueur.tornadeT = 0;
        if (Math.random() < 0.7) { const a = Math.random() * 6.28, rr = 1 + Math.random() * 5; emettre(V(joueur.pos.x + Math.cos(a) * rr, 0.3, joueur.pos.z + Math.sin(a) * rr), { n: 1, c1: '#e0f4ff', c2: '#3a7aff', dir: V(-Math.sin(a), 1.2, Math.cos(a)), vit: 6, vie: 0.5, taille: 0.35 }); }
        for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos); if (d < 7 && d > 1.6 && !e.boss) { const k = Math.min(1, dt * 6); deplacer(e, (joueur.pos.x - e.pos.x) * k * 0.6, (joueur.pos.z - e.pos.z) * k * 0.6, 0.4); } }
        tick -= dt; if (tick <= 0) { tick = 0.3; zoneDegats(joueur.pos, 3.8, s.mult, { silence: true, c1: '#bfe8ff' }); son('knifeSlice2', 0.25, 1.4); }
        if (joueur.tornadeT <= 0) { joueur.jouer(def.idle); return false; }
      });
      break;
    }
    case 'titan': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      const dep = joueur.pos.clone(), arr = pointLibreProche(V(point.x, 0, point.z), 0.6) || dep.clone();
      joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, vitesse: 0.9, forcer: true, fin }); joueur.verrouT = 0.7; joueur.invuln = Math.max(joueur.invuln, 0.7);
      son('cloth1', 0.6, 0.6);
      ajouterVfx(new THREE.Group(), (t) => {
        const k = Math.min(1, t / 0.55);
        joueur.pos.x = dep.x + (arr.x - dep.x) * k; joueur.pos.z = dep.z + (arr.z - dep.z) * k; joueur.root.position.y = Math.sin(k * Math.PI) * 4;
        if (k >= 1) {
          joueur.root.position.y = 0; G.shake = 1;
          const avant = vivants().length;
          onde(arr, '#ffe27a', 7, 0.6); onde(arr, '#ffffff', 4, 0.4); lueurSol(arr, '#ffd27a', 5, 0.8, 1.2);
          emettre(V(arr.x, 0.3, arr.z), { n: 90, c1: '#fff2c0', c2: '#8a6a2a', vit: 11, vie: 0.8, taille: 0.6, hemi: true, grav: 6 });
          zoneDegats(arr, 5.5, s.mult, { stun: 1.0, air: true, c1: '#ffe27a' }); son('impactPlate_heavy_000', 0.8, 0.5); son('lowFrequency_explosion_000', 0.5, 1.3);
          const tues = avant - vivants().length;
          if (tues >= 3) { joueur.cds[k2] = 0; UI.nombre(V(joueur.pos.x, 3, joueur.pos.z), 'RECHARGÉ !', 'crit'); son('confirmation_001', 0.6, 1.4); }
          return false;
        }
      });
      const k2 = k;
      break;
    }
    case 'orage': {
      joueur.orageT = 10; joueur.vampT = Math.max(joueur.vampT, 10);
      son('forceField_000', 0.7, 1.8); son('lowFrequency_explosion_000', 0.5, 1.6); G.shake = 0.5;
      onde(joueur.pos, '#9ab8ff', 6, 0.7); emettre(V(joueur.pos.x, 1.5, joueur.pos.z), { n: 80, c1: '#ffffff', c2: '#3a5aff', vit: 8, vie: 0.8, taille: 0.45 });
      let frappe = 0; const jO = joueur;
      ajouterVfx(new THREE.Group(), (t, dt) => {
        if (joueur !== jO || !(joueur.orageT > 0)) return false;
        joueur.orageT -= dt; if (joueur.mort) joueur.orageT = 0;
        if (Math.random() < 0.5) emettre(V(joueur.pos.x + rnd(-0.6, 0.6), 0.5 + Math.random() * 1.6, joueur.pos.z + rnd(-0.6, 0.6)), { n: 1, c1: '#ffffff', c2: '#5a8aff', vit: 2, vie: 0.3, taille: 0.25 });
        frappe -= dt;
        if (frappe <= 0) { frappe = 0.4; const l = vivants().filter(e => dist2D(e.pos, joueur.pos) < s.portee); if (l.length) eclairCiel(hasard(l), s.mult); }
        if (joueur.orageT <= 0) return false;
      });
      UI.toast('COLÈRE DE L’ORAGE', true);
      break;
    }
    case 'triple': {
      const { dir, cible } = directionVisee(s.portee);
      if (!cible) { joueur.energie += s.energie; UI.toast('Aucune cible'); break; }
      faireFace(dir);
      const d = dist2D(cible.pos, joueur.pos) - cible.rayon;
      if (d > 1.6) { const p = cible.pos.clone().addScaledVector(V(joueur.pos.x - cible.pos.x, 0, joueur.pos.z - cible.pos.z).normalize(), cible.rayon + 1.1); traineeRouge(joueur.pos, p); const q = pointLibreProche(p, 0.5); if (q) joueur.pos.set(q.x, 0, q.z); }
      joueur.verrouT = 0.42;
      const anims = ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop', '2H_Melee_Attack_Stab'];
      for (let i = 0; i < 3; i++) programmer(0.02 + i * 0.13, () => {
        if (cible.mort) return; faireFace(V(cible.pos.x - joueur.pos.x, 0, cible.pos.z - joueur.pos.z).normalize());
        joueur.jouer(anims[i], { boucle: false, vitesse: 2.6, forcer: true, fondu: 0.04, fin });
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, i === 2 ? '#ff2a3a' : '#ffb0b0', Math.PI * 0.6, 0.18);
        blesser(cible, s.mult * furtifBonus(), { c1: '#ff4a5a', c2: '#3a0008' }); gagnerCombo(1); son(i === 2 ? 'knifeSlice2' : 'knifeSlice', 0.4, 1.2 + i * 0.1);
      });
      break;
    }
    case 'curee': {
      const pts = joueur.combo || 0;
      const { dir, cible } = directionVisee(s.portee);
      if (!cible || !pts) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast(!pts ? 'Pas de points de combo' : 'Aucune cible'); son('error_001', 0.3); break; }
      faireFace(dir); teleportDerriere(cible);
      joueur.jouer('2H_Melee_Attack_Stab', { boucle: false, vitesse: 1.8, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.12, () => {
        if (cible.mort) return;
        const mult = (s.mult + 0.65 * pts) * furtifBonus();
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3.2, '#ff1a2a', Math.PI * 0.9, 0.35); arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.5, '#ffffff', Math.PI * 0.5, 0.25);
        blesser(cible, mult, { c1: '#ff2a3a', c2: '#2a0004' }); emettre(V(cible.pos.x, 1.2, cible.pos.z), { n: 20 + pts * 12, c1: '#ff6a6a', c2: '#5a0008', vit: 7, vie: 0.7, taille: 0.45, grav: 6 });
        UI.nombre(V(cible.pos.x, 3, cible.pos.z), pts >= 5 ? 'CURÉE ×5 !' : `Curée ×${pts}`, 'crit'); son('impactPlate_heavy_000', 0.6, 0.9); G.shake = 0.25 + pts * 0.1;
        joueur.combo = 0; if (pts >= 5) furtif(1);
      });
      break;
    }
    case 'zephyr': {
      if (joueur.zephyrT > 0 && joueur.zephyrCharges > 0) { joueur.zephyrCharges--; joueur.energie += s.energie; joueur.cds[k] = joueur.zephyrCharges > 0 ? 0.25 : joueur.cdMax[k]; }
      else { joueur.zephyrCharges = 2; joueur.zephyrT = 5; joueur.cds[k] = 0.25; joueur.sprintT = Math.max(joueur.sprintT, 3); programmer(5, () => { if (joueur.zephyrCharges > 0) { joueur.zephyrCharges = 0; joueur.cds[k] = joueur.cdMax[k]; } joueur.zephyrT = 0; }); }
      const mv = Math.hypot(entree.jx, entree.jy) > 0.2 ? DIR_DROITE.clone().multiplyScalar(entree.jx).addScaledVector(DIR_HAUT, entree.jy).normalize() : directionVisee(s.portee).dir;
      faireFace(mv); const dep = joueur.pos.clone();
      joueur.jouer('Dodge_Forward', { boucle: false, vitesse: 2, forcer: true, fin }); joueur.dashT = 0.2; joueur.dashV = mv.clone().multiplyScalar(s.portee / 0.2); joueur.invuln = Math.max(joueur.invuln, 0.3);
      son('cloth1', 0.6, 1.4);
      programmer(0.21, () => {
        traineeRouge(dep, joueur.pos, '#7affc0');
        for (const e of vivants()) { if (distSegPt(dep, joueur.pos, e.pos) < 1.6 + e.rayon) { blesser(e, s.mult * furtifBonus(), { c1: '#bfffe0', c2: '#0a5a3a' }); gagnerCombo(1); } }
      });
      break;
    }
    case 'vampirisme': { joueur.vampT = 5; son('forceField_000', 0.4, 1.6); onde(joueur.pos, '#ff4a6a', 3, 0.5); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 30, c1: '#ff8aa0', c2: '#8a0020', vit: 3, vie: 0.7, taille: 0.4 }); break; }
    case 'purge': { joueur.slowT = 0; joueur.verrouT = 0; joueur.invuln = 1.2; son('forceField_000', 0.5, 1.2); onde(joueur.pos, '#e0c8ff', 3.5, 0.5); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 40, c1: '#ffffff', c2: '#a070ff', vit: 4, vie: 0.6, taille: 0.4 }); break; }
    case 'souffle': { joueur.soinT = 3; son('confirmation_001', 0.4); onde(joueur.pos, '#9dff8a', 2.5, 0.6); break; }
    case 'ruee': { joueur.sprintT = 3; joueur.slowT = 0; son('cloth1', 0.6, 1.4); emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 20, c1: '#fff8c0', c2: '#ffd04a', vit: 3, vie: 0.5, taille: 0.35 }); break; }
  }
}
// bulle de protection (joueur, rivaux, coéquipiers) : un seul matériau partagé
let matBulle = null;
function bulle(cible, fini) {
  matBulle = matBulle || new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: 'varying vec3 vN; varying vec3 vV; void main(){ vec4 mv=modelViewMatrix*vec4(position,1.0); vN=normalize(normalMatrix*normal); vV=normalize(-mv.xyz); gl_Position=projectionMatrix*mv; }',
    fragmentShader: 'varying vec3 vN; varying vec3 vV; void main(){ float f=pow(1.0-abs(dot(vN,vV)),2.5); gl_FragColor=vec4(vec3(0.45,0.8,1.0)*(f*1.6+0.06), f*0.9+0.05); }' });
  const m = new THREE.Mesh(new THREE.SphereGeometry(1.5, 24, 16), matBulle);
  ajouterVfx(m, () => { m.position.set(cible.pos.x, 1.1, cible.pos.z); if (cible.mort || fini()) return false; });
}
function rempartIA(e) {
  e.cdRempart = 18; e.bouclierIA = e.pvMax * 0.25; e.bouclierT = 4;
  if (e.camp === 'ennemi') emoteBot(e, ['malin', 'bof'], 0.2, 0.3);
  bulle(e, () => e.bouclierIA <= 0 || e.bouclierT <= 0);
  onde(e.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.45, 1.4);
  UI.nombre(V(e.pos.x, 2.8, e.pos.z), 'Rempart', 'info');
}
function boirePotion() {
  if ((joueur.cds.POT || 0) > 0 || joueur.potions <= 0 || joueur.mort) { son('error_001', 0.25); return; }
  joueur.potions--; J.potions = joueur.potions; joueur.cds.POT = 60; joueur.potionT = 1;
  son('metalLatch', 0.5, 1.4); emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 20, c1: '#ff8a9a', c2: '#ff2a4a', vit: 2, vie: 0.7, taille: 0.35, monte: 2 });
  sauver();
}

// ---------------- Mise à jour du joueur ----------------
G.auto = (() => { try { return localStorage.getItem('breche-auto') === '1'; } catch (e) { return false; } })();
function majJoueur(dt) {
  const j = joueur, st = j.st;
  for (const k in j.cds) j.cds[k] = Math.max(0, j.cds[k] - dt);
  j.atkT -= dt; j.verrouT -= dt; j.invuln -= dt; j.combatT -= dt;
  if (j.mort) { j.maj(dt); return; }
  if (demon) { majDemon(dt); return; }
  // régénération
  j.energie = Math.min(st.energieMax, j.energie + dt * (6 + st.energieMax * 0.012) * (1 + (st.tal && st.tal.enRegen || 0)));
  const regen = j.combatT > 0 ? st.regen * 0.25 : st.regen * 3;
  j.pv = Math.min(st.pvMax, j.pv + st.pvMax * regen / 100 * dt);
  if (j.soinT > 0) { j.soinT -= dt; const h = st.pvMax * 0.1 * dt; if (goulet) scoreDe(j).soin += Math.min(h, st.pvMax - j.pv); j.pv = Math.min(st.pvMax, j.pv + h); if (Math.random() < 0.5) emettre(V(j.pos.x, 0.4, j.pos.z), { n: 1, c1: '#bfffb0', c2: '#3aff4a', dir: V(0, 1, 0), vit: 2, rayon: 0.7, vie: 0.8, taille: 0.3 }); }
  if (j.potionT > 0) { j.potionT -= dt; const kP = 0.4 * (1 + (st.tal && st.tal.potion || 0)); if (goulet) scoreDe(j).soin += Math.min(st.pvMax * kP * dt, st.pvMax - j.pv); j.pv = Math.min(st.pvMax, j.pv + st.pvMax * kP * dt); }
  if (j.bouclierT > 0) { j.bouclierT -= dt; if (j.bouclierT <= 0) j.bouclier = 0; }
  if (j.sprintT > 0) { j.sprintT -= dt; if (Math.random() < 0.4) emettre(V(j.pos.x, 0.2, j.pos.z), { n: 1, c1: '#fff2b0', c2: '#ffcf4a', vit: 0.5, vie: 0.5, taille: 0.3 }); }
  if (j.slowT > 0) j.slowT -= dt;
  if (j.vampT > 0) j.vampT -= dt;
  // arme de haut tier : aura
  const tier = J.equip.arme?.tier || 1;
  if (tier >= 6 && Math.random() < dt * (tier - 4) * 6) emettre(pointArme(), { n: 1, c1: TIERS[tier].color, c2: '#ffffff', vit: 0.6, vie: 0.6, taille: 0.22, rayon: 0.3 });
  // ruée / roulade
  if (j.dashT > 0) { j.dashT -= dt; deplacer(j, j.dashV.x * dt, j.dashV.z * dt); if (Math.random() < 0.7) emettre(V(j.pos.x, 0.5, j.pos.z), { n: 1, c1: '#ffffff', c2: '#c8b8a0', vit: 0.5, vie: 0.4, taille: 0.4 }); j.maj(dt); return; }
  // tempête d'acier
  if (j.spinT > 0) {
    j.spinT -= dt; j.spinTick -= dt;
    if (j.spinTick <= 0) { j.spinTick = 0.4; zoneDegats(j.pos, SORTS.tempete.portee, SORTS.tempete.mult, { c1: '#c7d6ff', c2: '#5a7aff' }); son('knifeSlice2', 0.35, 1.2); }
    if (j.spinT <= 0) j.jouer(j.def.idle);
  }
  // déplacement
  let mx = entree.jx, my = entree.jy;
  const k = entree.clavier;
  if (k.ArrowLeft) mx -= 1; if (k.ArrowRight) mx += 1; if (k.ArrowUp) my += 1; if (k.ArrowDown) my -= 1;
  if (arene && arene.t > 0) { mx = 0; my = 0; } // décompte : personne ne bouge
  const m = Math.min(1, Math.hypot(mx, my));
  const tourne = j.spinT > 0 || j.tornadeT > 0; // tempête d'acier / œil du cyclone : on garde l'animation de toupie
  if (j.animT > 0) j.animT -= dt;
  if (j.verrouT <= 0) j.verrouAtk = false;
  const bloque = j.verrouT > 0 && !tourne && !j.verrouAtk;
  let autoAtk = false;
  if (G.auto && pvpActif()) couperAuto('Mode auto désactivé : combat JcJ');
  if (G.auto && m <= 0.12 && !transition) autoAtk = modeAuto(j, dt, bloque);
  j.couches = m > 0.12 && !bloque && !tourne; j.jambesNom = j.def.run;
  if (m > 0.12 && !bloque) {
    const dir = DIR_DROITE.clone().multiplyScalar(mx).addScaledVector(DIR_HAUT, my).normalize();
    let v = st.vitesse * (1 + bonusParch('vitesse')) * (j.orageT > 0 ? 1.4 : 1) * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1) * (tourne ? 0.7 : 1) * (j.verrouAtk && j.verrouT > 0 ? 0.45 : 1) * (j.eveilT > 0 ? 1.15 : 1); // vitesse constante, peu importe l'inclinaison du joystick
    // accélération douce (0,1 s) : le perso démarre et tourne avec du poids, sans à-coups
    deplacer(j, dir.x * v * dt, dir.z * v * dt);
    const vise = (entree.atk || entree.clavier[' ']) && j.cible && !j.cible.mort && dist2D(j.cible.pos, j.pos) - j.cible.rayon < st.portee + 0.5;
    const a0 = j.angle;
    if (!tourne && !vise) { j.angle = tourner(j.angle, Math.atan2(dir.x, dir.z), dt * 14); j.root.rotation.y = j.angle; }
    // jambes toujours en course quand on bouge, même pendant une attaque (le haut du corps frappe)
    if (!tourne) { if (j.haut) j._jouerBas(j.def.run); else if (j.courante && j.courante.loop === THREE.LoopOnce && j.courante.isRunning()) { const n = j.courante.getClip().name, t = j.courante.time, ts = j.courante.timeScale, f = j._onFin; if (j._jouerHaut(n, { vitesse: ts, fin: f, jambes: j.def.run })) j.haut.time = t; } else j.jouer(j.def.run); }
    j.pasT -= dt * v; if (j.pasT <= 0) { j.pasT = 2.4; son(Math.random() < 0.5 ? 'footstep_concrete_000' : 'footstep_concrete_001', 0.12); if (J.argent >= 5e6 && Math.random() < 0.3) son('handleCoins', 0.05, 1.7); } // une bourse bien pleine tinte en marchant
  } else if (j.haut) { j._jouerBas(j.def.idle); // on s'arrête pendant une attaque : les jambes se posent
  } else if (!bloque && !tourne && !(j.animT > 0)) {
    const c = j.courante; const n = c ? c.getClip().name : '';
    if (n === j.def.run || n === 'Walking_A') j.jouer(j.def.idle);
    // posture : garde haute en combat, détendue au calme
    const garde = !j.rangee && j.combatT > 0 && j.actions['2H_Melee_Idle'] && ['epee', 'orage', 'ombre', 'assassin', 'demon'].includes(j.armeType);
    const voulu = garde ? '2H_Melee_Idle' : j.rangee ? 'Idle' : j.def.idle;
    if ((n === j.def.idle || n === '2H_Melee_Idle' || n === 'Idle') && n !== voulu) j.jouer(voulu, { fondu: 0.35 });
  }
  if (j.sortAttente) { j.sortAttente.t -= dt; if (j.sortAttente.t <= 0) j.sortAttente = null; else if (j.verrouT <= 0.15) { const sa = j.sortAttente; j.sortAttente = null; viseeForcee = sa.force; lancerSort(sa.k); viseeForcee = null; } }
  if ((entree.atk || entree.clavier[' '] || autoAtk) && !(arene && arene.t > 0) && !j.sortAttente) attaquer(dt);
  j.maj(dt);
}

