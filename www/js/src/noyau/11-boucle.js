// ---------------- Boucle ----------------
const camMarche = (x, z) => monde.marche(x, z); // la caméra ne traverse pas les murs
let dernier = performance.now(), hudT = 0, miniT = 0, ileT = 2, argentVu = null, gainCumul = 0, gainT = 0;
const ORBITE = V(0, 0, 0);
// filet de sécurité : une erreur dans une mise à jour ne doit jamais figer le jeu (l'image continue, l'erreur est notée)
let derniereErr = 0;
function boucle() {
  requestAnimationFrame(boucle);
  const t0m = G.mesure ? performance.now() : 0;
  try { boucleCorps(); if (G.mesure) { G.mesure.push([G._tl - t0m, performance.now() - G._tl]); if (G.mesure.length > 4000) G.mesure.shift(); } } catch (e) {
    if (performance.now() - derniereErr > 5000) { derniereErr = performance.now(); console.error('Erreur de jeu :', e && e.stack || e); if (pontErreurs.length < 20) pontErreurs.push(String(e && e.message)); }
    try { if (!G.simRapide) rendre(); } catch (e2) {}
  }
}
function boucleCorps() {
  const now = performance.now(); const dtReel = (now - dernier) / 1000; let dt = Math.min(0.05, dtReel); dernier = now;
  if (G.ralentiT > 0) { G.ralentiT -= dtReel; dt *= G.ralentiK; } // arrêt sur image / ralenti des gros coups
  const q = majQualiteAuto(dtReel, enJeu && !transition && !document.hidden && !modeActuel); // réglage auto seulement sur la Place : jamais de gel en plein combat
  majResolution(dtReel, enJeu && !transition && !document.hidden);
  if (q === 'baisse') UI.toast(G.niveau === 1 ? 'Qualité ajustée : lueurs coupées pour plus de fluidité' : 'Qualité ajustée : ombres coupées pour plus de fluidité');
  G.t += dt; G.dt = dt;
  for (const f of G.anims || []) f(G.t, dt);
  for (let i = minuteries.length - 1; i >= 0; i--) { const m = minuteries[i]; m.t -= dt; if (m.t <= 0) { minuteries.splice(i, 1); m.fn(); } }
  if (marchand) marchand.maj(dt);
  if (enJeu && joueur) {
    G.focus = joueur.pos;
    if (!transition) majJoueur(dt);
    for (let xi = -1; xi < allies.length; xi++) { const x = xi < 0 ? joueur : allies[xi]; if (!x._pp) x._pp = x.pos.clone(); x.vel = x.vel || V(); x.vel.set((x.pos.x - x._pp.x) / Math.max(dt, 0.001), 0, (x.pos.z - x._pp.z) / Math.max(dt, 0.001)); x._pp.copy(x.pos); }
    if (!modeActuel) { majBots(dt); for (const l of meute) if (l && !l.mort && allies.includes(l)) { majLoup(l, dt); l.maj(dt); } } else { majEnnemis(dt); majAllies(dt); majProjectiles(dt); majInvasion(dt); majArene(dt); if (modeActuel.id === 'ville') majVille(dt); else if (captifV) majCaptif(dt); }
    for (let i = dangers.length - 1; i >= 0; i--) { dangers[i].t -= dt; if (dangers[i].t <= 0) dangers.splice(i, 1); }
    if (modeActuel && modeActuel.sylve) { majSylve(dt); sylveMeterT = (sylveMeterT || 0) - dt; if (sylveMeterT <= 0) { sylveMeterT = 0.5; if (compteur) UI.majDegats(classement(compteur.total, 0, G.t - sylve.debut)); } }
    if (errant) majErrant(dt);
    if (modeActuel && modeActuel.id === 'domaine') majServiteurs(dt);
    if (terres) majTerres(dt);
    if (modeActuel && modeActuel.id === 'ile') { majOuvriers(dt); majNoeuds(dt); majRecolteJoueur(dt); majPillard(dt); if (intendant) intendant.maj(dt); }
    if (passeur) passeur.maj(dt);
    if (graveuse) graveuse.maj(dt);
    ileT -= dt; if (ileT <= 0) { ileT = 3; majVengeance(); majProduction(); majDomaine(); majAssauts(); majRaids(); if (modeActuel && modeActuel.id === 'ile' && !monde.etranger && !(raid && raid.r)) journalIle(monde.ile); }
    if (monde.type === 'donjon') { majScenes(dt); majCrypte(dt); majAurasDonjon(dt); }
    majRegards(); majAuras(dt); majPortes(dt); majVueOmbre(); majTK(dt); majLames(dt); majPossedes(dt);
    if (!modeActuel || modeActuel.id === 'ile') majParolesPNJ(dt);
    majRumeurs(dt); majFortune(dt); majEchosArene(dt);
    majEscouade(dt); majCommandeOmbres(dt); majAbime(dt); majMeuteJoueur(dt); if (taverne) majTaverne(dt); if (mission) majMission(dt); majEveil(dt); if (goulet) majGoulet(dt); if (!modeActuel) majPortailGoulet();
    G.enCombat = joueur.combatT > 0 && !!modeActuel;
    G.acteurJoueur = joueur; G.camMarche = G.murs && monde && monde.marche ? camMarche : null;
    majCamera(dt, G.solH && !G.camCible ? V(joueur.pos.x, solY(joueur.pos.x, joueur.pos.z), joueur.pos.z) : (G.camCible || joueur.pos));
    majTorches(joueur.pos);
    if (joueur.comboT > 0) { joueur.comboT -= dt; if (joueur.comboT <= 0) joueur.combo = 0; }
    if (argentVu !== null && J.argent !== argentVu) { const d = J.argent - argentVu; if (d > 0) gainCumul += d; else UI.perteArgent(-d); UI.majBourse(J.argent); }
    gainT -= dtReel; if (gainCumul > 0 && gainT <= 0) { gainT = 0.9; const sp = G.sourceArgent || projeter(V(joueur.pos.x, 1.8, joueur.pos.z)); UI.gainArgent(gainCumul, sp.x, sp.y); gainCumul = 0; G.sourceArgent = null; }
    argentVu = J.argent; UI.roulerBourse(dtReel);
    hudT -= dt; if (hudT <= 0) { hudT = 0.08; UI.majCombo(joueur.def.assassin ? joueur.combo || 0 : -1); UI.majHud(joueur, joueur.st); UI.majSorts(joueur); majInteractions(); majCadreAutre(); majBarreRival(); }
    miniT -= dt; if (miniT <= 0) { miniT = 0.2; majBoutonTP(); majMini(); majParchemins(0.2); majMusique(0.2); }
    UI.majPlaques(joueur.pos);
    // anneau de cible
    majAnneauCible(); majVisee();
    majPont(dt);
  } else if (monde) {
    // écran titre : la caméra tourne autour de la place
    G.camYaw = Math.PI / 4 + Math.sin(G.t * 0.1) * 0.5; ORBITE.set(Math.sin(G.t * 0.07) * 6, 0, 2);
    majCamera(dt, ORBITE); majTorches(ORBITE);
    majBots(dt);
    UI.majPlaques(ORBITE);
  }
  if (enJeu && !G.camLibre && joueur) {
    const vue = G.camCible ? 'iso' : (G.camVue || 'iso');
    if (vue === 'iso') G.camYaw = Math.PI / 4;
    else if (vue === 'heros' && G.t - (G.dragT || -9) > 1.4 && Math.hypot(entree.jx, entree.jy) > 0.2 && entree.jy > -0.35) {
      // la caméra se replace doucement derrière toi quand tu avances
      let dy = joueur.angle + Math.PI - G.camYaw; dy = Math.atan2(Math.sin(dy), Math.cos(dy)); G.camYaw += dy * Math.min(1, G.dt * 1.5);
    }
    const mc = $('#carteMini'); if (mc) { const r = vue === 'iso' ? null : G.camYaw; if (mc._r !== r) { mc._r = r; mc.style.transform = r === null ? '' : `rotate(${r}rad)`; mc.classList.toggle('rond', r !== null); } }
  }
  majFeux(dt); majVfx(dt); majParticules(dt);
  const t1 = performance.now();
  if (G.mesure) G._tl = performance.now();
  if (!G.simRapide) { const tr = PROF_ON ? performance.now() : 0; rendre(); if (PROF_ON) profNote('rendu (GPU)', performance.now() - tr); }
  const t2 = performance.now(), P = G.perf || (G.perf = { upd: 0, rend: 0, max: 0, pics: 0 });
  P.upd = P.upd * 0.95 + (t1 - now) * 0.05; P.rend = P.rend * 0.95 + (t2 - t1) * 0.05;
  if (t2 - now > 40) P.pics++; P.max = Math.max(P.max, t2 - now);
  if (G.perfOn) {
    P.n = (P.n || 0) + 1; P.acc = (P.acc || 0) + dtReel; P.pire = Math.max(P.pire || 0, dtReel);
    if (G.perfOn && !PROF_ON) instrumenter();
    if (P.pire > 0.06 && PROF_ON) { let k = '', v = 0; for (const n in PROF_MAX) if (PROF_MAX[n] > v) { v = PROF_MAX[n]; k = n; } profGel = v < P.pire * 300 ? `dernier gel ${Math.round(P.pire * 1000)} ms → hors du code du jeu (mémoire / affichage du navigateur)` : `dernier gel ${Math.round(P.pire * 1000)} ms → ${k.replace(/^maj/, '')} ${Math.round(v)} ms`; }
    if (P.acc >= 0.5) { UI.majPerf(`${Math.round(P.n / P.acc)} fps · pire ${Math.round(P.pire * 1000)} ms · ${G.renderer.info.render.calls} appels · qualité ${['basse', 'moyenne', 'haute'][G.niveau]}${PROF_ON ? '\n' + rapportProf(P.n) + (profGel ? '\n' + profGel : '') : ''}`); P.n = 0; P.acc = 0; P.pire = 0; }
  }
}
let anneau = null;
function majAnneauCible() {
  if (!anneau) {
    anneau = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.1, 40), new THREE.MeshBasicMaterial({ color: '#ff3a2a', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    anneau.rotation.x = -Math.PI / 2; G.scene.add(anneau);
  }
  if (!anneau.parent) G.scene.add(anneau);
  const c = joueur.cibleVerrou && !joueur.cibleVerrou.mort ? joueur.cibleVerrou : (entree.atk ? joueur.cible : null);
  if (c && !c.mort) { anneau.visible = true; anneau.position.set(c.pos.x, 0.12, c.pos.z); anneau.scale.setScalar(c.rayon * 1.6 + 0.3); anneau.material.color.set(joueur.cibleVerrou ? '#ffcf4a' : '#ff3a2a'); anneau.rotation.z = G.t; }
  else anneau.visible = false;
}
function majMini() {
  const ents = [];
  if (!modeActuel) {
    for (const b of bots) if (!b.mort) ents.push({ type: groupe && b.nom === groupe.nom ? 'allie' : 'joueur', x: b.pos.x, z: b.pos.z });
    if (marchand) ents.push({ type: 'pnj', x: marchand.pos.x, z: marchand.pos.z });
    ents.push({ type: 'portail', x: monde.portail.pos.x, z: monde.portail.pos.z });
    if (monde.portailArene) ents.push({ type: 'portailV', x: monde.portailArene.pos.x, z: monde.portailArene.pos.z });
    if (monde.portailIle) ents.push({ type: 'portailJ', x: monde.portailIle.pos.x, z: monde.portailIle.pos.z });
  } else if (monde.type === 'sylve') {
    for (const e of ennemis) if (!e.mort && (e.boss || dist2D(e.pos, joueur.pos) < 60)) ents.push({ type: e.boss ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    for (const a of allies) if (!a.mort && !a.invoc) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const c of coffres) if (!c.ouvert) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    if (sortie) ents.push({ type: 'portailV', x: sortie.pos.x, z: sortie.pos.z });
    ents.centre = joueur.pos;
  } else if (monde.type === 'terres') {
    for (const e of ennemis) if (!e.mort && dist2D(e.pos, joueur.pos) < 75) ents.push({ type: e.chasseur ? 'rouge' : e.boss ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    for (const c of coffres) if (!c.ouvert && dist2D(c.pos, joueur.pos) < 75) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    for (const p of monde.sorties) ents.push({ type: 'portailV', x: p.x, z: p.z });
  } else if (monde.type === 'goulet') {
    for (const a of allies) if (!a.mort && a.bg) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const e of ennemis) if (!e.mort && dist2D(e.pos, joueur.pos) < 30) ents.push({ type: 'rouge', x: e.pos.x, z: e.pos.z });
    if (goulet) for (const F of Object.values(goulet.drapeaux)) if (F.etat !== 'attente') ents.push({ type: 'drapeau', x: F.mesh.position.x, z: F.mesh.position.z, c: COUL_CAMP[F.camp], porte: F.etat === 'porte' });
    if (goulet) for (const b of goulet.bonus) if (b.t <= 0) ents.push({ type: 'bonusBG', x: b.pos.x, z: b.pos.z, c: b.coul });
  } else if (monde.type === 'ile') {
    for (const e of ennemis) if (!e.mort) ents.push({ type: 'boss', x: e.pos.x, z: e.pos.z });
    for (const a of allies) if (!a.mort) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const o of ouvriers) ents.push({ type: 'joueur', x: o.pos.x, z: o.pos.z });
    if (intendant) ents.push({ type: 'pnj', x: intendant.pos.x, z: intendant.pos.z });
    ents.push({ type: 'coffre', x: monde.coffrePos.x, z: monde.coffrePos.z, c: '#ffd25a' });
    ents.push({ type: 'portailJ', x: monde.portail.pos.x, z: monde.portail.pos.z });
  } else {
    for (const e of ennemis) if (!e.mort) {
      if (e.rival && invasion && !(invasion.revele > 0) && dist2D(e.pos, joueur.pos) > 14) continue;
      if (e.boss && e.boss.errant && !(e.revele > 0) && e.etat === 'dormant') continue;
      ents.push({ type: e.rival ? 'envahisseur' : e.boss && e.boss.errant ? 'errant' : e.boss ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    }
    for (const c of coffres) if (!c.ouvert) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    if (sortie) ents.push({ type: 'portailV', x: sortie.pos.x, z: sortie.pos.z });
    for (const a of allies) if (!a.mort) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
  }
  UI.mini(monde, joueur, ents);
}


